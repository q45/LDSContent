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

class CatalogTests: XCTestCase {
    
    static var contentController: ContentController!
    var catalog: Catalog!
    
    func testSchemaVersion() {
        XCTAssertEqual(catalog.schemaVersion, Catalog.SchemaVersion)
    }
    
    func testCatalogVersion() {
        XCTAssertGreaterThan(catalog.catalogVersion, 0)
    }
    
    func testSource() {
        let defaultSource = Source(id: 1, name: "default", type: .Default)
        
        XCTAssertEqual(catalog.sources(), [defaultSource])
        XCTAssertEqual(catalog.sourceWithID(1), defaultSource)
        XCTAssertEqual(catalog.sourceWithName("default"), defaultSource)
        
        let items = catalog.itemsWithSourceID(defaultSource.id)
        XCTAssertGreaterThan(items.count, 1)
    }
    
    func testItemCategory() {
        let scripturesItemCategory = ItemCategory(id: 1, name: "Scriptures")
        
        XCTAssertEqual(catalog.itemCategoryWithID(1), scripturesItemCategory)
    }
    
    func testItems() {
        let items = catalog.items()
        XCTAssertGreaterThan(items.count, 1000)
        
        let expectedItems = Array(items[0..<20])
        
        let items2 = catalog.itemsWithIDsIn(expectedItems.map { $0.id })
        XCTAssertEqual(items2, expectedItems)
        
        let items3 = catalog.itemsWithURIsIn(["/scriptures/bofm", "/scriptures/dc-testament"], languageID: 1)
        XCTAssertEqual(items3.count, 2)
        
        let expectedItem = items.first!
        
        let item = catalog.itemWithID(expectedItem.id)
        XCTAssertEqual(item, expectedItem)
        
        let item2 = catalog.itemWithURI(expectedItem.uri, languageID: expectedItem.languageID)
        XCTAssertEqual(item2, expectedItem)
        
        let item3 = catalog.itemThatContainsURI("/scriptures/bofm/1-ne/1", languageID: 1)
        XCTAssertEqual(item3!.uri, "/scriptures/bofm")
    }
    
    @available(*, deprecated=1.0.0)
    func testDeprecatedItems() {
        let items = catalog.items()
        XCTAssertGreaterThan(items.count, 1000)
        
        let expectedItems = Array(items[0..<20])
        
        let items3 = catalog.itemsWithExternalIDsIn(expectedItems.map { $0.externalID })
        XCTAssertEqual(items3, expectedItems)
        
        let expectedItem = items.first!
        
        let item2 = catalog.itemWithExternalID(expectedItem.externalID)
        XCTAssertEqual(item2, expectedItem)
    }
    
    func testLanguages() {
        let languages = catalog.languages()
        XCTAssertGreaterThan(languages.count, 20)
        
        let language = languages.first!
        
        XCTAssertEqual(catalog.languageWithID(language.id)!, language)
        XCTAssertEqual(catalog.languageWithISO639_3Code(language.iso639_3Code)!, language)
        XCTAssertEqual(catalog.languageWithBCP47Code(language.bcp47Code!)!, language)
        XCTAssertEqual(catalog.languageWithLDSLanguageCode(language.ldsLanguageCode)!, language)
        XCTAssertEqual(catalog.languageWithRootLibraryCollectionID(language.rootLibraryCollectionID)!, language)
    }
    
    @available(*, deprecated=1.0.0)
    func testDeprecatedLanguages() {
        let languages = catalog.languages()
        XCTAssertGreaterThan(languages.count, 20)
        
        let language = languages.first!
        
        XCTAssertEqual(catalog.languageWithRootLibraryCollectionExternalID(language.rootLibraryCollectionExternalID)!, language)
    }
    
    func testItemTitles() {
        let items = catalog.itemsWithTitlesThatContainString("Mormon", languageID: 1, limit: 10)
        XCTAssertTrue(items.contains { $0.title == "Book of Mormon" })
        
        let items2 = catalog.itemsWithTitlesThatContainString("mormon", languageID: 1, limit: 10)
        XCTAssertTrue(items2.contains { $0.title == "Book of Mormon" })
        
        let items3 = catalog.itemsWithTitlesThatContainString("Mormón", languageID: 1, limit: 10)
        XCTAssertTrue(items3.contains { $0.title == "Book of Mormon" })
        
        let items4 = catalog.itemsWithTitlesThatContainString("Mormon", languageID: 3, limit: 10)
        XCTAssertTrue(items4.contains { $0.title == "Libro de Mormón" })
        
        let items5 = catalog.itemsWithTitlesThatContainString("Mormo_", languageID: 1, limit: 10)
        XCTAssertEqual(items5.count, 0)
        
        let items6 = catalog.itemsWithTitlesThatContainString("Mormo%", languageID: 1, limit: 10)
        XCTAssertEqual(items6.count, 0)
        
        let items7 = catalog.itemsWithTitlesThatContainString("!Mormon", languageID: 1, limit: 10)
        XCTAssertEqual(items7.count, 0)
    }
    
    func testLanguageNames() {
        XCTAssertEqual(catalog.nameForLanguageWithID(1, inLanguageWithID: 1), "English")
        XCTAssertEqual(catalog.nameForLanguageWithID(3, inLanguageWithID: 1), "Spanish")
        XCTAssertEqual(catalog.nameForLanguageWithID(1, inLanguageWithID: 3), "Inglés")
        XCTAssertEqual(catalog.nameForLanguageWithID(3, inLanguageWithID: 3), "Español")
    }
    
    func testLibraryCollections() {
        let libraryCollections = catalog.libraryCollections()
        XCTAssertGreaterThan(libraryCollections.count, 0)
        
        let scripturesLibraryCollection = libraryCollections.find { $0.type == .Scriptures }!
        
        let items = catalog.itemsForLibraryCollectionWithID(scripturesLibraryCollection.id)
        XCTAssertGreaterThan(items.count, 0)
        
        let rootLibraryCollection = libraryCollections.first!
        
        let libraryCollections2 = catalog.libraryCollectionsForLibraryCollectionWithID(rootLibraryCollection.id)
        XCTAssertGreaterThan(libraryCollections2.count, 0)
        
        let libraryCollection = catalog.libraryCollectionWithID(scripturesLibraryCollection.id)!
        XCTAssertEqual(libraryCollection, scripturesLibraryCollection)
        
        let librarySection = catalog.librarySectionsForLibraryCollectionWithID(rootLibraryCollection.id).first!
        
        let libraryCollections3 = catalog.libraryCollectionsForLibrarySectionWithID(librarySection.id)
        XCTAssertGreaterThan(libraryCollections3.count, 0)
    }
    
    @available(*, deprecated=1.0.0)
    func testDeprecatedLibraryCollections() {
        let libraryCollections = catalog.libraryCollections()
        XCTAssertGreaterThan(libraryCollections.count, 0)
        
        let scripturesLibraryCollection = libraryCollections.find { $0.type == .Scriptures }!
        
        let libraryCollection = catalog.libraryCollectionWithExternalID(scripturesLibraryCollection.externalID)!
        XCTAssertEqual(libraryCollection, scripturesLibraryCollection)
        
        let rootLibraryCollection = libraryCollections.first!
        let librarySection = catalog.librarySectionsForLibraryCollectionWithID(rootLibraryCollection.id).first!
        
        let libraryCollections3 = catalog.libraryCollectionsForLibrarySectionWithExternalID(librarySection.externalID)
        XCTAssertGreaterThan(libraryCollections3.count, 0)
    }
    
    func testLibrarySections() {
        let scripturesLibraryCollection = catalog.libraryCollections().find { $0.type == .Scriptures }!
        
        let librarySections = catalog.librarySectionsForLibraryCollectionWithID(scripturesLibraryCollection.id)
        XCTAssertGreaterThan(librarySections.count, 0)
        
        let librarySection = librarySections.first!
        
        let librarySection2 = catalog.librarySectionWithID(librarySection.id)
        XCTAssertEqual(librarySection2, librarySection)
    }
    
    @available(*, deprecated=1.0.0)
    func testDeprecatedLibrarySections() {
        let scripturesLibraryCollection = catalog.libraryCollections().find { $0.type == .Scriptures }!
        
        let librarySections = catalog.librarySectionsForLibraryCollectionWithExternalID(scripturesLibraryCollection.externalID)
        XCTAssertGreaterThan(librarySections.count, 0)
        
        let librarySection = librarySections.first!
        
        let librarySection2 = catalog.librarySectionWithExternalID(librarySection.externalID)
        XCTAssertEqual(librarySection2, librarySection)
    }
    
    func testLibraryItems() {
        let scripturesLibraryCollection = catalog.libraryCollections().find { $0.type == .Scriptures }!
        let scripturesLibrarySection = catalog.librarySectionsForLibraryCollectionWithID(scripturesLibraryCollection.id).first!
        
        let libraryItems = catalog.libraryItemsForLibrarySectionWithID(scripturesLibrarySection.id)
        XCTAssertGreaterThan(libraryItems.count, 0)
        
        let libraryItems2 = catalog.libraryItemsForLibraryCollectionWithID(scripturesLibraryCollection.id)
        XCTAssertGreaterThan(libraryItems2.count, 0)
        
        let libraryItem = libraryItems.first!
        
        let libraryItems3 = catalog.libraryItemsWithItemID(libraryItem.itemID)
        XCTAssertTrue(libraryItems3.contains(libraryItem))
        
        let libraryItem2 = catalog.libraryItemWithItemID(libraryItem.itemID, inLibraryCollectionWithID: scripturesLibraryCollection.id)
        XCTAssertEqual(libraryItem2, libraryItem)
        
        let libraryItem3 = catalog.libraryItemWithID(libraryItem.id)
        XCTAssertEqual(libraryItem3, libraryItem)
    }
    
    @available(*, deprecated=1.0.0)
    func testDeprecatedLibraryItems() {
        let scripturesLibraryCollection = catalog.libraryCollections().find { $0.type == .Scriptures }!
        let scripturesLibrarySection = catalog.librarySectionsForLibraryCollectionWithID(scripturesLibraryCollection.id).first!
        
        let libraryItems = catalog.libraryItemsForLibrarySectionWithID(scripturesLibrarySection.id)
        
        let libraryItems2 = catalog.libraryItemsForLibrarySectionWithExternalID(scripturesLibrarySection.externalID)
        XCTAssertEqual(libraryItems2, libraryItems)
        
        let libraryItems3 = catalog.libraryItemsForLibraryCollectionWithExternalID(scripturesLibraryCollection.externalID)
        XCTAssertGreaterThan(libraryItems3.count, 0)
        
        let libraryItem = libraryItems.first!
        
        let libraryItems4 = catalog.libraryItemsWithItemExternalID(libraryItem.itemExternalID)
        XCTAssertTrue(libraryItems4.contains(libraryItem))
        
        let libraryItem2 = catalog.libraryItemWithItemExternalID(libraryItem.itemExternalID, inLibraryCollectionWithExternalID: scripturesLibraryCollection.externalID)
        XCTAssertEqual(libraryItem2, libraryItem)
        
        let libraryItem3 = catalog.libraryItemWithExternalID(libraryItem.externalID)
        XCTAssertEqual(libraryItem3, libraryItem)
    }
    
    func testLibraryNodes() {
        let scripturesLibraryCollection = catalog.libraryCollections().find { $0.type == .Scriptures }!
        let scripturesLibrarySection = catalog.librarySectionsForLibraryCollectionWithID(scripturesLibraryCollection.id).first!
        
        let libraryNodes = catalog.libraryNodesForLibrarySectionWithID(scripturesLibrarySection.id)
        XCTAssertGreaterThan(libraryNodes.count, 0)
    }
    
    @available(*, deprecated=1.0.0)
    func testDeprecatedLibraryNodes() {
        let scripturesLibraryCollection = catalog.libraryCollections().find { $0.type == .Scriptures }!
        let scripturesLibrarySection = catalog.librarySectionsForLibraryCollectionWithID(scripturesLibraryCollection.id).first!
        
        let libraryNodes2 = catalog.libraryNodesForLibrarySectionWithExternalID(scripturesLibrarySection.externalID)
        XCTAssertGreaterThan(libraryNodes2.count, 0)
    }
    
    func testStopwords() {
        let stopwords = catalog.stopwordsWithLanguageID(1)
        XCTAssertTrue(Set(stopwords.map { $0.word }).isStrictSupersetOf(["and", "of", "the"]))
    }
    
}

extension CatalogTests {
    
    override class func setUp() {
        super.setUp()
        
        do {
            let tempDirectoryURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent(NSProcessInfo.processInfo().globallyUniqueString)
            try NSFileManager.defaultManager().createDirectoryAtURL(tempDirectoryURL!, withIntermediateDirectories: true, attributes: nil)
            contentController = try ContentController(location: tempDirectoryURL!, baseURL: NSURL(string: "https://edge.ldscdn.org/mobile/gospelstudy/beta/")!)
        } catch {
            NSLog("Failed to create content controller: %@", "\(error)")
        }
    }
    
    override class func tearDown() {
        do {
            try NSFileManager.defaultManager().removeItemAtURL(contentController.location)
        } catch {}
        
        super.tearDown()
    }
    
    override func setUp() {
        super.setUp()
        
        self.catalog = loadCatalog()
    }
    
    private func loadCatalog() -> Catalog? {
        var catalog = CatalogTests.contentController.catalog
        if catalog == nil {
            let semaphore = dispatch_semaphore_create(0)
            CatalogTests.contentController.updateCatalog(progress: { _ in }, completion: { result in
                switch result {
                case let .Success(newCatalog):
                    catalog = newCatalog
                case let .PartialSuccess(newCatalog, _):
                    catalog = newCatalog
                case let .Error(errors):
                    NSLog("Failed with errors %@", "\(errors)")
                }
                
                dispatch_semaphore_signal(semaphore)
            })
            if dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, Int64(30 * NSEC_PER_SEC))) != 0 {
                NSLog("Timed out updating catalog")
            }
        }
        return catalog
    }

}
