//
//  TableView.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI

struct FetchViewOriginal: View {
    
    // source of truth for the sort
    @State var ascending = true
    
    // for testing body recomputation
    let counter: Int
    
    // initial sort [] means random and it resets to this every time this View is re-init by the parent body.
    // we cannot use the value of ascending in this decleration to set the correct sort.
    @FetchRequest(sortDescriptors: []) var items: FetchedResults<Item>
    
    var sortDescriptors: [SortDescriptor<Item>] {
        [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
    }
    
    var sortDescriptorsBinding: Binding<[SortDescriptor<Item>]> {
        Binding {
            sortDescriptors
        } set: { v in
            ascending = v.first?.order == .forward
        }
    }
    
    @State var counter2 = 0
    
    var body: some View {
        Button("Recompute \(counter2)") {
            counter2 += 1
        }
        Table(items, sortOrder: sortDescriptorsBinding) {
            TableColumn("timestamp", value: \.timestamp) { item in
                Text(item.timestamp!, format: Date.FormatStyle(date: .numeric, time: .standard))
            }
        }
        .onChange(of: ascending, initial: true) {
            items.sortDescriptors = sortDescriptors
        }
    }
}

#Preview {
    FetchViewOriginal(counter: 0)
}
