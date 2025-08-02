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
struct FetchRequest2<ResultType>: @preconcurrency DynamicProperty where ResultType: NSManagedObject {
    
    @Environment(\.managedObjectContext) private var context
    @StateObject private var coordinator = Coordinator()
    
    private let configurator: Configurator
    private let changesAnimation: Animation
    
    init(sortDescriptors: [SortDescriptor<ResultType>] = [], nsPredicate: NSPredicate? = nil, changesAnimation: Animation = .default) {
        let nsSortDescriptors = sortDescriptors.map(NSSortDescriptor.init)
        self.configurator = .components(nsSortDescriptors: nsSortDescriptors, predicate: nsPredicate)
        self.changesAnimation = changesAnimation
    }
    
    init(nsSortDescriptors: [NSSortDescriptor] = [], nsPredicate: NSPredicate? = nil, changesAnimation: Animation = .default) {
        self.configurator = .components(nsSortDescriptors: nsSortDescriptors, predicate: nsPredicate)
        self.changesAnimation = changesAnimation
    }
    
    init(fetchRequest: NSFetchRequest<ResultType>, changesAnimation: Animation = .default) {
        self.configurator = .request(fetchRequest)
        self.changesAnimation = changesAnimation
    }
    
    var wrappedValue: Result<[ResultType], Error> = .success([])
    
    mutating func update() {
        
        coordinator.animation = changesAnimation
        
        let fr = coordinator.fetchedResultsController?.fetchRequest ?? NSFetchRequest<ResultType>(entityName: "\(ResultType.self)")
        
        var fetchNeeded = configurator.configure(fetchRequest: fr)
        
        let frc: NSFetchedResultsController<ResultType>
        if let existingFRC = coordinator.fetchedResultsController, context == existingFRC.managedObjectContext {
            frc = existingFRC
        } else {
            frc = NSFetchedResultsController<ResultType>(fetchRequest: fr, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
            coordinator.fetchedResultsController = frc
            fetchNeeded = true
        }
        
        wrappedValue = Result {
            if fetchNeeded {
                try frc.performFetch()
            }
            return frc.fetchedObjects ?? []
        }
    }
    
    
    enum Configurator {
        case components(nsSortDescriptors: [NSSortDescriptor], predicate: NSPredicate?)
        case request(NSFetchRequest<ResultType>)
        
        func configure(fetchRequest fr: NSFetchRequest<ResultType>) -> Bool {
            var changed = false
            
            func assignIfDifferent<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<NSFetchRequest<ResultType>, T>,
                                                 _ newValue: T) {
                if fr[keyPath: keyPath] != newValue {
                    fr[keyPath: keyPath] = newValue
                    changed = true
                }
            }
            
            func assignIfDifferentOptional<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<NSFetchRequest<ResultType>, T?>,
                                                         _ newValue: T?) {
                if fr[keyPath: keyPath] != newValue {
                    fr[keyPath: keyPath] = newValue
                    changed = true
                }
            }
            
            switch self {
                case .components(let nsSortDescriptors, let predicate):
                    assignIfDifferent(\.sortDescriptors, nsSortDescriptors)
                    assignIfDifferent(\.predicate, predicate)
                    
                case .request(let newRequest):
                    // Core fetch properties
                    assignIfDifferentOptional(\.sortDescriptors, newRequest.sortDescriptors)
                    assignIfDifferentOptional(\.predicate, newRequest.predicate)
                    assignIfDifferent(\.fetchLimit, newRequest.fetchLimit)
                    assignIfDifferent(\.fetchOffset, newRequest.fetchOffset)
                    assignIfDifferent(\.fetchBatchSize, newRequest.fetchBatchSize)
                    
                    // Boolean flags
                    assignIfDifferent(\.includesSubentities, newRequest.includesSubentities)
                    assignIfDifferent(\.includesPendingChanges, newRequest.includesPendingChanges)
                    assignIfDifferent(\.returnsObjectsAsFaults, newRequest.returnsObjectsAsFaults)
                    assignIfDifferent(\.includesPropertyValues, newRequest.includesPropertyValues)
                    assignIfDifferent(\.shouldRefreshRefetchedObjects, newRequest.shouldRefreshRefetchedObjects)
                    
                    // propertiesToFetch: NSArray compare
                    if let lhs = fr.propertiesToFetch as? NSArray,
                       let rhs = newRequest.propertiesToFetch as? NSArray {
                        if !lhs.isEqual(to: rhs as! [Any]) {
                            fr.propertiesToFetch = newRequest.propertiesToFetch
                            changed = true
                        }
                    } else if (fr.propertiesToFetch != nil) || (newRequest.propertiesToFetch != nil) {
                        fr.propertiesToFetch = newRequest.propertiesToFetch
                        changed = true
                    }
                    
                    // Data result options
                    assignIfDifferent(\.resultType, newRequest.resultType)
                    assignIfDifferent(\.returnsDistinctResults, newRequest.returnsDistinctResults)
                    
                    // Advanced options
                    assignIfDifferentOptional(\.affectedStores, newRequest.affectedStores)
                    assignIfDifferentOptional(\.relationshipKeyPathsForPrefetching, newRequest.relationshipKeyPathsForPrefetching)
            }
            return changed
        }
    }
    
    @MainActor
    class Coordinator: NSObject, @preconcurrency NSFetchedResultsControllerDelegate, ObservableObject {
        
        var animation: Animation?
        
        var fetchedResultsController: NSFetchedResultsController<ResultType>? {
            didSet {
                oldValue?.delegate = nil
                fetchedResultsController?.delegate = self
            }
        }
        
        func controller(_ controller: NSFetchedResultsController<any NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
            if type != .update {
                withAnimation(animation) {
                    objectWillChange.send()
                }
            }
        }   
    }
}
