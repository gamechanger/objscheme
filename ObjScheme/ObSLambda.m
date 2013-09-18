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
#import "ObSGarbageCollector.h"

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
      if ( [parameters car] == S_DOT ) { // weird edge case more easily handled here
        _listParameter = [[parameters cadr] retain];

      } else {
        _parameters = [parameters retain];
        ObSCons* parameterCell = _parameters;
        ObSCons* lastParameterCell = nil;

        while ( [parameterCell isKindOfClass: [ObSCons class]] ) {
          if ( [parameterCell car] == S_DOT ) {
            _listParameter = [[parameterCell cadr] retain];
            [lastParameterCell setCdr: C_NULL]; // this is mutating (truncating) the _parameters variable!!!!
            break;
          }

          lastParameterCell = parameterCell;
          parameterCell = [parameterCell cdr];
        }
      }

    } else if ( parameters != C_NULL ) {
      _listParameter = [parameters retain];
    }

    _expression = [expression retain];
    _scope = [scope retain];
    _name = [name retain];
    _scopeName = [[NSString stringWithFormat: @"%@.call", _name] retain];
  }

  return self;
}

- (NSArray*)children {
  return [NSArray arrayWithObject: _scope];
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
  [_invocationScope release];
  _invocationScope = nil;
  [_scopeName release];
  _scopeName = nil;
  [super dealloc];
}

- (ObSSymbol*)name {
  return (_name == nil ? S_LAMBDA : _name);
}

- (NSString*)description {
  return [NSString stringWithFormat: @"ObSLambda '%@' <%@> %p", _name, _expression, self];
}

- (ObSScope*)newInvocationScope {
  if ( _invocationScope == nil ) {
    _invocationScope = [[ObSScope alloc] initWithOuterScope: _scope name: _scopeName];

  } else if ( _scopeInUse ) {
    return [[ObSScope alloc] initWithOuterScope: _scope name: _scopeName];
  }

  _scopeInUse = YES;
  [_invocationScope retain];
  return _invocationScope;
}

- (void)doneWithInvocationScope:(ObSScope*)scope {
  if ( scope == _invocationScope ) {
    _scopeInUse = NO;

    if ( [scope.environ count] > 0 ) {
      [_invocationScope release];
      _invocationScope = nil;
    }
  }
}

- (id)callWith:(ObSCons*)arguments {
  ObSScope* invocationScope = [self newInvocationScope];

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
  [self doneWithInvocationScope: invocationScope];
  [invocationScope release];
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
