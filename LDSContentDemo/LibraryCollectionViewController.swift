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
import Swiftification
import SVProgressHUD

class LibraryCollectionViewController: UIViewController {
    
    let contentController: ContentController
    let libraryCollection: LibraryCollection
    
    init(contentController: ContentController, libraryCollection: LibraryCollection) {
        self.contentController = contentController
        self.libraryCollection = libraryCollection
        
        super.init(nibName: nil, bundle: nil)
        
        automaticallyAdjustsScrollViewInsets = false
        
        title = libraryCollection.titleHTML
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    fileprivate static let CellIdentifier = "Cell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        automaticallyAdjustsScrollViewInsets = true
        
        tableView.register(LibraryItemTableViewCell.self, forCellReuseIdentifier: LibraryCollectionViewController.CellIdentifier)
        tableView.estimatedRowHeight = 44
        
        view.addSubview(tableView)
        
        let views = [
            "tableView": tableView,
        ]
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[tableView]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[tableView]|", options: [], metrics: nil, views: views))
        
        contentController.catalogUpdateObservers.add(self, operationQueue: .main, type(of: self).catalogDidUpdate)
        contentController.itemPackageInstallObservers.add(self, operationQueue: .main, type(of: self).itemPackageDidUpdate)
        contentController.itemPackageUninstallObservers.add(self, operationQueue: .main, type(of: self).itemPackageDidUninstall)
        catalog = contentController.catalog
        reloadData()
    }
    
    var catalog: Catalog?
    var sections = [(librarySection: LibrarySection, libraryNodes: [LibraryNode])]()
    
    func reloadData() {
        guard let catalog = catalog else { return }
        
        let librarySections = catalog.librarySectionsForLibraryCollectionWithID(libraryCollection.id)
        sections = librarySections.map { librarySection in
            return (librarySection: librarySection, libraryNodes: catalog.libraryNodesForLibrarySectionWithID(librarySection.id))
        }
    }
    
    func catalogDidUpdate(_ catalog: Catalog) {
        self.catalog = catalog
        reloadData()
    }
    
    func itemPackageDidUpdate(_ item: Item) {
        tableView.reloadData()
    }
    
    func itemPackageDidUninstall(_ item: Item) {
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        tableView.flashScrollIndicators()
    }
    
}

// MARK: - UITableViewDataSource

extension LibraryCollectionViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].libraryNodes.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].librarySection.title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LibraryCollectionViewController.CellIdentifier, for: indexPath)
        
        let libraryNode = sections[indexPath.section].libraryNodes[indexPath.row]
        switch libraryNode {
        case let libraryCollection as LibraryCollection:
            cell.textLabel?.text = libraryCollection.titleHTML
            cell.accessoryType = .disclosureIndicator
        case let libraryItem as LibraryItem:
            if let itemPackage = contentController.itemPackageForItemWithID(libraryItem.itemID) {
                cell.textLabel?.text = libraryItem.titleHTML
                cell.detailTextLabel?.text = "v\(itemPackage.schemaVersion).\(itemPackage.itemPackageVersion)"
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.textLabel?.text = libraryNode.titleHTML
                cell.detailTextLabel?.text = nil
                cell.accessoryType = .none
            }
        default:
            break
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let libraryNode = sections[indexPath.section].libraryNodes[indexPath.row]
        switch libraryNode {
        case let libraryItem as LibraryItem:
            return contentController.itemPackageForItemWithID(libraryItem.itemID) != nil
        default:
            return false
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let libraryNode = sections[indexPath.section].libraryNodes[indexPath.row]
            switch libraryNode {
            case _ as LibraryCollection:
                break
            case let libraryItem as LibraryItem:
                if let item = catalog?.itemWithID(libraryItem.itemID) {
                    SVProgressHUD.setDefaultMaskType(.clear)
                    SVProgressHUD.show(withStatus: "Uninstalling item")
                    
                    do {
                        try self.contentController.uninstallItemPackageForItem(item)

                        SVProgressHUD.setDefaultMaskType(.none)
                        SVProgressHUD.showSuccess(withStatus: "Uninstalled")
                    } catch let error as NSError {
                        NSLog("Failed to uninstall item package: %@", error)

                        SVProgressHUD.setDefaultMaskType(.none)
                        SVProgressHUD.showError(withStatus: "Failed")
                    }
                }
            default:
                break
            }
        }
    }
    
}

// MARK: - UITableViewDelegate

extension LibraryCollectionViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let libraryNode = sections[indexPath.section].libraryNodes[indexPath.row]
        switch libraryNode {
        case let libraryCollection as LibraryCollection:
            let viewController = LibraryCollectionViewController(contentController: contentController, libraryCollection: libraryCollection)
            
            navigationController?.pushViewController(viewController, animated: true)
        case let libraryItem as LibraryItem:
            if let itemPackage = contentController.itemPackageForItemWithID(libraryItem.itemID) {
                if let rootItemNavCollection = itemPackage.rootNavCollection() {
                    let viewController = ItemNavCollectionViewController(contentController: contentController, itemID: libraryItem.itemID, itemNavCollection: rootItemNavCollection)
                    
                    navigationController?.pushViewController(viewController, animated: true)
                } else {
                    tableView.deselectRow(at: indexPath, animated: false)
                }
            } else {
                if let item = catalog?.itemWithID(libraryItem.itemID) {
                    SVProgressHUD.setDefaultMaskType(.clear)
                    SVProgressHUD.showProgress(0, status:"Installing item")
                    
                    var previousAmount: Float = 0
                    contentController.installItemPackageForItem(item, progress: { amount in
                        guard previousAmount < amount - 0.1 else { return }
                        previousAmount = amount
                            
                        DispatchQueue.main.async {
                            SVProgressHUD.showProgress(amount, status: "Installing item")
                        }
                    }, completion: { result in
                        switch result {
                        case .success, .alreadyInstalled:
                            SVProgressHUD.setDefaultMaskType(.none)
                            SVProgressHUD.showSuccess(withStatus: "Installed")
                        case let .error(errors):
                            NSLog("Failed to install item package: %@", "\(errors)")
                            
                            SVProgressHUD.setDefaultMaskType(.none)
                            SVProgressHUD.showError(withStatus: "Failed")
                        }
                    })
                }
                
                tableView.deselectRow(at: indexPath, animated: false)
            }
        default:
            tableView.deselectRow(at: indexPath, animated: false)
        }
    }
    
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "Uninstall"
    }
    
}
