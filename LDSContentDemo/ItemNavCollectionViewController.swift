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

class ItemNavCollectionViewController: UIViewController {
    
    let contentController: ContentController
    let itemID: Int64
    let itemNavCollection: NavCollection
    
    init(contentController: ContentController, itemID: Int64, itemNavCollection: NavCollection) {
        self.contentController = contentController
        self.itemID = itemID
        self.itemNavCollection = itemNavCollection
        
        super.init(nibName: nil, bundle: nil)
        
        automaticallyAdjustsScrollViewInsets = false
        
        title = itemNavCollection.titleHTML
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
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: ItemNavCollectionViewController.CellIdentifier)
        tableView.estimatedRowHeight = 44
        
        view.addSubview(tableView)
        
        let views = [
            "tableView": tableView,
        ]
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[tableView]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[tableView]|", options: [], metrics: nil, views: views))
        
        contentController.itemPackageInstallObservers.add(self, operationQueue: .main, type(of: self).itemPackageDidUpdate)
        itemPackage = contentController.itemPackageForItemWithID(itemID)
        reloadData()
    }
    
    var itemPackage: ItemPackage?
    var sections = [(itemNavSection: NavSection, itemNavNodes: [NavNode])]()
    var sectionIndexes = [(title: String, indexPath: IndexPath)]()
    
    func reloadData() {
        guard let itemPackage = itemPackage else { return }
        
        let itemNavSections = itemPackage.navSectionsForNavCollectionWithID(itemNavCollection.id)
        sections = itemNavSections.map { itemNavSection in
            return (itemNavSection: itemNavSection, itemNavNodes: itemPackage.navNodesForNavSectionWithID(itemNavSection.id))
        }
        
        sectionIndexes = itemPackage.navCollectionIndexEntriesForNavCollectionWithID(itemNavCollection.id).flatMap { indexEntry in
            return (title: indexEntry.title, indexPath: indexEntry.indexPath)
        }
    }
    
    func itemPackageDidUpdate(_ item: Item) {
        guard item.id == itemID else { return }
        
        self.itemPackage = contentController.itemPackageForItemWithID(item.id)
        reloadData()
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

extension ItemNavCollectionViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].itemNavNodes.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].itemNavSection.title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ItemNavCollectionViewController.CellIdentifier, for: indexPath)
        
        let itemNavNode = sections[indexPath.section].itemNavNodes[indexPath.row]
        cell.textLabel?.text = itemNavNode.titleHTML
        
        if itemNavNode is NavCollection {
            cell.accessoryType = .disclosureIndicator
        } else {
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sectionIndexes.map { $0.title }
    }
    
    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        let sectionIndex = sectionIndexes[index]
        tableView.scrollToRow(at: sectionIndex.indexPath, at: .top, animated: false)
        return NSNotFound
    }
    
}

// MARK: - UITableViewDelegate

extension ItemNavCollectionViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let itemNavNode = sections[indexPath.section].itemNavNodes[indexPath.row]
        switch itemNavNode {
        case let itemNavCollection as NavCollection:
            let viewController = ItemNavCollectionViewController(contentController: contentController, itemID: itemID, itemNavCollection: itemNavCollection)
            
            navigationController?.pushViewController(viewController, animated: true)
        case _ as NavItem:
            tableView.deselectRow(at: indexPath, animated: false)
        default:
            tableView.deselectRow(at: indexPath, animated: false)
        }
    }
    
}
