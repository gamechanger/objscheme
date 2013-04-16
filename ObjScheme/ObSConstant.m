//
// ObSConstant.m
// GameChanger
//
// Created by Kiril Savino on Tuesday, April 16, 2013
// Copyright 2013 GameChanger. All rights reserved.
//


#import "ObSConstant.h"


@implementation ObSConstant

@synthesize name=_name;
- (id)initWithName:(NSString*)name {
  if ( ( self = [super init] ) ) {
    _name = [name retain];
  }
  return self;
}

- (void)dealloc {
  [_name release];
  [super dealloc];
}

- (NSString*)description {
  return _name;
}

@end

