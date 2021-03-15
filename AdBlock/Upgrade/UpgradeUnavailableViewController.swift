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

import Foundation
import SafariServices

class UpgradeUnavailableViewController: NSViewController {
    @IBOutlet weak var upgradeUnavailableTitle: NSTextField!
    @IBOutlet weak var upgradeUnavailableDescription: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var title = ""
        var description = ""
        
        if !SFSafariServicesAvailable(SFSafariServicesVersion.version11_0) {
            title = NSLocalizedString("upgrade.unavailable.version.title", comment: "")
            description = NSLocalizedString("upgrade.unavailable.version.desc", comment: "")
        } else {
            title = NSLocalizedString("upgrade.unavailable.unauthorized.title", comment: "")
            description = NSLocalizedString("upgrade.unavailable.unauthorized.desc", comment: "")
        }
        upgradeUnavailableTitle.stringValue = title
        upgradeUnavailableDescription.stringValue = description
    }
}
