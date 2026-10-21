//
//  FetchObserver.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 20/10/2026.
//
import SwiftUI
import CoreData

public protocol FetchRequestConfiguring<ResultType>: Equatable, Sendable {
    associatedtype ResultType: NSManagedObject
    func configure(request: NSFetchRequest<ResultType>)
}

@MainActor
public struct ModernSortedFetch<ResultType: NSManagedObject>: @preconcurrency SortDescriptorConfiguring {
    
    public var sortDescriptors: [SortDescriptor<ResultType>]
    
    public init(sortDescriptors: [SortDescriptor<ResultType>] = []) {
        self.sortDescriptors = sortDescriptors
    }
    
    public func configure(request: NSFetchRequest<ResultType>) {
        request.sortDescriptors = sortDescriptors.map { NSSortDescriptor($0) }
    }
}

public extension ModernSortedFetch {
    /// Creates a fetch configuration with the specified Swift `SortDescriptor`s.
    static func sortDescriptors(_ descriptors: [SortDescriptor<ResultType>]) -> ModernSortedFetch {
        ModernSortedFetch(sortDescriptors: descriptors)
    }
    
    /// Convenience helper for a single sort descriptor.
    static func sorted(by keyPath: KeyPath<ResultType, some Comparable> & Sendable, order: SortOrder = .forward) -> ModernSortedFetch {
        ModernSortedFetch(sortDescriptors: [SortDescriptor(keyPath, order: order)])
    }
}

@MainActor
@Observable
class FetchObserver<F: FetchRequestConfiguring>: NSObject, @preconcurrency NSFetchedResultsControllerDelegate {
    typealias State = (results: [F.ResultType], error: Error?)
    //var error: Error?
    //var results: [F.ResultType] = []
    
    private var state: State = ([], nil)
    
    @ObservationIgnored
    private var lastFetch: F?
    
    @ObservationIgnored
    var fetchedResultsController: NSFetchedResultsController<F.ResultType>? {
        didSet {
            oldValue?.delegate = nil
            fetchedResultsController?.delegate = self
        }
    }
    
    @ObservationIgnored
    private var hasStructuralChanges = false
    
    override init() {
        super.init()
    }
    
    // if change context should we clear the results regardless if there is an error?
    public func update(managedObjectContext: NSManagedObjectContext, fetch: F) -> State {
        let activeFRC: NSFetchedResultsController<F.ResultType>
        
        if let existingFRC = fetchedResultsController,
           existingFRC.managedObjectContext == managedObjectContext {
            if fetch == lastFetch {
                return state // this sets up observation
            }
            activeFRC = existingFRC
        } else {
            let fr = NSFetchRequest<F.ResultType>(entityName: F.ResultType.entity().name ?? "\(F.ResultType.self)")
            fr.sortDescriptors = []
            activeFRC = NSFetchedResultsController(
                fetchRequest: fr,
                managedObjectContext: managedObjectContext,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
            fetchedResultsController = activeFRC
        }
        
        lastFetch = fetch
        fetch.configure(request: activeFRC.fetchRequest)
        
        // silently update the observable property
        do {
            try activeFRC.performFetch()
            _state.error = nil
        } catch {
            _state.error = error
        }
        _state.results = activeFRC.fetchedObjects ?? []
        
        return state // this get sets up observation
    }
    
    public func controller(_ controller: NSFetchedResultsController<any NSFetchRequestResult>,
                           didChange anObject: Any,
                           at indexPath: IndexPath?,
                           for type: NSFetchedResultsChangeType,
                           newIndexPath: IndexPath?) {
        if type != .update {
            hasStructuralChanges = true
        }
    }
    
    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        guard hasStructuralChanges else { return }
        hasStructuralChanges = false
        
        // set and notify
        state = (controller.fetchedObjects as? [F.ResultType] ?? [], nil)
    }
    
    deinit {
        print("deinit")
    }
}
