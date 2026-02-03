//
//  TableView.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI
import CoreData

struct FetchViewOriginal: View {
    
    // for testing body recomputation
    let counter: Int
    
    // source of truth for the sort
    @State private var ascending = true
    
    @Environment(\.managedObjectContext) private var viewContext
    
    // initial sort [] means random and it resets to this every time this View is re-init by the parent body.
    // we cannot use the value of ascending in this decleration to set the correct sort.
//    @FetchRequest(sortDescriptors: []) var items: FetchedResults<Item>
  
    var sortDescriptors: [SortDescriptor<Item>] {
        [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
    }
    
    var fetchRequest: FetchRequest<Item> {
        FetchRequest(sortDescriptors: sortDescriptors)
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
            
            FetchedResultsView(results: fetchRequest) { results in
                Table(results, sortOrder: sortDescriptorsBinding) {
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
    }
    
    struct FetchedResultsView<Content, Result>: View where Content: View, Result: NSFetchRequestResult {
        @FetchRequest var results: FetchedResults<Result>
        @ViewBuilder let content: (FetchedResults<Result>) -> Content
        
        var body: some View {
            content(results)
        }
    }
}

#Preview {
    FetchViewOriginal(counter: 0)
}
