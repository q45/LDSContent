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

public struct RelatedVideoItemSource: Equatable {
    
    public let id: Int64
    public let mediaURL: URL
    public let type: String
    public let size: CGSize?
    public let fileSize: Int64?
    public let relatedVideoItemID: Int64
    
}

public func == (lhs: RelatedVideoItemSource, rhs: RelatedVideoItemSource) -> Bool {
    return lhs.id == rhs.id &&
        lhs.mediaURL == rhs.mediaURL &&
        lhs.type == rhs.type &&
        lhs.size == rhs.size &&
        lhs.fileSize == rhs.fileSize &&
        lhs.relatedVideoItemID == rhs.relatedVideoItemID
}
