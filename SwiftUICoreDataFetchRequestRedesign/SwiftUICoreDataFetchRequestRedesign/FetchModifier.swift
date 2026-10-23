//
//  FetchModifier.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 22/10/2026.
//
import SwiftUI
import CoreData

public protocol NSFetchRequestRepresentable<ResultType>: Equatable, Sendable {
    associatedtype ResultType: NSManagedObject
    
    func makeNSFetchRequest() -> NSFetchRequest<ResultType>
}

public struct FetchModifier<F: NSFetchRequestRepresentable>: ViewModifier {
    
    public let representable: F
    public let handleResults: (FetchedResults2<F.ResultType>) -> Void
    public let onError: (Error) -> Void
    
    @Environment(\.managedObjectContext) private var context
    
    private struct Trigger: Equatable {
        let context: NSManagedObjectContext
        let representable: F
    }
    
    @State private var observer = ResultsObserver<F.ResultType>()
    
    public func body(content: Content) -> some View {
        content
            .onChange(of: observer.version) {
                handleResults(FetchedResults2(results: observer.frc?.fetchedObjects ?? []))
            }
            .onChange(of: Trigger(context: context, representable: representable), initial: true) { old, new in
                let fr = representable.makeNSFetchRequest()
                do {
                    let frc = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: new.context, sectionNameKeyPath: nil, cacheName: nil)
                    try frc.performFetch()
                    frc.delegate = observer
                    observer.frc = frc
                    handleResults(FetchedResults2(results: frc.fetchedObjects ?? []))
                }catch {
                    onError(error)
                }
            }
    }
}

// MARK: - RandomAccessCollection Conformance via FRC APIs

public struct FetchedResults2<ResultType:NSManagedObject>: nonisolated RandomAccessCollection, Equatable {
    
    let results: [ResultType]
    
    init(results: [ResultType] = []) {
        self.results = results
    }
    
    public var startIndex: Int {
       // let _ = fetchObserver?.changeCount
        //return 0
        return results.startIndex
    }
    
    public var endIndex: Int {
       // let _ = fetchObserver?.changeCount
        //let x = frc?.sections?.first?.numberOfObjects ?? 0
        return results.endIndex
    }
    
    public subscript(position: Int) -> ResultType {
     //   let _ = fetchObserver?.changeCount
//        guard let object =  frc?.object(at: IndexPath(item: position, section: 0)) else {
//            fatalError("Index \(position) out of bounds for FetchedResults2 (Count: \(endIndex))")
//        }
//        return object
        results[position]
    }
    
    public func index(after i: Int) -> Int {
        //i + 1
        results.index(after: i)
    }
    
    public func index(before i: Int) -> Int {
        //i - 1
        results.index(before: i)
    }
}

@MainActor
@Observable
public class ResultsObserver<ResultType: NSManagedObject>: NSObject, @preconcurrency NSFetchedResultsControllerDelegate {
    
    private(set) var version = 0
    
    @ObservationIgnored
    var frc: NSFetchedResultsController<ResultType>? {
        didSet {
            oldValue?.delegate = nil
            frc?.delegate = self
        }
    }
    
    override init() {
        super.init()
        print("ResultsObserver init")
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
        
        version += 1
    }
    
    
    deinit {
        print("ResultsObserver deinit")
    }
}

public extension View {
    func fetch<F: NSFetchRequestRepresentable>(
        _ representable: F,
        handleResults: @escaping (FetchedResults2<F.ResultType>) -> Void,
        onError: @escaping (Error) -> Void,
    ) -> some View {
        modifier(FetchModifier(representable: representable, handleResults: handleResults, onError: onError))
    }
}
