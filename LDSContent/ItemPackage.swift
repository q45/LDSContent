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
import FTS3HTMLTokenizer

public class ItemPackage {
    
    var db: Connection?
    public let url: URL
    
    public init(url: URL, readonly: Bool = true) throws {
        do {
            db = try Connection(url.appendingPathComponent("package.sqlite").path, readonly: readonly)
            db?.busyTimeout = 5
            self.url = url
        } catch {
            throw error
        }
        
        try db?.execute("PRAGMA synchronous = OFF")
        try db?.execute("PRAGMA journal_mode = OFF")
        try db?.execute("PRAGMA temp_store = MEMORY")
        
        if readonly {
            // Only disable foreign keys when using as a readonly database for better performance
            try db?.execute("PRAGMA foreign_keys = OFF")
        }
        
        registerTokenizer(db?.handle, UnsafeMutablePointer<Int8>(mutating: ("HTMLTokenizer" as NSString).utf8String))
    }
    
    func itemPackageDirectoryDeleted(itemPackageURL: URL) {
        if itemPackageURL == url {
            db = nil
        }
    }
    
    public func inTransaction(_ closure: @escaping () throws -> Void) throws {
        let inTransactionKey = "txn:\(Unmanaged.passUnretained(self).toOpaque())"
        if Thread.current.threadDictionary[inTransactionKey] != nil {
            try closure()
        } else {
            Thread.current.threadDictionary[inTransactionKey] = true
            defer { Thread.current.threadDictionary.removeObject(forKey: inTransactionKey) }
            try db?.transaction {
                try closure()
            }
        }
    }
    
    public var databaseExists: Bool {
        return FileManager.default.fileExists(atPath: url.appendingPathComponent("package.sqlite").path)
    }
    
    public var schemaVersion: Int {
        return Int(self.intForMetadataKey("schemaVersion") ?? 0)
    }
    
    public var itemPackageVersion: Int {
        return Int(self.intForMetadataKey("itemPackageVersion") ?? 0)
    }
    
    public var iso639_3Code: String? {
        return self.stringForMetadataKey("iso639_3")
    }
    
    public var uri: String? {
        return self.stringForMetadataKey("uri")
    }
    
    public var itemID: Int64? {
        return self.intForMetadataKey("item_id")
    }
    
    public var itemExternalID: String? {
        return self.stringForMetadataKey("item_external_id")
    }
    
    public func itemHeadHTML() -> String {
        do {
            return try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsPackageDescendants).flatMap { fileURL -> String? in
                guard fileURL.pathExtension == "css" else { return nil }
                return "<link rel=\"stylesheet\" href=\"\(fileURL.path)\"/>"
            }.joined(separator: "\n")
        } catch {
            return ""
        }
    }
    
    public func scriptureGotoURL() -> URL {
        return url.appendingPathComponent("scriptureGoto.plist")
    }
    
}

extension ItemPackage {
    
    class MetadataTable {
        
        static let table = Table("metadata")
        static let key = Expression<String>("key")
        static let integerValue = Expression<Int64>("value")
        static let stringValue = Expression<String>("value")
        
    }
    
    func intForMetadataKey(_ key: String) -> Int64? {
        do {
            return try db?.pluck(MetadataTable.table.filter(MetadataTable.key == key).select(MetadataTable.stringValue)).flatMap { row in
                let string = row[MetadataTable.stringValue]
                return Int64(string)
            }
        } catch {
            return nil
        }
    }
    
    func stringForMetadataKey(_ key: String) -> String? {
        do {
            return try (db?.pluck(MetadataTable.table.filter(MetadataTable.key == key).select(MetadataTable.stringValue)))?.map { return $0[MetadataTable.stringValue] }
        } catch {
            return nil
        }
    }
    
}

extension ItemPackage {
    
    class SubitemContentView {
        
        static let table = View("subitem_content")
        static let id = Expression<Int64>("_id")
        static let subitemID = Expression<Int64>("subitem_id")
        static let contentHTML = Expression<Data>("content_html")
        
        static func fromRow(_ row: Row) -> SubitemContent {
            return SubitemContent(id: row[id], subitemID: row[subitemID], contentHTML: row[contentHTML])
        }
        
    }
    
    public func subitemContentWithSubitemID(_ subitemID: Int64) -> SubitemContent? {
        do {
            return try (db?.pluck(SubitemContentView.table.filter(SubitemContentView.subitemID == subitemID)))?.map { SubitemContentView.fromRow($0) }
        } catch {
            return nil
        }
    }
    
}

extension ItemPackage {
    
    class SubitemContentVirtualTable {
        
        static let table = VirtualTable("subitem_content_fts")
        static let id = Expression<Int64>("_id")
        static let subitemID = Expression<Int64>("subitem_id")
        static let contentHTML = Expression<Data>("content_html")
        
        static func fromRow(_ row: [Binding?], iso639_3Code: String, keywordSearch: Bool) -> SearchResult {
            return SearchResult(subitemID: Int64(row[2] as! Int64), uri: row[4] as! String, title: row[3] as! String, matchRanges: matchRangesFromOffsets(row[0] as! String, keywordSearch: keywordSearch), iso639_3Code: iso639_3Code, snippet: row[1] as! String)
        }
        
        static func matchRangesFromOffsets(_ offsets: String, keywordSearch: Bool) -> [NSRange] {
            var matchRanges = [NSRange]()
            
            let scanner = Scanner(string: offsets)
            while !scanner.isAtEnd {
                var columnNumber = 0
                if !scanner.scanInt(&columnNumber) {
                    return []
                }
                
                var termNumber = 0
                if !scanner.scanInt(&termNumber) {
                    return []
                }
                
                var byteOffset = 0
                if !scanner.scanInt(&byteOffset) {
                    return []
                }
                
                var byteSize = 0
                if !scanner.scanInt(&byteSize) {
                    return []
                }
                
                let range = NSMakeRange(byteOffset, byteSize)
                if !keywordSearch && termNumber != 0, let lastRange = matchRanges.popLast() {
                    // Combine into single range for exact phrase matches
                    let combinedRange = NSMakeRange(lastRange.location, (range.location - lastRange.location) + range.length)
                    matchRanges.append(combinedRange)
                } else {
                    // Don't try to combine search tokens on keyword search
                    matchRanges.append(range)
                }
            }
            return matchRanges
        }
        
    }

    public func searchResultsForString(_ searchString: String, subitemID: Int64? = nil) -> [SearchResult] {
        let iso639_3Code = self.iso639_3Code!
        let keywordSearch = !(searchString.hasPrefix("\"") && searchString.hasSuffix("\""))
        // Stray quotes cause a crash when doing the query
        var modifiedSearchString = searchString.replacingOccurrences(of: "\"", with: "")
        if keywordSearch {
            modifiedSearchString = "\"\(modifiedSearchString)\""
        }
        
        do {
            var subStatement = ""
            var bindings: [String: Binding?] = ["@searchString": modifiedSearchString]
            if let subitemID = subitemID {
                subStatement = "AND subitem._id = @subitemID"
                bindings["@subitemID"] = subitemID
            }
            
            let statement = "SELECT offsets(subitem_content_fts) AS offsets, snippet(subitem_content_fts, '<em class=\"searchMatch\">', '</em>', '…', -1, 35) AS snippet, subitem_content_fts.subitem_id, subitem.title, subitem.uri FROM subitem_content_fts LEFT JOIN subitem ON subitem._id = subitem_content_fts.subitem_id WHERE subitem_content_fts.content_html MATCH @searchString \(subStatement) ORDER BY subitem_content_fts.subitem_id"
            
            return try (db?.prepare(statement, bindings))?.map { row in
                return SubitemContentVirtualTable.fromRow(row, iso639_3Code: iso639_3Code, keywordSearch: keywordSearch)
            } ?? []
        } catch {
            return []
        }
    }
    
}

extension ItemPackage {
    
    class NavSectionTable {
        
        static let table = Table("nav_section")
        static let id = Expression<Int64>("_id")
        static let navCollectionID = Expression<Int64>("nav_collection_id")
        static let position = Expression<Int>("position")
        static let indentLevel = Expression<Int>("indent_level")
        static let title = Expression<String?>("title")
        
        static func fromRow(_ row: Row) -> NavSection {
            return NavSection(id: row[id], navCollectionID: row[navCollectionID], position: row[position], indentLevel: row[indentLevel], title: row[title])
        }
        
    }
    
    public func navSectionWithID(_ id: Int64) -> NavSection? {
        do {
            return try (db?.pluck(NavSectionTable.table.filter(NavSectionTable.id == id)))?.map { NavSectionTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    public func navSectionsForNavCollectionWithID(_ navCollectionID: Int64) -> [NavSection] {
        do {
            return try (db?.prepare(NavSectionTable.table.filter(NavSectionTable.navCollectionID == navCollectionID).order(NavSectionTable.position)))?.map { NavSectionTable.fromRow($0) } ?? []
        } catch {
            return []
        }
    }
    
    public func numberOfNavSectionsForNavCollectionWithID(_ navCollectionID: Int64) -> Int {
        do {
            return try db?.scalar(NavSectionTable.table.filter(NavSectionTable.navCollectionID == navCollectionID).order(NavSectionTable.position).count) ?? 0
        } catch {
            return 0
        }
    }
    
}

extension ItemPackage {
    
    class NavItemTable {
        
        static let table = Table("nav_item")
        static let id = Expression<Int64>("_id")
        static let navSectionID = Expression<Int64>("nav_section_id")
        static let position = Expression<Int>("position")
        static let imageRenditions = Expression<String?>("image_renditions")
        static let titleHTML = Expression<String>("title_html")
        static let subtitle = Expression<String?>("subtitle")
        static let preview = Expression<String?>("preview")
        static let uri = Expression<String>("uri")
        static let subitemID = Expression<Int64>("subitem_id")
        
        static func fromRow(_ row: Row) -> NavItem {
            return NavItem(id: row[id], navSectionID: row[navSectionID], position: row[position], imageRenditions: row[imageRenditions].flatMap { $0.toImageRenditions() }, titleHTML: row[titleHTML], subtitle: row[subtitle], preview: row[preview], uri: row[uri], subitemID: row[subitemID])
        }
        
    }
    
    public func navItemWithURI(_ uri: String) -> NavItem? {
        do {
            return try (db?.pluck(NavItemTable.table.filter(NavItemTable.uri == uri)))?.map { NavItemTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    public func navItemsForNavSectionWithID(_ navSectionID: Int64) -> [NavItem] {
        do {
            return try (db?.prepare(NavItemTable.table.filter(NavItemTable.navSectionID == navSectionID).order(NavItemTable.position)))?.map { NavItemTable.fromRow($0) } ?? []
        } catch {
            return []
        }
    }
    
}

extension ItemPackage {
    
    public func navNodesForNavSectionWithID(_ navSectionID: Int64) -> [NavNode] {
        var navNodes = [NavNode]()
        navNodes += navCollectionsForNavSectionWithID(navSectionID).map { $0 as NavNode }
        navNodes += navItemsForNavSectionWithID(navSectionID).map { $0 as NavNode }
        return navNodes.sorted { $0.position < $1.position }
    }
    
}

extension ItemPackage {
    
    class AuthorTable {
        static let table = Table("author")
        static let id = Expression<Int64>("_id")
        static let givenName = Expression<String>("given_name")
        static let familyName = Expression<String>("family_name")
        static let imageRenditions = Expression<String?>("image_renditions")
        
        static func fromRow(_ row: Row) -> Author {
            return Author(id: row[id], givenName: row[givenName], familyName: row[familyName], imageRenditions: row[imageRenditions].flatMap { $0.toImageRenditions() })
        }
    }
    
    public func authorsOfSubitemWithID(_ subitemID: Int64) -> [Author] {
        do {
            return try (db?.prepare(AuthorTable.table.select(AuthorTable.table[*]).join(SubitemAuthorTable.table, on: AuthorTable.table[AuthorTable.id] == SubitemAuthorTable.authorID).filter(SubitemAuthorTable.subitemID == subitemID).order(AuthorTable.familyName).order(AuthorTable.familyName, AuthorTable.givenName)))?.map { AuthorTable.fromRow($0) } ?? []
        } catch {
            return []
        }
    }
    
    public func authorWithGivenName(_ givenName: String, familyName: String) -> Author? {
        do {
            return try (db?.pluck(AuthorTable.table.filter(AuthorTable.givenName == givenName && AuthorTable.familyName == familyName)))?.map { AuthorTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
}

extension ItemPackage {
    
    class RoleTable {
        static let table = Table("role")
        static let id = Expression<Int64>("_id")
        static let name = Expression<String>("name")
        static let position = Expression<Int>("position")
        
        static func fromRow(_ row: Row) -> Role {
            return Role(id: row[id], name: row[name], position: row[position])
        }
    }
    
    public func roleWithName(_ name: String) -> Role? {
        do {
            return try (db?.pluck(RoleTable.table.filter(RoleTable.name == name)))?.map { RoleTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
}

extension ItemPackage {
    
    class AuthorRoleTable {
        static let table = Table("author_role")
        static let id = Expression<Int64>("_id")
        static let authorID = Expression<Int64>("author_id")
        static let roleID = Expression<Int64>("role_id")
        static let position = Expression<Int>("position")
        
        static func fromRow(_ row: Row) -> AuthorRole {
            return AuthorRole(id: row[id], authorID: row[authorID], roleID: row[roleID], position: row[position])
        }
    }
    
}

extension ItemPackage {
    
    class SubitemAuthorTable {
        static let table = Table("subitem_author")
        static let id = Expression<Int64>("_id")
        static let subitemID = Expression<Int64>("subitem_id")
        static let authorID = Expression<Int64>("author_id")
    }
    
}

extension ItemPackage {
    
    class TopicTable {
        static let table = Table("topic")
        static let id = Expression<Int64>("_id")
        static let name = Expression<String>("name")
        
        static func fromRow(_ row: Row) -> Topic {
            return Topic(id: row[id], name: row[name])
        }
    }
    
    public func topicWithName(_ name: String) -> Topic? {
        do {
            return try (db?.pluck(TopicTable.table.filter(TopicTable.name == name)))?.map { TopicTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
}

extension ItemPackage {
    
    class SubitemTopicTable {
        static let table = Table("subitem_topic")
        static let id = Expression<Int64>("_id")
        static let subitemID = Expression<Int64>("subitem_id")
        static let topicID = Expression<Int64>("topic_id")
    }
    
}
