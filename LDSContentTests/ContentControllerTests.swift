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
    static let Timeout: TimeInterval = 120
    
    func testInstallingOldItemPackagesNotAllowed() {
        let installExpectation = expectation(description: "Install item")
        let alreadyCurrentExpectation = self.expectation(description: "Don't install old item")
        let contentController = ContentControllerTests.contentController!
        contentController.updateCatalog { result in
            if case let .success(catalog) = result {
                let currentItem = catalog.itemWithURI("/scriptures/bofm", languageID: catalog.languageWithISO639_3Code("eng")!.id)!
                contentController.installItemPackageForItem(currentItem) { result in
                    if case .success = result {
                        installExpectation.fulfill()
                        let oldItem = Item(id: currentItem.id, externalID: currentItem.externalID, languageID: currentItem.languageID, sourceID: currentItem.sourceID, platform: currentItem.platform, uri: currentItem.uri, title: currentItem.title, itemCoverRenditions: currentItem.itemCoverRenditions, itemCategoryID: currentItem.itemCategoryID, version: currentItem.version - 1, obsolete: currentItem.obsolete)
                        contentController.installItemPackageForItem(oldItem) { result in
                            if case let .alreadyInstalled(package) = result {
                                XCTAssertEqual(currentItem.version, package.itemPackageVersion)
                                alreadyCurrentExpectation.fulfill()
                            }
                        }
                    }
                }
            }
        }
        
        waitForExpectations(timeout: ContentControllerTests.Timeout, handler: nil)
    }
    
    func testOldCatalogsCleanedUpOnUpdate() {
        let cleanupExpectation = expectation(description: "Didn't clean up old catalogs")
        let contentController = ContentControllerTests.contentController!
        contentController.updateCatalog { result in
            if case .success = result {
                // Add stuff to the catalog directories to make sure they get cleaned up
                let extraDefaultURL = contentController.location.appendingPathComponent("Catalogs/default/somethingElse/someFile")
                let extraMergedURL = contentController.location.appendingPathComponent("MergedCatalogs/somethingElse/someFile")
                let extraURLs = [extraDefaultURL, extraMergedURL]
                let data = "hi".data(using: String.Encoding.utf8)!
                extraURLs.forEach { url in
                    let directory = url.deletingLastPathComponent()
                    try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                    try! data.write(to: url)
                    try! XCTAssertNotNil(Data(contentsOf: url))
                    XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
                }
                
                contentController.updateCatalog { result in
                    if case .success = result {
                        extraURLs.forEach { url in
                            let directory = url.deletingLastPathComponent()
                            do {
                                // This should fail because the file should be gone
                                try _ = Data(contentsOf: url)
                                XCTFail()
                            } catch {}
                            
                            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
                        }
                        
                        cleanupExpectation.fulfill()
                    }
                }
            }
        }
        
        waitForExpectations(timeout: ContentControllerTests.Timeout, handler: nil)
    }
    
    func testOldItemPackagesCleanedUpOnUpdate() {
        let cleanupExpectation = expectation(description: "Didn't clean up old item packages")
        let contentController = ContentControllerTests.contentController!
        contentController.updateCatalog { result in
            if case let .success(catalog) = result {
                let currentItem = catalog.itemWithURI("/scriptures/bofm", languageID: catalog.languageWithISO639_3Code("eng")!.id)!
                let oldItem = Item(id: currentItem.id, externalID: currentItem.externalID, languageID: currentItem.languageID, sourceID: currentItem.sourceID, platform: currentItem.platform, uri: currentItem.uri, title: currentItem.title, itemCoverRenditions: currentItem.itemCoverRenditions, itemCategoryID: currentItem.itemCategoryID, version: currentItem.version - 1, obsolete: currentItem.obsolete)
                contentController.installItemPackageForItem(oldItem) { result in
                    if case let .success(oldPackage) = result {
                        XCTAssertEqual(oldPackage.itemPackageVersion, oldItem.version)
                        let oldPackageURL = oldPackage.url
                        
                        contentController.installItemPackageForItem(currentItem) { result in
                            if case .success = result {
                                XCTAssertFalse(FileManager.default.fileExists(atPath: oldPackageURL.path))
                                cleanupExpectation.fulfill()
                            }
                        }
                    }
                }
            }
        }
        
        waitForExpectations(timeout: ContentControllerTests.Timeout, handler: nil)
    }
    
}

extension ContentControllerTests {
    override func setUp() {
        super.setUp()
        
        do {
            let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
            try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            ContentControllerTests.contentController = try ContentController(location: tempDirectoryURL, baseURL: URL(string: "https://edge.ldscdn.org/mobile/gospelstudy/beta/")!)
        } catch {
            NSLog("Failed to create content controller: %@", "\(error)")
        }
    }
    
    override func tearDown() {
        do {
            try FileManager.default.removeItem(at: ContentControllerTests.contentController.location)
        } catch {}
        
        super.tearDown()
    }
}
