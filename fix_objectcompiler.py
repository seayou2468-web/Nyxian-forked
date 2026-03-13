import sys
import re

file_path = 'Nyxian/LindChain/Compiler/ObjectCompiler.cpp'
with open(file_path, 'r') as f:
    content = f.read()

if '#include <mutex>' not in content:
    content = content.replace('#include "clang/Basic/Diagnostic.h"', '#include <mutex>\n#include "clang/Basic/Diagnostic.h"')

new_compile_start = """
static std::mutex compileMutex;

int CompileObject(int argc,
                  const char **argv,
                  const char *outputFilePath,
                  const char *platformTriple,
                  char **errorStringSet)
{
    std::lock_guard<std::mutex> lock(compileMutex);
"""

content = re.sub(r'int CompileObject\(.*?\) \{', new_compile_start, content, flags=re.DOTALL)

with open(file_path, 'w') as f:
    f.write(content)
