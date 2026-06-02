import Foundation
import SwiftUI
import CoreData
import Combine

@propertyWrapper
public struct FetchRequest2<ResultType>: DynamicProperty where ResultType: NSManagedObject {
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    @StateObject private var result = FetchResult2<ResultType>()
    
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
    
    public var wrappedValue: FetchResult2<ResultType> {
        switch config {
            case .manual(let request):
                result.fetchRequest = request
            case .modern(let sort, let predicate):
                result.sortDescriptors = sort
                result.nsPredicate = predicate
            case .convenience(let sort, let predicate):
                result.nsSortDescriptors = sort
                result.nsPredicate = predicate
        }
        result.managedObjectContext = managedObjectContext
        result.changesAnimation = changesAnimation
        return result
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

@Observable
@MainActor
public class FetchResult2<ResultType>: NSObject, @preconcurrency NSFetchedResultsControllerDelegate, ObservableObject where ResultType: NSManagedObject {
    public var changesAnimation: Animation?
    
    init(changesAnimation: Animation? = nil) {
        let fr = NSFetchRequest<ResultType>(entityName: ResultType.entity().name ?? "\(ResultType.self)")
        self._fetchRequest = fr
        self.changesAnimation = changesAnimation
        super.init()
    }
    
    public var managedObjectContext: NSManagedObjectContext? {
        didSet {
            if managedObjectContext != oldValue {
                _fetchedResultsController = nil
            }
        }
    }
    
    // Stored request with copying semantics; we expose a computed property to hook willSet/didSet behavior
    private var _fetchRequest: NSFetchRequest<ResultType> {
        didSet {
            _fetchedResultsController = nil
        }
    }
    
    //@NSCopying var not working in @Observable
    public var fetchRequest: NSFetchRequest<ResultType> {
        get {
            _fetchRequest
        }
        set {
            if newValue != _fetchRequest {
                _fetchRequest = newValue.copy() as! NSFetchRequest<ResultType>
            }
        }
    }
    
    public var nsSortDescriptors: [NSSortDescriptor]? {
        get {
            _fetchRequest.sortDescriptors
        }
        set {
            let fr = _fetchRequest
            if newValue != fr.sortDescriptors {
                fr.sortDescriptors = newValue
                _fetchRequest = fr
                _sortDescriptors = nil
            }
        }
    }
    
    public var nsPredicate: NSPredicate? {
        get {
            _fetchRequest.predicate
        }
        set {
            let fr = _fetchRequest
            if newValue != fr.predicate {
                fr.predicate = newValue
                _fetchRequest = fr
            }
        }
    }
    
    public var _sortDescriptors: [SortDescriptor<ResultType>]?
    public var sortDescriptors: [SortDescriptor<ResultType>] {
        get {
            if let _sortDescriptors { return _sortDescriptors }
            let sd = fetchRequest.sortDescriptors?.compactMap { SortDescriptor($0, comparing: ResultType.self) } ?? []
            _sortDescriptors = sd
            return sd
        }
        set {
            if _sortDescriptors != newValue {
                _sortDescriptors = newValue
                nsSortDescriptors = newValue.map { NSSortDescriptor($0) }
            }
        }
    }
    
    private var _fetchedResultsController: NSFetchedResultsController<ResultType>? {
        didSet {
            oldValue?.delegate = nil
            _fetchedResultsController?.delegate = self
            _objects = nil
        }
    }
    
    private var fetchedResultsController: NSFetchedResultsController<ResultType> {
        get throws {
            if let _fetchedResultsController { return _fetchedResultsController }
            guard let managedObjectContext else {
                throw FetchError.missingContext
            }
            if fetchRequest.sortDescriptors?.isEmpty ?? true {
                throw FetchError.missingSortDescriptors
            }
            let frc = NSFetchedResultsController<ResultType>(
                fetchRequest: fetchRequest,
                managedObjectContext: managedObjectContext,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
            _fetchedResultsController = frc
            
            try frc.performFetch()
            return frc
        }
    }
    
    
    private var _objects: [ResultType]?
    public var objects: [ResultType] {
        if let _objects { return _objects }
        let fetchedObjects: [ResultType]
        do {
            fetchedObjects = try fetchedResultsController.fetchedObjects ?? []
            lastError = nil
        }
        catch {
            fetchedObjects = []
            lastError = error as? FetchError ?? FetchError.fetchFailure(error) // and keep old objects
        }
        _objects = fetchedObjects
        return fetchedObjects
    }

    public var lastError: Error? = nil
    
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
            _objects = fetchedObjects
        }
    }
    
}
