

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
        controller.disablePublishing = true
        switch config {
            case .manual(let request):
                controller.fetchRequest = request
            case .modern(let sort, let predicate):
                controller.sortDescriptors = sort
                controller.nsPredicate = predicate
            case .legacy(let sort, let predicate):
                controller.nsSortDescriptors = sort
                controller.nsPredicate = predicate
        }
        controller.managedObjectContext = managedObjectContext
        controller.changesAnimation = changesAnimation
        controller.disablePublishing = false
    }
}

enum FetchError: LocalizedError {
    case missingContext
    case fetchFailure(Error)
    
    var errorDescription: String? {
        switch self {
            case .missingContext:
                return "The operation couldn't be completed because the managedObjectContext is null."
            case .fetchFailure(let error):
                return error.localizedDescription
        }
    }
}

@MainActor
public class FetchController3<ResultType>: NSObject, @preconcurrency NSFetchedResultsControllerDelegate, ObservableObject where ResultType: NSManagedObject {
    
    public var changesAnimation: Animation?
    private var fetchedResultsController: NSFetchedResultsController<ResultType>? {
        didSet {
            oldValue?.delegate = nil
            fetchedResultsController?.delegate = self
        }
    }
    
    private let convenienceFetchRequest: NSFetchRequest<ResultType> = NSFetchRequest<ResultType>(entityName: ResultType.entity().name ?? "\(ResultType.self)")
    
    private var _result = FetchResult<ResultType>()
    public var result: FetchResult<ResultType> {
        
        // get the fetch request we are using
        let fr: NSFetchRequest<ResultType>
        if let fetchRequest {
            fr = fetchRequest
        }
        else {
            fr = convenienceFetchRequest
        }
        
        // check if anything has changed requiring a new frc
        if let frc = fetchedResultsController {
            if frc.managedObjectContext != managedObjectContext {
                fetchedResultsController = nil
            }
            if frc.fetchRequest != fr {
                fetchedResultsController = nil
            }
        }

        // make new frc if necessary
        if fetchedResultsController == nil {
            if let managedObjectContext {
                // we copy the request so we can compare agains the updated convenienceFetchRequest next time.
                let frc = NSFetchedResultsController<ResultType>(
                    fetchRequest: fr.copy() as! NSFetchRequest<ResultType>,
                    managedObjectContext: managedObjectContext,
                    sectionNameKeyPath: nil,
                    cacheName: nil
                )
                fetchedResultsController = frc
                
                do {
                    try frc.performFetch()
                    _result.error = nil
                    _result.objects = frc.fetchedObjects ?? []
                }
                catch {
                    _result.error = FetchError.fetchFailure(error) // and keep old objects
                }
            } else {
                _result.error = FetchError.missingContext
            }
        }
        return _result
    }
    
    
    init(nsSortDescriptors: [NSSortDescriptor] = [], nsPredicate: NSPredicate? = nil) {
        super.init()
        self.nsPredicate = nsPredicate
        self.nsSortDescriptors = nsSortDescriptors
    }
    
    var nsPredicate: NSPredicate? {
        set {
            fetchRequest = nil
            convenienceFetchRequest.predicate = newValue
        }
        get {
            convenienceFetchRequest.predicate
        }
    }
    
    var nsSortDescriptors: [NSSortDescriptor]? {
        set {
            sortDescriptors = nil
            convenienceFetchRequest.sortDescriptors = newValue
        }
        get {
            convenienceFetchRequest.sortDescriptors
        }
    }
    
    var sortDescriptors: [SortDescriptor<ResultType>]? {
        willSet {
            fetchRequest = nil
        }
        didSet {
            if sortDescriptors != oldValue {
                convenienceFetchRequest.sortDescriptors = sortDescriptors?.map { NSSortDescriptor($0) }
            }
        }
    }
    
    var disablePublishing = false
    
    var managedObjectContext: NSManagedObjectContext? {
        willSet {
            if !disablePublishing {
                objectWillChange.send()
            }
        }
    }
    
    var fetchRequest: NSFetchRequest<ResultType>? {
        willSet {
            if !disablePublishing {
                objectWillChange.send()
            }
        }
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
            if !disablePublishing { // bit of an odd case
                objectWillChange.send()
            }
            _result.objects = fetchedObjects
        }
    }
    
}
