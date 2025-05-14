//
//  FetchViewRedesign.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI
import CoreData

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
    
    @StateObject var controller = FetchController<Item>()
    
    var result: Result<[Item], Error> {
        Result { try controller.result(context: viewContext, sortDescriptors: sortDescriptors.map(NSSortDescriptor.init)) }
    }
    
    struct ItemRow: View {
        @ObservedObject var item: Item
        
        var body: some View {
            Text(item.timestamp!, format: Date.FormatStyle(date: .numeric, time: .standard))
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                Button("Recompute \(counter2)") {
                    counter2 += 1 // calls body
                }
                Button("Update") {
                    if case let .success(items) = result {
                        items.first?.timestamp = Date()
                    }
                }
                Button("Delete") {
                    if case let .success(items) = result {
                        if let first = items.first {
                            viewContext.delete(first)
                        }
                    }
                }
            }
            switch(result) {
                case let .failure(error):
                    Text(error.localizedDescription)
                case let .success(items):
                    Table(items, sortOrder: sortDescriptorsBinding) {
                        TableColumn("timestamp", value: \.timestamp) { item in
                            ItemRow(item: item)
                        }
                    }
            }
        }
    }
}

#Preview {
    FetchViewRedesign(counter: 0)
}
