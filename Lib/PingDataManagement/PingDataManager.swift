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

    func pingDataIfNecessary() {
        let pingDate = nextScheduleDate()
        let currentDate = Date()
        if currentDate >= pingDate {
            sendPingData()
        }
    }

    private func schedulePingData() {
        let pingDate = nextScheduleDate()
        SwiftyBeaver.debug("[next ping date]: \(pingDate)")
        let currentDate = Date()
        if currentDate >= pingDate {
            sendPingData()
        }
        SwiftyBeaver.debug("[self.getNextPing]: \(self.getNextPing())")
        DispatchQueue.global(qos: .background).asyncAfter(deadline: self.getNextPing()) {
            self.schedulePingData()
        }
    }
    
    func sendPingData() {
        UserPref.incrementTotalPings()
        UserPref.setLastPingDate(Date())
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
        }
    }
    
    private func preparePingData() -> [String: Any] {
        self.setSafariVersion()
        var pingData: [String: Any] = [:]
        pingData["cmd"] = "ping"
        let locale = NSLocale.autoupdatingCurrent
        pingData["n"] = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
        pingData["v"] = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
        pingData["u"] = generateOrGetUserId()   // user id
        pingData["ov"] = ProcessInfo().operatingSystemVersionString // operating system version
        pingData["f"] = "MA" // flavor
        pingData["o"] = "Mac OS X" // OS
        pingData["bv"] = UserPref.safariVersion()
        pingData["l"] = locale.languageCode!   // user language
        pingData["aa"] = FilterListManager.shared.isEnabled(filterListId: Constants.ALLOW_ADS_FILTER_LIST_ID) ? 1 : 0
        pingData["lol"] = UserPref.isLaunchAppOnUserLogin() ? 1 : 0
        
        return pingData
    }
    
    func generateOrGetUserId() -> String {
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
        var delayHours = 1.0
        if totalPings == 0 {
            return Date() - TimeInterval(1000) // ping now
        } else if totalPings == 1 {
             delayHours = 0.1 // 6 minutes
        } else if totalPings == 2 {
            delayHours = 1 // 1 hour
        } else if totalPings < 8 {
            delayHours = 24 // 24 hours
        } else {
            delayHours = 24 * 7 // 1 week
        }

        let lastPingDate = UserPref.lastPingDate() ?? Date()
        let nextScheduleDate = lastPingDate + TimeInterval(60 * 60 * delayHours)
        SwiftyBeaver.debug("[nextScheduleDate totalPings]: \(totalPings) delayHours: \(delayHours) lastpingDate: \(lastPingDate) nextScheduleDate: \(nextScheduleDate)")
        return nextScheduleDate
    }

    private func getNextPing() -> DispatchTime {
        let totalPings = UserPref.totalPings()
        var delayHours = DispatchTime.now()
        var secondsSinceLastPing = 0.0
        if UserPref.lastPingDate() != nil {
            secondsSinceLastPing = (UserPref.lastPingDate()?.timeIntervalSinceNow)!
        }
        if totalPings == 1 {
            delayHours =  delayHours + DispatchTimeInterval.seconds(6 * 60) // 6 minutes
        } else if totalPings == 2 {
            delayHours =  delayHours + DispatchTimeInterval.seconds(60 * 60) // 1 hour
        } else if ((totalPings > 2) && (totalPings <= 8)) {
            delayHours = delayHours + DispatchTimeInterval.seconds(60 * 60 * 24) // 1 day
        } else {
            delayHours = delayHours + DispatchTimeInterval.seconds(60 * 60 * 24 * 7) // 1 week
        }
        // if set, 'secondsSinceLastPing' will be negative, so we add a negative value to correctly
        // calculate the delay hours
        delayHours = delayHours + DispatchTimeInterval.seconds(Int(secondsSinceLastPing))
        SwiftyBeaver.debug("getNextPing()  totalPings]: \(totalPings) [delayHours]: \(delayHours)) [secondsSinceLastPing]: \(secondsSinceLastPing)")
        return delayHours
    }

    private func setSafariVersion() {
        var safarVersion = "unk"
        var safariPath = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: "com.apple.Safari")
        if (safariPath != nil) {
            safariPath = safariPath! + "/Contents/Info.plist"
            if FileManager.default.isReadableFile(atPath: safariPath!) {
                let myDict = NSDictionary(contentsOfFile: safariPath!)
                safarVersion = myDict!["CFBundleShortVersionString"] as! String
                SwiftyBeaver.debug("safari version \(safarVersion)")
            }
        }
        UserPref.setSafariVersion(safarVersion)
    }
}
