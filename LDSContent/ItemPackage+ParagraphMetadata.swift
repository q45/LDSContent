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

extension ItemPackage {
    
    // MARK: ParagraphMetadataTable
    
    class ParagraphMetadataTable {
        
        static let table = Table("paragraph_metadata")
        static let id = Expression<Int64>("_id")
        static let subitemID = Expression<Int64>("subitem_id")
        static let paragraphID = Expression<String>("paragraph_id")
        static let paragraphAID = Expression<String>("paragraph_aid")
        static let verseNumber = Expression<String?>("verse_number")
        static let startIndex = Expression<Int>("start_index")
        static let endIndex = Expression<Int>("end_index")
        
        static func fromRow(_ row: Row) -> ParagraphMetadata {
            return ParagraphMetadata(id: row[id], subitemID: row[subitemID], paragraphID: row[paragraphID], paragraphAID: row[paragraphAID], verseNumber: row[verseNumber], range: NSRange(location: row[startIndex], length: row[endIndex] - row[startIndex]))
        }
        
        static func fromNamespacedRow(_ row: Row) -> ParagraphMetadata {
            return ParagraphMetadata(id: row[ParagraphMetadataTable.table[id]], subitemID: row[ParagraphMetadataTable.table[subitemID]], paragraphID: row[ParagraphMetadataTable.table[paragraphID]], paragraphAID: row[ParagraphMetadataTable.table[paragraphAID]], verseNumber: row[ParagraphMetadataTable.table[verseNumber]], range: NSRange(location: row[ParagraphMetadataTable.table[startIndex]], length: row[ParagraphMetadataTable.table[endIndex]] - row[ParagraphMetadataTable.table[startIndex]]))
        }
        
    }
    // MARK: Paragraph Metadata Methods
    
    /// Returns an array of ParagraphMetadata objects from the provided paragraphIDs and subitemID. Ordered by ParagraphMetaData startIndex.
    public func paragraphMetadataForParagraphIDs(_ paragraphIDs: [String], subitemID: Int64) -> [ParagraphMetadata] {
        do {
            return try (db?.prepare(ParagraphMetadataTable.table.filter(paragraphIDs.contains(ParagraphMetadataTable.paragraphID) && ParagraphMetadataTable.subitemID == subitemID).order(ParagraphMetadataTable.startIndex)))?.map { ParagraphMetadataTable.fromRow($0) } ?? []
        } catch {
            return []
        }
    }
    
	/// Returns an array of ordered ParagraphMetadata objects from the provided subitemID. Ordered by ParagraphMetaData startIndex.
    public func paragraphMetadataForSubitemID(_ subitemID: Int64) -> [ParagraphMetadata] {
        do {
            return try (db?.prepare(ParagraphMetadataTable.table.filter(ParagraphMetadataTable.subitemID == subitemID).order(ParagraphMetadataTable.startIndex)))?.map { ParagraphMetadataTable.fromRow($0) } ?? []
        } catch {
            return []
        }
    }
    
    /// Returns an array of ordered ParagraphMetadata objects from the provided paragraphAIDs and subitemID. Ordered by ParagraphMetaData startIndex.
    public func paragraphMetadataForParagraphAIDs(_ paragraphAIDs: [String], subitemID: Int64) -> [ParagraphMetadata] {
        do {
            return try (db?.prepare(ParagraphMetadataTable.table.filter(paragraphAIDs.contains(ParagraphMetadataTable.paragraphAID) && ParagraphMetadataTable.subitemID == subitemID).order(ParagraphMetadataTable.startIndex)))?.map { ParagraphMetadataTable.fromRow($0) } ?? []
        } catch {
            return []
        }
    }
    
    /// Returns an array of ordered ParagraphMetadata objects from the provided paragraphAIDs and docID. Ordered by ParagraphMetaData startIndex.
    public func paragraphMetadataForParagraphAIDs(_ paragraphAIDs: [String], docID: String) -> [ParagraphMetadata] {
        do {
            return try (db?.prepare(ParagraphMetadataTable.table.join(SubitemTable.table, on: ParagraphMetadataTable.subitemID == SubitemTable.table[SubitemTable.id]).filter(paragraphAIDs.contains(ParagraphMetadataTable.paragraphAID) && SubitemTable.docID == docID).order(ParagraphMetadataTable.startIndex)))?.map { ParagraphMetadataTable.fromNamespacedRow($0) } ?? []
        } catch {
            return []
        }
    }
    
    /// Returns an optional ParagraphMetadata from the provided paragraphID and subitemID.
    public func paragraphMetadataForParagraphID(_ paragraphID: String, subitemID: Int64) -> ParagraphMetadata? {
        do {
            return try (db?.pluck(ParagraphMetadataTable.table.filter(ParagraphMetadataTable.subitemID == subitemID && ParagraphMetadataTable.paragraphID == paragraphID)))?.map { ParagraphMetadataTable.fromRow($0) }
        } catch {
            return nil
        }
    }
    
    // MARK: Ordered Paragraph Methods
    
    /// Returns an array of ordered paragraphAIDs from the provided paragraphAIDs and subitemID. Ordered by ParagraphMetaData startIndex.
    public func orderedParagraphAIDs(fromParagraphAIDs paragraphAIDs: [String], subitemID: Int64) -> [String] {
        do {
            return try (db?.prepare(ParagraphMetadataTable.table.select(ParagraphMetadataTable.paragraphAID).filter(ParagraphMetadataTable.subitemID == subitemID && paragraphAIDs.contains(ParagraphMetadataTable.paragraphAID)).order(ParagraphMetadataTable.startIndex)))?.map { $0[ParagraphMetadataTable.paragraphAID] } ?? []
        } catch {
            return paragraphAIDs
        }
    }
    
    /// Returns an array of ordered paragraphAID's from the provided paragraphURIs. Ordered by ParagraphMetaData startIndex.
    public func orderedParagraphAIDs(fromParagraphURIs paragraphURIs: [String]) -> [String] {
        guard let firstParagraphURI = paragraphURIs.first, let index = firstParagraphURI.range(of: ".", options: .backwards)?.lowerBound else { return [] }
        
        let subitemURI = firstParagraphURI.substring(to: index)
        let paragraphIDs = paragraphURIs.flatMap { uri -> String? in
            guard let endIndex = uri.range(of: ".", options: .backwards)?.upperBound else { return nil }
            return uri.substring(from: endIndex)
        }
        
        do {
            return try (db?.prepare(ParagraphMetadataTable.table.select(ParagraphMetadataTable.paragraphAID).filter(paragraphIDs.contains(ParagraphMetadataTable.paragraphID)).join(SubitemTable.table.filter(SubitemTable.uri == subitemURI), on: ParagraphMetadataTable.subitemID == SubitemTable.table[SubitemTable.id]).order(ParagraphMetadataTable.startIndex)))?.map { $0[ParagraphMetadataTable.paragraphAID] } ?? []
        } catch {
            return []
        }
    }
    
    /// Returns an array of ordered paragraphIDs from the provided paragraphIDs and subitemID. Ordered by ParagraphMetaData startIndex.
    public func orderedParagraphIDs(fromParagraphIDs paragraphIDs: [String], subitemID: Int64) -> [String] {
        do {
            return try (db?.prepare(ParagraphMetadataTable.table.select(ParagraphMetadataTable.paragraphID).filter(ParagraphMetadataTable.subitemID == subitemID && paragraphIDs.contains(ParagraphMetadataTable.paragraphID)).order(ParagraphMetadataTable.startIndex)))?.map { $0[ParagraphMetadataTable.paragraphID] } ?? []
        } catch {
            return paragraphIDs
        }
    }
    
    /// Returns an array of orderedParagraphID's from the provided paragraphAIDs and subitemID. Ordered by ParagraphMetaData startIndex.
    public func orderedParagraphIDs(fromParagraphAIDs paragraphAIDs: [String], subitemID: Int64) -> [String] {
        do {
            return try (db?.prepare(ParagraphMetadataTable.table.select(ParagraphMetadataTable.paragraphID).filter(ParagraphMetadataTable.subitemID == subitemID && paragraphAIDs.contains(ParagraphMetadataTable.paragraphAID)).order(ParagraphMetadataTable.startIndex)))?.map { $0[ParagraphMetadataTable.paragraphID] } ?? []
        } catch {
            return []
        }
    }
    
    /// Returns an array of ordered paragraphURIs from the provided paragraphAIDS and subitemID. Ordered by ParagraphMetaData startIndex.
    public func orderedParagraphURIs(fromParagraphAIDs paragraphAIDs: [String], subitemID: Int64) -> [String] {
        do {
            return try (db?.prepare(SubitemTable.table.select(SubitemTable.uri, ParagraphMetadataTable.paragraphID).join(ParagraphMetadataTable.table.filter(paragraphAIDs.contains(ParagraphMetadataTable.paragraphAID)), on: ParagraphMetadataTable.subitemID == SubitemTable.table[SubitemTable.id]).order(ParagraphMetadataTable.startIndex)))?.map { String(format: "%@.%@", $0[SubitemTable.uri], $0[ParagraphMetadataTable.paragraphID]) } ?? []
        } catch {
            return []
        }
    }
    
	/// Returns verse numbers as an array of Strings from the provided docID and paragraphAIDs. Ordered by ParagraphMetaData startIndex.
    func verseNumbersForSubitemWithDocID(_ docID: String, paragraphAIDs: [String]) -> [String] {
        do {
            return try db?.prepare(ParagraphMetadataTable.table.select(ParagraphMetadataTable.verseNumber).filter(paragraphAIDs.contains(ParagraphMetadataTable.paragraphAID)).join(SubitemTable.table.filter(SubitemTable.docID == docID), on: ParagraphMetadataTable.subitemID == SubitemTable.table[SubitemTable.id]).order(ParagraphMetadataTable.startIndex)).flatMap { $0[ParagraphMetadataTable.verseNumber] } ?? []
        } catch {
            return []
        }
    }
    
}
