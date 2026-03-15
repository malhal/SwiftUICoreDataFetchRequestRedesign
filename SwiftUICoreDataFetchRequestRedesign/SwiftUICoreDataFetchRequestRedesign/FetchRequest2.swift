//
//  FetchRequest2.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI
import CoreData

@propertyWrapper
public struct FetchRequest2<ResultType>: DynamicProperty where ResultType: NSManagedObject {
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    @StateObject private var controller = FetchController2<ResultType>()
    
    private let config: FetchConfig
    private let changesAnimation: Animation?
    
    // Internal representation to avoid 'if let' branching in wrappedValue
    private enum FetchConfig {
        case manual(NSFetchRequest<ResultType>)
        case modern(sort: [SortDescriptor<ResultType>], predicate: NSPredicate?)
        case legacy(sort: [NSSortDescriptor], predicate: NSPredicate?)
    }
    
    // Modern SortDescriptors (SwiftUI standard)
    public init(sortDescriptors: [SortDescriptor<ResultType>], nsPredicate: NSPredicate? = nil, changesAnimation: Animation? = nil) {
        self.config = .modern(sort: sortDescriptors, predicate: nsPredicate)
        self.changesAnimation = changesAnimation
    }
    
    // Legacy NSSortDescriptors
    public init(nsSortDescriptors: [NSSortDescriptor], nsPredicate: NSPredicate? = nil, changesAnimation: Animation? = nil) {
        self.config = .legacy(sort: nsSortDescriptors, predicate: nsPredicate)
        self.changesAnimation = changesAnimation
    }
    
    // Existing NSFetchRequest
    public init(fetchRequest: NSFetchRequest<ResultType>, changesAnimation: Animation? = nil) {
        self.config = .manual(fetchRequest)
        self.changesAnimation = changesAnimation
    }
    
    public var wrappedValue: FetchResult<ResultType> {
        controller.withoutPublishing { // prevents publishing changes from updates not allowed error
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
        }
        return controller.result
    }
}

public enum FetchError: LocalizedError {
    case missingContext
    case fetchFailure(Error)
    
    public var errorDescription: String? {
        switch self {
            case .missingContext:
                return "The operation couldn't be completed because the managedObjectContext is null."
            case .fetchFailure(let error):
                return error.localizedDescription
        }
    }
}

@MainActor
public class FetchController2<ResultType>: NSObject, @preconcurrency NSFetchedResultsControllerDelegate, ObservableObject where ResultType: NSManagedObject {
    
    public var changesAnimation: Animation?
    
    init(changesAnimation: Animation? = nil) {
        self.changesAnimation = changesAnimation
        super.init()
    }
    
    convenience init(nsSortDescriptors: [NSSortDescriptor], nsPredicate: NSPredicate? = nil, changesAnimation: Animation? = nil) {
        self.init(changesAnimation: changesAnimation)
        self.nsSortDescriptors = nsSortDescriptors
        self.nsPredicate = nsPredicate
    }
    
    convenience init(sortDescriptors: [SortDescriptor<ResultType>], nsPredicate: NSPredicate? = nil, changesAnimation: Animation? = nil) {
        self.init(changesAnimation: changesAnimation)
        self.sortDescriptors = sortDescriptors
        self.nsPredicate = nsPredicate
    }
    
    convenience init(fetchRequest: NSFetchRequest<ResultType>, changesAnimation: Animation? = nil) {
        self.init(changesAnimation: changesAnimation)
        self.fetchRequest = fetchRequest
    }
    
    private let convenienceFetchRequest: NSFetchRequest<ResultType> = NSFetchRequest<ResultType>(entityName: ResultType.entity().name ?? "\(ResultType.self)")
    
    public var nsPredicate: NSPredicate? {
        set {
            fetchRequest = nil
            convenienceFetchRequest.predicate = newValue
        }
        get {
            convenienceFetchRequest.predicate
        }
    }
    
    public var nsSortDescriptors: [NSSortDescriptor]? {
        set {
            convenienceFetchRequest.sortDescriptors = newValue
        }
        get {
            convenienceFetchRequest.sortDescriptors
        }
    }
    
    public var sortDescriptors: [SortDescriptor<ResultType>] = [] {
        willSet {
            fetchRequest = nil
        }
        didSet {
            if sortDescriptors != oldValue {
                nsSortDescriptors = sortDescriptors.map { NSSortDescriptor($0) }
            }
        }
    }
    
    public var isPublishingDisabled = false
    
    public func withoutPublishing(_ work: () -> Void) {
        self.isPublishingDisabled = true
        defer { self.isPublishingDisabled = false }
        work()
    }
    
    public var managedObjectContext: NSManagedObjectContext? {
        willSet {
            if !isPublishingDisabled {
                objectWillChange.send()
            }
        }
    }
    
    public var fetchRequest: NSFetchRequest<ResultType>? {
        willSet {
            if !isPublishingDisabled {
                objectWillChange.send()
            }
        }
    }
    
    private var fetchedResultsController: NSFetchedResultsController<ResultType>? {
        didSet {
            oldValue?.delegate = nil
            fetchedResultsController?.delegate = self
        }
    }
    
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
            _result.objects = fetchedObjects
        }
    }
    
}
