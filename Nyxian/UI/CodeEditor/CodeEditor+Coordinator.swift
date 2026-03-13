/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

import Foundation
import UIKit
import Runestone
@testable import Runestone

// MARK: - COORDINATOR
class Coordinator: NSObject, TextViewDelegate {
    private weak var parent: CodeEditorViewController?
    private var entries: [UInt64:(NeoButton?,UIView?)] = [:]
    private let entriesLock = NSLock()
    
    private(set) var isProcessing: Bool = false
    private(set) var isInvalidated: Bool = false
    private(set) var needsAnotherProcess: Bool = false

    private(set) var debounce: LDEDebouncer?
    private(set) var diag: [Synitem] = []
    private let vtkey: [(String,UIColor)] = [
        ("info.circle.fill", UIColor.blue.withAlphaComponent(0.3)),
        ("exclamationmark.triangle.fill", UIColor.orange.withAlphaComponent(0.3)),
        ("xmark.octagon.fill", UIColor.red.withAlphaComponent(0.3))
    ]
    
    init(parent: CodeEditorViewController) {
        self.parent = parent
        super.init()
        guard self.parent?.synpushServer != nil else { return }
        self.debounce = LDEDebouncer(delay: 1.5, with: DispatchQueue.main, withTarget: self, with: #selector(typecheckCode))
        if let textView = self.parent?.textView {
            self.textViewDidChange(textView)
        }
    }
    
    @objc func typecheckCode() {
        guard let textView = self.parent?.textView else { return }
        let text = textView.text
        self.isProcessing = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let parent = self.parent else { return }
            guard let server = parent.synpushServer else { return }
            
            parent.project?.projectConfig.reloadIfNeeded()
            let flags: [String] = parent.isReadOnly ? NXProjectConfig.sdkCompilerFlags() as! [String] : (parent.project?.projectConfig.compilerFlags as? [String] ?? [])

            server.reparseFile(text, withArgs: flags)
            self.diag = server.getDiagnostics()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isProcessing = false
                self.updateDiag()
            }
        }
    }
    

    func textViewDidChange(_ textView: TextView) {
        guard self.parent?.synpushServer != nil else { return }

        if !self.isInvalidated {
            self.isInvalidated = true
            self.entriesLock.lock()
            let currentEntries = self.entries
            self.entriesLock.unlock()

            for item in currentEntries {
                UIView.animate(withDuration: 0.3) {
                    item.value.1?.backgroundColor = UIColor.systemGray.withAlphaComponent(0.3)
                    item.value.0?.backgroundColor = UIColor.systemGray.withAlphaComponent(1.0)
                    item.value.0?.isUserInteractionEnabled = false
                    item.value.0?.errorview?.alpha = 0.0
                } completion: { _ in
                    item.value.0?.errorview?.removeFromSuperview()
                }
            }
        }
        
        self.redrawDiag()
        
        if self.isProcessing {
            self.needsAnotherProcess = true
            return
        }
        
        self.debounce?.debounce()
    }

    
    var isAutoIndenting = false
    
    func textView(_ textView: TextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if !isAutoIndenting,
           self.parent?.autoindent ?? false {
            guard text == "\n" else { return true }
            
            let nsText = textView.text as NSString
            
            let precedingText = nsText.substring(to: range.location)
            let unescapedQuotes = precedingText.reduce(0) { count, char in
                char == "\"" ? count + 1 : count
            }
            guard unescapedQuotes % 2 == 0 else { return true }

            let lineStart = precedingText.lastIndex(of: "\n").map {
                precedingText.distance(from: precedingText.startIndex, to: $0) + 1
            } ?? 0
            
            let previousLine = nsText.substring(with: NSRange(location: lineStart, length: range.location - lineStart))
            let leadingTabs = previousLine.prefix(while: { $0 == "\t" })
            var indent = String(leadingTabs)

            let previousLineContent = previousLine.trimmingCharacters(in: .whitespaces)
            let isOpeningBlock = previousLineContent.hasSuffix("{")

            if isOpeningBlock {
                indent += "\t"
            }
            
            let charAfterCursor: Character? = range.location < nsText.length
            ? Character(UnicodeScalar(nsText.character(at: range.location))!)
            : nil
            
            let insertion: String
            let cursorOffset: Int
            if charAfterCursor == "}" && isOpeningBlock {
                let deindent = indent.isEmpty ? "" : String(indent.dropLast())
                insertion = "\n" + indent + "\n" + deindent
                cursorOffset = 1 + indent.count
            } else if charAfterCursor == "}" && !indent.isEmpty {
                indent.removeLast()
                insertion = "\n" + indent
                cursorOffset = insertion.count
            } else {
                insertion = "\n" + indent
                cursorOffset = insertion.count
            }
            
            guard let textRange = textView.textRange(
                from: textView.position(from: textView.beginningOfDocument, offset: range.location)!,
                to: textView.position(from: textView.beginningOfDocument, offset: range.location + range.length)!
            ) else { return true }
            
            isAutoIndenting = true
            textView.replace(textRange, withText: insertion)
            isAutoIndenting = false
            
            let newCursorPos = range.location + cursorOffset
            if let pos = textView.position(from: textView.beginningOfDocument, offset: newCursorPos) {
                textView.selectedTextRange = textView.textRange(from: pos, to: pos)
            }
            
            return false
        }
        return true
    }
    
    func textViewDidChangeSelection(_ textView: TextView) {
        if self.isInvalidated {
            self.debounce?.debounce()
        }
    }
    
    func redrawDiag() {
        guard let parent = self.parent else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.entriesLock.lock()
            let currentEntries = self.entries
            self.entriesLock.unlock()

            if !currentEntries.isEmpty {
                for (line, views) in currentEntries {
                    guard let rect = parent.textView.rectForLine(Int(line)) else {
                        UIView.animate(withDuration: 0.3, animations: {
                            views.0?.alpha = 0
                            views.1?.alpha = 0
                        }, completion: { _ in
                            views.0?.removeFromSuperview()
                            views.1?.removeFromSuperview()
                            self.entriesLock.lock()
                            self.entries.removeValue(forKey: line)
                            self.entriesLock.unlock()
                        })
                        continue
                    }
                    views.0?.frame = CGRect(x: 0, y: rect.origin.y, width: parent.textView.gutterWidth, height: rect.height)
                    views.1?.frame = CGRect(x: 0, y: rect.origin.y, width: parent.textView.bounds.size.width, height: rect.height)
                }
            }
        }
    }
    func updateDiag() {
        guard let parent = self.parent else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.entriesLock.lock()
            let oldEntries = self.entries
            self.entries.removeAll()
            self.entriesLock.unlock()
            
            UIView.animate(withDuration: 0.3, animations: {
                for item in oldEntries {
                    item.value.0?.alpha = 0
                    item.value.1?.alpha = 0
                }
            }, completion: { _ in
                for item in oldEntries {
                    item.value.0?.removeFromSuperview()
                    item.value.1?.removeFromSuperview()
                }
                
                // Now add new diagnostics
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self = self else { return }
                    for item in self.diag {
                        var rect: CGRect?
                        DispatchQueue.main.sync {
                            rect = parent.textView.rectForLine(Int(item.line))
                        }
                        guard let lineRect = rect else { continue }

                        let properties = self.vtkey[Int(item.type)]

                        DispatchQueue.main.async {
                            self.entriesLock.lock()
                            if self.entries[item.line] != nil {
                                self.entriesLock.unlock()
                                return
                            }
                            self.entriesLock.unlock()

                            let view = UIView(frame: CGRect(x: 0, y: lineRect.origin.y, width: 3000, height: lineRect.height))
                            view.backgroundColor = properties.1
                            view.isUserInteractionEnabled = false
                            
                            let button = NeoButton(frame: CGRect(x: 0, y: lineRect.origin.y, width: parent.textView.gutterWidth, height: lineRect.height))
                            button.backgroundColor = properties.1.withAlphaComponent(1.0)
                            let configuration = UIImage.SymbolConfiguration(pointSize: parent.textView.theme.lineNumberFont.pointSize)
                            button.setImage(UIImage(systemName: properties.0, withConfiguration: configuration), for: .normal)
                            button.imageView?.tintColor = UIColor.systemBackground
                            
                            button.setAction { [weak self, weak button, weak parent] in
                                guard let self = self, let button = button, let parent = parent else { return }
                                button.stateview = !button.stateview
                                if button.stateview {
                                    let shift = parent.textView.gutterWidth
                                    let finalWidth = (parent.textView.bounds.width) / 1.5
                                    let preview = ErrorPreview(parent: self, frame: .zero, message: item.message, color: properties.1, minH: lineRect.height + 10)
                                    preview.translatesAutoresizingMaskIntoConstraints = false
                                    button.errorview = preview
                                    preview.alpha = 0

                                    parent.textView.addSubview(preview)
                                    let widthConstraint = preview.widthAnchor.constraint(equalToConstant: 0)
                                    NSLayoutConstraint.activate([
                                        preview.leadingAnchor.constraint(equalTo: parent.textView.leadingAnchor, constant: shift),
                                        preview.topAnchor.constraint(equalTo: parent.textView.topAnchor, constant: lineRect.origin.y),
                                        widthConstraint
                                    ])
                                    parent.textView.layoutIfNeeded()
                                    UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseOut], animations: {
                                        preview.alpha = 1
                                        widthConstraint.constant = finalWidth
                                        parent.textView.layoutIfNeeded()
                                    })
                                } else {
                                    if let preview = button.errorview {
                                        UIView.animate(withDuration: 0.3, animations: {
                                            preview.alpha = 0
                                        }, completion: { _ in
                                            preview.removeFromSuperview()
                                        })
                                    }
                                }
                            }
                            
                            view.alpha = 0
                            button.alpha = 0
                            
                            self.entriesLock.lock()
                            self.entries[item.line] = (button, view)
                            self.entriesLock.unlock()

                            if let textInputView = parent.textView.getTextInputView() {
                                textInputView.addSubview(view)
                                textInputView.sendSubviewToBack(view)
                                textInputView.gutterContainerView.isUserInteractionEnabled = true
                                textInputView.gutterContainerView.addSubview(button)
                            }

                            UIView.animate(withDuration: 0.3) {
                                view.alpha = 1
                                button.alpha = 1
                            }
                        }
                    }
                }
            })
        }
    }
    class ErrorPreview: UIView {
        var textView: UITextView
        var heigth: CGFloat = 0.0

        init(parent: Coordinator, frame: CGRect, message: String, color: UIColor, minH: CGFloat) {
            textView = UITextView()
            super.init(frame: .zero)

            self.backgroundColor = parent.parent?.textView.theme.gutterBackgroundColor
            self.layer.borderColor = color.withAlphaComponent(1.0).cgColor
            self.layer.borderWidth = 1
            self.layer.cornerRadius = 10
            self.layer.maskedCorners = [
                .layerMaxXMinYCorner,
                .layerMaxXMaxYCorner,
                .layerMinXMaxYCorner
            ]

            textView.translatesAutoresizingMaskIntoConstraints = false
            textView.text = message
            textView.font = parent.parent?.textView.theme.font
            textView.font = textView.font?.withSize((textView.font?.pointSize ?? 10) / 1.25)
            textView.textColor = UIColor.label
            textView.backgroundColor = .clear
            textView.isEditable = false
            textView.isScrollEnabled = false
            textView.textContainerInset = UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)

            self.addSubview(textView)

            NSLayoutConstraint.activate([
                textView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 8),
                textView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -8),
                textView.topAnchor.constraint(equalTo: self.topAnchor, constant: 8),
                textView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -8),
                self.heightAnchor.constraint(greaterThanOrEqualToConstant: minH)
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    class NeoButton: UIButton {
        var actionTap: () -> Void
        var stateview: Bool = false
        var errorview: ErrorPreview? = nil
        
        let hitTestEdgeInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
        
        override init(frame: CGRect) {
            self.actionTap = {}
            super.init(frame: frame)
            self.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                self.actionTap()
            }, for: UIControl.Event.touchDown)
        }
        
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            let relativeFrame = self.bounds
            let hitFrame = relativeFrame.inset(by: hitTestEdgeInsets)
            return hitFrame.contains(point)
        }
        
        func setAction(action: @escaping () -> Void) {
            self.actionTap = action
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func willMove(toSuperview newSuperview: UIView?) {
            if newSuperview == nil {
                if self.stateview {
                    actionTap()
                }
            }
            super.willMove(toSuperview: newSuperview)
        }
    }
}

// MARK: - Test
extension Runestone.TextView {
    func rectForLine(_ lineNumber: Int) -> CGRect? {
        let mirror = Mirror(reflecting: self)
        guard let lmAny = mirror.descendant("textInputView", "layoutManager"),
              let layoutManager = lmAny as? LayoutManager
        else {
            return nil
        }
        
        let lmMirror = Mirror(reflecting: layoutManager)
        guard let lineManager = lmMirror.descendant("lineManager") as? LineManager
        else {
            return nil
        }
        
        let index = lineNumber - 1
        guard index >= 0,
              index < lineManager.lineCount
        else {
            return nil
        }
        
        let targetLine = lineManager.line(atRow: lineNumber - 1)
        let endOffset = targetLine.location + targetLine.data.length
        layoutManager.layoutLines(toLocation: endOffset)
        
        let line = lineManager.line(atRow: index)
        
        let minY = line.yPosition
        let height = line.data.lineHeight
        let inset = layoutManager.textContainerInset
        let width = layoutManager.scrollViewWidth
        
        return CGRect(x: 0,
                      y: inset.top + minY,
                      width: width,
                      height: height)
    }
    
    func getTextInputView() -> TextInputView? {
        let mirror = Mirror(reflecting: self)
        guard let tiview = mirror.descendant("textInputView"),
              let textInputView = tiview as? TextInputView
        else {
            return nil
        }
        
        return textInputView
    }
}
