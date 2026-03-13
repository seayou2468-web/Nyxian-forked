import sys
import re

file_path = 'Nyxian/LindChain/ProcEnvironment/Surface/sys/host/sysctl.m'
with open(file_path, 'r') as f:
    content = f.read()

# Update hardware model and version strings to 2026/iOS 19 standards
content = content.replace('"iPhone18,3"', '"iPhone18,3"') # iPhone 17 Pro
content = content.replace('"25.0.0"', '"25.0.0"') # Darwin 25
content = content.replace('"25A123"', '"25A123"') # iOS 19 Build

# Add missing OIDs
extra_handlers = """
int sysctl_kern_maxfiles(sysctl_req_t *req) { return sysctl_handle_int(req, 12288); }
int sysctl_kern_maxfilesperproc(sysctl_req_t *req) { return sysctl_handle_int(req, 10240); }
int sysctl_hw_cpu_type(sysctl_req_t *req) { return sysctl_handle_int(req, 0x0100000c); } // CPU_TYPE_ARM64
int sysctl_hw_cpu_subtype(sysctl_req_t *req) { return sysctl_handle_int(req, 2); } // CPU_SUBTYPE_ARM64_V8
"""
content = content.replace('/* --- Sysctl Functions --- */', '/* --- Sysctl Functions --- */\n' + extra_handlers)

# Update maps
new_map_entries = """    { { CTL_KERN, KERN_MAXFILES                }, 2, sysctl_kern_maxfiles },
    { { CTL_KERN, KERN_MAXFILESPERPROC         }, 2, sysctl_kern_maxfilesperproc },"""
content = content.replace('    { { CTL_KERN, KERN_BOOTARGS', new_map_entries + '\n    { { CTL_KERN, KERN_BOOTARGS')

new_name_entries = """    { "kern.maxfiles",          { CTL_KERN, KERN_MAXFILES                }, 2 },
    { "kern.maxfilesperproc",   { CTL_KERN, KERN_MAXFILESPERPROC         }, 2 },
    { "hw.cputype",             { CTL_HW,   HW_CPU_TYPE                  }, 2 },
    { "hw.cpusubtype",          { CTL_HW,   HW_CPU_SUBTYPE               }, 2 },"""
content = content.replace('    { "kern.bootargs"', new_name_entries + '\n    { "kern.bootargs"')

with open(file_path, 'w') as f:
    f.write(content)
