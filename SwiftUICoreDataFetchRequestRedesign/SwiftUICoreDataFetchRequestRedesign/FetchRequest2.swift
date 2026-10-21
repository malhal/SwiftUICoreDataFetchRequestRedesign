//
//  StaticFetchRequest.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 20/10/2026.
//


import Foundation
import SwiftUI
import CoreData
import Combine

public protocol SortDescriptorConfiguring: FetchRequestConfiguring {
    init(sortDescriptors: [SortDescriptor<ResultType>])
}



extension FetchRequest2 where F: SortDescriptorConfiguring {
    public init(sortDescriptors: [SortDescriptor<F.ResultType>]) {
        self.init(F(sortDescriptors: sortDescriptors))
    }
}

@MainActor
@propertyWrapper
public struct FetchRequest2<F>: @preconcurrency DynamicProperty where F: FetchRequestConfiguring {
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var observer = FetchObserver<F>()
    private let fetch: F
    
    public init(_ fetch: F) {
        self.fetch = fetch
    }
    
    // Modern SortDescriptors (SwiftUI standard)
//    public init(sortDescriptors: [SortDescriptor<ResultType>], nsPredicate: NSPredicate? = nil, changesAnimation: Animation? = nil) {
//        self.config = .modern(sort: sortDescriptors, predicate: nsPredicate)
//        self.changesAnimation = changesAnimation
//    }
//    
//    // Legacy NSSortDescriptors
//    public init(nsSortDescriptors: [NSSortDescriptor], nsPredicate: NSPredicate? = nil, changesAnimation: Animation? = nil) {
//        self.config = .convenience(sort: nsSortDescriptors, predicate: nsPredicate)
//        self.changesAnimation = changesAnimation
//    }
//    
//    // Existing NSFetchRequest
//    public init(fetchRequest: NSFetchRequest<ResultType>, changesAnimation: Animation? = nil) {
//        self.config = .manual(fetchRequest)
//        self.changesAnimation = changesAnimation
//    }
//    
    // 💡 Pure, beautiful implementation alignment
    public private(set) var  wrappedValue: [F.ResultType] = []
    public private(set) var lastError: Error?
    
    public mutating func update() {
        let state = observer.update(managedObjectContext: viewContext, fetch: fetch)
        wrappedValue = state.results
        lastError = state.error
    }
}

public enum FetchError: LocalizedError {
    case missingContext
    case missingSortDescriptors
    case fetchFailure(Error)
     
    public var errorDescription: String? {
        switch self {
            case .missingSortDescriptors:
                return "The operation couldn't be completed because the sortDescriptors is empty."
            case .missingContext:
                return "The operation couldn't be completed because the managedObjectContext is null."
            case .fetchFailure(let error):
                return error.localizedDescription
        }
    }
}

