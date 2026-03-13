/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

 This file is part of Nyxian.
*/

#import <LindChain/ProcEnvironment/Surface/sys/cred/setpgrp.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>
#import <LindChain/ProcEnvironment/Surface/proc/lookup.h>

DEFINE_SYSCALL_HANDLER(getpgrp)
{
    return sys_proc_snapshot_->bsd.kp_eproc.e_pgid;
}

DEFINE_SYSCALL_HANDLER(setpgid)
{
    pid_t pid = (pid_t)args[0];
    pid_t pgid = (pid_t)args[1];

    if (pid == 0) pid = proc_getpid(sys_proc_snapshot_);
    if (pgid == 0) pgid = pid;

    ksurface_proc_t *target = NULL;
    if (proc_for_pid(pid, &target) != SURFACE_SUCCESS) {
        sys_return_failure(ESRCH);
    }

    kvo_wrlock(target);
    target->bsd.kp_eproc.e_pgid = pgid;
    kvo_unlock(target);
    kvo_release(target);

    return 0;
}

DEFINE_SYSCALL_HANDLER(getpgid)
{
    pid_t pid = (pid_t)args[0];
    if (pid == 0) return sys_proc_snapshot_->bsd.kp_eproc.e_pgid;

    ksurface_proc_t *target = NULL;
    if (proc_for_pid(pid, &target) != SURFACE_SUCCESS) {
        sys_return_failure(ESRCH);
    }

    pid_t pgid = target->bsd.kp_eproc.e_pgid;
    kvo_release(target);

    return pgid;
}
