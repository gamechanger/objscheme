//
// ObSCons.m
// GameChanger
//
// Created by Kiril Savino on Tuesday, April 16, 2013
// Copyright 2013 GameChanger. All rights reserved.
//

#import "ObSCons.h"
#import "ObjScheme.h"

@implementation ObSCons
@synthesize car=_car, cdr=_cdr;

+ (void)initialize {
}

+ (ObSCons*)cons:(id)a and:(id)b {

  return [[[ObSCons alloc] initWithCar: a cdr: b] autorelease];
}

- (id)initWithCar:(id)car cdr:(id)cdr {
  if ( ( self = [super init] ) ) {
    _car = [car retain];
    _cdr = [cdr retain];
  }
  return self;
}

- (void)dealloc {
  [_car release];
  [_cdr release];

  _car = nil;
  _cdr = nil;

  [super dealloc]; // this gets rid of a warning, stupidly
}

- (BOOL)isEqual:(id)obj {
  if ( obj == self ) {
    return YES;

  } else if ( obj == nil || ! [obj isKindOfClass: [ObSCons class]] ) {
    return NO;

  } else {
    ObSCons* cons = obj;
    return [[cons car] isEqual: _car] && [[cons cdr] isEqual: _cdr];
  }
}

- (BOOL)isList {
  id cdr = [self cdr];
  while ( cdr != C_NULL ) {
    if ( ! [cdr isKindOfClass: [ObSCons class]] )
      return NO;
  }
  return YES;
}

- (ObSCons*)clone {
  id cdr = _cdr;
  if ( [cdr isKindOfClass: [ObSCons class]] ) {
    cdr = [cdr clone];
  }
  return [[[ObSCons alloc] initWithCar: _car cdr: cdr] autorelease];
}

- (NSString*)description {
  NSMutableString* d = [NSMutableString string];
  [d appendString: @"("];
  id cell = self;

  while ( cell != C_NULL ) {
    if ( [d length] > 1 ) {
      [d appendString: @" "];
    }

    if ( [cell isKindOfClass: [ObSCons class]] ) {
      ObSCons* next = cell;
      id value = [next car];
      NSString* format = [value isKindOfClass: [NSString class]] ? @"\"%@\"" : @"%@";
      [d appendFormat: format, value];

      cell = [next cdr];

    } else {
      [d appendFormat: @". %@", cell];
      break;
    }
  }

  [d appendString: @")"];
  return d;
}

- (void)populateArray:(NSMutableArray*)array {
  ObSCons* cons = self;

  while ( 1 ) {
    [array addObject: cons.car];

    id cdr = cons.cdr;

    if ( cdr == C_NULL ) {
      break;
    }

    if ( [cdr isKindOfClass: [ObSCons class]] ) {
      cons = cdr;

    } else {
      [array addObject: cdr];
      break;
    }
  }
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state objects:(id*)stackbuf count:(NSUInteger)len {
  id current = (id)state->state;
  if ( current == 0 ){
    current = self;
    state->mutationsPtr = &state->extra[0];

  } else {
    if ( ! [current isKindOfClass: [ObSCons class]] ) {
      // should this fail here?
      return 0; // tail is not a list
    }

    ObSCons* cell = current;
    current = cell.cdr;
  }

  state->state = (unsigned long)current;
  state->itemsPtr = stackbuf;

  if ( current == C_NULL ) {
    return 0;

  } else if ( ! [current isKindOfClass: [ObSCons class]] ) {
    // list tail... should this fail?
    *stackbuf = current;
    return 1;

  } else {
    ObSCons* cell = current;
    stackbuf[0] = cell.car;
    return 1;
  }
}

- (id)cadr {
  ObSCons* next = [self cdr];
  return [next car];
}

- (id)caddr {
  ObSCons* next = [self cdr];
  next = [next cdr];
  return [next car];
}

- (id)cddr {
  ObSCons* next = [self cdr];
  return [next cdr];
}

- (id)cdddr {
  ObSCons* next = [self cdr];
  ObSCons* further = [next cdr];
  return [further cdr];
}

- (NSUInteger)count {
  ObSCons* cell = self;
  NSUInteger length = 0;
  while ( [cell isKindOfClass: [ObSCons class]] ) {
    length++;
    cell = [cell cdr];
  }
  return length;
}

- (NSArray*)toArray {
  NSMutableArray* array = [NSMutableArray array];
  [self populateArray: array];
  return array;
}

@end

