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
import SafariServices
import SwiftyBeaver

class IntroViewController: NSViewController {
    @IBAction func launchClick(_ sender: NSButton) {
        SFSafariApplication.showPreferencesForExtension(withIdentifier: Constants.SAFARI_CONTENT_BLOCKER_EXT_IDENTIFIER) { (error) in
            if let error = error {
                SwiftyBeaver.error("safari extension preference error: \(error.localizedDescription)")
            } else {
                SwiftyBeaver.debug("safari extension preference opened")
            }
        }
    }
}
