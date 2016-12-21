//
//  Catalog+SubitemMetadata.swift
//  Pods
//
//  Created by Stephan Heilner on 4/28/16.
//
//

import Foundation
import SQLite

public extension Catalog {
    
    class SubitemMetadataTable {
        
        static let table = Table("subitem_metadata")
        static let id = Expression<Int64>("_id")
        static let itemID = Expression<Int64>("item_id")
        static let subitemID = Expression<Int64>("subitem_id")
        static let docID = Expression<String>("doc_id")
        static let docVersion = Expression<Int>("doc_version")
        
    }
    
    public func itemAndSubitemIDForDocID(_ docID: String) -> (itemID: Int64, subitemID: Int64)? {
        do {
            return try db.pluck(SubitemMetadataTable.table.select(SubitemMetadataTable.itemID, SubitemMetadataTable.subitemID).filter(SubitemMetadataTable.docID == docID)).map { row in
                return (itemID: row[SubitemMetadataTable.itemID], subitemID: row[SubitemMetadataTable.subitemID])
            }
        } catch {
            return nil
        }
    }
    
    public func subitemIDForSubitemWithDocID(_ docID: String, itemID: Int64) -> Int64? {
        do {
            return try db.pluck(SubitemMetadataTable.table.select(SubitemMetadataTable.subitemID).filter(SubitemMetadataTable.docID == docID && SubitemMetadataTable.itemID == itemID)).map { row in
                return row[SubitemMetadataTable.subitemID]
            }
        } catch {
            return nil
        }
    }
    
    public func docIDForSubitemWithID(_ subitemID: Int64, itemID: Int64) -> String? {
        do {
            return try db.pluck(SubitemMetadataTable.table.select(SubitemMetadataTable.docID).filter(SubitemMetadataTable.subitemID == subitemID && SubitemMetadataTable.itemID == itemID)).map { row in
                return row[SubitemMetadataTable.docID]
            }
        } catch {
            return nil
        }
    }
    
    public func versionsForDocIDs(_ docIDs: [String]) -> [String: Int] {
        do {
            let results = try db.prepare(SubitemMetadataTable.table.select(SubitemMetadataTable.docID, SubitemMetadataTable.docVersion).filter(docIDs.contains(SubitemMetadataTable.docID))).map { row in
                return (row[SubitemMetadataTable.docID], row[SubitemMetadataTable.docVersion])
            }
            return Dictionary(results)
        } catch {
            return [:]
        }
    }
    
    public func maxSubitemMetadataID() -> Int64? {
        do {
            return try db.scalar(SubitemMetadataTable.table.select(SubitemMetadataTable.id.max))
        } catch {
            return 0
        }
    }
    
}
