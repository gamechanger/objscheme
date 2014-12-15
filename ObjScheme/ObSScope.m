//
// ObSScope.m
// GameChanger
//
// Created by Kiril Savino on Tuesday, April 16, 2013
// Copyright 2013 GameChanger. All rights reserved.
//


#import "ObSScope.h"
#import "ObjScheme.h"
#import "ObSSymbol.h"
#import "ObSProcedure.h"
#import "ObSCons.h"
#import "ObSLambda.h"
#import "ObSGarbageCollector.h"

@interface ObSScope ()

@property (nonatomic, retain) NSDictionary* evalMap;
@property (nonatomic, retain) NSMutableArray* stack;

@end

@implementation ObSScope {
  __weak ObSGarbageCollector* _inheritedGC;
  __weak ObjScheme* _context;
}

@synthesize outer=_outerScope, environ=_environ, context=_context, evalMap=_evalMap, stack=_stack;

BOOL _errorLogged = NO;

- (id)initWithContext:(ObjScheme*)context name:(NSString*)name {
  if ( (self = [super init]) ) {
    _name = [name retain];
    _outerScope = nil;
    _context = [context retain];
    _macros = [[NSMutableDictionary alloc] init];
    _environ = [[NSMutableDictionary alloc] init];
    _loadedFiles = [[NSMutableSet alloc] init];
    _inheritedGC = nil;
    _rootGC = [[ObSGarbageCollector alloc] initWithRoot: self];
    _stack = [[NSMutableArray alloc] init];
    [self buildEvaluationMap];
    [[self garbageCollector] startTracking: self];
  }
  return self;
}

- (id)initWithOuterScope:(ObSScope*)outer name:(NSString*)name {
  if ( (self = [super init]) ) {
    NSAssert(outer, @"outer scope is nil!");

    _name = [name retain];
    _outerScope = [outer retain];
    _context = [outer.context retain];
    _macros = _outerScope ? nil : [[NSMutableDictionary alloc] init]; // only used in root
    _environ = [[NSMutableDictionary alloc] init];
    _inheritedGC = [outer garbageCollector];
    _rootGC = nil;
    self.stack = outer.stack;
    self.evalMap = outer.evalMap;
    [[self garbageCollector] startTracking: self];
  }
  return self;
}

- (void)ensureLocalGC {
  if ( _rootGC == nil ) {
    _rootGC = [[ObSGarbageCollector alloc] initWithRoot: self];
  }
}

- (ObSGarbageCollector*)garbageCollector {
  return _rootGC ? _rootGC : _inheritedGC;
}

- (void)gc {
  [[self garbageCollector] runGarbageCollection];
}

- (oneway void)release {
  // basically, if we would otherwise be about to hit a reference count of 1
  // but we're retained by the Garbage Collector's list,
  // then we tell the GC to let us go, so we can properly hit 0 and dealloc here.
  // otherwise, we'd have to wait for the next GC cycle to go away, which is a waste.

  if ( _garbageCollector != nil && [self retainCount] == 2 ) {
    [_garbageCollector stopTracking: self];
  }

  [super release];
}

- (void)dealloc {
  [_name release];
  _name = nil;
  [_outerScope release];
  _outerScope = nil;
  [_macros release];
  _macros = nil;
  [_environ release];
  _environ = nil;
  [_loadedFiles release];
  _loadedFiles = nil;
  [_rootGC release];
  _rootGC = nil;
  [_context release];
  _context = nil;
  [_evalMap release];
  _evalMap = nil;
  [_stack release];
  _stack = nil;
  [super dealloc];
}

- (NSArray*)children {
  NSMutableArray* children = [NSMutableArray arrayWithCapacity: [_environ count] + ( _outerScope == nil ? 0 : 1 )];
  for ( id value in [_environ allValues] ) {
    if ( [value isKindOfClass: [ObSCollectible class]] ) {
      [children addObject: value];
    }
  }

  if ( _outerScope != nil ) {
    [children addObject: _outerScope];
  }

  return children;
}

/*
 * Used in GarbageCollection.
 */
- (void)releaseChildren {
  [_environ removeAllObjects];
}

- (NSString*)description {
  return [NSString stringWithFormat: @"ObSScope %p %@ : %@", self, _name, _environ];
}

- (BOOL)isFilenameLoaded:(NSString*)filename {
  if ( _loadedFiles && [_loadedFiles containsObject: filename] )
    return YES;
  return _outerScope == nil ? NO : [_outerScope isFilenameLoaded: filename];
}

- (void)recordFilenameLoaded:(NSString*)filename {
  if ( ! _loadedFiles ) {
    _loadedFiles = [[NSMutableSet alloc] init];
  }
  [_loadedFiles addObject: filename];
}

- (ObSScope*)findScopeOf:(ObSSymbol*)name {
  if ( [_environ objectForKey: name->_string] != nil ) {
    return self;
  }

  if ( _outerScope != nil ) {
    return [_outerScope findScopeOf: name];
  }

  [NSException raise: @"LookupError" format: @"Couldn't find defining scope of %@", name];
  return nil;
}

- (id)resolveSymbol:(ObSSymbol*)symbol {
  id myValue = [_environ objectForKey: symbol->_string];
  if ( myValue ) {
    return myValue;
  }

  if ( _outerScope != nil ) {
    return [_outerScope resolveSymbol: symbol];
  }

  [NSException raise: @"LookupError" format: @"Symbol %@ not found in any scope", symbol];
  return nil;
}

- (BOOL)definesSymbol:(ObSSymbol*)symbol {
  return [_environ objectForKey: symbol->_string] != nil;
}

- (void)define:(ObSSymbol*)symbol as:(id)thing {
  NSString* key = symbol->_string;
  [_environ setObject: thing forKey: key];
}

- (void)defineFunction:(id<ObSProcedure>)procedure {
  [self define: [procedure name] as: procedure];
}

- (id)evaluateList:(id)arg {
  if ( arg == C_NULL ) {
    return C_NULL;

  } else {
    ObSCons* list = arg;
    return CONS([self evaluate: CAR(list) named: nil], [self evaluateList: CDR(list)]);
  }
}

- (id)begin:(ObSCons*)expressions {
  id ret = nil;
  for ( id expression in expressions ) {
    ret = [self evaluate: expression named: nil];
  }
  NSAssert(ret, @"Empty begin statement");
  return ret;
}

- (void)pushStack:(id)token {
  [_stack addObject: token];
}

- (void)popStack {
  [_stack removeLastObject];
}

static NSMutableDictionary* __times = nil;

- (void)recordTimeForFunction:(NSString*)fname time:(NSTimeInterval)time {
  if ( __times == nil ) {
    __times = [NSMutableDictionary new];
  }

  if ( [__times objectForKey: fname] == nil ) {
    [__times setObject: @(time) forKey: fname];

  } else {
    [__times setObject: @(time + [[__times objectForKey: fname] floatValue]) forKey: fname];
  }
}

- (void)reportTimes {
  if ( __times == nil ) {
    __times = [NSMutableDictionary new];
  }
  for ( id key in __times ) {
    float time = [[__times objectForKey: key] floatValue];
    if ( time > 0.01f ) {
      NSLog( @"F: %@ -> %.2f", key, time );
    }
  }
}

typedef id (^ObSInternalFunction)(ObSScope* scope, ObSSymbol* name, ObSCons* args, BOOL* popStackWhenDone, BOOL* done);

+ (void)initialize {
  [ObjScheme initialize]; // FML, need to make sure constants are initialized...
}

- (void)buildEvaluationMap {
  NSMutableDictionary* evalMap = [[NSMutableDictionary alloc] initWithCapacity: 30];
  self.evalMap = evalMap;
  evalMap[S_EVAL.string] = Block_copy(^(ObSScope* scope, ObSSymbol* name, ObSCons* args, BOOL* popStackWhenDone, BOOL* done) {
      [scope pushStack: S_EVAL];
      *popStackWhenDone = YES;
      *done = NO;
      id newCode = [scope evaluate: CAR(args) named: nil];
      return newCode;
    });

  evalMap[S_OR.string] = Block_copy(^(ObSScope* scope, ObSSymbol* name, ObSCons* args, BOOL* popStackWhenDone, BOOL* done) {
      *done = YES;

      id operands = args;
      id result = B_FALSE;
      while ( operands != C_NULL ) {
        ObSCons* lst = operands;
        result = [scope evaluate: CAR(lst) named: nil];
        if ( result != B_FALSE ) {
          return result;
        }
        operands = CDR(lst);
      }
      return result;
    });

  evalMap[S_AND.string] = Block_copy(^(ObSScope* scope, ObSSymbol* name, ObSCons* args, BOOL* popStackWhenDone, BOOL* done) {
      *done = YES;

      id operands = args;
      id result = B_FALSE;
      while ( operands != C_NULL ) {
        ObSCons* lst = operands;
        result = [scope evaluate: CAR(lst) named: nil];
        if ( result == B_FALSE ) {
          return result;
        }
        operands = CDR(lst);
      }
      return result;
    });

  evalMap[S_COND.string] = Block_copy(^(ObSScope* scope, ObSSymbol* name, ObSCons* args, BOOL* popStackWhenDone, BOOL* done) {
      *done = YES;

      ObSCons* listOfTuples = args;
      id ret = UNSPECIFIED;

      for ( ObSCons* conditionAndResult in listOfTuples ) {
        id left = CAR(conditionAndResult);
        if ( left == S_ELSE ) {
          *done = NO;
          ret = CADR(conditionAndResult);
          break;

        } else {
          id condition = [scope evaluate: left named: nil];
          if ( condition != B_FALSE ) {
            if ( CDR(conditionAndResult) == C_NULL ) {
              *done = YES;
              ret = B_TRUE;
              break;

            } else {
              *done = NO;
              ret = CADR(conditionAndResult);
              break;
            }
          }
        }
      }

      return ret;
    });

  evalMap[S_LET.string] = Block_copy(^(ObSScope* scope, ObSSymbol* name, ObSCons* args, BOOL* popStackWhenDone, BOOL* done) {
      *done = YES;
      // normal: (let ((x y)) body)
      // named: (let name ((x y)) body)

      id ret;

      if ( [CAR(args) isKindOfClass: [ObSSymbol class]] ) { // named let

        ObSSymbol* letName = CAR(args);
        ObSCons* definitions = CADR(args);
        ObSCons* body = CDDR(args);
        ObSScope* letScope = [[ObSScope alloc] initWithOuterScope: scope
                                                             name: [NSString stringWithFormat: @"named-let %@", letName]];

        NSMutableArray* argList = [[NSMutableArray alloc] initWithCapacity: 4];

        for ( ObSCons* definition in definitions ) {
          ObSSymbol* name = CAR(definition);
          id expression = CADR(definition);
          [letScope define: name as: [scope evaluate: expression named: nil]];
          [argList addObject: name];
        }

        ObSCons* parameters = [ObjScheme list: argList];
        [argList release];

        ObSCons* expression = CONS(S_BEGIN, body);
        ObSLambda* lambda = [[ObSLambda alloc] initWithParameters: parameters
                                                       expression: expression
                                                            scope: letScope
                                                             name: letName];

        [letScope define: letName as: lambda];
        [lambda release];

        ret = [letScope begin: body];
        [letScope release];

      } else { // normal let

        ObSCons* definitions = CAR(args);
        ObSCons* body = CDR(args);
        ObSScope* letScope = [[ObSScope alloc] initWithOuterScope: scope
                                                             name: @"let"];

        for ( ObSCons* definition in definitions ) {
          ObSSymbol* name = CAR(definition);
          id expression = CADR(definition);
          [letScope define: name as: [scope evaluate: expression named: nil]];
        }

        ret = [letScope begin: body];
        [letScope release];
      }

      return ret;
    });

  ObSInternalFunction recursiveLet = ^(ObSScope* scope, ObSSymbol* name, ObSCons* args, BOOL* popStackWhenDone, BOOL* done) {

    ObSCons* definitions = CAR(args);
    ObSCons* body = CDR(args);
    ObSScope* letScope = [[ObSScope alloc] initWithOuterScope: scope
                                                         name: @"let*"];

    for ( ObSCons* definition in definitions ) {
      ObSSymbol* symbol = CAR(definition);
      id expression = CADR(definition);
      [letScope define: symbol as: [letScope evaluate: expression named: nil]];
    }

    id ret = [letScope begin: body];
    [letScope release];
    return ret;
  };

  // one or more of the following is technically wrong...
  evalMap[S_LET_STAR.string] = Block_copy(recursiveLet);
  evalMap[S_LETREC.string] = Block_copy(recursiveLet);

  evalMap[S_DO.string] = Block_copy(^(ObSScope* scope, ObSSymbol* name, ObSCons* args, BOOL* popStackWhenDone, BOOL* done) {
      *done = YES;
      id ret;

      ObSCons* variables = CAR(args);
      ObSCons* exit = CADR(args);
      ObSCons* loopBody = CDDR(args);
      ObSScope* doScope = [[ObSScope alloc] initWithOuterScope: scope
                                                          name: @"do"];

      NSMutableDictionary* varToStep = [[NSMutableDictionary alloc] initWithCapacity: 4];

      for ( ObSCons* variable in variables ) {
        ObSSymbol* name = CAR(variable);
        id value = CADR(variable);
        id step = CDDR(variable) != C_NULL ? CADDR(variable) : nil;
        if ( step ) {
          varToStep[name.string] = step;
        }
        [doScope define: name as: [scope evaluate: value named: nil]];
      }

      id exit_condition = CAR(exit);
      ObSCons* exitBody = CDR(exit);

      BOOL haveSteps = [varToStep count] > 0;

      while ( 1 ) {
        id testValue = [doScope evaluate: exit_condition named: nil];
        if ( testValue != B_FALSE ) {
          ret = B_FALSE;
          id body = exitBody;

          while ( body != C_NULL ) {
            ObSCons* realBody = body;
            ret = [doScope evaluate: CAR(realBody) named: nil];
            body = CDR(realBody);
          }

          break;
        }

        id body = loopBody;
        while ( body != C_NULL ) {
          ObSCons* realBody = body;
          [doScope evaluate: CAR(realBody) named: nil];
          body = CDR(realBody);
        }

        if ( haveSteps ) {
          NSMutableDictionary* changes = [[NSMutableDictionary alloc] init];

          for ( NSString* var in varToStep ) {
            changes[var] = [doScope evaluate: varToStep[var] named: nil];
          }

          if ( [changes count] ) {
            [doScope.environ addEntriesFromDictionary: changes];
          }

          [changes release];
        }
      }

      [varToStep release];
      [doScope release];

      return ret;
    });

  evalMap[S_QUOTE.string] = Block_copy(^(ObSScope* scope, ObSSymbol* name, ObSCons* args, BOOL* popStackWhenDone, BOOL* done) {
      *done = YES;
      NSAssert1(CDR(args) == C_NULL, @"quote can have only 1 operand, not %@", args);
      return CAR(args);
    });

  evalMap[S_LIST.string] = Block_copy(^(ObSScope* scope, ObSSymbol* name, ObSCons* args, BOOL* popStackWhenDone, BOOL* done) {
      *done = YES;
      [scope pushStack: S_LIST];
      id ret = [[scope evaluateList: args] retain];
      [scope popStack];
      return ret;
    });

  evalMap[S_IF.string] = Block_copy(^(ObSScope* scope, ObSSymbol* name, ObSCons* args, BOOL* popStackWhenDone, BOOL* done) {
      *done = NO;

      if ( [scope evaluate: CAR(args) named: nil] != B_FALSE ) {
        return CADR(args);

      } else {
        return CDDR(args) != C_NULL ? CADDR(args) : UNSPECIFIED;
      }
    });

  evalMap[S_IN.string] = Block_copy(^(ObSScope* scope, ObSSymbol* name, ObSCons* args, BOOL* popStackWhenDone, BOOL* done) {
      *done = YES;

      id ret;
      id toFind = [scope evaluate: CAR(args) named: nil];
      id list = [scope evaluate: CADR(args) named: nil];
      if ( [list isKindOfClass: [NSArray class]] ) {
        NSArray* a = list;
        ret = [a containsObject: toFind] ? B_TRUE : B_FALSE;

      } else if ( list == C_NULL ) {
        ret = B_FALSE;

      } else {
        ObSCons* cons = list;
        ret = B_FALSE;
        for ( id ob in cons ) {
          if ( [ob isEqual: toFind] ) {
            ret = B_TRUE;
            break;
          }
        }
      }

      return ret;
    });

  evalMap[S_APPLY.string] = Block_copy(^(ObSScope* scope, ObSSymbol* name, ObSCons* args, BOOL* popStackWhenDone, BOOL* done) {
      *done = YES;
      id function_name = CAR(args);
      id function_args = CADR(args);
      id fargs = [scope evaluate: function_args named: nil];
      id proc = [scope evaluate: function_name named: nil];
      [scope pushStack: function_name];
      id ret = [proc callWith: fargs];
      [scope popStack];
      return ret;
    });

  evalMap[S_SET.string] = Block_copy(^(ObSScope* scope, ObSSymbol* name, ObSCons* args, BOOL* popStackWhenDone, BOOL* done) {
      *done = YES;
      [scope pushStack: S_SET];
      ObSSymbol* symbol = CAR(args);
      id expression = CADR(args);
      ObSScope* definingScope = [scope findScopeOf: symbol]; // I do this first, which can fail, so we don't bother executing predicate
      [definingScope define: symbol as: [scope evaluate: expression named: nil]];
      [scope popStack];
      return UNSPECIFIED;
    });

  evalMap[S_DEFINE.string] = Block_copy(^(ObSScope* scope, ObSSymbol* name, ObSCons* args, BOOL* popStackWhenDone, BOOL* done) {
      *done = YES;
      [scope pushStack: S_DEFINE];
      ObSSymbol* variableName = CAR(args);
      id expression = CADR(args);
      [scope define: variableName as: [scope evaluate: expression named: variableName]];
      [scope popStack];
      return UNSPECIFIED;
    });

  evalMap[S_LAMBDA.string] = Block_copy(^(ObSScope* scope, ObSSymbol* name, ObSCons* args, BOOL* popStackWhenDone, BOOL* done) {
      *done = YES;

      [scope pushStack: S_LAMBDA];
      ObSCons* parameters = CAR(args);
      ObSCons* body = CADR(args);
      id lambda = [[[ObSLambda alloc] initWithParameters: parameters
                                              expression: body
                                                   scope: scope
                                                    name: name ? name : S_LAMBDA] autorelease];
      [scope popStack];
      return lambda;
    });

  evalMap[S_BEGIN.string] = Block_copy(^(ObSScope* scope, ObSSymbol* name, ObSCons* args, BOOL* popStackWhenDone, BOOL* done) {
      *done = YES;

      if ( (id)args == C_NULL ) {
        return (id)UNSPECIFIED;

      } else {
        id ret = B_FALSE;
        for ( id expression in args ) {
          ret = [scope evaluate: expression named: nil];
        }
        return ret;
      }
    });

  evalMap[S_LOAD.string] = Block_copy(^(ObSScope* scope, ObSSymbol* name, ObSCons* args, BOOL* popStackWhenDone, BOOL* done) {
      NSString* filename = [scope evaluate: CAR(args) named: nil];
      if ( (id)CDR(args) != C_NULL ) {
        scope = [scope evaluate: CADR(args) named: nil];
      }
      [_context loadFile: filename intoScope: scope];
      return UNSPECIFIED;
    });

  evalMap[S_THE_ENVIRONMENT.string] = Block_copy(^(ObSScope* scope, ObSSymbol* name, ObSCons* args, BOOL* popStackWhenDone, BOOL* done) {
      return scope;
    });
  [evalMap release];
}

- (id)evaluate:(id)token {
  return [self evaluate: token named: nil];
}

- (id)evaluate:(id)token named:(ObSSymbol*)name {
  NSAssert(token != nil, @"nil token");

  @try {
    BOOL popStack = NO;

    while ( 1 ) {
      if ( popStack ) {
        [self popStack];
        popStack = NO;
      }

      if ( [token isKindOfClass: [ObSSymbol class]] ) {
        return [self resolveSymbol: token]; // variable reference

      } else if ( ! [token isKindOfClass: [ObSCons class]] ) {
        return token; // literal

      } else {
        ObSCons* list = token;
        id head = CAR(list);
        ObSCons* rest = CDR(list);

        if ( [head isKindOfClass: [ObSSymbol class]] ) {
          BOOL done = YES;
          ObSSymbol* symbol = head;
          ObSInternalFunction f = _evalMap[symbol->_string];

          if ( f != nil ) {
            id result = f(self, name, rest, &popStack, &done);
            if ( done ) {
              return result;

            } else {
              name = nil;
              token = result;
              continue;
            }
          }
        }

        id<ObSProcedure> procedure = [self evaluate: head named: name];
        ObSCons* args = [self evaluateList: rest];
        [self pushStack: head];
        //NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
        id ret = [procedure callWith: args];
        //NSString* functionName = [head isKindOfClass: [ObSSymbol class]] ? ((ObSSymbol*)head)->_string : name ? name->_string : @"?";
        //[self recordTimeForFunction: functionName time: [NSDate timeIntervalSinceReferenceDate] - start];
        [self popStack];
        return ret;
      }
    }

  } @catch ( NSException* e ) {
    if ( ! _errorLogged ) {
      _errorLogged = YES;
      NSLog( @"Error %@", e );
      NSLog( @"Evaluating %@", token );
      for ( NSInteger i = [_stack count] - 1; i >= 0; i-- ) {
        NSLog( @" @ %@", [_stack objectAtIndex: i] );
      }
      [_stack removeAllObjects];
    }

    [e raise];
  }
}

- (void)defineMacroNamed:(ObSSymbol*)name asProcedure:(id<ObSProcedure>)procedure {
  if ( _macros ) {
    [_macros setObject: procedure forKey: name.string];
  }
}

- (BOOL)hasMacroNamed:(ObSSymbol*)name {
  return _macros && [_macros objectForKey: name.string] != nil;
}

- (id<ObSProcedure>)macroNamed:(ObSSymbol*)name {
  return _macros ?  [_macros objectForKey: name.string] : nil;
}

@end
