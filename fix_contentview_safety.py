import sys
import re

file_path = 'Nyxian/UI/ContentView.swift'
with open(file_path, 'r') as f:
    content = f.read()

# Add safety checks in documentPicker
safe_picker = """
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        do {
            guard let selectedURL = urls.first else { return }

            let extractFirst = URL(fileURLWithPath: "\\(NSTemporaryDirectory())Proj")
            if FileManager.default.fileExists(atPath: extractFirst.path) {
                try? FileManager.default.removeItem(at: extractFirst)
            }
            try FileManager.default.createDirectory(at: extractFirst, withIntermediateDirectories: true)

            if unzipArchiveAtPath(selectedURL.path, extractFirst.path) {
                let items = try FileManager.default.contentsOfDirectory(atPath: extractFirst.path)
                if let firstItem = items.first {
                    let projectPath = "\\(Bootstrap.shared.bootstrapPath("/Projects"))/\\(UUID().uuidString)"
                    try FileManager.default.moveItem(atPath: extractFirst.appendingPathComponent(firstItem).path, toPath: projectPath)

                    if let project = NXProject(path: projectPath) {
                        addProject(project)
                    }
                }
            } else {
                throw NSError(domain: "com.cr4zy.nyxian", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to unzip project archive"])
            }

            try? FileManager.default.removeItem(at: extractFirst)
        } catch {
            NotificationServer.NotifyUser(level: .error, notification: error.localizedDescription)
        }
    }
"""

# Re-escape for regex sub
safe_picker_repl = safe_picker.replace('\\', '\\\\')

content = re.sub(r'func documentPicker\(.*?\n    \}', safe_picker_repl, content, flags=re.DOTALL)

with open(file_path, 'w') as f:
    f.write(content)
