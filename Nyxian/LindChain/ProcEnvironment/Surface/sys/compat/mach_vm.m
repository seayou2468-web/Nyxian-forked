/*
 SPDX-License-Identifier: AGPL-3.0-or-later
*/

#import <LindChain/ProcEnvironment/Surface/sys/compat/mach_vm.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/permit.h>
#import <LindChain/ProcEnvironment/tfp.h>
#include <mach/mach_vm.h>

DEFINE_SYSCALL_HANDLER(mach_vm_read)
{
    task_t target_task = (task_t)args[0];
    mach_vm_address_t address = (mach_vm_address_t)args[1];
    mach_vm_size_t size = (mach_vm_size_t)args[2];
    userspace_pointer_t data_out = (userspace_pointer_t)args[3];
    userspace_pointer_t size_out = (userspace_pointer_t)args[4];

    vm_offset_t data;
    mach_msg_type_number_t data_cnt;

    kern_return_t kr = mach_vm_read(target_task, address, size, &data, &data_cnt);
    if (kr != KERN_SUCCESS) {
        sys_return_failure(EFAULT);
    }

    if (!mach_syscall_copy_out(sys_task_, data_cnt, (void *)data, data_out)) {
        vm_deallocate(mach_task_self(), data, data_cnt);
        sys_return_failure(EFAULT);
    }

    if (size_out != NULL) {
        mach_vm_size_t size_val = (mach_vm_size_t)data_cnt;
        mach_syscall_copy_out(sys_task_, sizeof(mach_vm_size_t), &size_val, size_out);
    }

    vm_deallocate(mach_task_self(), data, data_cnt);
    return 0;
}

DEFINE_SYSCALL_HANDLER(mach_vm_write)
{
    task_t target_task = (task_t)args[0];
    mach_vm_address_t address = (mach_vm_address_t)args[1];
    userspace_pointer_t data_ptr = (userspace_pointer_t)args[2];
    mach_msg_type_number_t data_cnt = (mach_msg_type_number_t)args[3];

    void *buffer = malloc(data_cnt);
    if (!buffer) sys_return_failure(ENOMEM);

    if (!mach_syscall_copy_in(sys_task_, data_cnt, buffer, data_ptr)) {
        free(buffer);
        sys_return_failure(EFAULT);
    }

    kern_return_t kr = mach_vm_write(target_task, address, (vm_offset_t)buffer, data_cnt);
    free(buffer);

    if (kr != KERN_SUCCESS) {
        sys_return_failure(EFAULT);
    }

    return 0;
}

DEFINE_SYSCALL_HANDLER(mach_vm_region)
{
    task_t target_task = (task_t)args[0];
    userspace_pointer_t address_ptr = (userspace_pointer_t)args[1];
    userspace_pointer_t size_ptr = (userspace_pointer_t)args[2];
    vm_region_flavor_t flavor = (vm_region_flavor_t)args[3];
    userspace_pointer_t info_ptr = (userspace_pointer_t)args[4];
    userspace_pointer_t info_cnt_ptr = (userspace_pointer_t)args[5];
    userspace_pointer_t object_name_ptr = (userspace_pointer_t)args[6];

    mach_vm_address_t address;
    mach_vm_size_t size;
    mach_msg_type_number_t info_cnt;
    mach_port_t object_name;

    if (!mach_syscall_copy_in(sys_task_, sizeof(address), &address, address_ptr) ||
        !mach_syscall_copy_in(sys_task_, sizeof(info_cnt), &info_cnt, info_cnt_ptr)) {
        sys_return_failure(EFAULT);
    }

    void *info = malloc(info_cnt * sizeof(int));
    kern_return_t kr = mach_vm_region(target_task, &address, &size, flavor, (vm_region_info_t)info, &info_cnt, &object_name);

    if (kr != KERN_SUCCESS) {
        free(info);
        sys_return_failure(EFAULT);
    }

    mach_syscall_copy_out(sys_task_, sizeof(address), &address, address_ptr);
    mach_syscall_copy_out(sys_task_, sizeof(size), &size, size_ptr);
    mach_syscall_copy_out(sys_task_, info_cnt * sizeof(int), info, info_ptr);
    mach_syscall_copy_out(sys_task_, sizeof(info_cnt), &info_cnt, info_cnt_ptr);

    if (object_name_ptr != NULL) {
        mach_syscall_copy_out(sys_task_, sizeof(object_name), &object_name, object_name_ptr);
    }

    free(info);
    return 0;
}
