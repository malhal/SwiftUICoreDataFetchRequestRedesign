# SwiftUI Core Data Fetch Request Redesign

This project provides a clean, high-performance, property-wrapper-driven Core Data fetch architecture designed to integrate natively into SwiftUI. It replaces traditional `@FetchRequest` limitations with a robust **`@propertyWrapper`** and **`FetchRequest2View`** combination, powered by an internal `@Observable` coordinator and an equatable protocol representation pattern.

---

## Why This Redesign?

### 1. Property Wrapper Ergonomics with Dynamic Query Types

Standard property wrappers like `@FetchRequest` require rigid initialization parameters that make custom, domain-specific query blueprints awkward.

* **The Factory Pattern (`NSFetchRequestRepresentable`)**: By defining your query configurations as value-type structs conforming to `NSFetchRequestRepresentable`, you can bundle complex sort descriptors, predicates, and fetch limits into clean, reusable objects.
* **`AnyFetchRequestRepresentable` Type Erasure**: Because protocols with associated types (`ResultType`) cannot normally be stored directly in type-erased properties, a custom type-opening container handles static type-casting safely under the hood, allowing `FetchRequest2` to accept any conforming representable without compile-time generics friction.

### 2. Explicit Error Boundaries & Configuration Tracking

Unlike native SwiftUI property wrappers that fail silently or lack exception handling, `FetchRequest2` exposes database errors directly through its projected configuration state (`projectedValue` / `Config`), keeping your UI safe to render fallback states.

### 3. Granular Observation & Performance Optimization

The underlying `Coordinator` implements `NSFetchedResultsControllerDelegate` and explicitly tracks structural changes:

* It ignores `.update` delegate events for collection reloads, preventing property changes inside a single row from triggering expensive full-list re-renders.
* It only triggers updates when structural mutations (inserts, deletes, moves) or external configuration changes occur.

---

## Core Components

* **`NSFetchRequestRepresentable`**: A protocol defining an equatable configuration blueprint (`makeNSFetchRequest()`) that builds an `NSFetchRequest`.
* **`AnyFetchRequestRepresentable`**: A type-erased container using static type-opening to compare and wrap arbitrary fetch request representables safely.
* **`FetchRequest2`**: A `@propertyWrapper` and `DynamicProperty` that manages the `NSFetchedResultsController` lifecycle, tracks the environment's `NSManagedObjectContext`, and exposes strongly-typed results and errors via `@Observable`.
* **`FetchRequest2View`**: A view helper container that injects the fetched array and configuration state directly into your custom content closure.

---

## Usage Example

Here is how cleanly you can drive a dynamic Core Data table query with sort order bindings, animation transactions, and real-time updates using `FetchRequest2` and `FetchRequest2View`:

```swift
import SwiftUI
import CoreData

struct ItemListView: View {
    @State private var ascending = false
    @Environment(\.managedObjectContext) var viewContext

    // Bindable sort descriptors for SwiftUI tables or controls
    var sortDescriptorsBinding: Binding<[SortDescriptor<Item>]> {
        Binding {
            [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
        } set: { value, transaction in
            withTransaction(transaction) {
                ascending = value.first?.order == .forward
            }
        }
    }

    var body: some View {
        VStack {
            Button("Toggle Sort: \(ascending ? "Ascending" : "Descending")") {
                withAnimation {
                    ascending.toggle()
                }
            }
            
            // Drive the view using FetchRequest2 wrapped in FetchRequest2View
            FetchRequest2View(FetchRequest2(SortedItems(ascending: ascending))) { items, config in
                
                if let error = config.lastError {
                    Text("Error loading data: \(error.localizedDescription)")
                        .foregroundColor(.red)
                }

                Table(items, sortOrder: sortDescriptorsBinding.animation()) {
                    TableColumn("Timestamp", value: \.timestamp) { item in
                        ItemRow(item: item)
                    }
                }
            }
        }
    }
}

// Define a domain-specific configuration conforming to NSFetchRequestRepresentable
struct SortedItems: NSFetchRequestRepresentable {
    let ascending: Bool
    
    func makeNSFetchRequest() -> NSFetchRequest<Item> {
        let fr = Item.fetchRequest()
        fr.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: ascending)]
        return fr
    }
}

// so the row updates when the timestamp changes because the FetchRequest2 only updates on insert/delete/move not change.
struct ItemRow: View {
    @ObservedObject var item: Item
    
    var body: some View {
        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
    }
}

```