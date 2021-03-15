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

// DomainSet: a subset of all domains.
//
// It can represent any subset of all domains.  Some examples:
//  - all domains
//  - all domains except foo
//  - only sub.foo
//  - only a, b, and c, excluding sub.a or sub.b (but including sub.sub.b)
//
// Create a new DomainSet from the given |data|.
//
// Each key in |data| is a subdomain, domain, or the required pseudodomain
// "DomainSet.ALL" which represents all domains.
// Each value is true/false, meaning "This domain is/is not in the set, and
// all of its subdomains not otherwise mentioned are/are not in the set."

import Foundation

class DomainSet: NSObject {
    static let ALL = ""
    var has: [String: Bool] = [:]
    
    var stringValue: String {
        var returnString = "DomainSet:"
        for (key, value) in has {
            var domain = key
            if domain.isEmpty {
                domain = "All"
            }
            returnString += " domain: \(domain) : \(String(value))"
        }
        return returnString
    }
    
    init(data: [String: Bool]) {
        if data[DomainSet.ALL] != nil {
            self.has = data
        }
    }

    static func parentDomainOf(domain: String) -> String {
        return domain.replaceMatches(pattern: "^.+?(?:\\.|$)", replacementString: "") ?? ""
    }

    static func domainAndParents(domain: String) -> [String: Bool] {
        var result: [String: Bool] = [:]
        
        _ = domain.split(separator: ".").reversed().reduce("") { (last, part) in
            var next: String
            if !last.isEmpty {
                next = "\(String(part)).\(last)"
            } else {
                next = "\(String(part))"
            }
            result[next] = true
            return next
        }
        
        return result
    }

    func clone() -> DomainSet {
        return DomainSet(data: has)
    }

    // Modify |this| by set-subtracting |other|.
    // |this| will contain the subset that was in |this| but not in |other|.
    // swiftlint:disable identifier_name
    func subtract(other: DomainSet) {
        func subtract_operator(a: Bool, b: Bool) -> Bool {
            return a && !b
        }
        apply(funcOperator: subtract_operator, other: other)
    }

    // NB: If we needed them, intersect and union are just like subtract, but use
    // a&&b and a||b respectively.  Union could be used to add two DomainSets.

    // Modify |this| to be the result of applying the given set |operator| (a
    // 2-param boolean function) to |this| and |other|. Returns undefined.
    private func apply(funcOperator: ((Bool, Bool) -> Bool), other: DomainSet) {
        // Make sure there's an entry in .has for every entry in other.has, so
        // that we examine every pairing in the next for loop.
        for (d, _) in other.has {
            self.has[d] = self.computedHas(domain: d)
        }
        // Apply the set operation to each pair of entries.  Use
        // other._computedHas() to derive any missing other.has entries.
        for (d, value) in self.has {
            self.has[d] = funcOperator(value, other.computedHas(domain: d))
        }
        // Optimization: get rid of redundant entries that now exist in this.has.
        // E.g. if DomainSet.ALL, a, and sub.a all = true, delete the last 2.
        var newHas: [String: Bool] = [:]
        newHas[DomainSet.ALL] = self.has[DomainSet.ALL]
        for (d, value) in self.has {
            if value != self.computedHas(domain: DomainSet.parentDomainOf(domain: d)) {
                newHas[d] = self.has[d]
            }
        }
        self.has = newHas
    }

    // True if |domain| is in the subset of all domains represented by |this|.
    //
    // E.g. if |this| DomainSet is the set of all domains other than a, then 'b'
    // will yield true, and both 'a' and 'sub.a' will yield false.
    func computedHas(domain: String) -> Bool {
        if let tempDomain = has[domain] {
            return tempDomain
        } else {
            return computedHas(domain: DomainSet.parentDomainOf(domain: domain))
        }
    }
}
