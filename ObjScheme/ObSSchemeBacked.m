//
// ObSSchemeBacked.m
// GameChanger
//
// Created by Kiril Savino on Saturday, December 1, 2012
// Copyright 2012 GameChanger. All rights reserved.
//

#import "ObSSchemeBacked.h"
#import "ObjScheme.h"

@implementation ObSSchemeBacked

@synthesize scope=_scope;

- (id)initWithScope:(ObSScope*)scope {
  if ( ( self = [super init] ) ) {
    _scope = [scope retain];
  }
  return self;
}

- (void)loadFile:(NSString*)file {
  [ObjScheme loadFile: file intoScope: _scope];
}

@end
