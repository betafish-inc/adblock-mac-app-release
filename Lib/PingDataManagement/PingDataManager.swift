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

    let alphanums = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p",
                     "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "0", "1", "2", "3", "4", "5",
                     "6", "7", "8", "9"]

    private override init() {}
    
    func start() {
        schedulePingData()
    }

    func pingDataIfNecessary() {
        let pingDate = nextScheduleDate()
        let currentDate = Date()
        if (currentDate >= pingDate) && !UserPref.isFileAccessBlocked {
            sendPingData()
        }
    }

    private func schedulePingData() {
        if !UserPref.isFileAccessBlocked {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: getNextPing()) {[weak self] in
                guard let strongSelf = self else { return }
                strongSelf.pingDataIfNecessary()
                var delay = DispatchTime.now()
                delay = delay + DispatchTimeInterval.seconds(60 * 60) // reschedule ourselves in 60 minutes
                DispatchQueue.global(qos: .background).asyncAfter(deadline: delay) {
                    self?.schedulePingData()
                }
            }
        }
    }
    
    func sendPingData() {
        let updatedPingCount = UserPref.incrementTotalPings()
        let updatedPingDate = UserPref.setLastPingDate(Date())
        if !(updatedPingCount && updatedPingDate) {
            UserPref.setFileAccessBlocked(true)
            return
        }
        guard let url = URL(string: "\(Constants.PING_URL)" ) else { return }
        
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
        var pingData: [String: Any] = [:]
        let locale = NSLocale.autoupdatingCurrent
        
        setSafariVersion()
        setOperatingSystemVersion()
        
        pingData["cmd"] = "ping"
        pingData["n"] = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String
        pingData["v"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        pingData["u"] = generateOrGetUserId()
        pingData["ov"] = UserPref.operatingSystemVersion
        pingData["f"] = "MA" // flavor
        pingData["o"] = "Mac OS X" // OS
        pingData["bv"] = UserPref.safariVersion
        pingData["l"] = locale.languageCode ?? locale.identifier
        pingData["aa"] = FilterListManager.shared.isEnabled(filterListId: Constants.ALLOW_ADS_FILTER_LIST_ID) ? 1 : 0
             
        return pingData
    }
    
    func generateOrGetUserId() -> String {
        if let userId = UserPref.userId { return userId }
        
        let time_suffix = String(Int(Double(floor(NSDate().timeIntervalSince1970 * 1000)).truncatingRemainder(dividingBy: 1e8))) // 8 digits from end of timestamp
        var result = ""
        for _ in 0..<8 {
            let randIndex = Int(arc4random_uniform(UInt32(alphanums.count)))
            result += alphanums[randIndex]
        }
        let newUserID = result + time_suffix
        UserPref.setUserId(newUserID)
        return newUserID
    }
    
    private func nextScheduleDate() -> Date {
        let totalPings = UserPref.totalPings
        var delayHours: Double
        switch totalPings {
        case 0:
            return Date() - TimeInterval(1000) // ping now
        case 1:
             delayHours = 0.1 // 6 minutes
        case 2:
            delayHours = 1 // 1 hour
        case 3...8:
            delayHours = 24 // 24 hours
        default:
            delayHours = 24 * 7 // 1 week
        }

        let lastPingDate = UserPref.lastPingDate ?? Date()
        let scheduledDate = lastPingDate + TimeInterval(60 * 60 * delayHours)
        SwiftyBeaver.debug("[nextScheduleDate totalPings]: \(totalPings) delayHours: \(delayHours) lastpingDate: \(lastPingDate) nextScheduleDate: \(scheduledDate)")
        return scheduledDate
    }

    private func getNextPing() -> DispatchTime {
        let scheduledDate = nextScheduleDate()
        let delayHours = DispatchTime.now() + scheduledDate.timeIntervalSinceNow
        SwiftyBeaver.debug("getNextPing() delayHours: \(delayHours)")
        return delayHours
    }

    private func setSafariVersion() {
        var safariVersion = "unk"
        if let safariPath = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: "com.apple.Safari") {
            let safariPathInfoPath = "\(safariPath)/Contents/Info.plist"
            if FileManager.default.isReadableFile(atPath: safariPathInfoPath), let myDict = NSDictionary(contentsOfFile: safariPathInfoPath) {
                safariVersion = myDict["CFBundleShortVersionString"] as? String ?? "unk"
            }
        }
        UserPref.setSafariVersion(safariVersion)
    }

    private func setOperatingSystemVersion() {
        let majorVersion = ProcessInfo().operatingSystemVersion.majorVersion
        let minorVersion = ProcessInfo().operatingSystemVersion.minorVersion
        let patchVersion = ProcessInfo().operatingSystemVersion.patchVersion
        UserPref.setOperatingSystemVersion("\(majorVersion).\(minorVersion).\(patchVersion)")
    }
}
