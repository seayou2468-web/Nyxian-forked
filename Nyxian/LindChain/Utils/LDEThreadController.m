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

#import <LindChain/Utils/LDEThreadController.h>
#include <sys/sysctl.h>
#include <mach/mach.h>
#include <pthread.h>
#include <stdatomic.h>

static inline void *pthreadBlockTrampoline(void *ptr)
{
    void (^block)(void) = (__bridge_transfer void (^)(void))ptr;
    block();
    return NULL;
}

void LDEPthreadDispatch(void (^code)(void))
{
    pthread_t thread;
    void *blockPointer = (__bridge_retained void *)code;
    pthread_create(&thread, NULL, pthreadBlockTrampoline, blockPointer);
    pthread_detach(thread);
}

int LDEGetOptimalThreadCount(void)
{
    static int cpuCount = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        size_t size = sizeof(int);
        int result = sysctlbyname("hw.logicalcpu_max", &cpuCount, &size, NULL, 0);
        cpuCount = (result == 0 && cpuCount > 0) ? cpuCount : (int)[[NSProcessInfo processInfo] activeProcessorCount];
    });
    return cpuCount;
}

int LDEGetUserSetThreadCount(void)
{
    NSNumber *value = [[NSUserDefaults standardUserDefaults] objectForKey:@"cputhreads"];
    int userSelected = (value && [value isKindOfClass:[NSNumber class]]) ? value.intValue : LDEGetOptimalThreadCount();
    return (userSelected <= 0) ? 1 : userSelected;
}

@interface LDEThreadTask : NSObject
@property (nonatomic, copy) void (^block)(void);
@property (nonatomic, copy) void (^completion)(void);
@end

@implementation LDEThreadTask
@end

@interface LDEThreadController () {
    @public
    pthread_mutex_t _mutex;
    pthread_cond_t _cond;
    NSMutableArray<LDEThreadTask *> *_queue;
    pthread_t *_threads_ptr;
    int _workerCount;
    _Atomic(bool) _shouldExit;
}
@end

static void *LDEWorkerThreadMain(void *arg)
{
    LDEThreadController *controller = (__bridge LDEThreadController *)arg;
    
    while(1)
    {
        LDEThreadTask *task = nil;

        pthread_mutex_lock(&controller->_mutex);
        
        while(controller->_queue.count == 0 && !atomic_load(&controller->_shouldExit))
        {
            pthread_cond_wait(&controller->_cond, &controller->_mutex);
        }
        
        if(atomic_load(&controller->_shouldExit) && controller->_queue.count == 0)
        {
            pthread_mutex_unlock(&controller->_mutex);
            break;
        }
        
        if(controller->_queue.count > 0)
        {
            task = controller->_queue.firstObject;
            [controller->_queue removeObjectAtIndex:0];
        }

        pthread_mutex_unlock(&controller->_mutex);

        if(task)
        {
            if(task.block) task.block();
            if(task.completion) task.completion();
        }
    }
    
    return NULL;
}

@implementation LDEThreadController

- (instancetype)initWithThreads:(uint32_t)threads
{
    self = [super init];
    if(self)
    {
        _workerCount = (threads == 0) ? 1 : threads;
        _queue = [[NSMutableArray alloc] init];
        pthread_mutex_init(&_mutex, NULL);
        pthread_cond_init(&_cond, NULL);
        atomic_init(&_shouldExit, false);

        _threads_ptr = calloc(_workerCount, sizeof(pthread_t));
        for(int i = 0; i < _workerCount; i++)
        {
            pthread_create(&_threads_ptr[i], NULL, LDEWorkerThreadMain, (__bridge void *)self);
        }
    }
    return self;
}

- (instancetype)init
{
    return [self initWithThreads:LDEGetOptimalThreadCount()];
}

- (instancetype)initWithUsersetThreadCount
{
    return [self initWithThreads:LDEGetUserSetThreadCount()];
}

- (void)dispatchExecution:(void (^)(void))code
           withCompletion:(void (^)(void))completion
{
    if(code == NULL || _lockdown)
    {
        if(completion) completion();
        return;
    }
    
    LDEThreadTask *task = [[LDEThreadTask alloc] init];
    task.block = code;
    task.completion = completion;
    
    pthread_mutex_lock(&_mutex);
    [_queue addObject:task];
    pthread_cond_signal(&_cond);
    pthread_mutex_unlock(&_mutex);
}

- (void)dealloc
{
    atomic_store(&_shouldExit, true);
    pthread_mutex_lock(&_mutex);
    pthread_cond_broadcast(&_cond);
    pthread_mutex_unlock(&_mutex);

    for(int i = 0; i < _workerCount; i++)
    {
        pthread_join(_threads_ptr[i], NULL);
    }

    free(_threads_ptr);
    pthread_mutex_destroy(&_mutex);
    pthread_cond_destroy(&_cond);
}

@end
