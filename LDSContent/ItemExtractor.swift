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
    
    static func extractItemPackage(location: URL, destination: URL) throws {
        let sourcePath = location.path
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)
        let destinationPath = destination.path
        guard SSZipArchive.unzipFile(atPath: sourcePath, toDestination: destinationPath) else {
            throw ContentError.errorWithCode(.unknown, failureReason: "Failed to decompress item package")
        }
        
        let uncompressedPackageURL = destination.appendingPathComponent("package.sqlite")
        if try !uncompressedPackageURL.checkResourceIsReachable() {
            throw ContentError.errorWithCode(.unknown, failureReason: "Uncompressed catalog is not reachable")
        }
    }
    
}
