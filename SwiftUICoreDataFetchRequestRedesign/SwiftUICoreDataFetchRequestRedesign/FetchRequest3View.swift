//
//  FetchRequest3View.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 22/11/2026.
//

import SwiftUI
import CoreData

public struct FetchRequest3<ResultType: NSFetchRequestResult>: Equatable {
    
    let representable: AnyFetchRequestRepresentable<ResultType>
    
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
}

public struct FetchRequest3View<ResultType: NSFetchRequestResult, Content: View>: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var observer: ResultsObserver?
    @State private var lastError: Error?
    
    private let fetchRequest: FetchRequest3<ResultType>
    private let content: ([ResultType], Error?) -> Content
    
    public init(
        _ fetchRequest: FetchRequest3<ResultType>,
        @ViewBuilder content: @escaping ([ResultType], Error?) -> Content
    ) {
        self.fetchRequest = fetchRequest
        self.content = content
    }
    
    func update() {
        do {
            let fr = fetchRequest.representable.makeNSFetchRequest()
            let frc = NSFetchedResultsController(
                fetchRequest: fr,
                managedObjectContext: viewContext,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
            
            try frc.performFetch()
            lastError = nil
            observer = ResultsObserver(frc: frc)
        }
        catch {
            lastError = error
        }
    }
    
    struct Trigger: Equatable {
        let fetchRequest: FetchRequest3<ResultType>
        let viewContext: NSManagedObjectContext
    }
    
    public var body: some View {
        content(observer?.objects ?? [], lastError)
            .onAppear {
                if observer == nil {
                    update()
                }
            }
            .onChange(of: Trigger(fetchRequest: fetchRequest, viewContext: viewContext)) {
                update()
            }
    }

    @MainActor
    @Observable
    final class ResultsObserver: NSObject, @preconcurrency NSFetchedResultsControllerDelegate {
        
        var objects: [ResultType]?
        
        private let frc: NSFetchedResultsController<ResultType>?
        
        init(frc: NSFetchedResultsController<ResultType>) {
            self.objects = frc.fetchedObjects
            self.frc = frc
            super.init()
            frc.delegate = self
        }
        
        // MARK: - Delegate
        @ObservationIgnored
        private var hasStructuralChanges = false
        
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
            objects = controller.fetchedObjects as? [ResultType]
        }
        
        deinit {
            print("FetchRequest3.Coordinator deinit")
        }

    }
}
