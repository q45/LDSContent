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
    
    class RelatedAudioItemTable {
        
        static let table = Table("related_audio_item")
        static let id = Expression<Int64>("_id")
        static let subitemID = Expression<Int64>("subitem_id")
        static let mediaURL = Expression<String>("media_url")
        static let fileSize = Expression<Int64>("file_size")
        static let duration = Expression<Int>("duration")
        static let voice = Expression<RelatedAudioVoice?>("related_audio_voice_id")
        
        static func fromRow(_ row: Row) -> RelatedAudioItem? {
            guard let mediaURL = URL(string: row[mediaURL]) else { return nil }
            
            return RelatedAudioItem(id: row[id], subitemID: row[subitemID], mediaURL: mediaURL, fileSize: row[fileSize], duration: row[duration], voice: row.get(voice))
        }
        
        static func fromNamespacedRow(_ row: Row) -> RelatedAudioItem? {
            guard let mediaURL = URL(string: row[RelatedAudioItemTable.table[mediaURL]]) else { return nil }
            
            return RelatedAudioItem(id: row[RelatedAudioItemTable.table[id]], subitemID: row[RelatedAudioItemTable.table[subitemID]], mediaURL: mediaURL, fileSize: row[RelatedAudioItemTable.table[fileSize]], duration: row[RelatedAudioItemTable.table[duration]], voice: row.get(RelatedAudioItemTable.voice))
        }
        
    }
    
    public func relatedAudioItemForSubitemWithURI(_ subitemURI: String, relatedAudioVoice: RelatedAudioVoice? = nil) -> RelatedAudioItem? {
        do {
            let relatedAudioItems = try db?.prepare(RelatedAudioItemTable.table.join(SubitemTable.table, on: SubitemTable.table[SubitemTable.id] == RelatedAudioItemTable.table[RelatedAudioItemTable.subitemID]).filter(SubitemTable.uri == subitemURI).order(RelatedAudioItemTable.voice)).flatMap { RelatedAudioItemTable.fromNamespacedRow($0) } ?? []
            return relatedAudioItems.find { $0.voice == relatedAudioVoice } ?? relatedAudioItems.first
        } catch {
            return nil
        }
    }
    
    public func relatedAudioItemsForSubitemWithID(_ subitemID: Int64) -> [RelatedAudioItem] {
        do {
            return try db?.prepare(RelatedAudioItemTable.table.filter(RelatedAudioItemTable.subitemID == subitemID)).flatMap { RelatedAudioItemTable.fromRow($0) } ?? []
        } catch {
            return []
        }
    }
    
    public func relatedAudioItemsForSubitemsWithIDs(_ subitemIDs: [Int64]) -> [RelatedAudioItem] {
        do {
            return try db?.prepare(RelatedAudioItemTable.table.filter(subitemIDs.contains(RelatedAudioItemTable.subitemID))).flatMap { RelatedAudioItemTable.fromRow($0) } ?? []
        } catch {
            return []
        }
    }
    
    public func hasRelatedAudioItemsForSubitemsWithIDs(_ subitemIDs: [Int64]) -> Bool {
        do {
            return try db?.scalar(RelatedAudioItemTable.table.filter(subitemIDs.contains(RelatedAudioItemTable.subitemID)).count) ?? 0 > 0
        } catch {
            return false
        }
    }
    
    fileprivate func subitemIDsForDescendantsOfNavNode(_ navNode: NavNode) -> [Int64] {
        var subitemIDs = Set<Int64>()
        
        switch navNode {
        case let navItem as NavItem:
            subitemIDs.insert(navItem.subitemID)
        case let navCollection as NavCollection:
            for section in navSectionsForNavCollectionWithID(navCollection.id) {
                for navNode in navNodesForNavSectionWithID(section.id) {
                    subitemIDs.formUnion(subitemIDsForDescendantsOfNavNode(navNode))
                }
            }
        default:
            break
        }
        
        return Array(subitemIDs)
    }
    
    func relatedAudioItemsInNavCollection(_ collection: NavCollection) -> [RelatedAudioItem] {
        let subitemIDs = subitemIDsForDescendantsOfNavNode(collection)
        return relatedAudioItemsForSubitemsWithIDs(subitemIDs)
    }
    
    func relatedAudioAvailableInNavCollection(_ collection: NavCollection) -> Bool {
        let subitemIDs = subitemIDsForDescendantsOfNavNode(collection)
        return hasRelatedAudioItemsForSubitemsWithIDs(subitemIDs)
    }
    
}
