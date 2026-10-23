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
    
    @State var items: [Item] = []
    
    var sortDescriptorsBinding: Binding<[KeyPathComparator<Item>]> {
        Binding {
            [KeyPathComparator(\Item.safeTimestamp, order: ascending ? .forward : .reverse)]
        } set: { value, transaction in
            withTransaction(transaction) {
                ascending = value.first?.order == .forward
            }
        }
    }
    
    @State private var sortOrder: [KeyPathComparator<Item>] = [KeyPathComparator(\.timestamp, order: .forward)]
    
    var body: some View {
        //FetchedResultsView(SortedItems(ascending: ascending)) { items, _ in
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
            
            Table(of: Item.self, sortOrder: sortDescriptorsBinding) {
                TableColumn("Timestamp", value: \Item.safeTimestamp) { item in
                    Text(item.safeTimestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                }
                
            } rows: {
                // The table structure and headers paint immediately.
                // When `items` is nil, it renders empty rows until the task finishes.
             
                ForEach(items) { item in
                    TableRow(item)
                    //Text(item.safeTimestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                }
            }
        }
        .fetch(SortedItems(ascending: ascending)) { result in
            withAnimation {
                // self.items = nil
                self.items = result
            }
        } onError: { error in
            // do we need to change the sort back?
        }
    }
}

extension Item {
    // Non-optional convenience computed property for UI sorting/display safely
    var safeTimestamp: Date {
        timestamp ?? .distantPast
    }
    
    public var id: ObjectIdentifier {
        ObjectIdentifier(self)
    }
}

struct SortedItems: NSFetchRequestRepresentable {
    let ascending: Bool
    
    func makeNSFetchRequest() -> NSFetchRequest<Item> {
        let fr = Item.fetchRequest()
        fr.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: ascending)]
        return fr
    }
    
}

struct ItemRow: View {
    @ObservedObject var item: Item
    
    var body: some View {
        Text(item.timestamp ?? .distantPast, format: Date.FormatStyle(date: .numeric, time: .standard))
    }
}
