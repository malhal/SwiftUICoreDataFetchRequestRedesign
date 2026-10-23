//
//  StaticFetchRequest.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 20/10/2026.
//

import Foundation
import SwiftUI
import CoreData
//
//@MainActor
//@propertyWrapper
//public struct FetchRequest2<Representable>: @preconcurrency DynamicProperty where Representable: NSFetchRequestRepresentable {
//    
//    @Environment(\.managedObjectContext) private var viewContext
//    @State private var observer = FetchedResultsObserver<Representable>()
//    private let representable: Representable
//    
//    public init(_ representable: Representable) {
//        self.representable = representable
//    }
//    
//    // Modern SortDescriptors (SwiftUI standard)
////    public init(sortDescriptors: [SortDescriptor<ResultType>], nsPredicate: NSPredicate? = nil, changesAnimation: Animation? = nil) {
////        self.config = .modern(sort: sortDescriptors, predicate: nsPredicate)
////        self.changesAnimation = changesAnimation
////    }
////    
////    // Legacy NSSortDescriptors
////    public init(nsSortDescriptors: [NSSortDescriptor], nsPredicate: NSPredicate? = nil, changesAnimation: Animation? = nil) {
////        self.config = .convenience(sort: nsSortDescriptors, predicate: nsPredicate)
////        self.changesAnimation = changesAnimation
////    }
////    
////    // Existing NSFetchRequest
////    public init(fetchRequest: NSFetchRequest<ResultType>, changesAnimation: Animation? = nil) {
////        self.config = .manual(fetchRequest)
////        self.changesAnimation = changesAnimation
////    }
////    
//    // 💡 Pure, beautiful implementation alignment
//    public private(set) var wrappedValue: FetchedResultsObserver<Representable>.State = ([], nil)
//    
//    public mutating func update() {
//        wrappedValue = observer.update(managedObjectContext: viewContext, representable: representable)
//    }
//}
//
//public enum FetchError: LocalizedError {
//    case missingContext
//    case missingSortDescriptors
//    case fetchFailure(Error)
//     
//    public var errorDescription: String? {
//        switch self {
//            case .missingSortDescriptors:
//                return "The operation couldn't be completed because the sortDescriptors is empty."
//            case .missingContext:
//                return "The operation couldn't be completed because the managedObjectContext is null."
//            case .fetchFailure(let error):
//                return error.localizedDescription
//        }
//    }
//}

