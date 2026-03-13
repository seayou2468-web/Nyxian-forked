import sys
import re

file_path = 'Nyxian/LindChain/Multitask/ProcessManager/LDEProcess.m'
with open(file_path, 'r') as f:
    content = f.read()

# Replace dispatch_sync with dispatch_async to avoid deadlocks
# Especially inside a callback that might be on a thread waiting for main
content = content.replace(
    'dispatch_sync(dispatch_get_main_queue(), ^{',
    'dispatch_async(dispatch_get_main_queue(), ^{'
)

with open(file_path, 'w') as f:
    f.write(content)
