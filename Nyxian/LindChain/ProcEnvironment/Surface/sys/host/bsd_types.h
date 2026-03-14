#ifndef DARWIN_BSD_TYPES_H
#define DARWIN_BSD_TYPES_H

#include <sys/types.h>
#include <sys/time.h>

/*
 * Redefining Darwin structures with 'darwin_' prefix to avoid conflicts
 * with iOS SDK headers while maintaining binary compatibility.
 */

struct darwin_extern_proc {
    union {
        struct {
            void *__p_forw;
            void *__p_back;
        } p_stch;
        struct timeval __p_starttime;
    } p_un;
    void *p_vnode;
    void *p_pptr;
    pid_t p_pid;
    pid_t p_oppid;
    int p_stat;
    char p_pad1[3];
    char p_pad2[1];
    u_int p_flag;
    char p_pad3[1];
    char p_pad4[1];
    char p_pad5[1];
    u_int p_pad6;
    void *p_pad7;
    int p_pad8;
    u_int p_pad9;
    u_int p_pad10;
    u_int p_pad11;
    u_int p_pad12;
    char p_comm[17];
    void *p_pad13;
    int p_pad14;
    u_int p_pad15;
    u_int p_pad16;
    u_int p_pad17;
    int p_priority;
    int p_usrpri;
    void *p_pad18;
    void *p_pad19;
};

struct darwin_ucred {
    int32_t cr_ref;
    uid_t cr_uid;
    short cr_ngroups;
    gid_t cr_groups[16];
};

struct darwin_pcred {
    char pc_pad[32];
    struct darwin_ucred *pc_ucred;
    uid_t p_ruid;
    uid_t p_svuid;
    gid_t p_rgid;
    gid_t p_svgid;
    int p_refcnt;
};

struct darwin_eproc {
    void *e_paddr;
    void *e_sess;
    struct darwin_pcred e_pcred;
    struct darwin_ucred e_ucred;
    struct {
        u_int vm_rssize;
        u_int vm_tsize;
        u_int vm_dsize;
        u_int vm_ssize;
    } e_vm;
    pid_t e_ppid;
    pid_t e_pgid;
    short e_jobc;
    dev_t e_tdev;
    pid_t e_tpgid;
    void *e_tsess;
    char e_wmesg[8];
    u_int e_xsize;
    short e_xrssize;
    short e_xccount;
    short e_xswrss;
    int32_t e_flag;
    char e_login[12];
    int32_t e_spare[4];
};

struct darwin_kinfo_proc {
    struct darwin_extern_proc kp_proc;
    struct darwin_eproc kp_eproc;
};

#endif /* DARWIN_BSD_TYPES_H */
