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
@class ObSConstant;
@class ObSSymbol;

extern ObSSymbol* S_DOT;
extern ObSSymbol* S_QUOTE;
extern ObSSymbol* S_IF;
extern ObSSymbol* S_SET;
extern ObSSymbol* S_DEFINE;
extern ObSSymbol* S_LAMBDA;
extern ObSSymbol* S_BEGIN;
extern ObSSymbol* S_DEFINEMACRO;
extern ObSSymbol* S_QUASIQUOTE;
extern ObSSymbol* S_UNQUOTE;
extern ObSSymbol* S_UNQUOTESPLICING;
extern ObSSymbol* S_APPEND;
extern ObSSymbol* S_CONS;
extern ObSSymbol* S_LET;
extern ObSSymbol* S_LET_STAR;
extern ObSSymbol* S_OPENPAREN;
extern ObSSymbol* S_CLOSEPAREN;
extern ObSSymbol* S_LIST;
extern ObSSymbol* S_EVAL;
extern ObSSymbol* S_MAP;
extern ObSSymbol* S_OPENBRACKET;
extern ObSSymbol* S_CLOSEBRACKET;
extern ObSSymbol* S_APPLY;
extern ObSSymbol* S_LOAD;

extern ObSConstant* B_FALSE;
extern ObSConstant* B_TRUE;

extern ObSConstant* C_NULL;

extern ObSConstant* UNSPECIFIED;



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


@protocol ObSFileLoader <NSObject>
- (ObSInPort*)findFile:(NSString*)filename;
- (NSString*)qualifyFileName:(NSString*)filename;
@end


@interface ObSBundleFileLoader : NSObject <ObSFileLoader>
@end


@interface ObSFilesystemFileLoader : NSObject <ObSFileLoader> {
  NSString* _directoryPath;
}
+ (ObSFilesystemFileLoader*)loaderForPath:(NSString*)path;
@end



@interface ObjScheme : NSObject
+ (ObSScope*)globalScope;
+ (id)parseOneToken:(ObSInPort*)inPort;
+ (id)parseString:(NSString*)string;
+ (id)read:(ObSInPort*)inPort;
+ (BOOL)isFalse:(id)token;
+ (void)loadFile:(NSString*)filename intoScope:(ObSScope*)scope;
+ (void)loadSource:(NSString*)source intoScope:(ObSScope*)scope;
+ (void)loadInPort:(ObSInPort*)port intoScope:(ObSScope*)scope forFilename:(NSString*)filename;
+ (void)addFileLoader:(id<ObSFileLoader>)loader;
+ (void)removeFileLoader:(id<ObSFileLoader>)loader;

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
  NSMutableSet* _loadedFiles;
}

@property (nonatomic,retain) ObSScope* outer;
@property (nonatomic,retain) NSMutableDictionary* environ;

+ (ObSScope*)getGlobalChildScope;

- (id)initWithOuterScope:(ObSScope*)outer;
- (id)resolveSymbol:(ObSSymbol*)variable;
- (BOOL)definesSymbol:(ObSSymbol*)symbol;
- (void)bootstrapMacros;
- (void)reportTimes;
- (id)evaluate:(id)token;
- (void)defineFunction:(id<ObSProcedure>)function;
- (void)define:(ObSSymbol*)symbol as:(id)thing;
- (void)defineMacroNamed:(ObSSymbol*)name asProcedure:(id<ObSProcedure>)procedure;
- (BOOL)hasMacroNamed:(ObSSymbol*)name;
- (id<ObSProcedure>)macroNamed:(ObSSymbol*)name;
- (ObSScope*)findScopeOf:(ObSSymbol*)name;
- (BOOL)isFilenameLoaded:(NSString*)filename;
- (void)recordFilenameLoaded:(NSString*)filename;

@end


@protocol ObSUnaryLambda <NSObject>
- (id)callNatively:(id)arg;
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
- (ObSNativeBlock)nativeBlock;

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

@interface ObSNativeUnaryLambda : NSObject <ObSProcedure,ObSUnaryLambda> {
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

+ (ObSCons*)cons:(id)a and:(id)b;
- (id)initWithCar:(id)car cdr:(id)cdr;
- (id)cadr;
- (id)caddr;
- (id)cddr;
- (id)cdddr;
- (NSArray*)toArray;
- (NSUInteger)count;
- (ObSCons*)clone;
@end



@interface ObSConstant : NSObject {
  NSString* _name;
}
@property (nonatomic,readonly) NSString* name;
- (id)initWithName:(NSString*)name;
@end




#define SY(s) [ObSSymbol symbolFromString: (s)]
#define MAP(p,a) [ObjScheme mapProcedure: (p) onArray: (a)];
