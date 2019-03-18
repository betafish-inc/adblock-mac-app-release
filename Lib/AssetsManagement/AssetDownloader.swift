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
import Alamofire
import SwiftyBeaver
import SafariServices

enum AssetDownloaderStatus {
    case idle
    case downloading
    case completed
    case noChange
    case downloadError
}

class AssetDownloader: NSObject {
    static let shared: AssetDownloader = AssetDownloader()

    var status: AssetDownloaderStatus = .idle

    private override init() {}

    /// Initiate the assets downloader
    func start(_ completion: ((AssetDownloaderStatus) -> Void)? = nil) {
        if self.status != .idle {
            return
        }

        self.status = .downloading
        let localChecksums: [String: String]? = FileManager.default.readJsonFile(at: Constants.AssetsUrls.assetsChecksumUrl)
        self.beginDownloadV2(localChecksums) { (error, changed) in
            if let _ = error {
                self.status = .downloadError
                completion?(.downloadError)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                    self.status = .idle
                })
                return
            }

            if changed == true {
                self.status = .completed
                completion?(.completed)
                self.status = .idle
            } else {
                self.status = .completed
                completion?(.noChange)
                self.status = .idle
            }
        }
    }

    /// Initiate downloading of filter lists and recursively download it
    ///
    /// - Parameters:
    ///   - checksums: updated checksums data
    ///   - completion: completion handler
    private func beginDownloadV2(_ checksums: [String: String]?, completion: @escaping (Error?, Bool?)->Void) {
        guard let checksums = checksums else {
            SwiftyBeaver.debug("[BEGIN_DOWNLOAD]: Nothing to download...")
            completion(nil, false)
            return
        }
        let checksumDownloadGroup = DispatchGroup()
        var idx = 0
        let total = checksums.count
        var storedError: Error? = nil
        var changed: Bool = false
        for (key, _) in checksums {
            let enabled = UserPref.isFilterListEnabled(identifier: key)
            if (!enabled) {
                continue
            }
            // Don't download the "easylist_content_blocker", if its not necessary
            // Since the "easylist_exceptionrules_content_blocker" file contains
            // the same rules (+AA rules) as the "easylist_content_blocker" file
            // only download the "easylist_exceptionrules_content_blocker", if
            // user has it enabled.
            //
            if (key == Constants.ADS_FILTER_LIST_ID &&
                UserPref.isFilterListEnabled(identifier: Constants.ALLOW_ADS_FILTER_LIST_ID)) || key == Constants.CUSTOM_FILTER_LIST_ID {
                continue
            }
            checksumDownloadGroup.enter()
            idx = idx + 1
            SwiftyBeaver.debug("[BEGIN_DOWNLOAD]: Initiate download... \(key) [\(idx) / \(total)]")
            self.download(key, completion: { (error, data, type) in
                if let error = error {
                    storedError = error
                } else if data != nil {
                    changed = true

                    // Save filterlist data to file
                    let thirdPartyDirUrl = Constants.AssetsUrls.thirdPartyFolder
                    FileManager.default.createDirectoryIfNotExists(thirdPartyDirUrl, withIntermediateDirectories: true)
                    var updatedKey = key
                    if SFSafariServicesAvailable(SFSafariServicesVersion.version11_0) && type == "json" {
                        updatedKey = key + "_v2";
                    }
                    let filterListFileUrl = thirdPartyDirUrl?.appendingPathComponent("\(updatedKey).\(type ?? "txt")")
                    SwiftyBeaver.debug("[FILTERLIST_FILE_PATH]: \(filterListFileUrl?.path ?? "NULL")")
                    if let filterListFilePath = filterListFileUrl?.path, FileManager.default.createFile(atPath: filterListFilePath, contents: data, attributes: nil) {
                        SwiftyBeaver.debug("[SAVE_UPDATE_FILTERLIST]: Successful")
                    } else {
                        SwiftyBeaver.error("[ERR_SAVE_UPDATE_FILTERLIST]: Unable to write filter list to file")
                    }
                }
                checksumDownloadGroup.leave()
            })
        }
        checksumDownloadGroup.notify(queue: .main) {
            SwiftyBeaver.debug("[BEGIN_DOWNLOAD]: Assets downloaded...")
            completion(storedError, changed)
        }
    }

    /// Download filter list by id provided in checksums and save it in shared group directory of app
    ///
    /// - Parameters:
    ///   - filterListId: filter list id
    ///   - completion: completion handler
    private func download(_ filterListId: String, completion: @escaping (Error?, Data?, String?) -> Void) {
        SwiftyBeaver.debug("[DOWNLOAD]: Downloading... \(filterListId)")
        let urlString = getURLById(filterListId: filterListId)
        guard let url = URL(string: urlString ) else {
            completion(Constants.AdBlockError.invalidApiUrl, nil, nil)
            return
        }

        var formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM y HH:mm:ss z"
        formatter.timeZone = TimeZone(abbreviation: "GMT")

        func test<T>(response: DataResponse<T>) {
            guard response.result.isSuccess else {
                if response.response?.statusCode == 304 {
                    SwiftyBeaver.debug("[DOWNLOAD] Filter list not modified... \(filterListId)")
                    completion(nil, nil, nil)
                } else {
                    SwiftyBeaver.error("Error while downloading filterlist: \(String(describing: response.result.error))")
                    completion(response.result.error, nil, nil)
                }
                return
            }

            let responseHeaders = response.response?.allHeaderFields
            let lastModified = responseHeaders?["Last-Modified"] as? String
            let modifiedDate = formatter.date(from: lastModified ?? Constants.DATE_STRING_A_WHILE_AGO) ?? Date(timeIntervalSince1970: 0)
            UserPref.setFilterListModifiedDate(identifier: filterListId, date: modifiedDate)
            SwiftyBeaver.debug("[DOWNLOAD]: Last modified... \(filterListId) \(modifiedDate)")

            let bcf = ByteCountFormatter()
            bcf.allowedUnits = [.useMB] // optional: restricts the units to MB only
            bcf.countStyle = .file
            let filterDataSize = bcf.string(fromByteCount: Int64(response.data?.count ?? 0))
            SwiftyBeaver.debug("[DOWNLOAD]: Downloaded... \(filterListId) (\(filterDataSize))")
            completion(nil, response.data, url.pathExtension)
        }

        SwiftyBeaver.debug("[DOWNLOAD_REQUEST]: \(url.absoluteString)")

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let dateString = formatter.string(from: UserPref.filterListModifiedDate(identifier: filterListId))
        req.setValue(dateString, forHTTPHeaderField:"If-Modified-Since" )
        req.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData

        if url.pathExtension == "json" {
            Alamofire.request(req)
                .validate()
                .responseJSON(completionHandler: test)
        } else {
            Alamofire.request(req)
                .validate()
                .responseString(completionHandler: test)
        }
    }

    private func getURLById(filterListId: String) -> String {
        if (filterListId == Constants.ADS_FILTER_LIST_ID && SFSafariServicesAvailable(SFSafariServicesVersion.version11_0)) {
            return "https://cdn.adblockcdn.com/filters/easylist_content_blocker_v2.json"
        } else if (filterListId == Constants.ALLOW_ADS_FILTER_LIST_ID  && SFSafariServicesAvailable(SFSafariServicesVersion.version11_0)) {
            return "https://cdn.adblockcdn.com/filters/easylist+exceptionrules_content_blocker_v2.json"
        } else if (filterListId == Constants.ADS_FILTER_LIST_ID && !SFSafariServicesAvailable(SFSafariServicesVersion.version11_0)) {
            return "https://cdn.adblockcdn.com/filters/easylist_content_blocker.json"
        } else if (filterListId == Constants.ALLOW_ADS_FILTER_LIST_ID && !SFSafariServicesAvailable(SFSafariServicesVersion.version11_0)) {
            return "https://cdn.adblockcdn.com/filters/easylist+exceptionrules_content_blocker.json"
        } else if (filterListId == Constants.ANTI_CIRCUMVENTION_LIST_ID) {
            return "https://easylist-downloads.adblockplus.org/abp-filters-anti-cv.txt"
        } else if (filterListId == Constants.ADVANCE_FILTER_LIST_ID) {
            return "https://cdn.adblockcdn.com/filters/advance_hiding.txt"
        }
        return ""
    }
}
