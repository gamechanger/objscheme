//
// ObSSchemeBacked.h
// GameChanger
//
// Created by Kiril Savino on Saturday, December 1, 2012
// Copyright 2012 GameChanger. All rights reserved.
//

#import "ObjScheme.h"


@interface ObSBridgedProcedure : NSObject {
  id<ObSProcedure> _proc;
  ObSNativeBlock _nativeBlock;
}
+ (ObSBridgedProcedure*)bridge:(id<ObSProcedure>)schemeProc;
- (id)initWithProcedure:(id<ObSProcedure>)schemeProc;
- (id)initWithNativeBlock:(ObSNativeBlock)nativeBlock;
- (id)invokeWithArguments:(NSArray*)arguments;
@end


@interface ObSSchemeBacked : NSObject {
  ObSScope* _scope;
}

@property (nonatomic,readonly) ObSScope* scope;

- (id)initWithScope:(ObSScope*)scope;
- (void)loadFile:(NSString*)file;
- (id)schemeObjectForKey:(NSString*)key;
- (void)setSchemeObject:(id)object forKey:(NSString*)key;
- (void)setGlobalSchemeObject:(id)object forKey:(NSString*)key;
- (id)callFunctionNamed:(NSString*)string;
- (id)callFunctionNamed:(NSString*)string withArguments:(NSArray*)arguments;
- (id)callFunctionNamed:(NSString*)string withArgument:(id)argument;

@end
