//
// Copyright (c) 2017 Mario Negro Martín
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

// This was initially taken from:
// https://medium.com/@mario.negro.martin/easy-xib-and-storyboard-localization-b2794c69c9db
// It has been modified to be compatible with the elements we want to localize

import AppKit

// MARK: Localizable
public protocol Localizable {
    var localized: String { get }
}

extension String: Localizable {
    public var localized: String {
        return NSLocalizedString(self, comment: "")
    }
}

// MARK: XIBLocalizable
public protocol XIBLocalizable {
    var xibLocKey: String? { get set }
}

extension NSTextField: XIBLocalizable {
    @IBInspectable public var xibLocKey: String? {
        get { return nil }
        set(key) {
            stringValue = key?.localized ?? ""
        }
    }
    @IBInspectable public var xibLocKeyHTML: String? {
        get { return nil }
        set(key) {
            attributedStringValue = String(key?.localized ?? "").convertHTML()
        }
    }
    @IBInspectable public var xibLocKeyPlaceholder: String? {
        get { return nil }
        set(key) {
            placeholderString = key?.localized ?? ""
        }
    }
}

extension NSMenuItem: XIBLocalizable {
    @IBInspectable public var xibLocKey: String? {
        get { return nil }
        set(key) {
            title = key?.localized ?? ""
        }
    }
}

extension NSMenu: XIBLocalizable {
    @IBInspectable public var xibLocKey: String? {
        get { return nil }
        set(key) {
            title = key?.localized ?? ""
        }
    }
}

extension NSWindow: XIBLocalizable {
    @IBInspectable public var xibLocKey: String? {
        get { return nil }
        set(key) {
            title = key?.localized ?? ""
        }
    }
}

extension NSButton: XIBLocalizable {
    @IBInspectable public var xibLocKey: String? {
        get { return nil }
        set(key) {
            title = key?.localized ?? ""
        }
    }
}

extension Button {
    @IBInspectable override public var xibLocKey: String? {
        get { return nil }
        set(key) {
            attributedTitle = NSAttributedString(string: key?.localized ?? "", attributes: getAttributes())
        }
    }
}
