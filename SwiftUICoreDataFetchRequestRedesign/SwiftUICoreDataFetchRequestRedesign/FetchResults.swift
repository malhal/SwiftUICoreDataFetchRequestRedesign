//
//  FetchResults.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 06/02/2026.
//
import CoreData

@MainActor
struct FetchResults<T: NSManagedObject> {
    static func updates(
        for request: NSFetchRequest<T>,
        in context: NSManagedObjectContext
    ) -> AsyncThrowingStream<[T], Error> {
        
        AsyncThrowingStream { continuation in
            let frc = NSFetchedResultsController(
                fetchRequest: request,
                managedObjectContext: context,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
            
            let monitor = Monitor(frc: frc)
            
            monitor.handler = { results in
                continuation.yield(results)
            }
            
            // The "Cleanup"
            continuation.onTermination = { @Sendable _ in
               // monitor.stop()
            }
            
            do {
               try monitor.start()
            }
            catch {
                continuation.finish(throwing: error)
            }
        }
    }
    
    /// A private coordinator that bridges FRC callbacks to the AsyncStream
    @MainActor
    private class Monitor: NSObject, @preconcurrency NSFetchedResultsControllerDelegate {
        var handler: (([T]) -> ())?
        let frc: NSFetchedResultsController<T>
       
        init(frc: NSFetchedResultsController<T>) {
            self.frc = frc
            super.init()
        }
        
        func start() throws {
            frc.delegate = self
            try frc.performFetch()
            handler?(frc.fetchedObjects ?? [])
        }
        
        func stop() {
            frc.delegate = nil
        }
        
        func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
            // 1. Cast the results back to our generic type
            guard let results = controller.fetchedObjects as? [T] else { return }
            
            // 2. Push the new array into the stream
            handler?(results)
        }
        
        // Optional: Handle errors or specific change types if needed,
        // but for a simple list sync, didChangeContent is the gold standard.
        
        deinit {
            print("deinit")
        }
    }
    
}
