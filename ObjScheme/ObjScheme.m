//
//  ObjScheme.m
//  ObjScheme
//
//  Created by Kiril Savino on 7/30/12.
//  Copyright (c) 2012, 2013 GameChanger. All rights reserved.
//

#import "ObjScheme.h"
#import "ObSNS.h"
#import "ObSStrings.h"
#import "ObSGarbageCollector.h"

ObSSymbol* S_DOT;
ObSSymbol* S_QUOTE;
ObSSymbol* S_IF;
ObSSymbol* S_SET;
ObSSymbol* S_DEFINE;
ObSSymbol* S_LAMBDA;
ObSSymbol* S_BEGIN;
ObSSymbol* S_DEFINEMACRO;
ObSSymbol* S_QUASIQUOTE;
ObSSymbol* S_UNQUOTE;
ObSSymbol* S_UNQUOTESPLICING;
ObSSymbol* S_APPEND;
ObSSymbol* S_CONS;
ObSSymbol* S_LET;
ObSSymbol* S_LET_STAR;
ObSSymbol* S_LETREC;
ObSSymbol* S_OPENPAREN;
ObSSymbol* S_CLOSEPAREN;
ObSSymbol* S_LIST;
ObSSymbol* S_EVAL;
ObSSymbol* S_MAP;
ObSSymbol* S_OPENBRACKET;
ObSSymbol* S_CLOSEBRACKET;
ObSSymbol* S_APPLY;
ObSSymbol* S_LOAD;
ObSSymbol* S_IN;
ObSSymbol* S_DO;
ObSSymbol* S_OR;
ObSSymbol* S_AND;
ObSSymbol* S_THE_ENVIRONMENT;
ObSSymbol* S_COND;
ObSSymbol* S_ELSE;

ObSConstant* B_FALSE;
ObSConstant* B_TRUE;

ObSConstant* C_NULL;

ObSConstant* UNSPECIFIED;

@interface ObjScheme ()

+ (id)atomFromToken:(NSString*)token;
+ (NSString*)unpackStringLiteral:(NSString*)string;
+ (id)expandToken:(id)token;
+ (id)expandToken:(id)token atTopLevel:(BOOL)topLevel;
+ (void)assertSyntax:(BOOL)correct elseRaise:(NSString*)message;
+ (id)expandQuasiquote:(id)token;
+ (void)addGlobalsToScope:(ObSScope*)scope;

@end




// ------ ObjScheme top-level

@implementation ObjScheme

static NSDictionary* __constants = nil;
static ObSScope* __globalScope = nil;
static NSMutableArray* __loaders = nil;

+ (void)initializeSymbols {
  S_DOT =             SY(@".");
  S_QUOTE =           SY(@"quote");
  S_IF =              SY(@"if");
  S_SET =             SY(@"set!");
  S_DEFINE =          SY(@"define");
  S_LAMBDA =          SY(@"lambda");
  S_BEGIN =           SY(@"begin");
  S_DEFINEMACRO =     SY(@"define-macro");
  S_QUASIQUOTE =      SY(@"quasiquote");
  S_UNQUOTE =         SY(@"unquote");
  S_UNQUOTESPLICING = SY(@"unquote-splicing");
  S_APPEND =          SY(@"append");
  S_CONS =            SY(@"cons");
  S_LET =             SY(@"let");
  S_LET_STAR =        SY(@"let*");
  S_LETREC =          SY(@"letrec");
  S_OPENPAREN =       SY(@"(");
  S_CLOSEPAREN =      SY(@")");
  S_OPENBRACKET =     SY(@"[");
  S_CLOSEBRACKET =    SY(@"]");
  S_LIST =            SY(@"list");
  S_EVAL =            SY(@"eval");
  S_MAP =             SY(@"map");
  S_APPLY =           SY(@"apply");
  S_LOAD =            SY(@"load");
  S_IN =              SY(@"in");
  S_DO =              SY(@"do");
  S_OR =              SY(@"or");
  S_AND =             SY(@"and");
  S_THE_ENVIRONMENT = SY(@"the-environment");
  S_COND =            SY(@"cond");
  S_ELSE =            SY(@"else");

  B_FALSE =           CONST(@"#f");
  B_TRUE =            CONST(@"#t");

  C_NULL =            CONST(@"()");

  UNSPECIFIED =       CONST(@"#<unspecified>");
}

+ (void)initialize {
  if ( __constants == nil ) {
    [self initializeSymbols];
    __constants = [[NSDictionary alloc]
                    initWithObjectsAndKeys:
                      B_FALSE, @"#f",
                    B_TRUE, @"#t",
                    [NSNumber numberWithInteger: 0], @"0",
                    [NSNumber numberWithDouble: 0.0], @"0.0",
                    nil];
  }

  if ( __loaders == nil ) {
    id<ObSFileLoader> bundleLoader = [[ObSBundleFileLoader alloc] init];
    __loaders = [[NSMutableArray alloc] initWithObjects: bundleLoader, nil];
    [bundleLoader release];
  }
}

+ (void)addFileLoader:(id<ObSFileLoader>)loader {
  [__loaders addObject: loader];
}

+ (void)removeFileLoader:(id<ObSFileLoader>)loader {
  [__loaders removeObject: loader];
}

+ (id)map:(id<ObSProcedure>)proc on:(id)arg {
  if ( arg == C_NULL ) {
    return C_NULL;

  } else {
    ObSCons* list = arg;
    return CONS([proc callWith: CONS(list.car, C_NULL)], [self map: proc on: list.cdr]);
  }
}

+ (ObSScope*)globalScope {
  if ( __globalScope == nil ) {
    __globalScope = [[ObSScope alloc] initWithOuterScope: nil name: @"global"];
    [ObjScheme addGlobalsToScope: __globalScope];
    [ObSNS initializeBridgeFunctions: __globalScope];
    [ObSStrings addToScope: __globalScope];
  }
  return __globalScope;
}

+ (NSString*)unpackStringLiteral:(NSString*)string {
  return [string substringWithRange: NSMakeRange(1, [string length]-2)];
}

+ (id)atomFromToken:(id)token {
  NSAssert(token != nil, @"Nil token not valid");
  id constantValue = [__constants objectForKey: token];
  if ( constantValue != nil )
    return constantValue;

  if ( [token isMemberOfClass: [ObSSymbol class]] )
    return token; // symbols are atomic

  NSString* string = token;
  if ( [string hasPrefix: @"\""] ) {
    return [ObjScheme unpackStringLiteral: string];
  }

  NSRange alphaNumRange = [string rangeOfCharacterFromSet: [NSCharacterSet letterCharacterSet]];
  if ( alphaNumRange.location == NSNotFound ) {

    NSRange dotLocation = [string rangeOfString: @"."];
    if ( dotLocation.location == NSNotFound ) {
      int intValue = [string intValue];
      if ( intValue != 0 ) { // note that the literal '0' is handled in constants above
        return [NSNumber numberWithInteger: intValue];
      }
    }

    double doubleValue = [string doubleValue];
    if ( doubleValue != 0.0 ) { // note that the literal '0.0' is handle in constants above
      return [NSNumber numberWithDouble: doubleValue];
    }
  }

  return [ObSSymbol symbolFromString: string];
}

+ (BOOL)isEmptyList:(id)token {
  return token == C_NULL;
}

+ (NSUInteger)listLength:(ObSCons*)list {
  NSUInteger length = 0;
  while ( (id)list != C_NULL ) {
    length++;
    list = [list cdr];
  }
  return length;
}

+ (ObSCons*)tailCons:(ObSCons*)list {
  while ( list.cdr != C_NULL ) {
    list = list.cdr;
  }
  return list;
}

+ (id)expandLetDefinitions:(id)definitions {
  if ( definitions == C_NULL ) {
    return C_NULL;

  } else {
    ObSCons* list = definitions;
    ObSCons* definition = [list car];
    definition = CONS([definition car], CONS([self expandToken: [definition cadr]], C_NULL));
    return CONS(definition, [self expandLetDefinitions: [list cdr]]);
  }
}

+ (id)expandTokenList:(id)arg {
  return [self expandTokenList: arg atTopLevel: NO];
}

+ (id)expandTokenList:(id)arg atTopLevel:(BOOL)topLevel {
  if ( arg == C_NULL ) {
    return C_NULL;

  } else {
    ObSCons* list = arg;
    id token = [self expandToken: list.car atTopLevel: topLevel];
    id tail = [self expandTokenList: list.cdr atTopLevel: topLevel];
    return ( token == UNSPECIFIED ? tail : CONS(token, tail) );
  }
}

+ (id)expandToken:(id)token {
  return [self expandToken: token atTopLevel: NO];
}

/**
 * Traverses a scope/token, doing basic syntax validation and expanding shortened forms.
 * @param  token     The token to expand & validate.
 * @param  topLevel  Whether this is the top-level scope.
 */
+ (id)expandToken:(id)token atTopLevel:(BOOL)topLevel {
  [ObjScheme assertSyntax: token != C_NULL elseRaise: @"Empty list is not a program"];

  if ( ! [token isKindOfClass: [ObSCons class]] ) {
    return token; // an atom
  }

  ObSCons* list = token;
  id head = list.car;
  NSUInteger length = [list count];

  if ( head == S_QUOTE ) { // (quote exp)
    [ObjScheme assertSyntax: (length == 2)
                  elseRaise: [NSString stringWithFormat: @"quote should have 1 arg, given %d", length-1]];

    id quotee = list.cadr;
    if ( [quotee isKindOfClass: [ObSCons class]] ) {
      ObSCons* quotedCons = quotee;
      if ( [quotedCons count] == 3 && [quotedCons cadr] == S_DOT ) {
        id pair = CONS([quotedCons car], [quotedCons caddr]);
        return CONS(S_QUOTE, CONS(pair, C_NULL));
      }
    }
    return list;

  } else if ( head == S_IF ) {
    [ObjScheme assertSyntax: (length == 4 || length == 3) elseRaise: @"Invalid 'if' syntax"];
    return [self expandTokenList: list atTopLevel: topLevel];

  } else if ( head == S_SET ) { // (set! thing exp)
    [ObjScheme assertSyntax: (length == 3) elseRaise: @"Invalid 'set!' syntax"];
    id var = [list cadr];
    [ObjScheme assertSyntax: [var isMemberOfClass: [ObSSymbol class]]
                  elseRaise: @"First arg of 'set!' should be a Symbol"];
    id expression = [self expandToken: [list caddr]];
    return CONS(S_SET, CONS(var, CONS(expression, C_NULL)));

  } else if ( head == S_DEFINE ) { // (define ...)
    [ObjScheme assertSyntax: (length >= 3) elseRaise: @"define takes at least 2 args"];
    id defineSpec = [list cadr];
    ObSCons* body = [list cddr];

    if ( [defineSpec isKindOfClass: [ObSCons class]] ) {
      // we're going to change (define (f args) body) => (define f (lambda (args) body)) for simplicity
      ObSCons* lambdaSpec = defineSpec;
      ObSSymbol* lambdaName = [lambdaSpec car];
      ObSCons* paramSpec = [lambdaSpec cdr];
      id params = paramSpec;
      if ( params != C_NULL && [params car] == S_DOT ) {
        params = [params cadr];
      }
      // => (f (params) body)
      ObSCons* lambda = CONS(S_LAMBDA, CONS(params, body));
      return [ObjScheme expandToken: CONS(S_DEFINE, CONS(lambdaName, CONS(lambda, C_NULL)))];

    } else {
      [ObjScheme assertSyntax: [defineSpec isMemberOfClass: [ObSSymbol class]]
                    elseRaise: @"define second param must be symbol"];
      id expression = [body car];
      return CONS(S_DEFINE, CONS(defineSpec, CONS([ObjScheme expandToken: expression], C_NULL)));
    }

  } else if ( head == S_DEFINEMACRO ) { // (define-macro symbol proc) or (define-macro (symbol args) body)
    [ObjScheme assertSyntax: topLevel elseRaise: @"define-macro must be invoked at the top level"];
    [ObjScheme assertSyntax: (length == 3) elseRaise: @"bad define-macro syntax"];

    id nameOrSpec = [list cadr];
    id body = [list caddr];
    body = [ObjScheme expandToken: body];
    ObSSymbol* macroName = nil;

    if ( [nameOrSpec isKindOfClass: [ObSSymbol class]] ) {
      macroName = nameOrSpec;

    } else {
      [ObjScheme assertSyntax: [nameOrSpec isKindOfClass: [ObSCons class]] elseRaise: @"bad define-macro spec"];
      ObSCons* callSpec = nameOrSpec;
      macroName = [callSpec car];
      id args = [nameOrSpec cdr];
      id lambdaArgSpec = args != C_NULL && [(ObSCons*)args car] == S_DOT ? [args cadr] : args;
      body = CONS(S_LAMBDA, CONS(lambdaArgSpec, body));
    }

    id<ObSProcedure> procedure = [[ObjScheme globalScope] evaluate: body];
    [ObjScheme assertSyntax: [procedure conformsToProtocol: @protocol(ObSProcedure)]
                  elseRaise: @"body of define-macro must be an invocation"];
    [[ObjScheme globalScope] defineMacroNamed: macroName asProcedure: procedure];

    return UNSPECIFIED;

  } else if ( head == S_BEGIN ) {
    if ( length == 1 ) { // (begin) => nil
      return C_NULL;

    } else {
      return CONS(S_BEGIN, [self expandTokenList: [list cdr] atTopLevel: topLevel]);
    }

  } else if ( head == S_LET || head == S_LET_STAR ) {
    // (let ((x e1) (y e2)) body...)
    // -or-
    // (let name ((x e1) (y e2)) body)
    // we special-case this so as not to accidentally try to expand the symbol names

    BOOL isNamed = [[list cadr] isKindOfClass: [ObSSymbol class]];
    if ( isNamed ) {
      ObSSymbol* name = [list cadr];
      ObSCons* definitions = [list caddr];
      ObSCons* body = [list cdddr];
      return CONS(head, CONS(name, CONS([self expandLetDefinitions: definitions], [self expandTokenList: body])));

    } else {
      ObSCons* definitions = [list cadr];
      ObSCons* body = [list cddr];
      return CONS(head, CONS([self expandLetDefinitions: definitions], [self expandTokenList: body]));
    }

  } else if ( head == S_LAMBDA ) {
    // (lambda (x) a b) => (lambda (x) (begin a b))
    // (lambda x expr) => (lambda (x) expr)
    [ObjScheme assertSyntax: (length >= 3) elseRaise: @"not enough args for lambda"];
    id parameters = [list cadr];
    if ( [parameters isKindOfClass: [ObSCons class]] ) {
      for ( id paramName in (ObSCons*)parameters ) {
        [ObjScheme assertSyntax: [paramName isKindOfClass: [ObSSymbol class]] elseRaise: [NSString stringWithFormat: @"invalid lambda parameter %@ in %@", paramName, parameters]];
      }

    } else {
      [ObjScheme assertSyntax: parameters == C_NULL || [parameters isKindOfClass: [ObSSymbol class]] elseRaise: [NSString stringWithFormat: @"invalid lambda parameter %@", parameters]];
    }

    ObSCons* body = [list cddr];
    id expression = [self expandToken: ([body count] == 1 ? [body car] : CONS(S_BEGIN, body))];

    return CONS(S_LAMBDA, CONS(parameters, CONS(expression, C_NULL)));

  } else if ( head == S_QUASIQUOTE ) {
    [ObjScheme assertSyntax: (length == 2) elseRaise: @"invalid quasiquote, wrong arg num"];
    return [ObjScheme expandQuasiquote: [list cadr]];

  } else if ( [head isKindOfClass: [ObSSymbol class]] ) {
    ObSSymbol* symbol = head;
    id macro = [[ObjScheme globalScope] macroNamed: symbol];
    if ( macro ) {
      ObSCons* args = [list cdr];
      return [ObjScheme expandToken: [macro callWith: args]];
    }
  }

  return [self expandTokenList: list];
}

+ (id)filter:(id)list with:(id<ObSProcedure>)proc {
  if ( list == C_NULL ) {
    return C_NULL;

  } else {
    ObSCons* cell = list;
    if ( [proc callWith: CONS([cell car], C_NULL)] != B_FALSE ) {
      return CONS(cell.car, [self filter: cell.cdr with: proc]);

    } else {
      return [self filter: cell.cdr with: proc];
    }
  }
}

+ (id)list:(NSArray*)tokens {

  if ( [tokens count] == 0 ) {
    return C_NULL;

  } else {
    return CONS([tokens objectAtIndex: 0], [self list: [tokens subarrayWithRange: NSMakeRange(1, [tokens count]-1)]]);
  }
}

+ (id)quoted:(id)token {
  return CONS(S_QUOTE, CONS(token, C_NULL));
}

/**
 * `x => 'x
 * `,x => x
 * `(,@x y)
 */
+ (id)expandQuasiquote:(id)token {
  if ( ! [token isKindOfClass: [ObSCons class]] ) {
    return [self quoted: token];

  } else {
    ObSCons* list = token;
    NSUInteger length = [ObjScheme listLength: list];

    id first = [list car];
    [ObjScheme assertSyntax: (first != S_UNQUOTESPLICING) elseRaise: @"can't splice at beginning of quasiquote"];
    ObSCons* remainderOfList = [list cdr];

    if ( first == S_UNQUOTE ) {
      [ObjScheme assertSyntax: (length == 2) elseRaise: @"invalid unquote phrase, missing operand"];
      return [list cadr];

    } else if ( [first isKindOfClass: [ObSCons class]] && [(ObSCons*)first car] == S_UNQUOTESPLICING ) {
      ObSCons* unquoteSplicingSpec = first;
      [ObjScheme assertSyntax: ([ObjScheme listLength: unquoteSplicingSpec] == 2) elseRaise: @"invalid unquote-splicing phrase, missing operand"];
      return CONS(S_APPEND, CONS([unquoteSplicingSpec cadr], CONS([ObjScheme expandQuasiquote: remainderOfList], C_NULL)));

    } else {
      return CONS(S_CONS, CONS([ObjScheme expandQuasiquote: first], CONS([ObjScheme expandQuasiquote: remainderOfList], C_NULL)));
    }
  }
}

+ (void)loadFile:(NSString*)filename {
  [self loadFile: filename intoScope: [ObjScheme globalScope]];
}

+ (void)loadFile:(NSString*)filename intoScope:(ObSScope*)scope {
  for ( id<ObSFileLoader> loader in __loaders ) {
    NSString* qualifiedName = [loader qualifyFileName: filename];
    if ( ! qualifiedName ) {
      continue;
    }

    if ( [scope isFilenameLoaded: qualifiedName] ) {
      //NSLog( @"Skipping %@, already loaded", qualifiedName );
      return;
    }

    ObSInPort* port = [loader findFile: qualifiedName];
    if ( port != nil ) {
      //NSLog( @"(%p) Loading %@ FOR %@", scope, qualifiedName, filename );
      [self loadInPort: port intoScope: scope forFilename: qualifiedName];
      return;
    }
  }

  [NSException raise: @"NoSuchFile" format: @"failed to find %@ from any source", filename];
}

+ (void)loadSource:(NSString*)source intoScope:(ObSScope*)scope {
  ObSInPort* port = [[ObSInPort alloc] initWithString: source];
  [self loadInPort: port intoScope: scope forFilename: nil];
  [port release];
}

+ (void)loadInPort:(ObSInPort*)port intoScope:(ObSScope*)scope forFilename:(NSString*)filename {
  id token = [ObjScheme parseOneToken: port];

  while ( token != _EOF ) {
    [scope evaluate: token];
    token = [ObjScheme parseOneToken: port];
  }

  if ( filename ) {
    [scope recordFilenameLoaded: filename];
  }
}

/**
 * read a program, then expand and error-check it
 */
+ (id)parseOneToken:(ObSInPort*)inPort {
  return [ObjScheme expandToken: [ObjScheme read: inPort] atTopLevel: YES];
}

+ (id)readAheadFromToken:(id)token andPort:(ObSInPort*)inPort {
  if ( token == S_OPENPAREN || token == S_OPENBRACKET ) {
    id list = C_NULL;
    ObSCons* lastCons = nil;

    while ( 1 ) {
      token = [inPort nextToken];
      if ( token == S_CLOSEPAREN || token == S_CLOSEBRACKET ) {
        break;

      } else {
        id next = [ObjScheme readAheadFromToken: token andPort: inPort];
        ObSCons* cell = CONS(next, C_NULL);

        if ( lastCons == nil ) {
          list = lastCons = cell;
        } else {
          lastCons.cdr = cell;
          lastCons = cell;
        }
      }
    }

    return list;

  } else if ( token == S_CLOSEPAREN ) {
    [NSException raise: @"SyntaxError" format: @"unexpected ')'"];
    return nil;

  } else if ( token == S_CLOSEBRACKET ) {
    [NSException raise: @"SyntaxError" format: @"unexpected ']'"];
    return nil;

  } else if ( token == S_QUOTE || token == S_QUASIQUOTE || token == S_UNQUOTE || token == S_UNQUOTESPLICING ) {
    return CONS(token, CONS([ObjScheme read: inPort], C_NULL));

  } else if ( token == _EOF ) {
    [NSException raise: @"SyntaxError" format: @"unexpected EOF in list"];
    return nil;

  } else {
    return [ObjScheme atomFromToken: token];
  }
}

+ (id)read:(ObSInPort*)inPort {
  id token = [inPort nextToken];

  if ( token == _EOF ) {
    return _EOF;

  } else {
    return [ObjScheme readAheadFromToken: token andPort: inPort];
  }
}

+ (id)parseString:(NSString*)string {
  return [ObjScheme parseOneToken: [[[ObSInPort alloc] initWithString: string] autorelease]];
}


+ (void)assertSyntax:(BOOL)correct elseRaise:(NSString*)message {
  if ( ! correct )
    [NSException raise: @"SyntaxError" format: @"%@", message];
}

+ (void)addGlobalsToScope:(ObSScope*)scope {
  [scope defineFunction: [ObSNativeLambda named: SY(@"+")
                                      fromBlock: ^(NSArray* list) {
        if ( [list count] == 0 ) {
          return [NSNumber numberWithInteger: 0];
        }

        int intRet = 0;
        double doubleRet = 0.0;
        BOOL useDouble = NO;

        for ( NSNumber* n in list ) {
          if ( ! useDouble && strcmp([n objCType], @encode(int)) == 0 ) {
            intRet += [n intValue];
            doubleRet += [n doubleValue];

          } else {
            useDouble = YES;
            doubleRet += [n doubleValue];
          }
        }

        if ( useDouble ) {
          return [NSNumber numberWithDouble: doubleRet];

        } else {
          return [NSNumber numberWithInt: intRet];
        }

        /*
        NSNumber* first = [list objectAtIndex: 0];

        if ( strcmp([first objCType], @encode(int)) == 0 ) {
          int ret = 0;
          for ( NSNumber* number in list ) {
            ret += [number intValue];
          }
          return [NSNumber numberWithInteger: ret];

        } else {
          double ret = 0;
          for ( NSNumber* number in list ) {
            ret += [number doubleValue];
          }
          return [NSNumber numberWithDouble: ret];
        }
        */
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"-")
                                      fromBlock: ^(NSArray* list) {
        NSNumber* first = [list objectAtIndex: 0];
        NSNumber* second = [list objectAtIndex: 1];
        if ( strcmp([first objCType], @encode(int)) == 0 ) {
          return [NSNumber numberWithInteger: [first intValue]-[second intValue]];

        } else {
          return [NSNumber numberWithDouble: [first doubleValue]-[second doubleValue]];
        }
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"*")
                                      fromBlock: ^(NSArray* list) {
        if ( [list count] == 0 ) {
          return [NSNumber numberWithInteger: 0];
        }

        int intRet = 1;
        double doubleRet = 1.0;
        BOOL useDouble = NO;

        for ( NSNumber* number in list ) {
          NSAssert1( [number isKindOfClass: [NSNumber class]], @"%@ is not a number", number );
          if ( useDouble || strcmp([number objCType], @encode(int)) != 0 ) {
            useDouble = YES;
            doubleRet *= [number doubleValue];

          } else {
            intRet *= [number intValue];
            doubleRet *= [number doubleValue];
          }
        }

        if ( useDouble ) {
          return [NSNumber numberWithDouble: doubleRet];

        } else {
          return [NSNumber numberWithInteger: intRet];
        }
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"/")
                                      fromBlock: ^(NSArray* list) {
                                        NSNumber* first = [list objectAtIndex: 0];
                                        NSNumber* second = [list objectAtIndex: 1];

                                        if ( [second floatValue] == 0.0 )
                                          return [NSNumber numberWithLongLong: LLONG_MAX];

                                        if ( [first floatValue] == 0.0 )
                                          return first;

                                        return [NSNumber numberWithDouble: [first doubleValue]/[second doubleValue]];
                                      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"safe-divide")
                                      fromBlock: ^(NSArray* list) {
                                        NSNumber* first = [list objectAtIndex: 0];
                                        NSNumber* second = [list objectAtIndex: 1];
                                        
                                        if ( [second floatValue] == 0.0 )
                                          return [NSNumber numberWithLongLong: LLONG_MAX];
                                        
                                        if ( [first floatValue] == 0.0 )
                                          return first;
                                        
                                        return [NSNumber numberWithDouble: [first doubleValue]/[second doubleValue]];
                                      }]];
  
  [scope define: SY(@"+inf.0") as: [NSNumber numberWithLongLong: LLONG_MAX]];


  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"not")
                                                 fromBlock: ^(id object) { return object == B_FALSE ? B_TRUE : B_FALSE; }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@">")
                                      fromBlock: ^(NSArray* list) {
        NSNumber* first = [list objectAtIndex: 0];
        NSNumber* second = [list objectAtIndex: 1];
        return [first doubleValue] > [second doubleValue] ? B_TRUE : B_FALSE;
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"<")
                                      fromBlock: ^(NSArray* list) {
        NSNumber* first = [list objectAtIndex: 0];
        NSNumber* second = [list objectAtIndex: 1];
        return [first doubleValue] < [second doubleValue] ? B_TRUE : B_FALSE;
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@">=")
                                      fromBlock: ^(NSArray* list) {
        NSNumber* first = [list objectAtIndex: 0];
        NSNumber* second = [list objectAtIndex: 1];
        return [first doubleValue] >= [second doubleValue] ? B_TRUE : B_FALSE;
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"<=")
                                      fromBlock: ^(NSArray* list) {
        NSNumber* first = [list objectAtIndex: 0];
        NSNumber* second = [list objectAtIndex: 1];
        return [first doubleValue] <= [second doubleValue] ? B_TRUE : B_FALSE;
      }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"=")
                                            fromBlock: ^(id a, id b) {
        NSNumber* first = a;
        NSNumber* second = b;
        return [first isEqualToNumber: second] ? B_TRUE : B_FALSE;
      }]];


  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"list?")
                                           fromBlock: ^(id o) {
        if ( o == C_NULL ) {
          return B_TRUE;

        } else if ( [o isKindOfClass: [ObSCons class]] ) {
          ObSCons* cons = o;
          id cdr = cons.cdr;
          return TRUTH(cdr == C_NULL || [cdr isKindOfClass: [ObSCons class]]);

        } else {
          return B_FALSE;
        }
      }]];

  [scope defineFunction: U_LAMBDA(@"null?", ^(id o) { return TRUTH(o == C_NULL); })];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"last")
                                            fromBlock: ^(id list) {
        if ( list == C_NULL )
          return [ObjScheme boolToTruth: NO];

        ObSCons* tail = list;
        id item = [tail car];

        while ( [tail cdr] != C_NULL ) {
          tail = [tail cdr];
          item = [tail car];
        }

        return item;
      }]];

  [scope defineFunction: B_LAMBDA(@"eq?", ^(id a, id b){ return (a == b) ? B_TRUE : B_FALSE; })];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"eqv?")
                                            fromBlock: ^(id a, id b) {
        if ( [a isKindOfClass: [NSNumber class]] && [b isKindOfClass: [NSNumber class]] ) {
          NSNumber* n1 = a, *n2 = b;
          return TRUTH([n1 isEqualToNumber: n2]);
        } else {
          return TRUTH(a == b);
        }
      }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"equal?")
                                            fromBlock: ^(id a, id b) {

        if ( [a isKindOfClass: [NSNumber class]] && [b isKindOfClass: [NSNumber class]] ) {
          NSNumber* n1 = a, *n2 = b;
          return [n1 isEqualToNumber: n2] ? B_TRUE : B_FALSE;

        } else if ( a == b ) {
          return B_TRUE;

        } else {
          return [a isEqual: b] ? B_TRUE : B_FALSE;
        }
      }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"cons")
                                            fromBlock: ^(id a, id b) {
        return [[[ObSCons alloc] initWithCar: a cdr: b] autorelease];
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"car")
                                           fromBlock: ^(id o) {
        NSAssert1([o isKindOfClass: [ObSCons class]], @"invalid operand for car %@", o);
        ObSCons* cons = o;
        return [cons car];
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"cdr")
                                           fromBlock: ^(id o) {
        NSAssert1([o isKindOfClass: [ObSCons class]], @"invalid operand for car %@", o);
        ObSCons* cons = o;
        return [cons cdr];
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"cadr")
                                           fromBlock: ^(id o) {
        NSAssert1([o isKindOfClass: [ObSCons class]], @"invalid operand for car %@", o);
        ObSCons* cons = o;
        return [cons cadr];
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"caddr")
                                           fromBlock: ^(id o) {
        NSAssert1([o isKindOfClass: [ObSCons class]], @"invalid operand for car %@", o);
        ObSCons* cons = o;
        return [cons caddr];
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"cddr")
                                           fromBlock: ^(id o) {
        NSAssert1([o isKindOfClass: [ObSCons class]], @"invalid operand for car %@", o);
        ObSCons* cons = o;
        return [cons cddr];
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"cdddr")
                                           fromBlock: ^(id o) {
        NSAssert1([o isKindOfClass: [ObSCons class]], @"invalid operand for car %@", o);
        ObSCons* cons = o;
        return [cons cdddr];
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"length")
                                           fromBlock: ^(id o) {
        if ( o == C_NULL )
          return [NSNumber numberWithInteger: 0];

        NSAssert1([o isKindOfClass: [ObSCons class]], @"invalid operand for length, should be list %@", o);
        int length = 0;
        id cell = o;
        while ( cell != C_NULL ) {
          NSAssert([o isKindOfClass: [ObSCons class]], @"length called on non-list, %@", o);
          length++;
          ObSCons* cons = cell;
          cell = [cons cdr];
        }
        return [NSNumber numberWithInteger: length];
      }]];

  [scope defineFunction: U_LAMBDA(@"symbol?", ^(id o) { return TRUTH([o isKindOfClass: [ObSSymbol class]]); })];
  [scope defineFunction: U_LAMBDA(@"boolean?", ^(id o) { return TRUTH(o == B_TRUE || o == B_FALSE); })];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"pair?")
                                           fromBlock: ^(id o) {
        if ( o == C_NULL || ! [o isKindOfClass: [ObSCons class]] ) {
          return B_FALSE;

        } else {
          // if anything down the path isn't a CONS or null, then yeah
          ObSCons* cons = o;

          while ( 1 ) {
            o = [cons cdr];

            if ( o == C_NULL ) {
              return B_FALSE; // this is a list, by definition
            }

            if ( [o isKindOfClass: [ObSCons class]] ) {
              cons = o;
              continue;

            } else {
              return B_TRUE; // we found a non-list CDR
            }
          }
        }
      }]];

  [scope defineFunction: U_LAMBDA(@"number?", ^(id o) { return TRUTH([o isKindOfClass: [NSNumber class]]); })];
  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"integer?")
                                           fromBlock: ^(id o) {
        if ( ! [o isKindOfClass: [NSNumber class]] ) {
          return B_FALSE;

        } else {
          NSNumber* number = o;
          return TRUTH(strcmp([number objCType], @encode(int)) == 0);
        }
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"procedure?")
                                           fromBlock: ^(id o) {
        return TRUTH([o conformsToProtocol: @protocol(ObSProcedure)]);
      }]];

  [scope defineFunction: U_LAMBDA(@"symbol->string", ^(id o) { ObSSymbol* s = o; return s.string; })];
  [scope defineFunction: U_LAMBDA(@"string->symbol", ^(id o) { return [ObSSymbol symbolFromString: o]; })];
  [scope defineFunction: [ObSNativeLambda named: SY(@"string-append")
                                      fromBlock: ^(NSArray* strings) {
        NSMutableString* string = [NSMutableString string];
        for ( NSString* s in strings ) {
          [string appendString: s];
        }
        return string;
      }]];
  [scope defineFunction: U_LAMBDA(@"string->number", ^(id o) { return [NSNumber numberWithDouble: [(NSString*)o doubleValue]]; })];
  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"number->string")
                                           fromBlock: ^(id o) {
        NSNumber* n = o;
        if ( strcmp([n objCType], @encode(int)) == 0 ) {
          return [NSString stringWithFormat: @"%d", [n intValue]];
        } else {
          return [NSString stringWithFormat: @"%f", [n doubleValue]];
        }
      }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"string-split")
                                            fromBlock: ^(id string, id sep) {
        // TODO: this should *really* enforce that 'sep' is a character, not a string, but it's all Doug's fault.
        return [ObjScheme list: [(NSString*)string componentsSeparatedByString: sep]];
      }]];

  [scope defineFunction: U_LAMBDA(@"inexact->exact", ^(id o) { return [NSNumber numberWithInteger: [(NSNumber*)o intValue]]; })];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"map")
                                            fromBlock: ^(id proc, id args) {
        NSAssert1( [proc conformsToProtocol: @protocol(ObSProcedure)], @"map: proc is %@", proc );
        NSAssert1( args == C_NULL || [args isKindOfClass: [ObSCons class]], @"map: args is '%@'", args );
        return [ObjScheme map: (id<ObSProcedure>)proc on: (ObSCons*)args];
      }]];

  [scope defineFunction: U_LAMBDA(@"display", ^(id x) { NSLog(@"%@", x); return B_FALSE; })];

  [scope defineFunction: [ObSNativeLambda named: SY(@"newline")
                                      fromBlock: ^(NSArray* array) {
        NSLog(@"");
        return B_FALSE; }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"abs")
                                           fromBlock: ^(id n) {
        NSNumber* number = n;
        if ( strcmp([number objCType], @encode(int)) == 0 ) {
          return [NSNumber numberWithInteger: abs([number intValue])];

        } else {
          return [NSNumber numberWithDouble: fabs([number doubleValue])];
        }
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"even?")
                                           fromBlock: ^(id n) {
        NSNumber* number = n;
        return TRUTH([number intValue] % 2 == 0);
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"odd?")
                                           fromBlock: ^(id n) {
        NSNumber* number = n;
        return TRUTH([number intValue] % 2 == 1);
      }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"expt")
                                            fromBlock: ^(id a, id b) {
        NSNumber *n1 = a, *n2 = b;
        if ( ISDOUBLE(n1) || ISDOUBLE(n2) ) {
          return [NSNumber numberWithDouble: pow([n1 doubleValue], [n2 doubleValue])];
        } else {
          NSInteger power = [n2 intValue];
          if ( power < 0 ) {
            return [NSNumber numberWithDouble: pow([n1 doubleValue], power)];

          } else {
            return [NSNumber numberWithInteger: pow([n1 intValue], power)];
          }
        }
      }]];

  [scope defineFunction: B_LAMBDA(@"filter", ^(id a, id b) { return [ObjScheme filter: b with: a]; })];

  [scope defineFunction: B_LAMBDA(@"string-startswith?", ^(id a, id b) { return [ObjScheme boolToTruth: [(NSString*)a hasPrefix: (NSString*)b]]; })];
  [scope defineFunction: B_LAMBDA(@"string-endswith?", ^(id a, id b) { return [ObjScheme boolToTruth: [(NSString*)a hasSuffix: (NSString*)b]]; })];
  [scope defineFunction: [ObSNativeLambda named: SY(@"string-substring")
                                      fromBlock: ^(NSArray* args) {
        NSString* string = [args objectAtIndex: 0];
        NSInteger firstIdx = [(NSNumber*)[args objectAtIndex: 1] intValue];
        if ( firstIdx < 0 ) {
          firstIdx = [string length] + firstIdx; // + is right, it's negative
        }

        if ( [args count] == 3 ) {
          NSInteger secondIdx = [(NSNumber*)[args objectAtIndex: 2] intValue];
          if ( secondIdx < 0 ) {
            secondIdx = [string length] + secondIdx; // + is right, it's negative
          }

          return [string substringWithRange: NSMakeRange(firstIdx, secondIdx-firstIdx)];

        } else {
          return [string substringFromIndex: firstIdx];
        }

      }]];

  [scope defineFunction: B_LAMBDA(@"split", ^(id s1, id s2) { NSString* str = s1; NSString* d = s2; return [ObjScheme list: [str componentsSeparatedByString: d]]; })];

  [scope defineFunction: [ObSNativeLambda named: SY(@"max")
                                      fromBlock: ^(NSArray* args) {
        NSNumber* max = nil;
        double maxDouble = 0.0;

        for ( NSNumber* n in args ) {
          double d = [n doubleValue];

          if ( max == nil || d > maxDouble ) {
            max = n;
            maxDouble = d;
          }
        }

        return max;
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"min")
                                      fromBlock: ^(NSArray* args) {
        NSNumber* min = nil;
        double minDouble = 0.0;

        for ( NSNumber* n in args ) {
          double d = [n doubleValue];

          if ( min == nil || d < minDouble ) {
            min = n;
            minDouble = d;
          }
        }

        return min;
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"make-vector")
                                      fromBlock: ^(NSArray* args) {
        int size = [(NSNumber*)[args objectAtIndex: 0] intValue];
        NSMutableArray* vector = [NSMutableArray arrayWithCapacity: size];

        id fill = UNSPECIFIED;
        if ( [args count] > 1 ) {
          fill = [args objectAtIndex: 1];
        }

        for ( int i = 0; i < size; i++ ) {
          [vector addObject: fill];
        }

        return vector;
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"vector")
                                      fromBlock: ^(NSArray* args) {
        return args;
      }]];

  [scope defineFunction: U_LAMBDA(@"vector-length", ^(id a) { return [NSNumber numberWithInteger: [(NSArray*)a count]]; })];

  [scope defineFunction: U_LAMBDA(@"vector?", ^(id a) { return TRUTH([a isKindOfClass: [NSArray class]]); })];

  [scope defineFunction: U_LAMBDA(@"vector->list", ^(id a) { return [ObjScheme list: (NSArray*)a]; })];
  [scope defineFunction: U_LAMBDA(@"list->vector", ^(id a) { if ( a == C_NULL ) { return (id)[NSArray array]; } else { return (id)[(ObSCons*)a toArray]; } })];
  [scope defineFunction: B_LAMBDA(@"vector-ref", ^(id a, id b) { return [(NSArray*)a objectAtIndex: [(NSNumber*)b intValue]]; })];
  [scope defineFunction: [ObSNativeLambda named: SY(@"vector-set!")
                                      fromBlock: ^(NSArray* args) {
        NSMutableArray* vector = [args objectAtIndex: 0];
        int index = [(NSNumber*)[args objectAtIndex: 1] intValue];
        id value = [args objectAtIndex: 2];
        [vector replaceObjectAtIndex: index withObject: value];
        return UNSPECIFIED;
      }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"list-head")
                                            fromBlock: ^(id a, id b) {
        ObSCons* list = a;
        NSInteger length = [(NSNumber*)b integerValue];

        id ret = C_NULL;
        ObSCons* soFar = nil;

        // if length == 0, we'll just return C_NULL, which is correct
        while ( length-- > 0 ) {
          if ( ret == C_NULL ) {
            // this is just the first iteration, where we create the 1-length sublist
            ret = soFar = CONS(list.car, C_NULL);

          } else {
            // from then on, we're tracking the last CONS cell, and mutating it.
            ObSCons* nextCell = CONS(list.car, C_NULL);
            [soFar setCdr: nextCell];
            soFar = nextCell;
          }
          // pop!
          list = list.cdr;
        }

        return ret;
      }]];

  [scope defineFunction: U_LAMBDA(@"vector->immutable-vector", ^(id a) { return [NSArray arrayWithArray: (NSArray*)a]; })];
  [scope defineFunction: U_LAMBDA(@"immutable?", ^(id a) { return TRUTH([a isKindOfClass: [NSString class]] || ( [a isKindOfClass: [NSArray class]] && ! [a isKindOfClass: [NSMutableArray class]] )); })];
  [scope defineFunction: [ObSNativeLambda named: SY(@"vector-immutable")
                                      fromBlock: ^(NSArray* params) {
        return [NSArray arrayWithArray: params];
      }]];
  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"vector-fill!")
                                            fromBlock: ^(id a, id value) {
        NSMutableArray* vector = a;
        NSUInteger length = [vector count];
        for ( NSUInteger i = 0; i < length; i++ ) {
          [vector replaceObjectAtIndex: i withObject: value];
        }
        return UNSPECIFIED;
      }]];


  [scope defineFunction: U_LAMBDA(@"unspecified?", ^(id a) { return TRUTH(a == UNSPECIFIED); })];

  [scope defineFunction: U_LAMBDA(@"identity", ^(id x) { return x; })];

  [scope defineFunction: U_LAMBDA(@"string?", ^(id x) { return TRUTH([x isKindOfClass: [NSString class]]); })];
  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"for-each")
                                            fromBlock: ^(id a, id b) {
        if ( b != C_NULL ) {
          id<ObSProcedure> proc = a;
          ObSCons* list = b;
          if ( [a conformsToProtocol: @protocol(ObSUnaryLambda)] ) {
            id<ObSUnaryLambda> unary = a;
            for ( id item in list ) {
              [unary callNatively: item];
            }

          } else {
            for ( id item in list ) {
              [proc callWith: CONS(item, C_NULL)];
            }
          }
        }
        return UNSPECIFIED;
      }]];

  [scope defineFunction: U_LAMBDA(@"round", ^(id a) { return [NSNumber numberWithDouble: round([(NSNumber*)a doubleValue])]; })];
  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"set-car!")
                                            fromBlock: ^(id a, id val) {
        ObSCons* cons = a;
        [cons setCar: val];
        return UNSPECIFIED;
      }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"set-cdr!")
                                            fromBlock: ^(id a, id val) {
        ObSCons* cons = a;
        [cons setCdr: val];
        return UNSPECIFIED;
      }]];

  [scope defineFunction: [ObSNativeLambda named: S_APPEND
                                      fromBlock: ^(NSArray* array) {
        ObSCons* list = (id)C_NULL;

        for ( id thing in array ) {
          if ( thing == (id)C_NULL ) {
            continue;
          }

          ObSCons* subList = thing;
          if ( list == (id)C_NULL ) {
            list = [subList clone];

          } else {
            [[ObjScheme tailCons: list] setCdr: [subList clone]];
          }
        }

        return (id)list;
      }]];

  // TODO:
  /*
    - (vector-copy! dest dest-start src [src-start src-end])
    - error <= and replace Exceptions with (error) results which cause a return...? would that work...?
    - floor/ceiling
    - member? (member? thing list)
    - reduce (reduce combiner list)
    - write (and something for formatting properly...)

    - SOON:
    - char (#\a) support?

    - MAYBE:
    - I/O: load, read, write, read-char, open-input-file, close-input-port, open-output-file, close-output-port, eof-object?
    - port?

    - SOME DAY:
    - call/cc
   */
}

+ (BOOL)isTrue:(id)token {
  return token == B_TRUE;
}

+ (BOOL)isFalse:(id)token {
  return token == B_FALSE;
}

+ (id)boolToTruth:(BOOL)b {
  return b ? B_TRUE : B_FALSE;
}

+ (id)unspecified {
  return UNSPECIFIED;
}

@end
