//
//  FetchViewRedesign.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 12/11/2024.
//

import SwiftUI

fileprivate let fetchRequest = {
    let fr = Item.fetchRequest()
    fr.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
    return fr
}()

struct MyView: View {
    static let colors: [Color] = [.red, .green, .purple, .yellow, .blue, .orange, .teal]
    
    @State var color = Self.colors[0]
    @State var counter = 0
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 50, height: 50)
            .shadow(radius: 3)
            .overlay {
                Text("\(counter)")
            }
            .padding(20)
    }
}



struct FetchViewRedesign: View {
    static var myImage: NSImage?
    @Environment(\.managedObjectContext) var viewContext
    @State private var ascending: Bool = false
    
    // source of truth for the sort can easily be persisted
    @AppStorage("Ascending") private var ascendingStored = false
    
    // for testing body recomputation
    let counter: Int
    
    @FetchRequest2(intialSortDescriptors: [], initialNSPredicate: NSPredicate(value: false)) var result: Result<[Item], Error> // false predicate is a constant NSFalsePredicate that prevents the inital fetch with no sort from doing anything.
    
    // gets the sort descriptor directly from the fetch.
    // transforms from the sort descriptors set by the table to the ascending state bool.
    var sortDescriptorsBinding: Binding<[SortDescriptor<Item>]> {
        Binding {
            _result.sortDescriptors
        } set: { v in
            // after this, the onChange will set the new sortDescriptor.
            ascending = v.first?.order == .forward
        }
    }
    
    @State var counter2 = 0

    var body: some View {
        Button("Recompute \(counter2)") {
            counter2 += 1 // calls body
        }
        Group {
            switch(result) {
                case let .failure(error):
                    Text(error.localizedDescription)
                case let .success(items):
                    Table(items, sortOrder: sortDescriptorsBinding) {
                        TableColumn("timestamp", value: \.timestamp) { item in
                            Text(item.timestamp!, format: Date.FormatStyle(date: .numeric, time: .standard))
                        }
                    }
            }
        }
        .onChange(of: ascending, initial: true) {
            _result.sortDescriptors = [SortDescriptor(\Item.timestamp, order: ascending ? .forward : .reverse)]
            _result.nsPredicate = nil // clear the false predicate
        }
    }
}

#Preview {
    FetchViewRedesign(counter: 0)
}
