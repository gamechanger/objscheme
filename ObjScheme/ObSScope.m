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


@implementation ObSScope

@synthesize outer=_outerScope, environ=_environ;

static NSMutableArray* _stack;
BOOL _errorLogged = NO;

+ (void)initialize {
  _stack = [[NSMutableArray alloc] init];
}

+ (ObSScope*)newGlobalChildScopeNamed:(NSString*)name {
  return [[ObSScope alloc] initWithOuterScope: [ObjScheme globalScope] name: name];
}

- (id)initWithOuterScope:(ObSScope*)outer name:(NSString*)name {
  if ( (self = [super init]) ) {
    _name = [name retain];
    _outerScope = [outer retain];
    _macros = [[NSMutableDictionary alloc] init];
    _environ = [[NSMutableDictionary alloc] init];
    _loadedFiles = [[NSMutableSet alloc] init];
    _inheritedGC = outer ? [outer garbageCollector] : nil;
    _rootGC = _inheritedGC ? nil : [[ObSGarbageCollector alloc] initWithRoot: self];
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
  [super dealloc];
}

- (NSArray*)children {
  NSMutableArray* children = [NSMutableArray arrayWithCapacity: [_environ count]];
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

- (void)releaseChildren {
  [_environ removeAllObjects];
}

- (NSString*)description {
  return [NSString stringWithFormat: @"ObSScope %p %@ : %@", self, _name, _environ];
}

- (BOOL)isFilenameLoaded:(NSString*)filename {
  if ( [_loadedFiles containsObject: filename] )
    return YES;
  return _outerScope == nil ? NO : [_outerScope isFilenameLoaded: filename];
}

- (void)recordFilenameLoaded:(NSString*)filename {
  [_loadedFiles addObject: filename];
}

- (ObSScope*)findScopeOf:(ObSSymbol*)name {
  if ( [_environ objectForKey: name.string] != nil ) {
    return self;
  }

  if ( _outerScope != nil ) {
    return [_outerScope findScopeOf: name];
  }

  [NSException raise: @"LookupError" format: @"Couldn't find defining scope of %@", name];
  return nil;
}

- (id)resolveSymbol:(ObSSymbol*)symbol {
  id myValue = [_environ objectForKey: symbol.string];
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
  return [_environ objectForKey: symbol.string] != nil;
}

- (void)define:(ObSSymbol*)symbol as:(id)thing {
  NSString* key = symbol.string;
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
    return CONS([self evaluate: [list car]], [self evaluateList: [list cdr]]);
  }
}

- (id)begin:(ObSCons*)expressions {
  NSAssert( [expressions isKindOfClass: [ObSCons class]], @"invalid begin block %@", expressions);

  id ret = nil;
  for ( id expression in expressions ) {
    ret = [self evaluate: expression];
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

- (id)evaluate:(id)token {
  return [self evaluate: token named: nil];
}

- (id)evaluate:(id)token named:(ObSSymbol*)name {
  NSAssert(token != nil, @"nil token");

  @try {
    id ret;

    while ( 1 ) {
      if ( [token isKindOfClass: [ObSSymbol class]] ) {
        ret = [self resolveSymbol: token]; // variable reference
        break;

      } else if ( ! [token isKindOfClass: [ObSCons class]] ) {
        ret = token; // literal
        break;

      } else {
        ObSCons* list = token;
        id head = [list car];
        ObSCons* rest = [list cdr];
        NSUInteger argCount = (id)rest == C_NULL ? 0 : [rest count];

        if ( head == S_EVAL ) {
          NSAssert1(argCount == 1, @"eval can have only 1 operand, not %@", rest);
          [self pushStack: S_EVAL];
          token = [self evaluate: [rest car]];
          [self popStack];

        } else if ( head == S_OR ) {

          id operands = rest;
          while ( operands != C_NULL ) {
            ObSCons* lst = operands;
            id aResult = [self evaluate: [lst car]];
            if ( aResult != B_FALSE ) {
              return aResult;
            }
            operands = [lst cdr];
          }
          return B_FALSE;

        } else if ( head == S_AND ) {
          id operands = rest;
          id thing = B_FALSE;
          while ( operands != C_NULL ) {
            ObSCons* lst = operands;
            thing = [self evaluate: [lst car]];
            if ( thing == B_FALSE ) {
              return B_FALSE;
            }
            operands = [lst cdr];
          }
          return thing;

        } else if ( head == S_COND ) {
          ObSCons* listOfTuples = rest;
          BOOL continueEvaluation = NO;
          for ( ObSCons* conditionAndResult in listOfTuples ) {
            id condition = [self evaluate: [conditionAndResult car]];
            if ( condition == S_ELSE ) {
              token = [conditionAndResult cadr];
              continueEvaluation = YES;
              break;

            } else {
              if ( condition == B_TRUE ) {
                if ( [conditionAndResult cdr] == C_NULL ) {
                  return B_TRUE;

                } else {
                  continueEvaluation = YES;
                  token = [conditionAndResult cadr];
                  continue;
                }
              }
            }
          }

          if ( continueEvaluation ) {
            continue;
          } else {
            return UNSPECIFIED;
          }


        } else if ( head == S_LET ) {
          // normal: (let ((x y)) body)
          // named: (let name ((x y)) body)

          if ( [[rest car] isKindOfClass: [ObSSymbol class]] ) { // named let

            ObSSymbol* letName = [rest car];
            ObSCons* definitions = [rest cadr];
            ObSCons* body = [rest cddr];
            ObSScope* letScope = [[ObSScope alloc] initWithOuterScope: self
                                                                 name: [NSString stringWithFormat: @"named-let %@", letName]];

            NSMutableArray* argList = [[NSMutableArray alloc] initWithCapacity: 4];

            for ( ObSCons* definition in definitions ) {
              ObSSymbol* name = [definition car];
              id expression = [definition cadr];
              [letScope define: name as: [self evaluate: expression]];
              [argList addObject: name];
            }

            ObSCons* parameters = [ObjScheme list: argList];
            [argList release];

            ObSCons* expression = [ObSCons cons: S_BEGIN and: body];
            ObSLambda* lambda = [[ObSLambda alloc] initWithParameters: parameters
                                                           expression: expression
                                                                scope: letScope
                                                                 name: letName];

            [letScope define: letName as: lambda];
            [lambda release];

            ret = [letScope begin: body];
            [letScope release];

          } else { // normal let

            ObSCons* definitions = [rest car];
            ObSCons* body = [rest cdr];
            ObSScope* letScope = [[ObSScope alloc] initWithOuterScope: self
                                                                 name: @"let"];

            for ( ObSCons* definition in definitions ) {
              ObSSymbol* name = [definition car];
              id expression = [definition cadr];
              [letScope define: name as: [self evaluate: expression]];
            }

            ret = [letScope begin: body];
            [letScope release];
          }

          break;

        } else if ( head == S_LET_STAR ) {
          ObSCons* definitions = [rest car];
          ObSCons* body = [rest cdr];
          ObSScope* letScope = [[ObSScope alloc] initWithOuterScope: self
                                                               name: @"let*"];

          for ( ObSCons* definition in definitions ) {
            ObSSymbol* name = [definition car];
            id expression = [definition cadr];
            [letScope define: name as: [letScope evaluate: expression]];
          }

          ret = [letScope begin: body];
          [letScope release];
          break;

        } else if ( head == S_DO ) {
          ObSCons* variables = [rest car];
          ObSCons* exit = [rest cadr];
          ObSCons* loopBody = [rest cddr];
          ObSScope* doScope = [[ObSScope alloc] initWithOuterScope: self
                                                              name: @"do"];

          NSMutableDictionary* varToStep = [[NSMutableDictionary alloc] initWithCapacity: 4];

          for ( ObSCons* variable in variables ) {
            ObSSymbol* name = [variable car];
            id value = [variable cadr];
            id step = [variable cddr] != C_NULL ? [variable caddr] : nil;
            if ( step ) {
              varToStep[name.string] = step;
            }
            [doScope define: name as: [self evaluate: value]];
          }

          id exit_condition = [exit car];
          ObSCons* exitBody = [exit cdr];

          BOOL haveSteps = [varToStep count] > 0;

          while ( 1 ) {
            id testValue = [doScope evaluate: exit_condition];
            if ( testValue != B_FALSE ) {
              ret = B_FALSE;
              id body = exitBody;

              while ( body != C_NULL ) {
                ObSCons* realBody = body;
                ret = [doScope evaluate: [realBody car]];
                body = [realBody cdr];
              }

              break;
            }

            id body = loopBody;
            while ( body != C_NULL ) {
              ObSCons* realBody = body;
              [doScope evaluate: [body car]];
              body = [realBody cdr];
            }

            if ( haveSteps ) {
              NSMutableDictionary* changes = [[NSMutableDictionary alloc] init];

              for ( NSString* var in varToStep ) {
                changes[var] = [doScope evaluate: varToStep[var]];
              }

              if ( [changes count] ) {
                [doScope.environ addEntriesFromDictionary: changes];
              }

              [changes release];
            }
          }

          [varToStep release];
          [doScope release];
          break;

        } else if ( head == S_QUOTE ) { // (quote exp) -> exp
          NSAssert1(argCount == 1, @"quote can have only 1 operand, not %@", rest);
          ret = [rest car];
          break;

        } else if ( head == S_LIST ) { // (list a b c)
          [self pushStack: S_LIST];
          ret = [self evaluateList: rest];
          [self popStack];
          break;

        } else if ( head == S_IF ) { // (if test consequence alternate) <- note that full form is enforced by expansion
          id test = [rest car];
          id consequence = [rest cadr];
          id alternate = argCount == 3 ? [rest caddr] : UNSPECIFIED;
          token = [self evaluate: test] == B_FALSE ? alternate : consequence;
          continue; // I'm being explicit here for clarity, we'll now evaluate this token

        } else if ( head == S_IN ) { // (in ob lst)
          id toFind = [self evaluate: [rest car]];
          id list = [self evaluate: [rest cadr]];
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

          break;

        } else if ( head == S_APPLY ) {
          id function_name = [rest car];
          id function_args = [rest cadr];
          id args = [self evaluate: function_args];
          id proc = [self evaluate: function_name];
          [self pushStack: function_name];
          ret = [proc callWith: args];
          [self popStack];
          break;

        } else if ( head == S_SET ) { // (set! variableName expression)
          [self pushStack: S_SET];

          ObSSymbol* symbol = [rest car];
          id expression = [rest cadr];
          ObSScope* definingScope = [self findScopeOf: symbol]; // I do this first, which can fail, so we don't bother executing predicate
          [definingScope define: symbol as: [self evaluate: expression]];
          [self popStack];
          ret = UNSPECIFIED;
          break;

        } else if ( head == S_DEFINE ) { // (define variableName expression)
          [self pushStack: S_DEFINE];
          ObSSymbol* variableName = [rest car];
          id expression = [rest cadr];
          [self define: variableName as: [self evaluate: expression named: variableName]];
          [self popStack];
          ret = UNSPECIFIED;
          break;

        } else if ( head == S_LAMBDA ) { // (lambda (argumentNames) body)
          [self pushStack: S_LAMBDA];

          ObSCons* parameters = [rest car];
          ObSCons* body = [rest cadr];
          ret = [[[ObSLambda alloc] initWithParameters: parameters
                                            expression: body
                                                 scope: self
                                                  name: name ? name : S_LAMBDA] autorelease];
          [self popStack];
          break;

        } else if ( head == S_BEGIN ) { // (begin expression...)
          ret = [NSNumber numberWithBool: NO];
          if ( (id)rest == C_NULL ) {
            ret = UNSPECIFIED;

          } else {
            for ( id expression in rest ) {
              ret = [self evaluate: expression];
            }
          }

          break; // begin evaluates to value of final expression

        } else if ( head == S_LOAD ) { // (load <filename> [environment])
          NSString* filename = [self evaluate: [rest car]];
          ObSScope* scope = self;
          if ( (id)[rest cdr] != C_NULL ) {
            scope = [self evaluate: [rest cadr]];
          }
          [ObjScheme loadFile: filename intoScope: scope];
          ret = UNSPECIFIED;
          break;

        } else if ( head == S_THE_ENVIRONMENT ) {
          return self;

        } else { // (<procname> args...)
          ObSSymbol* functionName = head;
          id<ObSProcedure> procedure = [self evaluate: functionName];
          ObSCons* args = [self evaluateList: rest];
          [self pushStack: head];
          //NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
          ret = [procedure callWith: args];
          //[self recordTimeForFunction: functionName.string time: [NSDate timeIntervalSinceReferenceDate] - start];
          [self popStack];
          break;
        }
      }
    }

    return ret;

  } @catch ( NSException* e ) {
    if ( ! _errorLogged ) {
      _errorLogged = YES;
      NSLog( @"Error %@", e );
      NSLog( @"Evaluating %@", token );
      for ( int i = [_stack count]-1; i >= 0; i-- ) {
        NSLog( @" @ %@", [_stack objectAtIndex: i] );
      }
      [_stack removeAllObjects];
    }

    [e raise];
  }
}

- (void)defineMacroNamed:(ObSSymbol*)name asProcedure:(id<ObSProcedure>)procedure {
  [_macros setObject: procedure forKey: name.string];
}

- (BOOL)hasMacroNamed:(ObSSymbol*)name {
  return [_macros objectForKey: name.string] != nil;
}

- (id<ObSProcedure>)macroNamed:(ObSSymbol*)name {
  return [_macros objectForKey: name.string];
}

@end
