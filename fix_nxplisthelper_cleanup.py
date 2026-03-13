import sys
import re

file_path = 'Nyxian/LindChain/Project/NXPlistHelper.m'
with open(file_path, 'r') as f:
    content = f.read()

# Remove unreachable return
content = content.replace(
    '    return result;\n    return NULL;',
    '    return result;'
)

# Ensure _savedHash is initialized in all cases
content = content.replace(
    '_plistPath = plistPath;\n        _savedHash = [self currentHash];',
    '_plistPath = plistPath;\n        _savedHash = [self currentHash] ?: @"";'
)

with open(file_path, 'w') as f:
    f.write(content)
