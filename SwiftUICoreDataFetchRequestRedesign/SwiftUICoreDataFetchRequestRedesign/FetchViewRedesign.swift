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
    
    @State private var counter2 = 0
    
    var body: some View {
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
            FetchedTable2(ascending: $ascending)
        }
    }
}

struct SortedItems: FetchRequestConfiguring<Item> {
    let ascending: Bool
    
    func configure(request: NSFetchRequest<Item>) {
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: ascending)]
    }
}

extension FetchedTable2 {
    init(ascending: Binding<Bool>) {
        //_items = FetchRequest2(SortedItems(ascending: ascending.wrappedValue))
        let sortDescriptors = [SortDescriptor(\Item.timestamp, order: ascending.wrappedValue ? .forward : .reverse)]
        self.init(items: FetchRequest2(sortDescriptors: sortDescriptors), ascending: ascending)
    }
    
}

struct FetchedTable2: View {
    @FetchRequest2<ModernSortedFetch> var items: [Item]
    @Binding private var ascending: Bool
    
    @Environment(\.managedObjectContext) var viewContext
    
    var sortDescriptorsBinding: Binding<[SortDescriptor<Item>]> {
        Binding {
            [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
        } set: { value, transaction in
            _ascending.transaction(transaction).wrappedValue = value.first?.order == .forward
        }
    }
    
    var body: some View {
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

struct ItemRow: View {
    @ObservedObject var item: Item
    
    var body: some View {
        Text(item.timestamp ?? .distantPast, format: Date.FormatStyle(date: .numeric, time: .standard))
    }
}
