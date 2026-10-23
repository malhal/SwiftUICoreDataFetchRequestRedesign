# SwiftUI Core Data Fetch Redesign

This project provides a clean, minimal, and high-performance Core Data fetch architecture designed to fit naturally into SwiftUI. It replaces traditional property wrappers and post-render hack patterns with a view modifier approach (`.fetch(...)`) powered by an internal observable observer pattern, bringing built-in error handling, precise state tracking, granular change observation, and seamless transaction/animation preservation to Core Data.

---

## Why This Redesign?

### 1. View Modifier vs. Property Wrapper (Why Avoid `@PropertyWrapper`?)

Traditional property wrappers like `@FetchRequest` enforce strict compile-time type requirements at the property declaration site. When working with a generic configuration protocol (`NSFetchRequestRepresentable`), attempting to drive a property wrapper via an associated type introduces severe ergonomic hurdles:

* **The Syntax Barrier**: Declaring a property wrapper with generic constraints on a child view makes standard `@` syntax clumsy or entirely impossible without messy type-erasure.
* **Lifecycle & Scoping**: A view modifier (`.fetch(...)`) acts as a natural SwiftUI boundary. It scopes the `FetchedResultsObserver lifecycle tightly to the view's appearance and passes strongly-typed results (`FetchedResults2<ResultType>`) directly into a clean closure, aligning with native SwiftUI data-flow patterns.

### 2. Synchronous Evaluation & Transaction Preservation

Evaluates fetches cleanly during state transitions, ensuring that incoming animation transactions (such as `withAnimation` triggered by user toggles or table sort order bindings) flow seamlessly down to view updates without dropping context or triggering stray animation glitches.

### 3. Built-in Error Handling

Standard `@FetchRequest` does not expose fetch errors or handle execution failures gracefully. This architecture exposes explicit error states through the `.fetch(_:, handleResults:, onError:)` modifier, allowing database errors to be handled safely while separating success paths.

### 4. Granular Observation

The underlying `FetchedResultsObserver explicitly ignores `.update` delegate events, tracking only structural changes (inserts, deletes, moves). This prevents property updates in a single row from triggering expensive collection-wide re-renders.

---

## Core Components

* **`FetchModifier`**: A view modifier that manages the `NSFetchedResultsController` lifecycle and binds observation updates to view rendering.
* **`NSFetchRequestRepresentable`**: A protocol defining a lightweight, equatable, and sendable configuration blueprint with an associated result type to build an `NSFetchRequest`.
* **`FetchedResults2`**: A lightweight wrapper conforming to `RandomAccessCollection` and `Equatable` wrapping the underlying fetched objects.
* **`FetchedResultsObserver`**: An `@Observable` class acting as the `NSFetchedResultsControllerDelegate`, tracking structural updates and managing version bumps reactively.

---

## Animation & Transaction Behavior

Understanding how animations interact with this architecture ensures smooth visual transitions for both local user interactions and background synchronization:

### 1. Local Actions & Uncommitted Changes (`processPendingChanges`)

Because Core Data operations are asynchronous by default, uncommitted in-memory insertions or deletions will normally close their `withAnimation` transaction block before the fetched results controller fires its delegate.

* To force an immediate synchronous evaluation so that uncommitted local inserts animate smoothly, call `viewContext.processPendingChanges()` inside your local action block.
* Alternatively, you can omit the save and let uncommitted updates refresh the UI reactively.

### 2. Background and External Updates

* **Quiet by Default:** Background updates (such as CloudKit syncs or data imports) update silently without animations. This prevents "sync storms," UI stutter, and abrupt layout jumps while users are interacting with the app.
* **Custom Background Animations:** If background changes *do* need to animate into view, you can wrap the context merge process (`viewContext.mergeChanges(...)`) inside an explicit `withAnimation` block at the boundary where external saves enter the context.

### 3. Bindings & Parameter Changes

* State-driven changes—such as tapping a sort toggle bound via `withAnimation`—trigger a re-evaluation of the fetch configuration inside the modifier. Because the resulting update flows through the active transaction, row re-orderings animate smoothly alongside the control itself.

---

## Usage Example

```swift
import SwiftUI
import CoreData

struct ItemListView: View {
    @State private var ascending = true
    @State private var items = FetchedResults2<Item>()
    @Environment(\.managedObjectContext) private var viewContext
    
    // Define a domain-specific configuration conforming to NSFetchRequestRepresentable
    struct SortedItems: NSFetchRequestRepresentable {
        let ascending: Bool
         
        func makeNSFetchRequest() -> NSFetchRequest<Item> {
            let fr = Item.fetchRequest()
            fr.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: ascending)]
            return fr
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                Button(ascending ? "Ascending" : "Descending") {
                    withAnimation {
                        ascending.toggle()
                    }
                }
                Spacer()
            }
            .padding()
             
            List {
                ForEach(items) { item in
                    Text(item.timestamp?.description ?? "Unknown Date")
                }
            }
        }
        .fetch(SortedItems(ascending: ascending)) { result in
            withAnimation {
               items = result
            }
        } onError: { error in
            print("Fetch failed: \(error)")
        }
    }
}

```
