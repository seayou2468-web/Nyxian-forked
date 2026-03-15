/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

 This file is part of Nyxian.
*/

#ifndef SURFACE_SYS_SETPGRP_H
#define SURFACE_SYS_SETPGRP_H

#import <LindChain/ProcEnvironment/Surface/surface.h>

DECLARE_SYSCALL_HANDLER(getpgrp);
DECLARE_SYSCALL_HANDLER(setpgid);
DECLARE_SYSCALL_HANDLER(getpgid);

#endif /* SURFACE_SYS_SETPGRP_H */
