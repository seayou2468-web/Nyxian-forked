import sys
import re

file_path = 'Nyxian/LindChain/ProcEnvironment/Surface/obj/alloc.c'
with open(file_path, 'r') as f:
    content = f.read()

# Fix kvobject_alloc to initialize event_rwlock
content = content.replace(
    'pthread_rwlock_init(&(kvo->rwlock), NULL);  /* initilizing the lock lol */',
    'pthread_rwlock_init(&(kvo->rwlock), NULL);  /* initilizing the lock lol */\n    pthread_rwlock_init(&(kvo->event_rwlock), NULL); /* initilizing the other lock lol */'
)

# Also fix the cleanup path if main_handler fails
content = content.replace(
    'pthread_rwlock_destroy(&(kvo->rwlock));\n        free(kvo);\n        return NULL;',
    'pthread_rwlock_destroy(&(kvo->rwlock));\n        pthread_rwlock_destroy(&(kvo->event_rwlock));\n        free(kvo);\n        return NULL;'
)

with open(file_path, 'w') as f:
    f.write(content)
