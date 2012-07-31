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
+ (id)parseFromInPort:(ObSInPort*)inPort;
+ (id)parseString:(NSString*)string;
+ (id)loadFromInPort:(ObSInPort*)inPort;
@end


@interface ObSSymbol : NSString
+ (ObSSymbol*)symbolFromString:(NSString*)string;
@end


@class ObSProcedure;

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
- (id)evaluateList:(NSArray*)list;
- (void)defineMacroNamed:(NSString*)name asProcedure:(ObSProcedure*)procedure;
- (BOOL)hasMacroNamed:(NSString*)name;
- (ObSProcedure*)macroNamed:(NSString*)name;

@end



@interface ObSProcedure : NSObject
- (id)initWithParameterList:(NSArray*)parameters
             expressionName:(NSString*)expressionName
                    environ:(ObSScope*)environ;
- (id)invokeWithArguments:(NSArray*)args;
@end



@interface ObSInPort : NSObject {
  NSData* _data;
}
- (id)initWithData:(NSData*)data;
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




typedef id (^ObSProcedureBlock)(NSArray*);
