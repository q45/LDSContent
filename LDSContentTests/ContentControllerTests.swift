//
//  ContentControllerTests.swift
//  LDSContent
//
//  Created by Nick Shelley on 8/4/16.
//  Copyright © 2016 Hilton Campbell. All rights reserved.
//

import Foundation

import XCTest
@testable import LDSContent

class ContentControllerTests: XCTestCase {
    
    static var contentController: ContentController!
    static let Timeout: NSTimeInterval = 120
    
    func testInstallingOldItemPackagesNotAllowed() {
        let installExpectation = expectationWithDescription("Install item")
        let alreadyCurrentExpectation = self.expectationWithDescription("Don't install old item")
        let contentController = ContentControllerTests.contentController
        contentController.updateCatalog { result in
            if case let .Success(catalog) = result {
                let currentItem = catalog.itemWithURI("/scriptures/bofm", languageID: catalog.languageWithISO639_3Code("eng")!.id)!
                contentController.installItemPackageForItem(currentItem) { result in
                    if case .Success = result {
                        installExpectation.fulfill()
                        let oldItem = Item(id: currentItem.id, externalID: currentItem.externalID, languageID: currentItem.languageID, sourceID: currentItem.sourceID, platform: currentItem.platform, uri: currentItem.uri, title: currentItem.title, itemCoverRenditions: currentItem.itemCoverRenditions, itemCategoryID: currentItem.itemCategoryID, version: currentItem.version - 1, obsolete: currentItem.obsolete)
                        contentController.installItemPackageForItem(oldItem) { result in
                            if case let .AlreadyInstalled(package) = result {
                                XCTAssertEqual(currentItem.version, package.itemPackageVersion)
                                alreadyCurrentExpectation.fulfill()
                            }
                        }
                    }
                }
            }
        }
        
        waitForExpectationsWithTimeout(ContentControllerTests.Timeout, handler: nil)
    }
    
    func testOldCatalogsCleanedUpOnUpdate() {
        let cleanupExpectation = expectationWithDescription("Didn't clean up old catalogs")
        let contentController = ContentControllerTests.contentController
        contentController.updateCatalog { result in
            if case .Success = result {
                // Add stuff to the catalog directories to make sure they get cleaned up
                let extraDefaultURL = contentController.location.URLByAppendingPathComponent("Catalogs/default/somethingElse/someFile")
                let extraMergedURL = contentController.location.URLByAppendingPathComponent("MergedCatalogs/somethingElse/someFile")
                let extraURLs = [extraDefaultURL, extraMergedURL]
                let data = "hi".dataUsingEncoding(NSUTF8StringEncoding)!
                extraURLs.forEach { url in
                    let directory = url.URLByDeletingLastPathComponent!
                    try! NSFileManager.defaultManager().createDirectoryAtURL(directory, withIntermediateDirectories: true, attributes: nil)
                    try! data.writeToURL(url, options: [])
                    XCTAssertNotNil(NSData(contentsOfURL: url))
                    XCTAssertTrue(NSFileManager.defaultManager().fileExistsAtPath(directory.path!))
                }
                
                contentController.updateCatalog { result in
                    if case .Success = result {
                        extraURLs.forEach { url in
                            let directory = url.URLByDeletingLastPathComponent!
                            XCTAssertNil(NSData(contentsOfURL: url))
                            XCTAssertFalse(NSFileManager.defaultManager().fileExistsAtPath(directory.path!))
                        }
                        
                        cleanupExpectation.fulfill()
                    }
                }
            }
        }
        
        waitForExpectationsWithTimeout(ContentControllerTests.Timeout, handler: nil)
    }
    
    func testOldItemPackagesCleanedUpOnUpdate() {
        let cleanupExpectation = expectationWithDescription("Didn't clean up old item packages")
        let contentController = ContentControllerTests.contentController
        contentController.updateCatalog { result in
            if case let .Success(catalog) = result {
                let currentItem = catalog.itemWithURI("/scriptures/bofm", languageID: catalog.languageWithISO639_3Code("eng")!.id)!
                let oldItem = Item(id: currentItem.id, externalID: currentItem.externalID, languageID: currentItem.languageID, sourceID: currentItem.sourceID, platform: currentItem.platform, uri: currentItem.uri, title: currentItem.title, itemCoverRenditions: currentItem.itemCoverRenditions, itemCategoryID: currentItem.itemCategoryID, version: currentItem.version - 1, obsolete: currentItem.obsolete)
                contentController.installItemPackageForItem(oldItem) { result in
                    if case let .Success(oldPackage) = result {
                        XCTAssertEqual(oldPackage.itemPackageVersion, oldItem.version)
                        let oldPackageURL = oldPackage.url
                        
                        contentController.installItemPackageForItem(currentItem) { result in
                            if case .Success = result {
                                XCTAssertFalse(NSFileManager.defaultManager().fileExistsAtPath(oldPackageURL.path!))
                                cleanupExpectation.fulfill()
                            }
                        }
                    }
                }
            }
        }
        
        waitForExpectationsWithTimeout(ContentControllerTests.Timeout, handler: nil)
    }
    
}

extension ContentControllerTests {
    override func setUp() {
        super.setUp()
        
        do {
            let tempDirectoryURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent(NSProcessInfo.processInfo().globallyUniqueString)
            try NSFileManager.defaultManager().createDirectoryAtURL(tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            ContentControllerTests.contentController = try ContentController(location: tempDirectoryURL)
        } catch {
            NSLog("Failed to create content controller: %@", "\(error)")
        }
    }
    
    override func tearDown() {
        do {
            try NSFileManager.defaultManager().removeItemAtURL(ContentControllerTests.contentController.location)
        } catch {}
        
        super.tearDown()
    }
}
