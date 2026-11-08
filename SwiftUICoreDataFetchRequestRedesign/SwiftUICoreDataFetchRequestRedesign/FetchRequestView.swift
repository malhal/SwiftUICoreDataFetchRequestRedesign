//
//  FetchRequestView.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 03/11/2026.
//
import CoreData
import SwiftUI

public struct FetchRequestView<T: NSManagedObject, Content: View>: View {
    
    @FetchRequest private var results: FetchedResults<T>
    private let content: (FetchedResults<T>) -> Content

    public init(
        _ request: FetchRequest<T>,
        @ViewBuilder content: @escaping (FetchedResults<T>) -> Content
    ) {
        self._results = request
        self.content = content
    }

    public var body: some View {
        content(results)
    }
}
