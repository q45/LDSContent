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

import UIKit
import LDSContent
import SVProgressHUD

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    lazy var contentController: ContentController? = {
        guard let location = NSFileManager.privateDocumentsURL.URLByAppendingPathComponent("Content"), baseURL = NSURL(string: "https://edge.ldscdn.org/mobile/gospelstudy/beta/") else { return nil }
        do {
            try NSFileManager.defaultManager().createDirectoryAtURL(location, withIntermediateDirectories: true, attributes: nil)
        } catch {}
        return try? ContentController(location: location, baseURL: baseURL)
    }()
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        do {
            try NSFileManager.defaultManager().createDirectoryAtURL(NSFileManager.privateDocumentsURL, withIntermediateDirectories: true, attributes: nil)
        } catch {}
        do {
            try NSFileManager.privateDocumentsURL.setResourceValue(true, forKey: NSURLIsExcludedFromBackupKey)
        } catch {}
        
        window = UIWindow(frame: UIScreen.mainScreen().bounds)
        
        if let contentController = contentController {
            let viewController = LanguagesViewController(contentController: contentController)
            let navigationController = UINavigationController(rootViewController: viewController)
            window?.rootViewController = navigationController
        }
        
        window?.makeKeyAndVisible()
        
        return true
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        NSLog("Updating catalog")
        
        let showUI = contentController?.catalog == nil
        if showUI {
            SVProgressHUD.setDefaultMaskType(.Clear)
            SVProgressHUD.showProgress(0, status: "Installing catalog")
        }
        
        var previousAmount: Float = 0
        contentController?.updateCatalog(progress: { amount in
            guard previousAmount < amount - 0.1 else { return }
            previousAmount = amount
            
            dispatch_async(dispatch_get_main_queue()) {
                SVProgressHUD.showProgress(amount, status: "Installing catalog")
            }
        }, completion: { result in
            switch result {
            case let .Success(catalog):
                NSLog("Updated catalog to v%li.%li", catalog.schemaVersion, catalog.catalogVersion)
            case let .PartialSuccess(catalog, errors):
                NSLog("Updated catalog to v%li.%li", catalog.schemaVersion, catalog.catalogVersion)
                for (name, errors) in errors {
                    NSLog("Failed to update catalog \(name): %@", "\(errors)")
                }
            case let .Error(errors):
                NSLog("Failed to update catalog: %@", "\(errors)")
            }
            
            if showUI {
                dispatch_async(dispatch_get_main_queue()) {
                    switch result {
                    case .Success, .PartialSuccess:
                        SVProgressHUD.setDefaultMaskType(.None)
                        SVProgressHUD.showSuccessWithStatus("Installed")
                    case .Error:
                        SVProgressHUD.setDefaultMaskType(.None)
                        SVProgressHUD.showErrorWithStatus("Failed")
                    }
                }
            }
        })
    }
    
}

