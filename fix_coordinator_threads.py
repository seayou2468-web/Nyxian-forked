import sys
import re

file_path = 'Nyxian/UI/CodeEditor/CodeEditor+Coordinator.swift'
with open(file_path, 'r') as f:
    content = f.read()

# Fix textView.text access and isProcessing/isInvalidated in typecheckCode
typecheck_new = """
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
"""

content = re.sub(r'func typecheckCode\(\) \{.*?\}', typecheck_new, content, flags=re.DOTALL)

# Fix textViewDidChange to be safer
did_change_new = """
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
"""
content = re.sub(r'func textViewDidChange\(.*?\n    \}', did_change_new, content, flags=re.DOTALL)

with open(file_path, 'w') as f:
    f.write(content)
