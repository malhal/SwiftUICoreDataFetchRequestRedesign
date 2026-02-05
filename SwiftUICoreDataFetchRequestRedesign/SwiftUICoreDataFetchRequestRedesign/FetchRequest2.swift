//
//  FetchRequest2.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//
// This design is essentially a lazy loader of the fetcehd results.
// Once could argue doing a fetch from body is bad.

import SwiftUI
import CoreData

@MainActor
@propertyWrapper
struct FetchRequest2<ResultType>: DynamicProperty where ResultType: NSManagedObject {
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    @StateObject private var coordinator = Coordinator()
    
    let changesAnimation: Animation
    let config: Config

    enum Config: Equatable {
        func isCompatible(with old: Config) -> Bool {
            switch (old, self) {
                case (.basic, .basic):
                    // Hardware is always compatible when staying in Basic mode
                    return true
                    
                case (.rawRequest(let oldReq), .rawRequest(let newReq)):
                    // Hardware is only compatible if the FetchRequest object is the same instance
                    return oldReq === newReq
                    
                default:
                    // Mode swapped (Basic <-> Raw), hardware is incompatible
                    return false
            }
        }
        
        func resolveFetchRequest() -> NSFetchRequest<ResultType> {
            switch self {
                case .rawRequest(let req):
                    return req
                case .basic(let req):
                    let fr = NSFetchRequest<ResultType>(entityName: ResultType.entity().name ?? "\(ResultType.self)")
                    fr.sortDescriptors = req.resolveNSSortDescriptors()
                    fr.predicate = req.nsPredicate
                    return fr
            }
        }
        
        func apply(to request: NSFetchRequest<ResultType>) {
            switch self {
                case .basic(let basic):
                    request.predicate = basic.nsPredicate
                    request.sortDescriptors = basic.resolveNSSortDescriptors()
                case .rawRequest(_):
                    // We only get here if the instance is the same (isCompatible check),
                    // so there is typically nothing to sync for raw requests.
                    break
            }
        }
        
        struct Basic: Equatable {
            let nsPredicate: NSPredicate?
            let sortType: SortType
            
            // This enum lets us compare modern vs legacy intents
            enum SortType: Equatable {
                case modern([SortDescriptor<ResultType>])
                case legacy([NSSortDescriptor])
            }
            
            // Helper to get NSSortDescriptors regardless of which type was provided
            func resolveNSSortDescriptors() -> [NSSortDescriptor] {
                switch sortType {
                    case .modern(let modern):
                        // Convert Swift SortDescriptors to legacy for the FRC
                        return modern.map { NSSortDescriptor($0) }
                    case .legacy(let legacy):
                        return legacy
                }
            }
        }
        
        case rawRequest(NSFetchRequest<ResultType>)
        case basic(Basic)
    }
    
    
    init(sortDescriptors: [SortDescriptor<ResultType>], nsPredicate: NSPredicate? = nil, changesAnimation: Animation = .default) {
        let basic = Config.Basic(nsPredicate: nsPredicate, sortType: .modern(sortDescriptors))
        config = Config.basic(basic)
        self.changesAnimation = changesAnimation
    }
    
    init(nsSortDescriptors: [NSSortDescriptor], nsPredicate: NSPredicate? = nil, changesAnimation: Animation = .default) {
        let basic = Config.Basic(nsPredicate: nsPredicate, sortType: .legacy(nsSortDescriptors))
        self.config = Config.basic(basic)
        self.changesAnimation = changesAnimation
    }
    
    init(fetchRequest: NSFetchRequest<ResultType>, changesAnimation: Animation = .default) {
        self.config = Config.rawRequest(fetchRequest)
        self.changesAnimation = changesAnimation
    }
    
    var wrappedValue: Result<[ResultType], Error> {
        coordinator.managedObjectContext = managedObjectContext
        coordinator.changesAnimation = changesAnimation
        coordinator.config = config
        return coordinator.result
    }
    
    @MainActor
    class Coordinator: NSObject, @preconcurrency NSFetchedResultsControllerDelegate, ObservableObject {
        
        var changesAnimation: Animation!
        
        var managedObjectContext: NSManagedObjectContext! {
            didSet {
                if managedObjectContext != oldValue {
                    _fetchedResultsController = nil
                }
            }
        }
        
        var config: Config! {
            didSet {
                if config != oldValue {
                    if let frc = _fetchedResultsController {
                        if config.isCompatible(with: oldValue) {
                            config.apply(to: frc.fetchRequest)
                            _result = nil
                        }
                        else {
                            _fetchedResultsController = nil
                        }
                    }
                }
            }
        }
        
        private var _fetchedResultsController: NSFetchedResultsController<ResultType>! {
            didSet {
                oldValue?.delegate = nil
                _fetchedResultsController?.delegate = self
                _result = nil
            }
        }
        
        var fetchedResultsController: NSFetchedResultsController<ResultType> {
            if _fetchedResultsController == nil {
                let fr = config.resolveFetchRequest()
                _fetchedResultsController = NSFetchedResultsController(
                    fetchRequest: fr,
                    managedObjectContext: managedObjectContext,
                    sectionNameKeyPath: nil,
                    cacheName: nil
                )
            }
            return _fetchedResultsController
        }
        
        private var _result: Result<[ResultType], Error>!
        var result: Result<[ResultType], Error> {
            if _result == nil {
                _result = Result {
                    try fetchedResultsController.performFetch()
                    return fetchedResultsController.fetchedObjects ?? []
                }
            }
            return _result
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
                _result = .success(controller.fetchedObjects as? [ResultType] ?? [])
            }
        }
        
    }
}
