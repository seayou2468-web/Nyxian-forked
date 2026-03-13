import sys

file_path = 'Nyxian/LindChain/ProcEnvironment/Surface/radix/radix.c'
with open(file_path, 'r') as f:
    content = f.read()

content = content.replace(
    'uint64_t ident = ident_prefix | (i << ((RADIX_LEVELS - 1 - level) * RADIX_BITS));',
    'uint64_t ident = ident_prefix | ((uint64_t)i << ((RADIX_LEVELS - 1 - level) * RADIX_BITS));'
)

with open(file_path, 'w') as f:
    f.write(content)
