//
//  TableView.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI
import CoreData

struct FetchViewOriginal: View {
    
    // for testing body recomputation
    let counter: Int
    
    // source of truth for the sort
    @State private var ascending = true

    @State private var counter2 = 0
   
    var body: some View {
        
        Button("Recompute \(counter2)") {
            counter2 += 1
        }
        Button("ascending \(ascending.description)") {
            //  withAnimation {
            ascending.toggle()
        }
        FetchedTable(ascending: $ascending)
    }
}


extension FetchedTable {
    init(ascending: Binding<Bool>) {
        let sortDescriptors = [SortDescriptor(\Item.timestamp, order: ascending.wrappedValue ? .forward : .reverse)]
        let fetch = FetchRequest(sortDescriptors: sortDescriptors, animation: .default)
        let sortDescriptorsBinding = Binding {
            sortDescriptors
        } set: { v in
            ascending.wrappedValue = v.first?.order == .forward
        }
        self.init(items: fetch, sortDescriptors: sortDescriptorsBinding)
    }
}

struct FetchedTable: View {
    @FetchRequest var items: FetchedResults<Item>
    @Binding var sortDescriptors: [SortDescriptor<Item>]
    
    var body: some View {
        Table(items, sortOrder: $sortDescriptors) {
            TableColumn("timestamp" as LocalizedStringResource, value: \.timestamp) { item in
                Text(item.timestamp!, format: Date.FormatStyle(date: .numeric, time: .standard))
                
            }
        }
    }
}
