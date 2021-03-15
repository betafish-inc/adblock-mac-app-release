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

import WebKit
import Foundation
import SafariServices
import SwiftSoup
import SwiftyBeaver

class FilterNormalizer: NSObject {
    // Normalize a set of filters.
    // Remove broken filters, useless comments and unsupported things.
    // Input: text:string filter strings separated by '\n'
    //        keepComments:boolean if true, comments will not be removed
    // Returns: filter strings separated by '\n' with invalid filters
    //          removed or modified
    static func normalizeList(text: String, allowSnippets: Bool = false) -> String {
        let lines = text.split(separator: "\n").map(String.init)
        var result: [String] = []
        var ignoredFilterCount = 0
        for line in lines {
            do {
                let response = try FilterNormalizer.normalizeLine(filterText: line, allowSnippets: allowSnippets)
                if (response.ignoreFilter == false) &&
                    (response.notAFilter == false) {
                    if let filter = response.filter {
                        result.append(filter)
                    } else {
                        ignoredFilterCount += 1
                    }
                } else {
                    ignoredFilterCount += 1
                }
            } catch FilterRuleError.invalidContentFilterText(let sourceRule) {
                ignoredFilterCount += 1
                SwiftyBeaver.debug("[FILTER_NORMALIZER]: Invalid content filter text in source rule: \(sourceRule)")
            } catch FilterRuleError.invalidDomain(let domain) {
                ignoredFilterCount += 1
                SwiftyBeaver.debug("[FILTER_NORMALIZER]: Invalid domain: \(domain)")
            } catch FilterRuleError.invalidOption(let sourceRule, let unknownOption) {
                ignoredFilterCount += 1
                SwiftyBeaver.debug("[FILTER_NORMALIZER]: Invalid option: \(unknownOption) in sourceRule: \(sourceRule)")
            } catch FilterRuleError.invalidRegex(let sourceRule) {
                ignoredFilterCount += 1
                SwiftyBeaver.debug("[FILTER_NORMALIZER]: Invalid regex: \(sourceRule)")
            } catch FilterRuleError.invalidSelector(let sourceRule) {
                ignoredFilterCount += 1
                SwiftyBeaver.debug("[FILTER_NORMALIZER]: Invalid selector: \(sourceRule)")
            } catch FilterRuleError.snippetsNotAllowed(let sourceRule) {
                ignoredFilterCount += 1
                SwiftyBeaver.debug("[FILTER_NORMALIZER]: Snippets not allowed: \(sourceRule)")
            } catch {
                ignoredFilterCount += 1
                SwiftyBeaver.debug("[FILTER_NORMALIZER]: Unknown error")
            }
        }
        if ignoredFilterCount > 0 {
            SwiftyBeaver.debug("[FILTER_NORMALIZER]: ignored filters: \(ignoredFilterCount)")
        }
        return "\(result.joined(separator: "\n"))\n"
    }

    // Normalize a single filter.
    // Input: filter:string a single filter
    // Return: normalized filter string if the filter is valid, null if the filter
    //         will be ignored or false if it isn't supposed to be a filter.
    // Throws: exception if filter could not be parsed.
    //
    // Note that 'Expires' comments are considered valid comments that
    // need retention, because they carry information.
    // swiftlint:disable cyclomatic_complexity
    // TODO: reduce complexity of this function
    static func normalizeLine(filterText: String, allowSnippets: Bool = false) throws -> NormalizeLineResponse {
        var filter = filterText
        // Some rules are separated by \r\n; and hey, some rules may
        // have leading or trailing whitespace for some reason.
        
        if let updatedFilter = filter.replaceMatches(pattern: "\\r$", replacementString: "") {
            filter = updatedFilter
        }

        // Remove comment/empty filters.
        if Filter.isComment(text: filter) {
            return NormalizeLineResponse(filter: filter, ignoreFilter: false, notAFilter: true)
        }

        // Convert old-style hiding rules to new-style.
        if filter.range(of: "#[*a-z0-9_-]*(\\(|$)", options: .regularExpression) != nil &&
            (filter.range(of: "#@?#.", options: .regularExpression) == nil) &&
            !Filter.isContentFilter(text: filter) &&
            !Filter.isAdvancedSelectorFilter(text: filter) {
            // Throws exception if unparseable.
            filter = try FilterNormalizer.oldStyleHidingToNew(filterText: filter)
        }

        var parsedFilter: Filter?
        // If it is a hiding rule...
        if Filter.isSelectorFilter(text: filter) {
            // The filter must be of a correct syntax
            let selectorPart = filter.replaceMatches(pattern: "^.*?#@?\\??#", replacementString: "") ?? ""

            do {
                let html = "<html><head></head><body></body></html>"
                let doc: Document = try SwiftSoup.parse(html)
                _ = try doc.select("\(selectorPart),html")
            } catch {
                throw FilterRuleError.invalidSelector(sourceRule: filterText)
            }

            // On a few sites, we have to ignore [style] rules.
            // Affects Chrome (crbug 68705) and Safari (issue 6225).
            // Don't exclude the sites unless the filter would apply to them, or
            // loading the site will hang in Safari 6 while Safari creates a bunch of
            // one-off style sheets (issue 7356).
            if filter.range(of: "style([\\^$*]?=|\\])", options: .regularExpression) != nil {
                let excludedDomains = ["mail.google.com", "mail.yahoo.com"]
                filter = try FilterNormalizer.ensureExcluded(selectorFilterText: filter, excludedDomains: excludedDomains)
            }

            parsedFilter = SelectorFilter(text: filter)
        } else if Filter.isAdvancedSelectorFilter(text: filter) {
            parsedFilter = ElemHideEmulationFilter(text: filter)
        } else if Filter.isContentFilter(text: filter) {
            if Filter.isSnippetFilter(text: filter) && allowSnippets == false {
                throw FilterRuleError.snippetsNotAllowed(sourceRule: filterText) // snippets should be ignored
            }
            parsedFilter = Filter.fromText(text: filter)
        } else { // If it is a blocking rule...
            parsedFilter = PatternFilter.fromText(text: filter) as? PatternFilter
            var types = 0
            if let parsedPatternFilter = parsedFilter as? PatternFilter {
                types = parsedPatternFilter.allowedElementTypes ?? 0
                if let regexString = parsedPatternFilter.rule {
                    // Check for a '\d' any where in the regex
                    if regexString.contains("\\d") {
                        throw FilterRuleError.invalidRegex(sourceRule: filterText)
                    }
                    // Check for a '$' in any other place other the last character
                    if regexString.dropLast().contains("$") {
                        throw FilterRuleError.invalidRegex(sourceRule: filterText)
                    }
                    // Check for a single '|' in any other place other the last character
                    if regexString.contains("|") && !regexString.contains("||") {
                        throw FilterRuleError.invalidRegex(sourceRule: filterText)
                    }
                    // Check for a '{' in any other place other the first character
                    if regexString.dropFirst().contains("{") {
                        throw FilterRuleError.invalidRegex(sourceRule: filterText)
                    }
                }
            }

            let whitelistOptions = (ElementTypes["document"]! | ElementTypes["elemhide"]!)
            let hasWhitelistOptions = types & whitelistOptions
            if !Filter.isWhitelistFilter(text: filter) && (hasWhitelistOptions > 0) {
                throw FilterRuleError.invalidOption(sourceRule: filterText, unknownOption: "$document and $elemhide may only be used on whitelist filters")
            }
            if types == (types & ChromeOnlyElementTypes) {
                return NormalizeLineResponse(filter: filter, ignoreFilter: true, notAFilter: false)
            }
        }

        // Ignore filters whose domains aren't formatted properly.
        if let parsedFilterObject = parsedFilter, let parsedFilterDomains = parsedFilterObject.domains {
            try FilterNormalizer.verifyDomains(domainSet: parsedFilterDomains)
        }

        // Nothing's wrong with the filter.
        return NormalizeLineResponse(filter: filter, ignoreFilter: false, notAFilter: false)
    }

    // Return |selectorFilterText| modified if necessary so that it applies to no
    // domain in the |excludedDomains| list.
    // Throws if |selectorFilterText| is not a valid filter.
    // Example: ("a.com##div", ["sub.a.com", "b.com"]) -> "a.com,~sub.a.com##div"
    static func ensureExcluded(selectorFilterText: String, excludedDomains: [String]) throws -> String {
        var text = selectorFilterText
        let filter = SelectorFilter(text: text)
        let mustExclude = excludedDomains.filter {
            filter?.domains?.computedHas(domain: $0) ?? true
        }
        if !mustExclude.isEmpty {
            var toPrepend = "~\(mustExclude.joined(separator: ",~"))"
            if text.first != "#" {
                toPrepend += ","
            }
            text = toPrepend + text
        }
        return text
    }

    // Convert an old-style hiding rule to a new one.
    // Input: filter:string old-style filter
    // Returns: string new-style filter
    // Throws: exception if filter is unparseable.
    static func oldStyleHidingToNew(filterText: String) throws -> String {
        // Old-style is domain#node(attr=value) or domain#node(attr)
        // domain and node are optional, and there can be many () parts.
        var filter = filterText
        if let updatedFilter = filter.replaceMatches(pattern: "#", replacementString: "##") {
            filter = updatedFilter
        }
        var previousChar: Character = " "
        let parts = filter.split {
            var returnVal = false
            if previousChar == "#" && $0 == "#" {
                returnVal = true
            }
            previousChar = $0
            return returnVal
        }

        let domain = String(parts[0])
        var rule = ""
        if parts.count > 1 {
            rule = String(parts[1])
        }

        // Make sure the rule has only the following two things:
        // 1. a node -- this is optional and must be '*' or alphanumeric
        // 2. a series of ()-delimited arbitrary strings -- also optional
        //    the ()s can't be empty, and can't start with '='
        if (rule.isEmpty ||
            rule.range(of: "^(?:\\*|[a-z0-9\\-_]*)(?:\\([^=][^\\)]*?\\))*$", options: .regularExpression) == nil) {
            throw FilterRuleError.invalidSelector(sourceRule: rule)
        }

        let firstSegment = rule.range(of: "(")

        if firstSegment == nil {
            return "\(domain)##\(rule)"
        }
        let node = String(rule[..<(firstSegment?.lowerBound)!])
        var segments = String(rule[(firstSegment?.lowerBound)!...])
        
        // turn all (foo) groups into [foo]
        // turn all [foo=bar baz] groups into [foo="bar baz"]
        // Specifically match:    = then not " then anything till ]
        if let updatedSegments = segments.replaceMatches(pattern: "\\((.*?)\\)", replacementString: "[$1]")?
            .replaceMatches(pattern: "\\=([^\"][^\\]]*)", replacementString: "=\"$1\"") {
            segments = updatedSegments
        }
        // turn all [foo] into .foo, #foo
        // #div(adblock) means all divs with class or id adblock
        // class must be a single class, not multiple (not #*(ad listitem))
        // I haven't ever seen filters like #div(foo)(anotherfoo), so ignore these
        var resultFilter = node + segments
        let match = resultFilter.listGroups(pattern: "\\[([^\\=]*?)\\]") ?? []
        if !match.isEmpty {
            let part1 = resultFilter.replacingOccurrences(of: match[0], with: "#\(match[1])")
            let part2 = resultFilter.replacingOccurrences(of: match[0], with: ".\(match[1])")
            resultFilter = "\(part1),\(part2)"
        }

        return "\(domain)##\(resultFilter)"
    }
    // Throw an exception if the DomainSet |domainSet| contains invalid domains.
    static func verifyDomains(domainSet: DomainSet) throws {
        for (domain, _) in domainSet.has {
            if domain == DomainSet.ALL {
                continue
            }
            for codeUnit in domain.utf16 where codeUnit > 256 {
                throw FilterRuleError.invalidDomain(domain: domain)
            }
        }
    }
}

class NormalizeLineResponse {
    var filter: String?
    var ignoreFilter: Bool
    var notAFilter: Bool

    init(filter: String?, ignoreFilter: Bool, notAFilter: Bool) {
        self.filter = filter
        self.ignoreFilter = ignoreFilter
        self.notAFilter = notAFilter
    }
}
