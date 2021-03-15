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

final class StackedTabSelectionController: NSObject {
    private unowned var stackView: NSStackView
    private unowned var tabView: NSTabView
    private var buttons: [StackedTabButton] = []
    
    init(stackView: NSStackView, tabView: NSTabView) {
        self.stackView = stackView
        self.tabView = tabView
        super.init()
        self.tabView.delegate = self
        connect()
    }

    func selectTab(at index: Int) {
        selectTab(buttons[index])
    }

    private func connect() {
        let isHorizontal = stackView.orientation == .horizontal
        stackView.alignment = (isHorizontal) ? .firstBaseline : .leading

        buttons = tabView.tabViewItems.map { [weak self] (item) in
            precondition(!item.label.isEmpty, "TabViewItem must have a label." )

            let index = tabView.tabViewItems.firstIndex(of: item)!
            let button = StackedTabButton(title: item.label, target: self, action: #selector(selectTab(_:)), tag: index)
            return button
        }

        stackView.setViews(buttons, in: isHorizontal ? .leading : .top)
        let selectedTab = UserDefaults.standard.integer(forKey: "selected.tab")
        if selectedTab < buttons.count { selectTab(at: selectedTab) }
    }

    @objc private func selectTab(_ sender: NSButton) {
        tabView.selectTabViewItem(at: sender.tag)
        UserDefaults.standard.setValue(sender.tag, forKey: "selected.tab")

        sender.state = .on
        for button in (buttons.filter { $0 != sender }) {
            button.state = .off
        }
    }

    private class StackedTabButton: NSButton {
        private static let NORMAL_FONT = NSFont(name: "LucidaGrande", size: 14)!
        private static let SELECTED_FONT = NSFont(name: "LucidaGrande-Bold", size: 14)!
        
        override var state: NSControl.StateValue {
            didSet {
                (cell as? NSButtonCell)?.backgroundColor = state == .on ? NSColor.white.withAlphaComponent(0.25) : .clear
                font = state == .on ? StackedTabButton.SELECTED_FONT : StackedTabButton.NORMAL_FONT
            }
        }

        convenience init(title: String, target: Any?, action: Selector?, tag: Int) {
            self.init(title: "\t\(NSLocalizedString(title, comment: ""))", target: target, action: action)
            self.configure()
            self.tag = tag
        }

        private func configure() {
            setButtonType(.onOff)
            font = StackedTabButton.NORMAL_FONT
            bezelStyle = .shadowlessSquare
            isBordered = false
            alignment = .left
            heightAnchor.constraint(equalToConstant: 60.0).isActive = true
            setContentHuggingPriority(NSLayoutConstraint.Priority(1.0), for: .horizontal)
            attributedTitle = NSAttributedString(string: title, attributes: [.foregroundColor: NSColor.white])
        }
    }
}

extension StackedTabSelectionController: NSTabViewDelegate {
    func tabViewDidChangeNumberOfTabViewItems(_ tabView: NSTabView) {
        connect()
    }
}
