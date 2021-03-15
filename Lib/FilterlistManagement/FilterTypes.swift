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
    var id: Int
    var domains: DomainSet?
    static var cache: [String: Filter] = [:]
    private static let cacheQueue = DispatchQueue(label: "cacheQueue", attributes: .concurrent)
    
    var stringValue: String {
        var returnString = ""
        if let temp = domains {
            returnString += temp.stringValue
        }
        return returnString
    }

    override init() {
        Filter.lastId += 1
        self.id = Filter.lastId
    }
    
    private static func addToCache(text: String, filter: Filter) {
        Filter.cacheQueue.async(flags: .barrier) {
            Filter.cache[text] = filter
        }
    }
    
    private static func getFromCache(text: String) -> Filter? {
        var filter: Filter?
        Filter.cacheQueue.sync {
            filter = Filter.cache[text]
        }
        return filter
    }

    static func fromText(text: String) -> Filter? {
        if let filter = Filter.getFromCache(text: text) {
            return filter
        } else {
            let filter = SelectorFilter(text: text) ??
                ElemHideEmulationFilter(text: text) ??
                ContentFilter.from(text: text) ??
                PatternFilter.from(text: text)
            
            if let filter = filter {
                Filter.addToCache(text: text, filter: filter)
            }
            return filter
        }
    }

    //test if pattern#@#pattern or pattern#?#pattern
    static func isSelectorFilter(text: String) -> Bool {
        // This returns true for both hiding rules as hiding whitelist rules
        // This means that you'll first have to check if something is an excluded rule
        // before checking this, if the difference matters.
        return text.range(of: "#@?#.", options: .regularExpression) != nil
    }

    // test if pattern#@#pattern
    static func isSelectorExcludeFilter(text: String) -> Bool {
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
    static func isWhitelistFilter(text: String) -> Bool {
        return text.range(of: "^@@", options: .regularExpression) != nil
    }

    static func isComment(text: String) -> Bool {
        if text.isEmpty || text.first == "!" {
            return true
        }
        let lctext = text.lowercased()
        return ((lctext.hasPrefix("[adblock")) || (lctext.hasPrefix("(adblock")))
    }

    // Convert a comma-separated list of domain includes and excludes into a
    // DomainSet.
    static func toDomainSet(domainText: String, divider: String) -> DomainSet {
        var data: [String: Bool] = [:]
        
        guard let separatorChar = divider.first else {
            return DomainSet(data: data)
        }
        let domains = domainText.split(separator: separatorChar).map(String.init)

        data[DomainSet.ALL] = true
        if domainText.isEmpty {
            return DomainSet(data: data)
        }

        for domain in domains {
            if domain.hasPrefix("~") {
                data[String(domain.dropFirst())] = false
            } else {
                data[domain] = true
                data[DomainSet.ALL] = false
            }
        }

        return DomainSet(data: data)
    }
}

// Filters that block by CSS selector.
class SelectorFilter: Filter {
    var selector: String?
    var text: String?
    
    override var stringValue: String {
        var returnString = "SelectorFilter \(super.stringValue)"
        if let temp = selector {
            returnString = "\(returnString) selector: \(String(temp))"
        }
        return returnString
    }

    convenience init?(text: String) {
        guard Filter.isSelectorFilter(text: text) else { return nil }
        self.init()
        if let parts = text.listGroups(pattern: "(^.*?)#@?#(.+$)") {
            self.domains = Filter.toDomainSet(domainText: parts[1], divider: ",")
            self.selector = parts[2]
        } else {
            self.domains = DomainSet(data: [:])
            self.selector = ""
        }
        self.text = text
    }

    // If !|excludeFilters|, returns filter.
    // Otherwise, returns a new SelectorFilter that is the combination of
    // |filter| and each selector exclusion filter in the given list.
    static func merge(filter: SelectorFilter, excludeFiltersIn: [SelectorFilter]?) -> SelectorFilter {
        guard let excludeFilters = excludeFiltersIn else {
            return filter
        }
        if excludeFilters.isEmpty {
            return filter
        }
        if let domains = filter.domains {
            let domainsClone = domains.clone()
            for excludeFilter in excludeFilters {
                if let excludeDomains = excludeFilter.domains {
                    domainsClone.subtract(other: excludeDomains)
                }
            }
            if let result = SelectorFilter(text: "_##_") {
                result.selector = filter.selector
                result.domains = domainsClone
                return result
            }
        }
        return filter
    }
}

// Filters that block by CSS selector.
class ElemHideEmulationFilter: SelectorFilter {
    convenience init?(text: String) {
        guard Filter.isAdvancedSelectorFilter(text: text) else { return nil }
        self.init()
        if let parts = text.listGroups(pattern: "(^.*?)#\\?#(.+$)") {
            self.domains = Filter.toDomainSet(domainText: parts[1], divider: ",")
            self.selector = parts[2]
        } else {
            self.domains = DomainSet(data: [:])
            self.selector = ""
        }
        self.text = text
    }

    override var stringValue: String {
        return "ElemHideEmulationFilter \(super.stringValue)"
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
    var body: String?
    var text: String?
    
    override var stringValue: String {
        var returnString = "ContentFilter \(super.stringValue)"
        if let temp = body {
            returnString = "\(returnString) body: \(String(temp))"
        }
        if let temp = text {
            returnString = "\(returnString) text: \(String(temp))"
        }
        return returnString
    }

    convenience init(text: String, domains: String?, body: String) {
        self.init()
        self.body = body
        if let localDomains = domains {
            self.domains = Filter.toDomainSet(domainText: localDomains, divider: ",")
        }
        self.text = text
    }

    // Creates a content filter from a pre-parsed text representation
    static func from(text: String) -> SnippetFilter? {
        guard Filter.isContentFilter(text: text) else { return nil }
        
        var domains = ""
        var type = ""
        var body = ""
        if let matches = text.listMatches(pattern: "^([^/*|@\"!]*?)#([@?$])#(.+)$") {
            domains = matches[1]
            type = matches[2]
            body = matches[3]
        }
        
        // We don't allow content filters which have any empty domains.
        let emptyMatch = domains.containsMatch(pattern: "(^|,)~?(,|$)") ?? false
        guard (domains.isEmpty || !emptyMatch) && type == "$" else { return nil }
        
        return SnippetFilter(text: text, domains: domains, body: body)
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
        return body
    }

    convenience init(text: String, domains: String?, script: String) {
        self.init()
        self.body = script
        if let localDomains = domains {
            self.domains = Filter.toDomainSet(domainText: localDomains, divider: ",")
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
        if excludeFilters == nil {
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
    var allowedElementTypes: Int?
    var options: UInt8?
    var rule: String?
    var text: String?
    var key: String?
    var cspText: String?
    var rewrite: String?

    private static let DomainTextKey = "domainText"
    private static let OptionsTextKey = "options"
    private static let AllowedElementTypesKey = "allowedElementTypes"
    private static let RuleKey = "rule"
    private static let KeyKey = "key"
    private static let CspTextKey = "cspText"
    private static let RewriteKey = "rewrite"

    override var stringValue: String {
        var returnString = "PatternFilter \(super.stringValue)"
        if let temp = allowedElementTypes {
            returnString = "\(returnString) allowedElementTypes: \(String(temp))"
        }
        if let temp = options {
            returnString = "\(returnString) options: \(String(temp))"
        }
        if let temp = rule {
            returnString = "\(returnString) rule: \(temp)"
        }
        if let temp = text {
            returnString = "\(returnString) text: \(temp)"
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
        if (elementType & allowedElementTypes!) == 0 {
            return false
        }
    
        // If the resource is being loaded from the same origin as the document,
        // and your rule applies to third-party loads only, we don't care what
        // regex your rule contains, even if it's for someotherserver.com.
        if ((options ?? 0 & FilterOptions.THIRDPARTY.rawValue) != 0) && !isThirdParty {
            return false
        }
    
        if ((options ?? 0 & FilterOptions.FIRSTPARTY.rawValue) != 0) && isThirdParty {
            return false
        }
    
        if let key = self.key {
            if !(url.containsMatch(pattern: key) ?? false) {
                return false
            }
        }
    
        var match: Bool = false
        if let rule = self.rule {
            match = url.containsMatch(pattern: rule) ?? false
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
        var data: [String: Bool] = [:]
        data[DomainSet.ALL] = true
        result.domains = DomainSet(data: data)
        return result
    }

    // Text is the original filter text of a blocking or whitelist filter.
    // Returns nil if the rule is invalid.
    static func from(text: String) -> PatternFilter? {
        guard let data = try? PatternFilter.parseRule(text: text) else { return nil }
        
        let result = PatternFilter()
        if let domainText = data[DomainTextKey] as? String {
            result.domains = Filter.toDomainSet(domainText: domainText, divider: "|")
        }
        result.allowedElementTypes = data[AllowedElementTypesKey] as? Int
        result.options = data[OptionsTextKey] as? UInt8
        result.rule = data[RuleKey] as? String
        result.key = data[KeyKey] as? String
        result.cspText = data[CspTextKey] as? String
        result.rewrite = data[RewriteKey] as? String
        result.text = text
        
        return result
    }

    // Return a { rule, domainText, allowedElementTypes } object
    // for the given filter text.  Throws an exception if the rule is invalid.
    // swiftlint:disable cyclomatic_complexity
    // TODO: Reduce complexity of this function
    private static func parseRule(text: String) throws -> [String: Any] {
        var result: [String: Any] = [:]
        result[DomainTextKey] = ""
        result[OptionsTextKey] = FilterOptions.NONE.rawValue

        var optionsText = text.listMatches(pattern: "\\$~?[\\w-]+(?:=[^,]+)?(?:,~?[\\w-]+(?:=[^,]+)?)*$") ?? []
        var allowedElementTypes: Int?
        var rule = text
        var options = [String]()
        if !optionsText.isEmpty {
            optionsText[0].remove(at: optionsText[0].startIndex)
            let text = optionsText[0].lowercased()
            options = text.split(separator: ",").map(String.init)
            let dividerIndex = rule.firstIndex(of: "$") ?? rule.endIndex
            rule = String(rule[..<dividerIndex])
        }

        for option in options {
            var optionText = option
            if optionText.containsMatch(pattern: "^domain") ?? false {
                let domainEndInx = optionText.index(optionText.startIndex, offsetBy: 7)
                result[DomainTextKey] = String(optionText[domainEndInx...])
                continue
            }

            let inverted = (optionText.hasPrefix("~"))
            if inverted {
                optionText.remove(at: option.startIndex)
            }
            let originalOptionText = optionText
            optionText = optionText.replacingOccurrences(of: "-", with: "_")

            if optionText == "object_subrequest" {
                optionText = "object"
            }

            // "background" is a synonym for "image".
            if optionText == "background" {
                optionText = "image"
            }

            if let typeValue = ElementTypes[optionText] { // this option is a known element type
                if inverted {
                    if allowedElementTypes == nil {
                        allowedElementTypes = ElementTypes["DEFAULTTYPES"]
                    }
                    allowedElementTypes = allowedElementTypes! & ~typeValue
                } else {
                    if allowedElementTypes == nil {
                        allowedElementTypes = ElementTypes["NONE"]
                    }
                    allowedElementTypes = allowedElementTypes! | typeValue
                }
            } else if optionText == "third_party" {
                var optionVal: UInt8 = 0
                if let currentOptionValue = result[OptionsTextKey] as? UInt8 {
                    optionVal = currentOptionValue
                }
                if inverted {
                    optionVal = optionVal | FilterOptions.FIRSTPARTY.rawValue
                } else {
                    optionVal = optionVal | FilterOptions.THIRDPARTY.rawValue
                }
                result[OptionsTextKey] = optionVal
            } else if optionText == "match_case" {
                var optionVal: UInt8 = 0
                if let currentOptionValue = result[OptionsTextKey] as? UInt8 {
                    optionVal = currentOptionValue
                }
                //doesn"t have an inverted function
                optionVal = optionVal | FilterOptions.MATCHCASE.rawValue
                result[OptionsTextKey] = optionVal
            } else if originalOptionText.containsMatch(pattern: "^csp=") ?? false {
                let cspEndInx = originalOptionText.index(originalOptionText.startIndex, offsetBy: 4)
                let cspText = String(originalOptionText[cspEndInx...])
                let invalidCspMatch = cspText.lowercased().containsMatch(pattern: "(base-uri|referrer|report-to|report-uri|upgrade-insecure-requests)\\b") ?? false
                if !cspText.isEmpty && invalidCspMatch {
                  throw FilterRuleError.invalidOption(sourceRule: text, unknownOption: originalOptionText)
                }
                result[CspTextKey] = cspText
                if inverted {
                    if allowedElementTypes == nil {
                        allowedElementTypes = ElementTypes["DEFAULTTYPES"]!
                    }
                    allowedElementTypes = allowedElementTypes! & ~ElementTypes["csp"]!
                } else {
                    if allowedElementTypes == nil {
                        allowedElementTypes = ElementTypes["NONE"]!
                    }
                    allowedElementTypes = allowedElementTypes! | ElementTypes["csp"]!
                }
            } else if originalOptionText.containsMatch(pattern: "^rewrite=") ?? false {
                let rewriteEndInx = originalOptionText.index(originalOptionText.startIndex, offsetBy: 8)
                result[RewriteKey] = String(originalOptionText[rewriteEndInx...])
                if inverted {
                    if allowedElementTypes == nil {
                        allowedElementTypes = ElementTypes["DEFAULTTYPES"]!
                    }
                    allowedElementTypes = allowedElementTypes! & ~ElementTypes["DEFAULTTYPES"]!
                } else {
                    if allowedElementTypes == nil {
                        allowedElementTypes = ElementTypes["NONE"]!
                    }
                    allowedElementTypes = allowedElementTypes! | ElementTypes["DEFAULTTYPES"]!
                }
                allowedElementTypes = allowedElementTypes! & ~(ElementTypes["DEFAULTTYPES"]!
                    | ElementTypes["script"]! | ElementTypes["subdocument"]!
                    | ElementTypes["object"]! | ElementTypes["object_subrequest"]!)
            } else if option == "collapse" {
            // We currently do not support this option. However I've never seen any
            // reports where this was causing issues. So for now, simply skip this
            // option, without returning that the filter was invalid.
            } else {
                throw FilterRuleError.invalidOption(sourceRule: text, unknownOption: optionText)
            }
        }
        
        // If no element types are mentioned, the default set is implied.
        // Otherwise, the element types are used, which can be ElementTypes.NONE
        if allowedElementTypes == nil {
            result[AllowedElementTypesKey] = ElementTypes["DEFAULTTYPES"]
        } else {
            result[AllowedElementTypesKey] = allowedElementTypes
        }
        
        // We parse whitelist rules too, in which case we already know it's a
        // whitelist rule so can ignore the @@s.
        if Filter.isWhitelistFilter(text: rule) {
            let removeRange = rule.startIndex..<rule.index(rule.startIndex, offsetBy: 2)
            rule.removeSubrange(removeRange)
        }
        
        // Check if there's any non-ascii chars or if the rule itself is in regex form
        if rule.containsMatch(pattern: "[^\\x00-\\x7f]") ?? false
            || rule.containsMatch(pattern: "^\\/.+\\/$") ?? false {
            throw FilterRuleError.invalidRegex(sourceRule: text)
        }

        // Replace excessive wildcard sequences with a single one
        // Some chars in regexes mean something special; escape it always.
        // Escaped characters are also faster.
        // - Do not escape a-z A-Z 0-9 and _ because they can't be escaped
        // - Do not escape | ^ and * because they are handled below.
        // ^ is a separator char in ABP
        // If a rule contains *, replace that with .*
        // Starting with || means it should start at a domain or subdomain name, so
        // match ://<the rule> or ://some.domains.here.and.then.<the rule>
        // Starting with | means it should be at the beginning of the URL.
        // Rules ending in | means the URL should end there
        // Any other "|" within a string should really be a pipe.
        // If it starts or ends with *, strip that -- it's a no-op.
        if let updatedRule = rule.replaceMatches(pattern: "\\*-\\*-\\*-\\*-\\*", replacementString: "*")?
            .replaceMatches(pattern: "\\*\\*+", replacementString: "*")?
            .replaceMatches(pattern: "([^a-zA-Z0-9_|^*])", replacementString: "\\\\$1")?
            .replaceMatches(pattern: "\\^", replacementString: "[^\\\\-\\\\.\\\\%a-zA-Z0-9_]")?
            .replaceMatches(pattern: "\\*", replacementString: ".*")?
            .replaceMatches(pattern: "^\\|\\|", replacementString: "^[^\\\\/]+\\\\:\\\\/\\\\/([^\\\\/]+\\\\.)?")?
            .replaceMatches(pattern: "^\\|", replacementString: "^")?
            .replaceMatches(pattern: "\\|$", replacementString: "$")?
            .replaceMatches(pattern: "\\|", replacementString: "\\\\|")?
            .replaceMatches(pattern: "^\\.\\*", replacementString: "")?
            .replaceMatches(pattern: "\\.\\*$", replacementString: "") {
            rule = updatedRule
        }
        
        result[RuleKey] = rule
        return result
    }
}

protocol PrettyPrint {
    var stringValue: String { get }
}
