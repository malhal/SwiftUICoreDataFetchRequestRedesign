# SwiftUI CoreData @FetchRequest Redesign

Edit: the current version of the code uses a `@StateObject var controller = FetchController<Item>()` for the dynamic query which works better. The controller is updated with new fetch params in a computed property which retrieves the results for body. If the results for the same fetch params change, body is called again.

SwiftUI's `@FetchRequest` is missing error handling so this redesign attempts to implement that. Although its use may be limited as core data can hard if for example an invalid predicate is supplied. This project also attempts to demonstrate what I believe is proper dynamic fetch requests, i.e. if the sort or predicate is changed dynamically. I believe the vars and bindings that were added to `@FetchRequest` were actually an implementation mistake because when the `@FetchRequest` is re-init it loses all of its internal state of these vars anyway so the best pattern is to initialize it with the params you want whenever those change. There are 2 example Views, one using the original `@FetchREquest` and other uses my version @FetchRequest2 with the error support. In both cases the dynamic FetchRequest (where the sort descriptor is changed) is implemented using a generic child View which is a pattern you may find useful in your own projects even if you decide not to use the redesign.

This repository contains a sample project that shows the original fetch request and redesign side by side. Simply launch the project on macOS or iPad landscap (so table sort headers appear), modify the sort of both tables by clicking the headers, then click the counter increment button to cause both `View`s to be re-initialized to test that the state of the fetch is working correctly.



SwiftUI's `@FetchRequest` lacks built-in error handling, which this redesign aims to address. While its use may be somewhat limited—particularly when dealing with challenging scenarios like invalid predicates (hard crash)—this project also demonstrates what I consider to be a proper implementation of dynamic fetch requests. I believe the addition of variables and bindings to `@FetchRequest` was a design oversight. When the `@FetchRequest` is reinitialized, it loses all internal state related to these variables. Therefore, the best practice is probably to initialize a new `@FetchRequest` with the desired parameters whenever those parameters change. It appears to keep its internal NSFetchedResultsController and just update it, which my implementation also does.

This project provides two example views: one utilizing the original `@FetchRequest` and the other using my redesigned `@FetchRequest2`, which includes error handling. Both examples demonstrate dynamic fetch requests where the sort descriptor is modified. A reusable, generic child view is used to implement this dynamic behavior—a pattern you might find useful in your own projects, even if you choose not to adopt the redesign.

The repository contains a sample project showcasing the original and redesigned fetch requests side by side. To test the functionality:

1. Run the project on macOS or iPad in landscape mode (to enable table sort headers).
2. Modify the sort order of both tables by clicking the headers.
3. Click the counter increment button to trigger reinitialization of both views, verifying that the fetch request state persists as expected.

```
struct FetchViewRedesign: View {
    
    @Environment(\.managedObjectContext) var viewContext
    @State private var ascending: Bool = false
    
    // source of truth for the sort can easily be persisted
    @AppStorage("Ascending") private var ascendingStored = false
    
    // for testing body recomputation
    let counter: Int
    
    var sortDescriptors: [SortDescriptor<Item>] {
        [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
    }
    
    // gets the sort descriptor directly from the fetch.
    // transforms from the sort descriptors set by the table to the ascending state bool.
    var sortDescriptorsBinding: Binding<[SortDescriptor<Item>]> {
        Binding {
            sortDescriptors
        } set: { v in
            // after this, the onChange will set the new sortDescriptor.
            ascending = v.first?.order == .forward
        }
    }

    struct FetchedResultsView2<Content, ResultType>: View where Content: View, ResultType: NSManagedObject {
        let request: FetchRequest2<ResultType>
        @ViewBuilder let content: ((Result<[ResultType], Error>) -> Content)
        
        var body: some View {
            content(request.wrappedValue)
        }
    }
    
    var body: some View {
        FetchedResultsView2(request: FetchRequest2(sortDescriptors: sortDescriptors)) { result in
            switch(result) {
                case let .failure(error):
                    Text(error.localizedDescription)
                case let .success(items):
                    Table(items, sortOrder: sortDescriptorsBinding) {
                        TableColumn("timestamp", value: \.timestamp) { item in
                            Text(item.timestamp!, format: Date.FormatStyle(date: .numeric, time: .standard))
                        }
                    }
            }
        }
    }
}
```

![Screenshot](/Screenshots/Screenshot.png)