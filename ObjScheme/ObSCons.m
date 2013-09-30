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
    return (cons->_car == _car || [cons->_car isEqual: _car]) &&
      ( cons->_cdr == _cdr || [cons->_cdr isEqual: _cdr] );
  }
}

- (NSUInteger)hash {
  return (NSUInteger)self;
}

- (BOOL)isList {
  id x = _cdr;
  while ( x != C_NULL ) {
    if ( ! [x isKindOfClass: [ObSCons class]] ) {
      return NO; // this is a pair, it terminates with a value
    }
    x = ((ObSCons*)x)->_cdr;
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
      id value = next->_car;
      NSString* format = [value isKindOfClass: [NSString class]] ? @"\"%@\"" : @"%@";
      [d appendFormat: format, value];

      cell = next->_cdr;

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
    [array addObject: CAR(cons)];

    id cdr = CDR(cons);

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
    current = CDR(cell);
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
    stackbuf[0] = CAR(cell);
    return 1;
  }
}

- (NSUInteger)count {
  ObSCons* cell = self;
  NSUInteger length = 0;
  while ( [cell isKindOfClass: [ObSCons class]] ) {
    length++;
    cell = ((ObSCons*)cell)->_cdr;
  }
  return length;
}

- (NSArray*)toArray {
  return [[[self toMutableArray] copy] autorelease]; // could do the copy/autorelease dance, but lazy.
}

- (NSArray*)toMutableArray {
  NSMutableArray* array = [NSMutableArray array];
  [self populateArray: array];
  return array;
}

- (void)setCdr:(id)cdr {
  if ( cdr != _cdr ) {
    [_cdr release];
    _cdr = [cdr retain];
  }
}

- (void)setCar:(id)car {
  if ( car != _car ) {
    [_car release];
    _car = [car retain];
  }
}

@end

