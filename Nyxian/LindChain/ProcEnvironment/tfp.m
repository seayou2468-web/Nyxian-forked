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

#import <LindChain/ProcEnvironment/tfp.h>
#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/ProcEnvironment/proxy.h>
#import <LindChain/litehook/litehook.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/syscall.h>
#import <LindChain/Debugger/MachServer.h>
#import <LindChain/ProcEnvironment/Utils/ktfp.h>
#import <mach/mach.h>

kern_return_t environment_task_for_pid(mach_port_name_t tp_in,
                                       pid_t pid,
                                       mach_port_name_t *tp_out)
{
    /* sanity check */
    if(tp_out == NULL)
    {
        return KERN_FAILURE;
    }
    
    int64_t ret = environment_syscall(SYS_gettask, pid, false, tp_out);
    
    if(ret == -1 ||
       *tp_out == MACH_PORT_NULL)
    {
        return KERN_FAILURE;
    }
    
    return KERN_SUCCESS;
}

DEFINE_HOOK(task_name_for_pid, kern_return_t, (mach_port_name_t tp_in,
                                               pid_t pid,
                                               mach_port_name_t *tp_out))
{
    /* sanity check */
    if(tp_out == NULL)
    {
        return KERN_FAILURE;
    }
    
    /*
     * boolean flag to true means that we only want
     * the name port.
     */
    int64_t ret = environment_syscall(SYS_gettask, pid, true, tp_out);
    
    if(ret == -1 ||
       *tp_out == MACH_PORT_NULL)
    {
        return KERN_FAILURE;
    }
    
    return KERN_SUCCESS;
}

/*
 Init
 */
void environment_tfp_init(void)
{
    if(environment_is_role(EnvironmentRoleGuest))
    {
        /* sending our task port to the task port system */
        ktfp(KTFP_GUEST);
        
        /* hooking tfp api */
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, task_for_pid, environment_task_for_pid, nil);
        DO_HOOK_GLOBAL(task_name_for_pid);
    }
}

#include <mach/mach_vm.h>

DEFINE_HOOK(mach_vm_read, kern_return_t, (vm_map_t target_task, mach_vm_address_t address, mach_vm_size_t size, vm_offset_t *data, mach_msg_type_number_t *data_cnt))
{
    if (environment_is_role(EnvironmentRoleGuest)) {
        mach_vm_size_t size_out = 0;
        int64_t ret = environment_syscall(SYS_mach_vm_read, target_task, address, size, data, &size_out);
        if (ret == 0) {
            *data_cnt = (mach_msg_type_number_t)size_out;
            return KERN_SUCCESS;
        }
        return KERN_FAILURE;
    }
    return mach_vm_read(target_task, address, size, data, data_cnt);
}

DEFINE_HOOK(mach_vm_write, kern_return_t, (vm_map_t target_task, mach_vm_address_t address, vm_offset_t data, mach_msg_type_number_t data_cnt))
{
    if (environment_is_role(EnvironmentRoleGuest)) {
        int64_t ret = environment_syscall(SYS_mach_vm_write, target_task, address, data, data_cnt);
        return (ret == 0) ? KERN_SUCCESS : KERN_FAILURE;
    }
    return mach_vm_write(target_task, address, data, data_cnt);
}

DEFINE_HOOK(mach_vm_region, kern_return_t, (vm_map_t target_task, mach_vm_address_t *address, mach_vm_size_t *size, vm_region_flavor_t flavor, vm_region_info_t info, mach_msg_type_number_t *info_cnt, mach_port_t *object_name))
{
    if (environment_is_role(EnvironmentRoleGuest)) {
        int64_t ret = environment_syscall(SYS_mach_vm_region, target_task, address, size, flavor, info, info_cnt, object_name);
        return (ret == 0) ? KERN_SUCCESS : KERN_FAILURE;
    }
    return mach_vm_region(target_task, address, size, flavor, info, info_cnt, object_name);
}

void environment_mach_vm_init(void)
{
    if(environment_is_role(EnvironmentRoleGuest))
    {
        DO_HOOK_GLOBAL(mach_vm_read);
        DO_HOOK_GLOBAL(mach_vm_write);
        DO_HOOK_GLOBAL(mach_vm_region);
    }
}
