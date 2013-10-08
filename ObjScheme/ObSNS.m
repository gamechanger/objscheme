//
//  ObSNS.m
//  ObjScheme
//
//  Created by Kiril Savino on 8/6/12.
//  Copyright (c) 2012, 2013 GameChanger. All rights reserved.
//

#import "ObSNS.h"
#import "ObjScheme.h"

@implementation ObSNS

+ (void)initializeBridgeFunctions:(ObSScope*)scope {

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"NSDictionary:objectForKey")
                                            fromBlock: ^(id dict, id key) {
        id val = [(NSMutableDictionary*)dict objectForKey: key];
        return ( val == nil ? B_FALSE : val );
      }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"NSDictionary:containsKey?")
                                            fromBlock: ^(id dict, id key) {
        return [(NSMutableDictionary*)dict objectForKey: key] != nil ? B_TRUE : B_FALSE;
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"NSDictionary:keys")
                                           fromBlock: ^(id dict) { return [(NSDictionary*)dict allKeys]; }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"NSDictionary:dictionaryWithObjectsAndKeys")
                                      fromBlock: ^(ObSCons* args) {
        NSMutableDictionary* dict = [NSMutableDictionary dictionary];
        while ( (id)args != C_NULL ) {
          [dict setObject: CAR(args) forKey: CADR(args)];
          args = CDDR(args);
        }
        return dict;
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"NSMutableDictionary:whitelist")
                                      fromBlock: ^(ObSCons* args) {
        NSDictionary* dict = CAR(args);
        NSMutableDictionary* new_dict = [NSMutableDictionary dictionary];
        for ( id key in CDR(args) ) {
          new_dict[key] = dict[key];
        }
        return new_dict;
      }]];

  [scope defineFunction: [ObSNativeThunkLambda named: SY(@"NSMutableDictionary:dictionary")
                                           fromBlock: ^() { return [NSMutableDictionary dictionary]; }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"NSMutableDictionary:setObjectForKey")
                                      fromBlock: ^(ObSCons* args) {
        NSMutableDictionary* dict = CAR(args);
        [dict setObject: CADR(args) forKey: CADDR(args)];
        return UNSPECIFIED;
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"NSMutableDictionary:dictionaryWithObjectsAndKeys")
                                      fromBlock: ^(ObSCons* args) {
        NSMutableDictionary* dict = [NSMutableDictionary dictionary];
        while ( (id)args != C_NULL ) {
          [dict setObject: CAR(args) forKey: CADR(args)];
          args = CDDR(args);
        }
        return dict;
      }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"NSMutableDictionary:removeObjectForKey")
                                            fromBlock: ^(id dict, id key) {
        [(NSMutableDictionary*)dict removeObjectForKey: key];
        return [ObjScheme unspecified];
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"NSMutableDictionary:removeAllObjects")
                                           fromBlock: ^(id dict) {
        [(NSMutableDictionary*)dict removeAllObjects];
        return [ObjScheme unspecified];
      }]];
  
  [scope defineFunction: [ObSNativeLambda named: SY(@"NSArray:array")
                                      fromBlock: ^(ObSCons* args) {
        return EMPTY(args) ? [NSArray array] : [args toArray];
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"NSMutableArray:reversedArrayFromArray")
                                           fromBlock: ^(id array) {
        NSMutableArray* ret = [NSMutableArray arrayWithCapacity: [(NSArray*)array count]];
        for ( id x in [(NSArray*)array reverseObjectEnumerator] ) {
          [ret addObject: x];
        }
        return ret;
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"NSMutableArray:alphabetizedArray")
                                           fromBlock: ^(id array) {
        return [(NSArray*)array sortedArrayUsingComparator: ^(id a, id b) {
            NSString* s1 = a;
            NSString* s2 = b;
            return [s1 compare: s2];
          }];
      }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"NSArray:subarrayFromIndex")
                                            fromBlock: ^(id a, id b) {
        NSUInteger index = [(NSNumber*)b intValue];
        NSArray* array = a;
        return [[[array subarrayWithRange: NSMakeRange(index, [array count]-index)] mutableCopy] autorelease];
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"NSArray:subarrayFromIndexToIndex")
                                      fromBlock: ^(ObSCons* args) {
        NSArray* a = CAR(args);
        NSUInteger startIndex = [(NSNumber*)CADR(args) intValue];
        NSInteger endIndex = [(NSNumber*)CADDR(args) intValue];
        if ( endIndex < 0 ) {
          endIndex = [a count] + endIndex;
        }
        if ( endIndex > [a count] ) {
          endIndex = [a count];
        }
        return [NSMutableArray arrayWithArray: [a subarrayWithRange: NSMakeRange(startIndex, endIndex-startIndex)]];
      }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"NSArray:indexOfObject")
                                            fromBlock: ^(id a, id b) {
        NSUInteger index = [(NSArray*)a indexOfObject: b];
        return (id)(index == NSNotFound ? B_FALSE : @(index));
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"NSArray:count")
                                           fromBlock: ^(id a) { return @([(NSArray*)a count]); }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"NSArray:objectAtIndex")
                                            fromBlock: ^(id a, id b) { return [(NSArray*)a objectAtIndex: [(NSNumber*)b intValue]]; }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"NSMutableArray:array")
                                      fromBlock: ^(ObSCons* args) {
        return EMPTY(args) ? [NSMutableArray array] : [args toMutableArray];
      }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"NSMutableArray:addObject")
                                            fromBlock: ^(id array, id object) {
        [(NSMutableArray*)array addObject: object];
        return array;
      }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"NSMutableArray:removeObject")
                                            fromBlock: ^(id array, id object) {
        [(NSMutableArray*)array removeObject: object];
        return array;
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"NSMutableArray:setObjectAtIndex")
                                      fromBlock: ^(ObSCons* args) {
        NSMutableArray* array = CAR(args);
        id object = CADR(args);
        int index = [(NSNumber*)CADDR(args) intValue];
        [array replaceObjectAtIndex: index withObject: object];
        return UNSPECIFIED;
      }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"NSArray:containsObject?")
                                            fromBlock: ^(id array, id object) {
        return [(NSArray*)array containsObject: object] ? B_TRUE : B_FALSE;
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"NSDictionary?")
                                           fromBlock: ^(id x) {
        return [x isKindOfClass: [NSDictionary class]] ? B_TRUE : B_FALSE;
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"NSMutableDictionary?")
                                           fromBlock: ^(id x) {
        return [x isKindOfClass: [NSMutableDictionary class]] ? B_TRUE : B_FALSE;
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"NSArray?")
                                           fromBlock: ^(id x) {
        return [x isKindOfClass: [NSArray class]] ? B_TRUE : B_FALSE;
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"NSMutableArray?")
                                           fromBlock: ^(id x) {
        return [x isKindOfClass: [NSMutableArray class]] ? B_TRUE : B_FALSE;
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"NSArray->list")
                                           fromBlock: ^(id x) { return [ObjScheme list: (NSArray*)x]; }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"list->NSArray")
                                           fromBlock: ^(id x) {
        if ( [ObjScheme isEmptyList: x] ) {
          return (id)[NSArray array];

        } else {
          return (id)[(ObSCons*)x toArray];
        }
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"list->NSMutableArray")
                                           fromBlock: ^(id x) {
        if ( EMPTY(x) ) {
          return (NSMutableArray*) [NSMutableArray array];

        } else {
          return [(ObSCons*)x toMutableArray];
        }
      }]];
}

@end
