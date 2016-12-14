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
import SQLite

class ContentInventory {
    
    let db: Connection
    
    fileprivate static let currentVersion = 1
    
    init(path: String? = nil) throws {
        do {
            db = try Connection(path ?? "")
            db.busyTimeout = 5
        } catch {
            throw error
        }
        
        if databaseVersion < type(of: self).currentVersion {
            upgradeDatabaseFromVersion(databaseVersion)
        }
    }
    
    func inTransaction(_ closure: @escaping () throws -> Void) throws {
        let inTransactionKey = "txn:\(Unmanaged.passUnretained(self).toOpaque())"
        if Thread.current.threadDictionary[inTransactionKey] != nil {
            try closure()
        } else {
            Thread.current.threadDictionary[inTransactionKey] = true
            defer { Thread.current.threadDictionary.removeObject(forKey: inTransactionKey) }
            try db.transaction {
                try closure()
            }
        }
    }
    
    var databaseVersion: Int {
        get {
            do {
                return try Int(db.scalar("PRAGMA user_version") as? Int64 ?? 0)
            } catch {
                return 0
            }
        }
        set {
            do {
                try db.run("PRAGMA user_version = \(newValue)")
            } catch {}
        }
    }
    
    fileprivate func upgradeDatabaseFromVersion(_ fromVersion: Int) {
        if fromVersion < 1 {
            do {
                try inTransaction {
                    try self.db.run(InstalledItemTable.table.create(ifNotExists: true) { builder in
                        builder.column(InstalledItemTable.itemID, primaryKey: true)
                        builder.column(InstalledItemTable.schemaVersion)
                        builder.column(InstalledItemTable.itemPackageVersion)
                    })
                    
                    try self.db.run(InstallQueueTable.table.create(ifNotExists: true) { builder in
                        builder.column(InstallQueueTable.itemID, primaryKey: true)
                    })
                    
                    try self.db.run(ErroredInstallTable.table.create(ifNotExists: true) { builder in
                        builder.column(ErroredInstallTable.itemID, primaryKey: true)
                    })
                    
                    try self.db.run(InstalledCatalogTable.table.create(ifNotExists: true) { builder in
                        builder.column(InstalledCatalogTable.name, primaryKey: true)
                        builder.column(InstalledCatalogTable.url)
                        builder.column(InstalledCatalogTable.version)
                    })
                    
                    self.databaseVersion = 1
                }
            } catch {}
        }
    }
    
}

extension ContentInventory {
    
    class InstalledItemTable {
        
        static let table = Table("installed_item")
        static let itemID = Expression<Int64>("item_id")
        static let schemaVersion = Expression<Int>("schema_version")
        static let itemPackageVersion = Expression<Int>("item_package_version")
        
    }
    
    func installedItemIDs() -> [Int64] {
        do {
            return try db.prepare(InstalledItemTable.table.select(InstalledItemTable.itemID)).map { $0[InstalledItemTable.itemID] }
        } catch {
            return []
        }
    }
    
    func installedVersionOfItemWithID(_ itemID: Int64) -> (schemaVersion: Int, itemPackageVersion: Int)? {
        do {
            return try db.pluck(InstalledItemTable.table.filter(InstalledItemTable.itemID == itemID)).map { row in
                return (schemaVersion: row[InstalledItemTable.schemaVersion], itemPackageVersion: row[InstalledItemTable.itemPackageVersion])
            }
        } catch {
            return nil
        }
    }
    
    func isItemWithIDInstalled(itemID: Int64) -> Bool {
        do {
            return try db.scalar(InstalledItemTable.table.filter(InstalledItemTable.itemID == itemID).count) != 0
        } catch {
            return false
        }
    }
    
    func setSchemaVersion(_ schemaVersion: Int, itemPackageVersion: Int, forItemWithID itemID: Int64) throws {
        _ = try db.run(InstalledItemTable.table.insert(or: .replace,
            InstalledItemTable.itemID <- itemID,
            InstalledItemTable.schemaVersion <- schemaVersion,
            InstalledItemTable.itemPackageVersion <- itemPackageVersion
        ))
    }
    
    func removeVersionForItemWithID(_ itemID: Int64) throws {
        _ = try db.run(InstalledItemTable.table.filter(InstalledItemTable.itemID == itemID).delete())
    }

}

extension ContentInventory {
    
    class InstallQueueTable {
        
        static let table = Table("install_queue")
        static let itemID = Expression<Int64>("item_id")
        
    }
    
    func installingItemIDs() -> [Int64] {
        do {
            return try db.prepare(InstallQueueTable.table.select(InstallQueueTable.itemID)).map { $0[InstallQueueTable.itemID] }
        } catch {
            return []
        }
    }
    
    func addToInstallQueue(itemID: Int64) throws {
        _ = try db.run(InstallQueueTable.table.insert(or: .replace, InstallQueueTable.itemID <- itemID))
    }
    
    func removeFromInstallQueue(itemID: Int64) throws {
        _ = try db.run(InstallQueueTable.table.filter(InstallQueueTable.itemID == itemID).delete())
    }
    
}

extension ContentInventory {
    
    class ErroredInstallTable {
        
        static let table = Table("errored_install")
        static let itemID = Expression<Int64>("item_id")
        
    }
    
    func erroredItemIDs() -> [Int64] {
        do {
            return try db.prepare(ErroredInstallTable.table.select(ErroredInstallTable.itemID)).map { $0[ErroredInstallTable.itemID] }
        } catch {
            return []
        }
    }
    
    func setErrored(_ errored: Bool, itemID: Int64) throws {
        if errored {
            _ = try db.run(ErroredInstallTable.table.insert(or: .replace, ErroredInstallTable.itemID <- itemID))
        } else {
            _ = try db.run(ErroredInstallTable.table.filter(ErroredInstallTable.itemID == itemID).delete())
        }
        
    }
    
}

extension ContentInventory {
    
    class InstalledCatalogTable {
        
        static let table = Table("installed_catalog")
        static let name = Expression<String>("name")
        static let url = Expression<String?>("url")
        static let version = Expression<Int>("version")
        
        static func fromRow(_ row: Row) -> CatalogMetadata {
            return CatalogMetadata(name: row[name], url: row[url], version: row[version])
        }
        
    }
    
    func addOrUpdateCatalog(_ name: String, url: String?, version: Int) throws {
        _ = try db.run(InstalledCatalogTable.table.insert(or: .replace, InstalledCatalogTable.name <- name, InstalledCatalogTable.url <- url, InstalledCatalogTable.version <- version))
    }
    
    func deleteCatalogsNamed(_ names: [String]) throws {
        _ = try db.run(InstalledCatalogTable.table.filter(names.contains(InstalledCatalogTable.name)).delete())
    }
    
    func installedCatalogs() -> [CatalogMetadata] {
        do {
            return try db.prepare(InstalledCatalogTable.table).map { InstalledCatalogTable.fromRow($0) }
        } catch {
            return []
        }
    }
    
    func catalogNamed(_ name: String) -> CatalogMetadata? {
        // TODO: Switch back to use `db.pluck` when it doesn't crash
        do {
            return try db.prepare(InstalledCatalogTable.table.filter(InstalledCatalogTable.name == name).limit(1)).map { InstalledCatalogTable.fromRow($0) }.first
        } catch {
            return nil
        }
    }
    
}
