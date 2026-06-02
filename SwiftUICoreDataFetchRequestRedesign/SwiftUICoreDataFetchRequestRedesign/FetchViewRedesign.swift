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
    
    static var falsePredicate = NSPredicate(value: false)
    
    @State private var ascending: Bool = true
    
    // source of truth for the sort can easily be persisted
    // @AppStorage("Ascending") private var ascendingStored = true
    
    // for testing body recomputation
    let counter: Int
    
    @State var toggle = false
    
    var fetchRequest: FetchRequest2<Item> {
        FetchRequest2(sortDescriptors: sortDescriptors, changesAnimation: .default)
    }
    
    // gets the sort descriptor directly from the fetch.
    // transforms from the sort descriptors set by the table to the ascending state bool.
    var sortDescriptors: [SortDescriptor<Item>] {
        [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
    }
    
    var sortDescriptorsBinding: Binding<[SortDescriptor<Item>]> {
        return Binding {
            sortDescriptors
        } set: { value in
            ascending = value.first?.order == .forward
        }
    }
    
    var body: some View {
        VStack {
            
            FetchRequestView(request: fetchRequest) { result in
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
                    Button("ascending \(ascending.description)") {
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
                Table(items, sortOrder: sortDescriptorsBinding) {
                    
                    TableColumn("timestamp" as LocalizedStringResource, value: \.timestamp) { item in
                        ItemRow(item: item)
                    }
                }
            }
        }
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
    
struct FetchRequestView<Content, ResultType>: View where Content: View, ResultType: NSManagedObject {
    @FetchRequest2 var request: FetchResult2<ResultType>
    @ViewBuilder let content: (FetchResult2<ResultType>) -> Content
    
    var body: some View {
        content(request)
    }
}

//#Preview {
//    FetchViewRedesign(counter: 0)
//}
