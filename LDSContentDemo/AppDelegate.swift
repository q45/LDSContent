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
    
    lazy var contentController: ContentController! = {
        let location = FileManager.privateDocumentsURL.appendingPathComponent("Content")
        let baseURL = URL(string: "https://edge.ldscdn.org/mobile/gospelstudy/beta/")!
        do {
            try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true, attributes: nil)
        } catch {}
        return try? ContentController(location: location, baseURL: baseURL)
    }()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        do {
            try FileManager.default.createDirectory(at: FileManager.privateDocumentsURL, withIntermediateDirectories: true, attributes: nil)
        } catch {}
        do {
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var url = FileManager.privateDocumentsURL
            try url.setResourceValues(resourceValues)
        } catch {}
        
        
        let viewController = LanguagesViewController(contentController: contentController)
        
        let navigationController = UINavigationController(rootViewController: viewController)
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        NSLog("Updating catalog")
        
        let showUI = (contentController.catalog == nil)
        if showUI {
            SVProgressHUD.setDefaultMaskType(.clear)
            SVProgressHUD.showProgress(0, status: "Installing catalog")
        }
        
        var previousAmount: Float = 0
        contentController.updateCatalog(progress: { amount in
            guard previousAmount < amount - 0.1 else { return }
            previousAmount = amount
            
            DispatchQueue.main.async {
                SVProgressHUD.showProgress(amount, status: "Installing catalog")
            }
        }, completion: { result in
            switch result {
            case let .success(catalog):
                NSLog("Updated catalog to v%li.%li", catalog.schemaVersion, catalog.catalogVersion)
            case let .partialSuccess(catalog, errors):
                NSLog("Updated catalog to v%li.%li", catalog.schemaVersion, catalog.catalogVersion)
                for (name, errors) in errors {
                    NSLog("Failed to update catalog \(name): %@", "\(errors)")
                }
            case let .error(errors):
                NSLog("Failed to update catalog: %@", "\(errors)")
            }
            
            if showUI {
                DispatchQueue.main.async {
                    switch result {
                    case .success, .partialSuccess:
                        SVProgressHUD.setDefaultMaskType(.none)
                        SVProgressHUD.showSuccess(withStatus: "Installed")
                    case .error:
                        SVProgressHUD.setDefaultMaskType(.none)
                        SVProgressHUD.showError(withStatus: "Failed")
                    }
                }
            }
        })
    }
    
}

