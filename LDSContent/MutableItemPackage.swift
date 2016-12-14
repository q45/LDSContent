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

public enum MutableItemPackageError: Error {
    case nilConnectionError
}

public class MutableItemPackage: ItemPackage {
    
    public init(url: URL, iso639_1Code: String, iso639_3Code: String) throws {
        try super.init(url: url, readonly: false)
        
        try createDatabaseTables(iso639_1Code: iso639_1Code)
        
        self.iso639_3Code = iso639_3Code
    }
    
    fileprivate func createDatabaseTables(iso639_1Code: String) throws {
        try db?.transaction {
            if self.db?.tableExists("metadata") == false {
                if let sqlPath = Bundle(for: type(of: self)).path(forResource: "ItemPackage", ofType: "sql") {
                    let sql = String(format: try String(contentsOfFile: sqlPath, encoding: String.Encoding.utf8), iso639_1Code)
                    try self.db?.execute(sql)
                } else {
                    throw ContentError.errorWithCode(.unknown, failureReason: "Unable to locate SQL for item package.")
                }
            }
        }
    }
    
    public override var schemaVersion: Int {
        get {
            return super.schemaVersion
        }
        set {
            setInt(Int64(newValue), forMetadataKey: "schemaVersion")
        }
    }
    
    public override var itemPackageVersion: Int {
        get {
            return super.itemPackageVersion
        }
        set {
            setInt(Int64(newValue), forMetadataKey: "itemPackageVersion")
        }
    }
    
    public override var iso639_3Code: String? {
        get {
            return super.iso639_3Code
        }
        set {
            setString(newValue, forMetadataKey: "iso639_3")
        }
    }
    
    public override var uri: String? {
        get {
            return super.uri
        }
        set {
            setString(newValue, forMetadataKey: "uri")
        }
    }
    
    public override var itemID: Int64? {
        get {
            return super.itemID
        }
        set {
            setInt(newValue, forMetadataKey: "item_id")
        }
    }
    
    public override var itemExternalID: String? {
        get {
            return super.itemExternalID
        }
        set {
            setString(newValue, forMetadataKey: "item_external_id")
        }
    }
    
    public func vacuum() throws {
        try db?.execute("VACUUM")
    }
    
}

extension MutableItemPackage {
    
    func setInt(_ integerValue: Int64?, forMetadataKey key: String) {
        do {
            if let integerValue = integerValue {
                _ = try db?.run(MetadataTable.table.insert(or: .replace, MetadataTable.key <- key, MetadataTable.integerValue <- integerValue))
            } else {
                _ = try db?.run(MetadataTable.table.filter(MetadataTable.key == key).delete())
            }
        } catch {}
    }
    
    func setString(_ stringValue: String?, forMetadataKey key: String) {
        do {
            if let stringValue = stringValue {
                _ = try db?.run(MetadataTable.table.insert(or: .replace, MetadataTable.key <- key, MetadataTable.stringValue <- stringValue))
            } else {
                _ = try db?.run(MetadataTable.table.filter(MetadataTable.key == key).delete())
            }
        } catch {}
    }
    
}

extension MutableItemPackage {
    
    public func addSubitemWithURI(_ uri: String, docID: String, docVersion: Int, position: Int, titleHTML: String, title: String, webURL: URL, contentType: ContentType = .standard) throws -> Subitem {
        guard let id = try db?.run(SubitemTable.table.insert(
            SubitemTable.uri <- uri,
            SubitemTable.docID <- docID,
            SubitemTable.docVersion <- docVersion,
            SubitemTable.position <- position,
            SubitemTable.titleHTML <- titleHTML,
            SubitemTable.title <- title,
            SubitemTable.webURL <- webURL.absoluteString,
            SubitemTable.contentType <- contentType
        )) else { throw MutableItemPackageError.nilConnectionError }
        
        return Subitem(id: id, uri: uri, docID: docID, docVersion: docVersion, position: position, titleHTML: titleHTML, title: title, webURL: webURL, contentType: contentType)
    }
    
    public func addSubitemContentWithSubitemID(_ subitemID: Int64, contentHTML: Data) throws -> SubitemContent {
        guard let id = try db?.run(SubitemContentVirtualTable.table.insert(
            SubitemContentVirtualTable.subitemID <- subitemID,
            SubitemContentVirtualTable.contentHTML <- contentHTML
        ))  else { throw MutableItemPackageError.nilConnectionError }
        
        return SubitemContent(id: id, subitemID: subitemID, contentHTML: contentHTML)
    }

    public func addRelatedContentItemWithSubitemID(_ subitemID: Int64, refID: String, labelHTML: String, originID: String, contentHTML: String, wordOffset: Int, byteLocation: Int) throws -> RelatedContentItem {
        guard let id = try db?.run(RelatedContentItemTable.table.insert(
            RelatedContentItemTable.subitemID <- subitemID,
            RelatedContentItemTable.refID <- refID,
            RelatedContentItemTable.labelHTML <- labelHTML,
            RelatedContentItemTable.originID <- originID,
            RelatedContentItemTable.contentHTML <- contentHTML,
            RelatedContentItemTable.wordOffset <- wordOffset,
            RelatedContentItemTable.byteLocation <- byteLocation
        )) else { throw MutableItemPackageError.nilConnectionError }
        
        return RelatedContentItem(id: id, subitemID: subitemID, refID: refID, labelHTML: labelHTML, originID: originID, contentHTML: contentHTML, wordOffset: wordOffset, byteLocation: byteLocation)
    }
    
    public func addRelatedAudioItemWithSubitemID(_ subitemID: Int64, mediaURL: URL, fileSize: Int64, duration: Int, voice: RelatedAudioVoice?) throws -> RelatedAudioItem {
        guard let id = try db?.run(RelatedAudioItemTable.table.insert(
            RelatedAudioItemTable.subitemID <- subitemID,
            RelatedAudioItemTable.mediaURL <- mediaURL.absoluteString,
            RelatedAudioItemTable.fileSize <- fileSize,
            RelatedAudioItemTable.duration <- duration,
            RelatedAudioItemTable.voice <- voice
        )) else { throw MutableItemPackageError.nilConnectionError }
        
        return RelatedAudioItem(id: id, subitemID: subitemID, mediaURL: mediaURL, fileSize: fileSize, duration: duration, voice: voice)
    }
    
    public func addRelatedVideoItem(subitemID: Int64, posterURL: URL, videoID: String, title: String) throws -> RelatedVideoItem {
        guard let id = try db?.run(RelatedVideoItemTable.table.insert(
            RelatedVideoItemTable.subitemID <- subitemID,
            RelatedVideoItemTable.posterURL <- posterURL.absoluteString,
            RelatedVideoItemTable.videoID <- videoID,
            RelatedVideoItemTable.title <- title
        )) else { throw MutableItemPackageError.nilConnectionError }
        
        return RelatedVideoItem(id: id, subitemID: subitemID, posterURL: posterURL, videoID: videoID, title: title)
    }
    
    public func addRelatedVideoItemSource(mediaURL: URL, type: String, size: CGSize?, fileSize: Int64?, relatedVideoItemID: Int64) throws -> RelatedVideoItemSource {
        guard let id = try db?.run(RelatedVideoItemSourceTable.table.insert(
            RelatedVideoItemSourceTable.mediaURL <- mediaURL.absoluteString,
            RelatedVideoItemSourceTable.type <- type,
            RelatedVideoItemSourceTable.width <- size.flatMap { Int($0.width) },
            RelatedVideoItemSourceTable.height <- size.flatMap { Int($0.height) },
            RelatedVideoItemSourceTable.fileSize <- fileSize,
            RelatedVideoItemSourceTable.relatedVideoItemID <- relatedVideoItemID
        )) else { throw MutableItemPackageError.nilConnectionError }
        
        return RelatedVideoItemSource(id: id, mediaURL: mediaURL, type: type, size: size, fileSize: fileSize, relatedVideoItemID: relatedVideoItemID)
    }
    
    public func addNavCollectionWithNavSectionID(_ navSectionID: Int64?, position: Int, imageRenditions: [ImageRendition]?, titleHTML: String, subtitle: String?, uri: String) throws -> NavCollection {
        guard let id = try db?.run(NavCollectionTable.table.insert(
            NavCollectionTable.navSectionID <- navSectionID,
            NavCollectionTable.position <- position,
            NavCollectionTable.imageRenditions <- String(imageRenditions),
            NavCollectionTable.titleHTML <- titleHTML,
            NavCollectionTable.subtitle <- subtitle,
            NavCollectionTable.uri <- uri
        )) else { throw MutableItemPackageError.nilConnectionError }
        
        return NavCollection(id: id, navSectionID: navSectionID, position: position, imageRenditions: imageRenditions, titleHTML: titleHTML, subtitle: subtitle, uri: uri)
    }

    public func addNavCollectionIndexEntryWithNavCollectionID(_ navCollectionID: Int64, position: Int, title: String, listIndex: Int, section: Int, row: Int) throws -> NavCollectionIndexEntry {
        guard let id = try db?.run(NavCollectionIndexEntryTable.table.insert(
            NavCollectionIndexEntryTable.navCollectionID <- navCollectionID,
            NavCollectionIndexEntryTable.position <- position,
            NavCollectionIndexEntryTable.title <- title,
            NavCollectionIndexEntryTable.listIndex <- listIndex,
            NavCollectionIndexEntryTable.indexPathSection <- section,
            NavCollectionIndexEntryTable.indexPathRow <- row
        )) else { throw MutableItemPackageError.nilConnectionError }
        
        return NavCollectionIndexEntry(id: id, navCollectionID: navCollectionID, position: position, title: title, listIndex: listIndex, indexPath: IndexPath(item: row, section: section))
    }
    
    public func addNavSectionWithNavCollectionID(_ navCollectionID: Int64, position: Int, title: String?, indentLevel: Int) throws -> NavSection {
        guard let id = try db?.run(NavSectionTable.table.insert(
            NavSectionTable.navCollectionID <- navCollectionID,
            NavSectionTable.position <- position,
            NavSectionTable.indentLevel <- indentLevel,
            NavSectionTable.title <- title
        )) else { throw MutableItemPackageError.nilConnectionError }
        
        return NavSection(id: id, navCollectionID: navCollectionID, position: position, indentLevel: indentLevel, title: title)
    }
    
    public func addNavItemWithNavSectionID(_ navSectionID: Int64, position: Int, imageRenditions: [ImageRendition]?, titleHTML: String, subtitle: String?, preview: String?, uri: String, subitemID: Int64) throws -> NavItem {
        guard let id = try db?.run(NavItemTable.table.insert(
            NavItemTable.navSectionID <- navSectionID,
            NavItemTable.position <- position,
            NavItemTable.imageRenditions <- String(imageRenditions),
            NavItemTable.titleHTML <- titleHTML,
            NavItemTable.subtitle <- subtitle,
            NavItemTable.preview <- preview,
            NavItemTable.uri <- uri,
            NavItemTable.subitemID <- subitemID
        )) else { throw MutableItemPackageError.nilConnectionError }
        
        return NavItem(id: id, navSectionID: navSectionID, position: position, imageRenditions: imageRenditions, titleHTML: titleHTML, subtitle: subtitle, preview: preview, uri: uri, subitemID: subitemID)
    }
    
    public func addParagraphMetadata(paragraphID: String, paragraphAID: String, subitemID: Int64, verseNumber: String?, range: NSRange) throws {
        _ = try db?.run(ParagraphMetadataTable.table.insert(
            ParagraphMetadataTable.subitemID <- subitemID,
            ParagraphMetadataTable.paragraphID <- paragraphID,
            ParagraphMetadataTable.paragraphAID <- paragraphAID,
            ParagraphMetadataTable.verseNumber <- verseNumber,
            ParagraphMetadataTable.startIndex <- range.location,
            ParagraphMetadataTable.endIndex <- range.location + range.length
        ))
    }
    
    public func addAuthor(givenName: String, familyName: String, imageRenditions: [ImageRendition]?) throws -> Author {
        if let author = authorWithGivenName(givenName, familyName: familyName) {
            return author
        }
        
        guard let id = try db?.run(AuthorTable.table.insert(or: .ignore,
            AuthorTable.givenName <- givenName,
            AuthorTable.familyName <- familyName,
            AuthorTable.imageRenditions <- String(imageRenditions)
        )) else { throw MutableItemPackageError.nilConnectionError }
        
        return Author(id: id, givenName: givenName, familyName: familyName, imageRenditions: imageRenditions)
    }
    
    public func addRole(name: String, position: Int) throws -> Role {
        if let role = roleWithName(name) {
            return role
        }
        
        guard let id = try db?.run(RoleTable.table.insert(or: .ignore,
            RoleTable.name <- name,
            RoleTable.position <- position
        )) else { throw MutableItemPackageError.nilConnectionError }
        
        return Role(id: id, name: name, position: position)
    }
    
    public func addAuthorRole(author: Author, role: Role, position: Int) throws -> AuthorRole {
        guard let id = try db?.run(AuthorRoleTable.table.insert(or: .ignore,
            AuthorRoleTable.authorID <- author.id,
            AuthorRoleTable.roleID <- role.id,
            AuthorRoleTable.position <- position
        )) else { throw MutableItemPackageError.nilConnectionError }
        
        return AuthorRole(id: id, authorID: author.id, roleID: role.id, position: position)
    }
    
    public func addSubitemAuthor(subitem: Subitem, author: Author) throws {
        _ = try db?.run(SubitemAuthorTable.table.insert(or: .ignore,
            SubitemAuthorTable.subitemID <- subitem.id,
            SubitemAuthorTable.authorID <- author.id
        ))
    }
    
    public func addTopic(_ name: String) throws -> Topic {
        if let topic = topicWithName(name) {
            return topic
        }
        
        guard let id = try db?.run(TopicTable.table.insert(
            TopicTable.name <- name
        )) else { throw MutableItemPackageError.nilConnectionError }
        
        return Topic(id: id, name: name)
    }
    
    public func addSubitemTopic(_ subitem: Subitem, topic: Topic) throws {
        _ = try db?.run(SubitemTopicTable.table.insert(or: .ignore,
            SubitemTopicTable.subitemID <- subitem.id,
            SubitemTopicTable.topicID <- topic.id
        ))
    }
    
}
