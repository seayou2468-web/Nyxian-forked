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

/* --- Dynamic Registration Structures --- */

typedef struct sysctl_node {
    char *name;
    int mib[20];
    size_t mib_len;
    sysctl_fn_t fn;
    struct sysctl_node *next;
} sysctl_node_t;

static sysctl_node_t *dynamic_sysctls = NULL;
static pthread_mutex_t sysctl_mutex = PTHREAD_MUTEX_INITIALIZER;

void ksurface_sysctl_register(const int *mib, size_t mib_len, sysctl_fn_t fn) {
    ksurface_sysctl_register_by_name(NULL, mib, mib_len, fn);
}

void ksurface_sysctl_register_by_name(const char *name, const int *mib, size_t mib_len, sysctl_fn_t fn) {
    pthread_mutex_lock(&sysctl_mutex);

    /* Check for duplicate */
    sysctl_node_t *curr = dynamic_sysctls;
    while (curr) {
        if (mib_len == curr->mib_len && memcmp(mib, curr->mib, mib_len * sizeof(int)) == 0) {
            pthread_mutex_unlock(&sysctl_mutex);
            return;
        }
        if (name && curr->name && strcmp(name, curr->name) == 0) {
            pthread_mutex_unlock(&sysctl_mutex);
            return;
        }
        curr = curr->next;
    }

    sysctl_node_t *node = malloc(sizeof(sysctl_node_t));
    if (node) {
        node->name = name ? strdup(name) : NULL;
        node->mib_len = mib_len;
        memcpy(node->mib, mib, mib_len * sizeof(int));
        node->fn = fn;
        node->next = dynamic_sysctls;
        dynamic_sysctls = node;
    }
    pthread_mutex_unlock(&sysctl_mutex);
}

/* --- Global Virtualized State (Writable) --- */
static int g_kern_maxfiles = 12288;
static int g_kern_maxfilesperproc = 10240;
static int g_kern_maxproc = 1000;

/* --- Utility Handlers --- */

int sysctl_handle_string(sysctl_req_t *req, const char *val) {
    if (req->oldlenp) {
        size_t len = strlen(val) + 1;
        size_t oldlen = 0;
        if (!mach_syscall_copy_in(req->task, sizeof(size_t), &oldlen, req->oldlenp)) return -1;
        if (req->oldp) {
            if (oldlen < len) { req->err = ENOMEM; return -1; }
            if (!mach_syscall_copy_out(req->task, len, val, req->oldp)) return -1;
        }
        if (!mach_syscall_copy_out(req->task, sizeof(size_t), &len, req->oldlenp)) return -1;
    }
    if (req->newp) {
        if (!entitlement_got_entitlement(proc_getentitlements(req->proc_snapshot), PEEntitlementHostManager)) { req->err = EPERM; return -1; }
        req->err = EINVAL; return -1;
    }
    return 0;
}

int sysctl_handle_int(sysctl_req_t *req, int *val_ptr) {
    if (req->oldlenp) {
        int val = *val_ptr;
        size_t len = sizeof(int);
        size_t oldlen = 0;
        if (!mach_syscall_copy_in(req->task, sizeof(size_t), &oldlen, req->oldlenp)) return -1;
        if (req->oldp) {
            if (oldlen < len) { req->err = ENOMEM; return -1; }
            if (!mach_syscall_copy_out(req->task, len, &val, req->oldp)) return -1;
        }
        if (!mach_syscall_copy_out(req->task, sizeof(size_t), &len, req->oldlenp)) return -1;
    }
    if (req->newp) {
        if (!entitlement_got_entitlement(proc_getentitlements(req->proc_snapshot), PEEntitlementHostManager)) { req->err = EPERM; return -1; }
        if (req->newlen != sizeof(int)) { req->err = EINVAL; return -1; }
        int new_val = 0;
        if (!mach_syscall_copy_in(req->task, sizeof(int), &new_val, req->newp)) return -1;
        *val_ptr = new_val;
    }
    return 0;
}

int sysctl_handle_int_const(sysctl_req_t *req, int val) {
    if (req->oldlenp) {
        size_t len = sizeof(int);
        size_t oldlen = 0;
        if (!mach_syscall_copy_in(req->task, sizeof(size_t), &oldlen, req->oldlenp)) return -1;
        if (req->oldp) {
            if (oldlen < len) { req->err = ENOMEM; return -1; }
            if (!mach_syscall_copy_out(req->task, len, &val, req->oldp)) return -1;
        }
        if (!mach_syscall_copy_out(req->task, sizeof(size_t), &len, req->oldlenp)) return -1;
    }
    if (req->newp) {
        if (!entitlement_got_entitlement(proc_getentitlements(req->proc_snapshot), PEEntitlementHostManager)) { req->err = EPERM; return -1; }
        req->err = EINVAL; return -1;
    }
    return 0;
}

int sysctl_handle_int64_const(sysctl_req_t *req, int64_t val) {
    if (req->oldlenp) {
        size_t len = sizeof(int64_t);
        size_t oldlen = 0;
        if (!mach_syscall_copy_in(req->task, sizeof(size_t), &oldlen, req->oldlenp)) return -1;
        if (req->oldp) {
            if (oldlen < len) { req->err = ENOMEM; return -1; }
            if (!mach_syscall_copy_out(req->task, len, &val, req->oldp)) return -1;
        }
        if (!mach_syscall_copy_out(req->task, sizeof(size_t), &len, req->oldlenp)) return -1;
    }
    if (req->newp) {
        if (!entitlement_got_entitlement(proc_getentitlements(req->proc_snapshot), PEEntitlementHostManager)) { req->err = EPERM; return -1; }
        req->err = EINVAL; return -1;
    }
    return 0;
}

/* --- Specific Handlers --- */

int sysctl_kern_maxfiles(sysctl_req_t *req) { return sysctl_handle_int(req, &g_kern_maxfiles); }
int sysctl_kern_maxfilesperproc(sysctl_req_t *req) { return sysctl_handle_int(req, &g_kern_maxfilesperproc); }
int sysctl_kernmaxproc(sysctl_req_t *req) { return sysctl_handle_int(req, &g_kern_maxproc); }

int sysctl_hw_cpu_type(sysctl_req_t *req) { return sysctl_handle_int_const(req, 0x0100000c); } // CPU_TYPE_ARM64
int sysctl_hw_cpu_subtype(sysctl_req_t *req) { return sysctl_handle_int_const(req, 2); } // CPU_SUBTYPE_ARM64_V8
int sysctl_hw_cpufamily(sysctl_req_t *req) { return sysctl_handle_int_const(req, 0x7e254e4c); } // A20
int sysctl_hw_vectorunit(sysctl_req_t *req) { return sysctl_handle_int_const(req, 1); }
int sysctl_hw_optional_floatingpoint(sysctl_req_t *req) { return sysctl_handle_int_const(req, 1); }
int sysctl_kern_bootargs(sysctl_req_t *req) { return sysctl_handle_string(req, "rootdev=/dev/disk0s1"); }

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
    pthread_rwlock_rdlock(&(ksurface->proc_info.struct_lock));
    kinfo_proc_t *kpbuf = NULL;
    ksurface_return_t ksr = proc_list(req->proc_snapshot, &kpbuf, &needed, flavour, req->name[3]);
    pthread_rwlock_unlock(&(ksurface->proc_info.struct_lock));
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

int sysctl_kern_proc_args(sysctl_req_t *req) {
    if (req->namelen != 3) { req->err = EINVAL; return -1; }
    pid_t pid = req->name[2];
    ksurface_proc_t *proc = NULL;
    if (proc_for_pid(pid, &proc) != SURFACE_SUCCESS) { req->err = ESRCH; return -1; }

    kvo_rdlock(proc);
    const char *path = proc->nyx.executable_path;
    size_t path_len = strlen(path) + 1;
    int argc = 1;
    size_t total_len = sizeof(int) + path_len;

    int ret = 0;
    if (req->oldlenp) {
        size_t oldlen = 0;
        if (!mach_syscall_copy_in(req->task, sizeof(size_t), &oldlen, req->oldlenp)) { ret = -1; goto out; }
        if (req->oldp) {
            if (oldlen < total_len) { req->err = ENOMEM; ret = -1; goto out; }
            if (!mach_syscall_copy_out(req->task, sizeof(int), &argc, req->oldp)) { ret = -1; goto out; }
            if (!mach_syscall_copy_out(req->task, path_len, path, (userspace_pointer_t)((char*)req->oldp + sizeof(int)))) { ret = -1; goto out; }
        }
        if (!mach_syscall_copy_out(req->task, sizeof(size_t), &total_len, req->oldlenp)) { ret = -1; goto out; }
    }

out:
    kvo_unlock(proc);
    kvo_release(proc);
    return ret;
}

bool is_valid_hostname_regex(const char *hostname)
{
    if(strnlen(hostname, 255) >= 255) return false;
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
    if(req->oldp) {
        pthread_rwlock_rdlock(&(ksurface->host_info.struct_lock));
        if(!mach_syscall_copy_out(req->task, strlen(ksurface->host_info.hostname) + 1, ksurface->host_info.hostname, req->oldp)) {
            pthread_rwlock_unlock(&(ksurface->host_info.struct_lock)); return -1;
        }
        pthread_rwlock_unlock(&(ksurface->host_info.struct_lock));
    }
    if(req->newp) {
        if(!entitlement_got_entitlement(proc_getentitlements(req->proc_snapshot), PEEntitlementHostManager)) { req->err = EPERM; return -1; }
        if(req->newlen > 255) { req->err = EINVAL; return -1; }
        char *newname = mach_syscall_alloc_in(req->task, req->newlen, req->newp);
        if(!newname) { req->err = EFAULT; return -1; }
        if(!is_valid_hostname_regex(newname)) { req->err = EINVAL; free(newname); return -1; }
        pthread_rwlock_wrlock(&(ksurface->host_info.struct_lock));
        strlcpy(ksurface->host_info.hostname, newname, req->newlen + 1);
        pthread_rwlock_unlock(&(ksurface->host_info.struct_lock));
        free(newname);
    }
    return 0;
}

int sysctl_hw_ncpu(sysctl_req_t *req) { return sysctl_handle_int_const(req, (int)[[NSProcessInfo processInfo] activeProcessorCount]); }
int sysctl_hw_pagesize(sysctl_req_t *req) { return sysctl_handle_int_const(req, (int)getpagesize()); }
int sysctl_hw_memsize(sysctl_req_t *req) { return sysctl_handle_int64_const(req, (int64_t)[[NSProcessInfo processInfo] physicalMemory]); }
int sysctl_hw_machine(sysctl_req_t *req) { return sysctl_handle_string(req, "iPhone15,4"); }
int sysctl_hw_model(sysctl_req_t *req) { return sysctl_handle_string(req, "iPhone15,4"); }
int sysctl_hw_cpufreq(sysctl_req_t *req) { return sysctl_handle_int64_const(req, 3200000000LL); }
int sysctl_hw_busfreq(sysctl_req_t *req) { return sysctl_handle_int64_const(req, 1000000000LL); }
int sysctl_hw_tbfreq(sysctl_req_t *req) { return sysctl_handle_int64_const(req, 24000000LL); }
int sysctl_hw_cachelinesize(sysctl_req_t *req) { return sysctl_handle_int_const(req, 64); }

int sysctl_kern_ostype(sysctl_req_t *req) { return sysctl_handle_string(req, "Darwin"); }
int sysctl_kern_osrelease(sysctl_req_t *req) { return sysctl_handle_string(req, "25.1.0"); }
int sysctl_kern_osversion(sysctl_req_t *req) { return sysctl_handle_string(req, "26D5034a"); }
int sysctl_kern_version(sysctl_req_t *req) { return sysctl_handle_string(req, "Darwin Kernel Version 25.1.0: Wed Feb 11 21:34:12 PST 2026; root:xnu-12000.1.13~1/RELEASE_ARM64_T8160"); }
int sysctl_kern_osproductversion(sysctl_req_t *req) { return sysctl_handle_string(req, "26.1"); }
int sysctl_kern_ngroups(sysctl_req_t *req) { return sysctl_handle_int_const(req, 16); }
int sysctl_kern_saved_ids(sysctl_req_t *req) { return sysctl_handle_int_const(req, 1); }

/* --- Map Definitions --- */

static const sysctl_map_entry_t sysctl_map[] = {
    { { CTL_KERN, KERN_OSPRODUCTVERSION       }, 2, sysctl_kern_osproductversion },
    { { CTL_KERN, KERN_OSVERSION              }, 2, sysctl_kern_osversion },
    { { CTL_KERN, KERN_OSRELEASE              }, 2, sysctl_kern_osrelease },
    { { CTL_KERN, KERN_OSTYPE                 }, 2, sysctl_kern_ostype },
    { { CTL_KERN, KERN_VERSION                }, 2, sysctl_kern_version },
    { { CTL_KERN, KERN_MAXFILES                }, 2, sysctl_kern_maxfiles },
    { { CTL_KERN, KERN_MAXFILESPERPROC         }, 2, sysctl_kern_maxfilesperproc },
    { { CTL_KERN, KERN_BOOTARGS               }, 2, sysctl_kern_bootargs },
    { { CTL_KERN, KERN_HOSTNAME                 }, 2, sysctl_kernhostname },
    { { CTL_KERN, KERN_MAXPROC                  }, 2, sysctl_kernmaxproc },
    { { CTL_KERN, KERN_PROC, KERN_PROC_ALL      }, 3, sysctl_kernproc },
    { { CTL_KERN, KERN_PROC, KERN_PROC_PID      }, 3, sysctl_kernproc },
    { { CTL_KERN, KERN_PROC, KERN_PROC_UID      }, 3, sysctl_kernproc },
    { { CTL_KERN, KERN_PROCARGS2               }, 2, sysctl_kern_proc_args },
    { { CTL_KERN, KERN_NGROUPS                  }, 2, sysctl_kern_ngroups },
    { { CTL_KERN, KERN_SAVED_IDS                }, 2, sysctl_kern_saved_ids },
    { { CTL_HW,   HW_CPU_TYPE                 }, 2, sysctl_hw_cpu_type },
    { { CTL_HW,   HW_CPU_SUBTYPE              }, 2, sysctl_hw_cpu_subtype },
    { { CTL_HW,   HW_CPU_FAMILY               }, 2, sysctl_hw_cpufamily },
    { { CTL_HW,   HW_VECTORUNIT               }, 2, sysctl_hw_vectorunit },
    { { CTL_HW,   HW_OPTIONAL, 1              }, 3, sysctl_hw_optional_floatingpoint },
    { { CTL_HW,   HW_NCPU                       }, 2, sysctl_hw_ncpu },
    { { CTL_HW,   HW_PAGESIZE                   }, 2, sysctl_hw_pagesize },
    { { CTL_HW,   HW_MEMSIZE                    }, 2, sysctl_hw_memsize },
    { { CTL_HW,   HW_MACHINE                    }, 2, sysctl_hw_machine },
    { { CTL_HW,   HW_MODEL                      }, 2, sysctl_hw_model },
    { { CTL_HW,   HW_CACHELINE                  }, 2, sysctl_hw_cachelinesize },
};

static const sysctl_name_map_entry_t sysctl_name_map[] = {
    { "kern.osproductversion",  { CTL_KERN, KERN_OSPRODUCTVERSION       }, 2 },
    { "kern.osrelease",         { CTL_KERN, KERN_OSRELEASE               }, 2 },
    { "kern.hostname",          { CTL_KERN, KERN_HOSTNAME                }, 2 },
    { "hw.machine",             { CTL_HW,   HW_MACHINE                   }, 2 },
    { "hw.model",               { CTL_HW,   HW_MODEL                     }, 2 },
    { "hw.cpufamily",           { CTL_HW,   HW_CPU_FAMILY                }, 2 },
};

/* --- Lookup Logic --- */

static sysctl_fn_t sysctl_lookup(sysctl_req_t *req)
{
    /* Check static map first */
    for (size_t i = 0; i < sizeof(sysctl_map)/sizeof(sysctl_map[0]); i++) {
        const sysctl_map_entry_t *e = &sysctl_map[i];
        if (req->namelen == e->mib_len) {
            bool match = true;
            for(size_t j = 0; j < e->mib_len; j++) if(req->name[j] != e->mib[j]) { match = false; break; }
            if(match) return e->fn;
        }
    }

    /* Check dynamic list */
    pthread_mutex_lock(&sysctl_mutex);
    sysctl_node_t *node = dynamic_sysctls;
    while (node) {
        if (req->namelen == node->mib_len) {
            bool match = true;
            for (size_t j = 0; j < node->mib_len; j++) if (req->name[j] != node->mib[j]) { match = false; break; }
            if (match) {
                sysctl_fn_t fn = node->fn;
                pthread_mutex_unlock(&sysctl_mutex);
                return fn;
            }
        }
        node = node->next;
    }
    pthread_mutex_unlock(&sysctl_mutex);

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

    /* Static name map */
    const sysctl_name_map_entry_t *found = NULL;
    for(size_t i = 0; i < sizeof(sysctl_name_map)/sizeof(sysctl_name_map[0]); i++) if(strcmp(name_buf, sysctl_name_map[i].name) == 0) { found = &sysctl_name_map[i]; break; }

    if (found) {
        sysctl_req_t req = { .name = {}, .namelen = (u_int)found->mib_len, .oldp = (userspace_pointer_t)args[1], .oldlenp = (userspace_pointer_t)args[2], .newp = (userspace_pointer_t)args[3], .newlen = (size_t)args[4], .err = 0, .task = sys_task_, .proc_snapshot = sys_proc_snapshot_ };
        memcpy(req.name, found->mib, found->mib_len * sizeof(int));
        free(name_buf);
        sysctl_fn_t fn = sysctl_lookup(&req);
        if(fn != NULL) { int ret = fn(&req); *err = req.err; return ret; }
        sys_return_failure(ENOSYS); // name_buf was freed
    } else {
        /* Dynamic registration search by name */
        pthread_mutex_lock(&sysctl_mutex);
        sysctl_node_t *node = dynamic_sysctls;
        while (node) {
            if (node->name && strcmp(name_buf, node->name) == 0) {
                sysctl_req_t req = { .name = {}, .namelen = (u_int)node->mib_len, .oldp = (userspace_pointer_t)args[1], .oldlenp = (userspace_pointer_t)args[2], .newp = (userspace_pointer_t)args[3], .newlen = (size_t)args[4], .err = 0, .task = sys_task_, .proc_snapshot = sys_proc_snapshot_ };
                memcpy(req.name, node->mib, node->mib_len * sizeof(int));
                sysctl_fn_t fn = node->fn;
                pthread_mutex_unlock(&sysctl_mutex);
                free(name_buf);
                int ret = fn(&req);
                *err = req.err;
                return ret;
            }
            node = node->next;
        }
        pthread_mutex_unlock(&sysctl_mutex);
    }

    free(name_buf);
    sys_return_failure(ENOSYS);
}

void ksurface_sysctl_cleanup(void) {
    pthread_mutex_lock(&sysctl_mutex);
    sysctl_node_t *node = dynamic_sysctls;
    while (node) {
        sysctl_node_t *next = node->next;
        if (node->name) free(node->name);
        free(node);
        node = next;
    }
    dynamic_sysctls = NULL;
    pthread_mutex_unlock(&sysctl_mutex);
}
