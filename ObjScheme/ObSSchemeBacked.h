//
// ObSSchemeBacked.h
// GameChanger
//
// Created by Kiril Savino on Saturday, December 1, 2012
// Copyright 2012 GameChanger. All rights reserved.
//

@class ObSScope;

@interface ObSSchemeBacked : NSObject {
  ObSScope* _scope;
}

@property (nonatomic,readonly) ObSScope* scope;

- (id)initWithScope:(ObSScope*)scope;
- (void)loadFile:(NSString*)file;

@end
