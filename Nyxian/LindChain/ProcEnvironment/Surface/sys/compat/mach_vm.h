/*
 SPDX-License-Identifier: AGPL-3.0-or-later
*/

#ifndef SURFACE_SYS_MACH_VM_H
#define SURFACE_SYS_MACH_VM_H

#import <LindChain/ProcEnvironment/Surface/surface.h>
#include <mach/mach_vm.h>

DEFINE_SYSCALL_HANDLER(mach_vm_read);
DEFINE_SYSCALL_HANDLER(mach_vm_write);
DEFINE_SYSCALL_HANDLER(mach_vm_region);

kern_return_t nx_mach_vm_read(task_t target_task,
                              mach_vm_address_t address,
                              mach_vm_size_t size,
                              void *buffer,
                              mach_vm_size_t *outSize);

kern_return_t nx_mach_vm_write(task_t target_task,
                               mach_vm_address_t address,
                               const void *buffer,
                               mach_msg_type_number_t length);

kern_return_t nx_mach_vm_protect(task_t target_task,
                                 mach_vm_address_t address,
                                 mach_vm_size_t size,
                                 vm_prot_t protection);

#endif /* SURFACE_SYS_MACH_VM_H */
