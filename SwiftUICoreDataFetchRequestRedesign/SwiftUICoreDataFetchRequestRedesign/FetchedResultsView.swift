//
//  Fetch.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 16/10/2026.
//

import CoreData
import SwiftUI
import Combine

public protocol FetchRequestConfiguring<ResultType>: Equatable, Sendable {
    associatedtype ResultType: NSManagedObject
    func configure(request: NSFetchRequest<ResultType>)
}

@MainActor
public struct ModernSortedFetch<ResultType: NSManagedObject>: @preconcurrency FetchRequestConfiguring {
    
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
public struct FetchedResultsView<F, Content> where F: FetchRequestConfiguring {

    private let fetch: F
    private var content: ([F.ResultType], Error?) -> Content
    
    @State private var observer = FetchObserver<F>()
    
    @Environment(\.managedObjectContext) private var viewContext
    
    public init(
        _ fetch: F,
        @ViewBuilder content: @escaping ([F.ResultType], Error?) -> Content
    ) {
        self.fetch = fetch
        self.content = content
    }
}

// extension allows skipping the return in body
extension FetchedResultsView: View where Content: View {
    public var body: some View {
        let _ = observer.update(managedObjectContext: viewContext, fetch: fetch)
        content(observer.results, observer.error)
    }
}

@MainActor
@Observable
class FetchObserver<F: FetchRequestConfiguring>: NSObject, @preconcurrency NSFetchedResultsControllerDelegate {
    
    var error: Error?
    var results: [F.ResultType] = []
    
    @ObservationIgnored
    public var lastFetch: F?
    
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
    public func update(managedObjectContext: NSManagedObjectContext, fetch: F) {
        let activeFRC: NSFetchedResultsController<F.ResultType>
        
        if let existingFRC = fetchedResultsController,
           existingFRC.managedObjectContext == managedObjectContext {
            if fetch == lastFetch {
                return
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
        
        do {
            try activeFRC.performFetch()
            _error = nil
        } catch {
            _error = error
        }
        _results = activeFRC.fetchedObjects ?? []
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
        
        // Bump revision to force SwiftUI to re-evaluate body when background deletes/inserts happen
        error = nil
        results = controller.fetchedObjects as? [F.ResultType] ?? []
    }
    
    deinit {
        print("deinit")
    }
}
