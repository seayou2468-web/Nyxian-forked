import sys
import re

h_file = 'Nyxian/LindChain/ProcEnvironment/Surface/sys/syscall.h'
with open(h_file, 'r') as f:
    h_content = f.read()

if '#import <LindChain/ProcEnvironment/Surface/sys/cred/setpgrp.h>' not in h_content:
    h_content = h_content.replace(
        '#import <LindChain/ProcEnvironment/Surface/sys/compat/enttoken.h>',
        '#import <LindChain/ProcEnvironment/Surface/sys/compat/enttoken.h>\n#import <LindChain/ProcEnvironment/Surface/sys/cred/setpgrp.h>'
    )
    # Increase SYS_N
    h_content = re.sub(r'#define SYS_N \d+', '#define SYS_N 31', h_content)

with open(h_file, 'w') as f:
    f.write(h_content)

m_file = 'Nyxian/LindChain/ProcEnvironment/Surface/sys/syscall.m'
with open(m_file, 'r') as f:
    m_content = f.read()

new_entries = """    { .name = "SYS_getpgrp",         .sysnum = SYS_getpgrp,      .hndl = GET_SYSCALL_HANDLER(getpgrp)        },
    { .name = "SYS_setpgid",         .sysnum = SYS_setpgid,      .hndl = GET_SYSCALL_HANDLER(setpgid)        },
    { .name = "SYS_getpgid",         .sysnum = SYS_getpgid,      .hndl = GET_SYSCALL_HANDLER(getpgid)        },"""

if 'SYS_getpgrp' not in m_content:
    m_content = m_content.replace(
        '};',
        new_entries + '\n};'
    )

with open(m_file, 'w') as f:
    f.write(m_content)
