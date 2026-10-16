# SwiftUI Core Data Modern Fetch Redesign

This project provides a clean, minimal, and high-performance Core Data fetch architecture designed to fit naturally into SwiftUI. It replaces the traditional `@FetchRequest` property wrapper with a generic view modifier (`.fetch`) and an observable observer pattern, bringing built-in error handling, precise state tracking, and granular change observation to Core Data.

> "That is an exceptionally clean, elegant piece of architecture. You’ve successfully engineered a high-performance Core Data fetch modifier that mirrors the best design principles of SwiftUI and modern reactive systems."

---

## Why This Redesign?

1. **Built-in Error Handling**: Standard `@FetchRequest` does not expose fetch errors or handle execution failures gracefully. This redesign delivers a `Result<[ResultType], Error>` callback to handle database errors safely.
2. **Two-Tier Invalidation Architecture**: 
   - **Tier 1 (Heavy / Context Switch)**: Re-initializes the `NSFetchedResultsController` entirely only when the `NSManagedObjectContext` reference changes.
   - **Tier 2 (Light / Parameter Update)**: Reuses the existing FRC in place and reconfigures its request when sorting parameters change, avoiding unnecessary database teardowns.
3. **Granular Observation**: The underlying `FetchObserver` explicitly ignores `.update` delegate events, tracking only structural changes (inserts, deletes, moves). This prevents property updates in a single row from triggering expensive collection-wide re-renders.
4. **Pure Value-Type Configuration (`ModernSortedFetch`)**: Uses modern Swift `SortDescriptor` values that conform to `Equatable`, making change detection fast, reliable, and free of reference-type comparison overhead.

---

## Core Components

- **`Fetch` Protocol**: Defines a lightweight, equatable configuration blueprint with an associated result type.
- **`ModernSortedFetch`**: A concrete implementation using typed Swift `SortDescriptor` values to configure underlying `NSFetchRequest` objects.
- **`FetchObserver`**: An `@Observable` class acting as the `NSFetchedResultsControllerDelegate`, tracking structural updates and managing state signaling via a change counter.
- **`FetchModifier`**: A view modifier combining SwiftUI's `.onChange` and environment contexts to drive the fetch lifecycle cleanly.

---

## Usage Example 1
**Custom Fetch Struct (`AscendingFetch`)**: Demonstrates how to define a dedicated, domain-specific `Fetch` struct to encapsulate custom query configuration and sort logic cleanly into a reusable value type.
```swift
struct ItemListView: View {
    @State private var sortAscending = true
    @State private var items: [Item] = []
    
    struct AscendingFetch: Fetch<Item> {
        let ascending: Bool
        
        func configure(request: NSFetchRequest<Item>) {
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: ascending)]
        }
    }
    
    var body: some View {
        List(items) { item in
            Text(item.name ?? "")
        }
        .fetch(
            AscendingFetch(ascending: sortAscending)
        ) { result in
            switch result {
            case .success(let fetchedItems):
                self.items = fetchedItems
            case .failure(let error):
                print("Fetch failed: \(error.localizedDescription)")
            }
        }
    }
}
```

---

## Usage Example 2
**Modern Sorted Fetch (`ModernSortedFetch`)**: Demonstrates how to use the built-in generic helper with native Swift SortDescriptor values for quick, lightweight, and type-safe query setup without writing custom structs.
```swift
struct ItemListView: View {
    @State private var sortAscending = true
    @State private var items: [Item] = []
    
    var body: some View {
        List(items) { item in
            Text(item.name ?? "")
        }
        .fetch(
            ModernSortedFetch(
                sortDescriptors: [SortDescriptor(\.timestamp, order: sortAscending ? .forward : .reverse)]
            )
        ) { result in
            switch result {
            case .success(let fetchedItems):
                self.items = fetchedItems
            case .failure(let error):
                print("Fetch failed: \(error.localizedDescription)")
            }
        }
    }
}
```
