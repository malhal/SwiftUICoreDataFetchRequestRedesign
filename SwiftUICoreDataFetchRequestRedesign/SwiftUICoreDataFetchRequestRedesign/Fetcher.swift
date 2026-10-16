//
//  Fetch.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 16/10/2026.
//


//
//  FetchModifier.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 15/10/2026.
//

import CoreData
import SwiftUI
import Combine

public protocol FetchRequestConfiguring<ResultType>: Equatable {
    associatedtype ResultType: NSManagedObject
    func configure(request: NSFetchRequest<ResultType>)
}

public struct ModernSortedFetch<ResultType: NSManagedObject>: FetchRequestConfiguring {
    public var sortDescriptors: [SortDescriptor<ResultType>]
    
    public init(sortDescriptors: [SortDescriptor<ResultType>] = []) {
        self.sortDescriptors = sortDescriptors
    }
    
    public func configure(request: NSFetchRequest<ResultType>) {
        request.sortDescriptors = sortDescriptors.map { NSSortDescriptor($0) }
    }
}


public struct FetchState<ResultType: NSManagedObject> {
    public fileprivate(set) var results: [ResultType]
    public fileprivate(set) var error: Error?
}

public struct Fetcher<F: FetchRequestConfiguring, Content: View>: View {
    
    private let fetch: F
    private var content: (FetchState<F.ResultType>) -> Content
    
    @State private var observer = FetchObserver()
    
    @Environment(\.managedObjectContext) private var context
    
    public init(
        _ fetch: F,
        @ViewBuilder content: @escaping (FetchState<F.ResultType>) -> Content
    ) {
        self.fetch = fetch
        self.content = content
    }
    
    public var body: some View {
        let _ = observer.update(context: context, fetch: fetch)
        content(observer.state)
    }
    
    @Observable
    public class FetchObserver: NSObject, NSFetchedResultsControllerDelegate {
        
        public private(set) var state = FetchState<F.ResultType>(results: [], error: nil)
        
        @ObservationIgnored
        public var lastFetch: F?
        
        @ObservationIgnored
        var fetchedResultsController: NSFetchedResultsController<F.ResultType>? {
            didSet {
                oldValue?.delegate = nil
                fetchedResultsController?.delegate = self
            }
        }
        
        @ObservationIgnored
        private var hasStructuralChanges = false
        
        
        override init() {
            super.init()
        }

        // if change context should we clear the results regardless if there is an error?
        public func update(context: NSManagedObjectContext, fetch: F) {
            let activeFRC: NSFetchedResultsController<F.ResultType>
            
            if let existingFRC = fetchedResultsController,
                existingFRC.managedObjectContext == context {
                if fetch == lastFetch {
                   return
                }
                activeFRC = existingFRC
            } else {
                let fr = NSFetchRequest<F.ResultType>(entityName: F.ResultType.entity().name ?? "\(F.ResultType.self)")
                fr.sortDescriptors = []
                activeFRC = NSFetchedResultsController(
                    fetchRequest: fr,
                    managedObjectContext: context,
                    sectionNameKeyPath: nil,
                    cacheName: nil
                )
                fetchedResultsController = activeFRC
            }
            
            lastFetch = fetch
            fetch.configure(request: activeFRC.fetchRequest)
            
            do {
                try activeFRC.performFetch()
                _state.error = nil
            } catch {
                _state.error = error
            }
            _state.results = activeFRC.fetchedObjects ?? []
        }
        
        public func controller(_ controller: NSFetchedResultsController<any NSFetchRequestResult>,
                               didChange anObject: Any,
                               at indexPath: IndexPath?,
                               for type: NSFetchedResultsChangeType,
                               newIndexPath: IndexPath?) {
            if type != .update {
                hasStructuralChanges = true
            }
        }
        
        public func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
            guard hasStructuralChanges else { return }
            hasStructuralChanges = false
            
            // Bump revision to force SwiftUI to re-evaluate body when background deletes/inserts happen
            state.error = nil
            state.results = controller.fetchedObjects as? [F.ResultType] ?? []
        }
        
        deinit {
            print("deinit")
        }
    }
}
