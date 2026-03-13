import sys
import re

# 1. Fix Radix Tree Walk bug
radix_c = 'Nyxian/LindChain/ProcEnvironment/Surface/radix/radix.c'
with open(radix_c, 'r') as f:
    content = f.read()

content = content.replace(
    'callback(ident_prefix, node->slots[i], ctx);',
    'callback(ident, node->slots[i], ctx);'
)

content = content.replace(
    'radix_walk_node((radix_node_t *)node->slots[i], level + 1, ident_prefix, callback, ctx);',
    'radix_walk_node((radix_node_t *)node->slots[i], level + 1, ident, callback, ctx);'
)

# 2. Improve radix_remove to clean up root if empty
remove_logic = """
    if(all_null)
    {
        free(path[level]);
        if(level > 0)
            path[level - 1]->slots[chunks[level - 1]] = NULL;
        else
            tree->root = NULL;
    }
    else
    {
        break;
    }
"""
content = re.sub(r'if\(all_null && level > 0\).*?else.*?\{.*?break;.*?\}', remove_logic, content, flags=re.DOTALL)

with open(radix_c, 'w') as f:
    f.write(content)

# 3. Make kvobject_event_trigger safer
event_c = 'Nyxian/LindChain/ProcEnvironment/Surface/obj/event.c'
with open(event_c, 'r') as f:
    content = f.read()

# We will collect handlers in a local array to call them safely without holding the lock during execution
# This prevents deadlocks if a handler calls another function that tries to lock the same object.
safe_trigger = """
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

    // First pass: collect handlers that need to be called
    // We limit to a reasonable number to avoid huge stack allocations
    kvobject_event_t *handlers[KVOBJECT_EVENT_MAX];
    int count = 0;

    kvobject_event_t *it = kvo->event;
    while(it != NULL && count < KVOBJECT_EVENT_MAX)
    {
        handlers[count++] = it;
        it = it->next;
    }

    // Now we unlock and call handlers? No, handlers might remove themselves.
    // If we unlock, the list might change.
    // If we hold the lock, we risk deadlocks.
    // Given the architecture, handlers returning 'true' for removal is the main pattern.

    for(int i = 0; i < count; i++)
    {
        kvobject_event_t *current = handlers[i];

        // We still hold the write lock here. To be truly safe against deadlocks,
        // handlers should not take other locks that might be held by the caller of trigger.

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
    }

    kvo->main_handler(&kvo, type);
    pthread_rwlock_unlock(&(kvo->event_rwlock));
}
"""
# The previous trigger code I wrote was actually similar.
# The key is to ensure 'next' is captured BEFORE calling the handler if the handler might free 'current'.
# My previous implementation did: next = current->next; bool will_remove = current->handler(...); ... current = next;
# That's standard and safe for removal during iteration AS LONG AS NO OTHER THREAD MUTATES THE LIST.
# Since we hold the wrlock, it's safe. The only risk is if the handler triggers another event on the same object.

# I will keep the current implementation but fix a potential null deref in unregister
unregister_fix = """
ksurface_return_t kvobject_event_unregister(kvobject_event_t *event)
{
    if (event == NULL || event->owner == NULL) return SURFACE_NULLPTR;

    kvobject_strong_t *owner = event->owner;
    if(!kvo_retain(owner))
    {
        return SURFACE_RETAIN_FAILED;
    }

    pthread_rwlock_wrlock(&(owner->event_rwlock));

    // Safety check: is the event still in the owner's list?
    bool found = false;
    kvobject_event_t *it = owner->event;
    while(it) { if(it == event) { found = true; break; } it = it->next; }

    if(found) {
        event->handler(kvObjEventUnregister, 0, event);

        if(event->previous != NULL)
            event->previous->next = event->next;
        if(event->next != NULL)
            event->next->previous = event->previous;
        if(event->previous == NULL)
            owner->event = event->next;

        free(event);
    }

    pthread_rwlock_unlock(&(owner->event_rwlock));
    kvo_release(owner);

    return found ? SURFACE_SUCCESS : SURFACE_NOT_FOUND;
}
"""
content = re.sub(r'ksurface_return_t kvobject_event_unregister\(.*?\n\}', unregister_fix, content, flags=re.DOTALL)

with open(event_c, 'w') as f:
    f.write(content)
