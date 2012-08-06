//
//  ObSNS.m
//  ObjScheme
//
//  Created by Kiril Savino on 8/6/12.
//  Copyright (c) 2012 GameChanger. All rights reserved.
//

#import "ObSNS.h"
#import "ObjScheme.h"

@implementation ObSNS

+ (void)initializeBridgeFunctions:(ObSScope*)scope {

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"NSDictionary:objectForKey")
                                            fromBlock: ^(id a, id b) { return [(NSMutableDictionary*)a objectForKey: b]; }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"NSDictionary:containsKey")
                                            fromBlock: ^(id a, id b) { return [ObjScheme boolToTruth: [(NSMutableDictionary*)a objectForKey: b] != nil]; }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"NSDictionary:keys")
                                           fromBlock: ^(id a) { return [ObjScheme list: [(NSDictionary*)a allKeys]]; }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"NSDictionary:dictionaryWithObjectsAndKeys")
                                      fromBlock: ^(NSArray* args) {
        NSMutableDictionary* dict = [NSMutableDictionary dictionary];
        NSUInteger length = [args count];
        for ( NSUInteger i = 0; i < length-1; i++ ) {
          [dict setObject: [args objectAtIndex: i] forKey: [args objectAtIndex: i+1]];
        }
        return [NSDictionary dictionaryWithDictionary: dict];
      }]];

  [scope defineFunction: [ObSNativeThunkLambda named: SY(@"NSMutableDictionary:dictionary")
                                           fromBlock: ^() { return [NSMutableDictionary dictionary]; }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"NSMutableDictionary:setObjectForKey")
                                      fromBlock: ^(NSArray* args) {
        NSMutableDictionary* dict = [args objectAtIndex: 0];
        id value = [args objectAtIndex: 1];
        id key = [args objectAtIndex: 2];
        [dict setObject: value forKey: key];
        return [ObjScheme unspecified];
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"NSMutableDictionary:dictionaryWithObjectsAndKeys")
                                      fromBlock: ^(NSArray* args) {
        NSMutableDictionary* dict = [NSMutableDictionary dictionary];
        NSUInteger length = [args count];
        for ( NSUInteger i = 0; i < length-1; i++ ) {
          [dict setObject: [args objectAtIndex: i] forKey: [args objectAtIndex: i+1]];
        }
        return dict;
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"NSArray:array")
                                      fromBlock: ^(NSArray* args) {
        return [NSArray arrayWithArray: args];
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"NSArray:count")
                                           fromBlock: ^(id a) { return [NSNumber numberWithInteger: [(NSArray*)a count]]; }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"NSArray:objectAtIndex")
                                            fromBlock: ^(id a, id b) { return [(NSArray*)a objectAtIndex: [(NSNumber*)b intValue]]; }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"NSMutableArray:array")
                                      fromBlock: ^(NSArray* args) {
        return [NSMutableArray arrayWithArray: args];
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"NSMutableArray:setObjectAtIndex")
                                      fromBlock: ^(NSArray* args) {
        NSMutableArray* array = [args objectAtIndex: 0];
        id object = [args objectAtIndex: 1];
        int index = [(NSNumber*)[args objectAtIndex: 2] intValue];
        [array replaceObjectAtIndex: index withObject: object];
        return [ObjScheme unspecified];
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"NSArray->list")
                                           fromBlock: ^(id x) { return [ObjScheme list: (NSArray*)x]; }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"list->NSArray")
                                           fromBlock: ^(id x) {
        if ( [ObjScheme isEmptyList: x] ) {
          return [NSArray array];

        } else {
          return [(ObSCons*)x toArray];
        }
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"list->NSMutableArray")
                                           fromBlock: ^(id x) {
        if ( [ObjScheme isEmptyList: x] ) {
          return [NSMutableArray array];

        } else {
          return [NSMutableArray arrayWithArray: [(ObSCons*)x toArray]];
        }
      }]];

  /*
    TODOS:
    - OMG AM I DONE?
   */
}

@end