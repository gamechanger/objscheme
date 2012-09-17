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
@class ObSCons;



@interface ObSSymbol : NSObject {
  NSString* _string;
}
@property (nonatomic,readonly) NSString* string;
+ (ObSSymbol*)symbolFromString:(NSString*)string;
- (id)initWithString:(NSString*)string;
@end



@protocol ObSProcedure <NSObject>
- (id)callWith:(ObSCons*)args;
- (ObSSymbol*)name;
@end



@interface ObjScheme : NSObject
+ (ObSScope*)globalScope;
+ (id)parse:(ObSInPort*)inPort;
+ (id)parseString:(NSString*)string;
+ (id)read:(ObSInPort*)inPort;
+ (BOOL)isFalse:(id)token;

+ (id)map:(id<ObSProcedure>)procedure on:(id)list;
+ (NSArray*)filter:(ObSCons*)list with:(id<ObSProcedure>)procedure;
+ (ObSCons*)list:(NSArray*)array;
+ (id)boolToTruth:(BOOL)b;
+ (BOOL)isEmptyList:(id)token;
+ (id)unspecified;
@end



@interface ObSScope : NSObject {
  ObSScope* _outerScope;
  NSMutableDictionary* _macros;
  NSMutableDictionary* _environ;
}

@property (nonatomic,retain) ObSScope* outer;
@property (nonatomic,retain) NSMutableDictionary* environ;

- (id)initWithOuterScope:(ObSScope*)outer;
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
  ObSSymbol* _listParameter;
  ObSCons* _parameters;
  id _expression;
  ObSScope* _scope;
  ObSSymbol* _name;
}

@property (readonly) ObSSymbol* listParameter;
@property (readonly) ObSCons* parameters;
@property (readonly) id expression;
@property (readonly) ObSScope* scope;
@property (readonly) ObSSymbol* name;

- (id)initWithParameters:(id)parameters
              expression:(id)expression
                   scope:(ObSScope*)scope
                    name:(ObSSymbol*)name;
- (id)callWith:(ObSCons*)arguments;
@end




typedef id (^ObSNativeBlock)(NSArray*);

@interface ObSNativeLambda : NSObject <ObSProcedure> {
  ObSNativeBlock _block;
  ObSSymbol* _name;
}

@property (readonly) ObSSymbol* name;

+ (id)named:(ObSSymbol*)name fromBlock:(ObSNativeBlock)block;
- (id)initWithBlock:(ObSNativeBlock)block name:(ObSSymbol*)name;
- (id)callWith:(ObSCons*)arguments;

@end



typedef id (^ObSNativeBinaryBlock)(id,id);

@interface ObSNativeBinaryLambda : NSObject <ObSProcedure> {
  ObSNativeBinaryBlock _block;
  ObSSymbol* _name;
}

@property (readonly) ObSSymbol* name;

+ (id)named:(ObSSymbol*)name fromBlock:(ObSNativeBinaryBlock)block;
- (id)initWithBlock:(ObSNativeBinaryBlock)block name:(ObSSymbol*)name;
- (id)callWith:(ObSCons*)arguments;

@end





typedef id (^ObSNativeUnaryBlock)(id);

@interface ObSNativeUnaryLambda : NSObject <ObSProcedure> {
  ObSNativeUnaryBlock _block;
  ObSSymbol* _name;
}

@property (readonly) ObSSymbol* name;

+ (id)named:(ObSSymbol*)name fromBlock:(ObSNativeUnaryBlock)block;
- (id)initWithBlock:(ObSNativeUnaryBlock)block name:(ObSSymbol*)name;
- (id)callWith:(ObSCons*)arguments;

@end




typedef id (^ObSNativeThunkBlock)();

@interface ObSNativeThunkLambda : NSObject <ObSProcedure> {
  ObSNativeThunkBlock _block;
  ObSSymbol* _name;
}

@property (readonly) ObSSymbol* name;

+ (id)named:(ObSSymbol*)name fromBlock:(ObSNativeThunkBlock)block;
- (id)initWithBlock:(ObSNativeThunkBlock)block name:(ObSSymbol*)name;
- (id)callWith:(ObSCons*)arguments;

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



@interface ObSCons : NSObject <NSFastEnumeration> {
  id _car;
  id _cdr;
}
@property (nonatomic, retain) id car;
@property (nonatomic, retain) id cdr;
- (id)initWithCar:(id)car cdr:(id)cdr;
- (id)cadr;
- (id)caddr;
- (id)cddr;
- (NSArray*)toArray;
- (NSUInteger)count;
@end



@interface ObSConstant : NSObject {
  NSString* _name;
}
@property (nonatomic,readonly) NSString* name;
- (id)initWithName:(NSString*)name;
@end




#define SY(s) [ObSSymbol symbolFromString: (s)]
#define MAP(p,a) [ObjScheme mapProcedure: (p) onArray: (a)];
