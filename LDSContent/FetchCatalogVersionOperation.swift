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

class FetchCatalogVersionOperation: Operation, ResultOperationType {
    
    let session: Session
    let baseURL: NSURL
    
    private(set) var result: Int?
    
    init(session: Session, baseURL: NSURL) {
        self.session = session
        self.baseURL = baseURL
        
        super.init()
    }
    
    override func execute() {
        let indexURL = baseURL.URLByAppendingPathComponent("v3/index.json")
        let request = NSMutableURLRequest(URL: indexURL)
        
        let task = session.urlSession.dataTaskWithRequest(request) { data, response, error in
            self.session.networkActivityObservers.notify(.Stop)
            
            if let error = error {
                self.finish(error)
                return
            }
            
            guard let data = data else {
                self.finish(Error.errorWithCode(.Unknown, failureReason: "Missing response data"))
                return
            }
            
            let jsonObject: AnyObject
            do {
                jsonObject = try NSJSONSerialization.JSONObjectWithData(data, options: [])
            } catch let error as NSError {
                self.finish(error)
                return
            }
            
            guard let jsonDictionary = jsonObject as? [String: AnyObject], catalogVersion = jsonDictionary["catalogVersion"] as? Int else {
                self.finish(Error.errorWithCode(.Unknown, failureReason: "Unexpected JSON response"))
                return
            }
            
            self.result = catalogVersion
            
            self.finish()
        }
        session.networkActivityObservers.notify(.Start)
        task.resume()
    }
    
}
