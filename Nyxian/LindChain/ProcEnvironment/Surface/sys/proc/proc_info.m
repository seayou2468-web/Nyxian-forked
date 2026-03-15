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

#import <LindChain/ProcEnvironment/Surface/sys/proc/proc_info.h>
#import <LindChain/ProcEnvironment/Surface/sys/host/proc_info_types.h>
#import <LindChain/ProcEnvironment/Surface/sys/host/proc_flags.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/proc/list.h>
#import <LindChain/ProcEnvironment/Surface/proc/lookup.h>
#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>
#import <LindChain/ProcEnvironment/Object/FDMapObject.h>
#import <LindChain/ProcEnvironment/Object/FDObject.h>
#import <mach/mach.h>
#import <mach/task_info.h>
#import <mach/thread_info.h>
#import <mach/mach_vm.h>
#import <sys/stat.h>
#import <xpc/xpc.h>

static int proc_info_listpids(uint32_t type, uint32_t flavor, userspace_pointer_t buffer, uint32_t buffersize, task_t task, ksurface_proc_snapshot_t *caller)
{
    kinfo_proc_t *kpbuf = NULL;
    size_t needed = 0;
    ksurface_return_t ksr = proc_list(caller, &kpbuf, &needed, PROC_FLV_ALL, 0);

    if (ksr != SURFACE_SUCCESS) return -1;

    uint32_t count = (uint32_t)(needed / sizeof(kinfo_proc_t));
    uint32_t *pids = malloc(count * sizeof(uint32_t));
    if (!pids) { if(kpbuf) free(kpbuf); return -1; }

    for (uint32_t i = 0; i < count; i++) {
        pids[i] = (uint32_t)kpbuf[i].kp_proc.p_pid;
    }

    uint32_t copy_size = (buffersize < count * sizeof(uint32_t)) ? buffersize : (uint32_t)(count * sizeof(uint32_t));
    if (buffer != 0 && !mach_syscall_copy_out(task, copy_size, pids, buffer)) {
        free(kpbuf); free(pids); return -1;
    }

    free(kpbuf); free(pids);
    return (int)(count * sizeof(uint32_t));
}

static void fill_bsdinfo(ksurface_proc_t *proc, struct darwin_proc_bsdinfo *bsd)
{
    bsd->pbi_pid = (uint32_t)proc_getpid(proc);
    bsd->pbi_ppid = (uint32_t)proc_getppid(proc);
    bsd->pbi_uid = (uint32_t)proc_geteuid(proc);
    bsd->pbi_gid = (uint32_t)proc_getegid(proc);
    bsd->pbi_ruid = (uint32_t)proc_getruid(proc);
    bsd->pbi_rgid = (uint32_t)proc_getrgid(proc);
    bsd->pbi_svuid = (uint32_t)proc_getsvuid(proc);
    bsd->pbi_svgid = (uint32_t)proc_getsvgid(proc);
    bsd->pbi_status = (uint32_t)proc->bsd.kp_proc.p_stat;
    bsd->pbi_flags = (uint32_t)proc->bsd.kp_proc.p_flag;
    bsd->pbi_nice = (uint32_t)proc->bsd.kp_proc.p_priority;
    bsd->pbi_start_tvsec = (uint64_t)proc->bsd.kp_proc.p_un.__p_starttime.tv_sec;
    bsd->pbi_start_tvusec = (uint64_t)proc->bsd.kp_proc.p_un.__p_starttime.tv_usec;
    strlcpy(bsd->pbi_comm, proc->bsd.kp_proc.p_comm, sizeof(bsd->pbi_comm));
    strlcpy(bsd->pbi_name, proc->bsd.kp_proc.p_comm, sizeof(bsd->pbi_name));
}

static int fill_taskinfo(task_t task, struct darwin_proc_taskinfo *ti)
{
    if (task == MACH_PORT_NULL) return -1;

    struct task_basic_info_64 tbi;
    mach_msg_type_number_t count = TASK_BASIC_INFO_64_COUNT;
    if (task_info(task, TASK_BASIC_INFO_64, (task_info_t)&tbi, &count) == KERN_SUCCESS) {
        ti->pti_virtual_size = tbi.virtual_size;
        ti->pti_resident_size = tbi.resident_size;
        ti->pti_policy = tbi.policy;
    }

    struct task_events_info tei;
    count = TASK_EVENTS_INFO_COUNT;
    if (task_info(task, TASK_EVENTS_INFO, (task_info_t)&tei, &count) == KERN_SUCCESS) {
        ti->pti_faults = tei.faults;
        ti->pti_pageins = tei.pageins;
        ti->pti_cow_faults = tei.cow_faults;
        ti->pti_messages_sent = tei.messages_sent;
        ti->pti_messages_received = tei.messages_received;
        ti->pti_syscalls_mach = tei.syscalls_mach;
        ti->pti_syscalls_unix = tei.syscalls_unix;
        ti->pti_csw = tei.csw;
    }

    struct task_absolutetime_info tai;
    count = TASK_ABSOLUTETIME_INFO_COUNT;
    if (task_info(task, TASK_ABSOLUTETIME_INFO, (task_info_t)&tai, &count) == KERN_SUCCESS) {
        ti->pti_total_user = tai.total_user;
        ti->pti_total_system = tai.total_system;
        ti->pti_threads_user = tai.threads_user;
        ti->pti_threads_system = tai.threads_system;
    }

    return 0;
}

static int proc_info_pidinfo(int pid, uint32_t flavor, uint64_t arg, userspace_pointer_t buffer, uint32_t buffersize, task_t task)
{
    ksurface_proc_t *proc = NULL;
    if (proc_for_pid(pid, &proc) != SURFACE_SUCCESS) return -1;

    int ret = -1;

    switch (flavor) {
        case PROC_PIDTASKALLINFO: {
            struct darwin_proc_taskallinfo tai = {};
            kvo_rdlock(proc);
            fill_bsdinfo(proc, &tai.pbsd);
            fill_taskinfo(proc->task, &tai.ptinfo);
            kvo_unlock(proc);
            if (mach_syscall_copy_out(task, sizeof(tai), &tai, buffer)) ret = sizeof(tai);
            break;
        }
        case PROC_PIDTBSDINFO: {
            struct darwin_proc_bsdinfo bsd = {};
            kvo_rdlock(proc);
            fill_bsdinfo(proc, &bsd);
            kvo_unlock(proc);
            if (mach_syscall_copy_out(task, sizeof(bsd), &bsd, buffer)) ret = sizeof(bsd);
            break;
        }
        case PROC_PIDTASKINFO: {
            struct darwin_proc_taskinfo ti = {};
            kvo_rdlock(proc);
            fill_taskinfo(proc->task, &ti);
            kvo_unlock(proc);
            if (mach_syscall_copy_out(task, sizeof(ti), &ti, buffer)) ret = sizeof(ti);
            break;
        }
        case PROC_PIDPATHINFO: {
            char path[PATH_MAX] = {};
            kvo_rdlock(proc);
            strlcpy(path, proc->nyx.executable_path, sizeof(path));
            kvo_unlock(proc);
            if (mach_syscall_copy_out(task, sizeof(path), path, buffer)) ret = sizeof(path);
            break;
        }
        case PROC_PIDLISTTHREADS: {
            if (proc->task == MACH_PORT_NULL) break;
            thread_act_array_t threads;
            mach_msg_type_number_t count;
            if (task_threads(proc->task, &threads, &count) == KERN_SUCCESS) {
                uint64_t *tids = malloc(count * sizeof(uint64_t));
                for (uint32_t i = 0; i < count; i++) tids[i] = (uint64_t)threads[i];
                uint32_t copy_size = (buffersize < count * sizeof(uint64_t)) ? buffersize : (uint32_t)(count * sizeof(uint64_t));
                if (mach_syscall_copy_out(task, copy_size, tids, buffer)) ret = (int)(count * sizeof(uint64_t));
                for (uint32_t i = 0; i < count; i++) mach_port_deallocate(mach_task_self(), threads[i]);
                free(threads); free(tids);
            }
            break;
        }
        case PROC_PIDTHREADINFO: {
            thread_t thread = (thread_t)arg;
            struct darwin_proc_threadinfo thinfo = {};
            struct thread_basic_info tbi;
            mach_msg_type_number_t count = THREAD_BASIC_INFO_COUNT;
            if (thread_info(thread, THREAD_BASIC_INFO, (thread_info_t)&tbi, &count) == KERN_SUCCESS) {
                thinfo.pth_user_time = (uint64_t)tbi.user_time.seconds * 1000000000ULL + tbi.user_time.microseconds * 1000ULL;
                thinfo.pth_system_time = (uint64_t)tbi.system_time.seconds * 1000000000ULL + tbi.system_time.microseconds * 1000ULL;
                thinfo.pth_cpu_usage = tbi.cpu_usage;
                thinfo.pth_run_state = tbi.run_state;
                thinfo.pth_flags = tbi.flags;
                thinfo.pth_sleep_time = tbi.sleep_time;
            }
            if (mach_syscall_copy_out(task, sizeof(thinfo), &thinfo, buffer)) ret = sizeof(thinfo);
            break;
        }
        case PROC_PIDREGIONINFO: {
            mach_vm_address_t address = (mach_vm_address_t)arg;
            struct darwin_proc_regioninfo ri = {};
            vm_region_basic_info_data_64_t info;
            mach_vm_size_t size;
            mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
            mach_port_t object_name;
            if (mach_vm_region(proc->task, &address, &size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &count, &object_name) == KERN_SUCCESS) {
                ri.pri_address = (uint64_t)address;
                ri.pri_size = (uint64_t)size;
                ri.pri_protection = (uint32_t)info.protection;
                ri.pri_max_protection = (uint32_t)info.max_protection;
                ri.pri_behavior = (uint32_t)info.behavior;
                ri.pri_user_wired_count = (uint32_t)info.user_wired_count;
                if (object_name != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(), object_name);
            }
            if (mach_syscall_copy_out(task, sizeof(ri), &ri, buffer)) ret = sizeof(ri);
            break;
        }
    }

    kvo_release(proc);
    return ret;
}

static int proc_info_pidfdinfo(int pid, uint32_t flavor, int fd, userspace_pointer_t buffer, uint32_t buffersize, task_t task)
{
    LDEProcess *process = [[LDEProcessManager shared] processForProcessIdentifier:(pid_t)pid];
    if (!process) return -1;

    FDMapObject *fdMap = process.fdMap;

    int ret = -1;

    switch (flavor) {
        case PROC_PIDLISTFDS: {
            NSDictionary *map = fdMap.fd_map;
            if (!map) map = @{};

            uint32_t count = (uint32_t)map.count;
            struct darwin_proc_fdinfo *fds = malloc(count * sizeof(struct darwin_proc_fdinfo));
            if(!fds) return -1;
            uint32_t i = 0;
            for (NSNumber *fdNum in map.allKeys) {
                fds[i].proc_fd = [fdNum intValue];
                fds[i].proc_fdtype = PROC_PIDFDVNODEINFO;
                i++;
            }

            uint32_t copy_size = (buffersize < count * sizeof(struct darwin_proc_fdinfo)) ? buffersize : (uint32_t)(count * sizeof(struct darwin_proc_fdinfo));
            if (mach_syscall_copy_out(task, copy_size, fds, buffer)) ret = (int)(count * sizeof(struct darwin_proc_fdinfo));
            free(fds);
            break;
        }
        case PROC_PIDFDINFO: {
            FDObject *fdo = [fdMap.fd_map objectForKey:@(fd)];
            if (!fdo) break;

            struct darwin_vnode_fdinfo vfi = {};
            vfi.pfi.fi_type = PROC_PIDFDVNODEINFO;

            int tmpfd = xpc_fd_dup(fdo.fd);
            if (tmpfd >= 0) {
                char path[PATH_MAX];
                if (fcntl(tmpfd, F_GETPATH, path) == 0) {
                    strlcpy(vfi.pvi.vi_path, path, sizeof(vfi.pvi.vi_path));
                }
                struct stat st;
                if (fstat(tmpfd, &st) == 0) {
                    vfi.pvi.vi_stat.vst_size = st.st_size;
                    vfi.pvi.vi_stat.vst_mode = (uint32_t)st.st_mode;
                    vfi.pvi.vi_stat.vst_uid = st.st_uid;
                    vfi.pvi.vi_stat.vst_gid = st.st_gid;
                }
                vfi.pfi.fi_openflags = (uint32_t)fcntl(tmpfd, F_GETFL);
                vfi.pfi.fi_offset = lseek(tmpfd, 0, SEEK_CUR);
                close(tmpfd);
            }

            if (mach_syscall_copy_out(task, sizeof(vfi), &vfi, buffer)) ret = sizeof(vfi);
            break;
        }
    }

    return ret;
}

DEFINE_SYSCALL_HANDLER(proc_info)
{
    uint32_t call = (uint32_t)args[0];
    int pid = (int)args[1];
    uint32_t flavor = (uint32_t)args[2];
    uint64_t arg = (uint64_t)args[3];
    userspace_pointer_t buffer = (userspace_pointer_t)args[4];
    uint32_t buffersize = (uint32_t)args[5];

    int ret = -1;

    switch (call) {
        case PROC_INFO_CALL_LISTPIDS:
            ret = proc_info_listpids((uint32_t)pid, flavor, buffer, buffersize, sys_task_, sys_proc_snapshot_);
            break;
        case PROC_INFO_CALL_PIDINFO:
            ret = proc_info_pidinfo(pid, flavor, arg, buffer, buffersize, sys_task_);
            break;
        case PROC_INFO_CALL_PIDFDINFO:
            ret = proc_info_pidfdinfo(pid, flavor, (int)arg, buffer, buffersize, sys_task_);
            break;
        default:
            *err = ENOSYS;
            return -1;
    }

    if (ret < 0) {
        *err = ESRCH;
        return -1;
    }

    return ret;
}
