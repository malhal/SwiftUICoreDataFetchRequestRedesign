# SwiftUI CoreData @FetchRequest Redesign

SwiftUI's `@FetchRequest` has an unfortunate flaw: its sort descriptors are lost if the `View` containing the `@FetchRequest` is re-init. This redesign attempts to resolve that flaw by maintaining the state of the `NSFetchRequest` between `View` inits. This allows for the sort order to be a `@State` source of truth and is used to update the fetch request's sort descriptor. Another great feature is if the `NSManagedObjectContext` in the environment is replaced, results are updated from the new context whilst the original fetch request is maintained. The fetch error is exposed to allow to detect invalid fetches, although the use may be rather limited as core data appears to crash hard if for example an invalid predicate is supplied.

This repository contains a sample project that shows the original fetch request and redesign side by side and demonstrates the flaw and how it is prevented. Simply launch the project on macOS or iPad landscap (so table sort headers appear), modify the sort of both tables by clicking the headers, then click the counter increment button to cause both `View`s to be re-initialized.

The redesign invoves a `@FetchRequest2` property wrapper. It is init differently from `@FetchRequest`, i.e. no configuration, instead it can be dynamically configured, e.g. in an `onChange` action. This allows for the sort descriptors to only need to be configured in one place using the ascending state as the source of truth.
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