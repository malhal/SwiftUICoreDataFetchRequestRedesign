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
    @StateObject private var controller: FetchController<ResultType>
    
    init(intialSortDescriptors: [SortDescriptor<ResultType>], initialNSPredicate: NSPredicate? = nil) {
        _controller = StateObject(wrappedValue: FetchController<ResultType>(sortDescriptors: intialSortDescriptors.map { NSSortDescriptor($0) }, predicate: initialNSPredicate))
    }
    
    init(initialNSSortDescriptors: [NSSortDescriptor], initialNSPredicate: NSPredicate? = nil) {
        _controller = StateObject(wrappedValue: FetchController<ResultType>(sortDescriptors: initialNSSortDescriptors, predicate: initialNSPredicate))
    }
    
    var sortDescriptors: [SortDescriptor<ResultType>] {
        get {
            controller.fetchRequest.sortDescriptors?.compactMap { SortDescriptor($0, comparing: ResultType.self) } ?? []
        }
        nonmutating set {
            controller.fetchRequest.sortDescriptors = newValue.map { NSSortDescriptor($0) }
            controller.invalidateCachedResult()
        }
    }
    
    var nsSortDescriptors: [NSSortDescriptor] {
        get {
            controller.fetchRequest.sortDescriptors ?? []
        }
        nonmutating set {
            controller.fetchRequest.sortDescriptors = newValue
            controller.invalidateCachedResult()
        }
    }
    
    var nsPredicate: NSPredicate? {
        get {
            controller.fetchRequest.predicate
        }
        nonmutating set {
            controller.fetchRequest.predicate = newValue
            controller.invalidateCachedResult()
        }
    }
    
    public var wrappedValue: Result<[ResultType], Error> {
        // a cached result, a refetch if the fetch changed or a new FRC if the context changed.
        return controller.result(for: viewContext)
    }
    
}
    

@MainActor
class FetchController<ResultType: NSFetchRequestResult>: NSObject, @preconcurrency NSFetchedResultsControllerDelegate, ObservableObject {
    
    internal let fetchRequest: NSFetchRequest<ResultType>
    private var fetchedResultsController: NSFetchedResultsController<ResultType>? {
        didSet {
            oldValue?.delegate = nil
            fetchedResultsController?.delegate = self
        }
    }
    
    init(sortDescriptors: [NSSortDescriptor], predicate: NSPredicate? = nil) {
        let fr = NSFetchRequest<ResultType>(entityName: "\(ResultType.self)")
        fr.sortDescriptors = sortDescriptors
        fr.predicate = predicate
        self.fetchRequest = fr
    }
    
    func invalidateCachedResult() {
        cachedResult = nil
        objectWillChange.send()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // only send if something read the results
        cachedResult = Result.success(controller.fetchedObjects as! [ResultType])
        objectWillChange.send()
    }
    
    enum FetchedResultsControllerError: Error {
        case initializationFailed
    }
    
    private var cachedResult: Result<[ResultType], Error>?
    func result(for context: NSManagedObjectContext) -> Result<[ResultType], Error> {
        let frc: NSFetchedResultsController<ResultType>
        if let fetchedResultsController {
            if context == fetchedResultsController.managedObjectContext, let cachedResult {
                return cachedResult
            }
            frc = fetchedResultsController
        }
        else {
            frc = NSFetchedResultsController<ResultType>(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
            fetchedResultsController = frc
            cachedResult = nil
        }
        let result: Result<[ResultType], Error>
        do {
            try frc.performFetch()
            result = Result.success(frc.fetchedObjects ?? [])
        }
        catch {
            result = Result.failure(error)
        }
        cachedResult = result
        return result
    }
}
