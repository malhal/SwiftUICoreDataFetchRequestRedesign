import Foundation
import SwiftUI
import CoreData
import Combine

@propertyWrapper
public struct StaticFetchRequest<ResultType>: DynamicProperty where ResultType: NSManagedObject {
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    @StateObject private var fetcher = FetchUpdates<ResultType>()
    
    private let config: FetchUpdates<ResultType>.FetchConfiguration
    private let changesAnimation: Animation?
    
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
    
    // 💡 Pure, beautiful implementation alignment
    public var wrappedValue: FetchResult2<ResultType> {
        fetcher.changesAnimation = changesAnimation
        return fetcher.latestResult(for: config, context: managedObjectContext)
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
public class FetchUpdates<ResultType>: NSObject, @preconcurrency NSFetchedResultsControllerDelegate, ObservableObject where ResultType: NSManagedObject {
    
    @ObservationIgnored
    public var changesAnimation: Animation?
    
    init(changesAnimation: Animation? = nil) {
        self.changesAnimation = changesAnimation
        super.init()
    }
    
    // Internal representation to avoid 'if let' branching in wrappedValue
    public enum FetchConfiguration: Equatable {
        case manual(NSFetchRequest<ResultType>)
        case modern(sort: [SortDescriptor<ResultType>], predicate: NSPredicate? = nil)
        case convenience(sort: [NSSortDescriptor], predicate: NSPredicate? = nil)
    }
    
    // 1. Keep a single, reusable instance cached in private storage to avoid allocation churn
    @ObservationIgnored
    private let scratchpadRequest = NSFetchRequest<ResultType>(entityName: ResultType.entity().name ?? "\(ResultType.self)")
    
    @ObservationIgnored
    private var cachedSortDescriptors: [SortDescriptor<ResultType>]?
    
    /// The single unified entry point. Mutates the scratchpad based on the config variant
    /// and ensures optimal structural caching paths.
    public func latestResult(
        for config: FetchConfiguration,
        context: NSManagedObjectContext
    ) -> FetchResult2<ResultType> {
        
        // 2. Map configuration states directly to our reusable scratchpadRequest reference
        switch config {
            case .manual(let rawRequest):
                // Pass-through execution for custom requests
                return executeFetch(with: rawRequest, context: context)
                
            case .modern(let sort, let predicate):
                if cachedSortDescriptors != sort {
                    cachedSortDescriptors = sort
                    scratchpadRequest.sortDescriptors = sort.map { NSSortDescriptor($0) }
                }
                scratchpadRequest.predicate = predicate
                return executeFetch(with: scratchpadRequest, context: context)
                
            case .convenience(let sort, let predicate):
                cachedSortDescriptors = nil // Invalidate modern cache token safely
                scratchpadRequest.sortDescriptors = sort
                scratchpadRequest.predicate = predicate
                return executeFetch(with: scratchpadRequest, context: context)
        }
    }
    
    // MARK: - Core Fetch Mechanics
    
    private func executeFetch(with incomingRequest: NSFetchRequest<ResultType>, context: NSManagedObjectContext) -> FetchResult2<ResultType> {
        // Validate sorting exists
        guard incomingRequest.sortDescriptors?.isEmpty == false else {
            lastResult.lastError = FetchError.missingSortDescriptors
            return lastResult
        }
        
        // Check if the FRC can be reused
        if let currentFRC = frc,
           currentFRC.managedObjectContext === context,
           currentFRC.fetchRequest == incomingRequest {
            return lastResult
        }
        
        // Configuration drifted: Rebuild a frozen copy for the new FRC tracking instance
        let safeRequestCopy = incomingRequest.copy() as! NSFetchRequest<ResultType>
        let newFRC = NSFetchedResultsController(
            fetchRequest: safeRequestCopy,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        self.frc = newFRC
        
        do {
            try newFRC.performFetch()
            lastResult.objects = newFRC.fetchedObjects ?? []
            lastResult.lastError = nil
        } catch {
            lastResult.lastError = FetchError.fetchFailure(error)
        }
        
        return lastResult
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
