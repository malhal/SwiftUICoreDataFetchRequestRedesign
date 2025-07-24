//
//  FetchViewRedesign 2.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 24/07/2025.
//

import SwiftUI
import CoreData

struct FetchViewRedesign3: View {
    
    @Environment(\.managedObjectContext) var viewContext
    
    @Fetch<Item>(initialPredicate: NSPredicate(value: false)) var controller
    
    @State private var ascending: Bool = true
    
    // source of truth for the sort can easily be persisted
    @AppStorage("Ascending") private var ascendingStored = true
    
    // for testing body recomputation
    let counter: Int
    
    var body: some View {
        VStack {
            
            Button("Test send") {
                controller.predicateSubject.send(nil)
                controller.sortDescriptorsSubject.send([NSSortDescriptor(keyPath: \Item.timestamp, ascending: ascending)])
                
            }
            
            FetchView(result: controller.result, ascending: $ascending)
            
        }
        .onChange(of: ascending, initial: true) {
            controller.predicateSubject.send(nil)
            controller.sortDescriptorsSubject.send([NSSortDescriptor(keyPath: \Item.timestamp, ascending: ascending)])
        }
    }
    
    struct FetchView: View {
        @Environment(\.managedObjectContext) var viewContext
        //@Binding var sortDescriptors: [SortDescriptor<Item>]
        @State var counter2 = 0
        let result: Result<[Item], Error>
        @Binding var ascending: Bool
//        init(sortDescriptors: Binding<[SortDescriptor<Item>]>) {
//            _sortDescriptors = sortDescriptors
//            _result = FetchRequest2(sortDescriptors: sortDescriptors.wrappedValue)
//        }
        
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

        struct ItemRow: View {
            @ObservedObject var item: Item
            
            var body: some View {
                Text(item.timestamp!, format: Date.FormatStyle(date: .numeric, time: .standard))
            }
        }
        
        var body: some View {
            
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
