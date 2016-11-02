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
import SSZipArchive

struct ItemExtractor {
    
    static func extractItemPackage(location location: NSURL, destination: NSURL) throws {
        guard let sourcePath = location.path else {
            throw Error.errorWithCode(.Unknown, failureReason: "Failed to get compressed item package path")
        }
        
        try NSFileManager.defaultManager().createDirectoryAtURL(destination, withIntermediateDirectories: true, attributes: nil)
        
        guard let destinationPath = destination.path else {
            throw Error.errorWithCode(.Unknown, failureReason: "Failed to get destination directory path")
        }
        
        guard SSZipArchive.unzipFileAtPath(sourcePath, toDestination: destinationPath) else {
            throw Error.errorWithCode(.Unknown, failureReason: "Failed to decompress item package")
        }
        
        let uncompressedPackageURL = destination.URLByAppendingPathComponent("package.sqlite")
        
        var error: NSError?
        if uncompressedPackageURL?.checkResourceIsReachableAndReturnError(&error) != true {
            throw error ?? Error.errorWithCode(.Unknown, failureReason: "Resource is not reachable")
        }
    }
    
}
