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
    
    class RelatedVideoItemTable {
        
        static let table = Table("related_video_item")
        static let id = Expression<Int64>("_id")
        static let subitemID = Expression<Int64>("subitem_id")
        static let posterURL = Expression<String?>("poster_url")
        static let videoID = Expression<String>("video_id")
        static let title = Expression<String>("title")
        
        static func fromRow(_ row: Row) -> RelatedVideoItem {
            return RelatedVideoItem(id: row[id], subitemID: row[subitemID], posterURL: row[posterURL].flatMap { URL(string: $0) }, videoID: row[videoID], title: row[title])
        }
        
        static func fromNamespacedRow(_ row: Row) -> RelatedVideoItem {
            return RelatedVideoItem(id: row[RelatedAudioItemTable.table[id]], subitemID: row[RelatedAudioItemTable.table[subitemID]], posterURL: row[RelatedAudioItemTable.table[posterURL]].flatMap { URL(string: $0) }, videoID: row[RelatedAudioItemTable.table[videoID]], title: row[RelatedAudioItemTable.table[title]])
        }
        
    }
    
    class RelatedVideoItemSourceTable {
        
        static let table = Table("related_video_item_source")
        static let id = Expression<Int64>("_id")
        static let mediaURL = Expression<String>("media_url")
        static let type = Expression<String>("type")
        static let width = Expression<Int?>("width")
        static let height = Expression<Int?>("height")
        static let fileSize = Expression<Int64?>("file_size")
        static let relatedVideoItemID = Expression<Int64>("related_video_item_id")
        
        static func fromRow(_ row: Row) -> RelatedVideoItemSource? {
            guard let mediaURL = URL(string: row[mediaURL]) else { return nil }
            
            var size: CGSize?
            if let width = row[width], let height = row[height] {
                size = CGSize(width: width, height: height)
            }
            return RelatedVideoItemSource(id: row[id], mediaURL: mediaURL, type: row[type], size: size, fileSize: row[fileSize], relatedVideoItemID: row[relatedVideoItemID])
        }
        
        static func fromNamespacedRow(_ row: Row) -> RelatedVideoItemSource? {
            guard let mediaURL = URL(string: row[RelatedAudioItemTable.table[mediaURL]]) else { return nil }
            
            var size: CGSize?
            if let width = row[RelatedAudioItemTable.table[width]], let height = row[RelatedAudioItemTable.table[height]] {
                size = CGSize(width: width, height: height)
            }
            return RelatedVideoItemSource(id: row[RelatedAudioItemTable.table[id]], mediaURL: mediaURL, type: row[RelatedAudioItemTable.table[type]], size: size, fileSize: row[RelatedAudioItemTable.table[fileSize]], relatedVideoItemID: row[RelatedAudioItemTable.table[relatedVideoItemID]])
        }
        
    }
    
    public func relatedVideoItemsForSubitemWithID(_ subitemID: Int64) -> [RelatedVideoItem] {
        do {
            return try (db?.prepare(RelatedVideoItemTable.table.filter(RelatedVideoItemTable.subitemID == subitemID)))?.map { RelatedVideoItemTable.fromRow($0) } ?? []
        } catch {
            return []
        }
    }
    
    public func relatedVideoItemSourcesForRelatedVideoItemWithID(_ relatedVideoItemID: Int64) -> [RelatedVideoItemSource] {
        do {
            return try db?.prepare(RelatedVideoItemSourceTable.table.filter(RelatedVideoItemSourceTable.relatedVideoItemID == relatedVideoItemID)).flatMap { RelatedVideoItemSourceTable.fromRow($0) } ?? []
        } catch {
            return []
        }
    }
    
}
