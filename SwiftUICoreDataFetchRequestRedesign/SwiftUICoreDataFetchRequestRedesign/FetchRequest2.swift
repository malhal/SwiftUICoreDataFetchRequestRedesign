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
            coordinator.fetchRequest.sortDescriptors?.compactMap { SortDescriptor($0, comparing: ResultType.self) } ?? []
        }
        nonmutating set {
            coordinator.fetchRequest.sortDescriptors = newValue.map { NSSortDescriptor($0) }
            coordinator.fetchedResultsController = nil
        }
    }
    
    var nsSortDescriptors: [NSSortDescriptor] {
        get {
            coordinator.fetchRequest.sortDescriptors ?? []
        }
        nonmutating set {
            coordinator.fetchRequest.sortDescriptors = newValue
            coordinator.fetchedResultsController = nil
        }
    }
    
    var nsPredicate: NSPredicate? {
        get {
            coordinator.fetchRequest.predicate
        }
        nonmutating set {
            coordinator.fetchRequest.predicate = newValue
            coordinator.fetchedResultsController = nil
        }
    }
    
    public var wrappedValue: Result<[ResultType], Error> {
        coordinator.result
    }
    
    private var initialFetchRequest: NSFetchRequest<ResultType> {
        let fr = NSFetchRequest<ResultType>(entityName: "\(ResultType.self)")
        fr.predicate = initialNSPredicate()
        if let initialNSSortDescriptors {
            fr.sortDescriptors = initialNSSortDescriptors()
        }
        else {
            fr.sortDescriptors = initialSortDescriptors.map { NSSortDescriptor($0) }
        }
        return fr
    }
    
    func update() {
        if coordinator.managedObjectContext != viewContext {
            coordinator.managedObjectContext = viewContext
        }
        if coordinator.fetchRequest == nil {
            coordinator.fetchRequest = initialFetchRequest
        }
    }
    
    @Observable
    class Coordinator: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
        
        @ObservationIgnored
        var managedObjectContext: NSManagedObjectContext! {
            didSet {
                _fetchedResultsController = nil
            }
        }
        
        @ObservationIgnored
        var fetchRequest: NSFetchRequest<ResultType>! {
            didSet {
                _fetchedResultsController = nil
            }
        }
        
        @ObservationIgnored
        var _fetchedResultsController: NSFetchedResultsController<ResultType>? {
            didSet {
                oldValue?.delegate = nil
                _fetchedResultsController?.delegate = self
                _result = nil
            }
        }
        var fetchedResultsController: NSFetchedResultsController<ResultType>! {
            get {
                if _fetchedResultsController == nil {
                    _fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
                }
                return _fetchedResultsController
            }
            set {
                _fetchedResultsController = newValue
            }
        }
        
        func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
            _result = .success(controller.fetchedObjects as! [ResultType])
        }
    
        var _result: Result<[ResultType], Error>?
        var result: Result<[ResultType], Error>! {
            get {
                if _result == nil {
                    do {
                        let frc = fetchedResultsController!
                        try frc.performFetch()
                        _result = Result.success(frc.fetchedObjects!)
                    }
                    catch {
                        _result = Result.failure(error)
                    }
                }
                return _result!
            }
        }
    }
}

