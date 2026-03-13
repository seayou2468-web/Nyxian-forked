import sys
import re

file_path = 'Nyxian/LindChain/Utils/LDEThreadController.m'
with open(file_path, 'r') as f:
    content = f.read()

# Fix potential negative index when atomic_fetch_add overflows
content = content.replace(
    'int workerIndex = atomic_fetch_add(&_nextWorker, 1) % _workerCount;',
    'int next = atomic_fetch_add(&_nextWorker, 1);\n    int workerIndex = (next < 0 ? -next : next) % _workerCount;'
)

with open(file_path, 'w') as f:
    f.write(content)
