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

class DownloadCatalogTests: XCTestCase {
    
    func testDownloadLatestCatalog() {
        let session = Session(baseURL: NSURL(string: "https://edge.ldscdn.org/mobile/gospelstudy/beta/")!)
        let catalogURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent(NSProcessInfo.processInfo().globallyUniqueString)
        let downloadExpectation = expectationWithDescription("Download latest catalog")
        let alreadyCurrentExpectation = self.expectationWithDescription("Already downloaded catalog")
        session.updateDefaultCatalog(destination: { _ in catalogURL }) { result in
            switch result {
            case .Success:
                do {
                    let catalog = try Catalog(path: catalogURL.path!)
                    XCTAssertGreaterThan(catalog.catalogVersion, 0)
                } catch {
                    XCTFail("Failed to connect to catalog: \(error)")
                }
            case .AlreadyCurrent:
                XCTFail("Shouldn't be already current.")
            case let .Error(errors):
                XCTFail("Failed with errors \(errors)")
            }
            downloadExpectation.fulfill()
            
            session.updateDefaultCatalog(destination: { _ in catalogURL }) { result in
                switch result {
                case .Success:
                    XCTFail("Should be already current.")
                case .AlreadyCurrent:
                    do {
                        let catalog = try Catalog(path: catalogURL.path!)
                        XCTAssertGreaterThan(catalog.catalogVersion, 0)
                    } catch {
                        XCTFail("Failed to connect to catalog: \(error)")
                    }
                case let .Error(errors):
                    XCTFail("Failed with errors \(errors)")
                }
                alreadyCurrentExpectation.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(30, handler: nil)
    }
    
}
