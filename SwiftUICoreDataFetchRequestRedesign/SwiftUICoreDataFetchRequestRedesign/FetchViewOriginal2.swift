//
//  FetchViewOriginal 2.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 24/07/2025.
//


//
//  TableView.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI
import CoreData

struct FetchViewOriginal2: View {
    
    // for testing body recomputation
    let counter: Int
    
    // source of truth for the sort
    @State private var ascending = true
    
    @Environment(\.managedObjectContext) private var viewContext
    
    // initial sort [] means random and it resets to this every time this View is re-init by the parent body.
    // we cannot use the value of ascending in this decleration to set the correct sort.
    @FetchRequest(sortDescriptors: [], predicate: NSPredicate(value: false)) var items: FetchedResults<Item>
  
    var sortDescriptors: [SortDescriptor<Item>] {
        [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
    }
    
    var sortDescriptorsBinding: Binding<[SortDescriptor<Item>]> {
        Binding {
            sortDescriptors
        } set: { v in
            ascending = v.first?.order == .forward
        }
    }
    
    @State private var counter2 = 0
    
    var body: some View {
        VStack {
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
            
            
            Table(items, sortOrder: sortDescriptorsBinding) {
                //    List(results) { item in
                TableColumn("timestamp", value: \.timestamp) { item in
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
            .onChange(of: ascending, initial: true) {
                items.nsPredicate = nil
                items.sortDescriptors = sortDescriptors // causes a fetch
            }
            
        }
    }
    
    struct FetchedResultsView<Content, Result>: View where Content: View, Result: NSFetchRequestResult {
        let request: FetchRequest<Result>
        @ViewBuilder let content: (FetchedResults<Result>) -> Content
        
        var results: FetchedResults<Result> {
            request.wrappedValue
        }
        
        var body: some View {
            content(results)
        }
    }
}

#Preview {
    FetchViewOriginal(counter: 0)
}
