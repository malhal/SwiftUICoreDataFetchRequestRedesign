//
//  FetchRequest3.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 24/07/2025.
//
// A new attempt that debounces inputs and does the fetch before the next call to body.

import SwiftUI
import CoreData
import Combine

@propertyWrapper
struct Fetch<ResultType>: DynamicProperty where ResultType: NSManagedObject {
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var controller: Controller
    
    init(initialSortDescriptors: [NSSortDescriptor] = [], initialPredicate: NSPredicate? = NSPredicate(value: false)) {
        _controller = StateObject(wrappedValue: {
            let fr = NSFetchRequest<ResultType>(entityName: "\(ResultType.self)")
            fr.sortDescriptors = initialSortDescriptors
            fr.predicate = initialPredicate
            return Controller(fetchRequest: fr)
        }())
    }
    
    init(initialFetchRequest: NSFetchRequest<ResultType>) {
        _controller = StateObject(wrappedValue: Controller(fetchRequest: initialFetchRequest.copy() as! NSFetchRequest<ResultType>))
    }
    
    var wrappedValue: Controller {
        controller
    }
    
    func update() {
        controller.managedObjectContextSubject.send(viewContext)
    }
    
    @MainActor
    class Controller: NSObject, @preconcurrency NSFetchedResultsControllerDelegate, ObservableObject {
        
        let managedObjectContextSubject = PassthroughSubject<NSManagedObjectContext, Never>()
        
        @Published private var fetchedResultsController: NSFetchedResultsController<ResultType>?
        
        private var cancellables = Set<AnyCancellable>()
        public let sortDescriptorsSubject = PassthroughSubject<[NSSortDescriptor], Never>()
        public let predicateSubject = PassthroughSubject<NSPredicate?, Never>()
        @Published public var result: Result<[ResultType], Error> = .success([])
        
        init(fetchRequest: NSFetchRequest<ResultType>) {
            super.init()
            
            predicateSubject
                .assign(to: \.predicate, on: fetchRequest)
                .store(in: &cancellables)
            
            sortDescriptorsSubject
                .map { $0 as [NSSortDescriptor]? }
                .assign(to: \.sortDescriptors, on: fetchRequest)
                .store(in: &cancellables)
            
            managedObjectContextSubject
                .removeDuplicates() // because update sends it every time
                .debounce(for: 0, scheduler: RunLoop.main)
                .map { [weak self] moc in
                    let frc = NSFetchedResultsController<ResultType>(fetchRequest: fetchRequest, managedObjectContext: moc, sectionNameKeyPath: nil, cacheName: nil)
                    frc.delegate = self
                    return frc
                }
                .assign(to: &$fetchedResultsController)
            
            $fetchedResultsController
                .compactMap{ $0 }
                .combineLatest(sortDescriptorsSubject, predicateSubject)
                .debounce(for: 0, scheduler: RunLoop.main) // so both can be set in the same action without needless fetches
                .map { frc, _, _ in
                    do {
                        try frc.performFetch()
                        let result = frc.fetchedObjects ?? []
                        return Result<[ResultType], Error>.success(result)
                    }
                    catch {
                        return Result.failure(error)
                    }
                }
                .assign(to: &$result)
        }
        
        private var hasStructuralChanges = false
        
        func controllerWillChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
            hasStructuralChanges = false
        }
        
        func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
            //if cachedResult == nil {
            //cachedResult = controller.fetchedObjects as? [ResultType] ?? []
            //withAnimation(animation) {
            if hasStructuralChanges {
                result = Result.success(controller.fetchedObjects as? [ResultType] ?? [])
            }
        }
        
        func controller(_ controller: NSFetchedResultsController<any NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
            // we ignore object changes that do not affect the order.
            if type != .update {
                hasStructuralChanges = true
            }
        }
        
        
    }
}
