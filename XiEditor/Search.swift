// Copyright 2017 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Cocoa
import Swift

class FindViewController: NSViewController, NSSearchFieldDelegate {
    var findDelegate: FindDelegate!

    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var navigationButtons: NSSegmentedControl!
    @IBOutlet weak var doneButton: NSButton!
    @IBOutlet weak var viewHeight: NSLayoutConstraint!

    var ignoreCase = true
    var wrapAround = true

    override func viewDidLoad() {
        // add recent searches menu items
        let menu = searchField.searchMenuTemplate!

        menu.addItem(NSMenuItem.separator())

        let recentTitle = NSMenuItem(title: "Recent Searches", action: nil, keyEquivalent: "")
        recentTitle.tag = Int(NSSearchFieldRecentsTitleMenuItemTag)
        menu.addItem(recentTitle)

        let recentItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        recentItem.tag = Int(NSSearchFieldRecentsMenuItemTag)
        menu.addItem(recentItem)

        menu.addItem(NSMenuItem.separator())

        let recentClear = NSMenuItem(title: "Clear Recent Searches", action: nil, keyEquivalent: "")
        recentClear.tag = Int(NSSearchFieldClearRecentsMenuItemTag)
        menu.addItem(recentClear)
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return true
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.cancelOperation(_:)):
            // overriding cancelOperation is not enough, because the first Esc would just clear the
            // search field and not call cancelOperation
            findDelegate.closeFind()
            return true
        default:
            return false
        }
    }

    @IBAction func selectIgnoreCaseMenuAction(_ sender: NSMenuItem) {
        ignoreCase = !ignoreCase
        sender.state = ignoreCase ? NSOnState : NSOffState

        findDelegate.find(searchField.stringValue, caseSensitive: !ignoreCase)
        findDelegate.findNext(wrapAround: wrapAround, allowSame: true)
    }
    
    @IBAction func selectWrapAroundMenuAction(_ sender: NSMenuItem) {
        wrapAround = !wrapAround
        sender.state = wrapAround ? NSOnState : NSOffState
    }

    @IBAction func segmentControlAction(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            findDelegate.findPrevious(wrapAround: wrapAround)
        case 1:
            findDelegate.findNext(wrapAround: wrapAround, allowSame: false)
        default:
            break
        }
    }

    @IBAction func searchFieldAction(_ sender: NSSearchField) {
        findDelegate.find(sender.stringValue, caseSensitive: !ignoreCase)
        findDelegate.findNext(wrapAround: wrapAround, allowSame: false)
    }

    override func cancelOperation(_ sender: Any?) {
        findDelegate.closeFind()
    }
}

extension EditViewController {
    func openFind() {
        if findViewController.view.isHidden {
            findViewController.view.isHidden = false

            let offset = findViewController.viewHeight.constant
            scrollView.contentInsets = NSEdgeInsetsMake(offset, 0, 0, 0)
            updateShadowPosition(offset: offset)

            if !findViewController.searchField.stringValue.isEmpty {
                find(findViewController.searchField.stringValue,
                     caseSensitive: !findViewController.ignoreCase)
            }
        }

        findViewController.searchField.becomeFirstResponder()
    }

    func closeFind() {
        if !findViewController.view.isHidden {
            findViewController.view.isHidden = true
            clearFind()

            scrollView.contentInsets = NSEdgeInsetsZero
            updateShadowPosition(offset: 0)
        }

        editView.window?.makeFirstResponder(editView)
    }

    fileprivate func updateShadowPosition(offset: CGFloat) {
        shadowView.topOffset = offset
        shadowView?.updateScroll(scrollView.contentView.bounds,
                                 scrollView.documentView!.bounds)
        gutterView.needsDisplay = true

    }

    func findNext(wrapAround: Bool, allowSame: Bool) {
        var params = ["wrap_around": wrapAround]
        if allowSame {
            params["allow_same"] = true
        }
        document.sendRpcAsync("find_next", params: params)
    }

    func findPrevious(wrapAround: Bool) {
        document.sendRpcAsync("find_previous", params: [
            "wrap_around": wrapAround
        ])
    }

    func find(_ term: String?, caseSensitive: Bool) {
        var params: [String: Any] = [
            "case_sensitive": caseSensitive,
        ]

        if term != nil {
            params["chars"] = term
            document.sendRpcAsync("find", params: params) { _ in }
        } else {
            document.sendRpcAsync("find", params: params) { (result: Any?) in
                DispatchQueue.main.async {
                    self.findViewController.searchField.stringValue = result as! String
                }
            }
        }
    }

    func clearFind() {
        document.sendRpcAsync("find", params: ["chars": ""]) { _ in }
    }

    @IBAction func performCustomFinderAction(_ sender: Any?) {
        guard let tag = (sender as AnyObject).value(forKey: "tag") as? Int,
            let action = NSTextFinderAction(rawValue: tag) else { return }

        switch action {
        case .showFindInterface:
            openFind()

        case .hideFindInterface:
            closeFind()

        case .nextMatch:
            findNext(wrapAround: findViewController.wrapAround, allowSame: false)

        case .previousMatch:
            findPrevious(wrapAround: findViewController.wrapAround)

        case .replaceAll:
            Swift.print("replaceAll not implemented")

        case .replace:
            Swift.print("replace not implemented")

        case .replaceAndFind:
            Swift.print("replaceAndFind not implemented")

        case .setSearchString:
            openFind()
            self.find(nil, caseSensitive: !findViewController.ignoreCase)

        case .replaceAllInSelection:
            Swift.print("replaceAllInSelection not implemented")

        case .selectAll:
            Swift.print("selectAll not implemented")

        case .selectAllInSelection:
            Swift.print("selectAllInSelection not implemented")

        case .showReplaceInterface:
            Swift.print("showReplaceInterface not implemented")
            
        case .hideReplaceInterface:
            Swift.print("hideReplaceInterface not implemented")
        }
    }
}

class FindSearchField: NSSearchField {
    required init?(coder: NSCoder) {
        super.init(coder: coder)

        // Workaround: needs to be set here and not in FindViewController, otherwise
        // the menu/dropdown arrow wouldn't be visible
        centersPlaceholder = false

        sendsSearchStringImmediately = true
    }
}
