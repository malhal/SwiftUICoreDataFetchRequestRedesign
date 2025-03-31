//
//  FetchRequest2.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI
import CoreData
import Combine

@MainActor @propertyWrapper
struct FetchRequest2<ResultType>: DynamicProperty where ResultType: NSManagedObject {
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var controller = FetchController<ResultType>()
    
    private let nsSortDescriptors: [NSSortDescriptor]?
    private let nsPredicate: NSPredicate?
    
    init(sortDescriptors: [SortDescriptor<ResultType>], nsPredicate: NSPredicate? = nil) {
        self.init(nsSortDescriptors: sortDescriptors.map { NSSortDescriptor($0) }, nsPredicate: nsPredicate)
    }
    
    init(nsSortDescriptors: [NSSortDescriptor], nsPredicate: NSPredicate? = nil) {
        self.nsSortDescriptors = nsSortDescriptors
        self.nsPredicate = nsPredicate
    }
    
    var wrappedValue: Result<[ResultType], Error> {
        controller.result(context: viewContext, sortDescriptors: nsSortDescriptors, predicate: nsPredicate)
    }
}

@MainActor
class FetchController<ResultType: NSFetchRequestResult>: NSObject, @preconcurrency NSFetchedResultsControllerDelegate, ObservableObject {
    
    private var fetchedResultsController: NSFetchedResultsController<ResultType>? {
        didSet {
            oldValue?.delegate = nil
            fetchedResultsController?.delegate = self
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // only send if something read the results
        cachedResult = Result.success(controller.fetchedObjects as! [ResultType])
        objectWillChange.send()
    }
    
    private var cachedResult: Result<[ResultType], Error>?
    func result(context: NSManagedObjectContext, sortDescriptors: [NSSortDescriptor]? = nil, predicate: NSPredicate? = nil) -> Result<[ResultType], Error> {
        
        let fr = fetchedResultsController?.fetchRequest ?? NSFetchRequest<ResultType>(entityName: "\(ResultType.self)")
        if fr.sortDescriptors != sortDescriptors {
            fr.sortDescriptors = sortDescriptors
            cachedResult = nil
        }
        if fr.predicate != predicate {
            fr.predicate = predicate
            cachedResult = nil
        }
        
        let frc: NSFetchedResultsController<ResultType>
        if let fetchedResultsController {
            if context == fetchedResultsController.managedObjectContext, let cachedResult {
                return cachedResult
            }
            frc = fetchedResultsController
        }
        else {
            frc = NSFetchedResultsController<ResultType>(fetchRequest: fr, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
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
