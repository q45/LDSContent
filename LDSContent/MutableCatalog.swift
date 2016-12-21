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

public class MutableCatalog: Catalog {
    
    public init(path: String? = nil) throws {
        try super.init(path: path, readonly: false)
        
        try createDatabaseTables()
    }
    
    fileprivate func createDatabaseTables() throws {
        try db.transaction {
            if !self.db.tableExists("metadata") {
                if let sqlPath = Bundle(for: type(of: self)).path(forResource: "Catalog", ofType: "sql") {
                    let sql = try String(contentsOfFile: sqlPath, encoding: String.Encoding.utf8)
                    try self.db.execute(sql)
                } else {
                    throw ContentError.errorWithCode(.unknown, failureReason: "Unable to locate SQL for catalog.")
                }
            }
        }
    }
    
    public override var schemaVersion: Int {
        get {
            return super.schemaVersion
        }
        set {
            setInt(newValue, forMetadataKey: "schemaVersion")
        }
    }
    
    public override var catalogVersion: Int {
        get {
            return super.catalogVersion
        }
        set {
            setInt(newValue, forMetadataKey: "catalogVersion")
        }
    }
    
    public func vacuum() throws {
        try db.execute("VACUUM")
    }
    
}

extension MutableCatalog {
    
    func setInt(_ integerValue: Int?, forMetadataKey key: String) {
        do {
            if let integerValue = integerValue {
                _ = try db.run(MetadataTable.table.insert(or: .replace, MetadataTable.key <- key, MetadataTable.integerValue <- integerValue))
            } else {
                _ = try db.run(MetadataTable.table.filter(MetadataTable.key == key).delete())
            }
        } catch {}
    }
    
    func setString(_ stringValue: String?, forMetadataKey key: String) {
        do {
            if let stringValue = stringValue {
                _ = try db.run(MetadataTable.table.insert(or: .replace, MetadataTable.key <- key, MetadataTable.stringValue <- stringValue))
            } else {
                _ = try db.run(MetadataTable.table.filter(MetadataTable.key == key).delete())
            }
        } catch {}
    }
    
}

extension MutableCatalog {

    public func addOrUpdateSource(_ source: Source) throws {
        _ = try db.run(SourceTable.table.insert(or: .replace,
            SourceTable.id <- source.id,
            SourceTable.name <- source.name,
            SourceTable.typeID <- source.type.rawValue
        ))
    }
    
    public func addOrUpdateItemCategory(_ itemCategory: ItemCategory) throws {
        _ = try db.run(ItemCategoryTable.table.insert(or: .replace,
            ItemCategoryTable.id <- itemCategory.id,
            ItemCategoryTable.name <- itemCategory.name
        ))
    }
    
    public func addOrUpdateItem(_ item: Item) throws {
        _ = try db.run(ItemTable.table.insert(or: .replace,
            ItemTable.id <- item.id,
            ItemTable.externalID <- item.externalID,
            ItemTable.languageID <- item.languageID,
            ItemTable.sourceID <- item.sourceID,
            ItemTable.platformID <- item.platform.rawValue,
            ItemTable.uri <- item.uri,
            ItemTable.title <- item.title,
            ItemTable.itemCoverRenditions <- String(item.itemCoverRenditions),
            ItemTable.itemCategoryID <- item.itemCategoryID,
            ItemTable.version <- item.version,
            ItemTable.obsolete <- item.obsolete
        ))
    }
    
    public func addOrUpdateLanguage(_ language: Language) throws {
        _ = try db.run(LanguageTable.table.insert(or: .replace,
            LanguageTable.id <- language.id,
            LanguageTable.ldsLanguageCode <- language.ldsLanguageCode,
            LanguageTable.iso639_3Code <- language.iso639_3Code,
            LanguageTable.bcp47Code <- language.bcp47Code,
            LanguageTable.rootLibraryCollectionID <- language.rootLibraryCollectionID,
            LanguageTable.rootLibraryCollectionExternalID <- language.rootLibraryCollectionExternalID
        ))
    }
    
    public func setName(_ name: String, forLanguageWithID languageID: Int64, inLanguageWithID localizationLanguageID: Int64) throws {
        _ = try db.run(LanguageNameTable.table.insert(
            LanguageNameTable.languageID <- languageID,
            LanguageNameTable.localizationLanguageID <- localizationLanguageID,
            LanguageNameTable.name <- name
        ))
    }
    
    public func addOrUpdateLibraryCollection(_ libraryCollection: LibraryCollection) throws {
        _ = try db.run(LibraryCollectionTable.table.insert(or: .replace,
            LibraryCollectionTable.id <- libraryCollection.id,
            LibraryCollectionTable.externalID <- libraryCollection.externalID,
            LibraryCollectionTable.librarySectionID <- libraryCollection.librarySectionID,
            LibraryCollectionTable.librarySectionExternalID <- libraryCollection.librarySectionExternalID,
            LibraryCollectionTable.position <- libraryCollection.position,
            LibraryCollectionTable.titleHTML <- libraryCollection.titleHTML,
            LibraryCollectionTable.coverRenditions <- String(libraryCollection.coverRenditions),
            LibraryCollectionTable.typeID <- libraryCollection.type.rawValue
        ))
    }
    
    public func addOrUpdateLibrarySection(_ librarySection: LibrarySection) throws {
        _ = try db.run(LibrarySectionTable.table.insert(or: .replace,
            LibrarySectionTable.id <- librarySection.id,
            LibrarySectionTable.externalID <- librarySection.externalID,
            LibrarySectionTable.libraryCollectionID <- librarySection.libraryCollectionID,
            LibrarySectionTable.libraryCollectionExternalID <- librarySection.libraryCollectionExternalID,
            LibrarySectionTable.position <- librarySection.position,
            LibrarySectionTable.title <- librarySection.title,
            LibrarySectionTable.indexTitle <- librarySection.indexTitle
        ))
    }
    
    public func addOrUpdateLibraryItem(_ libraryItem: LibraryItem) throws {
        _ = try db.run(LibraryItemTable.table.insert(or: .replace,
            LibraryItemTable.id <- libraryItem.id,
            LibraryItemTable.externalID <- libraryItem.externalID,
            LibraryItemTable.librarySectionID <- libraryItem.librarySectionID,
            LibraryItemTable.librarySectionExternalID <- libraryItem.librarySectionExternalID,
            LibraryItemTable.position <- libraryItem.position,
            LibraryItemTable.titleHTML <- libraryItem.titleHTML,
            LibraryItemTable.obsolete <- libraryItem.obsolete,
            LibraryItemTable.itemID <- libraryItem.itemID,
            LibraryItemTable.itemExternalID <- libraryItem.itemExternalID
        ))
    }
    
    public func addStopword(_ stopword: Stopword) throws {
        _ = try db.run(StopwordTable.table.insert(or: .ignore,
            StopwordTable.languageID <- stopword.languageID,
            StopwordTable.word <- stopword.word
        ))
    }
    
    public func addSubitemMetadata(id: Int64, subitemID: Int64, itemID: Int64, docID: String, docVersion: Int) throws {
        _ = try db.run(SubitemMetadataTable.table.insert(or: .ignore,
            SubitemMetadataTable.id <- id,
            SubitemMetadataTable.subitemID <- subitemID,
            SubitemMetadataTable.itemID <- itemID,
            SubitemMetadataTable.docID <- docID,
            SubitemMetadataTable.docVersion <- docVersion
        ))
    }
    
}

extension MutableCatalog {
    
    func insertDataFromCatalog(_ path: String, name: String) throws {
        let attachName = name.replacingOccurrences(of: "-", with: "_")
        try db.run("ATTACH DATABASE ? AS ?", path, attachName)
        
        // loop through all tables in the database and copy the data into the merged database
        for row in try db.run("SELECT name FROM sqlite_master WHERE type='table' and name NOT IN ('metadata', 'sqlite_sequence')") {
            guard let tableName = row[0] as? String else { continue }
            try db.execute("INSERT OR IGNORE INTO \(tableName) SELECT * FROM \(attachName).\(tableName)")
        }
        
        // Handle the metadata table differently, add the catalogName as a prefix in keys
        try db.execute("INSERT OR IGNORE INTO metadata (key, value) SELECT '\(name).' || key, value FROM \(attachName).metadata")
        try db.run("DETACH DATABASE ?", attachName)
    }
    
}
