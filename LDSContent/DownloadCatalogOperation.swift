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
import SSZipArchive

enum DownloadCatalogOperationError: Error {
    case missingCatalogVersionError(String)
}

class DownloadCatalogOperation: Procedure, ResultInjection {
    
    var requirement: PendingValue<Int> = .pending // Catalog version injected from FetchCatalogVersionOperation
    var result: PendingValue<DownloadCatalogResult> = .pending
    
    var isCurrent = false
    
    let catalogName: String
    let session: Session
    let baseURL: URL
    let destination: (_ version: Int) -> URL
    let progress: (_ amount: Float) -> Void
    let tempDirectoryURL: URL
    
    init(session: Session, catalogName: String, baseURL: URL, destination: @escaping (_ version: Int) -> URL, progress: @escaping (_ amount: Float) -> Void, completion: @escaping (DownloadCatalogResult) -> Void) {
        self.session = session
        self.catalogName = catalogName
        self.baseURL = baseURL
        self.destination = destination
        self.progress = progress
        self.tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
        
        super.init()
        
        add(observer: BlockObserver(didFinish: { operation, errors in
            if errors.isEmpty, let version = self.requirement.value {
                if self.isCurrent {
                    let result = DownloadCatalogResult.alreadyCurrent
                    self.result = .ready(result)
                    completion(result)
                } else {
                    let destinationURL = self.destination(version)
                    do {
                        let directory = destinationURL.deletingLastPathComponent()
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                        try FileManager.default.moveItem(at: self.tempDirectoryURL.appendingPathComponent("Catalog.sqlite"), to: destinationURL)
                    } catch {}
                    let result = DownloadCatalogResult.success(version: version)
                    self.result = .ready(result)
                    completion(result)
                }
            } else {
                let result = DownloadCatalogResult.error(errors: errors)
                self.result = .ready(result)
                completion(result)
            }
        }))
    }
    
    override func execute() {
        guard let catalogVersion = requirement.value else {
            finish(withError: DownloadCatalogOperationError.missingCatalogVersionError("Catalog version was not injected properly and is nil."))
            return
        }
        
        let destinationURL = destination(catalogVersion)
        if (try? Catalog(path: destinationURL.path)) != nil {
            isCurrent = true
            finish()
            return
        } else if FileManager.default.fileExists(atPath: destinationURL.path) {
            do {
                try FileManager.default.removeItem(at: destinationURL)
            } catch {
                finish(withError: error)
                return
            }
        }
        
        downloadCatalog(baseURL: baseURL, catalogVersion: catalogVersion, progress: progress) { result in
            switch result {
            case let .success(location):
                self.extractCatalog(location: location) { result in
                    switch result {
                    case .success:
                        self.finish()
                    case let .error(error):
                        self.finish(withError: error)
                    }
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
    
    func downloadCatalog(baseURL: URL, catalogVersion: Int, progress: @escaping (_ amount: Float) -> Void, completion: @escaping (DownloadResult) -> Void) {
        let compressedCatalogURL = baseURL.appendingPathComponent("v3/catalogs/\(catalogVersion).zip")
        let request = URLRequest(url: compressedCatalogURL)
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
    
    enum ExtractCatalogResult {
        case success
        case error(error: Error)
    }
    
    func extractCatalog(location: URL, completion: (ExtractCatalogResult) -> Void) {
        let sourcePath = location.path
        do {
            try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            completion(.error(error: error))
            return
        }
        
        let destinationPath = tempDirectoryURL.path
        guard SSZipArchive.unzipFile(atPath: sourcePath, toDestination: destinationPath) else {
            completion(.error(error: ContentError.errorWithCode(.unknown, failureReason: "Failed to decompress catalog")))
            return
        }
        
        let uncompressedCatalogURL = tempDirectoryURL.appendingPathComponent("Catalog.sqlite")
        
        do {
            if try !uncompressedCatalogURL.checkResourceIsReachable() {
                completion(.error(error: ContentError.errorWithCode(.unknown, failureReason: "Uncompressed catalog is not reachable")))
                return
            }
        } catch {
            completion(.error(error: error))
            return
        }
        
        completion(.success)
    }
    
}
