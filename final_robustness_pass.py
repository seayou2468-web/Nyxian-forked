import sys
import re

# 1. Refine kvobject event system to prevent double unregistration calls
event_c = 'Nyxian/LindChain/ProcEnvironment/Surface/obj/event.c'
with open(event_c, 'r') as f:
    content = f.read()

# I'll add a flag to kvevent to track unregistration
event_h = 'Nyxian/LindChain/ProcEnvironment/Surface/obj/defs.h'
with open(event_h, 'r') as f:
    h_content = f.read()
if 'bool unregistered;' not in h_content:
    h_content = h_content.replace('void *ctx;                                      /* pointer to payload MARK: if heap allocated, deallocate it on unregistration */',
                                  'void *ctx;                                      /* pointer to payload MARK: if heap allocated, deallocate it on unregistration */\n    bool unregistered;')
    with open(event_h, 'w') as f:
        f.write(h_content)

# Update event.c to use the flag
content = content.replace(
    'e_event->ctx = context;',
    'e_event->ctx = context;\n    e_event->unregistered = false;'
)

unregister_safe = """
ksurface_return_t kvobject_event_unregister(kvobject_event_t *event)
{
    if (event == NULL || event->owner == NULL) return SURFACE_NULLPTR;

    kvobject_strong_t *owner = event->owner;
    if(!kvo_retain(owner))
    {
        return SURFACE_RETAIN_FAILED;
    }

    pthread_rwlock_wrlock(&(owner->event_rwlock));

    if (event->unregistered) {
        pthread_rwlock_unlock(&(owner->event_rwlock));
        kvo_release(owner);
        return SURFACE_SUCCESS;
    }

    event->unregistered = true;
    event->handler(kvObjEventUnregister, 0, event);

    if(event->previous != NULL)
        event->previous->next = event->next;
    if(event->next != NULL)
        event->next->previous = event->previous;
    if(event->previous == NULL)
        owner->event = event->next;

    pthread_rwlock_unlock(&(owner->event_rwlock));
    kvo_release(owner);
    free(event);

    return SURFACE_SUCCESS;
}
"""

trigger_safe = """
void kvobject_event_trigger(kvobject_strong_t *kvo,
                            kvobject_event_type_t type,
                            uint8_t value)
{
    assert(kvo != NULL && type != kvObjEventCopy);
    if(kvo->base_type != kvObjBaseTypeObject) return;

    pthread_rwlock_wrlock(&(kvo->event_rwlock));

    kvobject_event_t *current = kvo->event;
    while(current != NULL)
    {
        kvobject_event_t *next = current->next;

        bool will_remove = current->handler(type, value, current);
        if(type == kvObjEventDeinit) will_remove = true;

        if(will_remove && !current->unregistered)
        {
            current->unregistered = true;
            current->handler(kvObjEventUnregister, 0, current);

            if(current->previous != NULL)
                current->previous->next = current->next;
            if(current->next != NULL)
                current->next->previous = current->previous;
            if(current->previous == NULL)
                current->owner->event = current->next;

            free(current);
        }

        current = next;
    }

    kvo->main_handler(&kvo, type);
    pthread_rwlock_unlock(&(kvo->event_rwlock));
}
"""

content = re.sub(r'ksurface_return_t kvobject_event_unregister\(.*?\n\}', unregister_safe, content, flags=re.DOTALL)
content = re.sub(r'void kvobject_event_trigger\(.*?\n\}', trigger_safe, content, flags=re.DOTALL)

with open(event_c, 'w') as f:
    f.write(content)

# 2. Fix potential crash in LDEProcess scene creation
process_m = 'Nyxian/LindChain/Multitask/ProcessManager/LDEProcess.m'
with open(process_m, 'r') as f:
    content = f.read()

content = content.replace(
    'innerSelf.scene = [[PrivClass(FBSceneManager) sharedInstance] createSceneWithDefinition:definition initialParameters:parameters];',
    'if (innerSelf.processHandle && innerSelf.processHandle.identity) {\n                                innerSelf.scene = [[PrivClass(FBSceneManager) sharedInstance] createSceneWithDefinition:definition initialParameters:parameters];\n                                innerSelf.scene.delegate = innerSelf;\n                            }'
)

with open(process_m, 'w') as f:
    f.write(content)
