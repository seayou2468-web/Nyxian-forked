import sys

file_path = 'Nyxian/LindChain/Utils/LDEThreadController.m'
with open(file_path, 'r') as f:
    content = f.read()

content = content.replace(
    'int next = atomic_fetch_add(&_nextWorker, 1);\n    int workerIndex = (next < 0 ? -next : next) % _workerCount;',
    'unsigned int next = (unsigned int)atomic_fetch_add(&_nextWorker, 1);\n    int workerIndex = next % _workerCount;'
)

with open(file_path, 'w') as f:
    f.write(content)
