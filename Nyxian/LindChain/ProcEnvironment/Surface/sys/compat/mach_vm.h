/*
 SPDX-License-Identifier: AGPL-3.0-or-later
*/

#ifndef SURFACE_SYS_MACH_VM_H
#define SURFACE_SYS_MACH_VM_H

#import <LindChain/ProcEnvironment/Surface/surface.h>

DEFINE_SYSCALL_HANDLER(mach_vm_read);
DEFINE_SYSCALL_HANDLER(mach_vm_write);
DEFINE_SYSCALL_HANDLER(mach_vm_region);

#endif /* SURFACE_SYS_MACH_VM_H */
