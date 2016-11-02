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

private let escapeRegex = try! NSRegularExpression(pattern: "[!%_]", options: [])

extension String {
    
    func withoutDiacritics() -> String {
        let result = NSMutableString(string: self)
        CFStringTransform(result, nil, kCFStringTransformStripCombiningMarks, false)
        return result as String
    }
    
    func escaped() -> String {
        let result = NSMutableString(string: self)
        escapeRegex.replaceMatchesInString(result, options: [], range: NSMakeRange(0, result.length), withTemplate: "!$0")
        return result as String
    }
    
    init?(_ imageRenditions: [ImageRendition]?) {
        guard let imageRenditions = imageRenditions where !imageRenditions.isEmpty else { return nil }
        
        var components = [String]()
        for imageRendition in imageRenditions {
            guard let urlString = imageRendition.url.absoluteString else { continue }
            
            components.append("\(Int(imageRendition.size.width))x\(Int(imageRendition.size.height)),\(urlString)")
        }
        self.init(components.joinWithSeparator("\n"))
    }
    
    func toImageRenditions() -> [ImageRendition]? {
        var imageRenditions = [ImageRendition]()
        
        let scanner = NSScanner(string: self)
        scanner.charactersToBeSkipped = nil
        
        while true {
            var width: Int = 0
            if !scanner.scanInteger(&width) || width < 0 {
                return nil
            }
            
            if !scanner.scanString("x", intoString: nil) {
                return nil
            }
            
            var height: Int = 0
            if !scanner.scanInteger(&height) || height < 0 {
                return nil
            }
            
            if !scanner.scanString(",", intoString: nil) {
                return nil
            }
            
            var urlString: NSString?
            if !scanner.scanUpToString("\n", intoString: &urlString) {
                return nil
            }
            
            guard let unwrappedURLString = urlString as? String, url = NSURL(string: unwrappedURLString) else { return nil }
            
            imageRenditions.append(ImageRendition(size: CGSize(width: width, height: height), url: url))
            
            if scanner.atEnd {
                break
            }
            
            if !scanner.scanString("\n", intoString: nil) {
                return nil
            }
        }
        
        return imageRenditions.count > 0 ? imageRenditions : nil
    }
    
}
