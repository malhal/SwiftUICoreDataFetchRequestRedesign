//
//  FetchViewRedesign.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI
import CoreData

struct FetchViewRedesign: View {
    
    // for testing body recomputation
    let counter: Int
    
    @State private var ascending: Bool = true
    
    // source of truth for the sort can easily be persisted
    // @AppStorage("Ascending") private var ascendingStored = true
    
    @State var toggle = false
    
    @State private var counter2 = 0
    
    @Environment(\.managedObjectContext) var viewContext
    
    var sortDescriptorsBinding: Binding<[SortDescriptor<Item>]> {
        Binding {
            [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
        } set: { value, transaction in
            withTransaction(transaction) {
                ascending = value.first?.order == .forward
            }
        }
    }
    
    @State private var observer = FetchedResultsObserver<SortedItems>()
    
    var body: some View {
        FetchedResultsView(SortedItems(ascending: ascending)) { items, _ in
            VStack {
                HStack {
                    Button("Recompute \(counter2)") {
                        counter2 += 1
                    }
                    Button("ascending ") {
                        withAnimation {
                            ascending.toggle()
                        }
                    }
                }
                // FetchedTable2(ascending: $ascending)
                
                Button("Update") {
                    items.first?.timestamp = Date()
                }
                Button("Delete") {
                    if let first = items.first {
                        viewContext.delete(first)
                        withAnimation {
                            viewContext.processPendingChanges()
                        }
                    }
                }
                
                Table(items, sortOrder: sortDescriptorsBinding.animation()) {
                    TableColumn("timestamp" as LocalizedStringResource, value: \.timestamp) { item in
                        Text(item.timestamp!, format: Date.FormatStyle(date: .numeric, time: .standard))
                        
                    }
                }
            }
        }
    }
}
struct SortedItems: NSFetchRequestRepresentable {
    let ascending: Bool
    
    func makeNSFetchRequest() -> NSFetchRequest<Item> {
        Item.fetchRequest()
    }
    
    func updateNSFetchRequest(_ request: NSFetchRequest<Item>) {
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: ascending)]
    }
}

struct ItemRow: View {
    @ObservedObject var item: Item
    
    var body: some View {
        Text(item.timestamp ?? .distantPast, format: Date.FormatStyle(date: .numeric, time: .standard))
    }
}
