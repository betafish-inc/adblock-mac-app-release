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
import SafariServices

protocol RulesListVCDelegate: class {
    func onTooManyRulesActiveError()
}

class MainViewController: NSViewController {
    @IBOutlet weak var rightPanel: NSView!
    @IBOutlet weak var warningBox: NSBox!
    @IBOutlet weak var stackView: NSStackView!
    @IBOutlet weak var tabView: NSTabView!
    
    var tabSelector: StackedTabSelectionController?
    
    override func viewDidLoad() {
        tabSelector = StackedTabSelectionController(stackView: stackView, tabView: tabView)
        super.viewDidLoad()
        
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.appMenuBar.initializeAppMenuBar()
        }
        showOrHideExtensionWarning()
    }
    
    private func showOrHideExtensionWarning() {
        Util.fetchExtensionStatus {[weak self] (contentBlockerEnabled, _, error) in
            if error == nil {
               self?.warningBox.animator().isHidden = contentBlockerEnabled
            }
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 3) {
                self?.showOrHideExtensionWarning()
            }
        }
    }
    
    @IBAction func adBlockLogoClicked(_ sender: Any) {
        if !NSWorkspace.shared.openFile(Constants.ADBLOCK_WEBSITE_URL, withApplication: "Safari") {
            guard let url = URL(string: Constants.ADBLOCK_WEBSITE_URL) else { return }
            NSWorkspace.shared.open(url)
        }
    }
    
    @IBAction func activateExtensionButtonClicked(_ sender: Any) {
        SFSafariApplication.showPreferencesForExtension(withIdentifier: Constants.SAFARI_CONTENT_BLOCKER_EXT_IDENTIFIER) { (err) in
            if let error = err {
                SwiftyBeaver.error("safari extension preference error: \(error.localizedDescription)")
            } else {
                SwiftyBeaver.debug("safari extension preference opened")
            }
        }
    }
}

extension MainViewController: RulesListVCDelegate {
    func onTooManyRulesActiveError() {
        let message = NSLocalizedString("filter.lists.too.many.rules", comment: "")
        AlertUtil.toast(in: rightPanel, message: message, toastType: .error)
    }
}
