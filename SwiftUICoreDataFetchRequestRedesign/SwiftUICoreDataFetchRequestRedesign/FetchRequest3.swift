//
//  FetchRequest3.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI
import CoreData

@propertyWrapper
struct FetchRequest3<ResultType>: DynamicProperty where ResultType: NSManagedObject {
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    @StateObject private var controller = FetchController3<ResultType>()
    
    private let config: FetchConfig
    private let changesAnimation: Animation?
    
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
    
    var wrappedValue: FetchResult<ResultType> {
        controller.result
    }
    
    func update() {
        switch config {
            case .manual(let request):
                controller.update(fetchRequest: request, managedObjectContext: managedObjectContext)
            case .modern(let sort, let predicate):
                controller.update(sortDescriptors: sort, nsPredicate: predicate, managedObjectContext: managedObjectContext)
            case .legacy(let sort, let predicate):
                controller.update(nsSortDescriptors: sort, nsPredicate: predicate, managedObjectContext: managedObjectContext)
        }
        if changesAnimation != controller.changesAnimation {
            controller.changesAnimation = changesAnimation
        }
    }
}

public struct FetchResult<ResultType> {
    public var objects: [ResultType] = []
    public var error: Error? = nil
}

@MainActor
public class FetchController3<ResultType>: NSObject, @preconcurrency NSFetchedResultsControllerDelegate, ObservableObject where ResultType: NSManagedObject {
    
    init(changesAnimation: Animation? = nil) {
        self.changesAnimation = changesAnimation
        super.init()
    }
    
    public var changesAnimation: Animation?
    private var fetchedResultsController: NSFetchedResultsController<ResultType>?
    
    public private(set) var result = FetchResult<ResultType>()
    
    public func update(fetchRequest: NSFetchRequest<ResultType>, managedObjectContext: NSManagedObjectContext) {
        
        if let frc = fetchedResultsController {
            if frc.managedObjectContext != managedObjectContext {
                frc.delegate = nil
                fetchedResultsController = nil
            }
            
            if frc.fetchRequest != fetchRequest {
                frc.delegate = nil
                fetchedResultsController = nil
            }
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
            fetchedResultsController = frc
            
            do {
                try frc.performFetch()
                result.error = nil
                result.objects = fetchedResultsController?.fetchedObjects ?? []
            }
            catch {
                result.error = error // and keep old objects
            }
        }
    }
    
    private let convenienceFetchRequest: NSFetchRequest<ResultType> = NSFetchRequest<ResultType>(entityName: ResultType.entity().name ?? "\(ResultType.self)")
    // designed to prevent unnecessary converts to NSSortDescriptor
    private var cachedModernSortDescriptors: [SortDescriptor<ResultType>]?
    
    public func update(sortDescriptors: [SortDescriptor<ResultType>], nsPredicate: NSPredicate? = nil, managedObjectContext: NSManagedObjectContext) {
        if cachedModernSortDescriptors != sortDescriptors {
            convenienceFetchRequest.sortDescriptors = sortDescriptors.map { NSSortDescriptor($0) }
            cachedModernSortDescriptors = sortDescriptors
        }
        if convenienceFetchRequest.predicate != nsPredicate {
            convenienceFetchRequest.predicate = nsPredicate
        }
        update(fetchRequest: convenienceFetchRequest, managedObjectContext: managedObjectContext)
    }
    
    public func update(nsSortDescriptors: [NSSortDescriptor], nsPredicate: NSPredicate? = nil, managedObjectContext: NSManagedObjectContext) {
        if convenienceFetchRequest.sortDescriptors != nsSortDescriptors {
            convenienceFetchRequest.sortDescriptors = nsSortDescriptors
            cachedModernSortDescriptors = nil //nsSortDescriptors.compactMap { SortDescriptor($0, comparing: ResultType.self) }
        }
        if convenienceFetchRequest.predicate != nsPredicate {
            convenienceFetchRequest.predicate = nsPredicate
        }
        update(fetchRequest: convenienceFetchRequest, managedObjectContext: managedObjectContext)
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
        
        guard let fetchedObjects = controller.fetchedObjects as? [ResultType] else { return }
        
        withAnimation(changesAnimation) {
            objectWillChange.send()
            result.objects = fetchedObjects
        }
    }
    
}
