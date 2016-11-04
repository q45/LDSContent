//
// Copyright (c) 2016 Hilton Campbell
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import Foundation
import SQLite
import Swiftification

public class Catalog {
    
    /// The current schema version.
    ///
    /// The value is stored in `Schema.json`, so that it can also be read from scripts.
    public static let SchemaVersion: Int = {
        guard let
            path = Bundle(for: Catalog.self).path(forResource: "Schema", ofType: "json"),
            let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
            let dictionary = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String:Int],
            let schemaVersion = dictionary["schemaVersion"] else { fatalError("Failed to load schema version") }
        return schemaVersion
    }()
    
    let db: Connection
    let noDiacritic: ((Expression<String>) -> Expression<String>)
    
    let validPlatformIDs = [Platform.all.rawValue, Platform.iOS.rawValue]
    
    public init(path: String? = nil, readonly: Bool = true) throws {
        do {
            db = try Connection(path ?? "", readonly: readonly)
            db.busyTimeout = 5
        } catch {
            throw error
        }
            
        do {
            try db.execute("PRAGMA synchronous = OFF")
            try db.execute("PRAGMA journal_mode = OFF")
            try db.execute("PRAGMA temp_store = MEMORY")
            
            if readonly {
                // Only disable foreign keys when using as a readonly database for better performance
                try db.execute("PRAGMA foreign_keys = OFF")
            }
            
            noDiacritic = try db.createFunction("noDiacritic", deterministic: true) { (string: String) -> String in
                return string.withoutDiacritics()
            }
        } catch {
            throw error
        }
    }
    
    public func inTransaction(_ closure: @escaping () throws -> Void) throws {
        let inTransactionKey = "txn:\(Unmanaged.passUnretained(self).toOpaque())"
        if Thread.current.threadDictionary[inTransactionKey] != nil {
            try closure()
        } else {
            Thread.current.threadDictionary[inTransactionKey] = true
            defer { Thread.current.threadDictionary.removeObject(forKey: inTransactionKey) }
            try db.transaction {
                try closure()
            }
        }
    }
    
    public var schemaVersion: Int {
        return self.intForMetadataKey("schemaVersion") ?? 0
    }
    
    public var catalogVersion: Int {
        return self.intForMetadataKey("catalogVersion") ?? 0
    }
    
}

extension Catalog {
    
    class MetadataTable {
        
        static let table = Table("metadata")
        static let key = Expression<String>("key")
        static let integerValue = Expression<Int>("value")
        static let stringValue = Expression<String>("value")
        
    }
    
    func intForMetadataKey(_ key: String) -> Int? {
        do {
            return try db.pluck(MetadataTable.table.filter(MetadataTable.key == key).select(MetadataTable.stringValue)).flatMap { row in
                let string = row[MetadataTable.stringValue]
                return Int(string)
            }
        } catch {
            return nil
        }
    }
    
    func stringForMetadataKey(_ key: String) -> String? {
        do {
            return try db.pluck(MetadataTable.table.filter(MetadataTable.key == key).select(MetadataTable.stringValue)).map { return $0[MetadataTable.stringValue] }
        } catch {
            return nil
        }
    }
    
}

extension Catalog {
    
    class SourceTable {
        
        static let table = Table("source")
        static let id = Expression<Int64>("_id")
        static let name = Expression<String>("name")
        static let typeID = Expression<Int>("type_id")
        
        static func fromRow(_ row: Row) -> Source {
            return Source(id: row[id], name: row[name], type: SourceType(rawValue: row[typeID]) ?? .standard)
        }
        
    }
    
    public func sources() -> [Source] {
        do {
            return try db.prepare(SourceTable.table).map { row in
                return SourceTable.fromRow(row)
            }
        } catch {
            return []
        }
    }
    
    public func sourceWithID(_ id: Int64) -> Source? {
        do {
            return try db.pluck(SourceTable.table.filter(SourceTable.id == id)).map { SourceTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    public func sourceWithName(_ name: String) -> Source? {
        do {
            return try db.pluck(SourceTable.table.filter(SourceTable.name == name)).map { SourceTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
}

extension Catalog {
    
    class ItemCategoryTable {
        
        static let table = Table("item_category")
        static let id = Expression<Int64>("_id")
        static let name = Expression<String>("name")
        
        static func fromRow(_ row: Row) -> ItemCategory {
            return ItemCategory(id: row[id], name: row[name])
        }
        
    }
    
    public func itemCategoryWithID(_ id: Int64) -> ItemCategory? {
        do {
            return try db.pluck(ItemCategoryTable.table.filter(ItemCategoryTable.id == id)).map { ItemCategoryTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
}

extension Catalog {
    
    class ItemTable {
        
        static let table = Table("item")
        static let id = Expression<Int64>("_id")
        static let externalID = Expression<String>("external_id")
        static let languageID = Expression<Int64>("language_id")
        static let sourceID = Expression<Int64>("source_id")
        static let platformID = Expression<Int>("platform_id")
        static let uri = Expression<String>("uri")
        static let title = Expression<String>("title")
        static let itemCoverRenditions = Expression<String?>("item_cover_renditions")
        static let itemCategoryID = Expression<Int64>("item_category_id")
        static let version = Expression<Int>("version")
        static let obsolete = Expression<Bool>("is_obsolete")
        
        static func fromRow(_ row: Row) -> Item {
            return Item(id: row[id], externalID: row[externalID], languageID: row[languageID], sourceID: row[sourceID], platform: Platform(rawValue: row[platformID]) ?? .all, uri: row[uri], title: row[title], itemCoverRenditions: row[itemCoverRenditions].flatMap { $0.toImageRenditions() }, itemCategoryID: row[itemCategoryID], version: row[version], obsolete: row[obsolete])
        }
        
        static func fromNamespacedRow(_ row: Row) -> Item {
            return Item(id: row[ItemTable.table[id]], externalID: row[ItemTable.table[externalID]], languageID: row[ItemTable.table[languageID]], sourceID: row[ItemTable.table[sourceID]], platform: Platform(rawValue: row[ItemTable.table[platformID]]) ?? .all, uri: row[ItemTable.table[uri]], title: row[ItemTable.table[title]], itemCoverRenditions: row[ItemTable.table[itemCoverRenditions]].flatMap { $0.toImageRenditions() }, itemCategoryID: row[ItemTable.table[itemCategoryID]], version: row[ItemTable.table[version]], obsolete: row[ItemTable.table[obsolete]])
        }
        
    }
    
    public func items() -> [Item] {
        do {
            return try db.prepare(ItemTable.table).map { ItemTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    public func itemsForLibraryCollectionWithID(_ id: Int64) -> [Item] {
        do {
            return try db.prepare(ItemTable.table.join(LibraryItemTable.table, on: ItemTable.table[ItemTable.id] == LibraryItemTable.itemID).join(LibrarySectionTable.table, on: LibraryItemTable.librarySectionID == LibrarySectionTable.table[LibrarySectionTable.id]).filter(LibrarySectionTable.libraryCollectionID == id && validPlatformIDs.contains(ItemTable.platformID)).order(LibraryItemTable.position)).map { ItemTable.fromNamespacedRow($0) }
        } catch {
            return []
        }
    }
    
    public func itemsWithURIsIn(_ uris: [String], languageID: Int64) -> [Item] {
        do {
            return try db.prepare(ItemTable.table.filter(uris.contains(ItemTable.uri) && ItemTable.languageID == languageID && validPlatformIDs.contains(ItemTable.platformID))).map { ItemTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    public func itemsWithSourceID(_ sourceID: Int64) -> [Item] {
        do {
            return try db.prepare(ItemTable.table.filter(ItemTable.sourceID == sourceID && validPlatformIDs.contains(ItemTable.platformID))).map { ItemTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    public func itemsWithIDsIn(_ ids: [Int64]) -> [Item] {
        do {
            return try db.prepare(ItemTable.table.filter(ids.contains(ItemTable.id) && validPlatformIDs.contains(ItemTable.platformID))).map { ItemTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    public func itemsWithIDsIn(_ ids: [Int64], languageID: Int64) -> [Item] {
        do {
            return try db.prepare(ItemTable.table.filter(ids.contains(ItemTable.id) && validPlatformIDs.contains(ItemTable.platformID) && ItemTable.languageID == languageID)).map { ItemTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    @available(*, deprecated: 1.0.0, message: "Use `itemsWithIDsIn(_:)` instead")
    public func itemsWithExternalIDsIn(_ externalIDs: [String]) -> [Item] {
        do {
            return try db.prepare(ItemTable.table.filter(externalIDs.contains(ItemTable.externalID) && validPlatformIDs.contains(ItemTable.platformID))).map { ItemTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    public func itemWithID(_ id: Int64) -> Item? {
        do {
            return try db.pluck(ItemTable.table.filter(ItemTable.id == id && validPlatformIDs.contains(ItemTable.platformID))).map { ItemTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    @available(*, deprecated: 1.0.0, message: "Use `itemWithID(_:)` instead")
    public func itemWithExternalID(_ externalID: String) -> Item? {
        do {
            return try db.pluck(ItemTable.table.filter(ItemTable.externalID == externalID && validPlatformIDs.contains(ItemTable.platformID))).map { ItemTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    public func itemWithURI(_ uri: String, languageID: Int64) -> Item? {
        do {
            return try db.pluck(ItemTable.table.filter(ItemTable.uri == uri && ItemTable.languageID == languageID && validPlatformIDs.contains(ItemTable.platformID))).map { ItemTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    public func itemsWithTitlesThatContainString(_ string: String, languageID: Int64, limit: Int) -> [Item] {
        do {
            return try db.prepare(ItemTable.table.filter(noDiacritic(ItemTable.title).like("%\(string.withoutDiacritics().escaped())%", escape: "!") && ItemTable.languageID == languageID && validPlatformIDs.contains(ItemTable.platformID)).limit(limit)).map { ItemTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    public func itemThatContainsURI(_ uri: String, languageID: Int64) -> Item? {
        do {
            var prefix = uri
            while !prefix.isEmpty && prefix != "/" {
                if let item = try db.pluck(ItemTable.table.filter(ItemTable.uri == prefix && ItemTable.languageID == languageID && validPlatformIDs.contains(ItemTable.platformID))).map({ ItemTable.fromRow($0) }) {
                    return item
                }
                prefix = (prefix as NSString).deletingLastPathComponent
            }
            return nil
        } catch {
            return nil
        }
    }
    
    
}

extension Catalog {
    
    class LanguageTable {
        
        static let table = Table("language")
        static let id = Expression<Int64>("_id")
        static let ldsLanguageCode = Expression<String>("lds_language_code")
        static let iso639_3Code = Expression<String>("iso639_3")
        static let bcp47Code = Expression<String?>("bcp47")
        static let rootLibraryCollectionID = Expression<Int64>("root_library_collection_id")
        static let rootLibraryCollectionExternalID = Expression<String>("root_library_collection_external_id")
        
        static func fromRow(_ row: Row) -> Language {
            return Language(id: row[id], ldsLanguageCode: row[ldsLanguageCode], iso639_3Code: row[iso639_3Code], bcp47Code: row[bcp47Code], rootLibraryCollectionID: row[rootLibraryCollectionID], rootLibraryCollectionExternalID: row[rootLibraryCollectionExternalID])
        }
        
    }
    
    public func languages() -> [Language] {
        do {
            return try db.prepare(LanguageTable.table).map { LanguageTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    public func languageWithID(_ id: Int64) -> Language? {
        do {
            return try db.pluck(LanguageTable.table.filter(LanguageTable.id == id)).map { LanguageTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    public func languageWithISO639_3Code(_ iso639_3Code: String) -> Language? {
        do {
            return try db.pluck(LanguageTable.table.filter(LanguageTable.iso639_3Code == iso639_3Code)).map { LanguageTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    public func languageWithBCP47Code(_ bcp47Code: String) -> Language? {
        do {
            return try db.pluck(LanguageTable.table.filter(LanguageTable.bcp47Code == bcp47Code)).map { LanguageTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    public func languageWithLDSLanguageCode(_ ldsLanguageCode: String) -> Language? {
        do {
            return try db.pluck(LanguageTable.table.filter(LanguageTable.ldsLanguageCode == ldsLanguageCode)).map { LanguageTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    public func languageWithRootLibraryCollectionID(_ rootLibraryCollectionID: Int64) -> Language? {
        do {
            return try db.pluck(LanguageTable.table.filter(LanguageTable.rootLibraryCollectionID == rootLibraryCollectionID)).map { LanguageTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    @available(*, deprecated: 1.0.0, message: "Use `languageWithRootLibraryCollectionID(_:)` instead")
    public func languageWithRootLibraryCollectionExternalID(_ rootLibraryCollectionExternalID: String) -> Language? {
        do {
            return try db.pluck(LanguageTable.table.filter(LanguageTable.rootLibraryCollectionExternalID == rootLibraryCollectionExternalID)).map { LanguageTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
}

extension Catalog {
    
    class LanguageNameTable {
        
        static let table = Table("language_name")
        static let id = Expression<Int64>("_id")
        static let languageID = Expression<Int64>("language_id")
        static let localizationLanguageID = Expression<Int64>("localization_language_id")
        static let name = Expression<String>("name")
        
    }

    public func nameForLanguageWithID(_ languageID: Int64, inLanguageWithID localizationLanguageID: Int64) -> String? {
        // TODO: Switch back to use `db.scalar` when it doesn't crash
        do {
            let rows = try db.prepare(LanguageNameTable.table.select(LanguageNameTable.name).filter(LanguageNameTable.languageID == languageID && LanguageNameTable.localizationLanguageID == localizationLanguageID).limit(1))
            return Array(rows).first?[LanguageNameTable.name]
        } catch {
            return nil
        }
    }
    
}

extension Catalog {
    
    class LibrarySectionTable {
        
        static let table = Table("library_section")
        static let id = Expression<Int64>("_id")
        static let externalID = Expression<String>("external_id")
        static let libraryCollectionID = Expression<Int64>("library_collection_id")
        static let libraryCollectionExternalID = Expression<String>("library_collection_external_id")
        static let position = Expression<Int>("position")
        static let title = Expression<String?>("title")
        static let indexTitle = Expression<String?>("index_title")
        
        static func fromRow(_ row: Row) -> LibrarySection {
            return LibrarySection(id: row[id], externalID: row[externalID], libraryCollectionID: row[libraryCollectionID], libraryCollectionExternalID: row[libraryCollectionExternalID], position: row[position], title: row[title], indexTitle: row[indexTitle])
        }
        
    }
    
    public func librarySectionsForLibraryCollectionWithID(_ id: Int64) -> [LibrarySection] {
        do {
            return try db.prepare(LibrarySectionTable.table.filter(LibrarySectionTable.libraryCollectionID == id).order(LibrarySectionTable.position)).map { LibrarySectionTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    @available(*, deprecated: 1.0.0, message: "Use `librarySectionsForLibraryCollectionWithID(_:)` instead")
    public func librarySectionsForLibraryCollectionWithExternalID(_ externalID: String) -> [LibrarySection] {
        do {
            return try db.prepare(LibrarySectionTable.table.filter(LibrarySectionTable.libraryCollectionExternalID == externalID).order(LibrarySectionTable.position)).map { LibrarySectionTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    public func librarySectionWithID(_ id: Int64) -> LibrarySection? {
        do {
            return try db.pluck(LibrarySectionTable.table.filter(LibrarySectionTable.id == id)).map { LibrarySectionTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    @available(*, deprecated: 1.0.0, message: "Use `librarySectionWithID(_:)` instead")
    public func librarySectionWithExternalID(_ externalID: String) -> LibrarySection? {
        do {
            return try db.pluck(LibrarySectionTable.table.filter(LibrarySectionTable.externalID == externalID)).map { LibrarySectionTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
}

extension Catalog {
    
    class LibraryCollectionTable {
        
        static let table = Table("library_collection")
        static let id = Expression<Int64>("_id")
        static let externalID = Expression<String>("external_id")
        static let librarySectionID = Expression<Int64?>("library_section_id")
        static let librarySectionExternalID = Expression<String?>("library_section_external_id")
        static let position = Expression<Int>("position")
        static let titleHTML = Expression<String>("title_html")
        static let coverRenditions = Expression<String?>("cover_renditions")
        static let typeID = Expression<Int>("type_id")
        
        static func fromRow(_ row: Row) -> LibraryCollection {
            return LibraryCollection(id: row[id], externalID: row[externalID], librarySectionID: row[librarySectionID], librarySectionExternalID: row[librarySectionExternalID], position: row[position], titleHTML: row[titleHTML], coverRenditions: row[coverRenditions].flatMap { $0.toImageRenditions() }, type: LibraryCollectionType(rawValue: row[typeID]) ?? .standard)
        }
        
        static func fromNamespacedRow(_ row: Row) -> LibraryCollection {
            return LibraryCollection(id: row[LibraryCollectionTable.table[id]], externalID: row[LibraryCollectionTable.table[externalID]], librarySectionID: row[LibraryCollectionTable.table[librarySectionID]], librarySectionExternalID: row[LibraryCollectionTable.table[librarySectionExternalID]], position: row[LibraryCollectionTable.table[position]], titleHTML: row[LibraryCollectionTable.table[titleHTML]], coverRenditions: row[LibraryCollectionTable.table[coverRenditions]].flatMap { $0.toImageRenditions() }, type: LibraryCollectionType(rawValue: row[LibraryCollectionTable.table[typeID]]) ?? .standard)
        }
        
    }
    
    public func libraryCollections() -> [LibraryCollection] {
        do {
            return try db.prepare(LibraryCollectionTable.table).map { LibraryCollectionTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    public func libraryCollectionsForLibrarySectionWithID(_ librarySectionID: Int64) -> [LibraryCollection] {
        do {
            return try db.prepare(LibraryCollectionTable.table.filter(LibraryCollectionTable.librarySectionID == librarySectionID).order(LibraryCollectionTable.position)).map { LibraryCollectionTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    @available(*, deprecated: 1.0.0, message: "Use `libraryCollectionsForLibrarySectionWithID(_:)` instead")
    public func libraryCollectionsForLibrarySectionWithExternalID(_ librarySectionExternalID: String) -> [LibraryCollection] {
        do {
            return try db.prepare(LibraryCollectionTable.table.filter(LibraryCollectionTable.librarySectionExternalID == librarySectionExternalID).order(LibraryCollectionTable.position)).map { LibraryCollectionTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    public func libraryCollectionsForLibraryCollectionWithID(_ id: Int64) -> [LibraryCollection] {
        do {
            return try db.prepare(LibraryCollectionTable.table.join(LibrarySectionTable.table, on: LibraryCollectionTable.librarySectionID == LibrarySectionTable.table[LibrarySectionTable.id]).filter(LibrarySectionTable.libraryCollectionID == id).order(LibraryCollectionTable.table[LibraryCollectionTable.position])).map { LibraryCollectionTable.fromNamespacedRow($0) }
        } catch {
            return []
        }
    }
    
    public func libraryCollectionWithID(_ id: Int64) -> LibraryCollection? {
        do {
            return try db.pluck(LibraryCollectionTable.table.filter(LibraryCollectionTable.id == id)).map { LibraryCollectionTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    @available(*, deprecated: 1.0.0, message: "Use `libraryCollectionWithID(_:)` instead")
    public func libraryCollectionWithExternalID(_ externalID: String) -> LibraryCollection? {
        do {
            return try db.pluck(LibraryCollectionTable.table.filter(LibraryCollectionTable.externalID == externalID)).map { LibraryCollectionTable.fromRow($0) }
        } catch {
            return nil
        }
    }

}

extension Catalog {
    
    class LibraryItemTable {
        
        static let table = Table("library_item")
        static let id = Expression<Int64>("_id")
        static let externalID = Expression<String>("external_id")
        static let librarySectionID = Expression<Int64?>("library_section_id")
        static let librarySectionExternalID = Expression<String?>("library_section_external_id")
        static let position = Expression<Int>("position")
        static let titleHTML = Expression<String>("title_html")
        static let obsolete = Expression<Bool>("is_obsolete")
        static let itemID = Expression<Int64>("item_id")
        static let itemExternalID = Expression<String>("item_external_id")
        
        static func fromRow(_ row: Row) -> LibraryItem {
            return LibraryItem(id: row[id], externalID: row[externalID], librarySectionID: row[librarySectionID], librarySectionExternalID: row[librarySectionExternalID], position: row[position], titleHTML: row[titleHTML], obsolete: row[obsolete], itemID: row[itemID], itemExternalID: row[itemExternalID])
        }
        
        static func fromNamespacedRow(_ row: Row) -> LibraryItem {
            return LibraryItem(id: row[LibraryItemTable.table[id]], externalID: row[LibraryItemTable.table[externalID]], librarySectionID: row[LibraryItemTable.table[librarySectionID]], librarySectionExternalID: row[LibraryItemTable.table[librarySectionExternalID]], position: row[LibraryItemTable.table[position]], titleHTML: row[LibraryItemTable.table[titleHTML]], obsolete: row[LibraryItemTable.table[obsolete]], itemID: row[LibraryItemTable.table[itemID]], itemExternalID: row[LibraryItemTable.table[itemExternalID]])
        }
        
    }
    
    public func libraryItemsForLibrarySectionWithID(_ librarySectionID: Int64) -> [LibraryItem] {
        do {
            return try db.prepare(LibraryItemTable.table.filter(LibraryItemTable.librarySectionID == librarySectionID).order(LibraryItemTable.position)).map { LibraryItemTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    @available(*, deprecated: 1.0.0, message: "Use `libraryItemsForLibrarySectionWithID(_:)` instead")
    public func libraryItemsForLibrarySectionWithExternalID(_ librarySectionExternalID: String) -> [LibraryItem] {
        do {
            return try db.prepare(LibraryItemTable.table.join(ItemTable.table, on: ItemTable.table[ItemTable.id] == LibraryItemTable.itemID).filter(LibraryItemTable.librarySectionExternalID == librarySectionExternalID && validPlatformIDs.contains(ItemTable.platformID)).order(LibraryItemTable.position)).map { LibraryItemTable.fromNamespacedRow($0) }
        } catch {
            return []
        }
    }
    
    public func libraryItemsForLibraryCollectionWithID(_ libraryCollectionID: Int64) -> [LibraryItem] {
        do {
            return try db.prepare(LibraryItemTable.table.join(LibrarySectionTable.table, on: LibrarySectionTable.table[LibrarySectionTable.id] == LibraryItemTable.librarySectionID).filter(LibrarySectionTable.libraryCollectionID == libraryCollectionID).order(LibraryItemTable.position)).map { LibraryItemTable.fromNamespacedRow($0) }
        } catch {
            return []
        }
    }
    
    @available(*, deprecated: 1.0.0, message: "Use `libraryItemsForLibraryCollectionWithID(_:)` instead")
    public func libraryItemsForLibraryCollectionWithExternalID(_ libraryCollectionExternalID: String) -> [LibraryItem] {
        do {
            return try db.prepare(LibraryItemTable.table.join(LibrarySectionTable.table, on: LibrarySectionTable.table[LibrarySectionTable.id] == LibraryItemTable.librarySectionID).filter(LibrarySectionTable.libraryCollectionExternalID == libraryCollectionExternalID).order(LibraryItemTable.position)).map { LibraryItemTable.fromNamespacedRow($0) }
        } catch {
            return []
        }
    }
    
    public func libraryItemsWithItemID(_ itemID: Int64) -> [LibraryItem] {
        do {
            return try db.prepare(LibraryItemTable.table.filter(LibraryItemTable.itemID == itemID)).map { LibraryItemTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    @available(*, deprecated: 1.0.0, message: "Use `libraryItemsWithItemID(_:)` instead")
    public func libraryItemsWithItemExternalID(_ itemExternalID: String) -> [LibraryItem] {
        do {
            return try db.prepare(LibraryItemTable.table.filter(LibraryItemTable.itemExternalID == itemExternalID)).map { LibraryItemTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    public func libraryItemWithItemID(_ itemID: Int64, inLibraryCollectionWithID libraryCollectionID: Int64) -> LibraryItem? {
        do {
            return try db.pluck(LibraryItemTable.table.join(LibrarySectionTable.table, on: LibrarySectionTable.table[LibrarySectionTable.id] == LibraryItemTable.librarySectionID).filter(LibraryItemTable.itemID == itemID && LibrarySectionTable.libraryCollectionID == libraryCollectionID).order(LibraryItemTable.position)).map { LibraryItemTable.fromNamespacedRow($0) }
        } catch {
            return nil
        }
    }
    
    @available(*, deprecated: 1.0.0, message: "Use `libraryItemWithItemID(_:inLibraryCollectionWithID:)` instead")
    public func libraryItemWithItemExternalID(_ itemExternalID: String, inLibraryCollectionWithExternalID libraryCollectionExternalID: String) -> LibraryItem? {
        do {
            return try db.pluck(LibraryItemTable.table.join(LibrarySectionTable.table, on: LibrarySectionTable.table[LibrarySectionTable.id] == LibraryItemTable.librarySectionID).filter(LibraryItemTable.itemExternalID == itemExternalID && LibrarySectionTable.libraryCollectionExternalID == libraryCollectionExternalID).order(LibraryItemTable.position)).map { LibraryItemTable.fromNamespacedRow($0) }
        } catch {
            return nil
        }
    }
    
    public func libraryItemWithID(_ id: Int64) -> LibraryItem? {
        do {
            return try db.pluck(LibraryItemTable.table.filter(LibraryItemTable.id == id)).map { LibraryItemTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    @available(*, deprecated: 1.0.0, message: "Use `libraryItemWithID(_:)` instead")
    public func libraryItemWithExternalID(_ externalID: String) -> LibraryItem? {
        do {
            return try db.pluck(LibraryItemTable.table.filter(LibraryItemTable.externalID == externalID)).map { LibraryItemTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
}

extension Catalog {
    
    public func libraryNodesForLibrarySectionWithID(_ librarySectionID: Int64) -> [LibraryNode] {
        var libraryNodes = [LibraryNode]()
        libraryNodes += libraryCollectionsForLibrarySectionWithID(librarySectionID).map { $0 as LibraryNode }
        libraryNodes += libraryItemsForLibrarySectionWithID(librarySectionID).map { $0 as LibraryNode }
        return libraryNodes.sorted { $0.position < $1.position }
    }
    
    @available(*, deprecated: 1.0.0, message: "Use `libraryNodesForLibrarySectionWithID(_:)` instead")
    public func libraryNodesForLibrarySectionWithExternalID(_ librarySectionExternalID: String) -> [LibraryNode] {
        var libraryNodes = [LibraryNode]()
        libraryNodes += libraryCollectionsForLibrarySectionWithExternalID(librarySectionExternalID).map { $0 as LibraryNode }
        libraryNodes += libraryItemsForLibrarySectionWithExternalID(librarySectionExternalID).map { $0 as LibraryNode }
        return libraryNodes.sorted { $0.position < $1.position }
    }
    
}

extension Catalog {
    
    class StopwordTable {
        
        static let table = Table("stopword")
        static let id = Expression<Int64>("_id")
        static let languageID = Expression<Int64>("language_id")
        static let word = Expression<String>("word")
        
        static func fromRow(_ row: Row) -> Stopword {
            return Stopword(id: row[id], languageID: row[languageID], word: row[word])
        }
        
    }
    
    public func stopwordsWithLanguageID(_ languageID: Int64) -> [Stopword] {
        do {
            return try db.prepare(StopwordTable.table.filter(StopwordTable.languageID == languageID)).map { StopwordTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
}


