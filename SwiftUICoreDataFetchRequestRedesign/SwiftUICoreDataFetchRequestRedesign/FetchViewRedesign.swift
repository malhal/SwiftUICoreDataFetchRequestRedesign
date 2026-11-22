//
//  FetchViewRedesign.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI
import CoreData
import BindingKit

struct IsSortingKey: TransactionKey {
    static let defaultValue: Bool = false
}

extension Transaction {
    var isSorting: Bool {
        get { self[IsSortingKey.self] }
        set { self[IsSortingKey.self] = newValue }
    }
}

struct FetchViewRedesign: View {
    
    // for testing body recomputation
    let counter: Int
    
    @State private var ascending: Bool = false
    
    // source of truth for the sort can easily be persisted
    // @AppStorage("Ascending") private var ascendingStored = true
    
    @State var toggle = false
    
    @State private var counter2 = 0
    @Environment(\.managedObjectContext) var viewContext

    //@FetchRequest2 var items2: [Item]
    //@FetchRequest2(sortDescriptors: [SortDescriptor(\Item.timestamp)]) var items: [Item]
   // @FetchRequest2(SortedItems(ascending: false)) var items: [Item]
    
  //  @State private var sortOrder: [KeyPathComparator<Item>] = [KeyPathComparator(\.timestamp, order: .forward)]
//    var sortDescriptorsBinding: Binding<[KeyPathComparator<Item>]> {
//        Binding {
//            [KeyPathComparator(\Item.safeTimestamp, order: ascending ? .forward : .reverse)]
//        } set: { value, transaction in
//            withTransaction(transaction) {
//                ascending = value.first?.order == .forward
//            }
//        }
//    }
    
    var sortDescriptorsBinding: Binding<[SortDescriptor<Item>]> {
        Binding {
            [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
        } set: { value, transaction in
            withTransaction(transaction) {
                ascending = value.first?.order == .forward
            }
        }
    }
    
    var body: some View {
        let _ = Self._printChanges()
        VStack {
            HStack {
                Button("Recompute \(counter2)") {
                    counter2 += 1
                }
                Button("ascending ") {
                    //var t = Transaction()
                  //  t.disablesAnimations = true
                    
                    withTransaction(\.disablesAnimations, true) {
                        ascending.toggle()
                    }
                }
            }
            // FetchedTable2(ascending: $ascending)
            
           FetchRequest3View(FetchRequest3(SortedItems(ascending: ascending))) { items, error in
                
                Button("Update") {
                    items.first?.timestamp = Date()
                    //                    withAnimation {
                    //                        viewContext.processPendingChanges()
                    //                    }
                }
                Button("Delete") {
                    if let first = items.first {
                        let a = first.timestamp
                        viewContext.delete(first)
                        let b = first.timestamp
//                        withAnimation {
                            viewContext.processPendingChanges()
//                       }
                        let c = first.timestamp
                    }
                }
               
               Table(items, sortOrder: sortDescriptorsBinding) { // .transaction(\.disablesAnimations, true)
                    TableColumn("timestamp" as LocalizedStringResource, value: \.timestamp) { item in
                        ItemRow(item: item)
                    }
                }
               
               .animation(.default, value: items.map(\.id))
               
               //               VStack {
               //                   ForEach(items) { item in
               //                       ItemRow(item: item)
               //                   }
               //               }
               
//               .transaction(value: items.map(\.id)) { transaction in
//                   let t = transaction.disablesAnimations
//                   if !transaction.isSorting {
//                       transaction.animation = .default
//                   }
//                   
//                   let u = transaction.disablesAnimations
//                   print("")
//               }
               
//                .transaction { transaction in
//                    transaction.animation = .default
//                }
                
            
                //
//                .transaction { transaction in
//                    transaction.disablesAnimations = true
//                }
            }
          //  FetchedTable2(ascending: $ascending.animation())
//            Table(of: Item.self, sortOrder: sortDescriptorsBinding) {
//                TableColumn("Timestamp", value: \Item.safeTimestamp) { item in
//                    Text(item.safeTimestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
//                }
//                
//            } rows: {
//                // The table structure and headers paint immediately.
//                // When `items` is nil, it renders empty rows until the task finishes.
//             
//                ForEach(items) { item in
//                    TableRow(item)
//                    //Text(item.safeTimestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
//                }
//            }
        }
//        .fetch(SortedItems(ascending: ascending)) { result in
//            withAnimation {
//                // self.items = nil
//                self.items = result
//            }
//        } onError: { error in
//            // do we need to change the sort back?
//        }
    }
}

//struct FetchedTable2: View {
//    @FetchRequest2<SortedItems> var items: [Item]
//    @Binding var sortDescriptors: [SortDescriptor<Item>]
//    @Environment(\.managedObjectContext) var viewContext
//    
//    init(ascending: Binding<Bool>) {
//        let sortDescriptors = [SortDescriptor(\Item.timestamp, order: ascending.wrappedValue ? .forward : .reverse)]
//        _items = FetchRequest2(SortedItems(ascending: ascending.wrappedValue))
//        _sortDescriptors = Binding {
//            sortDescriptors
//        } set: { v, t in
//            withTransaction(t) {
//                ascending.wrappedValue = v.first?.order == .forward
//            }
//        }
//    }
//    
//    var body: some View {
//
//    }
//}


extension Item {
    // Non-optional convenience computed property for UI sorting/display safely
    var safeTimestamp: Date {
        timestamp ?? .distantPast
    }
    
    public var id: ObjectIdentifier {
        ObjectIdentifier(self)
    }
}

struct SortedItems: NSFetchRequestRepresentable<Item> {
    let ascending: Bool
    
    func makeNSFetchRequest() -> NSFetchRequest<Item> {
        let fr = Item.fetchRequest()
        fr.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: ascending)]
        return fr
    }
    
}

