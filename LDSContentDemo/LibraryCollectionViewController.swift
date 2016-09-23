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
        let tableView = UITableView(frame: .zero, style: .Plain)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private static let CellIdentifier = "Cell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        automaticallyAdjustsScrollViewInsets = true
        
        tableView.registerClass(LibraryItemTableViewCell.self, forCellReuseIdentifier: LibraryCollectionViewController.CellIdentifier)
        tableView.estimatedRowHeight = 44
        
        view.addSubview(tableView)
        
        let views = [
            "tableView": tableView,
        ]
        
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|[tableView]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[tableView]|", options: [], metrics: nil, views: views))
        
        contentController.catalogUpdateObservers.add(self, operationQueue: .mainQueue(), self.dynamicType.catalogDidUpdate)
        contentController.itemPackageInstallObservers.add(self, operationQueue: .mainQueue(), self.dynamicType.itemPackageDidUpdate)
        contentController.itemPackageUninstallObservers.add(self, operationQueue: .mainQueue(), self.dynamicType.itemPackageDidUninstall)
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
    
    func catalogDidUpdate(catalog: Catalog) {
        self.catalog = catalog
        reloadData()
    }
    
    func itemPackageDidUpdate(item: Item) {
        tableView.reloadData()
    }
    
    func itemPackageDidUninstall(item: Item) {
        tableView.reloadData()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        tableView.flashScrollIndicators()
    }
    
}

// MARK: - UITableViewDataSource

extension LibraryCollectionViewController: UITableViewDataSource {
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].libraryNodes.count
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].librarySection.title
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(LibraryCollectionViewController.CellIdentifier, forIndexPath: indexPath)
        
        let libraryNode = sections[indexPath.section].libraryNodes[indexPath.row]
        switch libraryNode {
        case let libraryCollection as LibraryCollection:
            cell.textLabel?.text = libraryCollection.titleHTML
            cell.accessoryType = .DisclosureIndicator
        case let libraryItem as LibraryItem:
            if let itemPackage = contentController.itemPackageForItemWithID(libraryItem.itemID) {
                cell.textLabel?.text = libraryItem.titleHTML
                cell.detailTextLabel?.text = "v\(itemPackage.schemaVersion).\(itemPackage.itemPackageVersion)"
                cell.accessoryType = .DisclosureIndicator
            } else {
                cell.textLabel?.text = libraryNode.titleHTML
                cell.detailTextLabel?.text = nil
                cell.accessoryType = .None
            }
        default:
            break
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        let libraryNode = sections[indexPath.section].libraryNodes[indexPath.row]
        switch libraryNode {
        case let libraryItem as LibraryItem:
            return contentController.itemPackageForItemWithID(libraryItem.itemID) != nil
        default:
            return false
        }
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let libraryNode = sections[indexPath.section].libraryNodes[indexPath.row]
            switch libraryNode {
            case _ as LibraryCollection:
                break
            case let libraryItem as LibraryItem:
                if let item = catalog?.itemWithID(libraryItem.itemID) {
                    SVProgressHUD.setDefaultMaskType(.Clear)
                    SVProgressHUD.showWithStatus("Uninstalling item")
                    
                    do {
                        try self.contentController.uninstallItemPackageForItem(item)

                        SVProgressHUD.setDefaultMaskType(.None)
                        SVProgressHUD.showSuccessWithStatus("Uninstalled")
                    } catch let error as NSError {
                        NSLog("Failed to uninstall item package: %@", error)

                        SVProgressHUD.setDefaultMaskType(.None)
                        SVProgressHUD.showErrorWithStatus("Failed")
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
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
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
                    tableView.deselectRowAtIndexPath(indexPath, animated: false)
                }
            } else {
                if let item = catalog?.itemWithID(libraryItem.itemID) {
                    SVProgressHUD.setDefaultMaskType(.Clear)
                    SVProgressHUD.showProgress(0, status:"Installing item")
                    
                    var previousAmount: Float = 0
                    contentController.installItemPackageForItem(item, progress: { amount in
                        guard previousAmount < amount - 0.1 else { return }
                        previousAmount = amount
                            
                        dispatch_async(dispatch_get_main_queue()) {
                            SVProgressHUD.showProgress(amount, status: "Installing item")
                        }
                    }, completion: { result in
                        switch result {
                        case .Success, .AlreadyInstalled:
                            SVProgressHUD.setDefaultMaskType(.None)
                            SVProgressHUD.showSuccessWithStatus("Installed")
                        case let .Error(errors):
                            NSLog("Failed to install item package: %@", "\(errors)")
                            
                            SVProgressHUD.setDefaultMaskType(.None)
                            SVProgressHUD.showErrorWithStatus("Failed")
                        }
                    })
                }
                
                tableView.deselectRowAtIndexPath(indexPath, animated: false)
            }
        default:
            tableView.deselectRowAtIndexPath(indexPath, animated: false)
        }
    }
    
    func tableView(tableView: UITableView, titleForDeleteConfirmationButtonForRowAtIndexPath indexPath: NSIndexPath) -> String? {
        return "Uninstall"
    }
    
}
