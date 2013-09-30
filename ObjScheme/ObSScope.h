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
@class ObjScheme;

@interface ObSScope : ObSCollectible {
  ObSScope* _outerScope;
  NSMutableDictionary* _macros;
  NSMutableDictionary* _environ;
  NSMutableSet* _loadedFiles;
  ObSGarbageCollector* _rootGC;
  NSString* _name;
}

@property (nonatomic,retain) ObSScope* outer;
@property (nonatomic,retain) ObjScheme* context;
@property (nonatomic,retain) NSMutableDictionary* environ;
@property (nonatomic,retain) NSString* name;

- (id)initWithContext:(ObjScheme*)context name:(NSString*)name;
- (id)initWithOuterScope:(ObSScope*)outer name:(NSString*)name;
- (id)resolveSymbol:(ObSSymbol*)variable;
- (BOOL)definesSymbol:(ObSSymbol*)symbol;
- (void)reportTimes;
- (id)evaluate:(id)token;
- (id)evaluate:(id)token named:(ObSSymbol*)name;
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
