import sys
import re

file_path = 'Nyxian/LindChain/ProcEnvironment/Syscall/mach_syscall_server.m'
with open(file_path, 'r') as f:
    content = f.read()

if '#import <LindChain/ProcEnvironment/Utils/klog.h>' not in content:
    content = content.replace('#import <LindChain/ProcEnvironment/Syscall/mach_syscall_server.h>', '#import <LindChain/ProcEnvironment/Syscall/mach_syscall_server.h>\n#import <LindChain/ProcEnvironment/Utils/klog.h>')

# Add logging when handler is not found
log_unimplemented = """
        /* checking if the handler was set by the kernel virtualisation layer */
        if(!handler)
        {
            klog_log(@"syscall:server", @"unimplemented syscall %d from pid %d", req->syscall_num, xnu_pid);
            err = ENOSYS;
"""

# I need to get xnu_pid into the worker thread loop or re-extract it.
# Actually get_caller_proc_snapshot already does it, but doesn't return the pid.
# Let's modify get_caller_proc_snapshot or just re-extract in worker thread.

content = content.replace(
    '        /* checking if the handler was set by the kernel virtualisation layer */\n        if(!handler)\n        {\n            err = ENOSYS;',
    '        /* checking if the handler was set by the kernel virtualisation layer */\n        if(!handler)\n        {\n            pid_t xnu_pid_err = 0;\n            mach_msg_audit_trailer_t *trailer = (mach_msg_audit_trailer_t *)((uint8_t *)&(buffer->header) + buffer->header.msgh_size);\n            if (trailer->msgh_trailer_type == MACH_MSG_TRAILER_FORMAT_0 && trailer->msgh_trailer_size >= sizeof(mach_msg_audit_trailer_t)) {\n                xnu_pid_err = (pid_t)trailer->msgh_audit.val[5];\n            }\n            klog_log(@"syscall:server", @"unimplemented syscall %d from pid %d", req->syscall_num, xnu_pid_err);\n            err = ENOSYS;'
)

with open(file_path, 'w') as f:
    f.write(content)
