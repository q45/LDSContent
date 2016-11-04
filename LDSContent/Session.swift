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
import Swiftification

class Session: NSObject {
    
    let networkActivityObservers = ObserverSet<ContentController.NetworkActivity>()
    
    enum DownloadResult {
        case success(location: URL)
        case error(error: Error)
    }
    
    lazy var urlSession: Foundation.URLSession = {
        return Foundation.URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    }()
    
    let procedureQueue: ProcedureQueue = {
        let queue = ProcedureQueue()
        queue.maxConcurrentOperationCount = 5
        return queue
    }()
    
    let baseURL: URL
    
    fileprivate var progressByTaskIdentifier: [Int: (_ amount: Float) -> Void] = [:]
    fileprivate var completionByTaskIdentifier: [Int: (_ result: DownloadResult) -> Void] = [:]
    
    init(baseURL: URL) {
        self.baseURL = baseURL
        super.init()
    }
    
    fileprivate func catalogOperationsForCatalogs(_ catalogs: [(name: String, baseURL: URL, destination: (_ version: Int) -> URL)], progress: @escaping (_ amount: Float) -> Void = { _ in }, completion: @escaping (DownloadCatalogResult) -> Void) -> [Operation] {
        return catalogs.flatMap { (name, baseURL, destination) -> [Operation] in
            let versionOperation = FetchCatalogVersionOperation(session: self, baseURL: baseURL)
            let downloadOperation = DownloadCatalogOperation(session: self, catalogName: name, baseURL: baseURL, destination: destination, progress: progress, completion: completion)
            downloadOperation.injectResult(from: versionOperation)
            return [versionOperation, downloadOperation]
        }
    }
    
    func updateDefaultCatalog(destination: @escaping (_ version: Int) -> URL, progress: @escaping (_ amount: Float) -> Void = { _ in }, completion: @escaping (DownloadCatalogResult) -> Void) {
        let operations = catalogOperationsForCatalogs([(ContentController.defaultCatalogName, baseURL, destination)], progress: progress, completion: completion)
        procedureQueue.add(operations: operations)
    }
    
    func updateSecureCatalogs(_ secureCatalogs: [(name: String, baseURL: URL, destination: (_ version: Int) -> URL)], progress: @escaping (_ amount: Float) -> Void = { _ in }, completion: @escaping ([(name: String, baseURL: URL, result: DownloadCatalogResult)]) -> Void) {
        let operations = catalogOperationsForCatalogs(secureCatalogs, progress: progress, completion: { _ in })
        let group = GroupProcedure(operations: operations)
        group.add(observer: DidFinishObserver { operation, errors in
            let results: [(name: String, baseURL: URL, result: DownloadCatalogResult)] = operations.flatMap {
                guard let downloadOperation = $0 as? DownloadCatalogOperation, let result = downloadOperation.result.value else { return nil }
                
                return (downloadOperation.catalogName, downloadOperation.baseURL, result)
            }
            
            completion(results)
        })
        procedureQueue.addOperation(group)
    }
    
    func downloadItemPackage(baseURL: URL, externalID: String, version: Int, priority: InstallPriority = .normal, progress: @escaping (_ amount: Float) -> Void, completion: @escaping (DownloadItemPackageResult) -> Void) {
        let operation = DownloadItemPackageOperation(session: self, baseURL: baseURL, externalID: externalID, version: version, progress: progress, completion: completion)
        if case priority = InstallPriority.high {
            operation.queuePriority = .veryHigh
        }
        procedureQueue.addOperation(operation)
    }
    
    func registerCallbacks(progress: @escaping (_ amount: Float) -> Void, completion: @escaping (_ result: DownloadResult) -> Void, forTaskIdentifier taskIdentifier: Int) {
        progressByTaskIdentifier[taskIdentifier] = progress
        completionByTaskIdentifier[taskIdentifier] = completion
    }
    
    func deregisterCallbacksForTaskIdentifier(_ taskIdentifier: Int) {
        progressByTaskIdentifier[taskIdentifier] = nil
        completionByTaskIdentifier[taskIdentifier] = nil
    }

    func waitWithCompletion(_ completion: @escaping () -> Void) {
        let operation = Procedure()
        operation.add(observer: BlockObserver(didFinish: { _, _ in completion() }))
        procedureQueue.addOperation(operation)
    }
}

extension Session: URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, challenge.protectionSpace.serverTrust.flatMap { URLCredential(trust: $0) })
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let completion = completionByTaskIdentifier[task.taskIdentifier] {
            completion(.error(error: error ?? ContentError.errorWithCode(.unknown, failureReason: "Failed to download")))
        }
    }
}

extension Session: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if let progress = progressByTaskIdentifier[downloadTask.taskIdentifier] {
            progress(Float(totalBytesWritten) / Float(totalBytesExpectedToWrite))
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let completion = completionByTaskIdentifier[downloadTask.taskIdentifier], let response = downloadTask.response as? HTTPURLResponse else { return }
        
        if response.statusCode == 200 {
            completion(.success(location: location))
        } else {
            completion(.error(error: ContentError.errorWithCode(.unknown, failureReason: "Failed to download, response status code: \(response.statusCode)")))
        }
    }
}
