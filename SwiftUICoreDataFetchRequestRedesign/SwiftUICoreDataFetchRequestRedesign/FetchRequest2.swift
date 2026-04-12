//
//  FetchRequest2.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI
import CoreData
import Combine

@propertyWrapper
public struct FetchRequest2<ResultType>: DynamicProperty where ResultType: NSManagedObject {
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    @StateObject private var controller = FetchController2<ResultType>()
    
    private let config: FetchConfig
    private let changesAnimation: Animation?
    
    // Internal representation to avoid 'if let' branching in wrappedValue
    private enum FetchConfig {
        case manual(NSFetchRequest<ResultType>)
        //case modern(sort: [SortDescriptor<ResultType>], predicate: NSPredicate?)
        case convenience(sort: [NSSortDescriptor], predicate: NSPredicate?)
    }
    
    // Modern SortDescriptors (SwiftUI standard)
    //    public init(sortDescriptors: [SortDescriptor<ResultType>], nsPredicate: NSPredicate? = nil, changesAnimation: Animation? = nil) {
    //        self.config = .modern(sort: sortDescriptors, predicate: nsPredicate)
    //        self.changesAnimation = changesAnimation
    //    }
    
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
    
    public var wrappedValue: FetchResult<ResultType> {
        controller.withoutPublishing { // prevents publishing changes from updates not allowed error
            switch config {
                case .manual(let request):
                    if controller.fetchRequest !== request { // we need to check the reference since we are alreayd monitoring its properties
                        controller.fetchRequest = request
                    }
                    //case .modern(let sort, let predicate):
                    //  if controller.fetchRequest.sortDescriptors != sort {
                    //      controller.fetchRequest.sortDescriptors = sort
                    //  }
                    //  if controller.fetchRequest.predicate != predicate {
                    //      controller.fetchRequest.predicate = predicate
                    //  }
                case .convenience(let sort, let predicate):
                    if controller.fetchRequest.sortDescriptors != sort {
                        let p = controller.fetchRequest.copy() as! NSFetchRequest<ResultType>
                        p.sortDescriptors = sort
                        controller.fetchRequest = p
                    }
                    if controller.fetchRequest.predicate != predicate {
                        controller.fetchRequest.predicate = predicate
                       
                    }
            }
            if controller.managedObjectContext != managedObjectContext {
                controller.managedObjectContext = managedObjectContext
            }
            if controller.changesAnimation != changesAnimation {
                controller.changesAnimation = changesAnimation
            }
        }
        return controller.result
    }
    
    public func update() {
       
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
    //public var objectWillChange = PassthroughSubject<Void, Never>()
    public var changesAnimation: Animation?
    
    init(fetchRequest: NSFetchRequest<ResultType>? = nil, changesAnimation: Animation? = nil) {
        self.fetchRequest = fetchRequest ?? NSFetchRequest<ResultType>(entityName: ResultType.entity().name ?? "\(ResultType.self)")
        self.changesAnimation = changesAnimation
        super.init()
        setupPropertyObservations()
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
            _fetchedResultsController = nil
        }
    }
    
    private var propertyObservations: [NSKeyValueObservation] = []
    
    private var _needsUpdatedResult: Bool = true
    private func setNeedsUpdatedResult() {
        if !isPublishingDisabled {
            objectWillChange.send()   
        }
        _needsUpdatedResult = true
    }
    
    private func setupPropertyObservations() {
        // Clear old observers so we don't leak or get double-notifications
        propertyObservations.removeAll()
        
        // Observe internal changes to the CURRENT request object
        let pObs = fetchRequest.observe(\.predicate, options: [.new]) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.setNeedsUpdatedResult()
            }
        }
        
        let sObs = fetchRequest.observe(\.sortDescriptors, options: [.new]) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.setNeedsUpdatedResult()
            }
        }
        
        propertyObservations = [pObs, sObs]
        
    }
    
    public var fetchRequest: NSFetchRequest<ResultType> {
        willSet {
            if !isPublishingDisabled {
                objectWillChange.send()
            }
        }
        didSet {
            _fetchedResultsController = nil
            setupPropertyObservations()
        }
    }
   
    private var _fetchedResultsController: NSFetchedResultsController<ResultType>? {
        didSet {
            oldValue?.delegate = nil
            _fetchedResultsController?.delegate = self
            _needsUpdatedResult = true
        }
    }
    private var fetchedResultsController: NSFetchedResultsController<ResultType>  {
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
            return frc
        }
    }
    
    private var _result = FetchResult<ResultType>()
    public var result: FetchResult<ResultType> {
        do {
            let frc = try fetchedResultsController
            if _needsUpdatedResult {
                _needsUpdatedResult = false
                try frc.performFetch()
                _result.error = nil
                _result.objects = frc.fetchedObjects ?? []
            }
        }
        catch {
            _result.error = error as? FetchError ?? FetchError.fetchFailure(error) // and keep old objects
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
