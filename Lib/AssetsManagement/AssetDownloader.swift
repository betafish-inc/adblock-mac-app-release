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

enum AssetDownloaderStatus {
    case idle
    case downloading
    case completed
    case noChange
    case downloadError
}

extension URL {
    func write(data: Data) {
        // Save filterlist data to file
        SwiftyBeaver.debug("[FILTERLIST_FILE_PATH]: \(path)")
        if FileManager.default.createFile(atPath: path, contents: data, attributes: nil) {
            SwiftyBeaver.debug("[SAVE_UPDATE_FILTERLIST]: Successful")
        } else {
            SwiftyBeaver.error("[ERR_SAVE_UPDATE_FILTERLIST]: Unable to write filter list to file")
        }
    }
}

extension UserPref {
    // Returns true only if the list is enabled
    // AND
    // the list is either not the ADS list OR AA is not enabled
    // (since if the ADS list and AA are both enabled, only AA
    // should be downloaded)
    // AND
    // the list isn't the custom list (static list)
    static func shouldDownloadList(_ identifier: String) -> Bool {
        return UserPref.isFilterListEnabled(identifier: identifier) &&
        (identifier != Constants.ADS_FILTER_LIST_ID || !UserPref.isFilterListEnabled(identifier: Constants.ALLOW_ADS_FILTER_LIST_ID)) &&
        identifier != Constants.CUSTOM_FILTER_LIST_ID
    }
}

class AssetDownloader: NSObject {
    static let shared: AssetDownloader = AssetDownloader()

    var status: AssetDownloaderStatus = .idle

    private override init() {}

    /// Initiate the assets downloader
    func start(_ completion: ((AssetDownloaderStatus) -> Void)? = nil) {
        guard status == .idle else { return }

        status = .downloading
        let localChecksums = (FileManager.default.readJsonFile(at: .assetsChecksumFile) as [String: String]?)?.filter { UserPref.shouldDownloadList($0.key) }
        if localChecksums?.isEmpty ?? true {
            completion?(.noChange)
            status = .idle
            return
        }
        
        var storedError: Error?
        var changed: Bool = false
        let checksumDownloadGroup = DispatchGroup()
        
        localChecksums?.forEach {
            checksumDownloadGroup.enter()
            let identifier = $0.key
            download(identifier) { (error, data, type) in
                if let error = error {
                    storedError = error
                } else if let data = data {
                    changed = true
                    URL.assetURL(asset: identifier, type: type)?.write(data: data)
                }
                checksumDownloadGroup.leave()
            }
        }
        
        checksumDownloadGroup.notify(queue: .main) {
            switch (storedError, changed) {
            case (nil, true):
                completion?(.completed)
            case (nil, false):
                completion?(.noChange)
            default:
                completion?(.downloadError)
            }
            self.status = .idle
        }
    }

    /// Download filter list by id provided in checksums and save it in shared group directory of app
    private func download(_ filterListId: String, completion: @escaping (Error?, Data?, String?) -> Void) {
        guard let url = URL.filterURL(filter: filterListId) else {
            completion(Constants.AdBlockError.invalidApiUrl, nil, nil)
            return
        }

        let formatter = dateFormatter

        func test<T>(response: DataResponse<T>) {
            guard response.result.isSuccess else {
                if response.response?.statusCode == 304 {
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
            completion(nil, response.data, url.pathExtension)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let dateString = formatter.string(from: UserPref.filterListModifiedDate(identifier: filterListId))
        req.setValue(dateString, forHTTPHeaderField: "If-Modified-Since" )
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
    
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM y HH:mm:ss z"
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        return formatter
    }()
}
