//
//  FetchModifier.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 15/10/2026.
//

import CoreData
import SwiftUI
import Combine

public protocol Fetch<ResultType>: Equatable {
    associatedtype ResultType: NSManagedObject
    func configure(request: NSFetchRequest<ResultType>)
}

public struct ModernSortedFetch<ResultType: NSManagedObject>: Fetch {
    public var sortDescriptors: [SortDescriptor<ResultType>]
    
    public init(sortDescriptors: [SortDescriptor<ResultType>] = []) {
        self.sortDescriptors = sortDescriptors
    }
    
    public func configure(request: NSFetchRequest<ResultType>) {
        request.sortDescriptors = sortDescriptors.map { NSSortDescriptor($0) }
    }
}

public struct FetchModifier<F: Fetch>: ViewModifier {
    
    public let fetch: F
    public let handleResults: (Result<[F.ResultType], Error>) -> Void
    
    @Environment(\.managedObjectContext) private var context
    @State private var observer = FetchObserver()
    
    private struct Trigger: Equatable {
        let context: NSManagedObjectContext
        let fetch: F
    }
    
    public func body(content: Content) -> some View {
        content
            .onChange(of: observer.changeCount) {
                handleResults(.success(observer.frc?.fetchedObjects as? [F.ResultType] ?? []))
            }
            .onChange(of: Trigger(context: context, fetch: fetch), initial: true) { old, new in
                // something changed that requires re-fetch
                // if context changed then need a new frc
                
                let frc: NSFetchedResultsController<F.ResultType>
                
                if let existingFRC = observer.frc, existingFRC.managedObjectContext == new.context {
                    frc = existingFRC
                }
                else {
                    let fr = NSFetchRequest<F.ResultType>(entityName: F.ResultType.entity().name ?? "\(F.ResultType.self)")
                    fr.sortDescriptors = []
                    frc = NSFetchedResultsController(
                        fetchRequest: fr,
                        managedObjectContext: new.context,
                        sectionNameKeyPath: nil,
                        cacheName: nil
                    )
                    observer.frc = frc
                }
                new.fetch.configure(request: frc.fetchRequest)
                let result = Result {
                    try frc.performFetch()
                    return frc.fetchedObjects ?? []
                }
                handleResults(result)
            }
        
    }
    
    @Observable
    class FetchObserver: NSObject, NSFetchedResultsControllerDelegate {
        
        var changeCount = 0
        
        @ObservationIgnored
        var frc: NSFetchedResultsController<F.ResultType>? {
            didSet {
                oldValue?.delegate = nil
                frc?.delegate = self
            }
        }
        
        override init() {
            super.init()
        }
        
        @ObservationIgnored
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
            
            changeCount += 1
        }
        
        deinit {
            print("deinit")
        }
        
    }
}

public extension View {
    func fetch<F: Fetch>(
        _ fetch: F,
        results: @escaping (Result<[F.ResultType], Error>) -> Void
    ) -> some View {
        modifier(FetchModifier(fetch: fetch, handleResults: results))
    }
}
