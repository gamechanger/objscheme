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

NSNumber* B_FALSE;
NSNumber* B_TRUE;

ObSConstant* C_NULL;

ObSConstant* UNSPECIFIED;
NSNumber* INF;

@interface ObjScheme ()

+ (id)atomFromToken:(NSString*)token;
+ (NSString*)unpackStringLiteral:(NSString*)string;
- (id)expandToken:(id)token;
- (id)expandToken:(id)token atTopLevel:(BOOL)topLevel;
+ (void)assertSyntax:(BOOL)correct elseRaise:(NSString*)message;
+ (id)expandQuasiquote:(id)token;
- (void)addGlobalsToScope:(ObSScope*)scope;

@end




// ------ ObjScheme top-level

@implementation ObjScheme {
  ObSScope* _globalScope;
}

static NSDictionary* __constants = nil;
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

  B_FALSE =           @NO;
  B_TRUE =            @YES;

  C_NULL =            CONST(@"()");

  UNSPECIFIED =       CONST(@"#<unspecified>");

  INF =         [[NSNumber alloc] initWithLongLong: LLONG_MAX];
}

+ (void)initialize {
  if ( __constants == nil ) {
    [self initializeSymbols];

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __constants = [[NSDictionary alloc]
                        initWithObjectsAndKeys:
                          B_FALSE, @"#f",
                        B_TRUE, @"#t",
                        [NSNumber numberWithInteger: 0], @"0",
                        [NSNumber numberWithDouble: 0.0], @"0.0",
                        nil];
      });
  }

  if ( __loaders == nil ) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        id<ObSFileLoader> bundleLoader = [[ObSBundleFileLoader alloc] init];
        __loaders = [[NSMutableArray alloc] initWithObjects: bundleLoader, nil];
        [bundleLoader release];
      });
  }
}

+ (void)addFileLoader:(id<ObSFileLoader>)loader {
  [__loaders addObject: loader];
}

+ (void)removeFileLoader:(id<ObSFileLoader>)loader {
  [__loaders removeObject: loader];
}

+ (id)map:(id<ObSProcedure>)proc on:(id)arg {
  if ( EMPTY(arg) ) {
    return C_NULL;

  } else {
    ObSCons* list = arg;
    return CONS([proc callWith: CONS(CAR(list), C_NULL)], [self map: proc on: CDR(list)]);
  }
}

- (void)dealloc {
  _globalScope.context = nil;
  [_globalScope release];
  [super dealloc];
}

- (ObSScope*)globalScope {
  if ( _globalScope == nil ) {
    _globalScope = [[ObSScope alloc] initWithContext: self name: @"global"];
    [self addGlobalsToScope: _globalScope];
    [ObSNS initializeBridgeFunctions: _globalScope];
    [ObSStrings addToScope: _globalScope];
  }
  return _globalScope;
}

+ (NSString*)unpackStringLiteral:(NSString*)string {
  return [string substringWithRange: NSMakeRange(1, [string length]-2)];
}

+ (id)atomFromToken:(id)token {
  NSAssert(token != nil, @"Nil token not valid");
  id constantValue = [__constants objectForKey: token];
  if ( constantValue != nil ) {
    return constantValue;
  }

  if ( [token isMemberOfClass: [ObSSymbol class]] ) {
    return token; // symbols are atomic
  }

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
  return EMPTY(token);
}

+ (NSUInteger)listLength:(ObSCons*)list {
  NSUInteger length = 0;
  while ( (id)list != C_NULL ) {
    length++;
    list = CDR(list);
  }
  return length;
}

+ (ObSCons*)tailCons:(ObSCons*)list {
  while ( CDR(list) != C_NULL ) {
    list = CDR(list);
  }
  return list;
}

id appendListsToList(ObSCons* lists, ObSCons* aList) {
  if ( EMPTY(lists) ) {
    return aList;
  }

  if ( EMPTY(aList) ) {
    return appendListsToList( CDR(lists), CAR(lists) );
  }

  return CONS(CAR(aList), appendListsToList( lists, CDR(aList) ));
}

- (id)expandLetDefinitions:(id)definitions {
  if ( EMPTY(definitions) ) {
    return C_NULL;

  } else {
    ObSCons* list = definitions;
    ObSCons* definition = CAR(list);
    definition = CONS(CAR(definition), CONS([self expandToken: CADR(definition)], C_NULL));
    return CONS(definition, [self expandLetDefinitions: CDR(list)]);
  }
}

- (id)expandTokenList:(id)arg {
  return [self expandTokenList: arg atTopLevel: NO];
}

- (id)expandTokenList:(id)arg atTopLevel:(BOOL)topLevel {
  if ( EMPTY(arg) ) {
    return C_NULL;

  } else {
    ObSCons* list = arg;
    id token = [self expandToken: CAR(list) atTopLevel: topLevel];
    id tail = [self expandTokenList: CDR(list) atTopLevel: topLevel];
    return ( token == UNSPECIFIED ? tail : CONS(token, tail) );
  }
}

- (id)expandToken:(id)token {
  return [self expandToken: token atTopLevel: NO];
}

/**
 * Traverses a scope/token, doing basic syntax validation and expanding shortened forms.
 * @param  token     The token to expand & validate.
 * @param  topLevel  Whether this is the top-level scope.
 */
- (id)expandToken:(id)token atTopLevel:(BOOL)topLevel {
  [ObjScheme assertSyntax: token != C_NULL elseRaise: @"Empty list is not a program"];

  if ( ! [token isKindOfClass: [ObSCons class]] ) {
    return token; // an atom
  }

  ObSCons* list = token;
  id head = CAR(list);
  NSUInteger length = [list count];

  if ( head == S_QUOTE ) { // (quote exp)
    [ObjScheme assertSyntax: (length == 2)
                  elseRaise: [NSString stringWithFormat: @"quote should have 1 arg, given %d", length-1]];

    id quotee = CADR(list);
    if ( [quotee isKindOfClass: [ObSCons class]] ) {
      ObSCons* quotedCons = quotee;
      if ( [quotedCons count] == 3 && CADR(quotedCons) == S_DOT ) {
        id pair = CONS(CAR(quotedCons), CADDR(quotedCons));
        return CONS(S_QUOTE, CONS(pair, C_NULL));
      }
    }
    return list;

  } else if ( head == S_IF ) {
    [ObjScheme assertSyntax: (length == 4 || length == 3) elseRaise: @"Invalid 'if' syntax"];
    return [self expandTokenList: list atTopLevel: topLevel];

  } else if ( head == S_SET ) { // (set! thing exp)
    [ObjScheme assertSyntax: (length == 3) elseRaise: @"Invalid 'set!' syntax"];
    id var = CADR(list);
    [ObjScheme assertSyntax: [var isMemberOfClass: [ObSSymbol class]]
                  elseRaise: @"First arg of 'set!' should be a Symbol"];
    id expression = [self expandToken: CADDR(list)];
    return CONS(S_SET, CONS(var, CONS(expression, C_NULL)));

  } else if ( head == S_DEFINE ) { // (define ...)
    [ObjScheme assertSyntax: (length >= 3) elseRaise: @"define takes at least 2 args"];
    id defineSpec = CADR(list);
    ObSCons* body = CDDR(list);

    if ( [defineSpec isKindOfClass: [ObSCons class]] ) {
      // we're going to change (define (f args) body) => (define f (lambda (args) body)) for simplicity
      ObSCons* lambdaSpec = defineSpec;
      ObSSymbol* lambdaName = CAR(lambdaSpec);
      ObSCons* paramSpec = CDR(lambdaSpec);
      id params = paramSpec;
      if ( params != C_NULL && CAR((ObSCons*)params) == S_DOT ) {
        params = CADR((ObSCons*)params);
      }
      // => (f (params) body)
      ObSCons* lambda = CONS(S_LAMBDA, CONS(params, body));
      return [self expandToken: CONS(S_DEFINE, CONS(lambdaName, CONS(lambda, C_NULL)))];

    } else {
      [ObjScheme assertSyntax: [defineSpec isMemberOfClass: [ObSSymbol class]]
                    elseRaise: @"define second param must be symbol"];
      id expression = CAR(body);
      return CONS(S_DEFINE, CONS(defineSpec, CONS([self expandToken: expression], C_NULL)));
    }

  } else if ( head == S_DEFINEMACRO ) { // (define-macro symbol proc) or (define-macro (symbol args) body)
    [ObjScheme assertSyntax: topLevel elseRaise: @"define-macro must be invoked at the top level"];
    [ObjScheme assertSyntax: (length == 3) elseRaise: @"bad define-macro syntax"];

    id nameOrSpec = CADR(list);
    id body = CADDR(list);
    body = [self expandToken: body];
    ObSSymbol* macroName = nil;

    if ( [nameOrSpec isKindOfClass: [ObSSymbol class]] ) {
      macroName = nameOrSpec;

    } else {
      [ObjScheme assertSyntax: [nameOrSpec isKindOfClass: [ObSCons class]] elseRaise: @"bad define-macro spec"];
      ObSCons* callSpec = nameOrSpec;
      macroName = CAR(callSpec);
      id args = CDR(callSpec);
      id lambdaArgSpec = EMPTY(args) && CAR((ObSCons*)args) == S_DOT ? CADR((ObSCons*)args) : args;
      body = CONS(S_LAMBDA, CONS(lambdaArgSpec, body));
    }

    id<ObSProcedure> procedure = [[self globalScope] evaluate: body named: macroName];
    [ObjScheme assertSyntax: [procedure conformsToProtocol: @protocol(ObSProcedure)]
                  elseRaise: @"body of define-macro must be an invocation"];
    [[self globalScope] defineMacroNamed: macroName asProcedure: procedure];

    return UNSPECIFIED;

  } else if ( head == S_BEGIN ) {
    if ( length == 1 ) { // (begin) => nil
      return C_NULL;

    } else {
      return CONS(S_BEGIN, [self expandTokenList: CDR(list) atTopLevel: topLevel]);
    }

  } else if ( head == S_LET || head == S_LET_STAR ) {
    // (let ((x e1) (y e2)) body...)
    // -or-
    // (let name ((x e1) (y e2)) body)
    // we special-case this so as not to accidentally try to expand the symbol names

    BOOL isNamed = [CADR(list) isKindOfClass: [ObSSymbol class]];
    if ( isNamed ) {
      ObSSymbol* name = CADR(list);
      ObSCons* definitions = CADDR(list);
      ObSCons* body = CDDDR(list);
      return CONS(head, CONS(name, CONS([self expandLetDefinitions: definitions], [self expandTokenList: body])));

    } else {
      ObSCons* definitions = CADR(list);
      ObSCons* body = CDDR(list);
      return CONS(head, CONS([self expandLetDefinitions: definitions], [self expandTokenList: body]));
    }

  } else if ( head == S_LAMBDA ) {
    // (lambda (x) a b) => (lambda (x) (begin a b))
    // (lambda x expr) => (lambda (x) expr)
    [ObjScheme assertSyntax: (length >= 3) elseRaise: @"not enough args for lambda"];
    id parameters = CADR(list);
    if ( [parameters isKindOfClass: [ObSCons class]] ) {
      for ( id paramName in (ObSCons*)parameters ) {
        [ObjScheme assertSyntax: [paramName isKindOfClass: [ObSSymbol class]] elseRaise: [NSString stringWithFormat: @"invalid lambda parameter %@ in %@", paramName, parameters]];
      }

    } else {
      [ObjScheme assertSyntax: EMPTY(parameters) || [parameters isKindOfClass: [ObSSymbol class]] elseRaise: [NSString stringWithFormat: @"invalid lambda parameter %@", parameters]];
    }

    ObSCons* body = CDDR(list);
    id expression = [self expandToken: ([body count] == 1 ? CAR(body) : CONS(S_BEGIN, body))];

    return CONS(S_LAMBDA, CONS(parameters, CONS(expression, C_NULL)));

  } else if ( head == S_QUASIQUOTE ) {
    [ObjScheme assertSyntax: (length == 2) elseRaise: @"invalid quasiquote, wrong arg num"];
    return [ObjScheme expandQuasiquote: CADR(list)];

  } else if ( [head isKindOfClass: [ObSSymbol class]] ) {
    ObSSymbol* symbol = head;
    id macro = [[self globalScope] macroNamed: symbol];
    if ( macro ) {
      ObSCons* args = CDR(list);
      return [self expandToken: [macro callWith: args]];
    }
  }

  return [self expandTokenList: list];
}

+ (id)filter:(id)list with:(id<ObSProcedure>)proc {
  if ( EMPTY(list) ) {
    return C_NULL;

  } else {
    ObSCons* cell = list;
    if ( [proc callWith: CONS(CAR(cell), C_NULL)] != B_FALSE ) {
      return CONS(CAR(cell), [self filter: CDR(cell) with: proc]);

    } else {
      return [self filter: CDR(cell) with: proc];
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

    id first = CAR(list);
    [ObjScheme assertSyntax: (first != S_UNQUOTESPLICING) elseRaise: @"can't splice at beginning of quasiquote"];
    ObSCons* remainderOfList = CDR(list);

    if ( first == S_UNQUOTE ) {
      [ObjScheme assertSyntax: (length == 2) elseRaise: @"invalid unquote phrase, missing operand"];
      return CADR(list);

    } else if ( [first isKindOfClass: [ObSCons class]] && CAR((ObSCons*)first) == S_UNQUOTESPLICING ) {
      ObSCons* unquoteSplicingSpec = first;
      [ObjScheme assertSyntax: ([ObjScheme listLength: unquoteSplicingSpec] == 2) elseRaise: @"invalid unquote-splicing phrase, missing operand"];
      return CONS(S_APPEND, CONS(CADR(unquoteSplicingSpec), CONS([ObjScheme expandQuasiquote: remainderOfList], C_NULL)));

    } else {
      return CONS(S_CONS, CONS([ObjScheme expandQuasiquote: first], CONS([ObjScheme expandQuasiquote: remainderOfList], C_NULL)));
    }
  }
}

- (void)loadFile:(NSString*)filename {
  [self loadFile: filename intoScope: [self globalScope]];
}

- (void)loadFile:(NSString*)filename intoScope:(ObSScope*)scope {
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

- (void)loadSource:(NSString*)source intoScope:(ObSScope*)scope {
  ObSInPort* port = [[ObSInPort alloc] initWithString: source];
  [self loadInPort: port intoScope: scope forFilename: nil];
  [port release];
}

- (void)loadInPort:(ObSInPort*)port intoScope:(ObSScope*)scope forFilename:(NSString*)filename {
  id token = [self parseOneToken: port];

  while ( token != _EOF ) {
    [scope evaluate: token named: nil];
    token = [self parseOneToken: port];
  }

  if ( filename ) {
    [scope recordFilenameLoaded: filename];
  }
}

/**
 * read a program, then expand and error-check it
 */
- (id)parseOneToken:(ObSInPort*)inPort {
  return [self expandToken: [ObjScheme read: inPort] atTopLevel: YES];
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
          [lastCons setCdr: cell];
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

- (id)parseString:(NSString*)string {
  return [self parseOneToken: [[[ObSInPort alloc] initWithString: string] autorelease]];
}


+ (void)assertSyntax:(BOOL)correct elseRaise:(NSString*)message {
  if ( ! correct ) {
    [NSException raise: @"SyntaxError" format: @"%@", message];
  }
}

id srfi1_remove( id<ObSProcedure> predicate, ObSCons* list) {
  if ( EMPTY(list) ) {
    return C_NULL;
  }

  id item = CAR(list);
  id predicateReturn = [predicate callWithSingleArg: item];

  if ( predicateReturn == B_FALSE ) {
    return CONS(item, srfi1_remove(predicate, CDR(list)));

  } else {
    return srfi1_remove(predicate, CDR(list));
  }
}

- (void)addGlobalsToScope:(ObSScope*)scope {
  [scope define: SY(@"+inf.0") as: INF];

  [scope defineFunction: [ObSNativeLambda named: SY(@"+")
                                      fromBlock: ^(ObSCons* list) {
        if ( [list count] == 0 ) {
          return [NSNumber numberWithInteger: 0];
        }

        int intRet = 0;
        double doubleRet = 0.0;
        BOOL useDouble = NO;

        for ( NSNumber* n in list ) {
          if ( n == INF ) {
            return INF;
          }

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

      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"-")
                                      fromBlock: ^(ObSCons* list) {
        NSNumber* first = CAR(list);
        NSNumber* second = CADR(list);
        if ( first == INF || second == INF ) {
          return INF;
        }

        if ( strcmp([first objCType], @encode(int)) == 0 ) {
          return [NSNumber numberWithInteger: [first intValue]-[second intValue]];

        } else {
          return [NSNumber numberWithDouble: [first doubleValue]-[second doubleValue]];
        }
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"*")
                                      fromBlock: ^(ObSCons* list) {
        if ( EMPTY(list) ) {
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
                                      fromBlock: ^(ObSCons* list) {
        NSNumber* first = CAR(list);
        NSNumber* second = CADR(list);

        if ( [second floatValue] == 0.0 ) {
          return INF;
        }

        if ( [first floatValue] == 0.0 ) {
          return first;
        }

        return [NSNumber numberWithDouble: [first doubleValue] / [second doubleValue]];
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"safe-divide")
                                      fromBlock: ^(ObSCons* list) {
        NSNumber* first = CAR(list);
        NSNumber* second = CADR(list);

        if ( [second floatValue] == 0.0 ) {
          return INF;
        }

        if ( [first floatValue] == 0.0 ) {
          return first;
        }

        return [NSNumber numberWithDouble: [first doubleValue] / [second doubleValue]];
      }]];


  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"not")
                                                 fromBlock: ^(id object) { return object == B_FALSE ? B_TRUE : B_FALSE; }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@">")
                                      fromBlock: ^(ObSCons* list) {
        NSNumber* first = CAR(list);
        NSNumber* second = CADR(list);
        return [first doubleValue] > [second doubleValue] ? B_TRUE : B_FALSE;
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"<")
                                      fromBlock: ^(ObSCons* list) {
        NSNumber* first = CAR(list);
        NSNumber* second = CADR(list);
        return [first doubleValue] < [second doubleValue] ? B_TRUE : B_FALSE;
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@">=")
                                      fromBlock: ^(ObSCons* list) {
        NSNumber* first = CAR(list);
        NSNumber* second = CADR(list);
        return [first doubleValue] >= [second doubleValue] ? B_TRUE : B_FALSE;
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"<=")
                                      fromBlock: ^(ObSCons* list) {
        NSNumber* first = CAR(list);
        NSNumber* second = CADR(list);
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
        if ( EMPTY(o) ) {
          return B_TRUE;

        } else if ( [o isKindOfClass: [ObSCons class]] ) {
          ObSCons* cons = o;
          id cdr = CDR(cons);
          return TRUTH(EMPTY(cdr) || [cdr isKindOfClass: [ObSCons class]]);

        } else {
          return B_FALSE;
        }
      }]];

  [scope defineFunction: U_LAMBDA(@"null?", ^(id o) { return TRUTH(EMPTY(o)); })];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"last")
                                            fromBlock: ^(id list) {
        if ( EMPTY(list) ) {
          return [ObjScheme boolToTruth: NO];
        }

        ObSCons* tail = list;
        id item = CAR(tail);

        while ( CDR(tail) != C_NULL ) {
          tail = CDR(tail);
          item = CAR(tail);
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
        return CAR(cons);
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"cdr")
                                           fromBlock: ^(id o) {
        NSAssert1([o isKindOfClass: [ObSCons class]], @"invalid operand for car %@", o);
        ObSCons* cons = o;
        return CDR(cons);
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"cadr")
                                           fromBlock: ^(id o) {
        NSAssert1([o isKindOfClass: [ObSCons class]], @"invalid operand for car %@", o);
        ObSCons* cons = o;
        return CADR(cons);
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"caddr")
                                           fromBlock: ^(id o) {
        NSAssert1([o isKindOfClass: [ObSCons class]], @"invalid operand for car %@", o);
        ObSCons* cons = o;
        return CADDR(cons);
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"cddr")
                                           fromBlock: ^(id o) {
        NSAssert1([o isKindOfClass: [ObSCons class]], @"invalid operand for car %@", o);
        ObSCons* cons = o;
        return CDDR(cons);
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"cdddr")
                                           fromBlock: ^(id o) {
        NSAssert1([o isKindOfClass: [ObSCons class]], @"invalid operand for car %@", o);
        ObSCons* cons = o;
        return CDDDR(cons);
      }]];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"length")
                                           fromBlock: ^(id o) {
        if ( EMPTY(o) ) {
          return [NSNumber numberWithInteger: 0];
        }

        NSAssert1([o isKindOfClass: [ObSCons class]], @"invalid operand for length, should be list %@", o);
        int length = 0;
        id cell = o;
        while ( cell != C_NULL ) {
          NSAssert([o isKindOfClass: [ObSCons class]], @"length called on non-list, %@", o);
          length++;
          ObSCons* cons = cell;
          cell = CDR(cons);
        }
        return [NSNumber numberWithInteger: length];
      }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"remove")
                                            fromBlock: ^(id a, id b) {
        return srfi1_remove(a, b);
      }]];

  [scope defineFunction: U_LAMBDA(@"symbol?", ^(id o) { return TRUTH([o isKindOfClass: [ObSSymbol class]]); })];
  [scope defineFunction: U_LAMBDA(@"boolean?", ^(id o) { return TRUTH(o == B_TRUE || o == B_FALSE); })];

  [scope defineFunction: [ObSNativeUnaryLambda named: SY(@"pair?")
                                           fromBlock: ^(id o) {
        if ( EMPTY(o) || ! [o isKindOfClass: [ObSCons class]] ) {
          return B_FALSE;

        } else {
          // if anything down the path isn't a CONS or null, then yeah
          ObSCons* cons = o;

          while ( 1 ) {
            o = CDR(cons);

            if ( EMPTY(o) ) {
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

  [scope defineFunction: U_LAMBDA(@"number?", ^(id o) { return TRUTH([o isKindOfClass: [NSNumber class]] && o != (id)kCFBooleanFalse && o != (id)kCFBooleanTrue); })];
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
                                      fromBlock: ^(ObSCons* strings) {
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
        // this should *really* enforce that 'sep' is a character, not a string, but it's all Doug's fault.
        return [ObjScheme list: [(NSString*)string componentsSeparatedByString: sep]];
      }]];

  [scope defineFunction: U_LAMBDA(@"inexact->exact", ^(id o) { return [NSNumber numberWithInteger: [(NSNumber*)o intValue]]; })];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"map")
                                            fromBlock: ^(id proc, id args) {
        NSAssert1( [proc conformsToProtocol: @protocol(ObSProcedure)], @"map: proc is %@", proc );
        NSAssert1( EMPTY(args) || [args isKindOfClass: [ObSCons class]], @"map: args is '%@'", args );
        return [ObjScheme map: (id<ObSProcedure>)proc on: (ObSCons*)args];
      }]];

  [scope defineFunction: U_LAMBDA(@"display", ^(id x) { NSLog(@"%@", x); return B_FALSE; })];

  [scope defineFunction: [ObSNativeLambda named: SY(@"newline")
                                      fromBlock: ^(ObSCons* array) {
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
                                      fromBlock: ^(ObSCons* args) {
        NSString* string = CAR(args);
        NSInteger firstIdx = [(NSNumber*)CADR(args) intValue];
        if ( firstIdx < 0 ) {
          firstIdx = [string length] + firstIdx; // + is right, it's negative
        }

        if ( CDDR(args) != C_NULL ) {
          NSInteger secondIdx = [(NSNumber*)CADDR(args) integerValue];
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
                                      fromBlock: ^(ObSCons* args) {
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
                                      fromBlock: ^(ObSCons* args) {
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
                                      fromBlock: ^(ObSCons* args) {
        int size = [(NSNumber*)CAR(args) intValue];
        NSMutableArray* vector = [NSMutableArray arrayWithCapacity: size];

        id fill = UNSPECIFIED;
        if ( CDR(args) != C_NULL ) {
          fill = CADR(args);
        }

        for ( int i = 0; i < size; i++ ) {
          [vector addObject: fill];
        }

        return vector;
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"vector")
                                      fromBlock: ^(ObSCons* args) {
        return [args toMutableArray];
      }]];

         [scope defineFunction: U_LAMBDA(@"vector-length", ^(id a) { return [NSNumber numberWithInteger: [(NSArray*)a count]]; })];

  [scope defineFunction: U_LAMBDA(@"vector?", ^(id a) { return TRUTH([a isKindOfClass: [NSArray class]]); })];

         [scope defineFunction: U_LAMBDA(@"vector->list", ^(id a) { return [ObjScheme list: (NSArray*)a]; })];
         [scope defineFunction: U_LAMBDA(@"list->vector", ^(id a) { if ( EMPTY(a) ) { return (id)[NSArray array]; } else { return (id)[(ObSCons*)a toArray]; } })];
  [scope defineFunction: B_LAMBDA(@"vector-ref", ^(id a, id b) { return [(NSArray*)a objectAtIndex: [(NSNumber*)b intValue]]; })];
  [scope defineFunction: [ObSNativeLambda named: SY(@"vector-set!")
                                      fromBlock: ^(ObSCons* args) {
        NSMutableArray* vector = CAR(args);
        int index = [(NSNumber*)CADR(args) intValue];
        id value = CADDR(args);
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
          if ( EMPTY(ret) ) {
            // this is just the first iteration, where we create the 1-length sublist
            ret = soFar = CONS(CAR(list), C_NULL);

          } else {
            // from then on, we're tracking the last CONS cell, and mutating it.
            ObSCons* nextCell = CONS(CAR(list), C_NULL);
            [soFar setCdr: nextCell];
            soFar = nextCell;
          }
          // pop!
          list = CDR(list);
        }

        return ret;
      }]];

  [scope defineFunction: U_LAMBDA(@"vector->immutable-vector", ^(id a) { return [NSArray arrayWithArray: (NSArray*)a]; })];
  [scope defineFunction: U_LAMBDA(@"immutable?", ^(id a) { return TRUTH([a isKindOfClass: [NSString class]] || ( [a isKindOfClass: [NSArray class]] && ! [a isKindOfClass: [NSMutableArray class]] )); })];
  [scope defineFunction: [ObSNativeLambda named: SY(@"vector-immutable")
                                      fromBlock: ^(ObSCons* params) {
        return [NSArray arrayWithArray: [params toArray]];
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
          for ( id item in list ) {
            [proc callWithSingleArg: item];
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
                                      fromBlock: ^(ObSCons* args) {
        if ( EMPTY(args) ) {
          return (id)args;
        }
        return appendListsToList(CDR(args), CAR(args));
      }]];

  [[self globalScope] defineFunction: [ObSNativeLambda named: SY(@"find-match")
                                                        fromBlock: ^(ObSCons* args) {
        id<ObSProcedure> testFunction = CAR(args);
        NSArray* inputArray = CADR(args);

        id ret = B_FALSE;

        for ( id item in inputArray ) {
          if ( [testFunction callWithSingleArg: item] != B_FALSE ) {
            ret = item;
            break;
          }
        }

        return ret;
      }]];

  [[self globalScope] defineFunction: [ObSNativeLambda named: SY(@"find-matches")
                                                        fromBlock: ^(ObSCons* args) {
        id<ObSProcedure> testFunction = CAR(args);
        NSArray* inputArray = CADR(args);

        NSMutableArray* ret = [NSMutableArray array];

        for ( id item in inputArray ) {
          if ( [testFunction callWithSingleArg: item] != B_FALSE ) {
            [ret addObject: item];
          }
        }

        return (id)ret;
      }]];
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
