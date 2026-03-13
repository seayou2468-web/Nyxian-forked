import sys
import re

file_path = 'Nyxian/LindChain/ProcEnvironment/Surface/sys/host/sysctl.m'
with open(file_path, 'r') as f:
    content = f.read()

# Add new sysctl handlers
new_handlers = """
int sysctl_hw_string(sysctl_req_t *req, const char *val)
{
    if(req->oldp && req->oldlenp)
    {
        size_t len = strlen(val) + 1;
        size_t oldlen = 0;
        if(!mach_syscall_copy_in(req->task, sizeof(size_t), &oldlen, req->oldlenp)) return -1;
        if(oldlen < len) { req->err = ENOMEM; return -1; }
        if(!mach_syscall_copy_out(req->task, len, val, req->oldp)) return -1;
        if(!mach_syscall_copy_out(req->task, sizeof(size_t), &len, req->oldlenp)) return -1;
    }
    return 0;
}

int sysctl_hw_int(sysctl_req_t *req, int val)
{
    if(req->oldp && req->oldlenp)
    {
        size_t len = sizeof(int);
        if(!mach_syscall_copy_out(req->task, len, &val, req->oldp)) return -1;
        if(!mach_syscall_copy_out(req->task, sizeof(size_t), &len, req->oldlenp)) return -1;
    }
    return 0;
}

int sysctl_hw_int64(sysctl_req_t *req, int64_t val)
{
    if(req->oldp && req->oldlenp)
    {
        size_t len = sizeof(int64_t);
        if(!mach_syscall_copy_out(req->task, len, &val, req->oldp)) return -1;
        if(!mach_syscall_copy_out(req->task, sizeof(size_t), &len, req->oldlenp)) return -1;
    }
    return 0;
}

int sysctl_hw_ncpu(sysctl_req_t *req) { return sysctl_hw_int(req, (int)[[NSProcessInfo processInfo] activeProcessorCount]); }
int sysctl_hw_pagesize(sysctl_req_t *req) { return sysctl_hw_int(req, (int)getpagesize()); }
int sysctl_hw_memsize(sysctl_req_t *req) { return sysctl_hw_int64(req, (int64_t)[[NSProcessInfo processInfo] physicalMemory]); }
int sysctl_hw_machine(sysctl_req_t *req) { return sysctl_hw_string(req, "arm64"); }
int sysctl_hw_model(sysctl_req_t *req) { return sysctl_hw_string(req, "iPhone"); }
int sysctl_kern_ostype(sysctl_req_t *req) { return sysctl_hw_string(req, "Darwin"); }
int sysctl_kern_osrelease(sysctl_req_t *req) { return sysctl_hw_string(req, "23.0.0"); }
int sysctl_kern_osversion(sysctl_req_t *req) { return sysctl_hw_string(req, "23A123"); }
"""

# Find a good place to insert handlers (before sysctl_map)
content = content.replace('/* sysctl map entries */', new_handlers + '\n/* sysctl map entries */')

# Update sysctl_map
new_map_entries = """    { { CTL_KERN, KERN_HOSTNAME                 }, 2, sysctl_kernhostname },
    { { CTL_KERN, KERN_MAXPROC                  }, 2, sysctl_kernmaxproc },
    { { CTL_KERN, KERN_PROC, KERN_PROC_ALL      }, 3, sysctl_kernproc },
    { { CTL_KERN, KERN_PROC, KERN_PROC_SESSION  }, 3, sysctl_kernproc },
    { { CTL_KERN, KERN_PROC, KERN_PROC_PID      }, 3, sysctl_kernproc },
    { { CTL_KERN, KERN_PROC, KERN_PROC_UID      }, 3, sysctl_kernproc },
    { { CTL_KERN, KERN_PROC, KERN_PROC_RUID     }, 3, sysctl_kernproc },
    { { CTL_HW,   HW_NCPU                       }, 2, sysctl_hw_ncpu },
    { { CTL_HW,   HW_PAGESIZE                   }, 2, sysctl_hw_pagesize },
    { { CTL_HW,   HW_MEMSIZE                    }, 2, sysctl_hw_memsize },
    { { CTL_HW,   HW_MACHINE                    }, 2, sysctl_hw_machine },
    { { CTL_HW,   HW_MODEL                      }, 2, sysctl_hw_model },
    { { CTL_KERN, KERN_OSTYPE                   }, 2, sysctl_kern_ostype },
    { { CTL_KERN, KERN_OSRELEASE                }, 2, sysctl_kern_osrelease },
    { { CTL_KERN, KERN_OSVERSION                }, 2, sysctl_kern_osversion },"""

content = re.sub(r'static const sysctl_map_entry_t sysctl_map\[\] = \{.*?\};',
                 'static const sysctl_map_entry_t sysctl_map[] = {\n' + new_map_entries + '\n};',
                 content, flags=re.DOTALL)

# Update sysctl_name_map
new_name_entries = """    { "kern.hostname",          { CTL_KERN, KERN_HOSTNAME                }, 2 },
    { "kern.maxproc",           { CTL_KERN, KERN_MAXPROC                 }, 2 },
    { "kern.proc.all",          { CTL_KERN, KERN_PROC, KERN_PROC_ALL     }, 3 },
    { "hw.ncpu",                { CTL_HW,   HW_NCPU                      }, 2 },
    { "hw.pagesize",            { CTL_HW,   HW_PAGESIZE                  }, 2 },
    { "hw.memsize",             { CTL_HW,   HW_MEMSIZE                   }, 2 },
    { "hw.machine",             { CTL_HW,   HW_MACHINE                   }, 2 },
    { "hw.model",               { CTL_HW,   HW_MODEL                     }, 2 },
    { "kern.ostype",            { CTL_KERN, KERN_OSTYPE                  }, 2 },
    { "kern.osrelease",         { CTL_KERN, KERN_OSRELEASE               }, 2 },
    { "kern.osversion",         { CTL_KERN, KERN_OSVERSION               }, 2 },"""

content = re.sub(r'static const sysctl_name_map_entry_t sysctl_name_map\[\] = \{.*?\};',
                 'static const sysctl_name_map_entry_t sysctl_name_map[] = {\n' + new_name_entries + '\n};',
                 content, flags=re.DOTALL)

with open(file_path, 'w') as f:
    f.write(content)
