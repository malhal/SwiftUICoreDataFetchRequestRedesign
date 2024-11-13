# SwiftUI CoreData @FetchRequest Redesign

SwiftUI's `@FetchRequest` has an unfortunate flaw: if sort descriptors and predicate are set via properties after init are lost if the `View` containing the `@FetchRequest` is re-init. This redesign attempts to resolve that flaw by maintaining the state of the `NSFetchRequest` between `View` inits. This allows for the sort order to be a `@State` source of truth and is used to update the fetch request's sort descriptor. Another great feature is if the `NSManagedObjectContext` in the environment is replaced, results are updated from the new context whilst the original fetch request is maintained. The fetch error is exposed to allow to detect invalid fetches, although the use may be rather limited as core data appears to crash hard if for example an invalid predicate is supplied.

This repository contains a sample project that shows the original fetch request and redesign side by side and demonstrates the flaw and how it is prevented. Simply launch the project on macOS or iPad landscap (so table sort headers appear), modify the sort of both tables by clicking the headers, then click the counter increment button to cause both `View`s to be re-initialized.

The redesign involves a `@FetchRequest2` property wrapper. Similar to `@State`, it can be optionally initialized with initial values for the sort descriptors and predicate. However, if these properties are changed after initialization (for example, in an `onChange` action) then the new values will always override the initial values, even if the `View` containing the wrapper is reinitialized. This approach simplifies the common scenario of the fetch being dependent on other view data. The wrapper can be initialized without any parameters and instead always configured dynamitcally in one place.

In the example below, the fetch request is configured only in the `onChange` modifier. The `initial: true` parameter ensures that it also executes when the screen first appears however you should be aware that it also executes if it re-appears, e.g. when navigating back to this screen. The `Table` uses a useful computed binding to access the current `sortDescriptors` from the fetch request, while setting the ascending state binding. This ascending state is used in `onChange` to update the fetch request with the new predicate.
```
struct FetchViewRedesign: View {
    
    @State private var ascending: Bool = false
    
    // source of truth for the sort can easily be persisted
    //@AppStorage("Config") private var ascending = false
    
    // for testing body recomputation
    let counter: Int
    
    @FetchRequest2 var result: Result<[Item], Error>
    
    // gets the sort descriptor directly from the fetch.
    // transforms from the sort descriptors set by the table to the ascending state bool.
    var sortDescriptors: Binding<[SortDescriptor<Item>]> {
        Binding {
            _result.sortDescriptors
        } set: { v in
            // after this, the onChange will set the new sortDescriptor.
            ascending = v.first?.order == .forward
        }
    }
    
    var body: some View {
        Group {
            switch(result) {
                case let .failure(error):
                    Text(error.localizedDescription)
                case let .success(items):
                    Table(items, sortOrder: sortDescriptors) {
                        TableColumn("timestamp", value: \.timestamp) { item in
                            Text(item.timestamp!, format: Date.FormatStyle(date: .numeric, time: .standard))
                        }
                    }
            }
        }
        .onChange(of: ascending, initial: true) {
            _result.sortDescriptors = [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
        }
    }
}
```

![Screenshot](/Screenshots/Screenshot.png)