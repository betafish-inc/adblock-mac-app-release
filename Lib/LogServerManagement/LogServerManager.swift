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
import Alamofire
import SafariServices

class LogServerManager: NSObject {
    static let shared: LogServerManager = LogServerManager()

    private override init() {}
    
    func recordMessageWithUserID(msg: String) {
        guard let url = URL(string: "\(Constants.LOG_SERVER_URL)" ) else {
            return
        }
        let userInfoPayload = preparePayload()
        var payload: [String: Any] = [:]
        payload["event"] =  msg
        payload["payload"] = userInfoPayload
        SwiftyBeaver.debug("[LOG_REQUEST]: \(url.absoluteString) => Para: \(payload)")
        Alamofire.request(url, method: .post, parameters: payload)
            .validate()
            .response { (response) in
                guard let data = response.data else {
                    SwiftyBeaver.error("Error in sending log message: \(String(describing: response.error))")
                    return
                }
                SwiftyBeaver.debug("[log server response]: \(String(data: data, encoding: .utf8) ?? "")")
        }
    }
    
    private func preparePayload() -> [String: Any] {
        var payload: [String: Any] = [:]
        payload["t"] = ""
        let locale = NSLocale.autoupdatingCurrent
        payload["u"] = PingDataManager.shared.generateOrGetUserId()
        payload["ov"] = ProcessInfo().operatingSystemVersionString // operating system version
        payload["f"] = "MA" // flavor
        payload["l"] = locale.languageCode!   // user language
        
        return payload
    }

}
