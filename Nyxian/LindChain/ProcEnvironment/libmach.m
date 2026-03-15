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
#import <LindChain/ProcEnvironment/libmach.h>
#import <LindChain/litehook/litehook.h>
#import <mach/mach.h>
#import <mach/mach_vm.h>

DEFINE_HOOK(mach_vm_read, kern_return_t, (vm_map_t target_task, mach_vm_address_t address, mach_vm_size_t size, vm_offset_t *data, mach_msg_type_number_t *dataCnt))
{
    environment_must_be_role(EnvironmentRoleGuest);

    /*
     * In a virtualized environment, target_task is a pid
     * but the standard Mach API uses ports.
     * We need to find the pid for this task port if it's not the current task.
     */
    pid_t pid = 0;
    if (target_task == mach_task_self()) {
        pid = getpid();
    } else {
        // Here we'd need a way to map port -> pid in guest,
        // but often tools like CocoaTop use task_for_pid first.
        // For now, let's assume the caller passed a pid or we use a fallback.
        // Actually, if we hooked task_for_pid to return pids as 'ports', we could use that.
        pid = (pid_t)target_task;
    }

    void *buffer = malloc(size);
    if (!buffer) return KERN_RESOURCE_SHORTAGE;

    int64_t ret = environment_syscall(SYS_vm_read, pid, address, size, buffer);
    if (ret != 0) {
        free(buffer);
        return KERN_FAILURE;
    }

    *data = (vm_offset_t)buffer;
    *dataCnt = (mach_msg_type_number_t)size;

    return KERN_SUCCESS;
}

DEFINE_HOOK(mach_vm_write, kern_return_t, (vm_map_t target_task, mach_vm_address_t address, vm_offset_t data, mach_msg_type_number_t dataCnt))
{
    environment_must_be_role(EnvironmentRoleGuest);
    pid_t pid = (target_task == mach_task_self()) ? getpid() : (pid_t)target_task;

    int64_t ret = environment_syscall(SYS_vm_write, pid, address, data, (uint64_t)dataCnt);
    return (ret == 0) ? KERN_SUCCESS : KERN_FAILURE;
}

DEFINE_HOOK(mach_vm_allocate, kern_return_t, (vm_map_t target_task, mach_vm_address_t *address, mach_vm_size_t size, int flags))
{
    environment_must_be_role(EnvironmentRoleGuest);
    pid_t pid = (target_task == mach_task_self()) ? getpid() : (pid_t)target_task;

    int64_t ret = environment_syscall(SYS_vm_allocate, pid, address, size, flags);
    return (ret == 0) ? KERN_SUCCESS : KERN_FAILURE;
}

DEFINE_HOOK(mach_vm_deallocate, kern_return_t, (vm_map_t target_task, mach_vm_address_t address, mach_vm_size_t size))
{
    environment_must_be_role(EnvironmentRoleGuest);
    pid_t pid = (target_task == mach_task_self()) ? getpid() : (pid_t)target_task;

    int64_t ret = environment_syscall(SYS_vm_deallocate, pid, address, size);
    return (ret == 0) ? KERN_SUCCESS : KERN_FAILURE;
}

DEFINE_HOOK(mach_vm_protect, kern_return_t, (vm_map_t target_task, mach_vm_address_t address, mach_vm_size_t size, boolean_t set_maximum, vm_prot_t new_protection))
{
    environment_must_be_role(EnvironmentRoleGuest);
    pid_t pid = (target_task == mach_task_self()) ? getpid() : (pid_t)target_task;

    int64_t ret = environment_syscall(SYS_vm_protect, pid, address, size, (uint64_t)set_maximum, (uint64_t)new_protection);
    return (ret == 0) ? KERN_SUCCESS : KERN_FAILURE;
}

DEFINE_HOOK(mach_vm_region, kern_return_t, (vm_map_t target_task, mach_vm_address_t *address, mach_vm_size_t *size, vm_region_flavor_t flavor, vm_region_info_t info, mach_msg_type_number_t *infoCnt, mach_port_t *object_name))
{
    environment_must_be_role(EnvironmentRoleGuest);
    pid_t pid = (target_task == mach_task_self()) ? getpid() : (pid_t)target_task;

    if (flavor != VM_REGION_BASIC_INFO_64) return KERN_INVALID_ARGUMENT;

    int64_t ret = environment_syscall(SYS_vm_region, pid, address, size, info);
    if (ret != 0) return KERN_FAILURE;

    if (object_name) *object_name = MACH_PORT_NULL;
    if (infoCnt) *infoCnt = VM_REGION_BASIC_INFO_COUNT_64;

    return KERN_SUCCESS;
}

void environment_libmach_init(void)
{
    if(environment_is_role(EnvironmentRoleGuest))
    {
        DO_HOOK_GLOBAL(mach_vm_read);
        DO_HOOK_GLOBAL(mach_vm_write);
        DO_HOOK_GLOBAL(mach_vm_allocate);
        DO_HOOK_GLOBAL(mach_vm_deallocate);
        DO_HOOK_GLOBAL(mach_vm_protect);
        DO_HOOK_GLOBAL(mach_vm_region);
    }
}
