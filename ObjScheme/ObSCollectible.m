//
// ObSCollectible.m
// GameChanger
//
// Created by Kiril Savino on Tuesday, April 16, 2013
// Copyright 2013 GameChanger. All rights reserved.
//

#import "ObSCollectible.h"

#import "ObSGarbageCollector.h"

@implementation ObSCollectible

- (NSArray*)children {
  [NSException raise: @"Not Implemented" format: @"OMG"];
  return nil;
}

- (void)releaseChildren {
  [NSException raise: @"Not Implemented" format: @"OMG"];
}

@end
