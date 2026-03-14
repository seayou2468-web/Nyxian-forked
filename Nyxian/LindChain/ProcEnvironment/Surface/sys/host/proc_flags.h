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

#ifndef DARWIN_PROC_FLAGS_H
#define DARWIN_PROC_FLAGS_H

/*
 * Process p_flag values (XNU compatible)
 */
#ifndef P_ADVLOCK
#define P_ADVLOCK       0x00000001
#endif

#ifndef P_CONTROLT
#define P_CONTROLT      0x00000002
#endif

#ifndef P_LP64
#define P_LP64          0x00000004  /* Process is LP64 */
#endif

#ifndef P_NOCLDSTOP
#define P_NOCLDSTOP     0x00000008
#endif

#ifndef P_PPWAIT
#define P_PPWAIT        0x00000010
#endif

#ifndef P_PROFIL
#define P_PROFIL        0x00000020
#endif

#ifndef P_SELECT
#define P_SELECT        0x00000040
#endif

#ifndef P_CONTINUED
#define P_CONTINUED     0x00000080
#endif

#ifndef P_SUGID
#define P_SUGID         0x00000100
#endif

#ifndef P_SYSTEM
#define P_SYSTEM        0x00000200
#endif

#ifndef P_TIMEOUT
#define P_TIMEOUT       0x00000400
#endif

#ifndef P_TRACED
#define P_TRACED        0x00000800
#endif

#ifndef P_DISABLE_ASLR
#define P_DISABLE_ASLR  0x00001000
#endif

#ifndef P_WEXIT
#define P_WEXIT         0x00002000
#endif

#ifndef P_EXEC
#define P_EXEC          0x00004000
#endif

/*
 * Process p_stat values (XNU compatible)
 */
#ifndef SIDL
#define SIDL    1               /* Process being created by fork. */
#endif

#ifndef SRUN
#define SRUN    2               /* Currently runnable. */
#endif

#ifndef SSLEEP
#define SSLEEP  3               /* Sleeping on an address. */
#endif

#ifndef SSTOP
#define SSTOP   4               /* Process debugging or suspension. */
#endif

#ifndef SZOMB
#define SZOMB   5               /* Awaiting collection by parent. */
#endif

/*
 * eproc e_flag values
 */
#ifndef EPROC_CTTY
#define EPROC_CTTY      0x00000001      /* has a controlling terminal */
#endif

#ifndef EPROC_SLEADER
#define EPROC_SLEADER   0x00000002      /* session leader */
#endif

/*
 * Wait options
 */
#ifndef WSTOPPED
#define WSTOPPED        0x00000008
#endif

#ifndef WCONTINUED
#define WCONTINUED      0x00000010
#endif

#ifndef W_STOPCODE
#define W_STOPCODE(sig) ((sig) << 8 | 0177)
#endif

/*
 * Priorities
 */
#ifndef PZERO
#define PZERO   22              /* No priority. */
#endif

#ifndef PUSER
#define PUSER   31              /* First user priority. */
#endif

#ifndef PRIO_MAX
#define PRIO_MAX 20
#endif

#ifndef PRIO_MIN
#define PRIO_MIN -20
#endif

/*
 * fcntl flags missing in some SDKs
 */
#ifndef F_ADDFILESIGS_RETURN
#define F_ADDFILESIGS_RETURN 103
#endif

#ifndef F_CHECK_LV
#define F_CHECK_LV 98
#endif

#ifndef F_GETLKPID
#define F_GETLKPID 66
#endif

/*
 * Code Signing (XNU compatible)
 */
#ifndef CSMAGIC_CODEDIRECTORY
#define CSMAGIC_CODEDIRECTORY 0xfade0c02
#endif

#ifndef CSMAGIC_EMBEDDED_SIGNATURE
#define CSMAGIC_EMBEDDED_SIGNATURE 0xfade0cc0
#endif

#ifndef CSSLOT_CODEDIRECTORY
#define CSSLOT_CODEDIRECTORY 0
#endif

#ifndef CS_HASHTYPE_SHA1
#define CS_HASHTYPE_SHA1 1
#endif

#ifndef CS_HASHTYPE_SHA256
#define CS_HASHTYPE_SHA256 2
#endif

#ifndef CS_HASHTYPE_SHA256_TRUNCATED
#define CS_HASHTYPE_SHA256_TRUNCATED 3
#endif

#ifndef CS_HASHTYPE_SHA384
#define CS_HASHTYPE_SHA384 4
#endif

/*
 * Misc Constants
 */
#ifndef USER_FSIGNATURES_CDHASH_LEN
#define USER_FSIGNATURES_CDHASH_LEN 48
#endif

/*
 * sysctl constants (moved from sysctl.h for consistency)
 */
#ifndef CTL_KERN
#define CTL_KERN 1
#endif
#ifndef CTL_HW
#define CTL_HW 6
#endif

#ifndef KERN_OSTYPE
#define KERN_OSTYPE           1
#endif
#ifndef KERN_OSRELEASE
#define KERN_OSRELEASE        2
#endif
#ifndef KERN_OSVERSION
#define KERN_OSVERSION        3
#endif
#ifndef KERN_VERSION
#define KERN_VERSION          4
#endif
#ifndef KERN_MAXPROC
#define KERN_MAXPROC          6
#endif
#ifndef KERN_MAXFILES
#define KERN_MAXFILES         7
#endif
#ifndef KERN_HOSTNAME
#define KERN_HOSTNAME        10
#endif
#ifndef KERN_PROC
#define KERN_PROC            14
#endif
#ifndef KERN_NGROUPS
#define KERN_NGROUPS         18
#endif
#ifndef KERN_SAVED_IDS
#define KERN_SAVED_IDS       20
#endif
#ifndef KERN_BOOTARGS
#define KERN_BOOTARGS        38
#endif
#ifndef KERN_PROCARGS
#define KERN_PROCARGS        39
#endif
#ifndef KERN_PROCARGS2
#define KERN_PROCARGS2       49
#endif
#ifndef KERN_MAXFILESPERPROC
#define KERN_MAXFILESPERPROC 67
#endif
#ifndef KERN_OSPRODUCTVERSION
#define KERN_OSPRODUCTVERSION 70
#endif

#ifndef KERN_PROC_ALL
#define KERN_PROC_ALL         0
#endif
#ifndef KERN_PROC_PID
#define KERN_PROC_PID         1
#endif
#ifndef KERN_PROC_RUID
#define KERN_PROC_RUID        2
#endif
#ifndef KERN_PROC_SESSION
#define KERN_PROC_SESSION     3
#endif
#ifndef KERN_PROC_UID
#define KERN_PROC_UID         5
#endif

#ifndef HW_MACHINE
#define HW_MACHINE            1
#endif
#ifndef HW_MODEL
#define HW_MODEL              2
#endif
#ifndef HW_NCPU
#define HW_NCPU               3
#endif
#ifndef HW_PAGESIZE
#define HW_PAGESIZE           7
#endif
#ifndef HW_OPTIONAL
#define HW_OPTIONAL           18
#endif
#ifndef HW_PHYSMEM
#define HW_PHYSMEM            19
#endif
#ifndef HW_USERMEM
#define HW_USERMEM            20
#endif
#ifndef HW_VECTORUNIT
#define HW_VECTORUNIT         22
#endif
#ifndef HW_BUS_FREQ
#define HW_BUS_FREQ           23
#endif
#ifndef HW_CPU_FREQ
#define HW_CPU_FREQ           24
#endif
#ifndef HW_CACHELINE
#define HW_CACHELINE          25
#endif
#ifndef HW_MEMSIZE
#define HW_MEMSIZE            27
#endif
#ifndef HW_TB_FREQ
#define HW_TB_FREQ            28
#endif
#ifndef HW_CPU_TYPE
#define HW_CPU_TYPE           30
#endif
#ifndef HW_CPU_SUBTYPE
#define HW_CPU_SUBTYPE        31
#endif
#ifndef HW_CPU_FAMILY
#define HW_CPU_FAMILY         32
#endif

#endif /* DARWIN_PROC_FLAGS_H */
