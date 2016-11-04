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
    case normal
    case high
}

/// Manages, installs, and updates catalogs and item packages.
public class ContentController {
    static let defaultCatalogName = "default"
    
    public let location: URL
    
    let contentInventory: ContentInventory
    let session: Session
    var progressByItemID = [Int64: Float]()
    
    public let catalogUpdateObservers = ObserverSet<Catalog>()
    public let itemPackageInstallObservers = ObserverSet<Item>()
    public let itemPackageUninstallObservers = ObserverSet<Item>()
    public let itemPackageInstallProgressObservers = ObserverSet<(item: Item, progress: Float)>()
    public let networkActivityObservers = ObserverSet<NetworkActivity>()
    
    public enum NetworkActivity {
        case start
        case stop
    }
    
    /// Constructs a controller for content at `location` with baseURL.
    public init(location: URL, baseURL: URL) throws {
        self.location = location
        session = Session(baseURL: baseURL)
        
        do {
            contentInventory = try ContentInventory(path: location.appendingPathComponent("Inventory.sqlite").path)
        } catch {
            throw error
        }
        session.networkActivityObservers.add(self, type(of: self).notifyNetworkActivity)
    }
    
    /// The currently installed catalog.
    public var catalog: Catalog? {
        if let mergedPath = mergedCatalogPath, let mergedCatalog = try? Catalog(path: mergedPath) {
            return mergedCatalog
        } else if let defaultPath = defaultCatalogPath, let defaultCatalog = try? Catalog(path: defaultPath) {
            return defaultCatalog
        }
        
        return nil
    }
    
    public var defaultCatalogPath: String? {
        guard let version = contentInventory.catalogNamed(ContentController.defaultCatalogName)?.version else { return nil }
        
        return locationForCatalog(ContentController.defaultCatalogName, version: version).path
    }
    
    public var mergedCatalogPath: String? {
        let directoryName = contentInventory.installedCatalogs().sorted { $0.name < $1.name }.reduce("") { $0 + $1.name + String($1.version) }
        guard !directoryName.isEmpty else { return nil }
        
        return location.appendingPathComponent("MergedCatalogs/\(directoryName)/Catalog.sqlite").path
    }
    
    /// Directly install catalog located at `path`
    public func installCatalog(atPath path: String) throws {
        guard let catalog = try? Catalog(path: path, readonly: true) else { return }
        
        let destinationURL = locationForCatalog(ContentController.defaultCatalogName, version: catalog.catalogVersion)
        let directory = destinationURL.deletingLastPathComponent()
        let destinationPath = destinationURL.path
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.copyItem(atPath: path, toPath: destinationPath)
        try contentInventory.addOrUpdateCatalog(ContentController.defaultCatalogName, url: nil, version: catalog.catalogVersion)
        try mergeCatalogs()
    }
    
    fileprivate func deleteSiblings(ofURL url: URL) {
        let parentDirectory = url.deletingLastPathComponent()
        guard let items = try? FileManager.default.contentsOfDirectory(at: parentDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return }
        
        for siblingURL in items where siblingURL.lastPathComponent != url.lastPathComponent {
            do {
                try FileManager.default.removeItem(at: siblingURL)
            } catch {}
        }
    }
    
    fileprivate func notifyNetworkActivity(_ networkActivity: NetworkActivity) {
        networkActivityObservers.notify(networkActivity)
    }
    
}

// MARK: - Catalog

extension ContentController {
    /// Checks the server for the latest catalog version and installs it if newer than the currently
    /// installed catalog (or if there is no catalog installed).
    public func updateCatalog(secureCatalogs: [(name: String, baseURL: URL)]? = nil, progress: (_ amount: Float) -> Void = { _ in }, completion: @escaping (UpdateAndMergeCatalogResult) -> Void) {
        if let secureCatalogs = secureCatalogs {
            // Delete secure catalogs we no longer have access to
            let catalogsToDelete = contentInventory.installedCatalogs().filter { installedCatalog in !installedCatalog.isDefault() && !secureCatalogs.contains(where: { secureCatalog in secureCatalog.name == installedCatalog.name })}.map { $0.name }
            do {
                try self.contentInventory.deleteCatalogsNamed(catalogsToDelete)
                try catalogsToDelete.forEach { try FileManager.default.removeItem(at: location.appendingPathComponent("Catalogs/\($0)")) }
            } catch {
                NSLog("Couldn't delete catalogs \(catalogsToDelete): \(error)")
            }
        }
        
        // This variable is used to see if there were any catalog changes
        let catalogPathBeforeMerge = self.mergedCatalogPath
        
        session.updateDefaultCatalog(destination: { version in self.locationForCatalog(ContentController.defaultCatalogName, version: version) }) { result in
            switch result {
            case let .success(version):
                do {
                    try self.contentInventory.addOrUpdateCatalog(ContentController.defaultCatalogName, url: nil, version: version)
                } catch let error as NSError {
                    completion(.error(errors: [error]))
                    return
                }
                fallthrough
            case .alreadyCurrent:
                func mergeAndComplete(secureCatalogFailures: [(name: String, errors: [Error])]) {
                    do {
                        let catalog = try self.mergeCatalogs()
                        if secureCatalogFailures.isEmpty {
                            completion(.success(catalog: catalog))
                        } else {
                            completion(.partialSuccess(catalog: catalog, secureCatalogFailures: secureCatalogFailures))
                        }
                        // Check to see if the catalogPath changed after merge
                        if self.mergedCatalogPath != catalogPathBeforeMerge {
                            self.catalogUpdateObservers.notify(catalog)
                        }
                    } catch {
                        completion(.error(errors: [error]))
                    }
                    
                    self.cleanupOldCatalogs()
                }
                
                // If default catalog update succeeds, attempt to update secure catalogs (if any)
                if let secureCatalogs = secureCatalogs {
                    self.session.updateSecureCatalogs(secureCatalogs.map { catalog in (catalog.name, catalog.baseURL, { version in self.locationForCatalog(catalog.name, version: version) }) }) { results in
                        var secureCatalogFailures = [(name: String, errors: [Error])]()
                        results.forEach { name, baseURL, result in
                            switch result {
                            case let .success(version):
                                do {
                                    try self.contentInventory.addOrUpdateCatalog(name, url: baseURL.absoluteString, version: version)
                                } catch let error as NSError {
                                    secureCatalogFailures.append((name: name, errors: [error]))
                                }
                            case .alreadyCurrent:
                                break
                            case let .error(errors):
                                secureCatalogFailures.append((name: name, errors: errors))
                            }
                        }
                        
                        mergeAndComplete(secureCatalogFailures: secureCatalogFailures)
                    }
                } else {
                    mergeAndComplete(secureCatalogFailures: [])
                }
                
            case let .error(errors):
                completion(.error(errors: errors))
            }
        }
    }
    
    @discardableResult fileprivate func mergeCatalogs() throws -> Catalog {
        guard let defaultVersion = contentInventory.catalogNamed(ContentController.defaultCatalogName)?.version, let mergedPath = mergedCatalogPath else { throw ContentError.errorWithCode(.unknown, failureReason: "No default catalog.") }
        
        if let existingCatalog = try? Catalog(path: mergedPath) {
            return existingCatalog
        }
        
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Catalog.sqlite")
        let defaultLocation = locationForCatalog(ContentController.defaultCatalogName, version: defaultVersion)
        do {
            try FileManager.default.removeItem(at: tempURL)
        } catch {}
        try FileManager.default.copyItem(at: defaultLocation, to: tempURL)
        
        let installedCatalogs = contentInventory.installedCatalogs()
        let mutableCatalog = try MutableCatalog(path: tempURL.path)
        
        for catalogMetadata in installedCatalogs where !catalogMetadata.isDefault() {
            let path = locationForCatalog(catalogMetadata.name, version: catalogMetadata.version).path
            try mutableCatalog.insertDataFromCatalog(path, name: catalogMetadata.name)
        }
        let mergedURL = URL(fileURLWithPath: mergedPath)
        let directory = mergedURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.moveItem(at: tempURL, to: mergedURL)
        
        return try Catalog(path: mergedPath)
    }
    
    fileprivate func locationForCatalog(_ name: String, version: Int) -> URL {
        return location.appendingPathComponent("Catalogs/\(name)/\(version)/Catalog.sqlite")
    }
    
    fileprivate func cleanupOldCatalogs() {
        var currentCatalogVersionURLs = contentInventory.installedCatalogs().flatMap { locationForCatalog($0.name, version: $0.version).deletingLastPathComponent() }
        if let mergedCatalogPath = mergedCatalogPath {
            let url = URL(fileURLWithPath: mergedCatalogPath).deletingLastPathComponent()
            currentCatalogVersionURLs.append(url)
        }
        
        currentCatalogVersionURLs.forEach(deleteSiblings)
    }
}

// MARK: - Item Package

extension ContentController {
    /// The currently installed item package for the designated item.
    public func itemPackageForItemWithID(_ itemID: Int64) -> ItemPackage? {
        if let installedVersion = contentInventory.installedVersionOfItemWithID(itemID) {
            return try? ItemPackage(url: location.appendingPathComponent("Item/\(itemID)/\(installedVersion.schemaVersion).\(installedVersion.itemPackageVersion)"))
        }
        
        return nil
    }
    
    /// Directly install item package located at `path`
    public func installItemPackage(atPath path: String, forItem item: Item) throws {
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
        defer {
            do {
                try FileManager.default.removeItem(at: tempDirectoryURL)
            } catch {}
        }
        
        try ItemExtractor.extractItemPackage(location: URL(fileURLWithPath: path), destination: tempDirectoryURL)
        let itemDirectoryURL = location.appendingPathComponent("Item/\(item.id)")
        let versionDirectoryURL = itemDirectoryURL.appendingPathComponent("\(Catalog.SchemaVersion).\(item.version)")
        
        do {
            try FileManager.default.createDirectory(at: itemDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch {}
        do {
            try FileManager.default.moveItem(at: tempDirectoryURL, to: versionDirectoryURL)
        } catch {}
        
        let itemPackage = try ItemPackage(url: versionDirectoryURL)
        if itemPackage.schemaVersion == Catalog.SchemaVersion && itemPackage.itemPackageVersion == item.version {
            try self.contentInventory.setSchemaVersion(Catalog.SchemaVersion, itemPackageVersion: item.version, forItemWithID: item.id)
        } else {
            try FileManager.default.removeItem(at: versionDirectoryURL)
            throw ContentError.errorWithCode(.unknown, failureReason: "Item package is not readable.")
        }
    }
    
    /// Downloads and installs a specific version of an item, if not installed already.
    public func installItemPackageForItem(_ item: Item, priority: InstallPriority = .normal, progress: ((_ amount: Float) -> Void)? = nil, completion: ((InstallItemPackageResult) -> Void)? = nil) {
        let itemDirectoryURL = location.appendingPathComponent("Item/\(item.id)")
        let versionDirectoryURL = itemDirectoryURL.appendingPathComponent("\(Catalog.SchemaVersion).\(item.version)/")
        
        func isAlreadyInstalled() -> Bool {
            if let installedVersion = contentInventory.installedVersionOfItemWithID(item.id), installedVersion.schemaVersion == Catalog.SchemaVersion && installedVersion.itemPackageVersion >= item.version {
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
                completion?(.alreadyInstalled(itemPackage: package))
            } else {
                completion?(.error(errors: [ContentError.errorWithCode(.unknown, failureReason: "Failed to get existing package")]))
            }
        }
        
        if isAlreadyInstalled() {
            completeAlreadyInstalled()
        } else {
            do {
                try contentInventory.addToInstallQueue(itemID: item.id)
                try contentInventory.setErrored(false, itemID: item.id)
            } catch {}
            
            
            let baseURL: URL?
            if let source = catalog?.sourceWithID(item.sourceID), source.type != .standard, let urlString = self.contentInventory.catalogNamed(source.name)?.url {
                baseURL = URL(string: urlString)
            } else {
                baseURL = nil
            }
            
            var previousAmount: Float = 0
            session.downloadItemPackage(baseURL: baseURL ?? session.baseURL, externalID: item.externalID, version: item.version, priority: priority, progress: { amount in
                progress?(amount)
                guard previousAmount == 0 || amount - previousAmount > 0.05 else { return }
                
                self.itemPackageInstallProgressObservers.notify((item: item, progress: amount))
                self.progressByItemID[item.id] = amount
                previousAmount = amount
            }) { result in
                self.progressByItemID[item.id] = nil
                switch result {
                case let .success(location):
                    guard !isAlreadyInstalled() else {
                        completeAlreadyInstalled()
                        break
                        
                    }
                    do {
                        try FileManager.default.createDirectory(at: itemDirectoryURL, withIntermediateDirectories: true, attributes: nil)
                    } catch {}
                    do {
                        try FileManager.default.moveItem(at: location, to: versionDirectoryURL)
                    } catch {}
                    
                    self.deleteSiblings(ofURL: versionDirectoryURL)
                    
                    do {
                        let itemPackage = try ItemPackage(url: versionDirectoryURL)
                        
                        try self.contentInventory.setSchemaVersion(Catalog.SchemaVersion, itemPackageVersion: item.version, forItemWithID: item.id)
                        
                        do {
                            try self.contentInventory.removeFromInstallQueue(itemID: item.id)
                        } catch {}
                        
                        self.itemPackageInstallObservers.notify(item)
                        
                        completion?(.success(itemPackage: itemPackage))
                    } catch let error as NSError {
                        do {
                            try self.contentInventory.setErrored(true, itemID: item.id)
                            try self.contentInventory.removeFromInstallQueue(itemID: item.id)
                        } catch {}
                        completion?(.error(errors: [error]))
                    }
                case let .error(errors):
                    do {
                        try self.contentInventory.setErrored(true, itemID: item.id)
                        try self.contentInventory.removeFromInstallQueue(itemID: item.id)
                    } catch {}
                    completion?(.error(errors: errors))
                }
            }
        }
    }
    
    /// Uninstalls a specific version of an item.
    public func uninstallItemPackageForItem(_ item: Item) throws {
        let itemDirectoryURL = location.appendingPathComponent("Item/\(item.id)")
        let versionDirectoryURL = itemDirectoryURL.appendingPathComponent("\(Catalog.SchemaVersion).\(item.version)")
        
        if let installedVersion = contentInventory.installedVersionOfItemWithID(item.id), installedVersion.schemaVersion == Catalog.SchemaVersion && installedVersion.itemPackageVersion == item.version {
            try FileManager.default.removeItem(at: versionDirectoryURL)

            try self.contentInventory.removeVersionForItemWithID(item.id)

            self.itemPackageUninstallObservers.notify(item)
        }
    }
    
    public func isItemWithIDInstalled(_ itemID: Int64) -> Bool {
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
    
    public func installedVersionOfItemWithID(_ itemID: Int64) -> (schemaVersion: Int, itemPackageVersion: Int)? {
        return contentInventory.installedVersionOfItemWithID(itemID)
    }
    
    public func itemPackageInstallProgressForItemWithID(_ itemID: Int64) -> Float? {
        return progressByItemID[itemID]
    }
    
    public func isUpdatingOrInstalling() -> Bool {
        return session.procedureQueue.operationCount > 0
    }
    
    public func waitWithCompletion(_ completion: @escaping () -> Void) {
        session.waitWithCompletion(completion)
    }
    
}
