import sys
import re

file_path = 'Nyxian/LindChain/ProcEnvironment/Syscall/mach_syscall_server.m'
with open(file_path, 'r') as f:
    content = f.read()

# Ensure mach_port_deallocate is called on all paths
content = content.replace(
    '        /* getting callers identity from the payload */\n        ksurface_proc_snapshot_t *proc_snapshot = get_caller_proc_snapshot(&(buffer->header));\n        \n        /* null pointer check */\n        if(proc_snapshot == NULL)\n        {\n            /* checking if proc copy is null */\n            err = EAGAIN;\n            result = -1;\n            goto cleanup;\n        }',
    '        /* getting callers identity from the payload */\n        ksurface_proc_snapshot_t *proc_snapshot = get_caller_proc_snapshot(&(buffer->header));\n        \n        /* null pointer check */\n        if(proc_snapshot == NULL)\n        {\n            /* checking if proc copy is null */\n            err = EAGAIN;\n            result = -1;\n            /* reply must happen before goto cleanup because cleanup uses proc_snapshot */\n            send_reply(&(req->header), result, NULL, 0, err, false);\n            if (task != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(), task);\n            continue;\n        }'
)

with open(file_path, 'w') as f:
    f.write(content)
