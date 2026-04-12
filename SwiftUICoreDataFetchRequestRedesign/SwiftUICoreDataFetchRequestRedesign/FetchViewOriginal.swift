//
//  TableView.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI
import CoreData

//KeyPathComparator
extension SortComparator {
    /// Returns a copy of the comparator with the opposite sort order.
    func reversed() -> Self {
        var copy = self
        copy.order = (self.order == .forward ? .reverse : .forward)
        return copy
    }
}

//class MyFetch: ObservableObject {
struct MyFetch {
    var request = { let fr = Item.fetchRequest()
        fr.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        return fr
    }()
    
//    init() {
//        observation = request.observe(\.predicate, options: [.old, .new]) { request, change in
//            if let newPredicate = change.newValue {
//                print("Surgical Alert: Predicate changed to: \(newPredicate?.predicateFormat ?? "nil")")
//            } else {
//                print("Predicate was cleared.")
//            }
//        }
//    }
//    
//    var observation: NSKeyValueObservation?
    
    // it is diffing because if i set the predicate to the same predicate then fetch doesnt happen
    
    var ascending = true {
        didSet {
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: ascending)]
           // if !ascending {
//                let oldRequest = request.copy() as! NSFetchRequest<Item>
//                if oldRequest == request {
//                    print("Malc")
//                }
//                let fr = Item.fetchRequest()
//                fr.sortDescriptors = []
                
             //   request.predicate = NSPredicate(format: "timestamp < %@", argumentArray: [Date.now])
              //  if oldRequest == request {
              //      print("Malc")
              //  }
                
                
                //fetchRequest = fr
            //}
        }
    }
}

let falsePredicate = NSPredicate(value: false)

struct Item2: Identifiable, Equatable {
    let id = UUID()
    var timestamp = Date.now
    
    static var sample: [Item2] {
        return [
            .init(timestamp: .distantPast), .init(), .init(timestamp: .distantFuture)
        ]
    }
}

struct SortedItems {
     var items: [Item2] {
        didSet {
            update()
        }
    }
    
    init(items: [Item2] = [], sortOrder: [KeyPathComparator<Item2>] = []) {
        self.items = items.sorted(using: sortOrder)
        self.sortOrder = sortOrder
        update()
    }
    
    private(set) var sortedItems: [Item2] = []
    
    var sortOrder: [KeyPathComparator<Item2>] {
        didSet {
            update()
        }
    }
    
    mutating func update(){
        sortedItems = items.sorted(using: sortOrder)
    }
    
}

struct FetchViewOriginal: View {
    
    // for testing body recomputation
    let counter: Int
    let myStore: MyStore
    // source of truth for the sort
    @State private var ascending = true
    @State private var ascending2 = true
    //@State var myFetch = MyFetch()
    
    // @Environment(\.managedObjectContext) private var viewContext
    
    // initial sort [] means random and it resets to this every time this View is re-init by the parent body.
    // we cannot use the value of ascending in this decleration to set the correct sort.
    //@FetchRequest(sortDescriptors: [], predicate: falsePredicate) var items: FetchedResults<Item>
    @State var items = Item2.sample
    @State var sortedItems = SortedItems()
    //@State var sortedItems = [Item2]()
    //@State var sortDescriptors = [KeyPathComparator<Item2>]()
    
//    var sortDescriptors: [SortDescriptor<Item2>] {
//        [SortDescriptor(\Item2.timestamp, order: ascending ? .forward : .reverse)]
//    }
//
//    var sortDescriptorsBinding: Binding<[SortDescriptor<Item2>]> {
//        Binding {
//            sortDescriptors
//        } set: { v in
//            ascending = v.first?.order == .forward
//        }
//    }
//    
//    
//    var fetchRequest: FetchRequest<Item> {
//        //FetchRequest(sortDescriptors: sortDescriptors)
//        FetchRequest(fetchRequest: myFetch.request, animation: .default)
//    }

    @State private var counter2 = 0
   
    var body: some View {
      //  VStack {
            //            NavigationLink("Test Link") {
            //                Text("Test")
            //                    .toolbar {
            //                        ToolbarItem {
            //                            Button {
            //                                let newItem = Item(context: viewContext)
            //                                newItem.timestamp = Date()
            //
            //                                do {
            //                                    try viewContext.save()
            //                                } catch {
            //                                    // Replace this implementation with code to handle the error appropriately.
            //                                    // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            //                                    let nsError = error as NSError
            //                                    fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            //                                }
            //                            } label: {
            //                                Label("Add Item", systemImage: "plus")
            //                            }
            //                        }
            //                    }
            //            }
            Button("Recompute \(counter2)") {
                counter2 += 1
            }
        Button("Add") {
           /// withAnimation {
            DispatchQueue.main.asyncAfter(deadline:.now() + 0) {
                items.append(.init())
            }
                
           // }
        }
            Button("ascending \(ascending)") {
              //  withAnimation {
                 ascending.toggle()
                //}
                
                //sortedItems.sortOrder = [KeyPathComparator(\Item2.timestamp, order: !ascending ? .forward : .reverse)]
                //}
                //if let sort = sortOrder.first {
                //     sortOrder = [sort.reversed()]
                // }
                //  }
            }
            //FetchedTable(ascending: $ascending)
            
        Table(sortedItems.sortedItems, sortOrder: $sortedItems.sortOrder.animation()) { //}, sortOrder: sortDescriptorsBinding) {
        //VStack {
                    //    ForEach(sortedItems.sortedItems) { item in
                //
                //TableColumn("timestamp" as LocalizedStringResource, value: \Item2.timestamp) { item in
                TableColumn("timestamp", value: \Item2.timestamp) { item in
                    //       NavigationLink {
                    //                        Text(item.timestamp!, format: Date.FormatStyle(date: .numeric, time: .standard))
                    //                            .toolbar {
                    //                                Button("Delete") {
                    //                                    viewContext.delete(item)
                    //                                }
                    //                            }
                    //                        } label: {
                    Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    //                        }
                    
                }
            }
        
       
        
        .onAppear {
            print("onAppear")
            sortedItems = SortedItems(items: items, sortOrder: [KeyPathComparator(\Item2.timestamp, order: ascending ? .forward : .reverse)])
        }
        .onChange(of: sortedItems.sortOrder) {
            let newAscending = sortedItems.sortOrder.first?.order == .forward
            // BREAK THE LOOP: Only write if the value is actually different
            if ascending != newAscending {
                ascending = newAscending
            }
        }
        .onChange(of: ascending) {
            //withAnimation {
            sortedItems.sortOrder = [KeyPathComparator(\Item2.timestamp, order: ascending ? .forward : .reverse)]
           // }
        }
        .onChange(of: items) {
           // withAnimation {
            sortedItems.items = items
           // }
        }
       
//        .onReceive(myStore.$count1) { c in
//            print("count1")
//        }
//        .onReceive(myStore.$count2) { c in
//            print("count2")
        //}
        
    }
  

    
//    struct FetchedResultsView<Content, Result>: View where Content: View, Result: NSFetchRequestResult {
//        @FetchRequest var results: FetchedResults<Result>
//        @ViewBuilder let content: (FetchedResults<Result>) -> Content
//        
//        var body: some View {
//            content(results)
//        }
//    }
}

//NSViewRepresentable ignores withAnimation when triggered via .onChange on macOS, unlike UIViewRepresentable on iOS
//import UIKit
//struct AnimatedBackgroundView: UIViewRepresentable {
//    let toggle: Bool
//    func makeUIView(context: Context) -> some UIView {
//        UIView()
//    }
//    
//    func updateUIView(_ uiView: UIViewType, context: Context) {
//        let targetColor = toggle ? UIColor.red : UIColor.blue
//        context.animate {
//            uiView.backgroundColor = targetColor
//        }
//        
//    }
//}



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
            //    List(results) { item in
            TableColumn("timestamp" as LocalizedStringResource, value: \.timestamp) { item in
                //       NavigationLink {
                //                        Text(item.timestamp!, format: Date.FormatStyle(date: .numeric, time: .standard))
                //                            .toolbar {
                //                                Button("Delete") {
                //                                    viewContext.delete(item)
                //                                }
                //                            }
                //                        } label: {
                Text(item.timestamp!, format: Date.FormatStyle(date: .numeric, time: .standard))
                //                        }
                
            }
        }
    }
}

//#Preview {
//    FetchViewOriginal(counter: 0)
//}
