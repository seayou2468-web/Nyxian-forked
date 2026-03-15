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

#ifndef SURFACE_SYSCTL_H
#define SURFACE_SYSCTL_H

#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Syscall/mach_syscall_server.h>

/* --- sysctl constants --- */
#ifndef CTL_KERN
#define CTL_KERN 1
#endif
#ifndef CTL_HW
#define CTL_HW 6
#endif

/* KERN constants */
#ifndef KERN_OSTYPE
#define KERN_OSTYPE           1
#endif
#ifndef KERN_OSRELEASE
#define KERN_OSRELEASE        2
#endif
#ifndef KERN_OSVERSION
#define KERN_OSVERSION        3
#endif
#ifndef KERN_VERSION
#define KERN_VERSION          4
#endif
#ifndef KERN_MAXPROC
#define KERN_MAXPROC          6
#endif
#ifndef KERN_MAXFILES
#define KERN_MAXFILES         7
#endif
#ifndef KERN_HOSTNAME
#define KERN_HOSTNAME        10
#endif
#ifndef KERN_PROC
#define KERN_PROC            14
#endif
#ifndef KERN_NGROUPS
#define KERN_NGROUPS         18
#endif
#ifndef KERN_SAVED_IDS
#define KERN_SAVED_IDS       20
#endif
#ifndef KERN_BOOTARGS
#define KERN_BOOTARGS        38
#endif
#ifndef KERN_PROCARGS
#define KERN_PROCARGS        39
#endif
#ifndef KERN_PROCARGS2
#define KERN_PROCARGS2       49
#endif
#ifndef KERN_MAXFILESPERPROC
#define KERN_MAXFILESPERPROC 67
#endif
#ifndef KERN_OSPRODUCTVERSION
#define KERN_OSPRODUCTVERSION 70
#endif

/* KERN_PROC subtypes */
#ifndef KERN_PROC_ALL
#define KERN_PROC_ALL         0
#endif
#ifndef KERN_PROC_PID
#define KERN_PROC_PID         1
#endif
#ifndef KERN_PROC_RUID
#define KERN_PROC_RUID        2
#endif
#ifndef KERN_PROC_SESSION
#define KERN_PROC_SESSION     3
#endif
#ifndef KERN_PROC_UID
#define KERN_PROC_UID         5
#endif

/* HW constants */
#ifndef HW_MACHINE
#define HW_MACHINE            1
#endif
#ifndef HW_MODEL
#define HW_MODEL              2
#endif
#ifndef HW_NCPU
#define HW_NCPU               3
#endif
#ifndef HW_PAGESIZE
#define HW_PAGESIZE           7
#endif
#ifndef HW_OPTIONAL
#define HW_OPTIONAL           18
#endif
#ifndef HW_PHYSMEM
#define HW_PHYSMEM            19
#endif
#ifndef HW_USERMEM
#define HW_USERMEM            20
#endif
#ifndef HW_VECTORUNIT
#define HW_VECTORUNIT         22
#endif
#ifndef HW_BUS_FREQ
#define HW_BUS_FREQ           23
#endif
#ifndef HW_CPU_FREQ
#define HW_CPU_FREQ           24
#endif
#ifndef HW_CACHELINE
#define HW_CACHELINE          25
#endif
#ifndef HW_MEMSIZE
#define HW_MEMSIZE            27
#endif
#ifndef HW_TB_FREQ
#define HW_TB_FREQ            28
#endif
#ifndef HW_CPU_TYPE
#define HW_CPU_TYPE           30
#endif
#ifndef HW_CPU_SUBTYPE
#define HW_CPU_SUBTYPE        31
#endif
#ifndef HW_CPU_FAMILY
#define HW_CPU_FAMILY         32
#endif

/* --- sysctl request structure --- */
typedef struct {
    int name[20];
    u_int namelen;
    userspace_pointer_t oldp;
    userspace_pointer_t oldlenp;
    userspace_pointer_t newp;
    size_t newlen;
    errno_t err;
    task_t task;
    ksurface_proc_snapshot_t *proc_snapshot;
} sysctl_req_t;

/* --- sysctl handler function type --- */
typedef int (*sysctl_fn_t)(sysctl_req_t *req);

/* --- sysctl map entry structure --- */
typedef struct {
    int mib[20];
    size_t mib_len;
    sysctl_fn_t fn;
} sysctl_map_entry_t;

/* --- sysctl name map entry structure --- */
typedef struct {
    const char *name;
    int mib[20];
    size_t mib_len;
} sysctl_name_map_entry_t;

/* --- Dynamic Registration API --- */
void ksurface_sysctl_register(const int *mib, size_t mib_len, sysctl_fn_t fn);
void ksurface_sysctl_register_by_name(const char *name, const int *mib, size_t mib_len, sysctl_fn_t fn);
void ksurface_sysctl_cleanup(void);

DECLARE_SYSCALL_HANDLER(sysctl);
DECLARE_SYSCALL_HANDLER(sysctlbyname);

#endif /* SURFACE_SYSCTL_H */
