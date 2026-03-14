#include <stdint.h>
#include <sys/types.h>
#include <stdlib.h>
#include <string.h>

/* Mock types */
typedef void* userspace_pointer_t;
typedef uint32_t task_t;
typedef int errno_t;
#define DEFINE_SYSCALL_HANDLER(name) void syscall_server_handler_##name(void)
typedef struct ksurface_proc ksurface_proc_snapshot_t;

/* Simulate LindChain structure */
#include "Nyxian/LindChain/ProcEnvironment/Surface/sys/host/bsd_types.h"

/* The test should confirm no collision with a fake system header if we had one,
   but here we check if the darwin_ prefixed types are available. */

int main() {
    struct darwin_kinfo_proc kp;
    kp.kp_proc.p_pid = 1;
    return 0;
}
