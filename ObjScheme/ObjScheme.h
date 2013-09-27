//
//  ObjScheme.h
//  ObjScheme
//
//  Created by Kiril Savino on 7/30/12.
//  Copyright (c) 2012, 2013 GameChanger. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ObSSymbol.h"
#import "ObSProcedure.h"
#import "ObSFileLoader.h"
#import "ObSScope.h"
#import "ObSInPort.h"
#import "ObSCons.h"
#import "ObSConstant.h"
#import "ObSLambda.h"

@class ObSGarbageCollector;


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
extern ObSSymbol* S_LETREC;
extern ObSSymbol* S_OPENPAREN;
extern ObSSymbol* S_CLOSEPAREN;
extern ObSSymbol* S_LIST;
extern ObSSymbol* S_EVAL;
extern ObSSymbol* S_MAP;
extern ObSSymbol* S_OPENBRACKET;
extern ObSSymbol* S_CLOSEBRACKET;
extern ObSSymbol* S_APPLY;
extern ObSSymbol* S_LOAD;
extern ObSSymbol* S_IN;
extern ObSSymbol* S_DO;
extern ObSSymbol* S_OR;
extern ObSSymbol* S_AND;
extern ObSSymbol* S_THE_ENVIRONMENT;
extern ObSSymbol* S_COND;
extern ObSSymbol* S_ELSE;

extern NSNumber* B_FALSE;
extern NSNumber* B_TRUE;

extern ObSConstant* C_NULL;

extern ObSConstant* UNSPECIFIED;


@interface ObjScheme : NSObject
- (ObSScope*)globalScope;
- (void)loadFile:(NSString*)filename;
- (void)loadFile:(NSString*)filename intoScope:(ObSScope*)scope;
- (void)loadSource:(NSString*)source intoScope:(ObSScope*)scope;
- (void)loadInPort:(ObSInPort*)port intoScope:(ObSScope*)scope forFilename:(NSString*)filename;
- (id)parseOneToken:(ObSInPort*)inPort;
- (id)parseString:(NSString*)string;
+ (id)read:(ObSInPort*)inPort;
+ (BOOL)isTrue:(id)token;
+ (BOOL)isFalse:(id)token;
+ (void)addFileLoader:(id<ObSFileLoader>)loader;
+ (void)removeFileLoader:(id<ObSFileLoader>)loader;

+ (id)map:(id<ObSProcedure>)procedure on:(id)list;
+ (NSArray*)filter:(ObSCons*)list with:(id<ObSProcedure>)procedure;
+ (ObSCons*)list:(NSArray*)array;
+ (id)boolToTruth:(BOOL)b;
+ (BOOL)isEmptyList:(id)token;
+ (id)unspecified;

@end


#define SY(s) [ObSSymbol symbolFromString: (s)]
#define MAP(p,a) [ObjScheme mapProcedure: (p) onArray: (a)];
#define B_LAMBDA(name, block) [ObSNativeBinaryLambda named: SY(name) fromBlock: (block)]
#define U_LAMBDA(name, block) [ObSNativeUnaryLambda named: SY(name) fromBlock: (block)]
#define TRUTH(b) ((b) ? B_TRUE : B_FALSE)
#define IF(x) ((x) != B_FALSE)
#define CONS(x,y) [ObSCons cons: (x) and: (y)]
#define ISINT(n) (strcmp([(n) objCType], @encode(int)) == 0)
#define ISDOUBLE(n) (strcmp([(n) objCType], @encode(double)) == 0)
#define CONST(s) [[ObSConstant alloc] initWithName: (s)]
#define CAR(x) ((x)->_car)
#define CDR(x) ((x)->_cdr)
#define CADR(x) CAR((ObSCons*)(CDR(x)))
#define CDDR(x) CDR((ObSCons*)(CDR(x)))
#define CADDR(x) CAR((ObSCons*)CDDR(x))
#define CDDDR(x) CDR((ObSCons*)CDDR(x))
#define CADDDR(x) CAR((ObSCons*)CDDDR(x))
#define EMPTY(list) ((id)(list) == C_NULL)
