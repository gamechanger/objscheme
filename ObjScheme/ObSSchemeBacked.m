//
// ObSSchemeBacked.m
// GameChanger
//
// Created by Kiril Savino on Saturday, December 1, 2012
// Copyright 2012 GameChanger. All rights reserved.
//

#import "ObSSchemeBacked.h"
#import "ObjScheme.h"

@implementation ObSSchemeBacked

// -- static stuff -- //

+ (NSString*)toSchemeName:(NSString*)cocoaName {
  NSRegularExpression* finalP = [NSRegularExpression regularExpressionWithPattern: @"_p$"
                                                                          options: 0
                                                                            error: nil];
  NSString* schemeName = [finalP stringByReplacingMatchesInString: cocoaName
                                                          options: 0
                                                            range: NSMakeRange(0, [cocoaName length])
                                                     withTemplate: @"?"];
  return [schemeName stringByReplacingOccurrencesOfString: @"_" withString: @"-"];
}

+ (NSString*)toCocoaName:(NSString*)schemeName {
  NSRegularExpression* finalP = [NSRegularExpression regularExpressionWithPattern: @"\\?$"
                                                                          options: 0
                                                                            error: nil];
  NSString* cocoaName = [finalP stringByReplacingMatchesInString: schemeName
                                                         options: 0
                                                           range: NSMakeRange(0, [schemeName length])
                                                    withTemplate: @"_p"];
  return [cocoaName stringByReplacingOccurrencesOfString: @"-" withString: @"_"];
}

// -- object methods below here -- //

- (id)initWithScope:(ObSScope*)scope {
  if ( ( self = [super init] ) ) {
    _scope = [scope retain];
  }
  return self;
}

- (NSMethodSignature*)methodSignatureForSelector:(SEL)selector {
  NSMethodSignature* ret = [super methodSignatureForSelector: selector];
  if ( ret != nil ) {
    return ret;
  }

  NSString* schemeName = [ObSSchemeBacked toCocoaName: NSStringFromSelector(selector)];
  NSDictionary* environ = _scope.environ;
  if ( [environ objectForKey: schemeName] ) {
    /*
      Return type is object (id) / ptr.
     |
     |  self (implied) is a ptr
     | |
     | |  selector (implied)
     | | |
     | | | takes 1 param, an NSArray*
     | | | |
     v v v v
     @ @ : @
    */
    return [NSMethodSignature signatureWithObjCTypes: "@@:@"];
  }

  return nil;
}

- (void)forwardInvocation:(NSInvocation*)invocation {
  NSInteger firstArgumentIndex = 2; // 0 = self, 1 = selector
  NSArray* args = NULL;
  [invocation getArgument: &args atIndex: firstArgumentIndex];
  ObSCons* schemeArgs = [ObjScheme list: args];
  NSString* schemeFunctionName = [ObSSchemeBacked toSchemeName: NSStringFromSelector(invocation.selector)];
  NSArray* schemeCall = [NSArray arrayWithObjects: schemeFunctionName, schemeArgs, nil];
  [invocation setReturnValue: [_scope evaluate: [ObjScheme list: schemeCall]]];
}

- (void)loadFile:(NSString*)file {
  [ObjScheme loadFile: file intoScope: _scope];
}

@end
