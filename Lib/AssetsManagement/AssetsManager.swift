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
// swiftlint:disable shorthand_operator

import Cocoa
import SafariServices
import SwiftyBeaver

enum AssetsManagerStatus {
    case idle
    case filterUpdateStarted
    case filterUpdateCompleted
    case filterUpdateCompletedNoChange
    case filterUpdateError
    case mergeRulesStarted
    case mergeRulesCompleted
    case mergeRulesError
}

class AssetsManager: NSObject {
    static let shared: AssetsManager = AssetsManager()
    
    var status: Observable<AssetsManagerStatus> = Observable(.idle)
    
    private override init() {
        super.init()        
    }
    
    func initialize() {
        copyAssetsToGroupStorageIfNotExists()
        scheduleNextDownload()
    }
    
    private func copyAssetsToGroupStorageIfNotExists() {
        guard let destAssetsDirUrl = URL.assetsFolder else { return }
        if !FileManager.default.fileExists(atPath: destAssetsDirUrl.path) {
            guard let srcAssetsDirUrl = Bundle.main.url(forResource: "Assets", withExtension: nil) else { return }
            do {
                try FileManager.default.copyItem(at: srcAssetsDirUrl, to: destAssetsDirUrl)
                UserPref.setFilterListsUpdatedDate(Constants.BUNDLED_FILTER_LISTS_UPDATE_DATE)
                UserPref.setBundledAssetsDefaultStateUpdated(false)
            } catch {
                SwiftyBeaver.error(error)
            }
        } else {
            guard let destThirdPartyDirPath = URL.thirdPartyFolder,
                let srcThirdPartyDirUrl = Bundle.main.url(forResource: "Assets/ThirdParty", withExtension: nil),
                let sourceThirdPartyFilePaths = try? FileManager.default.contentsOfDirectory(atPath: srcThirdPartyDirUrl.path)
                else { return }
            var missingFile = false
            for filePath in sourceThirdPartyFilePaths {
                let destFileUrl = destThirdPartyDirPath.appendingPathComponent(filePath)
                if !FileManager.default.fileExists(atPath: destFileUrl.path) {
                    let srcFileUrl = srcThirdPartyDirUrl.appendingPathComponent(filePath)
                    do {
                        try FileManager.default.copyItem(at: srcFileUrl, to: destFileUrl)
                        missingFile = true
                    } catch {
                        SwiftyBeaver.error(error)
                    }
                }
            }
            if missingFile {
                guard let srcAssetsDirUrl = Bundle.main.url(forResource: "Assets", withExtension: nil) else { return }
                let srcAssetChecksumUrl = srcAssetsDirUrl.appendingPathComponent("assets_checksum.json")
                guard let destAssetChecksumUrl = URL.assetsChecksumFile else { return }
                do {
                    try FileManager.default.removeItem(at: destAssetChecksumUrl)
                    try FileManager.default.copyItem(at: srcAssetChecksumUrl, to: destAssetChecksumUrl)
                } catch {
                    SwiftyBeaver.error(error)
                }
                UserPref.setFilterListsUpdatedDate(Constants.BUNDLED_FILTER_LISTS_UPDATE_DATE)
                UserPref.setBundledAssetsDefaultStateUpdated(false)
            }
        }
    }

    func requestFilterUpdate() {
        guard status.get() == .idle else { return }
        
        status.set(newValue: .filterUpdateStarted)
        
        AssetDownloader.shared.start {[weak self] (downloadStatus) in
            guard let strongSelf = self else { return }
            switch downloadStatus {
            case .completed:
                strongSelf.status.set(newValue: .filterUpdateCompleted)
                strongSelf.status.set(newValue: .idle)
                strongSelf.requestMerge()
            case .noChange:
                strongSelf.status.set(newValue: .filterUpdateCompletedNoChange)
                strongSelf.status.set(newValue: .idle)
                UserPref.setFilterListsUpdatedDate(Date())
            default:
                strongSelf.status.set(newValue: .filterUpdateError)
                strongSelf.status.set(newValue: .idle)
            }
        }
    }
    
    func requestMerge() {
        guard status.get() == .idle else { return }
        
        status.set(newValue: .mergeRulesStarted)
        
        let mergeGroup = DispatchGroup()
        var contentBlockingMergeStatus: AssetMergerStatus = .merging
        
        mergeGroup.enter()
        AssetMerger.shared.start { (mergeStatus) in
            SFContentBlockerManager.reloadContentBlocker(withIdentifier: Constants.SAFARI_CONTENT_BLOCKER_EXT_IDENTIFIER) { (error) in
                if let error = error {
                    SwiftyBeaver.error("[ASSETS_MANAGER]: Error in reloading content blocker \(error)")
                } else {
                    SwiftyBeaver.debug("[ASSETS_MANAGER]: Content blocker reloaded successfully")
                }
                contentBlockingMergeStatus = mergeStatus
                mergeGroup.leave()
            }
        }
        
        mergeGroup.enter()
        FilterListsText.shared.rebuild { mergeGroup.leave() }
        
        mergeGroup.notify(queue: .main) {[weak self] in
            guard let strongSelf = self else { return }
            strongSelf.status.set(newValue: contentBlockingMergeStatus == .completed ? .mergeRulesCompleted : .mergeRulesError)
            strongSelf.status.set(newValue: .idle)
            UserPref.setFilterListsUpdatedDate(Date())
        }
    }

    func downloadDataIfNecessary() {
        let nextDate = nextScheduleDate()
        let currentDate = Date()
        if currentDate >= nextDate {
            AssetsManager.shared.requestFilterUpdate()
        }
    }

    // computes the next download time based on the last time the content blocker files were downloaded.
    private func nextScheduleDate() -> Date {
        let lastFilterListsUpdatedDate = UserPref.filterListsUpdatedDate
        // Since we're using the |filterListsUpdatedDate| from the User Preferences file,
        // check to see the file is writable, if not, send a msg
        if let userPrefPath = URL.userPreferenceFile?.path, !FileManager.default.isWritableFile(atPath: userPrefPath) {
            LogServerManager.recordMessageWithUserID(msg: "user_preference_file_not_writable")
        }
        var delay: TimeInterval = 0
        if lastFilterListsUpdatedDate == Constants.BUNDLED_FILTER_LISTS_UPDATE_DATE {
            delay = TimeInterval(60 * 60) // 1 hour after the last updated date bundled with the app
        } else {
            delay = TimeInterval(Constants.FILTER_LISTS_UPDATE_INTERVAL_SECONDS)
        }
        let nextScheduleDate = lastFilterListsUpdatedDate + delay
        SwiftyBeaver.debug("[ASSETS_MANAGER]: nextScheduleDate: \(nextScheduleDate) ")
        return nextScheduleDate
    }

    // runs an async task at the appropriate time - approximately once a day
    private func scheduleNextDownload() {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: getNextDownloadTime()) {[weak self] in
            guard let strongSelf = self else { return }
            strongSelf.downloadDataIfNecessary()
            var delay = DispatchTime.now()
            delay = delay + DispatchTimeInterval.seconds(60 * 60) // reschedule ourselves in 60 minutes
            DispatchQueue.global(qos: .background).asyncAfter(deadline: delay) {
                self?.scheduleNextDownload()
            }
        }
    }

    // computes the next download time based on the current time, and the last time the content blocker files were downloaded.
    private func getNextDownloadTime() -> DispatchTime {
        let scheduledDate = nextScheduleDate()
        let delayHours = DispatchTime.now() + scheduledDate.timeIntervalSinceNow
        SwiftyBeaver.debug("[ASSETS_MANAGER]: delayHours: \(delayHours) ")
        
        return delayHours
    }
}
