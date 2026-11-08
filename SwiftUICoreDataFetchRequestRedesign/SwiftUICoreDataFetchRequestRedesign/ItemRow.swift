//
//  ItemRow.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 02/11/2026.
//
import SwiftUI

struct ItemRow: View {
    @ObservedObject var item: Item
    
    var body: some View {
        Text(item.timestamp2, format: Date.FormatStyle(date: .numeric, time: .standard))
    }
}
