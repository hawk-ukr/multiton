//
//  ABSingletonProtocol.h
//  ABMultiton
//
//  Created by Alexey Belkevich on 1/16/13.
//  Copyright (c) 2013 okolodev. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ABSingletonProtocol <NSObject>

+ (instancetype)sharedInstance;

@end
