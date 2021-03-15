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
import SwiftyBeaver

extension NSStoryboard {
    class func debugVC() -> DebugViewController {
        // swiftlint:disable force_cast
        let viewController = mainStoryboard.instantiateController(withIdentifier: "DebugVC") as! DebugViewController
        viewController.viewModel = DebugViewModel()
        return viewController
    }
}

extension String {
    static let debugInfoDidChangeKey = "debug.info.did.change.key"
}

class DebugViewController: NSViewController {
    @IBOutlet weak var debugTextView: NSTextView!
    
    fileprivate var viewModel: DebugViewModelType? {
        didSet {
            disposables[.debugInfoDidChangeKey]?.dispose()
            disposables[.debugInfoDidChangeKey] = viewModel?.debugInfo.didChange.addHandler(target: self, handler: DebugViewController .debugInfoDidChange)
        }
    }
    private var disposables: [String: Disposable] = [:]
    
    private func debugInfoDidChange(change: (String?, String?)) {
        let (_, newValue) = change
        debugTextView.string = newValue ?? ""
    }
    
    override func viewDidAppear() {
        viewModel?.debugModelDidChange(DebugInfo())
    }
    
    deinit {
        disposables.forEach { $0.1.dispose() }
    }
}
