//
// ObSScope.h
// GameChanger
//
// Created by Kiril Savino on Tuesday, April 16, 2013
// Copyright 2013 GameChanger. All rights reserved.
//

#import "ObSCollectible.h"

@class ObSSymbol;
@protocol ObSProcedure;
@class ObSGarbageCollector;

@interface ObSScope : ObSCollectible {
  ObSScope* _outerScope;
  NSMutableDictionary* _macros;
  NSMutableDictionary* _environ;
  NSMutableSet* _loadedFiles;
  __weak ObSGarbageCollector* _inheritedGC;
  ObSGarbageCollector* _rootGC;
  NSString* _name;
}

@property (nonatomic,retain) ObSScope* outer;
@property (nonatomic,retain) NSMutableDictionary* environ;
@property (nonatomic,retain) NSString* name;

+ (ObSScope*)newGlobalChildScopeNamed:(NSString*)name;

- (id)initWithOuterScope:(ObSScope*)outer name:(NSString*)name;
- (id)resolveSymbol:(ObSSymbol*)variable;
- (BOOL)definesSymbol:(ObSSymbol*)symbol;
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

- (ObSGarbageCollector*)garbageCollector;
- (void)gc;
- (void)ensureLocalGC;

@end
