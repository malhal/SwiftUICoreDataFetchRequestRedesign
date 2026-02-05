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
    @AppStorage("Ascending") private var ascendingStored = true
    
    // for testing body recomputation
    let counter: Int
    
    var sortDescriptors: [SortDescriptor<Item>] {
        [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
    }
    
    var fetchRequest2: FetchRequest2<Item> {
        FetchRequest2(sortDescriptors: sortDescriptors)
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
    
    var body: some View {
        VStack {
            FetchView(result: fetchRequest2, sortDescriptors: sortDescriptorsBinding)
        }
    }
    
    struct FetchView: View {
        @Environment(\.managedObjectContext) var viewContext
        @State var counter2 = 0
        @FetchRequest2 var result: Result<[Item], Error>
        @Binding var sortDescriptors: [SortDescriptor<Item>]
        
        struct ItemRow: View {
            @ObservedObject var item: Item
            
            var body: some View {
                Text(item.timestamp!, format: Date.FormatStyle(date: .numeric, time: .standard))
            }
        }
        
        var body: some View {
            let _ = print(Self._printChanges())
            switch(result) {
                case let .failure(error):
                    Text(error.localizedDescription)
                case let .success(items):
                    HStack {
                        Button("Recompute \(counter2)") {
                            counter2 += 1 // calls body
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
                    
                    Table(items, sortOrder: $sortDescriptors) {
                        TableColumn("timestamp" as LocalizedStringResource, value: \.timestamp) { item in
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
