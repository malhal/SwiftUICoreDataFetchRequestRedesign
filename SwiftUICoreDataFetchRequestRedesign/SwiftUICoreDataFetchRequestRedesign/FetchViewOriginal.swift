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
    @State private var ascending = false

    @State private var counter2 = 0
   
    var body: some View {
        
        Button("Recompute \(counter2)") {
            counter2 += 1
        }
        Button("ascending \(ascending.description)") {
            //  withAnimation {
            ascending.toggle()
        }
        FetchedTable(ascending: $ascending)
    }
}

struct FetchedTable: View {
    @FetchRequest var items: FetchedResults<Item>
    @Binding var sortDescriptors: [SortDescriptor<Item>]
    
    init(ascending: Binding<Bool>) {
        let sortDescriptors = [SortDescriptor(\Item.timestamp, order: ascending.wrappedValue ? .forward : .reverse)]
        _items = FetchRequest(sortDescriptors: sortDescriptors, animation: .default)
        _sortDescriptors = Binding {
            sortDescriptors
        } set: { v in
            ascending.wrappedValue = v.first?.order == .forward
        }
    }
    
    var body: some View {
        Table(items, sortOrder: $sortDescriptors) {
            TableColumn("timestamp" as LocalizedStringResource, value: \.timestamp) { item in
                Text(item.timestamp!, format: Date.FormatStyle(date: .numeric, time: .standard))
            }
        }
    }
}

//struct FetchedTable: View {
//    // 1. Declare the property wrapper with SectionIdentifier (String) and Result (Item)
//    @SectionedFetchRequest<String?, Item> var sections: SectionedFetchResults<String?, Item>
//    @Binding var sortDescriptors: [SortDescriptor<Item>]
//    
//    init(ascending: Binding<Bool>) {
//        let order: Foundation.SortOrder = ascending.wrappedValue ? .forward : .reverse
//        
//        // CRITICAL CORE DATA RULE:
//        // The FIRST sort descriptor MUST match the section identifier property!
//        let sortDescriptors = [
//            SortDescriptor(\Item.text, order: order),
//            SortDescriptor(\Item.timestamp, order: order)
//        ]
//        
//        _sections = SectionedFetchRequest(
//            sectionIdentifier: \.text,
//            sortDescriptors: sortDescriptors,
//            animation: .default
//        )
//        
//        _sortDescriptors = Binding {
//            sortDescriptors
//        } set: { v in
//            ascending.wrappedValue = v.first?.order == .forward
//        }
//    }
//    
//    var body: some View {
//        let x = _sections.wrappedValue
//        // Sections can now be iterated over to render hierarchical tables or lists
//        List {
//            ForEach(sections) { section in
//                Section(header: Text("Category: \(section.id)")) {
//                    ForEach(section) { item in
//                        Text(item.timestamp!, format: Date.FormatStyle(date: .numeric, time: .standard))
//                    }
//                }
//            }
//        }
//    }
//}
