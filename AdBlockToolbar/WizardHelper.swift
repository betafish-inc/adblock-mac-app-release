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

extension URL {
    static let whitelistURL = Bundle.main.url(forResource: "whitelist_ui", withExtension: "js")
    static let jqueryUiURL = Bundle.main.url(forResource: "jquery/jquery-ui.min", withExtension: "js")
    static let jqueryURL = Bundle.main.url(forResource: "jquery/jquery-2.1.1.min", withExtension: "js")
    static let jqueryUiCSSURL = Bundle.main.url(forResource: "jquery/css/jquery-ui", withExtension: "css")
    static let jqueryOverrideCSSURL = Bundle.main.url(forResource: "jquery/css/override-page", withExtension: "css")
    
    func readFile() -> String {
        return (try? String.init(contentsOf: self)) ?? ""
    }
}

class WizardHelper: NSObject {
    static func injectWizard() {
        let whitelistText = URL.whitelistURL?.readFile() ?? ""
        let jqueryUiText = URL.jqueryUiURL?.readFile() ?? ""
        let jqueryText = URL.jqueryURL?.readFile() ?? ""
        let jqueryUiCSSText = URL.jqueryUiCSSURL?.readFile() ?? ""
        let jqueryOverrideCSSText = URL.jqueryOverrideCSSURL?.readFile() ?? ""
        
        let locale = NSLocale.autoupdatingCurrent.languageCode!
        let localeFile = "_locales/\(locale)/messages"
        var localeFileURL = Bundle.main.url(forResource: localeFile, withExtension: "json")
        if !FileManager.default.fileExists(atPath: (localeFileURL?.absoluteString)!) {
            localeFileURL = Bundle.main.url(forResource: "_locales/en/messages", withExtension: "json")
        }
        let localeMessageText = localeFileURL?.readFile() ?? ""
        
        SFSafariApplication.getActiveWindow { (window) in
            window?.getActiveTab { (tab) in
                tab?.getActivePage { (page) in
                    page?.dispatchMessageToScript(withName: "localeMessages", userInfo: ["localeMessages": localeMessageText, "topOnly": true ])
                    page?.dispatchMessageToScript(withName: "addCSS", userInfo: ["addCSS": jqueryUiCSSText, "topOnly": true ])
                    page?.dispatchMessageToScript(withName: "addCSS", userInfo: ["addCSS": jqueryOverrideCSSText, "topOnly": true ])
                    page?.dispatchMessageToScript(withName: "injectScript", userInfo: ["evalScript": jqueryText, "topOnly": true ])
                    page?.dispatchMessageToScript(withName: "injectScript", userInfo: ["evalScript": jqueryUiText, "topOnly": true ])
                    page?.dispatchMessageToScript(withName: "injectScript", userInfo: ["evalScript": whitelistText, "topOnly": true ])
                }
            }
        }
    }
}
