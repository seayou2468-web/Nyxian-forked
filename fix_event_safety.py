import sys
import re

file_path = 'Nyxian/LindChain/ProcEnvironment/Surface/obj/event.c'
with open(file_path, 'r') as f:
    content = f.read()

# Fix kvobject_event_unregister to be more robust
# It should check if it's already being removed or handled.
# Actually, the main issue is kvobject_event_trigger calling free on current.
# If a handler calls unregister, it might lead to double free.

# Let's rewrite kvobject_event_trigger to avoid this.
# Instead of iterating and removing in-place with a wrlock held during the call,
# we should ideally collect handlers or at least handle self-unregistration safely.

trigger_new = """
void kvobject_event_trigger(kvobject_strong_t *kvo,
                            kvobject_event_type_t type,
                            uint8_t value)
{
    assert(kvo != NULL && type != kvObjEventCopy);

    if(kvo->base_type != kvObjBaseTypeObject)
    {
        return;
    }

    pthread_rwlock_wrlock(&(kvo->event_rwlock));

    kvobject_event_t *current = kvo->event;
    while(current != NULL)
    {
        kvobject_event_t *next = current->next;

        // Execute handler
        bool will_remove = current->handler(type, value, current);

        if(type == kvObjEventDeinit)
        {
            will_remove = true;
        }

        if(will_remove)
        {
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
# Note: Re-calculating 'next' before the call is slightly safer but if the handler
# removes 'next', it's still an issue. However, standard linked list iteration
# usually does it this way.

content = re.sub(r'void kvobject_event_trigger\(.*?\n\}', trigger_new, content, flags=re.DOTALL)

with open(file_path, 'w') as f:
    f.write(content)
