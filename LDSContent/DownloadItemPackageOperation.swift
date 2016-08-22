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
import Operations

class DownloadItemPackageOperation: Operation {
    let session: Session
    let tempDirectoryURL: NSURL
    let externalID: String
    let version: Int
    let progress: (amount: Float) -> Void
    
    init(session: Session, externalID: String, version: Int, progress: (amount: Float) -> Void, completion: (DownloadItemPackageResult) -> Void) {
        self.session = session
        self.tempDirectoryURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent(NSProcessInfo.processInfo().globallyUniqueString)
        self.externalID = externalID
        self.version = version
        self.progress = progress
        
        super.init()
        
        addObserver(BlockObserver(didFinish: { operation, errors in
            if errors.isEmpty {
                completion(.Success(location: self.tempDirectoryURL))
            } else {
                completion(.Error(errors: errors))
            }
            
            do {
                try NSFileManager.defaultManager().removeItemAtURL(self.tempDirectoryURL)
            } catch {}
        }))
    }
    
    override func execute() {
        downloadItemPackage(externalID: externalID, version: version, progress: progress) { result in
            switch result {
            case let .Success(location):
                do {
                    try ItemExtractor.extractItemPackage(location: location, destination: self.tempDirectoryURL)
                    self.finish()
                } catch {
                    self.finish(error)
                }
            case let .Error(error):
                self.finish(error)
            }
        }
    }
    
    enum DownloadResult {
        case Success(location: NSURL)
        case Error(error: NSError)
    }
    
    func downloadItemPackage(externalID externalID: String, version: Int, progress: (amount: Float) -> Void, completion: (DownloadResult) -> Void) {
        let compressedItemPackageURL = session.baseURL.URLByAppendingPathComponent("v3/item-packages/\(externalID)/\(version).zip")
        let request = NSMutableURLRequest(URL: compressedItemPackageURL)
        let task = session.urlSession.downloadTaskWithRequest(request)
        session.registerCallbacks(progress: progress, completion: { result in
            self.session.deregisterCallbacksForTaskIdentifier(task.taskIdentifier)
            
            switch result {
            case let .Error(error: error):
                completion(.Error(error: error))
            case let .Success(location: location):
                completion(.Success(location: location))
            }
        }, forTaskIdentifier: task.taskIdentifier)
        task.resume()
    }
    
}
