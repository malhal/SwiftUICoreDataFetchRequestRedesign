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
        controller.result
    }
    
    public func update() {
        controller.withoutPublishing { // prevents publishing changes from updates not allowed error
            switch config {
                case .manual(let request):
                    if controller.fetchRequest != request {
                        controller.fetchRequest = request
                    }
                case .modern(let sort, let predicate):
                    if controller.sortDescriptors != sort {
                        controller.sortDescriptors = sort
                    }
                    if controller.nsPredicate != predicate {
                        controller.nsPredicate = predicate
                    }
                case .legacy(let sort, let predicate):
                    if controller.nsSortDescriptors != sort {
                        controller.nsSortDescriptors = sort
                    }
                    if controller.nsPredicate != predicate {
                        controller.nsPredicate = predicate
                    }
            }
            if controller.managedObjectContext != managedObjectContext {
                controller.managedObjectContext = managedObjectContext
            }
            if controller.changesAnimation != changesAnimation {
                controller.changesAnimation = changesAnimation
            }
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
    
    public var nsPredicate: NSPredicate? {
        set {
            let fr = fetchRequest
            fr.predicate = newValue
            fetchRequest = fr
        }
        get {
            fetchRequest.predicate
        }
    }
    
    public var nsSortDescriptors: [NSSortDescriptor]? {
        set {
            let fr = fetchRequest
            fr.sortDescriptors = newValue
            fetchRequest = fr
        }
        get {
            fetchRequest.sortDescriptors
        }
    }
    
    public var sortDescriptors: [SortDescriptor<ResultType>]? {
        didSet {
            nsSortDescriptors = sortDescriptors?.map { NSSortDescriptor($0) }
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
        didSet {
            fetchedResultsController = nil
        }
    }
    
    public var fetchRequest = NSFetchRequest<ResultType>(entityName: ResultType.entity().name ?? "\(ResultType.self)") {
        willSet {
            if !isPublishingDisabled {
                objectWillChange.send()
            }
        }
        didSet {
            fetchedResultsController = nil
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
        // make new frc if necessary
        if fetchedResultsController == nil {
            if let managedObjectContext {
                if fetchRequest.sortDescriptors?.isEmpty ?? true {
                    _result.error = FetchError.missingSortDescriptors
                }
                else {
                    // we copy the request so we can compare agains the updated convenienceFetchRequest next time.
                    let frc = NSFetchedResultsController<ResultType>(
                        fetchRequest: fetchRequest,
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
