import sys

file_path = 'Nyxian/LindChain/ProcEnvironment/Surface/sys/host/sysctl.m'
with open(file_path, 'r') as f:
    content = f.read()

content = content.replace('"23.0.0"', '"25.0.0"')
content = content.replace('"23A123"', '"25A123"')
content = content.replace('Version 23.0.0: Fri Sep 15 14:41:34 PDT 2023; root:xnu-10002.1.13~1',
                          'Version 25.0.0: Fri Sep 12 14:41:34 PDT 2025; root:xnu-12000.1.13~1')

with open(file_path, 'w') as f:
    f.write(content)
