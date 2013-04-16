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

- (void)setGarbageCollector:(ObSGarbageCollector*)gc {
  _garbageCollector = gc;
}

- (oneway void)release {
  // basically, if we would otherwise be about to hit a reference count of 1
  // otherwise, but we're retained by the Garbage Collector's list,
  // then we tell the GC to let us go, so we can properly hit 0 and dealloc here.
  // otherwise, we'd have to wait for the next GC cycle to go away, which is a waste.
  if ( _garbageCollector != nil && [self retainCount] == 2 ) {
    [_garbageCollector stopTracking: self];
  }
  [super release];
}

- (NSArray*)childCollectibles {
  [NSException raise: @"Not Implemented" format: @"OMG"];
  return nil;
}

- (void)releaseChildren {
  [NSException raise: @"Not Implemented" format: @"OMG"];
}

@end
