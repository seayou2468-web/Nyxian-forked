import sys
import re

file_path = 'Nyxian/LindChain/Multitask/ProcessManager/LDEProcessManager.m'
with open(file_path, 'r') as f:
    content = f.read()

# Add safety check for applicationObject launch allowed
content = content.replace(
    '    if(!applicationObject.isLaunchAllowed)\n    {\n        [NotificationServer NotifyUserWithLevel:NotifLevelError notification:[NSString stringWithFormat:@"\\"%@\\" Is No Longer Available", applicationObject.displayName] delay:0.0];\n        os_unfair_lock_unlock(&processes_array_lock);\n        return -1;\n    }',
    '    if(!applicationObject || !applicationObject.isLaunchAllowed)\n    {\n        [NotificationServer NotifyUserWithLevel:NotifLevelError notification:[NSString stringWithFormat:@"\\"%@\\" Is No Longer Available", applicationObject ? applicationObject.displayName : bundleIdentifier] delay:0.0];\n        os_unfair_lock_unlock(&processes_array_lock);\n        return -1;\n    }'
)

with open(file_path, 'w') as f:
    f.write(content)
