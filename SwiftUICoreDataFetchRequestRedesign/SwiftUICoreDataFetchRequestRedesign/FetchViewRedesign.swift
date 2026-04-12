//
//  FetchViewRedesign.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI
import CoreData
import Combine
class TestObject: ObservableObject {
    
    var _result = MyResult()
    func invalidate() {
        objectWillChange.send()
        _result.random = 0
    }
    var result: MyResult {
        if _result.random == 0 {
            _result.random = Int.random(in: 0...Int.max)
        }
        return _result
    }
}

struct MyResult {
    var random = 0
}

struct FetchViewRedesign: View {
    @Environment(\.managedObjectContext) var viewContext
    
    //@State private var sortDescriptors2: [SortDescriptor<Item>] = [SortDescriptor(\Item.timestamp, order: .reverse)]
    static var falsePredicate = NSPredicate(value: false)
    //@State private var nsPredicate: NSPredicate? = falsePredicate
    //@State private var nsSortDescriptors: [NSSortDescriptor] = []
    
    @State private var ascending: Bool = true
    
    // source of truth for the sort can easily be persisted
    // @AppStorage("Ascending") private var ascendingStored = true
    
    // for testing body recomputation
    let counter: Int
    
    //    var sortDescriptors: [SortDescriptor<Item>] {
    //        [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
    //    }
    
    @StateObject var testObject = TestObject()
    
    //@State var myFetch = MyFetch()
    @State var toggle = false
    @StateObject var fetchController = FetchController2<Item>(changesAnimation: .default)//sortDescriptors: [], nsPredicate: Self.falsePredicate)
    
    //    var fetchRequest: FetchRequest2<Item> {
    //        FetchRequest2(nsSortDescriptors: nsSortDescriptors, changesAnimation: .default)
    //      //  FetchRequest2(fetchRequest: myFetch.request, changesAnimation: .default)
    //    }
    
    
    // gets the sort descriptor directly from the fetch.
    // transforms from the sort descriptors set by the table to the ascending state bool.
    var sortDescriptors: Binding<[SortDescriptor<Item>]> {
        return Binding {
            //fetchController.fetchRequest.sortDescriptors?.compactMap { SortDescriptor<Item>($0, comparing: Item.self)  } ?? []
            [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
        } set: { value in
            //fetchController.fetchRequest.sortDescriptors = value.map { NSSortDescriptor($0) }
            //   withTransaction(transaction) {
            ascending = value.first?.order == .forward
            //   updateNSSortDescriptors()
            // }
        }
    }
    
    @State var text = ""
    
    func updateNSSortDescriptors() {
        fetchController.fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: ascending)]
    }
    
    //    var nsSortDescriptors: [NSSortDescriptor] {
    //        [NSSortDescriptor(keyPath: \Item.timestamp, ascending: ascending)]
    //    }
    
    //    func updateController() {
    //        if fetchController.managedObjectContext != viewContext {
    //            fetchController.managedObjectContext = viewContext
    //        }
    //
    //        if fetchController.nsSortDescriptors?.first?.ascending != ascending {
    //            fetchController.nsSortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: ascending)]
    //        }
    //    }
    
    
    var body: some View {
        // let _ = updateController()
        //let _ = fetchController.update(nsSortDescriptors: nsSortDescriptors, nsPredicate: nsPredicate, managedObjectContext: viewContext)
        VStack {
            
            Text(testObject.result.random, format: .number)
            let result = fetchController.result // (nsSortDescriptors: nsSortDescriptors, managedObjectContext: viewContext)
            //  FetchedResultsView(result: fetchRequest) { result in
            let items = result.objects
            //                switch(result) {
            //                    case let .failure(error):
            //                        Text(error.localizedDescription)
            //                    case let .success(items):
            HStack {
                //                            Button("Recompute \(counter2)") {
                //                                counter2 += 1 // calls body
                //
                //                            }
                Button("ascending \(ascending)") {
                    //     withAnimation {
                    ascending.toggle()
                    //     }
                    
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
            //List {
            // ForEach(items) { item in
            Table(items, sortOrder: sortDescriptors) {
                
                TableColumn("timestamp" as LocalizedStringResource, value: \.timestamp) { item in
                    ItemRow(item: item)
                }
            }
            
            
            // .animation(.default, value: nsSortDescriptors)
        }
        .onAppear {
            fetchController.managedObjectContext = viewContext
            updateNSSortDescriptors()
        }
        .onChange(of: viewContext) {
            fetchController.managedObjectContext = viewContext
        }
        .onChange(of: ascending) {
            updateNSSortDescriptors()
        }
        
        //
        //      let fr = fetchController.fetchRequest//.copy() as! NSFetchRequest<Item>
        //      fr.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: ascending)]
        // fetchController.fetchRequest = fr
        
        //testObject.random = Int.random(in: 0...Int.max)
        // testObject.invalidate()
        //  }
        //nsSortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: ascending)]
    }
}
    
    struct ItemRow: View {
        @ObservedObject var item: Item
        
        var body: some View {
            Text(item.timestamp!, format: Date.FormatStyle(date: .numeric, time: .standard))
        }
    }
    
    //        var body: some View {
    //            let _ = print(Self._printChanges())
    //            resultsView
    //                .task(id: FetchID(context: viewContext, sort: sortDescriptors)) {
    //                    let fr = Item.fetchRequest()
    //                    fr.sortDescriptors = sortDescriptors.map { NSSortDescriptor($0) }
    //                    do {
    //                        for try await updates in FetchResults.updates(for: fr, in: viewContext) {
    //                            result = .success(updates)
    //                        }
    //                    }catch {
    //                        result = .failure(error)
    //                    }
    //                }
    //        }
    
struct FetchedResultsView<Content, ResultType>: View where Content: View, ResultType: NSManagedObject {
    @FetchRequest2 var result: FetchResult<ResultType>
    @ViewBuilder let content: (FetchResult<ResultType>) -> Content
    
    var body: some View {
        content(result)
    }
}

//#Preview {
//    FetchViewRedesign(counter: 0)
//}
