//
//  FetchModifier.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/10/2026.
//
import CoreData
import SwiftUI

public struct FetchModifier<ResultType: NSManagedObject, ID: Equatable>: ViewModifier {
    let id: ID
    let configure: (NSFetchRequest<ResultType>) -> Void
    let handleResults: (Result<[ResultType], Error>) -> Void
    
    @Environment(\.managedObjectContext) private var context
    @StateObject private var observer = FetchObserver()
    
    public func body(content: Content) -> some View {
        content
        // Context change (or initial load) creates a fresh FRC
            .onChange(of: context, initial: true) { _, _ in
                let request = NSFetchRequest<ResultType>(entityName: ResultType.entity().name ?? "\(ResultType.self)")
                configure(request)
                observer.frc = NSFetchedResultsController<ResultType>(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
                fetchAndHandleResults()
            }
        // ID change reuses the existing FRC and just fetches
            .onChange(of: id) { _, _ in
                configure(observer.frc.fetchRequest)
                fetchAndHandleResults()
            }
            .onReceive(observer.objectWillChange) {
                handleResults(.success(observer.frc.fetchedObjects ?? []))
            }
    }
    
    func fetchAndHandleResults() {
        do {
            try observer.frc.performFetch()
            handleResults(.success(observer.frc.fetchedObjects ?? []))
        } catch {
            handleResults(.failure(error))
        }
    }
    
    class FetchObserver: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
        var frc: NSFetchedResultsController<ResultType>! {
            didSet {
                oldValue?.delegate = nil
                frc.delegate = self
            }
        }
        
        override init() {
            super.init()
        }
        
        private var hasStructuralChanges = false
        
        public func controller(_ controller: NSFetchedResultsController<any NSFetchRequestResult>,
                               didChange anObject: Any,
                               at indexPath: IndexPath?,
                               for type: NSFetchedResultsChangeType,
                               newIndexPath: IndexPath?) {
            
            // We only care about moves, inserts, and deletes.
            // If it's just an .update, we leave hasStructuralChanges as false.
            
            // We explicitly ignore '.update' events to prevent unnecessary invalidation of the entire collection.
            // Following the 'Granular Observation' pattern:
            // 1. This Wrapper manages the IDENTITY and ORDER of the list (Structural Changes).
            // 2. Individual Row Views should use @ObservedObject to monitor property changes.
            // This prevents a single property update in one row from re-calculating the body of the entire list.
            
            if type != .update {
                hasStructuralChanges = true
            }
        }
        
        public func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
            // 1. If no structural changes happened, we stay silent.
            // The child views will handle their own @ObservedObject updates.
            guard hasStructuralChanges else { return }
            
            // 2. Prepare for the next transaction
            hasStructuralChanges = false
            
            objectWillChange.send()
        }
        
    }
}

public extension View {
    func fetch<ResultType: NSManagedObject, ID: Equatable>(
        of: ResultType.Type,
        id: ID,
        configure: @escaping (NSFetchRequest<ResultType>) -> Void,
        results: @escaping (Result<[ResultType], Error>) -> Void
    ) -> some View {
        modifier(FetchModifier(id: id, configure: configure, handleResults: results))
    }
}
