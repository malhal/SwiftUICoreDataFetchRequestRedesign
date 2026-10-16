# SwiftUI Core Data Fetch Redesign

This project provides a clean, minimal, and high-performance Core Data fetch architecture designed to fit naturally into SwiftUI. It replaces traditional property wrappers and post-render hack patterns with a synchronous container view (`Fetcher`) and an internal observable observer pattern, bringing built-in error handling, precise state tracking, granular change observation, and seamless transaction/animation preservation to Core Data.

---

## Why This Redesign?

1. **Synchronous Evaluation & Transaction Preservation**: Evaluates fetches synchronously during the render pass, ensuring that incoming animation transactions (such as `withAnimation` triggered by user toggles) flow seamlessly down to view updates without dropping context.
2. **Built-in Error Handling**: Standard `@FetchRequest` does not expose fetch errors or handle execution failures gracefully. This architecture exposes explicit error states via `FetchState` and handles database errors safely while retaining previous successful results.
3. **Two-Tier Invalidation Architecture**:
* **Tier 1 (Heavy / Context Switch)**: Re-initializes the `NSFetchedResultsController` entirely only when the `NSManagedObjectContext` reference changes.
* **Tier 2 (Light / Parameter Update)**: Reuses the existing FRC in place and reconfigures its request when sorting parameters change, avoiding unnecessary database teardowns.


4. **Granular Observation**: The underlying `FetchObserver` explicitly ignores `.update` delegate events, tracking only structural changes (inserts, deletes, moves). This prevents property updates in a single row from triggering expensive collection-wide re-renders.
5. **Pure Value-Type Configuration**: Uses lightweight value types conforming to `FetchRequestConfiguring` to define predicates and sort descriptors, making change detection fast, reliable, and free of reference-type comparison overhead.

---

## Core Components

* **`Fetcher`**: A native-feeling container view that accepts a configuration and yields a `FetchState` payload via a trailing closure, matching SwiftUI component ergonomics (like `GeometryReader`).
* **`FetchRequestConfiguring`**: A protocol defining a lightweight, equatable configuration blueprint with an associated result type to set up an `NSFetchRequest`.
* **`FetchState`**: A state proxy struct encapsulating current results (`[ResultType]`) and errors (`Error?`).
* **`FetchObserver`**: An `@Observable` class acting as the `NSFetchedResultsControllerDelegate`, tracking structural updates and managing fetched results reactively.

---

## Usage Example

```swift
import SwiftUI
import CoreData

struct ItemListView: View {
    @State private var sortAscending = true
    
    // Define a domain-specific configuration conforming to FetchRequestConfiguring
    struct AscendingFetch: FetchRequestConfiguring {
        let ascending: Bool
        
        func configure(request: NSFetchRequest<Item>) {
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: ascending)]
        }
    }
    
    var body: some View {
        // Pristine, unlabeled first parameter syntax mirroring native SwiftUI containers
        Fetcher(AscendingFetch(ascending: sortAscending)) { state in
            let items = state.results
            
            VStack {
                HStack {
                    Button(sortAscending ? "Ascending" : "Descending") {
                        withAnimation {
                            sortAscending.toggle()
                        }
                    }
                    Spacer()
                    Text("\(items.count) items")
                }
                .padding()
                
                List(items) { item in
                    Text(item.timestamp?.description ?? "Unknown Date")
                }
            }
        }
    }
}

```
