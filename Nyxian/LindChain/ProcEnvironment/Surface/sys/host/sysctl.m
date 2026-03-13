/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <LindChain/ProcEnvironment/Surface/sys/host/sysctl.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/proc/list.h>
#import <LindChain/ProcEnvironment/Surface/proc/lookup.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Surface/obj/kvobject.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <regex.h>
#import <sys/sysctl.h>

/* --- Utility Handlers --- */

int sysctl_handle_string(sysctl_req_t *req, const char *val) {
    size_t len = strlen(val) + 1;
    if (req->oldlenp) {
        size_t oldlen = 0;
        if (!mach_syscall_copy_in(req->task, sizeof(size_t), &oldlen, req->oldlenp)) return -1;
        if (req->oldp) {
            if (oldlen < len) { req->err = ENOMEM; return -1; }
            if (!mach_syscall_copy_out(req->task, len, val, req->oldp)) return -1;
        }
        if (!mach_syscall_copy_out(req->task, sizeof(size_t), &len, req->oldlenp)) return -1;
    }
    return 0;
}

int sysctl_handle_int(sysctl_req_t *req, int val) {
    size_t len = sizeof(int);
    if (req->oldlenp) {
        if (req->oldp) {
            size_t oldlen = 0;
            if (!mach_syscall_copy_in(req->task, sizeof(size_t), &oldlen, req->oldlenp)) return -1;
            if (oldlen < len) { req->err = ENOMEM; return -1; }
            if (!mach_syscall_copy_out(req->task, len, &val, req->oldp)) return -1;
        }
        if (!mach_syscall_copy_out(req->task, sizeof(size_t), &len, req->oldlenp)) return -1;
    }
    return 0;
}

int sysctl_handle_int64(sysctl_req_t *req, int64_t val) {
    size_t len = sizeof(int64_t);
    if (req->oldlenp) {
        if (req->oldp) {
            size_t oldlen = 0;
            if (!mach_syscall_copy_in(req->task, sizeof(size_t), &oldlen, req->oldlenp)) return -1;
            if (oldlen < len) { req->err = ENOMEM; return -1; }
            if (!mach_syscall_copy_out(req->task, len, &val, req->oldp)) return -1;
        }
        if (!mach_syscall_copy_out(req->task, sizeof(size_t), &len, req->oldlenp)) return -1;
    }
    return 0;
}

/* --- Sysctl Functions --- */

int sysctl_kernmaxproc(sysctl_req_t *req) { return sysctl_handle_int(req, 1000); }

int sysctl_kernproc(sysctl_req_t *req)
{
    proc_flavour_t flavour;
    size_t user_outlen = 0, needed = 0;
    switch(req->name[2])
    {
        case KERN_PROC_ALL: flavour = PROC_FLV_ALL; break;
        case KERN_PROC_UID: flavour = PROC_FLV_UID; goto validate;
        case KERN_PROC_RUID: flavour = PROC_FLV_RUID; goto validate;
        case KERN_PROC_SESSION: flavour = PROC_FLV_SID; goto validate;
        case KERN_PROC_PID: flavour = PROC_FLV_PID;
        validate:
            if(!req->oldlenp || req->namelen != 4) { req->err = EINVAL; return -1; }
            break;
        default: req->err = EINVAL; return -1;
    }
    if(req->oldlenp && !mach_syscall_copy_in(req->task, sizeof(size_t), &user_outlen, req->oldlenp)) { req->err = EFAULT; return -1; }
    proc_table_rdlock();
    kinfo_proc_t *kpbuf = NULL;
    ksurface_return_t ksr = proc_list(req->proc_snapshot, &kpbuf, &needed, flavour, req->name[3]);
    proc_table_unlock();
    if(ksr != SURFACE_SUCCESS || needed == 0) { req->err = ENOMEM; if(kpbuf) free(kpbuf); return -1; }
    if(req->oldp == NULL) {
        if(!mach_syscall_copy_out(req->task, sizeof(size_t), &needed, req->oldlenp)) { req->err = EFAULT; free(kpbuf); return -1; }
        free(kpbuf); return 0;
    }
    if(user_outlen < needed) {
        mach_syscall_copy_out(req->task, sizeof(size_t), &needed, req->oldlenp);
        req->err = ENOMEM; free(kpbuf); return -1;
    }
    if(!mach_syscall_copy_out(req->task, needed, kpbuf, req->oldp) || !mach_syscall_copy_out(req->task, sizeof(size_t), &needed, req->oldlenp)) {
        req->err = EFAULT; free(kpbuf); return -1;
    }
    free(kpbuf); return 0;
}

bool is_valid_hostname_regex(const char *hostname)
{
    if(strnlen(hostname, MAXHOSTNAMELEN) >= MAXHOSTNAMELEN) return false;
    static regex_t *regex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = malloc(sizeof(regex_t));
        if(regex && regcomp(regex, "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.)*[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$", REG_EXTENDED) != 0) {
            free(regex); regex = NULL;
        }
    });
    return regex && (regexec(regex, hostname, 0, NULL, 0) == 0);
}

int sysctl_kernhostname(sysctl_req_t *req)
{
    if(req->oldp || req->oldlenp) {
        host_rdlock();
        int ret = sysctl_handle_string(req, ksurface->host_info.hostname);
        host_unlock();
        if (ret != 0) return ret;
    }
    if(req->newp && req->newlen) {
        if(!entitlement_got_entitlement(proc_getentitlements(req->proc_snapshot), PEEntitlementHostManager)) { req->err = EPERM; return -1; }
        if(req->newlen > MAXHOSTNAMELEN) { req->err = EINVAL; return -1; }
        char *newname = mach_syscall_alloc_in(req->task, req->newlen, req->newp);
        if(!newname) { req->err = EFAULT; return -1; }
        if(!is_valid_hostname_regex(newname)) { req->err = EINVAL; free(newname); return -1; }
        host_wrlock();
        strlcpy(ksurface->host_info.hostname, newname, req->newlen + 1);
        [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithCString:ksurface->host_info.hostname encoding:NSUTF8StringEncoding] forKey:@"LDEHostname"];
        host_unlock();
        free(newname);
    }
    return 0;
}

int sysctl_hw_ncpu(sysctl_req_t *req) { return sysctl_handle_int(req, (int)[[NSProcessInfo processInfo] activeProcessorCount]); }
int sysctl_hw_pagesize(sysctl_req_t *req) { return sysctl_handle_int(req, (int)getpagesize()); }
int sysctl_hw_memsize(sysctl_req_t *req) { return sysctl_handle_int64(req, (int64_t)[[NSProcessInfo processInfo] physicalMemory]); }
int sysctl_hw_machine(sysctl_req_t *req) { return sysctl_handle_string(req, "arm64"); }
int sysctl_hw_model(sysctl_req_t *req) { return sysctl_handle_string(req, "iPhone14,5"); }
int sysctl_hw_cpufreq(sysctl_req_t *req) { return sysctl_handle_int64(req, 3200000000LL); }
int sysctl_hw_busfreq(sysctl_req_t *req) { return sysctl_handle_int64(req, 1000000000LL); }
int sysctl_hw_tbfreq(sysctl_req_t *req) { return sysctl_handle_int64(req, 24000000LL); }
int sysctl_hw_cachelinesize(sysctl_req_t *req) { return sysctl_handle_int(req, 64); }
int sysctl_hw_l1icachesize(sysctl_req_t *req) { return sysctl_handle_int(req, 131072); }
int sysctl_hw_l1dcachesize(sysctl_req_t *req) { return sysctl_handle_int(req, 65536); }
int sysctl_hw_l2cachesize(sysctl_req_t *req) { return sysctl_handle_int(req, 4194304); }

int sysctl_kern_ostype(sysctl_req_t *req) { return sysctl_handle_string(req, "Darwin"); }
int sysctl_kern_osrelease(sysctl_req_t *req) { return sysctl_handle_string(req, "25.0.0"); }
int sysctl_kern_osversion(sysctl_req_t *req) { return sysctl_handle_string(req, "25A123"); }
int sysctl_kern_version(sysctl_req_t *req) { return sysctl_handle_string(req, "Darwin Kernel Version 25.0.0: Fri Sep 12 14:41:34 PDT 2025; root:xnu-12000.1.13~1/RELEASE_ARM64_T8103"); }
int sysctl_kern_osvariant_status(sysctl_req_t *req) { return sysctl_handle_int64(req, 0); }
int sysctl_kern_ngroups(sysctl_req_t *req) { return sysctl_handle_int(req, 16); }
int sysctl_kern_saved_ids(sysctl_req_t *req) { return sysctl_handle_int(req, 1); }
int sysctl_kern_boottime(sysctl_req_t *req) { struct timeval tv = { .tv_sec = 1700000000, .tv_usec = 0 }; return sysctl_handle_string(req, (const char *)&tv); } /* Needs better handle for struct */

/* --- Map Definitions --- */

static const sysctl_map_entry_t sysctl_map[] = {
    { { CTL_KERN, KERN_HOSTNAME                 }, 2, sysctl_kernhostname },
    { { CTL_KERN, KERN_MAXPROC                  }, 2, sysctl_kernmaxproc },
    { { CTL_KERN, KERN_PROC, KERN_PROC_ALL      }, 3, sysctl_kernproc },
    { { CTL_KERN, KERN_PROC, KERN_PROC_SESSION  }, 3, sysctl_kernproc },
    { { CTL_KERN, KERN_PROC, KERN_PROC_PID      }, 3, sysctl_kernproc },
    { { CTL_KERN, KERN_PROC, KERN_PROC_UID      }, 3, sysctl_kernproc },
    { { CTL_KERN, KERN_PROC, KERN_PROC_RUID     }, 3, sysctl_kernproc },
    { { CTL_KERN, KERN_OSTYPE                   }, 2, sysctl_kern_ostype },
    { { CTL_KERN, KERN_OSRELEASE                }, 2, sysctl_kern_osrelease },
    { { CTL_KERN, KERN_OSVERSION                }, 2, sysctl_kern_osversion },
    { { CTL_KERN, KERN_VERSION                  }, 2, sysctl_kern_version },
    { { CTL_KERN, KERN_NGROUPS                  }, 2, sysctl_kern_ngroups },
    { { CTL_KERN, KERN_SAVED_IDS                }, 2, sysctl_kern_saved_ids },
    { { CTL_KERN, 71 /* KERN_OSVARIANT_STATUS */}, 2, sysctl_kern_osvariant_status },
    { { CTL_HW,   HW_NCPU                       }, 2, sysctl_hw_ncpu },
    { { CTL_HW,   HW_PAGESIZE                   }, 2, sysctl_hw_pagesize },
    { { CTL_HW,   HW_MEMSIZE                    }, 2, sysctl_hw_memsize },
    { { CTL_HW,   HW_MACHINE                    }, 2, sysctl_hw_machine },
    { { CTL_HW,   HW_MODEL                      }, 2, sysctl_hw_model },
    { { CTL_HW,   HW_PHYSMEM                    }, 2, sysctl_hw_memsize },
    { { CTL_HW,   HW_USERMEM                    }, 2, sysctl_hw_memsize },
    { { CTL_HW,   HW_CACHELINE                  }, 2, sysctl_hw_cachelinesize },
    { { CTL_HW,   HW_CPU_FREQ                   }, 2, sysctl_hw_cpufreq },
    { { CTL_HW,   HW_BUS_FREQ                   }, 2, sysctl_hw_busfreq },
    { { CTL_HW,   HW_TB_FREQ                    }, 2, sysctl_hw_tbfreq },
};

static const sysctl_name_map_entry_t sysctl_name_map[] = {
    { "kern.hostname",          { CTL_KERN, KERN_HOSTNAME                }, 2 },
    { "kern.maxproc",           { CTL_KERN, KERN_MAXPROC                 }, 2 },
    { "kern.proc.all",          { CTL_KERN, KERN_PROC, KERN_PROC_ALL     }, 3 },
    { "kern.ostype",            { CTL_KERN, KERN_OSTYPE                  }, 2 },
    { "kern.osrelease",         { CTL_KERN, KERN_OSRELEASE               }, 2 },
    { "kern.osversion",         { CTL_KERN, KERN_OSVERSION               }, 2 },
    { "kern.version",           { CTL_KERN, KERN_VERSION                 }, 2 },
    { "kern.ngroups",           { CTL_KERN, KERN_NGROUPS                 }, 2 },
    { "kern.saved_ids",         { CTL_KERN, KERN_SAVED_IDS               }, 2 },
    { "kern.osvariant_status",  { CTL_KERN, 71                           }, 2 },
    { "hw.ncpu",                { CTL_HW,   HW_NCPU                      }, 2 },
    { "hw.activecpu",           { CTL_HW,   HW_NCPU                      }, 2 },
    { "hw.physicalcpu",         { CTL_HW,   HW_NCPU                      }, 2 },
    { "hw.logicalcpu",          { CTL_HW,   HW_NCPU                      }, 2 },
    { "hw.pagesize",            { CTL_HW,   HW_PAGESIZE                  }, 2 },
    { "hw.memsize",             { CTL_HW,   HW_MEMSIZE                   }, 2 },
    { "hw.machine",             { CTL_HW,   HW_MACHINE                   }, 2 },
    { "hw.model",               { CTL_HW,   HW_MODEL                     }, 2 },
    { "hw.cpufrequency",        { CTL_HW,   HW_CPU_FREQ                  }, 2 },
    { "hw.busfrequency",        { CTL_HW,   HW_BUS_FREQ                  }, 2 },
    { "hw.tbfrequency",         { CTL_HW,   HW_TB_FREQ                   }, 2 },
    { "hw.cachelinesize",       { CTL_HW,   HW_CACHELINE                 }, 2 },
    { "hw.l1icachesize",        { CTL_HW,   74                           }, 2 },
    { "hw.l1dcachesize",        { CTL_HW,   75                           }, 2 },
    { "hw.l2cachesize",         { CTL_HW,   76                           }, 2 },
};

/* --- Main Implementation --- */

static sysctl_fn_t sysctl_lookup(sysctl_req_t *req)
{
    for (size_t i = 0; i < sizeof(sysctl_map)/sizeof(sysctl_map[0]); i++) {
        const sysctl_map_entry_t *e = &sysctl_map[i];
        if (req->namelen < e->mib_len) continue;
        bool match = true;
        for(size_t j = 0; j < e->mib_len; j++) if(req->name[j] != e->mib[j]) { match = false; break; }
        if(match) return e->fn;
    }
    if (req->name[0] == CTL_HW) {
        if (req->name[1] == 74) return sysctl_hw_l1icachesize;
        if (req->name[1] == 75) return sysctl_hw_l1dcachesize;
        if (req->name[1] == 76) return sysctl_hw_l2cachesize;
    }
    return NULL;
}

DEFINE_SYSCALL_HANDLER(sysctl)
{
    sysctl_req_t req = { .name = {}, .namelen = (u_int)args[1], .oldp = (userspace_pointer_t)args[2], .oldlenp = (userspace_pointer_t)args[3], .newp = (userspace_pointer_t)args[4], .newlen = (size_t)args[5], .err = 0, .task = sys_task_, .proc_snapshot = sys_proc_snapshot_ };
    if(req.namelen > 20) sys_return_failure(E2BIG);
    if(!mach_syscall_copy_in(sys_task_, req.namelen * sizeof(int), &(req.name), (userspace_pointer_t)args[0])) sys_return_failure(EFAULT);
    sysctl_fn_t fn = sysctl_lookup(&req);
    if(fn != NULL) { int ret = fn(&req); *err = req.err; return ret; }
    sys_return_failure(ENOSYS);
}

DEFINE_SYSCALL_HANDLER(sysctlbyname)
{    
    char *name_buf = mach_syscall_copy_str_in(sys_task_, (userspace_pointer_t)args[0], 128);
    if(name_buf == NULL) sys_return_failure(EINVAL);
    const sysctl_name_map_entry_t *found = NULL;
    for(size_t i = 0; i < sizeof(sysctl_name_map)/sizeof(sysctl_name_map[0]); i++) if(strcmp(name_buf, sysctl_name_map[i].name) == 0) { found = &sysctl_name_map[i]; break; }
    free(name_buf);
    if(found == NULL) sys_return_failure(ENOSYS);
    sysctl_req_t req = { .name = {}, .namelen = (u_int)found->mib_len, .oldp = (userspace_pointer_t)args[1], .oldlenp = (userspace_pointer_t)args[2], .newp = (userspace_pointer_t)args[3], .newlen = (size_t)args[4], .err = 0, .task = sys_task_, .proc_snapshot = sys_proc_snapshot_ };
    memcpy(req.name, found->mib, found->mib_len * sizeof(int));
    sysctl_fn_t fn = sysctl_lookup(&req);
    if(fn != NULL) { int ret = fn(&req); *err = req.err; return ret; }
    sys_return_failure(ENOSYS);
}
