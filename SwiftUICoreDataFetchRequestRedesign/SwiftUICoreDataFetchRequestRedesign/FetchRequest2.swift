//
//  StaticFetchRequest.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 8/11/2026.
//
import Foundation
import SwiftUI
import CoreData

public protocol NSFetchRequestRepresentable<ResultType>: Equatable {
    associatedtype ResultType: NSFetchRequestResult
    func makeNSFetchRequest() -> NSFetchRequest<ResultType>
}

struct DefaultFetchRequestRepresentable<ResultType: NSFetchRequestResult>: NSFetchRequestRepresentable {
    let entityName: String
    
    public func makeNSFetchRequest() -> NSFetchRequest<ResultType> {
        let fr = NSFetchRequest<ResultType>(entityName: entityName)
        fr.sortDescriptors = []
        return fr
    }
}

struct ModernSortFetchRequest<ResultType: NSManagedObject>: NSFetchRequestRepresentable {
    let sortDescriptors: [SortDescriptor<ResultType>]
    
    public func makeNSFetchRequest() -> NSFetchRequest<ResultType> {
        let fr = NSFetchRequest<ResultType>()
        fr.entity = ResultType.entity()
        fr.sortDescriptors = sortDescriptors.map { NSSortDescriptor($0) }
        return fr
    }
}

// 1. Type-erased wrapper that conforms to BOTH protocols and Equatable
public struct AnyFetchRequestRepresentable<ResultType: NSFetchRequestResult>: NSFetchRequestRepresentable {
    public typealias ResultType = ResultType
    
    private let base: any NSFetchRequestRepresentable<ResultType>
    
    public init<T: NSFetchRequestRepresentable<ResultType>>(_ base: T) {
        self.base = base
    }
    
    public func makeNSFetchRequest() -> NSFetchRequest<ResultType> {
        base.makeNSFetchRequest()
    }
    
    // Equatable conformance for SwiftUI's diffing engine (Zero closures used)
    public static func == (lhs: AnyFetchRequestRepresentable<ResultType>, rhs: AnyFetchRequestRepresentable<ResultType>) -> Bool {
        return areEqual(lhs.base, rhs.base)
    }
    
    private static func areEqual(_ lhs: any NSFetchRequestRepresentable<ResultType>, _ rhs: any NSFetchRequestRepresentable<ResultType>) -> Bool {
        func open<T: NSFetchRequestRepresentable<ResultType>>(_ lhsValue: T, _ rhsValue: any NSFetchRequestRepresentable<ResultType>) -> Bool {
            guard let rhsT = rhsValue as? T else { return false }
            return lhsValue == rhsT
        }
        return open(lhs, rhs)
    }
}

@MainActor
@propertyWrapper
public struct FetchRequest2<ResultType: NSFetchRequestResult>: @preconcurrency DynamicProperty {
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var coordinator = Coordinator()
    private let representable: AnyFetchRequestRepresentable<ResultType>
    
    public init() where ResultType: NSManagedObject {
        self.init(entityName: ResultType.entity().name!)
    }
    
    public init(entityName: String) {
        self.representable = AnyFetchRequestRepresentable(DefaultFetchRequestRepresentable<ResultType>(entityName: entityName))
    }
    
    public init<V: NSFetchRequestRepresentable<ResultType>>(_ representable: V) {
        self.representable = AnyFetchRequestRepresentable(representable)
    }
    
    public init(sortDescriptors: [SortDescriptor<ResultType>]) where ResultType: NSManagedObject {
        self.representable = AnyFetchRequestRepresentable(ModernSortFetchRequest(sortDescriptors: sortDescriptors))
    }
    
    // reads the tracked value
    public var wrappedValue: [ResultType] {
        coordinator.config.objects
    }
    
    // also reads the tracked value
    public var projectedValue: Config {
        coordinator.config
    }
    
    public func update() {
        coordinator.update(from: self)
    }
    
    public struct Config {
        public internal(set) var objects:  [ResultType] = []
        public internal(set) var lastError: (any Error)? = nil
    }
    
    @MainActor
    @Observable
    final class Coordinator: NSObject, @preconcurrency NSFetchedResultsControllerDelegate {
        
        private(set) var config = Config()
        
        @ObservationIgnored
        private var frc: NSFetchedResultsController<ResultType>? {
            didSet {
                oldValue?.delegate = nil
                frc?.delegate = self
            }
        }
        
        @ObservationIgnored
        private var hasStructuralChanges = false
        
        @ObservationIgnored
        private var representable: AnyFetchRequestRepresentable<ResultType>?
        
        @ObservationIgnored
        private var managedObjectContext: NSManagedObjectContext?
        
        func update(from parent: FetchRequest2) {
            if (managedObjectContext, representable) == (parent.managedObjectContext, parent.representable) {
                return
            }
            managedObjectContext = parent.managedObjectContext
            representable = parent.representable
            
            let fr = parent.representable.makeNSFetchRequest()
            let frc = NSFetchedResultsController(
                fetchRequest: fr,
                managedObjectContext: parent.managedObjectContext,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
            do {
                try frc.performFetch()
                self.frc = frc // only save if didn't fail so previous valid frc continues to update.
                _config.objects = frc.fetchedObjects ?? []
                _config.lastError = nil
            } catch {
                _config.lastError = error
            }
        }
        
        // MARK: - Delegate
        
        func controller(_ controller: NSFetchedResultsController<any NSFetchRequestResult>,
                               didChange anObject: Any,
                               at indexPath: IndexPath?,
                               for type: NSFetchedResultsChangeType,
                               newIndexPath: IndexPath?) {
            if type != .update {
                hasStructuralChanges = true
            }
        }
        
        func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
            guard hasStructuralChanges else { return }
            hasStructuralChanges = false
            config.objects = controller.fetchedObjects as? [ResultType] ?? []
        }
        
        deinit {
            print("FetchRequest2.Coordinator deinit")
        }
    }

}

