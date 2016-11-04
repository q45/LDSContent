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
import ProcedureKit

class DownloadItemPackageOperation: Procedure {
    let session: Session
    let tempDirectoryURL: URL
    let baseURL: URL
    let externalID: String
    let version: Int
    let progress: (_ amount: Float) -> Void
    
    init(session: Session, baseURL: URL, externalID: String, version: Int, progress: @escaping (_ amount: Float) -> Void, completion: @escaping (DownloadItemPackageResult) -> Void) {
        self.session = session
        self.tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
        self.baseURL = baseURL
        self.externalID = externalID
        self.version = version
        self.progress = progress
        
        super.init()
        
        add(observer: BlockObserver(didFinish: { operation, errors in
            if errors.isEmpty {
                completion(.success(location: self.tempDirectoryURL))
            } else {
                completion(.error(errors: errors))
            }
            
            do {
                try FileManager.default.removeItem(at: self.tempDirectoryURL)
            } catch {}
        }))
    }
    
    override func execute() {
        downloadItemPackage(baseURL: baseURL, externalID: externalID, version: version, progress: progress) { result in
            switch result {
            case let .success(location):
                do {
                    try ItemExtractor.extractItemPackage(location: location, destination: self.tempDirectoryURL)
                    self.finish()
                } catch {
                    self.finish(withError: error)
                }
            case let .error(error):
                self.finish(withError: error)
            }
        }
    }
    
    enum DownloadResult {
        case success(location: URL)
        case error(error: Error)
    }
    
    func downloadItemPackage(baseURL: URL, externalID: String, version: Int, progress: @escaping (_ amount: Float) -> Void, completion: @escaping (DownloadResult) -> Void) {
        let compressedItemPackageURL = baseURL.appendingPathComponent("v3/item-packages/\(externalID)/\(version).zip")
        let request = URLRequest(url: compressedItemPackageURL)
        let task = session.urlSession.downloadTask(with: request)
        session.registerCallbacks(progress: progress, completion: { result in
            self.session.deregisterCallbacksForTaskIdentifier(task.taskIdentifier)
            self.session.networkActivityObservers.notify(.stop)
            
            switch result {
            case let .error(error: error):
                completion(.error(error: error))
            case let .success(location: location):
                completion(.success(location: location))
            }
        }, forTaskIdentifier: task.taskIdentifier)
        session.networkActivityObservers.notify(.start)
        task.resume()
    }
    
}
