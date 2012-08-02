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



@interface ObSSymbol : NSObject {
  NSString* _string;
}
@property (nonatomic,readonly) NSString* string;
+ (ObSSymbol*)symbolFromString:(NSString*)string;
- (id)initWithString:(NSString*)string;
@end



@protocol ObSProcedure <NSObject>
- (id)invokeWithArguments:(NSArray*)arguments;;
- (ObSSymbol*)name;
@end



@interface ObjScheme : NSObject
+ (ObSScope*)globalScope;
+ (id)parse:(ObSInPort*)inPort;
+ (id)parseString:(NSString*)string;
+ (id)read:(ObSInPort*)inPort;
+ (BOOL)isFalse:(id)token;

- (NSArray*)mapProcedure:(id<ObSProcedure>)procedure onArray:(NSArray*)array;
@end



@interface ObSScope : NSObject {
  ObSScope* _outerScope;
  NSMutableDictionary* _macros;
  NSMutableDictionary* _environ;
}

@property (nonatomic,retain) ObSScope* outer;

- (id)initWithOuterScope:(ObSScope*)outer;
- (id)initWithOuterScope:(ObSScope*)outer
    paramListNameOrNames:(id)parameters
               arguments:(NSArray*)argument;
- (id)resolveSymbol:(ObSSymbol*)variable;
- (void)bootstrapMacros;
- (id)evaluate:(id)token;
- (void)defineFunction:(id<ObSProcedure>)function;
- (void)define:(ObSSymbol*)symbol as:(id)thing;
- (void)defineMacroNamed:(ObSSymbol*)name asProcedure:(id<ObSProcedure>)procedure;
- (BOOL)hasMacroNamed:(ObSSymbol*)name;
- (id<ObSProcedure>)macroNamed:(ObSSymbol*)name;
- (ObSScope*)findScopeOf:(ObSSymbol*)name;

@end



@interface ObSLambda : NSObject <ObSProcedure> {
  NSArray* _argumentNames;
  id _expression;
  ObSScope* _scope;
  ObSSymbol* _name;
}

@property (readonly) NSArray* argumentNames;
@property (readonly) id expression;
@property (readonly) ObSScope* scope;
@property (readonly) ObSSymbol* name;

- (id)initWithArgumentNames:(NSArray*)argumentNames
                 expression:(id)expression
                      scope:(ObSScope*)scope
                       name:(ObSSymbol*)name;
- (id)invokeWithArguments:(NSArray*)arguments;
@end




typedef id (^ObSNativeBlock)(NSArray*);

@interface ObSNativeLambda : NSObject <ObSProcedure> {
  ObSNativeBlock _block;
  ObSSymbol* _name;
}

@property (readonly) ObSSymbol* name;

+ (id)named:(ObSSymbol*)name fromBlock:(ObSNativeBlock)block;
- (id)initWithBlock:(ObSNativeBlock)block name:(ObSSymbol*)name;
- (id)invokeWithArguments:(NSArray*)arguments;

@end



typedef id (^ObSNativeBinaryBlock)(id,id);

@interface ObSNativeBinaryLambda : NSObject <ObSProcedure> {
  ObSNativeBinaryBlock _block;
  ObSSymbol* _name;
}

@property (readonly) ObSSymbol* name;

+ (id)named:(ObSSymbol*)name fromBlock:(ObSNativeBinaryBlock)block;
- (id)initWithBlock:(ObSNativeBinaryBlock)block name:(ObSSymbol*)name;
- (id)invokeWithArguments:(NSArray*)arguments;

@end





typedef id (^ObSNativeUnaryBlock)(id);

@interface ObSNativeUnaryLambda : NSObject <ObSProcedure> {
  ObSNativeUnaryBlock _block;
  ObSSymbol* _name;
}

@property (readonly) ObSSymbol* name;

+ (id)named:(ObSSymbol*)name fromBlock:(ObSNativeUnaryBlock)block;
- (id)initWithBlock:(ObSNativeUnaryBlock)block name:(ObSSymbol*)name;
- (id)invokeWithArguments:(NSArray*)arguments;

@end



@interface ObSInPort : NSObject {
  NSString* _data;
  NSUInteger _cursor;
}
@property (nonatomic,readonly) NSUInteger cursor;
- (id)initWithData:(NSData*)data;
- (id)initWithString:(NSString*)data;
- (id)nextToken;
@end



@interface ObSCons : NSObject {
  id<NSObject> _car;
  id<NSObject> _cdr;
}
@property (nonatomic, retain) id<NSObject> car;
@property (nonatomic, retain) id<NSObject> cdr;
- (id)initWithCar:(id)car cdr:(id)cdr;
- (NSArray*)toArray;
@end





#define SY(s) [ObSSymbol symbolFromString: (s)]
#define MAP(p,a) [ObjScheme mapProcedure: (p) onArray: (a)];
