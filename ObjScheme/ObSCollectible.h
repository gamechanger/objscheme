//
// ObSCollectible.h
// GameChanger
//
// Created by Kiril Savino on Tuesday, April 16, 2013
// Copyright 2013 GameChanger. All rights reserved.
//

@class ObSGarbageCollector;

@interface ObSCollectible : NSObject {
@public
  ObSGarbageCollector* _garbageCollector;
}

- (NSArray*)children;
- (void)releaseChildren;

@end
