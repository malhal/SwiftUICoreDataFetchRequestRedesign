//
//  StaticFetchRequest.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 20/10/2026.
//
import Foundation
import SwiftUI
import CoreData

public protocol NSFetchRequestRepresentable<ResultType>: Equatable {
    associatedtype ResultType: NSFetchRequestResult
    var entityName: String { get }
    func makeNSFetchRequest() -> NSFetchRequest<ResultType>
}

extension NSFetchRequestRepresentable where ResultType: NSManagedObject {
    var entityName: String {
        ResultType.entity().name!
    }
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
        let entity = ResultType.entity()
        let fr = NSFetchRequest<ResultType>(entityName: entity.name ?? entity.managedObjectClassName)
        fr.sortDescriptors = sortDescriptors.map { NSSortDescriptor($0) }
        return fr
    }
}

// 1. Type-erased wrapper that conforms to BOTH protocols and Equatable
public struct AnyFetchRequestRepresentable<ResultType: NSFetchRequestResult>: NSFetchRequestRepresentable, Equatable {
    public typealias ResultType = ResultType
    
    private let base: any NSFetchRequestRepresentable<ResultType>
    
    public init<T: NSFetchRequestRepresentable<ResultType>>(_ base: T) {
        self.base = base
    }
    
    public func makeNSFetchRequest() -> NSFetchRequest<ResultType> {
        base.makeNSFetchRequest()
    }
    
    public var entityName: String {
        base.entityName
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

// where Representable.ResultType == ResultType
@MainActor
@propertyWrapper
public struct FetchRequest2<ResultType: NSFetchRequestResult>: @preconcurrency DynamicProperty {
    
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var coordinator: Coordinator
    //private var equatable: (any Equatable)
    private var representable: AnyFetchRequestRepresentable<ResultType>
    

    
    public init(entityName: String = "") {
        self._coordinator = State(initialValue: Coordinator())
        self.representable = AnyFetchRequestRepresentable(DefaultFetchRequestRepresentable<ResultType>(entityName: entityName))
    }
    
    public init<V: NSFetchRequestRepresentable<ResultType>>(_ representable: V) {
        self._coordinator = State(initialValue: Coordinator())
        self.representable = AnyFetchRequestRepresentable(representable)
    }
    
    public init(sortDescriptors: [SortDescriptor<ResultType>]) where ResultType: NSManagedObject {
        self._coordinator = State(initialValue: Coordinator())
        self.representable = AnyFetchRequestRepresentable(ModernSortFetchRequest(sortDescriptors: sortDescriptors))
    }
    
    // reads the tracked value
    public var wrappedValue: [ResultType] {
        coordinator.config.objects
    }
    
    public mutating func update() {
        coordinator.update(from: self)
    }
    
    // also reads the tracked value
    public var projectedValue: Config { coordinator.config }
    
    public struct Config {
        public internal(set) var representable: AnyFetchRequestRepresentable<ResultType>!
        public internal(set) var managedObjectContext: NSManagedObjectContext!
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
        
        func update(from parent: FetchRequest2) {
            if let managedObjectContext = config.managedObjectContext, managedObjectContext == parent.managedObjectContext {
                
                // Check if both existentials are present and equal via type-opening helper
                if let currentEquatable = config.representable,
                    currentEquatable == parent.representable {
                    // They are equal! Skip work.
                    return
                }
                
            }
            
            _config.managedObjectContext = parent.managedObjectContext
            _config.representable = parent.representable
            let fr = parent.representable.makeNSFetchRequest()
            let frc = NSFetchedResultsController(
                fetchRequest: fr,
                managedObjectContext: parent.managedObjectContext,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
            do {
                try frc.performFetch()
                self.frc = frc
                _config.objects = frc.fetchedObjects ?? []
                _config.lastError = nil
            } catch {
                _config.lastError = error
            }
        }
        
        // Static helper to compare two `any Equatable` operands by opening the existential
        private static func areEqual(_ lhs: any Equatable, _ rhs: any Equatable) -> Bool {
            func open<T: Equatable>(_ lhsValue: T, _ rhsValue: any Equatable) -> Bool {
                guard let rhsT = rhsValue as? T else { return false }
                return lhsValue == rhsT
            }
            return open(lhs, rhs)
        }
        
        // MARK: - Delegate (Async Push)
        
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
    }

}

