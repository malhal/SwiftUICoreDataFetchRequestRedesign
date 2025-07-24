//
//  FetchRequest2.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI
import CoreData

@MainActor @propertyWrapper
struct FetchRequest2<ResultType>: DynamicProperty where ResultType: NSManagedObject {
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var controller = FetchController()
    
    private let nsSortDescriptors: [NSSortDescriptor]?
    private let nsPredicate: NSPredicate?
    
    init(sortDescriptors: [SortDescriptor<ResultType>], nsPredicate: NSPredicate? = nil) {
        self.init(nsSortDescriptors: sortDescriptors.map(NSSortDescriptor.init), nsPredicate: nsPredicate)
    }
    
    init(nsSortDescriptors: [NSSortDescriptor], nsPredicate: NSPredicate? = nil) {
        self.nsSortDescriptors = nsSortDescriptors
        self.nsPredicate = nsPredicate
    }
    
    var wrappedValue: Result<[ResultType], Error> {
        Result { try controller.result(context: viewContext, sortDescriptors: nsSortDescriptors, predicate: nsPredicate) }
    }
    
    
    @MainActor
    class FetchController: NSObject, @preconcurrency NSFetchedResultsControllerDelegate, ObservableObject {
        
        private var cachedResult: [ResultType]?
        
        private var animation: Animation?
        
        private var fetchedResultsController: NSFetchedResultsController<ResultType>? {
            didSet {
                oldValue?.delegate = nil
                fetchedResultsController?.delegate = self
            }
        }
        
        func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
            if cachedResult == nil {
                cachedResult = controller.fetchedObjects as? [ResultType] ?? []
                withAnimation(animation) {
                    objectWillChange.send()
                }
            }
        }
        
        func controller(_ controller: NSFetchedResultsController<any NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
            if type != .update {
                cachedResult = nil
            }
        }
        
        func result(context: NSManagedObjectContext, sortDescriptors: [NSSortDescriptor]? = nil, predicate: NSPredicate? = nil, animation: Animation? = .default) throws -> [ResultType] {
            
            self.animation = animation
            
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
            if let existingFRC = fetchedResultsController, context == existingFRC.managedObjectContext {
                frc = existingFRC
            } else {
                frc = NSFetchedResultsController<ResultType>(fetchRequest: fr, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
                fetchedResultsController = frc
                cachedResult = nil
            }
            
            if let cachedResult {
                return cachedResult
            }
            
            try frc.performFetch()
            let result = frc.fetchedObjects ?? []
            cachedResult = result
            return result
        }
    }

}
