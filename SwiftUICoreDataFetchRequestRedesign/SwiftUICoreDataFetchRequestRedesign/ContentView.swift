//
//  ContentView.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI
import CoreData
import Combine
import SwiftData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @State var counter = 0
    //@State var testChangingContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    @State var showRedesign = true
    
    var body: some View {
        NavigationStack {
            HStack {
                VStack {
                    Text("Launch on macOS or iPad landscape so sortable table headers appear. First click both headers to change the sort order of both tables, then click increment button. Notice Original loses the modified sort order but Redesign does not.").padding()
                    
                    Button("Increment \(counter)") {
                        counter += 1
                    }
                    Text("Increment counter causes FetchViewOriginal and FetchViewRedesign to be re-init.").padding()
                    
                }
                VStack {
                    FetchViewOriginal(counter: counter)
                }
                VStack {
                    Button(showRedesign ? "Hide" : "Show") {
                        showRedesign.toggle()
                    }
                    if showRedesign {
                        FetchViewRedesign(counter: counter)
                    }
                }
            }
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        }
        .onAppear {
            
//            let fr = Item.fetchRequest()
//            fr.sortDescriptors = []
//            let frc = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: viewContext, sectionNameKeyPath: nil, cacheName: nil)
//            try? frc.performFetch()
//            print("number \(frc.fetchedObjects?.count ?? -1)")
           // frc.fetchRequest.sortDescriptors = nil
            //frc.fetchRequest.predicate = NSPredicate(format: "timestamp == %@", "")
           // try? frc.performFetch()
          //  print("number \(frc.fetchedObjects?.count ?? -1)")
        }
    }
    
    private func addItem() {
        let newItem = Item(context: viewContext)
        newItem.timestamp = Date()
        withAnimation {
            viewContext.processPendingChanges() // required for row animation
        }
    }
}

@Model
class Item2 {
    var text: String?
    
    init() {
        
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
