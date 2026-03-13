import sys
import re

file_path = 'Nyxian/LindChain/ProcEnvironment/Object/MachOObject.m'
with open(file_path, 'r') as f:
    content = f.read()

# Fix error capturing and potential hang in signBinaryAtPath
content = content.replace(
    '[LCUtils signAppBundleWithZSign:[NSURL fileURLWithPath:bundlePath] completionHandler:^(BOOL succeeded, NSError *error){\n        error = error;\n        dispatch_semaphore_signal(sema);\n    }];',
    '[LCUtils signAppBundleWithZSign:[NSURL fileURLWithPath:bundlePath] completionHandler:^(BOOL succeeded, NSError *handlerError){\n        error = handlerError;\n        dispatch_semaphore_signal(sema);\n    }];'
)

# Fix signAndWriteBack too
content = content.replace(
    '[LCUtils signAppBundleWithZSign:[NSURL fileURLWithPath:bundlePath] completionHandler:^(BOOL succeeded, NSError *error){\n        error = error;\n        dispatch_semaphore_signal(sema);\n    }];',
    '[LCUtils signAppBundleWithZSign:[NSURL fileURLWithPath:bundlePath] completionHandler:^(BOOL succeeded, NSError *handlerError){\n        error = handlerError;\n        dispatch_semaphore_signal(sema);\n    }];'
)

with open(file_path, 'w') as f:
    f.write(content)
