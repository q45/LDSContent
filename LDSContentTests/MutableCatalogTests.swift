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

class MutableCatalogTests: XCTestCase {
    
    var catalog: MutableCatalog!
    
    func testSchemaVersion() {
        catalog.schemaVersion = Catalog.SchemaVersion
        XCTAssertEqual(catalog.schemaVersion, Catalog.SchemaVersion)
    }
    
    func testCatalogVersion() {
        catalog.catalogVersion = 250
        XCTAssertEqual(catalog.catalogVersion, 250)
    }
    
    func testVacuum() {
        XCTAssertNoThrow(try catalog.vacuum())
    }
    
    func testSource() {
        let source = Source(id: 1, name: "source", type: .standard)
        
        XCTAssertNoThrow(try catalog.addOrUpdateSource(source))
        XCTAssertEqual(catalog.sources(), [source])
            
        XCTAssertNoThrow(try catalog.addOrUpdateSource(source))
        XCTAssertEqual(catalog.sources(), [source])
        
        let source2 = Source(id: 2, name: "source2", type: .standard)
        
        XCTAssertNoThrow(try catalog.addOrUpdateSource(source2))
        XCTAssertEqual(catalog.sources(), [source, source2])
        
        let source3 = Source(id: source.id, name: "changed", type: source.type)
        
        XCTAssertNoThrow(try catalog.addOrUpdateSource(source3))
        XCTAssertEqual(catalog.sources(), [source3, source2])
    }
    
    func testItemCategory() {
        let itemCategory = ItemCategory(id: 1, name: "category")
        
        XCTAssertNoThrow(try catalog.addOrUpdateItemCategory(itemCategory))
        XCTAssertEqual(catalog.itemCategoryWithID(1), itemCategory)
    }
    
    func testItem() {
        let item = Item(id: 1, externalID: "1", languageID: 1, sourceID: 1, platform: .all, uri: "/item", title: "Item", itemCoverRenditions: [ImageRendition(size: CGSize(width: 10, height: 10), url: URL(string: "https://example.org/example.png")!)], itemCategoryID: 1, version: 1, obsolete: false)
        
        XCTAssertNoThrow(try catalog.addOrUpdateItem(item))
        XCTAssertEqual(catalog.itemWithID(1), item)
    }
    
    func testLanguage() {
        let language = Language(id: 1, ldsLanguageCode: "000", iso639_3Code: "eng", bcp47Code: "en", rootLibraryCollectionID: 1, rootLibraryCollectionExternalID: "1")
        
        XCTAssertNoThrow(try catalog.addOrUpdateLanguage(language))
        XCTAssertEqual(catalog.languageWithID(1), language)
    }
    
    func testLanguageNames() {
        XCTAssertNoThrow(try catalog.setName("English", forLanguageWithID: 1, inLanguageWithID: 1))
        XCTAssertEqual(catalog.nameForLanguageWithID(1, inLanguageWithID: 1), "English")
    }
    
    func testLibraryCollection() {
        let libraryCollection = LibraryCollection(id: 1, externalID: "1", librarySectionID: nil, librarySectionExternalID: nil, position: 1, titleHTML: "collection", coverRenditions: [ImageRendition(size: CGSize(width: 10, height: 10), url: URL(string: "https://example.org/example.png")!)], type: .standard)
        
        XCTAssertNoThrow(try catalog.addOrUpdateLibraryCollection(libraryCollection))
        XCTAssertEqual(catalog.libraryCollectionWithID(1), libraryCollection)
    }
    
    func testLibrarySection() {
        let librarySection = LibrarySection(id: 1, externalID: "1", libraryCollectionID: 1, libraryCollectionExternalID: "1", position: 1, title: "section", indexTitle: nil)
        
        XCTAssertNoThrow(try catalog.addOrUpdateLibrarySection(librarySection))
        XCTAssertEqual(catalog.librarySectionWithID(1), librarySection)
    }
    
    func testLibraryItem() {
        let libraryItem = LibraryItem(id: 1, externalID: "1", librarySectionID: nil, librarySectionExternalID: nil, position: 1, titleHTML: "item", obsolete: false, itemID: 1, itemExternalID: "1")
        
        XCTAssertNoThrow(try catalog.addOrUpdateLibraryItem(libraryItem))
        XCTAssertEqual(catalog.libraryItemWithID(1), libraryItem)
    }
    
    func testStopword() {
        let stopword = Stopword(id: 1, languageID: 1, word: "the")
        
        XCTAssertNoThrow(try catalog.addStopword(stopword))
        XCTAssertEqual(catalog.stopwordsWithLanguageID(1), [stopword])
    }
    
    func testSubitems() {
        XCTAssertNoThrow(try catalog.addSubitemMetadata(id: 1, subitemID: 1, itemID: 2, docID: "3", docVersion: 4))
        
        let itemAndSubitemID = catalog.itemAndSubitemIDForDocID("3")!
        XCTAssertEqual(itemAndSubitemID.itemID, 2)
        XCTAssertEqual(itemAndSubitemID.subitemID, 1)
        XCTAssertEqual(catalog.subitemIDForSubitemWithDocID("3", itemID: 2), 1)
        XCTAssertEqual(catalog.docIDForSubitemWithID(1, itemID: 2), "3")
        XCTAssertEqual(catalog.versionsForDocIDs(["3"]), ["3": 4])
    }
    
    override func setUp() {
        super.setUp()
        
        do {
            catalog = try MutableCatalog()
        } catch {
            catalog = nil
        }
    }
    
}
