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

DEFINE_SYSCALL_HANDLER(sysctl);
DEFINE_SYSCALL_HANDLER(sysctlbyname);

#endif /* SURFACE_SYSCTL_H */
