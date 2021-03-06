//
// ObSGarbageCollector.h
// GameChanger
//
// Created by Kiril Savino on Tuesday, April 16, 2013
// Copyright 2013 GameChanger. All rights reserved.
//

@class ObSCollectible;

@interface ObSGarbageCollector : NSObject {
  NSMutableSet* _collectibles;
  ObSCollectible* _root;
  BOOL _synchronous;
}

@property (nonatomic,assign) BOOL synchronous;

- (id)initWithRoot:(ObSCollectible*)root;

- (void)startTracking:(ObSCollectible*)collectible;
- (void)stopTracking:(ObSCollectible*)collectible;
- (void)runGarbageCollection;

@end
