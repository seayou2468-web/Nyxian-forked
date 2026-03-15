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

#import <Foundation/Foundation.h>
#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/ProcEnvironment/syscall.h>
#import <LindChain/ProcEnvironment/proxy.h>
#import <LindChain/ProcEnvironment/libproc.h>
#import <LindChain/litehook/litehook.h>
#import <LindChain/LiveContainer/Tweaks/libproc.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/sys/host/proc_flags.h>

DEFINE_HOOK(proc_listallpids, int, (void *buffer,
                                    int buffersize))
{
    if(buffersize < 0)
    {
        errno = EINVAL;
        return -1;
    }
    
    environment_must_be_role(EnvironmentRoleGuest);
    
    return (int)environment_syscall(SYS_proc_info, PROC_INFO_CALL_LISTPIDS, 0, 0, 0, buffer, (uint32_t)buffersize);
}

DEFINE_HOOK(proc_listpids, int, (uint32_t type,
                                 uint32_t flavor,
                                 void *buffer,
                                 int buffersize))
{
    environment_must_be_role(EnvironmentRoleGuest);
    return (int)environment_syscall(SYS_proc_info, PROC_INFO_CALL_LISTPIDS, type, flavor, 0, buffer, (uint32_t)buffersize);
}

DEFINE_HOOK(proc_pidinfo, int, (int pid,
                                int flavor,
                                uint64_t arg,
                                void *buffer,
                                int buffersize))
{
    environment_must_be_role(EnvironmentRoleGuest);
    return (int)environment_syscall(SYS_proc_info, PROC_INFO_CALL_PIDINFO, pid, (uint32_t)flavor, arg, buffer, (uint32_t)buffersize);
}

DEFINE_HOOK(proc_pidfdinfo, int, (int pid,
                                  int fd,
                                  int flavor,
                                  void *buffer,
                                  int buffersize))
{
    environment_must_be_role(EnvironmentRoleGuest);
    return (int)environment_syscall(SYS_proc_info, PROC_INFO_CALL_PIDFDINFO, pid, (uint32_t)flavor, (uint64_t)fd, buffer, (uint32_t)buffersize);
}

DEFINE_HOOK(proc_name, int, (pid_t pid,
                             void *buffer,
                             uint32_t buffersize))
{
    if(buffersize == 0 || buffer == NULL)
    {
        return 0;
    }
    
    struct {
        uint32_t pbi_flags;
        uint32_t pbi_status;
        uint32_t pbi_xstatus;
        uint32_t pbi_pid;
        uint32_t pbi_ppid;
        uint32_t pbi_uid;
        uint32_t pbi_gid;
        uint32_t pbi_ruid;
        uint32_t pbi_rgid;
        uint32_t pbi_svuid;
        uint32_t pbi_svgid;
        uint32_t pbi_rfu1;
        char     pbi_comm[16];
        char     pbi_name[32];
    } bsdinfo; // Minimal bsdinfo for name
    
    int ret = (int)environment_syscall(SYS_proc_info, PROC_INFO_CALL_PIDINFO, pid, PROC_PIDTBSDINFO, 0, &bsdinfo, sizeof(bsdinfo));
    
    if(ret <= 0)
    {
        return 0;
    }
    
    size_t full_len = strlen(bsdinfo.pbi_comm);
    size_t copy_len = (full_len >= buffersize) ? buffersize - 1 : full_len;
    
    strlcpy((char*)buffer, bsdinfo.pbi_comm, buffersize);
    return (int)copy_len;
}

DEFINE_HOOK(proc_pidpath, int, (pid_t pid,
                                void *buffer,
                                uint32_t buffersize))
{
    if(buffersize == 0 || buffer == NULL)
    {
        return 0;
    }
    
    return (int)environment_syscall(SYS_proc_info, PROC_INFO_CALL_PIDINFO, pid, PROC_PIDPATHINFO, 0, buffer, buffersize);
}

DEFINE_HOOK(proc_pid_rusage, int, (pid_t pid,
                                   int flavor,
                                   struct rusage_info_v2 *ri))
{
    if (!ri) return -1;
    memset(ri, 0, sizeof(*ri));
    
    struct {
        uint64_t pti_virtual_size;
        uint64_t pti_resident_size;
        uint64_t pti_total_user;
        uint64_t pti_total_system;
        // ... rest of darwin_proc_taskinfo
    } ti;
    
    int ret = (int)environment_syscall(SYS_proc_info, PROC_INFO_CALL_PIDINFO, pid, PROC_PIDTASKINFO, 0, &ti, sizeof(ti));
    if(ret <= 0) return -1;
    
    ri->ri_user_time = ti.pti_total_user;
    ri->ri_system_time = ti.pti_total_system;
    ri->ri_resident_size = ti.pti_resident_size;
    
    return 0;
}


DEFINE_HOOK(kill, int, (pid_t pid, int sig))
{
    return (int)environment_syscall(SYS_kill, pid, sig);
}

DEFINE_HOOK(raise, int, (int sig))
{
    return HOOK_FUNC(kill)(getpid(), sig);
}

void environment_libproc_init(void)
{
    if(environment_is_role(EnvironmentRoleGuest))
    {
        DO_HOOK_GLOBAL(proc_listallpids);
        DO_HOOK_GLOBAL(proc_listpids);
        DO_HOOK_GLOBAL(proc_pidinfo);
        DO_HOOK_GLOBAL(proc_pidfdinfo);
        DO_HOOK_GLOBAL(proc_name);
        DO_HOOK_GLOBAL(proc_pidpath);
        DO_HOOK_GLOBAL(proc_pid_rusage);
        DO_HOOK_GLOBAL(kill);
        DO_HOOK_GLOBAL(raise);
    }
}
