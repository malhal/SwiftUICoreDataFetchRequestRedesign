//
//  FetchViewRedesign.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI

struct FetchViewRedesign: View {
    
    @State private var ascending: Bool = false
    
    // source of truth for the sort can easily be persisted
    //@AppStorage("Config") private var ascending = false
    
    // for testing body recomputation
    let counter: Int
    
    @FetchRequest2(initialSortDescriptors: [SortDescriptor(\Item.timestamp, order: .forward)], initialNSPredicate: NSPredicate(value: true)) var result: Result<[Item], Error>
    
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

#Preview {
    FetchViewRedesign(counter: 0)
}
