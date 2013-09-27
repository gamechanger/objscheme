//
// ObSStrings.m
// GameChanger
//
// Created by Kiril Savino on Saturday, December 1, 2012
// Copyright 2012 GameChanger. All rights reserved.
//

#import "ObSStrings.h"
#import "ObjScheme.h"

@implementation ObSStrings

+ (void)addToScope:(ObSScope*)scope {
  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"string-split")
                                            fromBlock: ^(id s, id d) {
        NSString* string = s;
        NSString* separator = d;
        return [ObjScheme list: [string componentsSeparatedByString: separator]];
      }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"string-startswith?")
                                            fromBlock: ^(id s, id p) {
        return [ObjScheme boolToTruth: [(NSString*)s hasPrefix: (NSString*)p]];
      }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"string-endswith?")
                                            fromBlock: ^(id s, id p) {
        return [ObjScheme boolToTruth: [(NSString*)s hasSuffix: (NSString*)p]];
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"->string")
                                           fromBlock: ^(id x) {
                                             if ( x == (id) kCFBooleanFalse ) {
                                               return @"#f";
                                             } else if ( x == (id) kCFBooleanTrue ) {
                                               return @"#t";
                                             } else {
                                               return [x description];
                                             }
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"println")
                                           fromBlock: ^(id x) {
        NSLog(@"%@", x);
        return [ObjScheme unspecified];
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"format")
                                      fromBlock: ^(ObSCons* args) {
        NSString* formatString = CADR(args);

        NSError* error = NULL;
        NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern: @"~s"
                                                                               options: 0
                                                                                 error: &error];
        NSArray* matches = [regex matchesInString: formatString options: 0 range: NSMakeRange(0, [formatString length])];
        if ( [matches count] == 0 ) {
          return (id)formatString;
        }

        NSArray* formatArgs = [[args toArray] subarrayWithRange: NSMakeRange(2, [args count]-2)];
        NSUInteger numArgs = [formatArgs count];

        NSMutableString* string = [NSMutableString string];
        NSUInteger stringStart = 0;
        NSInteger implicitPositionCounter = -1;

        for ( NSTextCheckingResult* match in matches ) {
          NSRange range = [match range];
          if ( range.location > stringStart ) {
            [string appendString: [formatString substringWithRange: NSMakeRange(stringStart, range.location-stringStart)]];
          }

          NSInteger argumentIndex = ++implicitPositionCounter;
          if ( argumentIndex > numArgs ) {
            [NSException raise: @"InvalidFormat" format: @"implicit index in %@ at position %d", formatString, range.location];
          }
          [string appendFormat: @"%@", [formatArgs objectAtIndex: argumentIndex]];

          stringStart = range.location + range.length;
        }

        if ( stringStart < [formatString length] ) {
          [string appendString: [formatString substringFromIndex: stringStart]];
        }

        return (id)string;

      }]];

}

@end
