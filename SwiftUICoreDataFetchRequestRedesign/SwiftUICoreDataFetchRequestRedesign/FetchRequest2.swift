//
//  FetchRequest2.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI
import CoreData

@propertyWrapper
struct FetchRequest2<ResultType>: DynamicProperty where ResultType: NSManagedObject {
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    @StateObject private var coordinator = Coordinator()
    
    private let config: FetchConfig
    let changesAnimation: Animation?
    
    // Internal representation to avoid 'if let' branching in wrappedValue
    private enum FetchConfig {
        case manual(NSFetchRequest<ResultType>)
        case modern(sort: [SortDescriptor<ResultType>], predicate: NSPredicate?)
        case legacy(sort: [NSSortDescriptor], predicate: NSPredicate?)
    }
    
    // Modern SortDescriptors (SwiftUI standard)
    init(sortDescriptors: [SortDescriptor<ResultType>], nsPredicate: NSPredicate? = nil, changesAnimation: Animation? = nil) {
        self.config = .modern(sort: sortDescriptors, predicate: nsPredicate)
        self.changesAnimation = changesAnimation
    }
    
    // Legacy NSSortDescriptors
    init(nsSortDescriptors: [NSSortDescriptor], nsPredicate: NSPredicate? = nil, changesAnimation: Animation? = nil) {
        self.config = .legacy(sort: nsSortDescriptors, predicate: nsPredicate)
        self.changesAnimation = changesAnimation
    }
    
    // Existing NSFetchRequest
    init(fetchRequest: NSFetchRequest<ResultType>, changesAnimation: Animation? = nil) {
        self.config = .manual(fetchRequest)
        self.changesAnimation = changesAnimation
    }
    
    var wrappedValue: Result<[ResultType], Error> {
        Result {
            switch config {
                case .manual(let request):
                    return try coordinator.result(fetchRequest: request, managedObjectContext: managedObjectContext, changesAnimation: changesAnimation)
                case .modern(let sort, let predicate):
                    return try coordinator.result(sortDescriptors: sort, nsPredicate: predicate, managedObjectContext: managedObjectContext, changesAnimation: changesAnimation)
                case .legacy(let sort, let predicate):
                    return try coordinator.result(nsSortDescriptors: sort, nsPredicate: predicate, managedObjectContext: managedObjectContext, changesAnimation: changesAnimation)
            }
        }
    }
    
    @MainActor
    class Coordinator: NSObject, @preconcurrency NSFetchedResultsControllerDelegate, ObservableObject {
        
        private var changesAnimation: Animation?
        
        lazy var convenienceFetchRequest: NSFetchRequest<ResultType> = {
            NSFetchRequest<ResultType>(entityName: ResultType.entity().name ?? "\(ResultType.self)")
        }()
        
        // designed to prevent unnecessary converts to NSSortDescriptor
        private var cachedSortDescriptors: [SortDescriptor<ResultType>]?
        
        func result(sortDescriptors: [SortDescriptor<ResultType>], nsPredicate: NSPredicate? = nil, managedObjectContext: NSManagedObjectContext, changesAnimation: Animation? = nil) throws -> [ResultType] {
            if cachedSortDescriptors != sortDescriptors {
                convenienceFetchRequest.sortDescriptors = sortDescriptors.map { NSSortDescriptor($0) }
                cachedSortDescriptors = sortDescriptors
            }
            convenienceFetchRequest.predicate = nsPredicate
            return try result(fetchRequest: convenienceFetchRequest, managedObjectContext: managedObjectContext, changesAnimation: changesAnimation)
        }
        
        func result(nsSortDescriptors: [NSSortDescriptor], nsPredicate: NSPredicate? = nil, managedObjectContext: NSManagedObjectContext, changesAnimation: Animation? = nil) throws -> [ResultType] {
            convenienceFetchRequest.sortDescriptors = nsSortDescriptors
            convenienceFetchRequest.predicate = nsPredicate
            // clear in case they had previously been used
            cachedSortDescriptors = nil
            return try result(fetchRequest: convenienceFetchRequest, managedObjectContext: managedObjectContext, changesAnimation: changesAnimation)
        }
        
        private var fetchedResultsController: NSFetchedResultsController<ResultType>?
        
        func result(fetchRequest: NSFetchRequest<ResultType>, managedObjectContext: NSManagedObjectContext, changesAnimation: Animation? = nil) throws -> [ResultType] {
            
            self.changesAnimation = changesAnimation
            
            if fetchedResultsController?.managedObjectContext != managedObjectContext {
                fetchedResultsController = nil
            }
            
            if fetchedResultsController?.fetchRequest != fetchRequest {
                fetchedResultsController = nil
            }
            
            if fetchedResultsController == nil {
                // we copy the request so we can compare agains the updated convenienceFetchRequest next time.
                let fr = fetchRequest.copy() as! NSFetchRequest<ResultType>
                let frc = NSFetchedResultsController<ResultType>(
                    fetchRequest: fr,
                    managedObjectContext: managedObjectContext,
                    sectionNameKeyPath: nil,
                    cacheName: nil
                )
                
                frc.delegate = self
                try frc.performFetch()
                fetchedResultsController = frc
            }
            
            return fetchedResultsController?.fetchedObjects ?? []
        }
        
        private var hasStructuralChanges = false
        
        func controller(_ controller: NSFetchedResultsController<any NSFetchRequestResult>,
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
        
        func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
            // 1. If no structural changes happened, we stay silent.
            // The child views will handle their own @ObservedObject updates.
            guard hasStructuralChanges else { return }
            
            // 2. Prepare for the next transaction
            hasStructuralChanges = false
            
            withAnimation(changesAnimation) {
                objectWillChange.send()
            }
        }
        
    }
}
