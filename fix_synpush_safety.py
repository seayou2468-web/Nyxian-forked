import sys

file_path = 'Nyxian/LindChain/Synpush/Synpush.m'
with open(file_path, 'r') as f:
    content = f.read()

# Add null check for strdup
content = content.replace(
    '_args[i] = strdup([args[i] UTF8String]);',
    'const char *utf8 = [args[i] UTF8String]; _args[i] = utf8 ? strdup(utf8) : strdup("");'
)

with open(file_path, 'w') as f:
    f.write(content)
