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

public extension ItemPackage {
    
    class SubitemTable {
        
        static let table = Table("subitem")
        static let id = Expression<Int64>("_id")
        static let uri = Expression<String>("uri")
        static let docID = Expression<String>("doc_id")
        static let docVersion = Expression<Int>("doc_version")
        static let position = Expression<Int>("position")
        static let titleHTML = Expression<String>("title_html")
        static let title = Expression<String>("title")
        static let webURL = Expression<String>("web_url")
        static let contentType = Expression<ContentType>("content_type")
        
        static func fromRow(_ row: Row) -> Subitem {
            return Subitem(id: row[id], uri: row[uri], docID: row[docID], docVersion: row[docVersion], position: row[position], titleHTML: row[titleHTML], title: row[title], webURL: URL(string: row[webURL]), contentType: row.get(contentType))
        }
        
    }
    
    public func subitemWithURI(_ uri: String) -> Subitem? {
        do {
            return try (db?.pluck(SubitemTable.table.filter(SubitemTable.uri == uri)))?.map { SubitemTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    public func subitemWithDocID(_ docID: String) -> Subitem? {
        do {
            return try (db?.pluck(SubitemTable.table.filter(SubitemTable.docID == docID)))?.map { SubitemTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    public func subitemWithID(_ id: Int64) -> Subitem? {
        do {
            return try (db?.pluck(SubitemTable.table.filter(SubitemTable.id == id)))?.map { SubitemTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    public func subitemAtPosition(_ position: Int) -> Subitem? {
        do {
            return try (db?.pluck(SubitemTable.table.filter(SubitemTable.position == position)))?.map { SubitemTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    public func subitems() -> [Subitem] {
        do {
            return try (db?.prepare(SubitemTable.table.order(SubitemTable.position)))?.map { SubitemTable.fromRow($0) } ?? []
        } catch {
            return []
        }
    }
    
    public func subitemExistsWithURI(_ subitemURI: String) -> Bool {
        do {
            return try db?.scalar(SubitemTable.table.filter(SubitemTable.uri == subitemURI).count) ?? 0 > 0
        } catch {
            return false
        }
    }
    
    public func subitemsWithURIs(_ uris: [String]) -> [Subitem] {
        do {
            return try (db?.prepare(SubitemTable.table.filter(uris.contains(SubitemTable.uri)).order(SubitemTable.position)))?.map { SubitemTable.fromRow($0) } ?? []
        } catch {
            return []
        }
    }
    
    public func firstSubitemURIPrefixedByURI(_ uri: String) -> String? {
        do {
            return try (db?.pluck(SubitemTable.table.select(SubitemTable.uri).filter(SubitemTable.uri.like("\(uri.escaped())%", escape: "!")).order(SubitemTable.position)))?.map { $0[SubitemTable.uri] }
        } catch {
            return nil
        }
    }
    
    public func subitemsWithAuthor(_ author: Author) -> [Subitem] {
        do {
            return try (db?.prepare(SubitemTable.table.filter(SubitemTable.id == SubitemAuthorTable.subitemID && SubitemAuthorTable.authorID == author.id).order(SubitemTable.position)))?.map { SubitemTable.fromRow($0) } ?? []
        } catch {
            return []
        }
    }
    
    public func numberOfSubitems() -> Int {
        do {
            return try db?.scalar(SubitemTable.table.count) ?? 0
        } catch {
            return 0
        }
    }
    
    public func subitemIDOfSubitemWithURI(_ subitemURI: String) -> Int64? {
        do {
            return try (db?.pluck(SubitemTable.table.select(SubitemTable.id).filter(SubitemTable.uri == subitemURI)))?.map { $0[SubitemTable.id] }
        } catch {
            return nil
        }
    }
    
    public func docIDOfSubitemWithURI(_ subitemURI: String) -> String? {
        do {
            return try (db?.pluck(SubitemTable.table.select(SubitemTable.docID).filter(SubitemTable.uri == subitemURI)))?.map { $0[SubitemTable.docID] }
        } catch {
            return nil
        }
    }
    
    public func docVersionOfSubitemWithURI(_ subitemURI: String) -> Int? {
        do {
            return try (db?.pluck(SubitemTable.table.select(SubitemTable.docVersion).filter(SubitemTable.uri == subitemURI)))?.map { $0[SubitemTable.docVersion] }
        } catch {
            return nil
        }
    }
    
    public func URIOfSubitemWithID(_ subitemID: Int64) -> String? {
        do {
            return try (db?.pluck(SubitemTable.table.select(SubitemTable.uri).filter(SubitemTable.id == subitemID)))?.map { $0[SubitemTable.uri] }
        } catch {
            return nil
        }
    }
    
    public func URIsOfSubitemsWithIDs(_ ids: [Int64]) -> [String] {
        do {
            return try (db?.prepare(SubitemTable.table.select(SubitemTable.uri).filter(ids.contains(SubitemTable.id)).order(SubitemTable.position)))?.map { $0[SubitemTable.uri] } ?? []
        } catch {
            return []
        }
    }
    
    public func orderedSubitemURIsWithURIs(_ uris: [String]) -> [String] {
        do {
            return try (db?.prepare(SubitemTable.table.select(SubitemTable.uri).filter(uris.contains(SubitemTable.uri)).order(SubitemTable.position)))?.map { $0[SubitemTable.uri] } ?? []
        } catch {
            return []
        }
    }
    
    public func citationForSubitemWithDocID(_ docID: String, paragraphAIDs: [String]?) -> String? {
        guard let subitem = subitemWithDocID(docID) else { return nil }
        guard let verse = verseNumberTitleForSubitemWithDocID(docID, paragraphAIDs: paragraphAIDs) else { return subitem.title }
        
        var title = subitem.title
        if title.range(of: "[0-9]$", options: .regularExpression) == nil {
            // If not, add 1. This is a one chapter book.
            title += " 1"
        }
        return String(format: NSLocalizedString("%1$@:%2$@", comment: "Formatter string for creating short titles with a verse ({chapter title}:{verse number}, e.g. 1 Nephi 10:7)"), title, verse)
    }
    
    public func verseNumberTitleForSubitemWithDocID(_ docID: String, paragraphAIDs: [String]?) -> String? {
        var verse: String?
        
        if let paragraphAIDs = paragraphAIDs, !paragraphAIDs.isEmpty {
            let verseNumbers = verseNumbersForSubitemWithDocID(docID, paragraphAIDs: paragraphAIDs)
            if verseNumbers.count > 1, let firstVerse = verseNumbers.first, let lastVerse = verseNumbers.last {
                verse = String(format: "%@-%@", firstVerse, lastVerse)
            } else if verseNumbers.count == 1 {
                verse = verseNumbers.first
            }
        }
        
        return verse
    }
    
    func firstSubitemURIThatContainsURI(_ uri: String) -> String? {
        if subitemExistsWithURI(uri) {
            return uri
        }
        
        // Iteratively look for the last subitem whose URI is a prefix of this URI
        var subitemURI = uri.components(separatedBy: "?").first ?? ""
        while subitemURI.characters.count > 0 && subitemURI != "/" {
            guard !subitemExistsWithURI(subitemURI) else {
                // Found a valid SubitemURI
                return subitemURI
            }
            
            if let range = subitemURI.range(of: "/", options: .backwards) {
                subitemURI = subitemURI.substring(to: range.lowerBound)
            } else {
                subitemURI = ""
            }
        }
        
        return firstSubitemURIPrefixedByURI(uri)
    }
    
}
