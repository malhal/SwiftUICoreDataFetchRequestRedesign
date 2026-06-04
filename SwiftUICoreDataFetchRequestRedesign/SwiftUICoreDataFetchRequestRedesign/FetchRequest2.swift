import Foundation
import SwiftUI
import CoreData
import Combine

@propertyWrapper
public struct FetchRequest2<ResultType>: DynamicProperty where ResultType: NSManagedObject {
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    @StateObject private var controller = FetchController<ResultType>()
    
    private let config: FetchConfig
    private let changesAnimation: Animation?
    
    // Internal representation to avoid 'if let' branching in wrappedValue
    private enum FetchConfig {
        case manual(NSFetchRequest<ResultType>)
        case modern(sort: [SortDescriptor<ResultType>], predicate: NSPredicate?)
        case convenience(sort: [NSSortDescriptor], predicate: NSPredicate?)
    }
    
    // Modern SortDescriptors (SwiftUI standard)
        public init(sortDescriptors: [SortDescriptor<ResultType>], nsPredicate: NSPredicate? = nil, changesAnimation: Animation? = nil) {
            self.config = .modern(sort: sortDescriptors, predicate: nsPredicate)
            self.changesAnimation = changesAnimation
        }
    
    // Legacy NSSortDescriptors
    public init(nsSortDescriptors: [NSSortDescriptor], nsPredicate: NSPredicate? = nil, changesAnimation: Animation? = nil) {
        self.config = .convenience(sort: nsSortDescriptors, predicate: nsPredicate)
        self.changesAnimation = changesAnimation
    }
    
    // Existing NSFetchRequest
    public init(fetchRequest: NSFetchRequest<ResultType>, changesAnimation: Animation? = nil) {
        self.config = .manual(fetchRequest)
        self.changesAnimation = changesAnimation
    }
    
    public var wrappedValue: FetchResult2<ResultType> = .init()
    
    public mutating func update() {
        switch config {
            case .manual(let request):
                wrappedValue = controller.result(for: request, context: managedObjectContext, changesAnimation: changesAnimation)
            case .modern(let sort, let predicate):
                wrappedValue = controller.result(sortDescriptors: sort, predicate: predicate, context: managedObjectContext, changesAnimation: changesAnimation)
            case .convenience(let sort, let predicate):
                wrappedValue = controller.result(nsSortDescriptors: sort, predicate: predicate, context: managedObjectContext, changesAnimation: changesAnimation)
        }
    }
    
}

public enum FetchError: LocalizedError {
    case missingContext
    case missingSortDescriptors
    case fetchFailure(Error)
    
    public var errorDescription: String? {
        switch self {
            case .missingSortDescriptors:
                return "The operation couldn't be completed because the sortDescriptors is empty."
            case .missingContext:
                return "The operation couldn't be completed because the managedObjectContext is null."
            case .fetchFailure(let error):
                return error.localizedDescription
        }
    }
}

public struct FetchResult2<ResultType> {
    var objects: [ResultType] = []
    var lastError: Error? = nil
}

@Observable
@MainActor
public class FetchController<ResultType>: NSObject, @preconcurrency NSFetchedResultsControllerDelegate, ObservableObject where ResultType: NSManagedObject {
    public var changesAnimation: Animation?
    
    override init() {
        super.init()
    }
    
    // 1. Keep a single, reusable instance cached in private storage to avoid allocation churn
    @ObservationIgnored
    private let scratchpadRequest = NSFetchRequest<ResultType>(entityName: ResultType.entity().name ?? "\(ResultType.self)")
    
    @ObservationIgnored
    private var cachedSortDescriptors: [SortDescriptor<ResultType>]?
    
    public func result(
        sortDescriptors: [SortDescriptor<ResultType>],
        predicate: NSPredicate? = nil,
        context: NSManagedObjectContext,
        changesAnimation: Animation? = nil
    ) -> FetchResult2<ResultType> {
        
        // 1. Check if the incoming Swift SortDescriptors match our single cache property
        if cachedSortDescriptors != sortDescriptors {
            // Cache miss: Update the tracking token and perform the translation exactly once
            cachedSortDescriptors = sortDescriptors
            scratchpadRequest.sortDescriptors = sortDescriptors.map { NSSortDescriptor($0) }
        }
        // High-performance path: If they matched, we don't touch scratchpadRequest.sortDescriptors at all!
        // It safely retains the previously mapped NSSortDescriptor objects from the last pass.
        
        // 2. Assign the incoming predicate to our single reference vehicle
        scratchpadRequest.predicate = predicate
        
        // 3. Forward to the primary engine pipeline for deep structural matching
        return result(for: scratchpadRequest, context: context, changesAnimation: changesAnimation)
    }
    
    /// Convenience entry point that updates a reusable scratchpad request to avoid object allocation churn.
    public func result(
        nsSortDescriptors: [NSSortDescriptor],
        predicate: NSPredicate? = nil,
        context: NSManagedObjectContext,
        changesAnimation: Animation? = nil
    ) -> FetchResult2<ResultType> {
        
        // required for the other result func with modern sorts
        cachedSortDescriptors = nil
        
        // 2. Mutate the properties of the single reusable instance inline
        scratchpadRequest.sortDescriptors = nsSortDescriptors
        scratchpadRequest.predicate = predicate
        
        // 3. Pass the mutated scratchpad into our main engine method.
        // If it matches the current FRC structurally, it returns the cached objects instantly.
        // If it changed, the main method handles creating a safe, frozen .copy() for the new FRC.
        return result(for: scratchpadRequest, context: context, changesAnimation: changesAnimation)
    }
    
    /// The single source-of-truth entry point for data generation.
    /// Evaluates incoming configurations against the current FRC state and guarantees live updates.
    public func result(for incomingRequest: NSFetchRequest<ResultType>,
                        context: NSManagedObjectContext,
                        changesAnimation: Animation? = nil
    ) -> FetchResult2<ResultType> {
        self.changesAnimation = changesAnimation
        
        // 1. Validate that we have proper sorting configuration before initializing Core Data pipelines
        guard incomingRequest.sortDescriptors?.isEmpty == false else {
            let error = FetchError.missingSortDescriptors
            self.lastResult.lastError = error
            return self.lastResult
        }
        
        // 2. Check if we can reuse the existing FRC instance (Structural Verification)
        if let currentFRC = frc,
           currentFRC.managedObjectContext === context,
           currentFRC.fetchRequest == incomingRequest { // Uses native structural deep-equality override
            
            // Context and query configuration match exactly; return current cached objects immediately
            return self.lastResult
        }
        
        // 3. Setup a distinct instance shell to safely prevent shared-pointer mutation blindspots
        let safeRequestCopy = incomingRequest.copy() as! NSFetchRequest<ResultType>
        
        // 4. Construct a brand new FRC container
        let newFRC = NSFetchedResultsController<ResultType>(
            fetchRequest: safeRequestCopy,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        self.frc = newFRC
        
        do {
            try newFRC.performFetch()
            let fetched = newFRC.fetchedObjects ?? []
            
            // Update our tracked reactive property
            self.lastResult.objects = fetched
            self.lastResult.lastError = nil
        } catch {
            let wrappedError = FetchError.fetchFailure(error)
            self.lastResult.lastError = wrappedError
        }
        
        return self.lastResult
    }
    
    // The single, clean reactive property that SwiftUI tracks for structural layout updates
    private var lastResult = FetchResult2<ResultType>()
    
    // Core Data Internal Engines (Hidden from the public API surface)
    private var frc: NSFetchedResultsController<ResultType>? {
        didSet {
            oldValue?.delegate = nil
            frc?.delegate = self
        }
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
        
        guard let fetchedObjects = controller.fetchedObjects as? [ResultType] else { return }
        
        withAnimation(changesAnimation) {
            self.lastResult.objects = fetchedObjects
        }
    }
    
}
