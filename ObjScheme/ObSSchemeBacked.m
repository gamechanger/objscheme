//
// ObSSchemeBacked.m
// GameChanger
//
// Created by Kiril Savino on Saturday, December 1, 2012
// Copyright 2012 GameChanger. All rights reserved.
//

#import "ObSSchemeBacked.h"


@implementation ObSBridgedProcedure

+ (ObSBridgedProcedure*)bridge:(id<ObSProcedure>)schemeProc {
  return [[[ObSBridgedProcedure alloc] initWithProcedure: schemeProc] autorelease];
}

- (id)initWithProcedure:(id<ObSProcedure>)schemeProc {
  if ( self = [super init] ) {
    _proc = [schemeProc retain];
  }
  return self;
}

- (id)initWithNativeBlock:(ObSNativeBlock)block {
  if ( self = [super init] ) {
    _nativeBlock = Block_copy(block);
  }
  return self;
}

- (void)dealloc {
  [_proc release];
  Block_release(_nativeBlock);
  [super dealloc];
}

- (id)invokeWithArguments:(ObSCons*)arguments {
  id ret = nil;

  if ( _proc != nil ) {
    ret = [_proc callWith: arguments];

  } else {
    ret = _nativeBlock(arguments);
  }

  if ( [ret conformsToProtocol: @protocol(ObSProcedure)] ) {
    ret = [ObSBridgedProcedure bridge: ret];
  }
  return ret;
}

@end


@implementation ObSSchemeBacked

@synthesize scope=_scope;

- (id)initWithScope:(ObSScope*)scope {
  if ( ( self = [super init] ) ) {
    _scope = [scope retain];
  }
  return self;
}

- (void) dealloc {
  [_scope release];
  [super dealloc];
}

- (void)loadFile:(NSString*)file {
  [_scope.context loadFile: file intoScope: _scope];
}

- (id)schemeObjectForKey:(NSString*)key {
  id value = [_scope resolveSymbol: [ObSSymbol symbolFromString: key]];

  if ( [value conformsToProtocol: @protocol(ObSProcedure)] ) {
    return [ObSBridgedProcedure bridge: value];
  }

  return value;
}

- (id)callFunctionNamed:(NSString*)string {
  return [self callFunctionNamed: string withArguments: (ObSCons*)C_NULL];
}

- (id)callFunctionNamed:(NSString*)string withArgument:(id)argument  {
  ObSBridgedProcedure* proc = [self schemeObjectForKey: string];
  return [proc invokeWithArguments: CONS(argument, C_NULL)];
}

- (id)callFunctionNamed:(NSString*)string withArguments:(ObSCons*)arguments  {
  ObSBridgedProcedure* proc = [self schemeObjectForKey: string];
  return [proc invokeWithArguments: arguments];
}

- (void)setSchemeObject:(id)object forKey:(NSString*)key {
}

- (void)setGlobalSchemeObject:(id)object forKey:(NSString*)key {
}

@end
