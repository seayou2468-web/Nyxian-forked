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

#import <LindChain/ProcEnvironment/Surface/ksys/proc/vm.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/proc/lookup.h>
#import <LindChain/ProcEnvironment/Surface/permit.h>
#import <mach/mach.h>
#import <mach/mach_vm.h>

static vm_prot_t convert_prot(uint32_t prot)
{
    vm_prot_t real = VM_PROT_NONE;
    if (prot & 0x01) real |= VM_PROT_READ;
    if (prot & 0x02) real |= VM_PROT_WRITE;
    if (prot & 0x04) real |= VM_PROT_EXECUTE;
    return real;
}

DEFINE_SYSCALL_HANDLER(vm_read)
{
    pid_t pid = (pid_t)args[0];
    mach_vm_address_t address = (mach_vm_address_t)args[1];
    mach_vm_size_t size = (mach_vm_size_t)args[2];
    userspace_pointer_t buffer = (userspace_pointer_t)args[3];

    if (!permitive_over_pid_allowed(sys_proc_snapshot_, pid, YES, YES, PEEntitlementTaskForPid, PEEntitlementGetTaskAllowed)) {
        sys_return_failure(EPERM);
    }

    ksurface_proc_t *target;
    if (proc_for_pid(pid, &target) != SURFACE_SUCCESS) sys_return_failure(ESRCH);

    vm_offset_t data;
    mach_msg_type_number_t data_cnt;
    kern_return_t kr = mach_vm_read(target->task, address, size, &data, &data_cnt);

    kvo_release(target);

    if (kr != KERN_SUCCESS) sys_return_failure(EFAULT);

    if (!mach_syscall_copy_out(sys_task_, data_cnt, (void*)data, buffer)) {
        vm_deallocate(mach_task_self(), data, data_cnt);
        sys_return_failure(EFAULT);
    }

    vm_deallocate(mach_task_self(), data, data_cnt);
    return 0;
}

DEFINE_SYSCALL_HANDLER(vm_write)
{
    pid_t pid = (pid_t)args[0];
    mach_vm_address_t address = (mach_vm_address_t)args[1];
    userspace_pointer_t buffer = (userspace_pointer_t)args[2];
    mach_vm_size_t size = (mach_vm_size_t)args[3];

    if (!permitive_over_pid_allowed(sys_proc_snapshot_, pid, YES, YES, PEEntitlementTaskForPid, PEEntitlementGetTaskAllowed)) {
        sys_return_failure(EPERM);
    }

    void *local_data = mach_syscall_alloc_in(sys_task_, size, buffer);
    if (!local_data) sys_return_failure(EFAULT);

    ksurface_proc_t *target;
    if (proc_for_pid(pid, &target) != SURFACE_SUCCESS) { free(local_data); sys_return_failure(ESRCH); }

    kern_return_t kr = mach_vm_write(target->task, address, (vm_offset_t)local_data, (mach_msg_type_number_t)size);

    kvo_release(target);
    free(local_data);

    if (kr != KERN_SUCCESS) sys_return_failure(EFAULT);
    return 0;
}

DEFINE_SYSCALL_HANDLER(vm_allocate)
{
    pid_t pid = (pid_t)args[0];
    userspace_pointer_t address_ptr = (userspace_pointer_t)args[1];
    mach_vm_size_t size = (mach_vm_size_t)args[2];
    int flags = (int)args[3];

    if (!permitive_over_pid_allowed(sys_proc_snapshot_, pid, YES, YES, PEEntitlementTaskForPid, PEEntitlementGetTaskAllowed)) {
        sys_return_failure(EPERM);
    }

    mach_vm_address_t address = 0;
    if (!mach_syscall_copy_in(sys_task_, sizeof(address), &address, address_ptr)) sys_return_failure(EFAULT);

    ksurface_proc_t *target;
    if (proc_for_pid(pid, &target) != SURFACE_SUCCESS) sys_return_failure(ESRCH);

    kern_return_t kr = mach_vm_allocate(target->task, &address, size, flags);

    kvo_release(target);

    if (kr != KERN_SUCCESS) sys_return_failure(ENOMEM);

    if (!mach_syscall_copy_out(sys_task_, sizeof(address), &address, address_ptr)) sys_return_failure(EFAULT);
    return 0;
}

DEFINE_SYSCALL_HANDLER(vm_deallocate)
{
    pid_t pid = (pid_t)args[0];
    mach_vm_address_t address = (mach_vm_address_t)args[1];
    mach_vm_size_t size = (mach_vm_size_t)args[2];

    if (!permitive_over_pid_allowed(sys_proc_snapshot_, pid, YES, YES, PEEntitlementTaskForPid, PEEntitlementGetTaskAllowed)) {
        sys_return_failure(EPERM);
    }

    ksurface_proc_t *target;
    if (proc_for_pid(pid, &target) != SURFACE_SUCCESS) sys_return_failure(ESRCH);

    kern_return_t kr = mach_vm_deallocate(target->task, address, size);

    kvo_release(target);

    if (kr != KERN_SUCCESS) sys_return_failure(EINVAL);
    return 0;
}

DEFINE_SYSCALL_HANDLER(vm_protect)
{
    pid_t pid = (pid_t)args[0];
    mach_vm_address_t address = (mach_vm_address_t)args[1];
    mach_vm_size_t size = (mach_vm_size_t)args[2];
    bool set_maximum = (bool)args[3];
    uint32_t new_protection = (uint32_t)args[4];

    if (!permitive_over_pid_allowed(sys_proc_snapshot_, pid, YES, YES, PEEntitlementTaskForPid, PEEntitlementGetTaskAllowed)) {
        sys_return_failure(EPERM);
    }

    ksurface_proc_t *target;
    if (proc_for_pid(pid, &target) != SURFACE_SUCCESS) sys_return_failure(ESRCH);

    kern_return_t kr = mach_vm_protect(target->task, address, size, set_maximum, convert_prot(new_protection));

    kvo_release(target);

    if (kr != KERN_SUCCESS) sys_return_failure(EFAULT);
    return 0;
}

DEFINE_SYSCALL_HANDLER(vm_region)
{
    pid_t pid = (pid_t)args[0];
    userspace_pointer_t address_ptr = (userspace_pointer_t)args[1];
    userspace_pointer_t size_ptr = (userspace_pointer_t)args[2];
    userspace_pointer_t info_ptr = (userspace_pointer_t)args[3];

    if (!permitive_over_pid_allowed(sys_proc_snapshot_, pid, YES, YES, PEEntitlementTaskForPid, PEEntitlementGetTaskAllowed)) {
        sys_return_failure(EPERM);
    }

    mach_vm_address_t address = 0;
    if (!mach_syscall_copy_in(sys_task_, sizeof(address), &address, address_ptr)) sys_return_failure(EFAULT);

    ksurface_proc_t *target;
    if (proc_for_pid(pid, &target) != SURFACE_SUCCESS) sys_return_failure(ESRCH);

    vm_region_basic_info_data_64_t info;
    mach_vm_size_t size;
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object_name;

    kern_return_t kr = mach_vm_region(target->task, &address, &size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &count, &object_name);

    kvo_release(target);

    if (kr != KERN_SUCCESS) sys_return_failure(EFAULT);

    if (object_name != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(), object_name);

    if (!mach_syscall_copy_out(sys_task_, sizeof(address), &address, address_ptr) ||
        !mach_syscall_copy_out(sys_task_, sizeof(size), &size, size_ptr) ||
        !mach_syscall_copy_out(sys_task_, sizeof(info), &info, info_ptr)) {
        sys_return_failure(EFAULT);
    }

    return 0;
}
