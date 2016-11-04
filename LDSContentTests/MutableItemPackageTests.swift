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

import XCTest
@testable import LDSContent

class MutableItemPacakgeTests: XCTestCase {
    
    var itemPackage: MutableItemPackage!
    
    func testSchemaVersion() {
        itemPackage.schemaVersion = Catalog.SchemaVersion
        XCTAssertEqual(itemPackage.schemaVersion, Catalog.SchemaVersion)
    }
    
    func testItemPackageVersion() {
        itemPackage.itemPackageVersion = 250
        XCTAssertEqual(itemPackage.itemPackageVersion, 250)
    }
    
    func testISO639_3Code() {
        itemPackage.iso639_3Code = "eng"
        XCTAssertEqual(itemPackage.iso639_3Code, "eng")
    }
    
    func testURI() {
        itemPackage.uri = "/scriptures/bofm"
        XCTAssertEqual(itemPackage.uri, "/scriptures/bofm")
    }
    
    func testItemID() {
        itemPackage.itemID = 1
        XCTAssertEqual(itemPackage.itemID, 1)
    }
    
    func testItemExternalID() {
        itemPackage.itemExternalID = "_scriptures_bofm_000"
        XCTAssertEqual(itemPackage.itemExternalID, "_scriptures_bofm_000")
    }
    
    func testVacuum() {
        XCTAssertNoThrow(try itemPackage.vacuum())
    }
    
    func testSubitem() {
        let subitem = try! itemPackage.addSubitemWithURI("/scriptures/bofm/1-ne/1", docID: "1", docVersion: 1, position: 1, titleHTML: "1 Nephi 1", title: "1 Nephi 1", webURL: URL(string: "https://www.lds.org/scriptures/bofm/1-ne/1")!)
        
        XCTAssertNoThrow(try itemPackage.addSubitemContentWithSubitemID(subitem.id, contentHTML: "<p>CATS: All your base are belong to us.</p>".data(using: String.Encoding.utf8)!))
        
        let searchResults = itemPackage.searchResultsForString("base")
        XCTAssertGreaterThan(searchResults.count, 0)
    }
    
    func testRange() {
        XCTAssertNoThrow(try itemPackage.addParagraphMetadata(paragraphID: "p1", paragraphAID: "12345", subitemID: 1, verseNumber: nil, range: NSRange(location: 3, length: 10)))
        
        let paragraphMetadata = itemPackage.paragraphMetadataForParagraphID("p1", subitemID: 1)!
        XCTAssertEqual(paragraphMetadata.subitemID, 1)
        XCTAssertEqual(paragraphMetadata.paragraphID, "p1")
        XCTAssertEqual(paragraphMetadata.range, NSRange(location: 3, length: 10))
    }
    
    func testRelatedContentItem() {
        XCTAssertNoThrow(try itemPackage.addRelatedContentItemWithSubitemID(1, refID: "1", labelHTML: "2", originID: "3", contentHTML: "4", wordOffset: 13, byteLocation: 97))
        
        let relatedContentItems = itemPackage.relatedContentItemsForSubitemWithID(1)
        XCTAssertGreaterThan(relatedContentItems.count, 0)
    }
    
    func testRelatedAudioItem() {
        XCTAssertNoThrow(try itemPackage.addRelatedAudioItemWithSubitemID(1, mediaURL: URL(string: "https://www.example.com/audio.mp3")!, fileSize: 1000, duration: 370, voice: .male))
        
        let relatedAudioItems = itemPackage.relatedAudioItemsForSubitemWithID(1)
        XCTAssertGreaterThan(relatedAudioItems.count, 0)
    }
    
    func testRelatedVideoItem() {
        XCTAssertNoThrow(try itemPackage.addRelatedVideoItem(subitemID: 1, posterURL: URL(string: "https://www.example.com/poster.jpg")!, videoID: "1", title: "TestVideo"))
        XCTAssertNoThrow(try itemPackage.addRelatedVideoItemSource(mediaURL: URL(string: "https://www.example.com/video.mp4")!, type: "mp4", size: CGSize(width: 1280, height: 720), fileSize: 123456789, relatedVideoItemID: 1))
        
        let relatedVideoItems = itemPackage.relatedVideoItemsForSubitemWithID(1)
        XCTAssertGreaterThan(relatedVideoItems.count, 0)
        
        let relatedVideoSources = itemPackage.relatedVideoItemSourcesForRelatedVideoItemWithID(1)
        XCTAssertGreaterThan(relatedVideoSources.count, 0)
    }
    
    func testNavCollection() {
        let navCollection = try! itemPackage.addNavCollectionWithNavSectionID(nil, position: 1, imageRenditions: [ImageRendition(size: CGSize(width: 10, height: 10), url: URL(string: "https://example.org/example.png")!)], titleHTML: "title", subtitle: nil, uri: "/scriptures/bofm")
        
        let navCollection2 = itemPackage.navCollectionWithID(navCollection.id)
        XCTAssertEqual(navCollection2, navCollection)
    }
    
    func testNavCollectionIndexEntry() {
        let navCollectionIndexEntry = try! itemPackage.addNavCollectionIndexEntryWithNavCollectionID(1, position: 1, title: "title", listIndex: 1, section: 1, row: 2)
        
        let navCollectionIndexEntry2 = itemPackage.navCollectionIndexEntryWithID(navCollectionIndexEntry.id)
        XCTAssertEqual(navCollectionIndexEntry2, navCollectionIndexEntry)
    }
    
    func testNavSection() {
        let navSection = try! itemPackage.addNavSectionWithNavCollectionID(1, position: 1, title: nil, indentLevel: 1)
        
        let navSection2 = itemPackage.navSectionWithID(navSection.id)
        XCTAssertEqual(navSection2, navSection)
    }
    
    func testNavItem() {
        let navItem = try! itemPackage.addNavItemWithNavSectionID(1, position: 1, imageRenditions: [ImageRendition(size: CGSize(width: 10, height: 10), url: URL(string: "https://example.org/example.png")!)], titleHTML: "title", subtitle: nil, preview: nil, uri: "sparky", subitemID: 1)
        
        let navItem2 = itemPackage.navItemWithURI("sparky")
        XCTAssertEqual(navItem2, navItem)
    }
    
    func testParagraphMetadata() {
        XCTAssertNoThrow(try itemPackage.addParagraphMetadata(paragraphID: "p1", paragraphAID: "1", subitemID: 1, verseNumber: "1", range: NSRange(location: 1, length: 2)))
    }
    
    func testQueryWithVoicesOnAudioItemWithVoices() {
        let subitemWithMaleAndFemaleVoices = try! itemPackage.addSubitemWithURI("/scriptures/bofm/1-ne/1", docID: "1", docVersion: 1, position: 1, titleHTML: "1 Nephi 1", title: "1 Nephi 1", webURL: URL(string: "https://www.lds.org/scriptures/bofm/1-ne/1")!)
        
        // Add related audio with Male Voice
        XCTAssertNoThrow(try itemPackage.addRelatedAudioItemWithSubitemID(Int64(1), mediaURL: URL(string: "https://www.example.com/audio.mp3")!, fileSize: 1000, duration: 370, voice: RelatedAudioVoice(rawValue: Int64(1))))
        // Add related audio with Female Voice
        XCTAssertNoThrow(try itemPackage.addRelatedAudioItemWithSubitemID(Int64(1), mediaURL: URL(string: "https://www.example.com/audio.mp3")!, fileSize: 1000, duration: 370, voice: RelatedAudioVoice(rawValue: Int64(2))))
        // Add related audio with nil Voice
        XCTAssertNoThrow(try itemPackage.addRelatedAudioItemWithSubitemID(Int64(1), mediaURL: URL(string: "https://www.example.com/audio.mp3")!, fileSize: 1000, duration: 370, voice: RelatedAudioVoice(rawValue: Int64(3))))
        
        // Voice option is selected, there is a matching related audio item with that voice
        let relatedAudioItemWithMaleVoice = itemPackage.relatedAudioItemForSubitemWithURI(subitemWithMaleAndFemaleVoices.uri, relatedAudioVoice: .male)
        XCTAssertNotNil(relatedAudioItemWithMaleVoice)
        XCTAssertTrue(relatedAudioItemWithMaleVoice!.voice == .male)
        
        let relatedAudioItemWithFemaleVoice = itemPackage.relatedAudioItemForSubitemWithURI(subitemWithMaleAndFemaleVoices.uri, relatedAudioVoice: .female)
        XCTAssertNotNil(relatedAudioItemWithFemaleVoice)
        XCTAssertTrue(relatedAudioItemWithFemaleVoice!.voice == .female)
    
    }
    
    func testQueryWithVoicesOnAudioItemWithNilVoices() {
        let subitemWithMaleAndFemaleVoices = try! itemPackage.addSubitemWithURI("/scriptures/bofm/1-ne/1", docID: "1", docVersion: 1, position: 1, titleHTML: "1 Nephi 1", title: "1 Nephi 1", webURL: URL(string: "https://www.lds.org/scriptures/bofm/1-ne/1")!)
        
        // Add only related audio items with nil voices
        XCTAssertNoThrow(try itemPackage.addRelatedAudioItemWithSubitemID(Int64(1), mediaURL: URL(string: "https://www.example.com/audio.mp3")!, fileSize: 1000, duration: 370, voice: RelatedAudioVoice(rawValue: Int64(3))))
        XCTAssertNoThrow(try itemPackage.addRelatedAudioItemWithSubitemID(Int64(1), mediaURL: URL(string: "https://www.example.com/audio.mp3")!, fileSize: 1000, duration: 370, voice: RelatedAudioVoice(rawValue: Int64(3))))
        
        // Voice option is selected, there is a matching related audio item with that voice
        let relatedAudioItemWithMaleVoice = itemPackage.relatedAudioItemForSubitemWithURI(subitemWithMaleAndFemaleVoices.uri, relatedAudioVoice: .male)
        XCTAssertNotNil(relatedAudioItemWithMaleVoice)
        XCTAssertTrue(relatedAudioItemWithMaleVoice!.voice == nil)
        
        let relatedAudioItemWithFemaleVoice = itemPackage.relatedAudioItemForSubitemWithURI(subitemWithMaleAndFemaleVoices.uri, relatedAudioVoice: .female)
        XCTAssertNotNil(relatedAudioItemWithFemaleVoice)
        XCTAssertTrue(relatedAudioItemWithFemaleVoice!.voice == nil)
        
    }
    
    func testQueryWithNilVoiceOnAudioItemWithVoices() {
        let subitemWithMaleAndFemaleVoices = try! itemPackage.addSubitemWithURI("/scriptures/bofm/1-ne/1", docID: "1", docVersion: 1, position: 1, titleHTML: "1 Nephi 1", title: "1 Nephi 1", webURL: URL(string: "https://www.lds.org/scriptures/bofm/1-ne/1")!)
        
        // Add related audio with Male Voice
        XCTAssertNoThrow(try itemPackage.addRelatedAudioItemWithSubitemID(Int64(1), mediaURL: URL(string: "https://www.example.com/audio.mp3")!, fileSize: 1000, duration: 370, voice: RelatedAudioVoice(rawValue: Int64(1))))
        // Add related audio with Female Voice
        XCTAssertNoThrow(try itemPackage.addRelatedAudioItemWithSubitemID(Int64(1), mediaURL: URL(string: "https://www.example.com/audio.mp3")!, fileSize: 1000, duration: 370, voice: RelatedAudioVoice(rawValue: Int64(2))))
        
        // No voice option is passed, and there is only Male/Female related audio for a chapter
        let relatedAudioItemWithMaleOrFemaleVoice = itemPackage.relatedAudioItemForSubitemWithURI(subitemWithMaleAndFemaleVoices.uri, relatedAudioVoice: nil)
        XCTAssertNotNil(relatedAudioItemWithMaleOrFemaleVoice)
        let voice = relatedAudioItemWithMaleOrFemaleVoice!.voice
        XCTAssertTrue(voice == .female || voice == .male)

    }
    
    func testQueryWithWrongVoicesOnAudioItemWithVoices() {
        let subitemWithMaleVoice = try! itemPackage.addSubitemWithURI("/scriptures/bofm/1-ne/1", docID: "1", docVersion: 1, position: 1, titleHTML: "1 Nephi 1", title: "1 Nephi 1", webURL: URL(string: "https://www.lds.org/scriptures/bofm/1-ne/1")!)
        
        let subitemWithFemaleVoice = try! itemPackage.addSubitemWithURI("/scriptures/bofm/1-ne/2", docID: "2", docVersion: 1, position: 2, titleHTML: "1 Nephi 2", title: "1 Nephi 2", webURL: URL(string: "https://www.lds.org/scriptures/bofm/1-ne/2")!)
        
        let subitemWithFemaleVoiceAndNil = try! itemPackage.addSubitemWithURI("/scriptures/bofm/1-ne/3", docID: "3", docVersion: 1, position: 3, titleHTML: "1 Nephi 3", title: "1 Nephi 3", webURL: URL(string: "https://www.lds.org/scriptures/bofm/1-ne/3")!)
        
        // Add related audio with Male Voice to subitemWithMaleVoice
        XCTAssertNoThrow(try itemPackage.addRelatedAudioItemWithSubitemID(Int64(1), mediaURL: URL(string: "https://www.example.com/audio.mp3")!, fileSize: 1000, duration: 370, voice: RelatedAudioVoice(rawValue: Int64(1))))
        // Add related audio with Female Voice to subitemWithFemaleVoice
        XCTAssertNoThrow(try itemPackage.addRelatedAudioItemWithSubitemID(Int64(2), mediaURL: URL(string: "https://www.example.com/audio.mp3")!, fileSize: 1000, duration: 370, voice: RelatedAudioVoice(rawValue: Int64(2))))
        
        // Add related audio with Female Voice and Nil voice to subitemWithFemaleVoiceAndNil
        XCTAssertNoThrow(try itemPackage.addRelatedAudioItemWithSubitemID(Int64(3), mediaURL: URL(string: "https://www.example.com/audio.mp3")!, fileSize: 1000, duration: 370, voice: RelatedAudioVoice(rawValue: Int64(2))))
        XCTAssertNoThrow(try itemPackage.addRelatedAudioItemWithSubitemID(Int64(3), mediaURL: URL(string: "https://www.example.com/audio.mp3")!, fileSize: 1000, duration: 370, voice: RelatedAudioVoice(rawValue: Int64(3))))
        
        // Female voice option is passed, but there is only related audio with a male voice
        let relatedAudioItemWithFemaleVoice = itemPackage.relatedAudioItemForSubitemWithURI(subitemWithMaleVoice.uri, relatedAudioVoice: .female)
        
        // Male voice option is passed, but there is only related audio with a female voice
        let relatedAudioItemWithMaleVoice = itemPackage.relatedAudioItemForSubitemWithURI(subitemWithFemaleVoice.uri, relatedAudioVoice: .male)
        
        // Male voice option is passed, but there is only related audio with a female voice and nil voice
        let relatedAudioItemWithMaleVoiceOrNil = itemPackage.relatedAudioItemForSubitemWithURI(subitemWithFemaleVoiceAndNil.uri, relatedAudioVoice: .male)
        
        // Make sure we still get an audio item
        XCTAssertNotNil(relatedAudioItemWithFemaleVoice)
        XCTAssertNotNil(relatedAudioItemWithMaleVoice)
        XCTAssertNotNil(relatedAudioItemWithMaleVoiceOrNil)
        
        // Make sure the related audio item returned is the only voice available which in this case is the opposite gender.
        XCTAssertTrue(relatedAudioItemWithFemaleVoice!.voice == .male)
        XCTAssertTrue(relatedAudioItemWithMaleVoice!.voice == .female)
        
        // Since the male voice requested is not present, but nil and female is, voice defaults to nil.
        XCTAssertTrue(relatedAudioItemWithMaleVoiceOrNil!.voice == nil)
        
    }
    
    let tempPackageURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
    
    override func setUp() {
        super.setUp()
        
        do {
            try FileManager.default.createDirectory(at: tempPackageURL, withIntermediateDirectories: true, attributes: nil)
            itemPackage = try MutableItemPackage(url: tempPackageURL, iso639_1Code: "en", iso639_3Code: "eng")
        } catch {
            itemPackage = nil
        }
    }
    
    override func tearDown() {
        super.tearDown()
        
        let _ = try? FileManager.default.removeItem(at: tempPackageURL)
    }
    
}
