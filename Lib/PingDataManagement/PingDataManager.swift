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

class PingDataManager: NSObject {
    static let shared: PingDataManager = PingDataManager()

    let alphanums = ["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z","0","1","2","3","4","5","6","7","8","9"]

    private override init() {}
    
    func start() {
        schedulePingData()
    }
    
    private func schedulePingData() {
        
        let pingDate = nextScheduleDate()
        let currentDate = Date()
        if currentDate >= pingDate {
            sendPingData()
        }
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + (60 * 60)) {
            self.schedulePingData()
        }
    }
    
    func sendPingData() {
        UserPref.incrementTotalPings()
        guard let url = URL(string: "\(Constants.PING_URL)" ) else {
            return
        }
        let pingData = preparePingData()
        SwiftyBeaver.debug("[PING_DATA_REQUEST]: \(url.absoluteString) => Para: \(pingData)")
        Alamofire.request(url, method: .post, parameters: pingData)
            .validate()
            .response { (response) in
                guard let data = response.data else {
                    SwiftyBeaver.error("Error in sending ping data: \(String(describing: response.error))")
                    return
                }
                SwiftyBeaver.debug("[PING_DATA_RESPONSE]: \(String(data: data, encoding: .utf8) ?? "")")
                UserPref.setLastPingDate(Date())
        }
    }
    
    private func preparePingData() -> [String: Any] {
        var pingData: [String: Any] = [:]
        pingData["cmd"] = "ping"
        let locale = NSLocale.autoupdatingCurrent
        pingData["n"] = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
        pingData["v"] = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
        pingData["u"] = generateOrGetUserId()   // user id
        pingData["o"] = UserPref.operatingSystem()  // operating system
        pingData["ov"] = ProcessInfo().operatingSystemVersionString // operating system version
        pingData["f"] = "S" // browser flavor
        pingData["bv"] = UserPref.safariVersion()   // TODO browser version
        pingData["l"] = locale.languageCode!   // user language
        pingData["aa"] = FilterListManager.shared.isEnabled(filterListId: Constants.ALLOW_ADS_FILTER_LIST_ID) ? 1 : 0
        
        return pingData
    }
    
    private func generateOrGetUserId() -> String {
        if let userId = UserPref.userId() {
            return userId
        }
        let time_suffix = String(Int(Double(floor(NSDate().timeIntervalSince1970 * 1000)).truncatingRemainder(dividingBy: 1e8))) // 8 digits from end of timestamp
        var result = ""
        for _ in 0..<8 {
            let j = Int(arc4random_uniform(UInt32(alphanums.count)))
            result = result + alphanums[j]
        }
        let newUserID = result + time_suffix
        UserPref.setUserId(newUserID)
        return newUserID
    }
    
    private func nextScheduleDate() -> Date {
        let totalPings = UserPref.totalPings()
        var delayHours = 1
        if totalPings == 0 {
            delayHours = 1
        } else if totalPings < 8 {
            delayHours = 24
        } else {
            delayHours = 24 * 7
        }
        
        let lastPingDate = UserPref.lastPingDate() ?? Date()
        return lastPingDate + TimeInterval(60 * 60 * delayHours)
    }
}
