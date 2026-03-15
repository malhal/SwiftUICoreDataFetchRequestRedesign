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
    
    //@State private var sortDescriptors: [SortDescriptor<Item>] = []
    static var falsePredicate = NSPredicate(value: false)
    //@State private var nsPredicate: NSPredicate? =
    
    @State private var ascending: Bool = true
    //@State private var nsSortDescriptors: [NSSortDescriptor] = []
    
    // source of truth for the sort can easily be persisted
   // @AppStorage("Ascending") private var ascendingStored = true
    
    // for testing body recomputation
    let counter: Int
    
    var sortDescriptors: [SortDescriptor<Item>] {
        [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
    }
    
    //@State var myFetch = MyFetch()
    @State var toggle = false
    //@StateObject var fetchController = FetchController2<Item>(changesAnimation: .default)//sortDescriptors: [], nsPredicate: Self.falsePredicate)
    
    
    var fetchRequest: FetchRequest2<Item> {
        FetchRequest2(sortDescriptors: sortDescriptors, changesAnimation: .default)
    }
    
    // gets the sort descriptor directly from the fetch.
    // transforms from the sort descriptors set by the table to the ascending state bool.
    var sortDescriptorsBinding: Binding<[SortDescriptor<Item>]> {
        Binding {
            sortDescriptors
        } set: { v in
            ascending = v.first?.order == .forward
        }
    }
    
//    func updateNSSortDescriptors() {
//        fetchController.nsSortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: ascending)]
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
            // let items = fetchController.fetchedObjects
            FetchedResultsView(result: fetchRequest) { result in
                let items = result.objects
                //let items = fetchController.result.objects
                //                switch(result) {
                //                    case let .failure(error):
                //                        Text(error.localizedDescription)
                //                    case let .success(items):
                HStack {
                    //                            Button("Recompute \(counter2)") {
                    //                                counter2 += 1 // calls body
                    //
                    //                            }
                    Button("toggle \(toggle)") {
                        toggle.toggle()
                        if toggle {
                            //fetchController.fetchRequest = myFetch.request
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
                
                Table(items, sortOrder: sortDescriptorsBinding) {
                    TableColumn("timestamp" as LocalizedStringResource, value: \.timestamp) { item in
                        ItemRow(item: item)
                    }
                }
            }
//            .onAppear {
//                fetchController.nsPredicate = nil
//                fetchController.managedObjectContext = viewContext
//                updateNSSortDescriptors()
//            }
//            .onChange(of: viewContext) {
//                fetchController.managedObjectContext = viewContext
//            }
//            .onChange(of: ascending) {
//                updateNSSortDescriptors()
//            }
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
}

//#Preview {
//    FetchViewRedesign(counter: 0)
//}
