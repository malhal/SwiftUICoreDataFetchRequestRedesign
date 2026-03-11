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
    
    //@State private var nsSortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
    @State private var ascending: Bool = true
    
    @State private var sortDescriptors: [SortDescriptor<Item>] = []
    static var falsePredicate = NSPredicate(value: false)
    
    @State private var predicate: NSPredicate? = Self.falsePredicate
    // source of truth for the sort can easily be persisted
   // @AppStorage("Ascending") private var ascendingStored = true
    
    // for testing body recomputation
    let counter: Int
    
//    var sortDescriptors: [SortDescriptor<Item>] {
//        [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
//    }
    
    @StateObject var myFetch = MyFetch()
    
    var fetchRequest2: FetchRequest2<Item> {
       // FetchRequest2(sortDescriptors: sortDescriptors, nsPredicate: predicate)
        FetchRequest2(fetchRequest: myFetch.request)
    }
    
    // gets the sort descriptor directly from the fetch.
    // transforms from the sort descriptors set by the table to the ascending state bool.
    var sortDescriptorsBinding: Binding<[SortDescriptor<Item>]> {
        Binding {
            sortDescriptors
        } set: { v in
            ascending = v.first?.order == .forward
            sortDescriptors = v
        }
    }
    
    var body: some View {
        VStack {
            FetchedResultsView(results: fetchRequest2) { result in
                switch(result) {
                    case let .failure(error):
                        Text(error.localizedDescription)
                    case let .success(items):
                        HStack {
//                            Button("Recompute \(counter2)") {
//                                counter2 += 1 // calls body
//
//                            }
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
            }
        }
        .onAppear {
            sortDescriptors = [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
            predicate = nil
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
        @FetchRequest2 var results: Result<[ResultType], Error>
        @ViewBuilder let content: (Result<[ResultType], Error>) -> Content
        
        var body: some View {
            content(results)
        }
    }
}

#Preview {
    FetchViewRedesign(counter: 0)
}
