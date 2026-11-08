//
//  Item+CoreDataClass.swift
//  SwiftUICoreDataFetchRequestRedesign
//
//  Created by Malcolm Hall on 03/11/2026.
//
//

public import Foundation
public import CoreData

public typealias ItemCoreDataClassSet = NSSet

@objc(Item)
public class Item: NSManagedObject {

    var timestamp2: Date = Date()

    override public func awakeFromFetch() {
        super.awakeFromFetch()
        timestamp2 = timestamp ?? Date()
    }
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
    //    timestamp2 = timestamp ?? Date()
    }
    
    public override func didChangeValue(forKey key: String) {
        super.didChangeValue(forKey: key)
        
        // Whenever the managed 'timestamp' property updates,
        // immediately mirror it into our backup property.
        if key == "timestamp" {
            timestamp2 = timestamp ?? timestamp2
        }
    }
}
