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

class LanguagesViewController: UIViewController {
    
    let contentController: ContentController
    
    init(contentController: ContentController) {
        self.contentController = contentController
        
        super.init(nibName: nil, bundle: nil)
        
        automaticallyAdjustsScrollViewInsets = false
        
        title = "Languages"
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
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: LanguagesViewController.CellIdentifier)
        tableView.estimatedRowHeight = 44
        
        view.addSubview(tableView)
        
        let views = [
            "tableView": tableView,
        ]
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[tableView]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[tableView]|", options: [], metrics: nil, views: views))
        
        contentController.catalogUpdateObservers.add(self, operationQueue: .main, type(of: self).catalogDidUpdate)
        catalog = contentController.catalog
        reloadData()
    }
    
    var catalog: Catalog?
    var uiLanguage: Language?
    var languages = [Language]()
    
    func reloadData() {
        guard let catalog = catalog, let uiLanguage = catalog.languageWithISO639_3Code("eng") else { return }
        
        let languages = catalog.languages()
        
        let nameByLanguageID = [Int64: String](languages.flatMap { language in
            return catalog.nameForLanguageWithID(language.id, inLanguageWithID: uiLanguage.id).flatMap { (language.id, $0) }
        })
        
        self.uiLanguage = uiLanguage
        self.languages = languages.sorted { language1, language2 in
            if language1.id == uiLanguage.id {
                return true
            }
            if language2.id == uiLanguage.id {
                return false
            }
            return nameByLanguageID[language1.id] ?? "" < nameByLanguageID[language2.id] ?? ""
        }
        
        tableView.reloadData()
    }
    
    func catalogDidUpdate(_ catalog: Catalog) {
        self.catalog = catalog
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

extension LanguagesViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return languages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LanguagesViewController.CellIdentifier, for: indexPath)
        
        let language = languages[indexPath.row]
        if let catalog = catalog, let uiLanguage = uiLanguage {
            cell.textLabel?.text = catalog.nameForLanguageWithID(language.id, inLanguageWithID: uiLanguage.id)
        }
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
}

// MARK: - UITableViewDelegate

extension LanguagesViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let language = languages[indexPath.row]
        if let catalog = catalog, let rootLibraryCollection = catalog.libraryCollectionWithID(language.rootLibraryCollectionID) {
            let viewController = LibraryCollectionViewController(contentController: contentController, libraryCollection: rootLibraryCollection)
            
            navigationController?.pushViewController(viewController, animated: true)
        } else {
            tableView.deselectRow(at: indexPath, animated: false)
        }
    }
    
}
