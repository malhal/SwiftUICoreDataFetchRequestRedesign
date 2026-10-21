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
public struct FetchedResultsView<F, Content> where F: FetchRequestConfiguring {

    private let fetch: F
    private var content: ([F.ResultType], Error?) -> Content
    
    @State private var observer = FetchObserver<F>()
    
    @Environment(\.managedObjectContext) private var viewContext
    
    public init(
        _ fetch: F,
        @ViewBuilder content: @escaping ([F.ResultType], Error?) -> Content
    ) {
        self.fetch = fetch
        self.content = content
    }
}

// extension allows skipping the return in body
extension FetchedResultsView: View where Content: View {
    public var body: some View {
        let state = observer.update(managedObjectContext: viewContext, fetch: fetch)
        content(state.0, state.1)
    }
}
