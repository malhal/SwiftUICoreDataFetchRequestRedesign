//
//  FetchRequest2.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI
import CoreData
import Combine

@propertyWrapper struct FetchRequest2<ResultType>: DynamicProperty where ResultType: NSManagedObject {
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var coordinator = Coordinator()
    
    private let initialSortDescriptors: [SortDescriptor<ResultType>]
    private let initialNSSortDescriptors: (() -> [NSSortDescriptor])?
    private let initialNSPredicate: () -> NSPredicate?
    
    init(initialNSPredicate: @escaping @autoclosure () -> NSPredicate? = { nil }()) {
        self.initialSortDescriptors = []
        self.initialNSSortDescriptors = nil
        self.initialNSPredicate = initialNSPredicate
    }
    
    init(initialSortDescriptors: [SortDescriptor<ResultType>] = [], initialNSPredicate: @escaping @autoclosure () -> NSPredicate? = { nil }() ) {
        self.initialSortDescriptors = initialSortDescriptors
        self.initialNSPredicate = initialNSPredicate
        self.initialNSSortDescriptors = nil
    }
    
    init(initialNSSortDescriptors: @escaping @autoclosure () -> [NSSortDescriptor] = { [] }(), initialNSPredicate: @escaping @autoclosure () -> NSPredicate? = { nil }() ) {
        self.initialSortDescriptors = []
        self.initialNSSortDescriptors = initialNSSortDescriptors
        self.initialNSPredicate = initialNSPredicate
    }
    
    var sortDescriptors: [SortDescriptor<ResultType>] {
        get {
            coordinator.fetchedResultsController?.fetchRequest.sortDescriptors?.compactMap { SortDescriptor($0, comparing: ResultType.self) } ?? []
        }
        nonmutating set {
            coordinator.fetchedResultsController?.fetchRequest.sortDescriptors = newValue.map { NSSortDescriptor($0) }
            coordinator.result = nil
        }
    }
    
    var nsSortDescriptors: [NSSortDescriptor] {
        get {
            coordinator.fetchedResultsController?.fetchRequest.sortDescriptors ?? []
        }
        nonmutating set {
            coordinator.fetchedResultsController?.fetchRequest.sortDescriptors = newValue
            coordinator.result = nil
        }
    }
    
    var nsPredicate: NSPredicate? {
        get {
            coordinator.fetchedResultsController?.fetchRequest.predicate
        }
        nonmutating set {
            coordinator.fetchedResultsController?.fetchRequest.predicate = newValue
            coordinator.result = nil
        }
    }
    
    public var wrappedValue: Result<[ResultType], Error> {
        coordinator.result
    }
    
    func update() {
        if coordinator.fetchedResultsController?.managedObjectContext != viewContext {
            let fr = coordinator.fetchedResultsController?.fetchRequest ?? {
                let fr = NSFetchRequest<ResultType>(entityName: "\(ResultType.self)")
                if let initialNSSortDescriptors {
                    fr.sortDescriptors = initialNSSortDescriptors()
                }
                else {
                    fr.sortDescriptors = initialSortDescriptors.map { NSSortDescriptor($0) }
                }
                fr.predicate = initialNSPredicate()
                return fr
            }()
            coordinator.fetchedResultsController = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: viewContext, sectionNameKeyPath: nil, cacheName: nil)
        }
    }
    
    class Coordinator: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
        
        var fetchedResultsController: NSFetchedResultsController<ResultType>? {
            didSet {
                oldValue?.delegate = nil
                fetchedResultsController?.delegate = self
                _result = nil
            }
        }
        
        func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
            result = Result.success(controller.fetchedObjects as? [ResultType] ?? [])
        }
    
        private var _result: Result<[ResultType], Error>?
        var result: Result<[ResultType], Error>! {
            get {
                if _result == nil {
                    do {
                        try fetchedResultsController?.performFetch()
                        _result = Result.success(fetchedResultsController?.fetchedObjects ?? [])
                    }
                    catch {
                        _result = Result.failure(error)
                    }
                }
                return _result!
            }
            set {
                objectWillChange.send()
                _result = newValue
            }
        }
    }
}

