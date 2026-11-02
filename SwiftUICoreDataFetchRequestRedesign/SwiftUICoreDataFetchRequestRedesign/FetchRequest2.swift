//
//  StaticFetchRequest.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 20/10/2026.
//
import Foundation
import SwiftUI
import CoreData

@MainActor
@propertyWrapper
public struct FetchRequest2<Representable>: @preconcurrency DynamicProperty where Representable: NSFetchRequestRepresentable {
    
    @Environment(\.managedObjectContext) public var fetchRequestContext
    @State private var evaluator = Evaluator()
    private let representable: Representable
    
    public init(_ representable: Representable) {
        self.representable = representable
    }
    
    private var output = Output(results: [], error: nil)
    
    
    public var wrappedValue: [Representable.ResultType] {
        output.results
    }
    
    public var lastError: Error? {
        output.error
    }
    
    public struct Input: Equatable {
        public let context: NSManagedObjectContext
        public let representable: Representable
        
        public init(context: NSManagedObjectContext, representable: Representable) {
            self.context = context
            self.representable = representable
        }
    }
    
    public struct Output {
        public var results: [Representable.ResultType]
        public var error: Error?
        
        public init(results: [Representable.ResultType], error: Error?) {
            self.results = results
            self.error = error
        }
    }
    
    public mutating func update() {
        output = evaluator(Input(context: fetchRequestContext, representable: representable))
    }
    
    public var projectedValue: FetchRequest2<Representable> {
        self
    }
    
    @MainActor
    @Observable
    public class Evaluator: NSObject, @preconcurrency NSFetchedResultsControllerDelegate {
        
        @ObservationIgnored
        private var lastInput: Input?
        
        public var results: [Representable.ResultType] = []
        
        @ObservationIgnored
        public var error: Error?
        
        @ObservationIgnored
        var frc: NSFetchedResultsController<Representable.ResultType>? {
            didSet {
                oldValue?.delegate = nil
                frc?.delegate = self
            }
        }
        
        override init() {
            super.init()
            print("FetchedResultsObserver init")
        }
        
        @ObservationIgnored
        private var hasStructuralChanges = false
        
        @discardableResult
        public func callAsFunction(_ input: Input) -> Output {
            if let lastInput, lastInput == input {
                return Output(results: results, error: error)
            }
            lastInput = input
            
            let fr = input.representable.makeNSFetchRequest()
            do {
                let frc = NSFetchedResultsController(
                    fetchRequest: fr,
                    managedObjectContext: input.context,
                    sectionNameKeyPath: nil,
                    cacheName: nil
                )
                try frc.performFetch()
                self.frc = frc
                results = frc.fetchedObjects ?? []
                error = nil
            } catch {
                self.error = error
            }
            
            return Output(results: results, error: error)
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
            results = controller.fetchedObjects as? [Representable.ResultType] ?? []
        }
        
        deinit {
            print("FetchedResultsObserver deinit")
        }
    }
}
