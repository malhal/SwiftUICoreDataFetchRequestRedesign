//
//  Fetch.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 16/10/2026.
//

import CoreData
import SwiftUI
import Combine

@MainActor
public struct FetchedResultsView<F, Content> where F: NSFetchRequestRepresentable {

    private let representable: F
    private var content: ([F.ResultType], Error?) -> Content
    
    @State private var observer = FetchedResultsObserver<F>()
    
    @Environment(\.managedObjectContext) private var viewContext
    
    public init(
        _ representable: F,
        @ViewBuilder content: @escaping ([F.ResultType], Error?) -> Content
    ) {
        self.representable = representable
        self.content = content
    }
}

// extension allows skipping the return in body
extension FetchedResultsView: View where Content: View {
    public var body: some View {
        let state = observer.update(managedObjectContext: viewContext, representable: representable)
        content(state.results, state.error)
    }
}
