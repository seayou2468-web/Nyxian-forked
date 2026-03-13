import sys
import re

file_path = 'Nyxian/Bootstrap.swift'
with open(file_path, 'r') as f:
    content = f.read()

# Add isBootstrapping flag
content = content.replace(
    'var semaphore: DispatchSemaphore?',
    'var semaphore: DispatchSemaphore?\n    private var isBootstrapping = false'
)

# Add guard in bootstrap()
bootstrap_guard = """
    @objc func bootstrap() {
        if isBootstrapping { return }
        isBootstrapping = true
        print("[*] checking upon nyxian bootstrap")
"""
content = re.sub(r'@objc func bootstrap\(\) \{.*?print\("\[\*\] checking upon nyxian bootstrap"\)', bootstrap_guard, content, flags=re.DOTALL)

# Reset flag in LDEPthreadDispatch completion (this is tricky because it's a trailing closure)
# I'll add it at the end of the block inside LDEPthreadDispatch
content = content.replace(
    'print("[*] done")',
    'print("[*] done")\n            self.isBootstrapping = false'
)

with open(file_path, 'w') as f:
    f.write(content)
