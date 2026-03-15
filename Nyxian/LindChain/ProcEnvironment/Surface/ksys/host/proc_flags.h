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

#include <sys/param.h>

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

#ifndef MAXCOMLEN
#define MAXCOMLEN 16
#endif

/*
 * proc_info Call Types
 */
#ifndef PROC_INFO_CALL_LISTPIDS
#define PROC_INFO_CALL_LISTPIDS         1
#endif

#ifndef PROC_INFO_CALL_PIDINFO
#define PROC_INFO_CALL_PIDINFO          2
#endif

#ifndef PROC_INFO_CALL_PIDFDINFO
#define PROC_INFO_CALL_PIDFDINFO        3
#endif

#ifndef PROC_INFO_CALL_KERNMSGBUF
#define PROC_INFO_CALL_KERNMSGBUF       4
#endif

#ifndef PROC_INFO_CALL_SETCONTROL
#define PROC_INFO_CALL_SETCONTROL       5
#endif

#ifndef PROC_INFO_CALL_PIDFILEPORTINFO
#define PROC_INFO_CALL_PIDFILEPORTINFO  6
#endif

#ifndef PROC_INFO_CALL_TERMINATEPIDS
#define PROC_INFO_CALL_TERMINATEPIDS    7
#endif

#ifndef PROC_INFO_CALL_DIRTYCONTROL
#define PROC_INFO_CALL_DIRTYCONTROL     8
#endif

#ifndef PROC_INFO_CALL_PIDADDRINFO
#define PROC_INFO_CALL_PIDADDRINFO      9
#endif

/*
 * proc_info Flavors
 */
#ifndef PROC_PIDLISTPIDS
#define PROC_PIDLISTPIDS                1
#endif

#ifndef PROC_PIDTASKALLINFO
#define PROC_PIDTASKALLINFO             2
#endif

#ifndef PROC_PIDTBSDINFO
#define PROC_PIDTBSDINFO                3
#endif

#ifndef PROC_PIDTASKINFO
#define PROC_PIDTASKINFO                4
#endif

#ifndef PROC_PIDSTATSINFO
#define PROC_PIDSTATSINFO               5
#endif

#ifndef PROC_PIDLISTFDS
#define PROC_PIDLISTFDS                 6
#endif

#ifndef PROC_PIDFDINFO
#define PROC_PIDFDINFO                  7
#endif

#ifndef PROC_PIDTHREADINFO
#define PROC_PIDTHREADINFO              8
#endif

#ifndef PROC_PIDLISTTHREADS
#define PROC_PIDLISTTHREADS             9
#endif

#ifndef PROC_PIDREGIONINFO
#define PROC_PIDREGIONINFO              10
#endif

#ifndef PROC_PIDREGIONPATHINFO
#define PROC_PIDREGIONPATHINFO          11
#endif

#ifndef PROC_PIDVNODEPATHINFO
#define PROC_PIDVNODEPATHINFO           12
#endif

#ifndef PROC_PIDPATHINFO
#define PROC_PIDPATHINFO                13
#endif

#ifndef PROC_PIDWORKQUEUEINFO
#define PROC_PIDWORKQUEUEINFO           14
#endif

#ifndef PROC_PIDTHREADIDINFO
#define PROC_PIDTHREADIDINFO            15
#endif

#ifndef PROC_PIDLISTFILEPORTS
#define PROC_PIDLISTFILEPORTS           16
#endif

/*
 * FD Info Types
 */
#ifndef PROC_PIDFDVNODEINFO
#define PROC_PIDFDVNODEINFO             1
#endif

#ifndef PROC_PIDFDSOCKINFO
#define PROC_PIDFDSOCKINFO              2
#endif

#ifndef PROC_PIDFDPSEHMINFO
#define PROC_PIDFDPSEHMINFO             3
#endif

#ifndef PROC_PIDFDPIPEINFO
#define PROC_PIDFDPIPEINFO              4
#endif

#ifndef PROC_PIDFDKQUEUEINFO
#define PROC_PIDFDKQUEUEINFO            5
#endif

#ifndef PROC_PIDFDATALKINFO
#define PROC_PIDFDATALKINFO             6
#endif

#endif /* DARWIN_PROC_FLAGS_H */
