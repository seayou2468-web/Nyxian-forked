#ifndef BSD_TYPES_H
#define BSD_TYPES_H

#include <sys/types.h>
#include <sys/time.h>

/* Minimal definitions for kinfo_proc and friends to be independent of system headers */

struct extern_proc {
    union {
        struct {
            struct proc *__p_forw;
            struct proc *__p_back;
        } p_stch;
        struct timeval __p_starttime;
    } p_un;
    struct vnode *p_vnode;
    struct proc *p_pptr;
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

struct _ucred {
    int32_t cr_ref;
    uid_t cr_uid;
    short cr_ngroups;
    gid_t cr_groups[16];
};

struct _pcred {
    char pc_pad[32];
    struct _ucred *pc_ucred;
    uid_t p_ruid;
    uid_t p_svuid;
    gid_t p_rgid;
    gid_t p_svgid;
    int p_refcnt;
};

struct eproc {
    struct proc *e_paddr;
    struct session *e_sess;
    struct _pcred e_pcred;
    struct _ucred e_ucred;
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
    struct session *e_tsess;
    char e_wmesg[8];
    u_int e_xsize;
    short e_xrssize;
    short e_xccount;
    short e_xswrss;
    int32_t e_flag;
    char e_login[12];
    int32_t e_spare[4];
};

struct kinfo_proc {
    struct extern_proc kp_proc;
    struct eproc kp_eproc;
};

#endif /* BSD_TYPES_H */
