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
import Punycode_Cocoa

// Filter objects representing the given filter text.
class FilterSet: NSObject {
    // Map from domain (e.g. 'mail.google.com', 'google.com', or special-case
    // 'global') to list of filters that specify inclusion on that domain.
    // E.g. /f/$domain=sub.foo.com,bar.com will appear in items['sub.foo.com']
    // and items['bar.com'].
    var items: [String: [Filter]]
    
    // Map from domain to set of filter ids that specify exclusion on that domain.
    // Each filter will also appear in this.items at least once.
    // Examples:
    //   /f/$domain=~foo.com,~bar.com would appear in
    //     items['global'], exclude['foo.com'], exclude['bar.com']
    //   /f/$domain=foo.com,~sub.foo.com would appear in
    //     items['foo.com'], exclude['sub.foo.com']
    var exclude: [String: [Int: Bool]] = [:]
    
    override init() {
        self.items = ["global" : []]
    }
    
    // Return a new FilterSet containing the subset of this FilterSet's entries
    // which relate to the given domain or any of its superdomains.  E.g.
    // sub.foo.com will get items['global', 'foo.com', 'sub.foo.com'] and
    // exclude['foo.com', 'sub.foo.com'].
    func viewFor(domain: String, matchGeneric: Bool) -> FilterSet {
        let result = FilterSet();
        if !matchGeneric {
            result.items["global"] = self.items["global"]
        }
        
        for (nextDomain, _) in DomainSet.domainAndParents(domain: domain) {
            if (self.items[nextDomain] != nil) {
                result.items[nextDomain] = self.items[nextDomain]
            }
            if (self.exclude[nextDomain] != nil) {
                result.exclude[nextDomain] = self.exclude[nextDomain]
            }
        }
        return result
    }
    
    // Get a list of all Filter objects that should be tested on the given
    // domain, and return it with the given map function applied. This function
    // is for hiding rules only
    func filtersFor(domain: String, matchGeneric: Bool) -> [String] {
        var result: [String] = []
        let unicodeDomain = domain.punycodeDecoded ?? domain
        let limited = self.viewFor(domain: unicodeDomain, matchGeneric: matchGeneric)
        var data: [Int: SelectorFilter] = [:]
        
        // data = set(limited.items)
        for (_, entry) in limited.items {
            for filter in entry {
                if let selectorFilter = filter as? SelectorFilter {
                    data[filter.id] = selectorFilter
                }
            }
        }
        
        // data -= limited.exclude
        for (_, entry) in limited.exclude {
            for (id, _) in entry {
                if let index = data.index(forKey: id) {
                    data.remove(at: index)
                }
            }
        }
        
        for (_, filter) in data {
            if let selector = filter.selector {
                result.append(selector)
            }
        }
        
        return result
    }
    
    // Get a list of all Filter objects that should be tested on the given
    // domain, and return it with the given map function applied. This function
    // is for advanced hiding rules only
    func advanceFiltersFor(domain: String, matchGeneric: Bool) -> [Filter] {
        var result: [Filter] = []
        let unicodeDomain = domain.punycodeDecoded ?? domain
        let limited = self.viewFor(domain: unicodeDomain, matchGeneric: matchGeneric)
        var data: [Int: Filter] = [:]
        
        // data = set(limited.items)
        for (_, entry) in limited.items {
            for filter in entry {
                data[filter.id] = filter
            }
        }
        
        // data -= limited.exclude
        for (_, entry) in limited.exclude {
            for (id, _) in entry {
                if let index = data.index(forKey: id) {
                    data.remove(at: index)
                }
            }
        }
        
        for (_, filter) in data {
            result.append(filter)
        }

        return result
    }
    
    // Return the filter that matches this url+elementType on this frameDomain:
    // the filter in a relevant entry in this.items who is not also in a
    // relevant entry in this.exclude.
    // isThirdParty: true if url and frameDomain have different origins.
    func matches(url: String, elementType: Int, frameDomain: String, isThirdParty: Bool, matchGeneric: Bool) -> Filter? {
        let limited = self.viewFor(domain: frameDomain, matchGeneric: matchGeneric)
        for (_, entry) in limited.items {
            for filter in entry {
                if let patternFilter = filter as? PatternFilter {
                    if (patternFilter.matches(url: url, elementType: elementType, isThirdParty: isThirdParty)) {
                        // Maybe filter shouldn't match because it is excluded on our domain?
                        var excluded = false
                        for (_, value) in limited.exclude {
                            if (value[patternFilter.id] ?? false) {
                                excluded = true
                                break
                            }
                        }
                        
                        if (!excluded) {
                            return patternFilter
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    // Construct a FilterSet from the Filters that are the values in the |data|
    // object.  All filters should be the same type (whitelisting PatternFilters,
    // blocking PatternFilters, or SelectorFilters.)
    static func fromFilters(data: [Int: Filter]) -> FilterSet {
        let result = FilterSet()
        
        for (_, filter) in data {
            for (domain, value) in filter.domains?.has ?? [:] {
                if value {
                    var domainKey = domain
                    if domain == DomainSet.ALL {
                        domainKey = "global"
                    }
                    if (result.items[domainKey] == nil) {
                        result.items[domainKey] = []
                    }
                    result.items[domainKey]?.append(filter)
                } else if domain != DomainSet.ALL {
                    if result.exclude[domain] == nil {
                        result.exclude[domain] = [:]
                    }
                    result.exclude[domain]?[filter.id] = true
                }
            }
        }
        return result
    }
}
