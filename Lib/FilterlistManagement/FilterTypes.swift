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

/* This file was taken from AdBlock's iOS app, and then modified to use
 Swift 4 and MacOS APIs */

import Foundation
class Filter: NSObject, PrettyPrint {

    static var lastId = 0
    var id:Int
    var domains:DomainSet? = nil
    static var cache:[String:Filter] = [:]

    override init() {
        Filter.lastId = Filter.lastId + 1
        self.id = Filter.lastId
    }

    static func fromText(text:String) -> Filter? {
        if Filter.cache[text] == nil {
            if (Filter.isSelectorFilter(text: text)) {
                Filter.cache[text] = SelectorFilter(text: text)
            } else if (Filter.isAdvancedSelectorFilter(text: text)) {
                Filter.cache[text] = ElemHideEmulationFilter(text: text);
            } else if (Filter.isContentFilter(text: text)) {
                Filter.cache[text] = try? ContentFilter.from(text: text, domains: nil, type: nil, body: nil)
            } else {
                Filter.cache[text] = try? PatternFilter.from(text: text)
            }
        }
        return Filter.cache[text]
    }

    func toString() -> String {
        var returnString = ""
        if let temp = domains {
            returnString += temp.toString()
        }
        return returnString
    }

    //test if pattern#@#pattern or pattern#?#pattern
    static func isSelectorFilter(text:String)->Bool {
        // This returns true for both hiding rules as hiding whitelist rules
        // This means that you'll first have to check if something is an excluded rule
        // before checking this, if the difference matters.
        return text.range(of: "#@?#.", options: .regularExpression) != nil
    }

    // test if pattern#@#pattern
    static func isSelectorExcludeFilter(text:String)->Bool {
        return text.range(of: "#@#.", options: .regularExpression) != nil
    }

    // test if pattern#?#pattern
    static func isAdvancedSelectorFilter(text: String) -> Bool {
        return text.range(of: "#\\?#.", options: .regularExpression) != nil
    }

    // test if pattern# @ | ? | $ #pattern
    static func isContentFilter(text: String) -> Bool {
        return text.range(of: "^([^/*|@\"!]*?)#([@?$])#(.+)$", options: .regularExpression) != nil
    }

    // test if pattern#$#pattern
    static func isSnippetFilter(text: String) -> Bool {
        return text.range(of: "^([^/*|@\"!]*?)#\\$#(.+)$", options: .regularExpression) != nil
    }

    // test if @@pattern
    static func isWhitelistFilter(text:String)->Bool {
        return text.range(of: "^@@", options: .regularExpression) != nil
    }

    static func isComment(text:String)->Bool {
        if ((text.count == 0) || (text.first == "!")) {
            return true
        }
        let lctext = text.lowercased()
        return ((lctext.hasPrefix("[adblock")) || (lctext.hasPrefix("(adblock")))
    }

    // Convert a comma-separated list of domain includes and excludes into a
    // DomainSet.
    static func toDomainSet(domainText:String, divider:String)->DomainSet {
        let domains = domainText.split(separator: divider.first!).map(String.init)

        var data:[String:Bool] = [:]
        data[DomainSet.ALL] = true

        if (domainText == "") {
            return DomainSet(data: data)
        }

        for domain in domains {
            if (domain.hasPrefix("~")) {
                data[String(domain.dropFirst())] = false
            } else {
                data[domain] = true
                data[DomainSet.ALL] = false
            }
        }

        return  DomainSet(data: data)
    }
}

// Filters that block by CSS selector.
class SelectorFilter: Filter {

    var selector:String? = nil
    var text:String? = nil

    convenience init(text:String) {
        self.init()
        do {
            var parts = try listGroups(pattern: "(^.*?)#@?#(.+$)", inString: text)
            self.domains = Filter.toDomainSet(domainText:parts[1], divider:",")
            self.selector = parts[2]
        } catch {
            self.domains = DomainSet(data: [:])
            self.selector = ""
        }
        self.text = text
    }

    override func toString() -> String {
        var returnString = "SelectorFilter "
        returnString += super.toString()
        if let temp = selector {
            returnString += " selector: " + String(temp)
        }
        return returnString
    }

    // If !|excludeFilters|, returns filter.
    // Otherwise, returns a new SelectorFilter that is the combination of
    // |filter| and each selector exclusion filter in the given list.
    static func merge(filter:SelectorFilter, excludeFiltersIn:[SelectorFilter]?)->SelectorFilter {
        guard let excludeFilters = excludeFiltersIn else {
            return filter
        }
        if excludeFilters.count == 0 {
            return filter
        }
        if let domains = filter.domains {
            let domainsClone = domains.clone()
            for filter in excludeFilters {
                domainsClone.subtract(other: filter.domains!)
            }
            let result = SelectorFilter(text: "_##_")
            result.selector = filter.selector
            result.domains = domainsClone
            return result
        }
        return filter
    }
}

// Filters that block by CSS selector.
class ElemHideEmulationFilter: SelectorFilter {

    convenience init(text:String) {
        self.init()
        do {
            var parts = try listGroups(pattern: "(^.*?)#\\?#(.+$)", inString: text)
            self.domains = Filter.toDomainSet(domainText:parts[1], divider:",")
            self.selector = parts[2]
        } catch {
            self.domains = DomainSet(data: [:])
            self.selector = ""
        }
        self.text = text
    }

    override func toString() -> String {
        var returnString = "ElemHideEmulationFilter "
        returnString += super.toString()
        return returnString
    }
}

/**
 * Base class for content filters
 * @param {string} text
 * @param {string} [domains] Host names or domains the filter should be
 *                           restricted to
 * @param {string} body      The body of the filter
 */
class ContentFilter: Filter {

    var body: String? = nil
    var text: String? = nil

    convenience init(text: String, domains: String?, body: String) {
        self.init()
        self.body = body
        if let localDomains = domains {
            self.domains = Filter.toDomainSet(domainText: localDomains, divider: ",")
        }
        self.text = text
    }

    override func toString() -> String {
        var returnString = "ContentFilter "
        returnString += super.toString()
        if let temp = body {
            returnString += " body: " + String(temp)
        }
        if let temp = text {
            returnString += " text: " + String(temp)
        }
        return returnString
    }

    // Creates a content filter from a pre-parsed text representation
    static func from(text: String, domains: String?, type: String?, body: String?) throws -> SnippetFilter {
        var localDomains = domains ?? ""
        var localType = type ?? ""
        var localBody = body ?? ""
        if (localDomains.count == 0 && localType.count == 0 && localBody.count == 0 && Filter.isContentFilter(text: text)) {
            let matches = try listMatches(pattern: "^([^/*|@\"!]*?)#([@?$])#(.+)$", inString: text)
            localDomains = matches[1]
            localType = matches[2]
            localBody = matches[3]
        }
        // We don't allow content filters which have any empty domains.
        let emptyMatch = try containsMatch(pattern: "(^|,)~?(,|$)", inString: localDomains)
        if (localDomains.count > 0 && emptyMatch) {
            throw FilterRuleError.invalidDomain(domain: localDomains)
        }

        if (localType == "$") {
            return SnippetFilter(text: text, domains: localDomains, body: localBody)
        }
        throw FilterRuleError.invalidContentFilterText(sourceRule: text)
    }
}

/**
 * Class for snippet filters
 * @param {string} text
 * @param {string} [domains]
 * @param {string} script    Script that should be executed
 * @constructor
 * @augments ContentFilter
 */
class SnippetFilter: ContentFilter {

    var script: String? {
        return self.body
    }

    convenience init(text: String, domains: String?, script: String) {
        self.init()
        self.body = script
        if let localDomains = domains {
            self.domains = Filter.toDomainSet(domainText: localDomains, divider:",")
        }
        self.text = text
    }
    
    convenience init(text: String, domains: DomainSet?, script: String) {
        self.init()
        self.body = script
        self.domains = domains
        self.text = text
    }

    static func merge(filter: SnippetFilter, excludeFilters: [Filter]?) -> SnippetFilter {
        if (excludeFilters == nil) {
            return filter
        }

        let domains = filter.domains?.clone()
        for excludeFilter in excludeFilters ?? [] {
            if let excludeDomains = excludeFilter.domains {
                domains?.subtract(other: excludeDomains)
            }
        }

        return SnippetFilter(text: filter.text ?? "", domains: domains, script: filter.body ?? "")
    }
}

class PatternFilter: Filter {

    var allowedElementTypes:Int? = nil
    var options:UInt8? = nil
    var rule:String? = nil
    var text:String? = nil
    var key:String? = nil
    var cspText:String? = nil
    var rewrite:String? = nil

    private static let DomainTextKey = "domainText"
    private static let OptionsTextKey = "options"
    private static let AllowedElementTypesKey = "allowedElementTypes"
    private static let RuleKey = "rule"
    private static let KeyKey = "key"
    private static let CspTextKey = "cspText"
    private static let RewriteKey = "rewrite"

    override func toString() -> String {
        var returnString = "PatternFilter "
        returnString = super.toString()
        if let temp = allowedElementTypes {
            returnString += " allowedElementTypes: " + String(temp)
        }
        if let temp = options {
            returnString += " options: " + String(temp)
        }
        if let temp = rule {
            returnString += " rule: " + temp
        }
        if let temp = text {
            returnString += " text: " + temp
        }
        return returnString
    }
    
    // Returns true if an element of the given type loaded from the given URL
    // would be matched by this filter.
    //   url:string the url the element is loading.
    //   elementType:ElementTypes the type of DOM element.
    //   isThirdParty: true if the request for url was from a page of a
    //       different origin
    func matches(url: String, elementType: Int, isThirdParty: Bool) -> Bool {
        if ((elementType & self.allowedElementTypes!) == 0) {
            return false
        }
    
        // If the resource is being loaded from the same origin as the document,
        // and your rule applies to third-party loads only, we don't care what
        // regex your rule contains, even if it's for someotherserver.com.
        if (((self.options ?? 0 & FilterOptions.THIRDPARTY.rawValue) != 0) && !isThirdParty) {
            return false;
        }
    
        if (((self.options ?? 0 & FilterOptions.FIRSTPARTY.rawValue) != 0) && isThirdParty) {
            return false;
        }
    
        if let key = self.key {
            var match: Bool
            do {
                try match = containsMatch(pattern: key, inString: url)
            } catch {
                match = false
            }
            if !match {
                return false;
            }
        }
    
        var match: Bool = false
        if let rule = self.rule {
            do {
                try match = containsMatch(pattern: rule, inString: url)
            } catch {
                match = false
            }
        }
        return match
    }

    // Data is [rule text, allowed element types, options].
    static func fromData(data: [String]) throws -> PatternFilter {
        let result = PatternFilter()
        result.rule = data[0]
        var allowedElementTypes = Int(data[1])
        if allowedElementTypes == nil {
            allowedElementTypes = ElementTypes["DEFAULTTYPES"]
        }
        result.allowedElementTypes = allowedElementTypes
        result.options = UInt8(data[2])
        var data:[String:Bool] = [:]
        data[DomainSet.ALL] = true
        result.domains = DomainSet(data: data)
        return result
    }

    // Text is the original filter text of a blocking or whitelist filter.
    // Throws an exception if the rule is invalid.
    static func from(text:String) throws -> PatternFilter {
        var data = try PatternFilter.parseRule(text: text)
        let result = PatternFilter()
        if let domainText = data[DomainTextKey] as? String {
            result.domains = Filter.toDomainSet(domainText: domainText, divider: "|")
        }
        if let allowedElementTypes = data[AllowedElementTypesKey] as? Int {
            result.allowedElementTypes = allowedElementTypes
        }
        if let options = data[OptionsTextKey] as? UInt8 {
            result.options = options
        }
        if let rule = data[RuleKey] as? String {
            result.rule = rule
        }
        if let key = data[KeyKey] as? String {
            result.key = key
        }
        if let cspText = data[CspTextKey] as? String {
            result.cspText = cspText
        }
        if let rewrite = data[RewriteKey] as? String {
            result.rewrite = rewrite
        }
        result.text = text
        return result
    }

    // Return a { rule, domainText, allowedElementTypes } object
    // for the given filter text.  Throws an exception if the rule is invalid.
    private static func parseRule(text:String) throws-> [String:Any] {

        var result:[String:Any] = [:]
        result[DomainTextKey] = ""
        result[OptionsTextKey] = FilterOptions.NONE.rawValue

        var optionsText = try listMatches(pattern: "\\$~?[\\w-]+(?:=[^,]+)?(?:,~?[\\w-]+(?:=[^,]+)?)*$", inString: text)
        var allowedElementTypes:Int?
        var rule = text
        var options = [String]()
        if (optionsText.count > 0) {
            optionsText[0].remove(at: optionsText[0].startIndex)
            let text  = optionsText[0].lowercased()
            options = text.split(separator: ",").map(String.init)
            let dividerIndex = rule.index(of: "$") ?? rule.endIndex
            rule = String(rule[..<dividerIndex])
        }

        for option in options {
            var optionText = option
            if (try containsMatch(pattern: "^domain", inString: optionText)) {
                let domainEndInx = optionText.index(optionText.startIndex, offsetBy: 7)
                result[DomainTextKey] = String(optionText[domainEndInx...])
                continue
            }

            let inverted = (optionText.hasPrefix("~"))
            if (inverted) {
                optionText.remove(at: option.startIndex)
            }
            let originalOptionText = optionText
            optionText = optionText.replacingOccurrences(of: "-", with: "_")

            if (optionText == "object_subrequest") {
                optionText = "object"
            }

            // "background" is a synonym for "image".
            if (optionText == "background") {
                optionText = "image"
            }

            if let typeValue = ElementTypes[optionText] { // this option is a known element type
                if (inverted) {
                    if (allowedElementTypes == nil) {
                        allowedElementTypes = ElementTypes["DEFAULTTYPES"]
                    }
                    allowedElementTypes = allowedElementTypes! & ~typeValue
                } else {
                    if (allowedElementTypes == nil) {
                        allowedElementTypes = ElementTypes["NONE"]
                    }
                    allowedElementTypes = allowedElementTypes! | typeValue
                }
            } else if (optionText == "third_party") {
                var optionVal:UInt8 = 0
                if let currentOptionValue = result[OptionsTextKey] as? UInt8 {
                    optionVal = currentOptionValue
                }
                if (inverted) {
                    optionVal = optionVal | FilterOptions.FIRSTPARTY.rawValue
                } else {
                    optionVal = optionVal | FilterOptions.THIRDPARTY.rawValue
                }
                result[OptionsTextKey] = optionVal
            } else if (optionText == "match_case") {
                var optionVal:UInt8 = 0
                if let currentOptionValue = result[OptionsTextKey] as? UInt8 {
                    optionVal = currentOptionValue
                }
                //doesn"t have an inverted function
                optionVal = optionVal | FilterOptions.MATCHCASE.rawValue
                result[OptionsTextKey] = optionVal
            } else if (try containsMatch(pattern: "^csp=", inString: originalOptionText)){
                let cspEndInx = originalOptionText.index(originalOptionText.startIndex, offsetBy: 4)
                let cspText = String(originalOptionText[cspEndInx...])
                let invalidCspMatch = try containsMatch(pattern: "(base-uri|referrer|report-to|report-uri|upgrade-insecure-requests)\\b", inString: cspText.lowercased())
                if (cspText.count > 0 && invalidCspMatch) {
                  throw FilterRuleError.invalidOption(sourceRule: text, unknownOption: originalOptionText)
                }
                result[CspTextKey] = cspText
                if (inverted) {
                    if (allowedElementTypes == nil) {
                        allowedElementTypes = ElementTypes["DEFAULTTYPES"]!
                    }
                    allowedElementTypes = allowedElementTypes! & ~ElementTypes["csp"]!
                } else {
                    if (allowedElementTypes == nil) {
                        allowedElementTypes = ElementTypes["NONE"]!
                    }
                    allowedElementTypes = allowedElementTypes! | ElementTypes["csp"]!
                }
            } else if (try containsMatch(pattern: "^rewrite=", inString: originalOptionText)) {
                let rewriteEndInx = originalOptionText.index(originalOptionText.startIndex, offsetBy: 8)
                result[RewriteKey] = String(originalOptionText[rewriteEndInx...])
                if (inverted) {
                    if (allowedElementTypes == nil) {
                        allowedElementTypes = ElementTypes["DEFAULTTYPES"]!
                    }
                    allowedElementTypes = allowedElementTypes! & ~ElementTypes["DEFAULTTYPES"]!
                } else {
                    if (allowedElementTypes == nil) {
                        allowedElementTypes = ElementTypes["NONE"]!
                    }
                    allowedElementTypes = allowedElementTypes! | ElementTypes["DEFAULTTYPES"]!
                }
                allowedElementTypes = allowedElementTypes! & ~(ElementTypes["DEFAULTTYPES"]! | ElementTypes["script"]! | ElementTypes["subdocument"]! | ElementTypes["object"]! | ElementTypes["object_subrequest"]!)
            } else if (option == "collapse") {
            // We currently do not support this option. However I've never seen any
            // reports where this was causing issues. So for now, simply skip this
            // option, without returning that the filter was invalid.
            } else {
                throw FilterRuleError.invalidOption(sourceRule: text, unknownOption: optionText)
            }
        }
        // If no element types are mentioned, the default set is implied.
        // Otherwise, the element types are used, which can be ElementTypes.NONE
        if (allowedElementTypes == nil) {
            result[AllowedElementTypesKey] = ElementTypes["DEFAULTTYPES"]
        } else {
            result[AllowedElementTypesKey] = allowedElementTypes
        }
        // We parse whitelist rules too, in which case we already know it's a
        // whitelist rule so can ignore the @@s.
        if (Filter.isWhitelistFilter(text: rule)) {
            let removeRange = rule.startIndex..<rule.index(rule.startIndex, offsetBy: 2)
            rule.removeSubrange(removeRange)
        }
        // Check if there's any non-ascii chars, they're not supported...
        if (try containsMatch(pattern: "[^\\x00-\\x7f]", inString: rule)) {
            throw FilterRuleError.invalidRegex(sourceRule: text)
        }
        // Convert regexy stuff.

        // First, check if the rule itself is in regex form.  If so, we're done.
        if (try containsMatch(pattern: "^\\/.+\\/$", inString: rule)) {
            throw FilterRuleError.invalidRegex(sourceRule: text)
        }

        // ***** -> *
        //replace, excessive wildcard sequences with a single one
        rule = try replaceMatches(pattern: "\\*-\\*-\\*-\\*-\\*", inString: rule, replacementString: "*")!

        rule = try replaceMatches(pattern: "\\*\\*+", inString: rule, replacementString: "*")!

        // Some chars in regexes mean something special; escape it always.
        // Escaped characters are also faster.
        // - Do not escape a-z A-Z 0-9 and _ because they can't be escaped
        // - Do not escape | ^ and * because they are handled below.
        rule = try replaceMatches(pattern: "([^a-zA-Z0-9_|^*])", inString: rule, replacementString: "\\\\$1")!
        //^ is a separator char in ABP
        rule = try replaceMatches(pattern: "\\^", inString: rule, replacementString: "[^\\\\-\\\\.\\\\%a-zA-Z0-9_]")!
        //If a rule contains *, replace that by .*
        rule = try replaceMatches(pattern: "\\*", inString: rule, replacementString: ".*")!
        // Starting with || means it should start at a domain or subdomain name, so
        // match ://<the rule> or ://some.domains.here.and.then.<the rue>
        rule = try replaceMatches(pattern: "^\\|\\|", inString: rule, replacementString: "^[^\\\\/]+\\\\:\\\\/\\\\/([^\\\\/]+\\\\.)?")!
        // Starting with | means it should be at the beginning of the URL.
        rule = try replaceMatches(pattern: "^\\|", inString: rule, replacementString: "^")!
        // Rules ending in | means the URL should end there
        rule = try replaceMatches(pattern: "\\|$", inString: rule, replacementString: "$")!
        // Any other "|" within a string should really be a pipe.
        rule = try replaceMatches(pattern: "\\|", inString: rule, replacementString: "\\\\|")!
        // If it starts or ends with *, strip that -- it's a no-op.
        rule = try replaceMatches(pattern: "^\\.\\*", inString: rule, replacementString: "")!
        rule = try replaceMatches(pattern: "\\.\\*$", inString: rule, replacementString: "")!
        result[RuleKey] = rule
        return result
    }
}

protocol PrettyPrint {
    func toString() -> String
}
