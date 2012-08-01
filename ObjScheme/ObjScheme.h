//
//  ObjScheme.h
//  ObjScheme
//
//  Created by Kiril Savino on 7/30/12.
//  Copyright (c) 2012 GameChanger. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ObSScope;
@class ObSInPort;

@interface ObjScheme : NSObject
+ (ObSScope*)globalScope;
+ (id)parse:(ObSInPort*)inPort;
+ (id)parseString:(NSString*)string;
+ (id)read:(ObSInPort*)inPort;
@end


@interface ObSSymbol : NSObject {
  NSString* _string;
}
+ (ObSSymbol*)symbolFromString:(NSString*)string;
- (id)initWithString:(NSString*)string;
@end


@class ObSInvocation;

@interface ObSScope : NSMutableDictionary {
  ObSScope* _outerScope;
  NSMutableDictionary* _macros;
}

@property (nonatomic,retain) ObSScope* outer;

- (id)initWithOuterScope:(ObSScope*)outer;
- (id)initWithOuterScope:(ObSScope*)outer
    paramListNameOrNames:(id)parameters
               arguments:(NSArray*)argument;
- (id)resolveVariable:(NSString*)variable;
- (void)bootstrapMacros;
- (id)evaluate:(id)token;
- (void)defineMacroNamed:(NSString*)name asInvocation:(ObSInvocation*)procedure;
- (BOOL)hasMacroNamed:(NSString*)name;
- (ObSInvocation*)macroNamed:(NSString*)name;
- (ObSScope*)findScopeOf:(NSString*)name;

@end




@interface ObSProcedure : NSObject {
  NSArray* _argumentNames;
  id _expression;
  ObSScope* _scope;
}

@property (readonly) NSArray* argumentNames;
@property (readonly) id expression;
@property (readonly) ObSScope* scope;

- (id)initWithArgumentNames:(NSArray*)argumentNames
                 expression:(id)expression
                      scope:(ObSScope*)scope;
@end




typedef id (^ObSInvocationBlock)(NSArray*);

@interface ObSInvocation : NSObject {
  ObSInvocationBlock _block;
}

+ (id)fromBlock:(ObSInvocationBlock)block;
- (id)initWithBlock:(ObSInvocationBlock)block;
- (id)invokeWithArguments:(NSArray*)arguments;

@end



@interface ObSInPort : NSObject {
  NSString* _data;
  NSUInteger _cursor;
}
- (id)initWithData:(NSData*)data;
- (id)initWithString:(NSString*)data;
- (NSString*)nextToken;
@end



@interface ObSCons : NSObject {
  id<NSObject> _car;
  id<NSObject> _cdr;
}
@property (nonatomic, retain) id<NSObject> car;
@property (nonatomic, retain) id<NSObject> cdr;
- (id)car;
- (id)cdr;
@end



