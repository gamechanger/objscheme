//
// ObSSymbol.m
// GameChanger
//
// Created by Kiril Savino on Tuesday, April 16, 2013
// Copyright 2013 GameChanger. All rights reserved.
//

#import "ObSSymbol.h"


@implementation ObSSymbol

@synthesize string=_string;

+ (ObSSymbol*)symbolFromString:(NSString*)string {
  NSAssert( ! [string isEqual: @"#f"], @"no false fool");
  static NSMutableDictionary* __symbols = nil;
  if ( __symbols == nil ) {
    __symbols = [[NSMutableDictionary alloc] init];
  }

  ObSSymbol* symbol = [__symbols objectForKey: string];
  if ( symbol == nil ) {
    symbol = [[ObSSymbol alloc] initWithString: string];
    [__symbols setObject: symbol forKey: string];
    [symbol release];
  }

  return symbol;
}

- (id)initWithString:(NSString*)string {
  if ( ( self = [super init] ) ) {
    _string = [string copy];
  }
  return self;
}

- (void)dealloc {
  [_string release];
  [super dealloc];
}

- (BOOL)isEqual:(id)other {
  return other == self;
}

- (NSUInteger)hash {
  return [_string hash];
}

- (NSString*)description {
  return _string;
}

@end
