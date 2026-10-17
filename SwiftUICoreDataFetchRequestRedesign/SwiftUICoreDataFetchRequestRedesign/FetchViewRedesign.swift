//
//  FetchViewRedesign.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI
import CoreData

struct FetchViewRedesign: View {
    
    @State private var ascending: Bool = true
    
    // source of truth for the sort can easily be persisted
    // @AppStorage("Ascending") private var ascendingStored = true
    
    // for testing body recomputation
    let counter: Int
    
    @State var toggle = false
    
    // gets the sort descriptor directly from the fetch.
    // transforms from the sort descriptors set by the table to the ascending state bool.
    var sortDescriptors: [SortDescriptor<Item>] {
        [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
    }
    
    var sortDescriptorsBinding: Binding<[SortDescriptor<Item>]> {
        return Binding {
            sortDescriptors
        } set: { value, transaction in
            withTransaction(transaction) {
                ascending = value.first?.order == .forward
            }
        }
    }
    @Environment(\.managedObjectContext) var viewContext
    
    struct SortedItems: FetchRequestConfiguring<Item> {
        let ascending: Bool
        
        func configure(request: NSFetchRequest<Item>) {
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: ascending)]
        }
    }
    
    var body: some View {
        FetchedResultsView(SortedItems(ascending: ascending)) { items, _ in
            VStack {
                HStack {
                    Button("ascending ") {
                        withAnimation {
                            ascending.toggle()
                        }
                    }
                    
                    Button("Update") {
                        items.first?.timestamp = Date()
                    }
                    Button("Delete") {
                        if let first = items.first {
                            viewContext.delete(first)
                        }
                    }
                }
                Table(items, sortOrder: sortDescriptorsBinding.animation()) {
                    
                    TableColumn("timestamp" as LocalizedStringResource, value: \.timestamp) { item in
                        ItemRow(item: item)
                    }
                }
            }
        }
    }
}

struct ItemRow: View {
    @ObservedObject var item: Item
    
    var body: some View {
        Text(item.timestamp!, format: Date.FormatStyle(date: .numeric, time: .standard))
    }
}
