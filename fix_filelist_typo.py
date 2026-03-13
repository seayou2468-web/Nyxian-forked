import sys

file_path = 'Nyxian/UI/FileList/FileList.swift'
with open(file_path, 'r') as f:
    content = f.read()

content = content.replace('cachePath!))/debug.json', 'cachePath!)/debug.json')

with open(file_path, 'w') as f:
    f.write(content)
