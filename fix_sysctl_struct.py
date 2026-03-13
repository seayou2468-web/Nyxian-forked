import sys
import re

file_path = 'Nyxian/LindChain/ProcEnvironment/Surface/sys/host/sysctl.m'
with open(file_path, 'r') as f:
    content = f.read()

# Fix sysctl_kern_boottime
content = content.replace(
    'int sysctl_kern_boottime(sysctl_req_t *req) { struct timeval tv = { .tv_sec = 1700000000, .tv_usec = 0 }; return sysctl_handle_string(req, (const char *)&tv); }',
    'int sysctl_kern_boottime(sysctl_req_t *req) { struct timeval tv = { .tv_sec = 1700000000, .tv_usec = 0 }; size_t len = sizeof(struct timeval); if (req->oldlenp) { if (req->oldp) { size_t oldlen = 0; if (!mach_syscall_copy_in(req->task, sizeof(size_t), &oldlen, req->oldlenp)) return -1; if (oldlen < len) { req->err = ENOMEM; return -1; } if (!mach_syscall_copy_out(req->task, len, &tv, req->oldp)) return -1; } if (!mach_syscall_copy_out(req->task, sizeof(size_t), &len, req->oldlenp)) return -1; } return 0; }'
)

with open(file_path, 'w') as f:
    f.write(content)
