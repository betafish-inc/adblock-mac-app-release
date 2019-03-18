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

/**
 * @fileOverview Snippets implementation.
 */

class SnippetsHelper: NSObject {
    static let shared: SnippetsHelper = SnippetsHelper()
    
    private override init() {
        let snippetsURL = Bundle.main.url(forResource:"snippets", withExtension: "js")
        self.snippetsLibrarySource = (try? String(contentsOf: snippetsURL!)) ?? ""
        
        super.init()
    }
    
    var executableCode: [String: String] = [:]
    
    var snippetsLibrarySource: String
    
    let singleCharacterEscapes: [String: String] = [
        "n": "\n",
        "r": "\r",
        "t": "\t"
    ]
    
    /**
     * Parses a script and returns a list of all its commands and their arguments
     * @param {string} script
     * @return {Array.<string[]>}
     */
    func parseScript(script: String) -> [[String]] {
        var tree: [[String]] = []
    
        var escape = false
        var withinQuotes = false
    
        var unicodeEscape: String? = nil
    
        var call: [String] = []
        var argument: String = ""
    
        let trimmedScript = script.trimmingCharacters(in: .whitespacesAndNewlines) + ";"
        for character in trimmedScript {
            let whitespaceMatch = try? containsMatch(pattern: "\\s", inString: String(character))
            if let unicodeString = unicodeEscape {
                unicodeEscape = unicodeString + String(character)
                
                if unicodeEscape?.count == 4 {
                    if let unicodeStringInt = UInt32(unicodeString, radix: 16), let unicodeStringScalar = UnicodeScalar(unicodeStringInt) {
                        let charFromUnicode = Character(unicodeStringScalar)
                        argument.append(charFromUnicode)
                    }
                    
                    unicodeEscape = nil
                }
            } else if escape {
                escape = false
                
                if character == "u" {
                    unicodeEscape = ""
                } else if let escapedChar = singleCharacterEscapes[String(character)] {
                    argument += escapedChar
                } else {
                    argument.append(character)
                }
            } else if character == "\\" {
                escape = true
            } else if character == "'" {
                withinQuotes = !withinQuotes
            } else if (withinQuotes || (character != ";" && !(whitespaceMatch ?? false))) {
                argument.append(character)
            } else {
                if argument != "" {
                    call.append(argument)
                    argument = ""
                }
                
                if (character == ";" && call.count > 0) {
                    tree.append(call)
                    call = []
                }
            }
        }
    
        return tree
    }
    
    /**
     * Compiles a script against a given list of libraries into executable code
     * @param {string} script
     * @param {string[]} libraries
     * @return {string}
     */
    func compileScript(script: String, libraries: [String]) -> String {
        return """
            "use strict";
            {
                const libraries = \(libraries);
        
                const script = \(parseScript(script: script));
        
                let imports = Object.create(null);
                for (let library of libraries)
                    new Function("exports", library)(imports);
        
                for (let [name, ...args] of script)
                {
                    if (Object.prototype.hasOwnProperty.call(imports, name))
                    {
                        let value = imports[name];
                        if (typeof value === "function")
                            value(...args);
                    }
                }
            }
        """
    }
    
    func getExecutableCode(script: String) -> String {
        if let executableCode = executableCode[script] {
            return executableCode
        }
        
        let code = compileScript(script: script, libraries: [snippetsLibrarySource])
        
        executableCode[script] = code
        return code
    }
    
}
