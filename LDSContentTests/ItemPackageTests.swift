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
import LDSContent

class ItemPackageTests: XCTestCase {
    
    static var contentController: ContentController!
    var itemPackage: ItemPackage!
    var itemPackage2: ItemPackage!
    
    func testSchemaVersion() {
        XCTAssertEqual(itemPackage.schemaVersion, Catalog.SchemaVersion)
    }
    
    func testItemPackageVersion() {
        XCTAssertGreaterThan(itemPackage.itemPackageVersion, 0)
    }
    
    func testISO639_3Code() {
        XCTAssertEqual(itemPackage.iso639_3Code, "eng")
    }
    
    func testURI() {
        XCTAssertEqual(itemPackage.uri, "/scriptures/bofm")
    }
    
    func testItemID() {
        XCTAssertGreaterThan(itemPackage.itemID!, 0)
    }
    
    func testItemExternalID() {
        XCTAssertEqual(itemPackage.itemExternalID, "_scriptures_bofm_000")
    }
    
    func testSubitemContent() {
        let subitemID = Int64(1)
        let subitemContent = itemPackage.subitemContentWithSubitemID(subitemID)
        XCTAssertGreaterThan(subitemContent!.id, 0)
        XCTAssertEqual(subitemContent!.subitemID, subitemID)
        XCTAssertNotNil(subitemContent!.contentHTML)
    }
    
    func testSearchResults() {
        let searchResults = itemPackage.searchResultsForString("alma")
        XCTAssertGreaterThan(searchResults.count, 0)
        
        let searchResult = searchResults.first!
        let subitemContent = itemPackage.subitemContentWithSubitemID(searchResult.subitemID)!
        
        let string = String(data: subitemContent.contentHTML.subdataWithRange(searchResult.matchRanges.first!), encoding: NSUTF8StringEncoding)
        XCTAssertEqual(string, "Alma")
        
        let subitemID = searchResult.subitemID
        let subitemSearchResults = itemPackage.searchResultsForString("alma", subitemID: subitemID)
        XCTAssertEqual(subitemSearchResults, searchResults.filter { $0.subitemID == subitemID })
    }
    
    func testSubitem() {
        let uri = "/scriptures/bofm/1-ne/1"
        let subitem = itemPackage.subitemWithURI(uri)!
        XCTAssertGreaterThan(subitem.id, 0)
        XCTAssertEqual(subitem.uri, uri)
        
        let subitem2 = itemPackage.subitemWithDocID(subitem.docID)!
        XCTAssertEqual(subitem2, subitem)
        
        let subitem3 = itemPackage.subitemWithID(subitem.id)!
        XCTAssertEqual(subitem3, subitem)
        
        let subitem4 = itemPackage.subitemAtPosition(subitem.position)!
        XCTAssertEqual(subitem4, subitem)
        
        let subitems = itemPackage.subitems()
        XCTAssertGreaterThan(subitems.count, 10)
        
        let subitems2 = itemPackage.subitemsWithURIs(["/scriptures/bofm/alma/5", "/scriptures/bofm/enos/1"])
        XCTAssertEqual(subitems2.count, 2)
    }
    
    func testRelatedContentItem() {
        let uri = "/scriptures/bofm/1-ne/1"
        let subitem = itemPackage.subitemWithURI(uri)!
        let relatedContentItems = itemPackage.relatedContentItemsForSubitemWithID(subitem.id)
        XCTAssertGreaterThan(relatedContentItems.count, 0)
    }
    
    func testRelatedAudioItem() {
        let uri = "/scriptures/bofm/1-ne/1"
        let subitem = itemPackage.subitemWithURI(uri)!
        
        let relatedAudioItems = itemPackage.relatedAudioItemsForSubitemWithID(subitem.id)
        XCTAssertGreaterThan(relatedAudioItems.count, 0)
    }
    
    func testNavCollection() {
        let navCollection = itemPackage.rootNavCollection()!
        XCTAssertNil(navCollection.navSectionID)
        
        let navCollection2 = itemPackage.navCollectionWithID(navCollection.id)
        XCTAssertEqual(navCollection2, navCollection)
        
        let navCollection3 = itemPackage.navCollectionWithURI(navCollection.uri)
        XCTAssertEqual(navCollection3, navCollection)
        
        let oneNephiNavCollection = itemPackage.navCollectionWithURI("/scriptures/bofm#map3")! // 1 Nephi
        let oneNephiNavSection = itemPackage.navSectionWithID(oneNephiNavCollection.navSectionID!)!
        let navCollections = itemPackage.navCollectionsForNavSectionWithID(oneNephiNavSection.id)
        XCTAssertGreaterThan(navCollections.count, 0)
    }
    
    func testNavCollectionIndexEntry() {
        let navCollectionIndexEntry = itemPackage2.navCollectionIndexEntryWithID(1)!
        XCTAssertGreaterThan(navCollectionIndexEntry.navCollectionID, 0)
        
        let navCollection = itemPackage2.rootNavCollection()!
        let navCollectionIndexEntries = itemPackage2.navCollectionIndexEntriesForNavCollectionWithID(navCollection.id)
        XCTAssertGreaterThan(navCollectionIndexEntries.count, 0)
    }
    
    func testNavSection() {
        let navSection = itemPackage.navSectionWithID(1)!
        XCTAssertGreaterThan(navSection.navCollectionID, 0)
        
        let navSections = itemPackage.navSectionsForNavCollectionWithID(1)
        XCTAssertGreaterThan(navSections.count, 0)
    }
    
    func testNavItem() {
        let navItems = itemPackage.navItemsForNavSectionWithID(1)
        XCTAssertGreaterThan(navItems.count, 0)
        
        let navItem = navItems.first!
        
        let navItem2 = itemPackage.navItemWithURI(navItem.uri)
        XCTAssertEqual(navItem2, navItem)
    }
    
    func testNavNodes() {
        let navCollection = itemPackage.rootNavCollection()!
        let navSections = itemPackage.navSectionsForNavCollectionWithID(navCollection.id)
        let navSection = navSections.first!
        
        let navNodes = itemPackage.navNodesForNavSectionWithID(navSection.id)
        XCTAssertGreaterThan(navNodes.count, 0)
    }
    
    func testParagraphMetadata() {
        let uri = "/scriptures/bofm/1-ne/1"
        let subitem = itemPackage.subitemWithURI(uri)!
        
        let paragraphIDs = ["p1", "p2", "p7"]
        
        let paragraphMetadata = itemPackage.paragraphMetadataForParagraphIDs(paragraphIDs, subitemID: subitem.id)
        XCTAssertEqual(paragraphMetadata.count, paragraphIDs.count)
        
        
        let paragraphMetadata2 = itemPackage.paragraphMetadataForParagraphAIDs(paragraphMetadata.map { $0.paragraphAID }, subitemID: subitem.id)
        XCTAssertEqual(paragraphMetadata2, paragraphMetadata)
        
        let paragraphMetadata3 = itemPackage.paragraphMetadataForParagraphAIDs(paragraphMetadata.map { $0.paragraphAID }, docID: subitem.docID)
        XCTAssertEqual(paragraphMetadata3, paragraphMetadata)
    }
    
    func testSubitemURIsFromSubitemIDs() {
        let subitems = itemPackage.subitems()
        let subitemIDs = subitems.map { $0.id }
        
        let actualSubitemURIs = Set(itemPackage.URIsOfSubitemsWithIDs(subitemIDs))
        XCTAssertTrue(actualSubitemURIs == Set(subitems.map({ $0.uri })))
    }
    
    func testOrderedSubitemURIsWithURIs() {
        let orderedURIs = itemPackage.subitems().map { $0.uri }
        let unorderedURIs = orderedURIs.shuffle()
        
        XCTAssertFalse(orderedURIs == unorderedURIs)
        
        XCTAssertTrue(orderedURIs == itemPackage.orderedSubitemURIsWithURIs(unorderedURIs))
    }
    
}

extension ItemPackageTests {
    
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
        
        if let catalog = loadCatalog() {
            itemPackage = loadItemPackageForItemWithURI("/scriptures/bofm", iso639_3Code: "eng", inCatalog: catalog)
            itemPackage2 = loadItemPackageForItemWithURI("/scriptures/dc-testament", iso639_3Code: "eng", inCatalog: catalog)
        }
    }
    
    private func loadCatalog() -> Catalog? {
        var catalog = ItemPackageTests.contentController.catalog
        if catalog == nil {
            let semaphore = dispatch_semaphore_create(0)
            ItemPackageTests.contentController.updateCatalog(progress: { _ in }, completion: { result in
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
            if dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, Int64(60 * NSEC_PER_SEC))) != 0 {
                NSLog("Timed out updating catalog")
            }
        }
        return catalog
    }
    
    private func loadItemPackageForItemWithURI(uri: String, iso639_3Code: String, inCatalog catalog: Catalog) -> ItemPackage? {
        guard let language = catalog.languageWithISO639_3Code(iso639_3Code), item = catalog.itemWithURI(uri, languageID: language.id) else { return nil }
        
        var itemPackage = ItemPackageTests.contentController.itemPackageForItemWithID(item.id)
        if itemPackage == nil {
            let semaphore = dispatch_semaphore_create(0)
            ItemPackageTests.contentController.installItemPackageForItem(item, progress: { _ in }, completion: { result in
                switch result {
                case let .Success(newItemPackage):
                    itemPackage = newItemPackage
                case let .AlreadyInstalled(newItemPackage):
                    itemPackage = newItemPackage
                case let .Error(errors):
                    NSLog("Failed with errors %@", "\(errors)")
                }
                
                dispatch_semaphore_signal(semaphore)
            })
            if dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, Int64(60 * NSEC_PER_SEC))) != 0 {
                NSLog("Timed out installing item package")
            }
        }
        return itemPackage
    }
    
}
