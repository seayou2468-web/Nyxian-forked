import sys
import re

file_path = 'Nyxian/LindChain/ProcEnvironment/Surface/proc/fork.m'
with open(file_path, 'r') as f:
    content = f.read()

# Fix UAF in proc_exit
# The issue is accessing 'proc' after its last reference might have been consumed by kvo_release or proc_remove_by_pid
# But the code uses kvo_release(proc) then [process terminate]
# I'll reorder to terminate first.

content = content.replace(
    'proc_remove_by_pid(pid);  /* remove from global table */\n    \n    /* release our working reference */\n    kvo_release(proc);\n    \n    /* terminate process */\n    LDEProcess *process = [[LDEProcessManager shared].processes objectForKey:@(pid)];\n    if(process != NULL)\n    {\n        [process terminate];\n    }',
    '/* terminate process */\n    LDEProcess *process = [[LDEProcessManager shared].processes objectForKey:@(pid)];\n    if(process != NULL)\n    {\n        [process terminate];\n    }\n\n    proc_remove_by_pid(pid);  /* remove from global table */\n    \n    /* release our working reference */\n    kvo_release(proc);'
)

# Fix UAF in proc_zombify
content = content.replace(
    'kvo_unlock(proc);\n    kvo_release(proc);\n    \n    return SURFACE_SUCCESS;',
    'kvo_unlock(proc);\n    kvo_release(proc);\n    \n    return SURFACE_SUCCESS;'
)
# Actually proc_zombify seemed okay as long as it returns before 'proc' is used again.
# But let's check the recurse path.

with open(file_path, 'w') as f:
    f.write(content)
