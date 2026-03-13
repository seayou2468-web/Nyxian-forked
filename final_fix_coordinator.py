import sys
import re

file_path = 'Nyxian/UI/CodeEditor/CodeEditor+Coordinator.swift'
with open(file_path, 'r') as f:
    lines = f.readlines()

new_lines = []
skip = False
for line in lines:
    if 'private var entries: [UInt64:(NeoButton?,UIView?)] = [:]' in line:
        new_lines.append(line)
        new_lines.append('    private let entriesLock = NSLock()\n')
        continue

    if 'func redrawDiag()' in line:
        new_lines.append("""    func redrawDiag() {
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
""")
        skip = True
    elif 'func updateDiag()' in line:
        new_lines.append("""    func updateDiag() {
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
""")
        skip = True
    elif 'class ErrorPreview' in line:
        skip = False
        new_lines.append(line)
    elif not skip:
        new_lines.append(line)

with open(file_path, 'w') as f:
    f.writelines(new_lines)
