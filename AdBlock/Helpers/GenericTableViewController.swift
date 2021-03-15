/*******************************************************************************
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see {http://www.gnu.org/licenses/}.
 
 */

import Cocoa

class GenericTableViewController<Cell: GenericTableConforming>: NSViewController, TableController {
    @IBOutlet weak var tableView: NSTableView!
    
    var disposables: [Disposable] = []
    var items: [Cell.ModelType] = [] {
        didSet {
            DispatchQueue.main.async { [weak self] in self?.tableView.reloadData() }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return items.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return Cell.cellHeight
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: Cell.identifier, owner: nil) as? Cell else { return nil }

        cell.model = items[row]
        return cell
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }
    
    deinit {
        disposables.forEach { $0.dispose() }
    }
}

protocol GenericTableConforming: NSTableCellView {
    associatedtype ModelType

    static var identifier: NSUserInterfaceItemIdentifier { get }
    static var cellHeight: CGFloat { get }
    var model: ModelType { get set }
}

protocol TableController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {}
