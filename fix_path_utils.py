import sys
import re

# Fix LDEFilesFinder.m
finder_path = 'Nyxian/LindChain/Core/LDEFilesFinder.m'
with open(finder_path, 'r') as f:
    content = f.read()
content = content.replace(
    'NSString *fullPath = [searchPath stringByAppendingFormat:@"/%@", relativePath];',
    'NSString *fullPath = [searchPath stringByAppendingPathComponent:relativePath];'
)
with open(finder_path, 'w') as f:
    f.write(content)

# Fix NXProject.m (one instance was missed/risky)
project_path = 'Nyxian/LindChain/Project/NXProject.m'
with open(project_path, 'r') as f:
    content = f.read()
content = content.replace(
    'NXProject *project = [[NXProject alloc] initWithPath:[NSString stringWithFormat:@"%@/%@",path,entry]];',
    'NXProject *project = [[NXProject alloc] initWithPath:[path stringByAppendingPathComponent:entry]];'
)
with open(project_path, 'w') as f:
    f.write(content)

# Safer string conversion in Synpush.m
synpush_path = 'Nyxian/LindChain/Synpush/Synpush.m'
with open(synpush_path, 'r') as f:
    content = f.read()
content = content.replace(
    'item.message = [NSString stringWithFormat:@"%s", cmsg ?: "Unknown"];',
    'item.message = cmsg ? [NSString stringWithUTF8String:cmsg] : @"Unknown";'
)
with open(synpush_path, 'w') as f:
    f.write(content)
