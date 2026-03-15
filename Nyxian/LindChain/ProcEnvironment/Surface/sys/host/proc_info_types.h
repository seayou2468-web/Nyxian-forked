#ifndef DARWIN_PROC_INFO_TYPES_H
#define DARWIN_PROC_INFO_TYPES_H

#include <sys/types.h>
#include <LindChain/ProcEnvironment/Surface/sys/host/bsd_types.h>

/*
 * Redefining Darwin proc_info structures with 'darwin_' prefix
 * to avoid conflicts with iOS SDK while maintaining compatibility.
 */

struct darwin_vinfo_stat {
    uint32_t    vst_dev;
    uint32_t    vst_mode;
    uint32_t    vst_nlink;
    uint64_t    vst_ino;
    uid_t       vst_uid;
    gid_t       vst_gid;
    int32_t     vst_atime;
    int32_t     vst_atimensec;
    int32_t     vst_mtime;
    int32_t     vst_mtimensec;
    int32_t     vst_ctime;
    int32_t     vst_ctimensec;
    int32_t     vst_birthtime;
    int32_t     vst_birthtimensec;
    int64_t     vst_size;
    int64_t     vst_blocks;
    int32_t     vst_blksize;
    uint32_t    vst_flags;
    uint32_t    vst_gen;
    uint32_t    vst_rdev;
    int64_t     vst_qspare[2];
};

struct darwin_vnode_info {
    struct darwin_vinfo_stat vi_stat;
    int vi_type;
    int vi_pad;
    char vi_path[PATH_MAX];
};

struct darwin_proc_fileinfo {
    uint32_t fi_openflags;
    uint32_t fi_status;
    off_t    fi_offset;
    int32_t  fi_type;
    uint32_t fi_reserved;
};

struct darwin_proc_fdinfo {
    int32_t  proc_fd;
    uint32_t proc_fdtype;
};

struct darwin_vnode_fdinfo {
    struct darwin_proc_fileinfo pfi;
    struct darwin_vnode_info    pvi;
};

struct darwin_proc_bsdinfo {
    uint32_t                pbi_flags;
    uint32_t                pbi_status;
    uint32_t                pbi_xstatus;
    uint32_t                pbi_pid;
    uint32_t                pbi_ppid;
    uint32_t                pbi_uid;
    uint32_t                pbi_gid;
    uint32_t                pbi_ruid;
    uint32_t                pbi_rgid;
    uint32_t                pbi_svuid;
    uint32_t                pbi_svgid;
    uint32_t                pbi_rfu1;
    char                    pbi_comm[MAXCOMLEN];
    char                    pbi_name[2 * MAXCOMLEN];
    uint32_t                pbi_nfiles;
    uint32_t                pbi_pgid;
    uint32_t                pbi_pjobc;
    uint32_t                pbi_tdev;
    uint32_t                pbi_tpgid;
    uint32_t                pbi_nice;
    uint64_t                pbi_start_tvsec;
    uint64_t                pbi_start_tvusec;
};

struct darwin_proc_taskinfo {
    uint64_t                pti_virtual_size;
    uint64_t                pti_resident_size;
    uint64_t                pti_total_user;
    uint64_t                pti_total_system;
    uint64_t                pti_threads_user;
    uint64_t                pti_threads_system;
    int32_t                 pti_policy;
    int32_t                 pti_faults;
    int32_t                 pti_pageins;
    int32_t                 pti_cow_faults;
    int32_t                 pti_messages_sent;
    int32_t                 pti_messages_received;
    int32_t                 pti_syscalls_mach;
    int32_t                 pti_syscalls_unix;
    int32_t                 pti_csw;
    int32_t                 pti_threadnum;
    int32_t                 pti_priority;
    int32_t                 pti_res_spare;
};

struct darwin_proc_taskallinfo {
    struct darwin_proc_bsdinfo  pbsd;
    struct darwin_proc_taskinfo ptinfo;
};

struct darwin_proc_threadinfo {
    uint64_t                pth_user_time;
    uint64_t                pth_system_time;
    int32_t                 pth_cpu_usage;
    int32_t                 pth_policy;
    int32_t                 pth_run_state;
    int32_t                 pth_flags;
    int32_t                 pth_sleep_time;
    int32_t                 pth_curpri;
    int32_t                 pth_priority;
    int32_t                 pth_maxpriority;
    char                    pth_name[64];
};

struct darwin_proc_regioninfo {
    uint64_t                pri_offset;
    uint64_t                pri_address;
    uint64_t                pri_size;
    uint32_t                pri_depth;
    uint32_t                pri_ref_count;
    uint32_t                pri_share_mode;
    uint32_t                pri_private_pages_resident;
    uint32_t                pri_shared_pages_resident;
    uint32_t                pri_obj_id;
    uint32_t                pri_purgable;
    uint32_t                pri_max_protection;
    uint32_t                pri_protection;
    uint32_t                pri_behavior;
    uint32_t                pri_user_wired_count;
    uint32_t                pri_user_tag;
    uint32_t                pri_pages_resident;
    uint32_t                pri_pages_shared_now_private;
    uint32_t                pri_pages_swapped_out;
    uint32_t                pri_pages_dirtied;
    uint32_t                pri_ref_count_64;
};

struct darwin_proc_vnodepathinfo {
    struct darwin_vnode_info pvi_cdir;
    struct darwin_vnode_info pvi_rdir;
};

#endif /* DARWIN_PROC_INFO_TYPES_H */
