//
// ObSLambda.m
// GameChanger
//
// Created by Kiril Savino on Tuesday, April 16, 2013
// Copyright 2013 GameChanger. All rights reserved.
//

#import "ObSLambda.h"
#import "ObSScope.h"
#import "ObSSymbol.h"
#import "ObSCons.h"
#import "ObjScheme.h"

@implementation ObSLambda

@synthesize scope=_scope;
@synthesize expression=_expression;
@synthesize parameters=_parameters;
@synthesize listParameter=_listParameter;
@synthesize name=_name;

- (id)initWithParameters:(id)parameters
              expression:(id)expression
                   scope:(ObSScope*)scope
                    name:(ObSSymbol*)name {

  if ( (self = [self init]) ) {
    if ( [parameters isKindOfClass: [ObSCons class]] ) {
      _parameters = [parameters retain];
      ObSCons* cell = _parameters;
      ObSCons* last = nil;

      while ( [cell isKindOfClass: [ObSCons class]] ) {
        if ( [cell car] == S_DOT ) {
          NSAssert(last, @". as first param invalid");
          _listParameter = [[cell cadr] retain];
          [last setCdr: C_NULL];
          break;
        }

        last = cell;
        cell = [cell cdr];
      }

    } else if ( parameters != C_NULL ) {
      _listParameter = [parameters retain];
    }

    _expression = [expression retain];
    _scope = [scope retain];
    _name = [name retain];
  }

  return self;
}

- (oneway void)release {
  NSInteger retainCount = [self retainCount];
  [super release];
  if ( retainCount == 2 ) {
    if ( [_scope retainCount] == 1 ) {
      [_scope release];
      _scope = nil;
    }
  }
}

- (void)dealloc {
  [_listParameter release];
  _listParameter = nil;
  [_parameters release];
  _parameters = nil;
  [_expression release];
  _expression = nil;
  [_scope release];
  _scope = nil;
  [_name release];
  _name = nil;
  [super dealloc];
}

- (ObSSymbol*)name {
  return (_name == nil ? S_LAMBDA : _name);
}

- (id)callWith:(ObSCons*)arguments {
  ObSScope* invocationScope = [[ObSScope alloc] initWithOuterScope: _scope];
  if ( _parameters != nil ) {
    // for each parameter, pop something off the top of arguments...
    for ( ObSSymbol* key in _parameters ) {
      NSAssert1((id)arguments != C_NULL, @"ran out of arguments for %@", _parameters);
      [invocationScope define: key as: [arguments car]];
      arguments = [arguments cdr];
    }

    if ( (id)arguments != C_NULL ) {
      NSAssert( _listParameter, @"too many arguments" );
    }

    if ( _listParameter ) {
      [invocationScope define: _listParameter as: arguments];
    }

  } else if ( _listParameter != nil ) {
    [invocationScope define: _listParameter as: arguments];
  }

  id ret = [invocationScope evaluate: _expression];
  [invocationScope release]; // trying to be conservative with memory in highly recursive environment here
  return ret;
}

@end





@implementation ObSNativeLambda

+ (id)named:(ObSSymbol*)name fromBlock:(ObSNativeBlock)block {
  return [[[ObSNativeLambda alloc] initWithBlock: block name: name] autorelease];
}

- (id)initWithBlock:(ObSNativeBlock)block name:(ObSSymbol*)name {
  if ( ( self = [super init] ) ) {
    _block = Block_copy(block);
    _name = [name retain];
  }
  return self;
}

- (ObSSymbol*)name {
  return (_name == nil ? S_LAMBDA : _name);
}

- (void)dealloc {
  Block_release(_block);
  [_name release];
  [super dealloc];
}

- (ObSNativeBlock)nativeBlock {
  return _block;
}

- (id)callWith:(ObSCons*)arguments {
  if ( (id)arguments == C_NULL ) {
    return _block([NSArray array]);

  } else {
    return _block([arguments toArray]);
  }
}

@end





@implementation ObSNativeBinaryLambda

+ (id)named:(ObSSymbol*)name fromBlock:(ObSNativeBinaryBlock)block {
  return [[[ObSNativeBinaryLambda alloc] initWithBlock: block name: name] autorelease];
}

- (id)initWithBlock:(ObSNativeBinaryBlock)block name:(ObSSymbol*)name {
  if ( ( self = [super init] ) ) {
    _block = Block_copy(block);
    _name = [name retain];
  }
  return self;
}

- (void)dealloc {
  Block_release(_block);
  [_name release];
  [super dealloc];
}

- (id)callWith:(ObSCons*)list {
  NSAssert([list count] == 2, @"Oops, should pass 2 args to binary lambda %@", _name);
  return _block([list car], [list cadr]);
}

- (ObSSymbol*)name {
  return (_name == nil ? S_LAMBDA : _name);
}

@end






@implementation ObSNativeUnaryLambda

+ (id)named:(ObSSymbol*)name fromBlock:(ObSNativeUnaryBlock)block {
  return [[[ObSNativeUnaryLambda alloc] initWithBlock: block name: name] autorelease];
}

- (id)initWithBlock:(ObSNativeUnaryBlock)block name:(ObSSymbol*)name {
  if ( ( self = [super init] ) ) {
    _block = Block_copy(block);
    _name = [name retain];
  }
  return self;
}

- (void)dealloc {
  Block_release(_block);
  [_name release];
  [super dealloc];
}

- (id)callWith:(ObSCons*)list {
  NSAssert([list count] == 1, @"Oops, should pass 1 args to unary lambda %@", _name);
  return _block([list car]);
}

- (id)callNatively:(id)arg {
  return _block(arg);
}

- (ObSSymbol*)name {
  return (_name == nil ? S_LAMBDA : _name);
}

@end




@implementation ObSNativeThunkLambda

+ (id)named:(ObSSymbol*)name fromBlock:(ObSNativeThunkBlock)block {
  return [[[ObSNativeThunkLambda alloc] initWithBlock: block name: name] autorelease];
}

- (id)initWithBlock:(ObSNativeThunkBlock)block name:(ObSSymbol*)name {
  if ( ( self = [super init] ) ) {
    _block = Block_copy(block);
    _name = [name retain];
  }
  return self;
}

- (void)dealloc {
  Block_release(_block);
  [_name release];
  [super dealloc];
}

- (id)callWith:(ObSCons*)list {
  NSAssert((id)list == C_NULL, @"Oops, should pass 0 args to thunk lambda %@", _name);
  return _block();
}

- (ObSSymbol*)name {
  return (_name == nil ? S_LAMBDA : _name);
}

@end