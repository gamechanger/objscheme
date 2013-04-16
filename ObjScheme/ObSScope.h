//
// ObSScope.h
// GameChanger
//
// Created by Kiril Savino on Tuesday, April 16, 2013
// Copyright 2013 GameChanger. All rights reserved.
//

@class ObSSymbol;
@protocol ObSProcedure;

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
