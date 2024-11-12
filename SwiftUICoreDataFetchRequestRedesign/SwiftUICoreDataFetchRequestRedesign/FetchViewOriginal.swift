//
//  TableView.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI

struct FetchViewOriginal: View {
    
    // source of truth for the sort
    @State var ascending = false
    
    // for testing body recomputation
    let counter: Int
    
    @FetchRequest(sortDescriptors: []) var items: FetchedResults<Item>
    
    // transforms from ascending to sort descriptors.
    var sortDescriptors: Binding<[SortDescriptor<Item>]> {
        Binding {
            items.sortDescriptors
        } set: { v in
            ascending = v.first?.order == .forward
        }
    }
    
    var body: some View {
        Table(items, sortOrder: sortDescriptors) {
            TableColumn("timestamp", value: \.timestamp) { item in
                Text(item.timestamp!, format: Date.FormatStyle(date: .numeric, time: .standard))
            }
        }
        .onChange(of: ascending, initial: true) {
            items.sortDescriptors = [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
        }
    }
}

#Preview {
    FetchViewOriginal(counter: 0)
}
