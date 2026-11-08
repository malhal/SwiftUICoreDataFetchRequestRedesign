//
//  Fetch.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 16/10/2026.
//

import SwiftUI
import CoreData

public struct FetchRequest2View<ResultType: NSFetchRequestResult, Content: View>: View {
    let fetchRequest: FetchRequest2<ResultType>
    var results: [ResultType] {
        fetchRequest.wrappedValue
    }
    
    private let content: ([ResultType], FetchRequest2<ResultType>.Config) -> Content
    
    public init(
        _ fetchRequest: FetchRequest2<ResultType>,
        @ViewBuilder content: @escaping ([ResultType], FetchRequest2<ResultType>.Config) -> Content
    ) {
        self.fetchRequest = fetchRequest
        self.content = content
    }
    
    public var body: some View {
        content(results, fetchRequest.projectedValue)
    }
}
