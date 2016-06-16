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
import Swiftification

/// Manages, installs, and updates catalogs and item packages.
public class ContentController {
    public let location: NSURL
    
    let contentInventory: ContentInventory
    let session = Session()
    
    public let catalogUpdateObservers = ObserverSet<Catalog>()
    public let itemPackageInstallObservers = ObserverSet<Item>()
    public let itemPackageUninstallObservers = ObserverSet<Item>()
    
    public static var sharedController: ContentController?
    
    public static func setSharedController(location: NSURL) {
        sharedController = try? ContentController(location: location)
    }
    
    /// Constructs a controller for content at `location`.
    public init(location: NSURL) throws {
        self.location = location
        
        do {
            // TODO: Change back
            contentInventory = try ContentInventory(path: location.URLByAppendingPathComponent("ItemInventory.sqlite").path)
            //contentInventory = try ContentInventory(path: location.URLByAppendingPathComponent("Inventory.sqlite").path)
        } catch {
            throw error
        }
    }
    
    /// The currently installed catalog.
    public var catalog: Catalog? {
        guard let path = catalogPath else { return nil }
        
        return try? Catalog(path: path)
    }
    
    // TODO: This should be temporary
    public var catalogPath: String? {
        guard let catalogVerson = contentInventory.catalogVersion else { return nil }
        
        return location.URLByAppendingPathComponent("Catalog/\(catalogVerson)/Catalog.sqlite").path
    }
    
    /// Checks the server for the latest catalog version and installs it if newer than the currently
    /// installed catalog (or if there is no catalog installed).
    public func updateCatalog(progress progress: (amount: Float) -> Void, completion: (UpdateCatalogResult) -> Void) {
        session.fetchCatalogVersion { result in
            switch result {
            case let .Success(availableCatalogVersion):
                let versionDirectoryURL = self.location.URLByAppendingPathComponent("Catalog/\(availableCatalogVersion)")
                let catalogURL = versionDirectoryURL.URLByAppendingPathComponent("Catalog.sqlite")
                
                if let currentCatalogVersion = self.contentInventory.catalogVersion where currentCatalogVersion == availableCatalogVersion {
                    do {
                        let catalog = try Catalog(path: catalogURL.path)
                        completion(.AlreadyCurrent(catalog: catalog))
                    } catch let error as NSError {
                        completion(.Error(errors: [error]))
                    }
                } else {
                    self.session.downloadCatalog(catalogVersion: availableCatalogVersion, progress: progress) { result in
                        switch result {
                        case let .Success(location):
                            do {
                                try NSFileManager.defaultManager().createDirectoryAtURL(versionDirectoryURL, withIntermediateDirectories: true, attributes: nil)
                            } catch {}
                            do {
                                try NSFileManager.defaultManager().moveItemAtURL(location, toURL: catalogURL)
                            } catch {}
                            
                            do {
                                let catalog = try Catalog(path: catalogURL.path)
                                
                                self.contentInventory.catalogVersion = catalog.catalogVersion
                                
                                self.catalogUpdateObservers.notify(catalog)
                                
                                completion(.Success(catalog: catalog))
                            } catch let error as NSError {
                                completion(.Error(errors: [error]))
                            }
                        case let .Error(errors):
                            completion(.Error(errors: errors))
                        }
                    }
                }
            case let .Error(errors):
                completion(.Error(errors: errors))
            }
        }
    }
    
    /// The currently installed item package for the designated item.
    public func itemPackageForItemWithID(itemID: Int64) -> ItemPackage? {
        if let installedVersion = contentInventory.installedVersionOfItemWithID(itemID) {
            return try? ItemPackage(path: location.URLByAppendingPathComponent("Item/\(itemID)/\(installedVersion.schemaVersion).\(installedVersion.itemPackageVersion)/package.sqlite"))
        }
        
        return nil
    }
    
    /// Downloads and installs a specific version of an item, if not installed already.
    public func installItemPackageForItem(item: Item, progress: (amount: Float) -> Void, completion: (InstallItemPackageResult) -> Void) {
        let itemDirectoryURL = location.URLByAppendingPathComponent("Item/\(item.id)")
        let versionDirectoryURL = itemDirectoryURL.URLByAppendingPathComponent("\(Catalog.SchemaVersion).\(item.version)")
        let itemPackageURL = versionDirectoryURL.URLByAppendingPathComponent("package.sqlite")
        
        if let installedVersion = contentInventory.installedVersionOfItemWithID(item.id) where installedVersion.schemaVersion == Catalog.SchemaVersion && installedVersion.itemPackageVersion == item.version {
            do {
                let itemPackage = try ItemPackage(path: itemPackageURL)
                completion(.AlreadyInstalled(itemPackage: itemPackage))
            } catch let error as NSError {
                completion(.Error(errors: [error]))
            }
        } else {
            session.downloadItemPackage(externalID: item.externalID, version: item.version, progress: progress) { result in
                switch result {
                case let .Success(location):
                    do {
                        try NSFileManager.defaultManager().createDirectoryAtURL(itemDirectoryURL, withIntermediateDirectories: true, attributes: nil)
                    } catch {}
                    do {
                        try NSFileManager.defaultManager().moveItemAtURL(location, toURL: versionDirectoryURL)
                    } catch {}
                    
                    do {
                        let itemPackage = try ItemPackage(path: itemPackageURL)
                        
                        try self.contentInventory.setSchemaVersion(Catalog.SchemaVersion, itemPackageVersion: item.version, forItemWithID: item.id)
                        
                        self.itemPackageInstallObservers.notify(item)
                        
                        completion(.Success(itemPackage: itemPackage))
                    } catch let error as NSError {
                        completion(.Error(errors: [error]))
                    }
                case let .Error(errors):
                    completion(.Error(errors: errors))
                }
            }
        }
    }
    
    /// Uninstalls a specific version of an item.
    public func uninstallItemPackageForItem(item: Item) throws {
        let itemDirectoryURL = location.URLByAppendingPathComponent("Item/\(item.id)")
        let versionDirectoryURL = itemDirectoryURL.URLByAppendingPathComponent("\(Catalog.SchemaVersion).\(item.version)")
        
        if let installedVersion = contentInventory.installedVersionOfItemWithID(item.id) where installedVersion.schemaVersion == Catalog.SchemaVersion && installedVersion.itemPackageVersion == item.version {
            try NSFileManager.defaultManager().removeItemAtURL(versionDirectoryURL)

            try self.contentInventory.removeVersionForItemWithID(item.id)

            self.itemPackageUninstallObservers.notify(item)
        }
    }
    public func isItemWithIDInstalled(itemID: Int64) -> Bool {
        return contentInventory.isItemWithIDInstalled(itemID: itemID)
    }
    
    public func installedItemIDs() -> [Int64] {
        return contentInventory.installedItemIDs()
    }
    
    public func installedVersionOfItemWithID(itemID: Int64) -> (schemaVersion: Int, itemPackageVersion: Int)? {
        return contentInventory.installedVersionOfItemWithID(itemID)
    }
    
    public func isUpdatingOrInstalling() -> Bool {
        return session.operationQueue.operationCount > 0
    }
    
    public func waitWithCompletion(completion: () -> Void) {
        session.waitWithCompletion(completion)
    }
    
}
