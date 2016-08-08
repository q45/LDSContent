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

public enum InstallPriority {
    case Default
    case High
}

/// Manages, installs, and updates catalogs and item packages.
public class ContentController {
    static let defaultCatalogName = "default"
    
    public let location: NSURL
    
    let contentInventory: ContentInventory
    let session = Session()
    var progressByItemID = [Int64: Float]()
    
    public let catalogUpdateObservers = ObserverSet<Catalog>()
    public let itemPackageInstallObservers = ObserverSet<Item>()
    public let itemPackageUninstallObservers = ObserverSet<Item>()
    public let itemPackageInstallProgressObservers = ObserverSet<(item: Item, progress: Float)>()
    
    /// Constructs a controller for content at `location`.
    public init(location: NSURL) throws {
        self.location = location
        
        do {
            contentInventory = try ContentInventory(path: location.URLByAppendingPathComponent("Inventory.sqlite").path)
        } catch {
            throw error
        }
    }
    
    /// The currently installed catalog.
    public var catalog: Catalog? {
        if let mergedPath = mergedCatalogPath, mergedCatalog = try? Catalog(path: mergedPath) {
            return mergedCatalog
        } else if let defaultPath = defaultCatalogPath, defaultCatalog = try? Catalog(path: defaultPath) {
            return defaultCatalog
        }
        
        return nil
    }
    
    public var defaultCatalogPath: String? {
        guard let version = contentInventory.catalogNamed(ContentController.defaultCatalogName)?.version else { return nil }
        
        return locationForCatalog(ContentController.defaultCatalogName, version: version).path
    }
    
    public var mergedCatalogPath: String? {
        let directoryName = contentInventory.installedCatalogs().sort { $0.name < $1.name }.reduce("") { $0 + $1.name + String($1.version) }
        guard !directoryName.isEmpty else { return nil }
        
        return location.URLByAppendingPathComponent("MergedCatalogs/\(directoryName)/Catalog.sqlite").path
    }
    
    /// Directly install catalog located at `path`
    public func installCatalog(atPath path: String) throws {
        guard let catalog = try? Catalog(path: path, readonly: true) else { return }
        
        let destinationURL = locationForCatalog(ContentController.defaultCatalogName, version: catalog.catalogVersion)
        if let directory = destinationURL.URLByDeletingLastPathComponent, destinationPath = destinationURL.path {
            try NSFileManager.defaultManager().createDirectoryAtURL(directory, withIntermediateDirectories: true, attributes: nil)
            try NSFileManager.defaultManager().copyItemAtPath(path, toPath: destinationPath)
            try contentInventory.addOrUpdateCatalog(ContentController.defaultCatalogName, url: nil, version: catalog.catalogVersion)
            try mergeCatalogs()
        }
    }
    
    private func deleteSiblings(ofURL url: NSURL) {
        guard let parentDirectory = url.URLByDeletingLastPathComponent, items = try? NSFileManager.defaultManager().contentsOfDirectoryAtURL(parentDirectory, includingPropertiesForKeys: nil, options: [.SkipsHiddenFiles]) else { return }
        for siblingURL in items where siblingURL != url {
            do {
                try NSFileManager.defaultManager().removeItemAtURL(siblingURL)
            } catch {}
        }
    }
}

// MARK: - Catalog

extension ContentController {
    /// Checks the server for the latest catalog version and installs it if newer than the currently
    /// installed catalog (or if there is no catalog installed).
    public func updateCatalog(secureCatalogs secureCatalogs: [(name: String, baseURL: NSURL)]? = nil, progress: (amount: Float) -> Void = { _ in }, completion: (UpdateAndMergeCatalogResult) -> Void) {
        if let secureCatalogs = secureCatalogs {
            // Delete secure catalogs we no longer have access to
            let catalogsToDelete = contentInventory.installedCatalogs().filter { installedCatalog in !installedCatalog.isDefault() && !secureCatalogs.contains({ secureCatalog in secureCatalog.name == installedCatalog.name })}.map { $0.name }
            do {
                try self.contentInventory.deleteCatalogsNamed(catalogsToDelete)
                try catalogsToDelete.forEach { try NSFileManager.defaultManager().removeItemAtURL(location.URLByAppendingPathComponent("Catalogs/\($0)")) }
            } catch {
                NSLog("Couldn't delete catalogs \(catalogsToDelete): \(error)")
            }
        }
        
        session.updateDefaultCatalog(destination: { version in self.locationForCatalog(ContentController.defaultCatalogName, version: version) }) { result in
            switch result {
            case let .Success(version):
                do {
                    try self.contentInventory.addOrUpdateCatalog(ContentController.defaultCatalogName, url: nil, version: version)
                } catch let error as NSError {
                    completion(.Error(errors: [error]))
                    return
                }
                fallthrough
            case .AlreadyCurrent:
                func mergeAndComplete(secureCatalogFailures secureCatalogFailures: [(name: String, errors: [ErrorType])]) {
                    do {
                        let catalog = try self.mergeCatalogs()
                        if secureCatalogFailures.isEmpty {
                            self.catalogUpdateObservers.notify(catalog)
                            completion(.Success(catalog: catalog))
                        } else {
                            self.catalogUpdateObservers.notify(catalog)
                            completion(.PartialSuccess(catalog: catalog, secureCatalogFailures: secureCatalogFailures))
                        }
                    } catch {
                        completion(.Error(errors: [error]))
                    }
                    
                    self.cleanupOldCatalogs()
                }
                
                // If default catalog update succeeds, attempt to update secure catalogs (if any)
                if let secureCatalogs = secureCatalogs {
                    self.session.updateSecureCatalogs(secureCatalogs.map { catalog in (catalog.name, catalog.baseURL, { version in self.locationForCatalog(catalog.name, version: version) }) }) { results in
                        var secureCatalogFailures = [(name: String, errors: [ErrorType])]()
                        results.forEach { name, baseURL, result in
                            switch result {
                            case let .Success(version):
                                do {
                                    try self.contentInventory.addOrUpdateCatalog(name, url: baseURL.path, version: version)
                                } catch let error as NSError {
                                    secureCatalogFailures.append((name: name, errors: [error]))
                                }
                            case .AlreadyCurrent:
                                break
                            case let .Error(errors):
                                secureCatalogFailures.append((name: name, errors: errors))
                            }
                        }
                        
                        mergeAndComplete(secureCatalogFailures: secureCatalogFailures)
                    }
                } else {
                    mergeAndComplete(secureCatalogFailures: [])
                }
                
            case let .Error(errors):
                completion(.Error(errors: errors))
            }
        }
    }
    
    private func mergeCatalogs() throws -> Catalog {
        guard let defaultVersion = contentInventory.catalogNamed(ContentController.defaultCatalogName)?.version, mergedPath = mergedCatalogPath else { throw Error.errorWithCode(.Unknown, failureReason: "No default catalog.") }
        
        if let existingCatalog = try? Catalog(path: mergedPath) {
            return existingCatalog
        }
        
        let tempURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent("Catalog.sqlite")
        let defaultLocation = locationForCatalog(ContentController.defaultCatalogName, version: defaultVersion)
        do {
            try NSFileManager.defaultManager().removeItemAtURL(tempURL)
        } catch {}
        try NSFileManager.defaultManager().copyItemAtURL(defaultLocation, toURL: tempURL)
        
        let installedCatalogs = contentInventory.installedCatalogs()
        let mutableCatalog = try MutableCatalog(path: tempURL.path)
        
        for catalogMetadata in installedCatalogs where !catalogMetadata.isDefault() {
            guard let path = locationForCatalog(catalogMetadata.name, version: catalogMetadata.version).path else { continue }
            try mutableCatalog.insertDataFromCatalog(path, name: catalogMetadata.name)
        }
        let mergedURL = NSURL(fileURLWithPath: mergedPath)
        if let directory = mergedURL.URLByDeletingLastPathComponent {
            try NSFileManager.defaultManager().createDirectoryAtURL(directory, withIntermediateDirectories: true, attributes: nil)
        }
        try NSFileManager.defaultManager().moveItemAtURL(tempURL, toURL: mergedURL)
        
        return try Catalog(path: mergedPath)
    }
    
    private func locationForCatalog(name: String, version: Int) -> NSURL {
        return location.URLByAppendingPathComponent("Catalogs/\(name)/\(version)/Catalog.sqlite")
    }
    
    private func cleanupOldCatalogs() {
        var currentCatalogVersionURLs = contentInventory.installedCatalogs().flatMap { locationForCatalog($0.name, version: $0.version).URLByDeletingLastPathComponent }
        if let mergedCatalogPath = mergedCatalogPath, url = NSURL(fileURLWithPath: mergedCatalogPath).URLByDeletingLastPathComponent {
            currentCatalogVersionURLs.append(url)
        }
        
        currentCatalogVersionURLs.forEach(deleteSiblings)
    }
}

// MARK: - Item Package

extension ContentController {
    /// The currently installed item package for the designated item.
    public func itemPackageForItemWithID(itemID: Int64) -> ItemPackage? {
        if let installedVersion = contentInventory.installedVersionOfItemWithID(itemID) {
            return try? ItemPackage(url: location.URLByAppendingPathComponent("Item/\(itemID)/\(installedVersion.schemaVersion).\(installedVersion.itemPackageVersion)"))
        }
        
        return nil
    }
    
    /// Directly install item package located at `path`
    public func installItemPackage(atPath path: String, forItem item: Item) throws {
        let tempDirectoryURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent(NSProcessInfo.processInfo().globallyUniqueString)
        defer {
            do {
                try NSFileManager.defaultManager().removeItemAtURL(tempDirectoryURL)
            } catch {}
        }
        
        try ItemExtractor.extractItemPackage(location: NSURL(fileURLWithPath: path), destination: tempDirectoryURL)
        let itemDirectoryURL = location.URLByAppendingPathComponent("Item/\(item.id)")
        let versionDirectoryURL = itemDirectoryURL.URLByAppendingPathComponent("\(Catalog.SchemaVersion).\(item.version)")
        
        do {
            try NSFileManager.defaultManager().createDirectoryAtURL(itemDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch {}
        do {
            try NSFileManager.defaultManager().moveItemAtURL(tempDirectoryURL, toURL: versionDirectoryURL)
        } catch {}
        
        let itemPackage = try ItemPackage(url: versionDirectoryURL)
        if itemPackage.schemaVersion == Catalog.SchemaVersion && itemPackage.itemPackageVersion == item.version {
            try self.contentInventory.setSchemaVersion(Catalog.SchemaVersion, itemPackageVersion: item.version, forItemWithID: item.id)
        } else {
            try NSFileManager.defaultManager().removeItemAtURL(versionDirectoryURL)
            throw Error.errorWithCode(.Unknown, failureReason: "Item package is not readable.")
        }
    }
    
    /// Downloads and installs a specific version of an item, if not installed already.
    public func installItemPackageForItem(item: Item, priority: InstallPriority = .Default, progress: ((amount: Float) -> Void)? = nil, completion: ((InstallItemPackageResult) -> Void)? = nil) {
        let itemDirectoryURL = location.URLByAppendingPathComponent("Item/\(item.id)")
        let versionDirectoryURL = itemDirectoryURL.URLByAppendingPathComponent("\(Catalog.SchemaVersion).\(item.version)/")
        
        func isAlreadyInstalled() -> Bool {
            if let installedVersion = contentInventory.installedVersionOfItemWithID(item.id) where installedVersion.schemaVersion == Catalog.SchemaVersion && installedVersion.itemPackageVersion >= item.version {
                return true
            }
            
            return false
        }
        
        func completeAlreadyInstalled() {
            do {
                try contentInventory.setErrored(false, itemID: item.id)
                try contentInventory.removeFromInstallQueue(itemID: item.id)
            } catch {}
            
            if let package = itemPackageForItemWithID(item.id) {
                completion?(.AlreadyInstalled(itemPackage: package))
            } else {
                completion?(.Error(errors: [Error.errorWithCode(.Unknown, failureReason: "Failed to get existing package")]))
            }
        }
        
        if isAlreadyInstalled() {
            completeAlreadyInstalled()
        } else {
            do {
                try contentInventory.addToInstallQueue(itemID: item.id)
                try contentInventory.setErrored(false, itemID: item.id)
            } catch {}
            
            var previousAmount: Float = 0
            session.downloadItemPackage(externalID: item.externalID, version: item.version, priority: priority, progress: { amount in
                progress?(amount: amount)
                guard previousAmount == 0 || amount - previousAmount > 0.05 else { return }
                
                self.itemPackageInstallProgressObservers.notify((item: item, progress: amount))
                self.progressByItemID[item.id] = amount
                previousAmount = amount
            }) { result in
                self.progressByItemID[item.id] = nil
                switch result {
                case let .Success(location):
                    guard !isAlreadyInstalled() else {
                        completeAlreadyInstalled()
                        break
                        
                    }
                    do {
                        try NSFileManager.defaultManager().createDirectoryAtURL(itemDirectoryURL, withIntermediateDirectories: true, attributes: nil)
                    } catch {}
                    do {
                        try NSFileManager.defaultManager().moveItemAtURL(location, toURL: versionDirectoryURL)
                    } catch {}
                    
                    self.deleteSiblings(ofURL: versionDirectoryURL)
                    
                    do {
                        let itemPackage = try ItemPackage(url: versionDirectoryURL)
                        
                        try self.contentInventory.setSchemaVersion(Catalog.SchemaVersion, itemPackageVersion: item.version, forItemWithID: item.id)
                        
                        do {
                            try self.contentInventory.removeFromInstallQueue(itemID: item.id)
                        } catch {}
                        
                        self.itemPackageInstallObservers.notify(item)
                        
                        completion?(.Success(itemPackage: itemPackage))
                    } catch let error as NSError {
                        do {
                            try self.contentInventory.setErrored(true, itemID: item.id)
                            try self.contentInventory.removeFromInstallQueue(itemID: item.id)
                        } catch {}
                        completion?(.Error(errors: [error]))
                    }
                case let .Error(errors):
                    do {
                        try self.contentInventory.setErrored(true, itemID: item.id)
                        try self.contentInventory.removeFromInstallQueue(itemID: item.id)
                    } catch {}
                    completion?(.Error(errors: errors))
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
    
    public func installingItemIDs() -> [Int64] {
        return contentInventory.installingItemIDs()
    }
    
    public func erroredItemIDs() -> [Int64] {
        return contentInventory.erroredItemIDs()
    }
    
    public func installedVersionOfItemWithID(itemID: Int64) -> (schemaVersion: Int, itemPackageVersion: Int)? {
        return contentInventory.installedVersionOfItemWithID(itemID)
    }
    
    public func itemPackageInstallProgressForItemWithID(itemID: Int64) -> Float? {
        return progressByItemID[itemID]
    }
    
    public func isUpdatingOrInstalling() -> Bool {
        return session.operationQueue.operationCount > 0
    }
    
    public func waitWithCompletion(completion: () -> Void) {
        session.waitWithCompletion(completion)
    }
    
}
