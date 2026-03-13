import sys

file_path = 'Nyxian/LindChain/Project/NXProject.m'
with open(file_path, 'r') as f:
    content = f.read()

content = content.replace(
    '[defaultFileManager createDirectoryAtPath:[NSString stringWithFormat:@"%@%@", projectPath, directory] withIntermediateDirectories:NO attributes:NULL error:nil];',
    '[defaultFileManager createDirectoryAtPath:[NSString stringWithFormat:@"%@%@", projectPath, directory] withIntermediateDirectories:YES attributes:NULL error:nil];'
)

with open(file_path, 'w') as f:
    f.write(content)
