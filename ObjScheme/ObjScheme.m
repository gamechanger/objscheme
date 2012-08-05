//
//  ObjScheme.m
//  ObjScheme
//
//  Created by Kiril Savino on 7/30/12.
//  Copyright (c) 2012 GameChanger. All rights reserved.
//

#import "ObjScheme.h"

static ObSSymbol* S_DOT;
static ObSSymbol* S_QUOTE;
static ObSSymbol* S_IF;
static ObSSymbol* S_SET;
static ObSSymbol* S_DEFINE;
static ObSSymbol* S_LAMBDA;
static ObSSymbol* S_BEGIN;
static ObSSymbol* S_DEFINEMACRO;
static ObSSymbol* S_QUASIQUOTE;
static ObSSymbol* S_UNQUOTE;
static ObSSymbol* S_UNQUOTESPLICING;
static ObSSymbol* S_APPEND;
static ObSSymbol* S_CONS;
static ObSSymbol* S_LET;
static ObSSymbol* S_LET_STAR;
static ObSSymbol* S_OPENPAREN;
static ObSSymbol* S_CLOSEPAREN;
static ObSSymbol* S_LIST;
static ObSSymbol* S_EVAL;
static ObSSymbol* S_MAP;

static ObSConstant* B_FALSE;
static ObSConstant* B_TRUE;

static ObSConstant* C_NULL;

static ObSConstant* UNSPECIFIED;

static NSString* _EOF = @"#EOF#";

#define B_LAMBDA(name, block) [ObSNativeBinaryLambda named: SY(name) fromBlock: (block)]
#define U_LAMBDA(name, block) [ObSNativeUnaryLambda named: SY(name) fromBlock: (block)]
#define TRUTH(b) ((b) ? B_TRUE : B_FALSE)
#define IF(x) ((x) != B_FALSE)
#define CONS(x,y) [[[ObSCons alloc] initWithCar: (x) cdr: (y)] autorelease]
#define ISINT(n) (strcmp([(n) objCType], @encode(int)) == 0)
#define ISDOUBLE(n) (strcmp([(n) objCType], @encode(double)) == 0)
#define CONST(s) [[ObSConstant alloc] initWithName: (s)]

@interface ObjScheme ()

+ (id)atomFromToken:(NSString*)token;
+ (NSString*)unpackStringLiteral:(NSString*)string;
+ (id)expandToken:(id)token atTopLevel:(BOOL)topLevel;
+ (BOOL)isEmptyList:(id)token;
+ (void)assertSyntax:(BOOL)correct elseRaise:(NSString*)message;
+ (id)expandQuasiquote:(id)token;
+ (void)addGlobalsToScope:(ObSScope*)scope;

@end




// ------ ObjScheme top-level

@implementation ObjScheme

static NSDictionary* __constants = nil;
static ObSScope* __globalScope = nil;

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
  S_OPENPAREN =       SY(@"(");
  S_CLOSEPAREN =      SY(@")");
  S_LIST =            SY(@"list");
  S_EVAL =            SY(@"eval");
  S_MAP =             SY(@"map");

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
}

- (NSArray*)mapProcedure:(id<ObSProcedure>)procedure onArray:(NSArray*)array {
  NSMutableArray* ret = [NSMutableArray arrayWithCapacity: [array count]];
  for ( id thing in array ) {
    [ret addObject: [procedure invokeWithArguments: [NSArray arrayWithObject: thing]]];
  }
  return ret;
}

+ (ObSScope*)globalScope {
  if ( __globalScope == nil ) {
    __globalScope = [[ObSScope alloc] initWithOuterScope: nil];
    [__globalScope bootstrapMacros];
    [ObjScheme addGlobalsToScope: __globalScope];
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
  if ( [string hasPrefix: @"\""] )
    return [ObjScheme unpackStringLiteral: string];

  NSRange dotLocation = [string rangeOfString: @"."];
  if ( dotLocation.location == NSNotFound ) {
    int intValue = [string intValue];
    if ( intValue != 0 ) { // note that the literal '0' is handled in constants above
      return [NSNumber numberWithInteger: intValue];
    }
  }

  double doubleValue = [string doubleValue];
  if ( doubleValue != 0.0 ) // note that the literal '0.0' is handle in constants above
    return [NSNumber numberWithDouble: doubleValue];

  return [ObSSymbol symbolFromString: string];
}

+ (BOOL)isEmptyList:(id)token {
  if ( ! [token isKindOfClass: [NSArray class]] )
    return NO;
  NSArray* array = token;
  return [array count] == 0;
}

/**
 * Traverses a scope/token, doing basic syntax validation and expanding shortened forms.
 * @param  token     The token to expand & validate.
 * @param  topLevel  Whether this is the top-level scope.
 */
+ (id)expandToken:(id)token atTopLevel:(BOOL)topLevel {
  [ObjScheme assertSyntax: ! [ObjScheme isEmptyList: token] elseRaise: @"Empty list is not a program"];

  if ( ! [token isKindOfClass: [NSArray class]] ) {
    return token; // an atom
  }

  NSArray* array = token;
  id head = [array objectAtIndex: 0];

  if ( head == S_QUOTE ) { // (quote exp)
    [ObjScheme assertSyntax: ([array count] == 2)
                  elseRaise: [NSString stringWithFormat: @"quote should have 1 arg, given %d", [array count]-1]];
    return array;

  } else if ( head == S_IF ) { // (if x y) => (if x y #f)
    if ( [array count] == 3 ) { // (if x y)
      NSMutableArray* longer = [NSMutableArray arrayWithArray: array];
      [longer addObject: B_FALSE];
      array = longer;
    }

    [ObjScheme assertSyntax: ([array count] == 4) elseRaise: @"Invalid 'if' syntax"];
    NSMutableArray* ret = [NSMutableArray arrayWithCapacity: [array count]];
    for ( id subToken in array ) {
      [ret addObject: [ObjScheme expandToken: subToken atTopLevel: NO]];
    }
    return ret;

  } else if ( head == S_SET ) { // (set! thing exp)
    [ObjScheme assertSyntax: ([array count] == 3) elseRaise: @"Invalid 'set!' syntax"];
    id var = [array objectAtIndex: 1];
    [ObjScheme assertSyntax: [var isMemberOfClass: [ObSSymbol class]]
                  elseRaise: @"First arg of 'set!' should be a Symbol"];
    id expression = [ObjScheme expandToken: [array objectAtIndex: 2] atTopLevel: NO];
    return [NSArray arrayWithObjects: S_SET, var, expression, nil];

  } else if ( head == S_DEFINE ) { // (define ...)
    [ObjScheme assertSyntax: ([array count] >= 3) elseRaise: @"define takes at least 2 args"];
    id defineSpec = [array objectAtIndex: 1];
    NSArray* body = [array subarrayWithRange: NSMakeRange(2, [array count]-2)];

    if ( [defineSpec isKindOfClass: [NSArray class]] ) {
      // we're going to change (define (f args) body) => (define f (lambda (args) body)) for simplicity
      NSArray* lambdaSpec = defineSpec;
      NSString* lambdaName = [lambdaSpec objectAtIndex: 0];
      NSArray* lambdaParameterNames = [lambdaSpec subarrayWithRange: NSMakeRange(1, [lambdaSpec count]-1)];
      // => (f (params) body)
      NSMutableArray* lambdaDefinition = [NSMutableArray arrayWithObjects: S_LAMBDA, lambdaParameterNames, nil];
      [lambdaDefinition addObjectsFromArray: body];
      return [ObjScheme expandToken: [NSArray arrayWithObjects: S_DEFINE, lambdaName, lambdaDefinition, nil]
                         atTopLevel: NO];

    } else {
      [ObjScheme assertSyntax: [defineSpec isMemberOfClass: [ObSSymbol class]]
                    elseRaise: @"define second param must be symbol"];
      id expression = [body lastObject];
      return [NSArray arrayWithObjects: S_DEFINE, defineSpec, [ObjScheme expandToken: expression atTopLevel: NO], nil];
    }

  } else if ( head == S_DEFINEMACRO ) { // (define-macro symbol proc)
    [ObjScheme assertSyntax: topLevel elseRaise: @"define-macro must be invoked at the top level"];
    [ObjScheme assertSyntax: ([array count] == 3) elseRaise: @"bad define-macro syntax"];
    ObSSymbol* macroName = [array objectAtIndex: 1];
    id body = [ObjScheme expandToken: [array lastObject] atTopLevel: NO];
    id<ObSProcedure> procedure = [[ObjScheme globalScope] evaluate: body];
    [ObjScheme assertSyntax: [procedure conformsToProtocol: @protocol(ObSProcedure)]
                  elseRaise: @"body of define-macro must be an invocation"];
    [[ObjScheme globalScope] defineMacroNamed: macroName asProcedure: procedure];
    return nil;

  } else if ( head == S_BEGIN ) {
    if ( [array count] == 1 ) { // (begin) => nil
      return nil;

    } else {
      NSMutableArray* ret = [NSMutableArray arrayWithCapacity: [array count]];
      for ( id subToken in array ) {
        id expanded = [ObjScheme expandToken: subToken atTopLevel: topLevel];
        if ( expanded != nil ) // define-macro expands to nil
          [ret addObject: expanded];
      }
      return ret;
    }

  } else if ( head == S_LAMBDA ) {
    // (lambda (x) a b) => (lambda (x) (begin a b))
    // (lambda x expr) => (lambda (x) expr)
    [ObjScheme assertSyntax: ([array count] >= 3) elseRaise: @"not enough args for lambda"];
    NSArray* parameterList = nil;
    id parameterToken = [array objectAtIndex: 1];
    if ( [parameterToken isKindOfClass: [NSArray class]] ) {
      parameterList = parameterToken;
    } else {
      parameterList = [NSArray arrayWithObject: parameterToken];
    }

    for ( id paramName in parameterList ) {
      [ObjScheme assertSyntax: [paramName isKindOfClass: [ObSSymbol class]] elseRaise: @"invalid lambda argument"];
    }

    NSArray* body = [array subarrayWithRange: NSMakeRange(2, [array count]-2)];
    id expression;
    if ( [body count] == 1 ) {
      expression = [ObjScheme expandToken: [body lastObject] atTopLevel: NO];

    } else {
      NSMutableArray* newBody = [[NSMutableArray alloc] initWithArray: body];
      [newBody insertObject: S_BEGIN atIndex: 0];
      expression = [ObjScheme expandToken: newBody atTopLevel: NO];
      [newBody release];
    }

    return [NSArray arrayWithObjects: S_LAMBDA, parameterList, expression, nil];

  } else if ( head == S_QUASIQUOTE ) {
    [ObjScheme assertSyntax: ([array count] == 2) elseRaise: @"invalid quasiquote, wrong arg num"];
    return [ObjScheme expandQuasiquote: [array objectAtIndex: 1]];

  } else if ( [head isKindOfClass: [ObSSymbol class]] ) {
    ObSSymbol* symbol = head;
    if ( [[ObjScheme globalScope] hasMacroNamed: symbol] ) {
      id macro = [[ObjScheme globalScope] macroNamed: symbol];
      NSArray* macroArguments = [array subarrayWithRange: NSMakeRange(1, [array count]-1)];
      return [ObjScheme expandToken: [macro invokeWithArguments: macroArguments] atTopLevel: NO];
    }
  }

  NSMutableArray* ret = [NSMutableArray arrayWithCapacity: [array count]];
  for ( id subToken in array ) {
    [ret addObject: [ObjScheme expandToken: subToken atTopLevel: NO]];
  }
  return ret;
}

+ (id)map:(id<ObSProcedure>)proc on:(id)list {
  if ( list == C_NULL ) {
    return C_NULL;

  } else {
    ObSCons* cons = list;
    NSArray* args = [NSArray arrayWithObject: cons.car];
    return CONS([proc invokeWithArguments: args], [self map: proc on: cons.cdr]);
  }
}

+ (id)filterList:(id)list with:(id<ObSProcedure>)proc {
  if ( list == C_NULL ) {
    return C_NULL;

  } else {
    ObSCons* cell = list;
    NSArray* args = [NSArray arrayWithObject: cell.car];
    if ( [proc invokeWithArguments: args] != B_FALSE ) {
      return CONS(cell.car, [self filterList: cell.cdr with: proc]);

    } else {
      return [self filterList: cell.cdr with: proc];
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

+ (id)quote:(id)token {
  if ( [token isKindOfClass: [NSArray class]] ) {
    NSArray* tokens = token;
    NSMutableArray* quoted = [NSMutableArray arrayWithCapacity: [tokens count]];
    for ( id token in tokens ) {
      [quoted addObject: [self quote: token]];
    }
    return [self list: quoted];

  } else {
    return token;
  }
}

+ (id)quoted:(id)token {
  return [NSArray arrayWithObjects: S_QUOTE, token, nil];
}

/**
 * `x => 'x
 * `,x => x
 * `(,@x y)
 */
+ (id)expandQuasiquote:(id)token {
  if ( ! [token isKindOfClass: [NSArray class]] ) {
    return [self quoted: token];

  } else {
    NSArray* list = token;
    if ( [list count] == 0 )
      return [self quoted: list];

    id first = [list objectAtIndex: 0];
    [ObjScheme assertSyntax: (first != S_UNQUOTESPLICING) elseRaise: @"can't splice at beginning of quasiquote"];
    NSArray* remainderOfList = [list subarrayWithRange: NSMakeRange(1, [list count]-1)];

    if ( first == S_UNQUOTE ) {
      [ObjScheme assertSyntax: ([list count] == 2) elseRaise: @"invalid unquote phrase, missing operand"];
      return [list lastObject];

    } else if ( [first isKindOfClass: [NSArray class]] && [(NSArray*)first objectAtIndex: 0] == S_UNQUOTESPLICING ) {
      NSArray* unquoteSplicingSpec = first;
      [ObjScheme assertSyntax: ([unquoteSplicingSpec count] == 2) elseRaise: @"invalid unquote-splicing phrase, missing operand"];
      return [NSArray arrayWithObjects: S_APPEND,
                      [unquoteSplicingSpec objectAtIndex: 1],
                      [ObjScheme expandQuasiquote: remainderOfList], nil];

    } else {
      return [NSArray arrayWithObjects: S_CONS,
                      [ObjScheme expandQuasiquote: first],
                      [ObjScheme expandQuasiquote: remainderOfList], nil];
    }
  }
}

/**
 * read a program, then expand and error-check it
 */
+ (id)parse:(ObSInPort*)inPort {
  return [ObjScheme expandToken: [ObjScheme read: inPort] atTopLevel: YES];
}

+ (id)readAheadFromToken:(id)token andPort:(ObSInPort*)inPort {
  if ( token == S_OPENPAREN ) {
    NSMutableArray* list = [NSMutableArray array];

    while ( 1 ) {
      token = [inPort nextToken];
      if ( token == S_CLOSEPAREN ) {
        break;

      } else {
        [list addObject: [ObjScheme readAheadFromToken: token andPort: inPort]];
      }
    }

    return list;

  } else if ( token == S_CLOSEPAREN ) {
    [NSException raise: @"SyntaxError" format: @"unexpected ')'"];
    return nil;

  } else if ( token == S_QUOTE || token == S_QUASIQUOTE || token == S_UNQUOTE || token == S_UNQUOTESPLICING ) {
    return [NSArray arrayWithObjects: token, [ObjScheme read: inPort], nil];

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
  return [ObjScheme parse: [[[ObSInPort alloc] initWithString: string] autorelease]];
}


+ (void)assertSyntax:(BOOL)correct elseRaise:(NSString*)message {
  if ( ! correct )
    [NSException raise: @"SyntaxError" format: message];
}

+ (void)addGlobalsToScope:(ObSScope*)scope {
  [scope defineFunction: [ObSNativeLambda named: SY(@"+")
                                      fromBlock: ^(NSArray* list) {
        if ( [list count] == 0 )
          return [NSNumber numberWithInteger: 0];

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
        if ( [list count] == 0 )
          return [NSNumber numberWithInteger: 0];

        NSNumber* first = [list objectAtIndex: 0];
        if ( strcmp([first objCType], @encode(int)) == 0 ) {
          int ret = 1;
          for ( NSNumber* number in list ) {
            ret *= [number intValue];
          }
          return [NSNumber numberWithInteger: ret];

        } else {
          double ret = 1.0;
          for ( NSNumber* number in list ) {
            ret *= [number doubleValue];
          }
          return [NSNumber numberWithDouble: ret];
        }
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"/")
                                      fromBlock: ^(NSArray* list) {
        NSNumber* first = [list objectAtIndex: 0];
        NSNumber* second = [list objectAtIndex: 1];
        if ( strcmp([first objCType], @encode(int)) == 0 && strcmp([second objCType], @encode(int)) == 0 ) {
          return [NSNumber numberWithInteger: [first intValue]/[second intValue]];

        } else {
          return [NSNumber numberWithDouble: [first doubleValue]/[second doubleValue]];
        }
      }]];

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
          return TRUTH([n1 isEqualToNumber: n2]);
        } else {
          return TRUTH([a isEqual: b]);
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
        id second = [cons cdr];
        NSAssert1([second isKindOfClass: [ObSCons class]], @"cadr requires cdr to be a cons, but it's %@", second);
        ObSCons* cons2 = second;
        return [cons2 car];
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

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"apply")
                                            fromBlock: ^(id a, id b) {
        id<ObSProcedure> procedure = a;
        ObSCons* arguments = b;
        return [procedure invokeWithArguments: [arguments toArray]];
      }]];

  [scope defineFunction: U_LAMBDA(@"symbol->string", ^(id o) { ObSSymbol* s = o; return s.string; })];
  [scope defineFunction: [ObSNativeLambda named: SY(@"string-append")
                                      fromBlock: ^(NSArray* strings) {
        NSMutableString* string = [NSMutableString string];
        for ( NSString* s in strings ) {
          [string appendString: s];
        }
        return string;
      }]];

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"map")
                                            fromBlock: ^(id a, id b) {
        id<ObSProcedure> proc = a;
        NSAssert1( [proc conformsToProtocol: @protocol(ObSProcedure)], @"proc is %@", proc );
        ObSCons* arguments = b;
        NSAssert1( [arguments isKindOfClass: [ObSCons class]], @"args is %@", arguments );
        return [ObjScheme map: proc on: arguments];
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

  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"filter")
                                            fromBlock: ^(id a, id b) {
        return [ObjScheme filterList: b with: a];
      }]];

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

  [scope defineFunction: U_LAMBDA(@"vector-length", ^(id a) { NSArray* arr = a; return [NSNumber numberWithInteger: [arr count]]; })];
  [scope defineFunction: U_LAMBDA(@"vector?", ^(id a) { return TRUTH([a isKindOfClass: [NSArray class]]); })];
  [scope defineFunction: U_LAMBDA(@"vector->list", ^(id a) { return [ObjScheme list: (NSArray*)a]; })];
  [scope defineFunction: U_LAMBDA(@"list->vector", ^(id a) { if ( a == C_NULL ) { return [NSArray array]; } else { return [(ObSCons*)a toArray]; } })];
  [scope defineFunction: B_LAMBDA(@"vector-ref", ^(id a, id b) {return [(NSArray*)a objectAtIndex: [(NSNumber*)b intValue]]; })];
  [scope defineFunction: [ObSNativeLambda named: SY(@"vector-set!")
                                      fromBlock: ^(NSArray* args) {
        NSMutableArray* vector = [args objectAtIndex: 0];
        int index = [(NSNumber*)[args objectAtIndex: 1] intValue];
        id value = [args objectAtIndex: 2];
        [vector replaceObjectAtIndex: index withObject: value];
        return UNSPECIFIED;
      }]];

  [scope defineFunction: U_LAMBDA(@"unspecified?", ^(id a) { return TRUTH(a == UNSPECIFIED); })];

  [scope defineFunction: U_LAMBDA(@"string?", ^(id x) { return TRUTH([x isKindOfClass: [NSString class]]); })];
  [scope defineFunction: [ObSNativeBinaryLambda named: SY(@"for-each")
                                            fromBlock: ^(id a, id b) {
        id<ObSProcedure> proc = a;
        ObSCons* list = b;
        for ( id item in list ) {
          [proc invokeWithArguments: [NSArray arrayWithObject: item]];
        }
        return UNSPECIFIED;
      }]];

  [scope defineFunction: U_LAMBDA(@"round", ^(id a) { return [NSNumber numberWithDouble: round([(NSNumber*)a doubleValue])]; })];

  // TODO: (lambda x ...) makes 'x' the LIST of args.
  // TODO:
  /*
    - (vector-fill! v thing)
    - (vector-copy! dest dest-start src [src-start src-end])
    - (vector->immutable-vector v)
    - (vector-immutable <things>)
    - (immutable?)
    - MAYBE I/O: load, read, write, read-char, open-input-file, close-input-port, open-output-file, close-output-port, eof-object?
    - port?
    - call/cc
   */

  /*
    MORE:
    - cond
    - error <= and replace Exceptions with (error) results which cause a return...? would that work...?
    - every
    - floor/ceiling
    - member? (member? thing list)
    - reduce (reduce combiner list)
    - write (and something for formatting properly...)
    - MAYBE: char (#\a) support?
   */
}

+ (BOOL)isFalse:(id)token {
  return token == B_FALSE;
}

@end





@implementation ObSSymbol

@synthesize string=_string;

+ (ObSSymbol*)symbolFromString:(NSString*)string {
  NSAssert( ! [string isEqual: @"#f"], @"no false fool");
  static NSMutableDictionary* __symbols = nil;
  if ( __symbols == nil ) {
    __symbols = [[NSMutableDictionary alloc] init];
  }

  ObSSymbol* symbol = [__symbols objectForKey: string];
  if ( symbol == nil ) {
    symbol = [[ObSSymbol alloc] initWithString: string];
    [__symbols setObject: symbol forKey: string];
    [symbol release];
  }

  return symbol;
}

- (id)initWithString:(NSString*)string {
  if ( ( self = [super init] ) ) {
    _string = [string retain];
  }
  return self;
}

- (void)dealloc {
  [_string release];
  [super dealloc];
}

- (BOOL)isEqual:(id)other {
  return other == self;
}

- (NSUInteger)hash {
  return [_string hash];
}

- (NSString*)description {
  return [NSString stringWithFormat: @"Symbol(%@)", _string];
}

@end





@implementation ObSScope

@synthesize outer=_outerScope;

- (id)initWithOuterScope:(ObSScope*)outer {
  if ( (self = [super init]) ) {
    self.outer = outer;
    _macros = [[NSMutableDictionary alloc] init];
    _environ = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)dealloc {
  [_outerScope release];
  [_macros release];
  [_environ release];
  [super dealloc];
}

- (id)initWithOuterScope:(ObSScope*)outer
    paramListNameOrNames:(id)parameters
               arguments:(NSArray*)arguments {

  if ( (self = [self initWithOuterScope: outer]) ) {
    if ( [parameters isKindOfClass: [NSArray class]] ) {
      NSArray* parameterList = parameters;
      NSArray* namedParameters = parameters;
      ObSSymbol* catchAllParameterName = nil;

      // support for variable arity (lambda (x y . z) ...)
      if ( [parameterList containsObject: S_DOT] ) {
        namedParameters = [parameterList subarrayWithRange: NSMakeRange(0, [parameterList count]-1)];
        catchAllParameterName = [parameterList lastObject];
      }

      int numNamed = [namedParameters count];
      int numArgs = [arguments count];
      NSAssert1( numArgs == numNamed || catchAllParameterName != nil && numArgs > numNamed,
                 @"Syntax Error: Wrong Number of Arguments %@", arguments );

      for ( int i = 0; i < numNamed; i++ ) {
        ObSSymbol* name = [namedParameters objectAtIndex: i];
        [_environ setObject: [arguments objectAtIndex: i]
                     forKey: name.string];
      }

      if ( numArgs > numNamed ) {
        int numRemaining = numArgs - numNamed;
        [_environ setObject: [arguments subarrayWithRange: NSMakeRange(numNamed, numRemaining)]
                     forKey: catchAllParameterName.string];
      }

    } else {
      NSAssert1( [parameters isKindOfClass: [NSString class]], @"Syntax Error(?): Parameters for scope is %@", parameters );
      [_environ setObject: arguments forKey: parameters];
    }
  }
  return self;
}

- (id)resolveSymbol:(ObSSymbol*)symbol {
  id myValue = [_environ objectForKey: symbol.string];
  if ( myValue ) {
    return myValue;
  }

  if ( _outerScope != nil ) {
    return [_outerScope resolveSymbol: symbol];
  }

  [NSException raise: @"LookupError" format: @"Symbol %@ not defined", symbol];
  return nil;
}

- (void)define:(ObSSymbol*)symbol as:(id)thing {
  [_environ setObject: thing forKey: symbol.string];
}

- (void)defineFunction:(id<ObSProcedure>)procedure {
  [self define: [procedure name] as: procedure];
}

- (void)bootstrapMacros {
  static NSString* macros = @"(begin\n"

    "(define-macro and (lambda args\n"
    "   (if (null? args) #t\n"
    "       (if (= (length args) 1) (car args)\n"
    "           `(if ,(car args) (and ,@(cdr args)) #f)))))\n"

    "(define-macro or\n"
    "  (lambda args\n"
    "    (if (null? args) #f\n"
    "        (let ((arg (car args)))\n"
    "          `(let ((arg ,arg))\n"
    "             (if arg arg\n"
    "                 (or ,@(cdr args))))))))\n"

    ";; More macros can also go here\n"
    ")";

  ObSScope* global = [ObjScheme globalScope];
  [global evaluate: [ObjScheme parseString: macros]];
}

- (id)evaluateArray:(NSArray*)array {
  NSMutableArray* ret = [NSMutableArray arrayWithCapacity: [array count]];
  for ( id thing in array ) {
    [ret addObject: [self evaluate: thing]];
  }
  return ret;
}

- (id)evaluate:(id)token {
  NSAssert(token != nil, @"nil token");

  @try {
    while ( 1 ) {
      if ( [token isKindOfClass: [ObSSymbol class]] ) {
        return [self resolveSymbol: token]; // variable reference

      } else if ( ! [token isKindOfClass: [NSArray class]] && ! [token isKindOfClass: [ObSCons class]] ) {
        return token; // literal

      } else {
        NSArray* list = nil;
        if ( [token isKindOfClass: [NSArray class]] ) {
          list = token;

        } else {
          // this is here so that we can support (eval)...
          ObSCons* cons = token;
          list = [cons toArray];
        }

        id head = [list objectAtIndex: 0];
        NSArray* rest = [list subarrayWithRange: NSMakeRange(1, [list count]-1)];

        if ( head == S_EVAL ) {
          NSAssert1([rest count] == 1, @"eval can have only 1 operand, not %@", rest);
          id program = [self evaluate: [rest objectAtIndex: 0]];
          return [self evaluate: program];

        } else if ( head == S_LET ) {
          NSLog( @"Let..." );
          NSArray* definitions = [rest objectAtIndex: 0];
          NSArray* body = [rest subarrayWithRange: NSMakeRange(1, [rest count]-1)];
          ObSScope* letScope = [[ObSScope alloc] initWithOuterScope: self];

          for ( NSArray* definition in definitions ) {
            ObSSymbol* name = [definition objectAtIndex: 0];
            id expression = [definition objectAtIndex: 1];
            NSLog( @"defining %@ in let", name );
            [letScope define: name as: [self evaluate: expression]];
          }

          id result = nil;
          for ( id expression in body ) {
            NSLog( @"evaluate %@", expression );
            result = [letScope evaluate: expression];
          }
          NSLog( @"Returning from Let..." );
          return result;

        } else if ( head == S_LET_STAR ) {
          NSArray* definitions = [rest objectAtIndex: 0];
          NSArray* body = [rest subarrayWithRange: NSMakeRange(1, [rest count]-1)];
          ObSScope* letScope = [[ObSScope alloc] initWithOuterScope: self];

          for ( NSArray* definition in definitions ) {
            ObSSymbol* name = [definition objectAtIndex: 0];
            id expression = [definition objectAtIndex: 1];
            [letScope define: name as: [letScope evaluate: expression]];
          }

          id result = nil;
          for ( id expression in body ) {
            result = [letScope evaluate: expression];
          }
          return result;

        } else if ( head == S_QUOTE ) { // (quote exp) -> exp
          NSAssert1([rest count] == 1, @"quote can have only 1 operand, not %@", rest);
          return [ObjScheme quote: [rest objectAtIndex: 0]];

        } else if ( head == S_LIST ) { // (list a b c)
          return [ObjScheme list: [self evaluateArray: rest]];

        } else if ( head == S_IF ) { // (if test consequence alternate) <- note that full form is enforced by expansion
          id test = [rest objectAtIndex: 0];
          id consequence = [rest objectAtIndex: 1];
          id alternate = [rest objectAtIndex: 2];
          token = [self evaluate: test] == B_FALSE ? alternate : consequence;
          continue; // I'm being explicit here for clarity, we'll now evaluate this token

        } else if ( head == S_SET ) { // (set! variableName expression)
          ObSSymbol* symbol = [rest objectAtIndex: 0];
          id expression = [rest objectAtIndex: 1];
          ObSScope* definingScope = [self findScopeOf: symbol]; // I do this first, which can fail, so we don't bother executing predicate
          id value = [self evaluate: expression];
          [definingScope define: symbol as: value];
          return UNSPECIFIED;

        } else if ( head == S_DEFINE ) { // (define variableName expression)
          NSString* variableName = [rest objectAtIndex: 0];
          id expression = [rest objectAtIndex: 1];
          [_environ setObject: [self evaluate: expression] forKey: variableName];

        } else if ( head == S_LAMBDA ) { // (lambda (argumentNames) body)
          NSArray* argumentNames = [rest objectAtIndex: 0];
          NSArray* body = [rest objectAtIndex: 1];
          return [[[ObSLambda alloc] initWithArgumentNames: argumentNames
                                                expression: body
                                                     scope: self
                                                      name: S_LAMBDA] autorelease];

        } else if ( head == S_BEGIN ) { // (begin expression...)
          id result = [NSNumber numberWithBool: NO];
          for ( id expression in rest ) {
            result = [self evaluate: expression];
          }
          return result; // begin evaluates to value of final expression

        } else {
          id<ObSProcedure> procedure = [self evaluate: head];
          return [procedure invokeWithArguments: [self evaluateArray: rest]];
        }
      }
    }

  } @catch ( NSException* e ) {
    NSLog( @"FAILED TO EVALUATE %@", token );
    [e raise];
  }
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




@implementation ObSLambda

@synthesize scope=_scope, expression=_expression, argumentNames=_argumentNames, name=_name;


- (id)initWithArgumentNames:(NSArray*)argumentNames
                 expression:(id)expression
                      scope:(ObSScope*)scope
                       name:(ObSSymbol*)name {

  if ( (self = [self init]) ) {
    _argumentNames = [argumentNames retain];
    _expression = [expression retain];
    _scope = [scope retain];
    _name = [name retain];
  }

  return self;
}

- (void)dealloc {
  [_argumentNames release];
  [_expression release];
  [_scope release];
  [_name release];
  [super dealloc];
}

- (ObSSymbol*)name {
  return (_name == nil ? S_LAMBDA : _name);
}


- (id)invokeWithArguments:(NSArray*)arguments {
  ObSScope* invocationScope = [[ObSScope alloc] initWithOuterScope: _scope
                                              paramListNameOrNames: _argumentNames
                                                         arguments: arguments];
  id ret = [invocationScope evaluate: _expression];
  [invocationScope release]; // trying to be conservative with memory in highly recursive environment here
  return ret;
}

@end





@implementation ObSNativeLambda

+ (id)named:(ObSSymbol*)name fromBlock:(ObSNativeBlock)block {
  return [[[ObSNativeLambda alloc] initWithBlock: block name: name] autorelease];
}

- (id)initWithBlock:(ObSNativeBlock)block name:(ObSSymbol*)name {
  if ( ( self = [super init] ) ) {
    _block = Block_copy(block);
    _name = [name retain];
  }
  return self;
}

- (ObSSymbol*)name {
  return (_name == nil ? S_LAMBDA : _name);
}

- (void)dealloc {
  Block_release(_block);
  [_name release];
  [super dealloc];
}

- (id)invokeWithArguments:(NSArray*)arguments {
  return _block(arguments);
}

@end





@implementation ObSNativeBinaryLambda

+ (id)named:(ObSSymbol*)name fromBlock:(ObSNativeBinaryBlock)block {
  return [[[ObSNativeBinaryLambda alloc] initWithBlock: block name: name] autorelease];
}

- (id)initWithBlock:(ObSNativeBinaryBlock)block name:(ObSSymbol*)name {
  if ( ( self = [super init] ) ) {
    _block = Block_copy(block);
    _name = [name retain];
  }
  return self;
}

- (void)dealloc {
  Block_release(_block);
  [_name release];
  [super dealloc];
}

- (id)invokeWithArguments:(NSArray*)arguments {
  NSAssert([arguments count] == 2, @"Oops, should pass 2 args to binary lambda %@", _name);
  id a = [arguments objectAtIndex: 0];
  id b = [arguments objectAtIndex: 1];
  return _block(a, b);
}

- (ObSSymbol*)name {
  return (_name == nil ? S_LAMBDA : _name);
}

@end






@implementation ObSNativeUnaryLambda

+ (id)named:(ObSSymbol*)name fromBlock:(ObSNativeUnaryBlock)block {
  return [[[ObSNativeUnaryLambda alloc] initWithBlock: block name: name] autorelease];
}

- (id)initWithBlock:(ObSNativeUnaryBlock)block name:(ObSSymbol*)name {
  if ( ( self = [super init] ) ) {
    _block = Block_copy(block);
    _name = [name retain];
  }
  return self;
}

- (void)dealloc {
  Block_release(_block);
  [_name release];
  [super dealloc];
}

- (id)invokeWithArguments:(NSArray*)arguments {
  NSAssert([arguments count] == 1, @"Oops, should pass 1 args to unary lambda %@", _name);
  return _block([arguments lastObject]);
}

- (ObSSymbol*)name {
  return (_name == nil ? S_LAMBDA : _name);
}

@end





@implementation ObSInPort

@synthesize cursor=_cursor;

- (id)initWithString:(NSString*)string {
  if ( (self = [super init]) ) {
    _data = [string retain];
  }
  return self;
}

- (id)initWithData:(NSData*)data {
  if ( (self = [super init]) ) {
    _data = [[NSString alloc] initWithData: data
                                  encoding: NSUTF8StringEncoding];
  }
  return self;
}

- (void)dealloc {
  [_data release];
  [super dealloc];
}

- (NSString*)readLine {
  NSRange nextNL = [_data rangeOfString: @"\n"
                                options: 0
                                  range: NSMakeRange(_cursor, [_data length]-_cursor)];
  NSUInteger loc = nextNL.location;
  if ( loc == NSNotFound ) {
    loc = [_data length];
  }
  NSUInteger start = _cursor;
  NSUInteger length = loc-_cursor;
  _cursor = loc + 1; // move us past the newline
  return [_data substringWithRange: NSMakeRange(start, length)]; // return everything up to that
}

- (NSString*)readQuoted {
  NSRange nextQuote = [_data rangeOfString: @"\""
                                   options: 0
                                     range: NSMakeRange(_cursor, [_data length]-_cursor)];
  NSUInteger startQuote = _cursor - 1;
  NSUInteger endQuote = nextQuote.location;
  NSUInteger length = endQuote + 1 - startQuote;
  _cursor = endQuote + 1; // move us past the quote
  return [_data substringWithRange: NSMakeRange(startQuote, length)];
}

- (NSString*)readToken {
  NSUInteger start = _cursor-1;
  NSUInteger length = [_data length];
  if ( _cursor < length ) {
    unichar c = [_data characterAtIndex: _cursor];
    while ( c != ' ' && c != '\t' && c != '\n' && c != ')' ) {
      if ( _cursor == length - 1 ) {
        _cursor++;
        break;
      }
      c = [_data characterAtIndex: ++_cursor];
    }
  }
  return [_data substringWithRange: NSMakeRange(start, _cursor-start)];
}

- (id)nextToken {
  NSUInteger length = [_data length];
  if ( _cursor == length )
    return _EOF;

  NSAssert(_cursor < length, @"Went off the end");
  switch ( [_data characterAtIndex: _cursor++] ) {
  case ' ':
  case '\n':
  case '\t':
    return [self nextToken];

  case '(':  return S_OPENPAREN;
  case ')':  return S_CLOSEPAREN;
  case '`':  return S_QUASIQUOTE;
  case '\'': return S_QUOTE;
  case ',':
    {
      unichar next = [_data characterAtIndex: _cursor];
      if ( next == '@' ) {
        _cursor++;
        return S_UNQUOTESPLICING;

      } else {
        return S_UNQUOTE;
      }
    }

  case ';':
    [self readLine];
    return [self nextToken];

  case '"':
    return [self readQuoted];

  default:
    return [self readToken];
  }
}

@end


@implementation ObSCons
@synthesize car=_car, cdr=_cdr;

- (id)initWithCar:(id)car cdr:(id)cdr {
  if ( ( self = [super init] ) ) {
    _car = [car retain];
    _cdr = [cdr retain];
  }
  return self;
}

- (void)dealloc {
  [_car release];
  [_cdr release];
  [super dealloc];
}

- (BOOL)isEqual:(id)obj {
  if ( obj == nil || ! [obj isKindOfClass: [ObSCons class]] ) {
    return NO;

  } else {
    ObSCons* cons = obj;
    return [[cons car] isEqual: _car] && [[cons cdr] isEqual: _cdr];
  }
}

- (NSString*)description {
  return [NSString stringWithFormat: @"Cons(%@, %@)", _car, _cdr];
}

- (void)populateArray:(NSMutableArray*)array {
  [array addObject: _car];

  if ( _cdr != C_NULL ) {
    if ( [_cdr isKindOfClass: [ObSCons class]] ) {
      ObSCons* next = (ObSCons*)_cdr;
      [next populateArray: array];

    } else {
      [array addObject: _cdr];
    }
  }
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state objects:(id*)stackbuf count:(NSUInteger)len {
  id current = (id)state->state;
  if ( current == 0 ){
    NSLog(@"initializing enumeration");
    current = self;
    state->mutationsPtr = &state->extra[0];

  } else {
    if ( ! [current isKindOfClass: [ObSCons class]] ) {
      // should this fail here?
      NSLog( @"Ending, hit non-cons" );
      return 0; // tail is not a list
    }

    NSLog( @"moving to next cons" );
    ObSCons* cell = current;
    current = cell.cdr;
  }

  state->state = (unsigned long)current;
  state->itemsPtr = stackbuf;

  if ( current == C_NULL ) {
    NSLog( @"Hit end of list");
    return 0;

  } else if ( ! [current isKindOfClass: [ObSCons class]] ) {
    NSLog( @"non-list tail... returning it" );
    // list tail... should this fail?
    *stackbuf = current;
    return 1;

  } else {
    NSLog( @"returning car, yay" );
    ObSCons* cell = current;
    NSLog( @"cell is %@", cell );
    NSLog( @"car is  %@", cell.car );
    stackbuf[0] = cell.car;
    return 1;
  }
}

- (NSArray*)toArray {
  NSMutableArray* array = [NSMutableArray array];
  [self populateArray: array];
  return array;
}

@end



@implementation ObSConstant

@synthesize name=_name;
- (id)initWithName:(NSString*)name {
  if ( ( self = [super init] ) ) {
    _name = [name retain];
  }
  return self;
}

- (void)dealloc {
  [_name release];
  [super dealloc];
}

- (NSString*)description {
  return _name;
}

@end
