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

class Session: NSObject {
    enum DownloadResult {
        case Success(location: NSURL)
        case Error(error: NSError)
    }
    
    lazy var urlSession: NSURLSession = {
        return NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: self, delegateQueue: nil)
    }()
    
    let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 5
        return queue
    }()
    
    private var progressByTaskIdentifier: [Int: (amount: Float) -> Void] = [:]
    private var completionByTaskIdentifier: [Int: (result: DownloadResult) -> Void] = [:]
    
    private func catalogOperationsForCatalogs(catalogs: [(name: String, baseURL: NSURL, destination: (version: Int) -> NSURL)], progress: (amount: Float) -> Void = { _ in }, completion: (DownloadCatalogResult) -> Void) -> [Operation] {
        return catalogs.flatMap { (name, baseURL, destination) -> [Operation] in
            let versionOperation = FetchCatalogVersionOperation(session: self, baseURL: baseURL)
            let downloadOperation = DownloadCatalogOperation(session: self, catalogName: name, baseURL: baseURL, destination: destination, progress: progress, completion: completion)
            downloadOperation.injectResultFromDependency(versionOperation)
            return [versionOperation, downloadOperation]
        }
    }
    
    func updateDefaultCatalog(destination destination: (version: Int) -> NSURL, progress: (amount: Float) -> Void = { _ in }, completion: (DownloadCatalogResult) -> Void) {
        guard let defaultURL = NSURL(string: "https://edge.ldscdn.org/mobile/gospelstudy/beta/") else { return completion(.Error(errors: [Error.errorWithCode(.Unknown, failureReason: "Malformed base URL for default catalog.")])) }
        
        let operations = catalogOperationsForCatalogs([(ContentController.defaultCatalogName, defaultURL, destination)], progress: progress, completion: completion)
        operationQueue.addOperations(operations)
    }
    
    func updateSecureCatalogs(secureCatalogs: [(name: String, baseURL: NSURL, destination: (version: Int) -> NSURL)], progress: (amount: Float) -> Void = { _ in }, completion: ([(name: String, baseURL: NSURL, result: DownloadCatalogResult)]) -> Void) {
        let operations = catalogOperationsForCatalogs(secureCatalogs, progress: progress, completion: { _ in })
        let group = GroupOperation(operations: operations)
        group.addObserver(DidFinishObserver { operation, errors in
            let results: [(name: String, baseURL: NSURL, result: DownloadCatalogResult)] = operations.flatMap {
                guard let downloadOperation = $0 as? DownloadCatalogOperation, result = downloadOperation.result else { return nil }
                
                return (downloadOperation.catalogName, downloadOperation.baseURL, result)
            }
            
            completion(results)
        })
        operationQueue.addOperation(group)
    }
    
    func downloadItemPackage(externalID externalID: String, version: Int, priority: InstallPriority = .Default, progress: (amount: Float) -> Void, completion: (DownloadItemPackageResult) -> Void) {
        let operation = DownloadItemPackageOperation(session: self, externalID: externalID, version: version, progress: progress, completion: completion)
        if case priority = InstallPriority.High {
            operation.queuePriority = .VeryHigh
        }
        operationQueue.addOperation(operation)
    }
    
    func registerCallbacks(progress progress: (amount: Float) -> Void, completion: (result: DownloadResult) -> Void, forTaskIdentifier taskIdentifier: Int) {
        progressByTaskIdentifier[taskIdentifier] = progress
        completionByTaskIdentifier[taskIdentifier] = completion
    }
    
    func deregisterCallbacksForTaskIdentifier(taskIdentifier: Int) {
        progressByTaskIdentifier[taskIdentifier] = nil
        completionByTaskIdentifier[taskIdentifier] = nil
    }

    func waitWithCompletion(completion: () -> Void) {
        let operation = Operation()
        operation.addObserver(BlockObserver(didFinish: { _, _ in completion() }))
        operationQueue.addOperation(operation)
    }
}

extension Session: NSURLSessionDelegate {
    func URLSession(session: NSURLSession, didReceiveChallenge challenge: NSURLAuthenticationChallenge, completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential?) -> Void) {
        completionHandler(.UseCredential, challenge.protectionSpace.serverTrust.flatMap { NSURLCredential(forTrust: $0) })
    }
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        if let completion = completionByTaskIdentifier[task.taskIdentifier] {
            completion(result: .Error(error: error ?? Error.errorWithCode(.Unknown, failureReason: "Failed to download")))
        }
    }
}

extension Session: NSURLSessionDownloadDelegate {
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if let progress = progressByTaskIdentifier[downloadTask.taskIdentifier] {
            progress(amount: Float(totalBytesWritten) / Float(totalBytesExpectedToWrite))
        }
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        if let completion = completionByTaskIdentifier[downloadTask.taskIdentifier] {
            completion(result: .Success(location: location))
        }
    }
}
