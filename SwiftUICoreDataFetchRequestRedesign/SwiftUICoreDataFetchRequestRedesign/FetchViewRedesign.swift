//
//  FetchViewRedesign.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI

struct FetchViewRedesign: View {
    
    @Environment(\.managedObjectContext) var viewContext
    @State private var ascending: Bool = true
    
    // source of truth for the sort can easily be persisted
    @AppStorage("Ascending") private var ascendingStored = true
    
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
    
    @State var counter2 = 0

    struct FetchedResultsView2<Content, ResultType>: View where Content: View, ResultType: NSManagedObject {
        @FetchRequest2 var result: Result<[ResultType], Error>
        let content: ((Result<[ResultType], Error>) -> Content)
        
        init(request: FetchRequest2<ResultType>, @ViewBuilder content: @escaping (Result<[ResultType], Error>) -> Content) {
            self._result = request
            self.content = content
        }
        
        var body: some View {
            content(result)
        }
    }
    
    var body: some View {
        Button("Recompute \(counter2)") {
            counter2 += 1 // calls body
        }
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

#Preview {
    FetchViewRedesign(counter: 0)
}
