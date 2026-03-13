import sys
import re

file_path = 'Nyxian/LindChain/ProcEnvironment/Surface/sys/host/sysctl.m'
with open(file_path, 'r') as f:
    content = f.read()

# Add even more OIDs for completeness
extra_handlers = """
int sysctl_hw_cpufamily(sysctl_req_t *req) { return sysctl_handle_int(req, 0x12345678); } // Apple Silicon generic
int sysctl_hw_vectorunit(sysctl_req_t *req) { return sysctl_handle_int(req, 1); }
int sysctl_hw_optional_floatingpoint(sysctl_req_t *req) { return sysctl_handle_int(req, 1); }
int sysctl_kern_bootargs(sysctl_req_t *req) { return sysctl_handle_string(req, "rootdev=/dev/disk0s1"); }
"""
content = content.replace('/* --- Sysctl Functions --- */', '/* --- Sysctl Functions --- */\n' + extra_handlers)

# Update hardware model to a 2026-appropriate string
content = content.replace('"iPhone14,5"', '"iPhone18,3"')

# Update sysctl_map and sysctl_name_map
new_map_additions = """    { { CTL_KERN, KERN_BOOTARGS               }, 2, sysctl_kern_bootargs },
    { { CTL_HW,   HW_CPU_FAMILY               }, 2, sysctl_hw_cpufamily },
    { { CTL_HW,   HW_VECTORUNIT               }, 2, sysctl_hw_vectorunit },
    { { CTL_HW,   HW_OPTIONAL, 1 /* floatingpoint */ }, 3, sysctl_hw_optional_floatingpoint },"""

content = content.replace('    { { CTL_KERN, KERN_HOSTNAME', new_map_additions + '\n    { { CTL_KERN, KERN_HOSTNAME')

new_name_additions = """    { "kern.bootargs",          { CTL_KERN, KERN_BOOTARGS                }, 2 },
    { "hw.cpufamily",           { CTL_HW,   HW_CPU_FAMILY                }, 2 },
    { "hw.vectorunit",          { CTL_HW,   HW_VECTORUNIT                }, 2 },
    { "hw.optional.floatingpoint", { CTL_HW, HW_OPTIONAL, 1              }, 3 },"""

content = content.replace('    { "kern.hostname"', new_name_additions + '\n    { "kern.hostname"')

with open(file_path, 'w') as f:
    f.write(content)
