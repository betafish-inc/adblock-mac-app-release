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
import SwiftyBeaver

public struct DebugLog {
    static func configure() {
        if Constants.DEBUG_LOG_ENABLED && SwiftyBeaver.countDestinations() == 0 {
            let console = ConsoleDestination()
            console.minLevel = .verbose
            SwiftyBeaver.addDestination(console)
            if let assetsPath = URL.assetsFolder?.path, FileManager.default.fileExists(atPath: assetsPath) {
                FileManager.default.createDirectoryIfNotExists(.logFolder, withIntermediateDirectories: true)
                let file = FileDestination()
                file.logFileURL = .logFile
                SwiftyBeaver.addDestination(file)
            }
        }
    }
}
