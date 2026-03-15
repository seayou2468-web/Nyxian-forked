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

#ifndef SURFACE_SYS_SYSCALL_H
#define SURFACE_SYS_SYSCALL_H

/* headers to syscall handlers*/
#import <LindChain/ProcEnvironment/Surface/ksys/proc/kill.h>
#import <LindChain/ProcEnvironment/Surface/ksys/compat/bamset.h>
#import <LindChain/ProcEnvironment/Surface/ksys/cred/setuid.h>
#import <LindChain/ProcEnvironment/Surface/ksys/cred/setgid.h>
#import <LindChain/ProcEnvironment/Surface/ksys/compat/getent.h>
#import <LindChain/ProcEnvironment/Surface/ksys/cred/getpid.h>
#import <LindChain/ProcEnvironment/Surface/ksys/cred/getuid.h>
#import <LindChain/ProcEnvironment/Surface/ksys/cred/getgid.h>
#import <LindChain/ProcEnvironment/Surface/ksys/compat/gettask.h>
#import <LindChain/ProcEnvironment/Surface/ksys/compat/signexec.h>
#import <LindChain/ProcEnvironment/Surface/ksys/compat/procpath.h>
#import <LindChain/ProcEnvironment/Surface/ksys/compat/handoffep.h>
#import <LindChain/ProcEnvironment/Surface/ksys/cred/getsid.h>
#import <LindChain/ProcEnvironment/Surface/ksys/cred/setsid.h>
#import <LindChain/ProcEnvironment/Surface/ksys/host/sysctl.h>
#import <LindChain/ProcEnvironment/Surface/ksys/proc/wait4.h>
#import <LindChain/ProcEnvironment/Surface/ksys/proc/exit.h>
#import <LindChain/ProcEnvironment/Surface/ksys/host/ioctl.h>
#import <LindChain/ProcEnvironment/Surface/ksys/compat/setent.h>
#import <LindChain/ProcEnvironment/Surface/ksys/compat/enttoken.h>
#import <LindChain/ProcEnvironment/Surface/ksys/cred/setpgrp.h>
#import <LindChain/ProcEnvironment/Surface/ksys/proc/proc_info.h>
#import <LindChain/ProcEnvironment/Surface/ksys/proc/vm.h>
#include <sys/syscall.h>

/* additional nyxian syscalls for now */
#define SYS_bamset      750         /* setting audio background mode */
#define SYS_proctb      751         /* MARK: deprecated.. use SYS_sysctl instead */
#define SYS_getent      752         /* getting processes entitlements */
#define SYS_gethostname 753         /* MARK: deprecated.. use SYS_sysctl instead */
#define SYS_sethostname 754         /* MARK: deprecated.. use SYS_sysctl instead */
#define SYS_gettask     755         /* gets task port */
#define SYS_signexec    756         /* uses file descriptor passed by guest to sign executable */
#define SYS_procpath    757         /* gets process path of a pid */
#define SYS_procbsd     758         /* MARK: deprecated.. use SYS_sysctl instead */
#define SYS_handoffep   759         /* handoff exception port to kvirt */
#define SYS_setent      760         /* sets entitlements (sanitized ofc) */
#define SYS_enttoken    761
#define SYS_vm_read      762
#define SYS_vm_write     763
#define SYS_vm_allocate  764
#define SYS_vm_deallocate 765
#define SYS_vm_protect   766
#define SYS_vm_region    767         /* generation and consumption of token full of authority */

#define SYS_N 38

typedef struct {
    const char *name;
    uint32_t sysnum;
    syscall_handler_t hndl;
} syscall_list_item_t;

extern syscall_list_item_t sys_list[SYS_N];

#endif /* SURFACE_SYS_SYSCALL_H */
