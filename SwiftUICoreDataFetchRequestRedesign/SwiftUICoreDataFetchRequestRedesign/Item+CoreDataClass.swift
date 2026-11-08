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

    // This is a fix for FB25460082:
    // Properties being set to nil when an unsaved object is deleted which causes a List row animation glitch.
    var _timestampTombstone: Date?
    var timestampTombstone: Date? {
        let _ = timestamp // force awakeFromFetch
        return _timestampTombstone
    }

    // only called if a property is read
    override public func awakeFromFetch() {
        super.awakeFromFetch()
        _timestampTombstone = timestamp
    }
    
    // didChangeValue is called anyway, need to check for model editor defaults
//    override public func awakeFromInsert() {
//        super.awakeFromInsert()
//        _timestampTombstone = timestamp
//    }
    
    // not call to set to nil when unsaved inserted object is deleted
    public override func didChangeValue(forKey key: String) {
        super.didChangeValue(forKey: key)
        
        // Whenever the managed 'timestamp' property updates mirror it into our backup property.
        if key == "timestamp" {
            _timestampTombstone = timestamp
        }
    }
}
