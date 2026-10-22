//
//  FetchObserver.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 20/10/2026.
//
import SwiftUI
import CoreData

public protocol NSFetchRequestRepresentable<ResultType>: Equatable, Sendable {
    associatedtype ResultType: NSManagedObject
    
    func makeNSFetchRequest() -> NSFetchRequest<ResultType>
    func updateNSFetchRequest(_ request: NSFetchRequest<ResultType>)
}

//@MainActor
//public struct ModernSortedFetch<ResultType: NSManagedObject>: @preconcurrency SortDescriptorConfiguring {
//    
//    public var sortDescriptors: [SortDescriptor<ResultType>]
//    
//    public init(sortDescriptors: [SortDescriptor<ResultType>] = []) {
//        self.sortDescriptors = sortDescriptors
//    }
//    
//    public func updateNSFetchRequest(_ request: NSFetchRequest<ResultType>) {
//        request.sortDescriptors = sortDescriptors.map { NSSortDescriptor($0) }
//    }
//}
//
//public extension ModernSortedFetch {
//    /// Creates a fetch configuration with the specified Swift `SortDescriptor`s.
//    static func sortDescriptors(_ descriptors: [SortDescriptor<ResultType>]) -> ModernSortedFetch {
//        ModernSortedFetch(sortDescriptors: descriptors)
//    }
//    
//    /// Convenience helper for a single sort descriptor.
//    static func sorted(by keyPath: KeyPath<ResultType, some Comparable> & Sendable, order: SortOrder = .forward) -> ModernSortedFetch {
//        ModernSortedFetch(sortDescriptors: [SortDescriptor(keyPath, order: order)])
//    }
//}

// cant because when fetch fails they lose the objects
//public struct FetchedResults2<ResultType: NSManagedObject>: RandomAccessCollection {
//    let frc: NSFetchedResultsController<ResultType>
//    
//    // MARK: - Collection Conformance
//    
//    public var startIndex: Int {
//        return 0
//    }
//    
//    public var endIndex: Int {
//        return frc.fetchedObjects?.count ?? 0
//    }
//    
//    public subscript(position: Int) -> ResultType {
//        guard let objects = frc.fetchedObjects else {
//            fatalError("Attempted to access index \(position) on unfetched NSFetchedResultsController.")
//        }
//        return objects[position]
//    }
//    
//    public func index(after i: Int) -> Int {
//        return i + 1
//    }
//    
//    public func index(before i: Int) -> Int {
//        return i - 1
//    }
//}

@MainActor
@Observable
public final class FetchedResultsObserver<F: NSFetchRequestRepresentable>: NSObject, @preconcurrency NSFetchedResultsControllerDelegate {
    
    
    public typealias State = (results: [F.ResultType], error: Error?)
    //var error: Error?
    //var results: [F.ResultType] = []
    
    private var state: State = ([], nil)
    
    @ObservationIgnored
    private var lastRepresentable: F?
    
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
    public func update(managedObjectContext: NSManagedObjectContext, representable: F) -> State {
        let activeFRC: NSFetchedResultsController<F.ResultType>
        
        if let existingFRC = fetchedResultsController,
           existingFRC.managedObjectContext == managedObjectContext {
            if representable == lastRepresentable {
                return state // this sets up observation
            }
            activeFRC = existingFRC
            representable.updateNSFetchRequest(existingFRC.fetchRequest)
        } else {
            let fr = representable.makeNSFetchRequest()
            representable.updateNSFetchRequest(fr)
            activeFRC = NSFetchedResultsController(
                fetchRequest: fr,
                managedObjectContext: managedObjectContext,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
            fetchedResultsController = activeFRC
        }
        
        lastRepresentable = representable
      
        
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
