//
//  FetchRequest3.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 11/03/2026.
//
// Experimental version implemented using Combine operators.

import SwiftUI
import CoreData
import Combine

@propertyWrapper
struct FetchRequest3<ResultType>: DynamicProperty where ResultType: NSManagedObject {
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    @StateObject private var coordinator = Coordinator()
    
    private let config: FetchConfig
    let changesAnimation: Animation?
    
    // Internal representation to avoid 'if let' branching in wrappedValue
    enum FetchConfig {
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
        coordinator.result
    }
    
    func update() {
        coordinator.changesAnimation = changesAnimation
        coordinator.fetch.send(FetchIngredients(context: managedObjectContext, config: config))
    }
    
    typealias FetchIngredients = (
        context: NSManagedObjectContext,
        config: FetchConfig
    )
    
    
    class Coordinator: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
        
        // prevents @Published sending changes
        let objectWillChange = PassthroughSubject<Void, Never>()
        @Published var result: Result<[ResultType], Error> = .success([])

        let fetch = PassthroughSubject<FetchIngredients, Never>()
        
        var changesAnimation: Animation?
        
        override init() {
            super.init()
            
            let fetchRequest = NSFetchRequest<ResultType>(entityName: ResultType.entity().name ?? "\(ResultType.self)")
            var fetchedResultsController: NSFetchedResultsController<ResultType>?
            var modernSortDescriptors: [SortDescriptor<ResultType>]?
            
            fetch
                .compactMap { (fetch: FetchIngredients) in
                    
                    let fr = {
                        switch fetch.config {
                            case .manual(let request):
                                modernSortDescriptors = nil
                                return request
                            case .modern(let sort, let predicate):
                                if sort != modernSortDescriptors {
                                    fetchRequest.sortDescriptors = sort.map { NSSortDescriptor($0) }
                                    modernSortDescriptors = sort
                                }
                                fetchRequest.predicate = predicate
                                return fetchRequest
                            case .legacy(let sort, let predicate):
                                fetchRequest.sortDescriptors = sort
                                fetchRequest.predicate = predicate
                                modernSortDescriptors = nil
                                return fetchRequest
                        }
                    }()
                    
                    if fetch.context == fetchedResultsController?.managedObjectContext &&
                        fr == fetchedResultsController?.fetchRequest {
                        return nil
                    }
                        
                    let frc = NSFetchedResultsController<ResultType>(
                        fetchRequest: fr.copy() as! NSFetchRequest,
                        managedObjectContext: fetch.context,
                        sectionNameKeyPath: nil,
                        cacheName: nil
                    )
                    frc.delegate = self
                    fetchedResultsController = frc
                    return Result {
                        try frc.performFetch()
                        return frc.fetchedObjects ?? []
                    }
                }
                .assign(to: &$result)
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
                result = .success(controller.fetchedObjects as? [ResultType] ?? [])
            }
        }
        
    }
}
