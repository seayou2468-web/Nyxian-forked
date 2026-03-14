#include <stdint.h>
#include <sys/types.h>
#include <stdlib.h>
#include <string.h>

typedef void* userspace_pointer_t;
typedef uint32_t task_t;
typedef int errno_t;
#define DEFINE_SYSCALL_HANDLER(name) void syscall_server_handler_##name(void)
typedef struct ksurface_proc ksurface_proc_snapshot_t;

#define PROCENVIRONMENT_SURFACE_H
#define SURFACE_SYSCTL_H

/* --- sysctl handler function type --- */
typedef struct {
    int name[20];
    u_int namelen;
    userspace_pointer_t oldp;
    userspace_pointer_t oldlenp;
    userspace_pointer_t newp;
    size_t newlen;
    errno_t err;
    task_t task;
    ksurface_proc_snapshot_t *proc_snapshot;
} sysctl_req_t;

typedef int (*sysctl_fn_t)(sysctl_req_t *req);

/* --- Dynamic Registration API --- */
void ksurface_sysctl_register(const int *mib, size_t mib_len, sysctl_fn_t fn);
void ksurface_sysctl_register_by_name(const char *name, const int *mib, size_t mib_len, sysctl_fn_t fn);
void ksurface_sysctl_cleanup(void);

int main() {
    ksurface_sysctl_register(NULL, 0, NULL);
    ksurface_sysctl_register_by_name("test", NULL, 0, NULL);
    ksurface_sysctl_cleanup();
    return 0;
}
