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

class FetchCatalogVersionOperation: Procedure, ResultInjection {
    
    let session: Session
    let baseURL: URL
    
    var result: PendingValue<Int> = .pending
    var requirement: PendingValue<Void> = .void
    
    init(session: Session, baseURL: URL) {
        self.session = session
        self.baseURL = baseURL
        
        super.init()
    }
    
    override func execute() {
        let indexURL = baseURL.appendingPathComponent("v3/index.json")
        let request = URLRequest(url: indexURL)
        
        let task = session.urlSession.dataTask(with: request, completionHandler: { data, response, error in
            self.session.networkActivityObservers.notify(.stop)
            
            if let error = error {
                self.finish(withError: error)
                return
            }
            
            guard let data = data else {
                self.finish(withError: ContentError.errorWithCode(.unknown, failureReason: "Missing response data"))
                return
            }
            
            let jsonObject: Any
            do {
                jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            } catch let error as NSError {
                self.finish(withError: error)
                return
            }
            
            guard let jsonDictionary = jsonObject as? [String: Any], let catalogVersion = jsonDictionary["catalogVersion"] as? Int else {
                self.finish(withError: ContentError.errorWithCode(.unknown, failureReason: "Unexpected JSON response"))
                return
            }
            
            self.result = .ready(catalogVersion)
            
            self.finish()
        }) 
        session.networkActivityObservers.notify(.start)
        task.resume()
    }
    
}
