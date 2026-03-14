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

/* --- sysctl constants --- */
#ifndef CTL_KERN
#define CTL_KERN 1
#endif
#ifndef CTL_HW
#define CTL_HW 6
#endif

/* KERN constants */
#define KERN_OSTYPE           1
#define KERN_OSRELEASE        2
#define KERN_OSVERSION        3
#define KERN_VERSION          4
#define KERN_MAXPROC          6
#define KERN_MAXFILES         7
#define KERN_HOSTNAME        10
#define KERN_PROC            14
#define KERN_NGROUPS         18
#define KERN_SAVED_IDS       20
#define KERN_BOOTARGS        38
#define KERN_PROCARGS        39
#define KERN_PROCARGS2       49
#define KERN_MAXFILESPERPROC 67
#define KERN_OSPRODUCTVERSION 70

/* KERN_PROC subtypes */
#define KERN_PROC_ALL         0
#define KERN_PROC_PID         1
#define KERN_PROC_RUID        2
#define KERN_PROC_SESSION     3
#define KERN_PROC_UID         5

/* HW constants */
#define HW_MACHINE            1
#define HW_MODEL              2
#define HW_NCPU               3
#define HW_PAGESIZE           7
#define HW_OPTIONAL           18
#define HW_PHYSMEM            19
#define HW_USERMEM            20
#define HW_VECTORUNIT         22
#define HW_BUS_FREQ           23
#define HW_CPU_FREQ           24
#define HW_CACHELINE          25
#define HW_MEMSIZE            27
#define HW_TB_FREQ            28
#define HW_CPU_TYPE           30
#define HW_CPU_SUBTYPE        31
#define HW_CPU_FAMILY         32

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

DEFINE_SYSCALL_HANDLER(sysctl);
DEFINE_SYSCALL_HANDLER(sysctlbyname);

#endif /* SURFACE_SYSCTL_H */
