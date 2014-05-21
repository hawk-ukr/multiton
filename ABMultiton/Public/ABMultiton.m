//
//  ABMultiton.m
//  ABMultiton
//
//  Created by Alexey Belkevich on 1/13/13.
//  Copyright (c) 2013 okolodev. All rights reserved.
//

#import "ABMultiton.h"
#import "ABMultitonProtocol.h"
#import "ABMultitonInjector.h"
#import "NSOperationQueue+GCD.h"

NSString * const kMultitonException = @"class doesn't conforms to protocol ABMultitonProtocol'";

@interface ABMultiton ()
@property (nonatomic, readonly) NSMutableDictionary *instances;
@property (nonatomic, readonly) NSOperationQueue *queue;
@end

@implementation ABMultiton

#pragma mark - main routine

- (id)init
{
    self = [super init];
    if (self)
    {
        _instances = [[NSMutableDictionary alloc] init];
        _queue = [NSOperationQueue serialQueue];
#if TARGET_OS_IPHONE
        [[NSNotificationCenter defaultCenter]
                               addObserver:self selector:@selector(memoryWarningReceived:)
                                      name:UIApplicationDidReceiveMemoryWarningNotification
                                    object:nil];
#endif
    }
    return self;
}

- (void)dealloc
{
#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#endif
}

#pragma mark - shared instance

+ (instancetype)sharedInstance
{
    static ABMultiton *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        instance = [[ABMultiton alloc] init];
    });
    return instance;
}

#pragma mark - load

+ (void)load
{
    [super load];
    @autoreleasepool
    {
        [ABMultitonInjector injectMultitonProtocolMethods];
    }
}

#pragma mark - public

+ (id)sharedInstanceOfClass:(Class)theClass
{
    return [[ABMultiton sharedInstance] sharedInstanceOfClass:theClass withInitBlock:nil];
}

+ (id)sharedInstanceOfClass:(Class)theClass withInitBlock:(id (^)())initBlock
{
    return [[ABMultiton sharedInstance] sharedInstanceOfClass:theClass withInitBlock:initBlock];
}

+ (void)removeInstanceOfClass:(Class)theClass
{
    [[ABMultiton sharedInstance] removeInstanceOfClass:theClass];
}

+ (void)purgeRemovableInstances
{
    [[ABMultiton sharedInstance] purgeRemovableInstances];
}

+ (BOOL)containsInstanceOfClass:(Class)theClass
{
    NSString *className = NSStringFromClass(theClass);
    return ([[ABMultiton sharedInstance] getInstanceForKey:className] != nil);
}

#pragma mark - private

- (id)sharedInstanceOfClass:(Class)theClass withInitBlock:(id (^)())initBlock
{
    NSString *className = NSStringFromClass(theClass);
    if ([theClass conformsToProtocol:@protocol(ABMultitonProtocol)])
    {
        __block id classInstance;
        [self.queue syncBlock:^
        {
            classInstance = [self.instances objectForKey:className];
            if (!classInstance)
            {
                classInstance = initBlock ? initBlock() : [[theClass alloc] init];
                [self.instances setObject:classInstance forKey:className];
            }
        }];
        return classInstance;
    }
    NSString *reason = [NSString stringWithFormat:@"'%@' %@", className, kMultitonException];
    @throw [NSException exceptionWithName:kMultitonException reason:reason userInfo:nil];
}

- (id)getInstanceForKey:(NSString *)key
{
    __block id classInstance = nil;
    [self.queue syncBlock:^
    {
        classInstance = [self.instances objectForKey:key];
    }];
    return classInstance;
}

- (void)removeInstanceOfClass:(Class)theClass
{
    [self.queue asyncBlock:^
    {
        NSString *className = NSStringFromClass(theClass);
        [self.instances removeObjectForKey:className];
    }];
}

- (void)purgeRemovableInstances
{
    [self.queue asyncBlock:^
    {
        NSSet *keys = [self.instances keysOfEntriesPassingTest:^BOOL(id key, id obj, BOOL *stop)
        {
            if ([obj respondsToSelector:@selector(isRemovableInstance)])
            {
                return [obj isRemovableInstance];
            }
            return NO;
        }];
        [self.instances removeObjectsForKeys:[keys allObjects]];
    }];
}

#if TARGET_OS_IPHONE
- (void)memoryWarningReceived:(NSNotification *)notification
{
    [self purgeRemovableInstances];
}
#endif

@end
