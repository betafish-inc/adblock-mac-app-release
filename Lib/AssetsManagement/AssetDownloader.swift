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
        self.beginDownloadV2(localChecksums) { (error) in
            if let _ = error {
                self.status = .downloadError
                completion?(.downloadError)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                    self.status = .idle
                })
                return
            }
            self.status = .completed
            completion?(.completed)
            self.status = .idle
        }
    }

    /// Initiate downloading of filter lists and recursively download it
    ///
    /// - Parameters:
    ///   - checksums: updated checksums data
    ///   - completion: completion handler
    private func beginDownloadV2(_ checksums: [String: String]?, completion: @escaping (Error?)->Void) {
        guard let checksums = checksums else {
            SwiftyBeaver.debug("[BEGIN_DOWNLOAD]: Nothing to download...")
            completion(nil)
            return
        }
        let checksumDownloadGroup = DispatchGroup()
        var idx = 0
        let total = checksums.count
        var storedError: Error? = nil
        for (key, _) in checksums {
            checksumDownloadGroup.enter()
            idx = idx + 1
            SwiftyBeaver.debug("[BEGIN_DOWNLOAD]: Initiate download... \(key) [\(idx) / \(total)]")
            self.download(key, completion: { (error, data) in
                if let error = error {
                    storedError = error
                } else {
                    // Save filterlist data to json file
                    let thirdPartyDirUrl = Constants.AssetsUrls.thirdPartyFolder
                    FileManager.default.createDirectoryIfNotExists(thirdPartyDirUrl, withIntermediateDirectories: true)
                    
                    let filterListFileUrl = thirdPartyDirUrl?.appendingPathComponent("\(key).json")
                    SwiftyBeaver.debug("[FILTERLIST_FILE_PATH]: \(filterListFileUrl?.path ?? "NULL")")
                    if FileManager.default.createFile(atPath: (filterListFileUrl?.path)!, contents: data, attributes: nil) {
                        SwiftyBeaver.debug("[UPDATE_FILTERLIST]: Successful")
                    } else {
                        SwiftyBeaver.error("[ERR_UPDATE_FILTERLIST]: Unable to write checksums to file")
                    }
                }
                checksumDownloadGroup.leave()
            })
        }
        checksumDownloadGroup.notify(queue: .main) {
            SwiftyBeaver.debug("[BEGIN_DOWNLOAD]: Assets downloaded...")
            completion(storedError)
        }
    }
    
    /// Download filter list by id provided in checksums and save it in shared group directory of app
    ///
    /// - Parameters:
    ///   - filterListId: filter list id
    ///   - completion: completion handler
    private func download(_ filterListId: String, completion: @escaping (Error?, Data?) -> Void) {
        SwiftyBeaver.debug("[DOWNLOAD]: Downloading... \(filterListId)")
        let urlString = getURLById(filterListId: filterListId)
        guard let url = URL(string: urlString ) else {
            completion(Constants.AdBlockError.invalidApiUrl, nil)
            return
        }
        
        SwiftyBeaver.debug("[DOWNLOAD_REQUEST]: \(url.absoluteString)")
        Alamofire.request(url)
            .validate()
            .responseJSON { (response) in
                guard response.result.isSuccess else {
                    SwiftyBeaver.error("Error while downloading filterlist: \(String(describing: response.result.error))")
                    completion(response.result.error, nil)
                    return
                }
                
                let bcf = ByteCountFormatter()
                bcf.allowedUnits = [.useMB] // optional: restricts the units to MB only
                bcf.countStyle = .file
                let filterDataSize = bcf.string(fromByteCount: Int64(response.data?.count ?? 0))
                SwiftyBeaver.debug("[DOWNLOAD]: Downloaded... \(filterListId) (\(filterDataSize))")
                completion(nil, response.data)
        }
    }

    private func getURLById(filterListId: String) -> String {
        if (filterListId == "easylist_content_blocker") {
            //return "https://cdn.adblockcdn.com/filters/easylist.json"
            return "https://ping.ublock.org/api/filterlist/easylist_content_blocker"
        } else if (filterListId == "easylist_exceptionrules_content_blocker") {
            //return "https://cdn.adblockcdn.com/filters/easylist_aa.json"
            return "https://ping.ublock.org/api/filterlist/easylist_exceptionrules_content_blocker"
        }
        return ""
    }
}
