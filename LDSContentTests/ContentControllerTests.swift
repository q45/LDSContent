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
        
        waitForExpectationsWithTimeout(30, handler: nil)
    }
    
}

extension ContentControllerTests {
    override class func setUp() {
        super.setUp()
        
        do {
            let tempDirectoryURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent(NSProcessInfo.processInfo().globallyUniqueString)
            try NSFileManager.defaultManager().createDirectoryAtURL(tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            contentController = try ContentController(location: tempDirectoryURL)
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
}
