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
static ObSSymbol* S_FALSE;
static ObSSymbol* S_TRUE;
static ObSSymbol* S_OPENPAREN;
static ObSSymbol* S_CLOSEPAREN;

static NSString* _EOF = @"#EOF#";

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

static NSDictionary* __constants;
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
  S_FALSE =           SY(@"#f");
  S_TRUE =            SY(@"#t");
  S_OPENPAREN =       SY(@"(");
  S_CLOSEPAREN =      SY(@")");
}

+ (void)initialize {
  __constants = [[NSDictionary alloc]
                  initWithObjectsAndKeys:
                  [NSNumber numberWithInteger: 0], @"0",
                  [NSNumber numberWithFloat: 0.0], @"0.0",
                  nil];
  [self initializeSymbols];
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

  float floatValue = [string floatValue];
  if ( floatValue != 0.0 ) // note that the literal '0.0' is handle in constants above
    return [NSNumber numberWithFloat: floatValue];

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

  if ( ! [token isKindOfClass: [NSArray class]] )
    return token; // constant / value, return as-is

  NSArray* array = token;
  id head = [array objectAtIndex: 0];

  if ( head == S_QUOTE ) { // (quote exp)
    [ObjScheme assertSyntax: ([array count] == 2)
                  elseRaise: [NSString stringWithFormat: @"quote should have 1 arg, given %d", [array count]-1]];
    return array;

  } else if ( head == S_IF ) { // (if x y) => (if x y #f)
    if ( [array count] == 3 ) { // (if x y)
      NSMutableArray* longer = [NSMutableArray arrayWithArray: array];
      [longer addObject: S_FALSE];
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
      expression = [ObjScheme expandToken: body atTopLevel: NO];

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

+ (id)quote:(id)token {
  return [NSArray arrayWithObjects: S_QUOTE, token, nil];
}

/**
 * `x => 'x
 * `,x => x
 * `(,@x y)
 */
+ (id)expandQuasiquote:(id)token {
  if ( ! [token isKindOfClass: [NSArray class]] ) {
    return [self quote: token];

  } else {
    NSArray* list = token;
    if ( [list count] == 0 )
      return [self quote: list];

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
          float ret = 0;
          for ( NSNumber* number in list ) {
            ret += [number floatValue];
          }
          return [NSNumber numberWithFloat: ret];
        }
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"-")
                                      fromBlock: ^(NSArray* list) {
        NSNumber* first = [list objectAtIndex: 0];
        NSNumber* second = [list objectAtIndex: 1];
        if ( strcmp([first objCType], @encode(int)) == 0 ) {
          return [NSNumber numberWithInteger: [first intValue]-[second intValue]];

        } else {
          return [NSNumber numberWithFloat: [first floatValue]-[second floatValue]];
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
          float ret = 1.0;
          for ( NSNumber* number in list ) {
            ret *= [number floatValue];
          }
          return [NSNumber numberWithFloat: ret];
        }
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"/")
                                      fromBlock: ^(NSArray* list) {
        NSNumber* first = [list objectAtIndex: 0];
        NSNumber* second = [list objectAtIndex: 1];
        if ( strcmp([first objCType], @encode(int)) == 0 && strcmp([second objCType], @encode(int)) == 0 ) {
          return [NSNumber numberWithInteger: [first intValue]/[second intValue]];

        } else {
          return [NSNumber numberWithFloat: [first floatValue]/[second floatValue]];
        }
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"not")
                                      fromBlock: ^(NSArray* list) {
        NSAssert([list count] == 1, @"not only takes 1 arg");
        return [list lastObject] == S_FALSE ? S_TRUE : S_FALSE;
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@">")
                                      fromBlock: ^(NSArray* list) {
        NSNumber* first = [list objectAtIndex: 0];
        NSNumber* second = [list objectAtIndex: 1];
        return [first floatValue] > [second floatValue] ? S_TRUE : S_FALSE;
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"<")
                                      fromBlock: ^(NSArray* list) {
        NSNumber* first = [list objectAtIndex: 0];
        NSNumber* second = [list objectAtIndex: 1];
        return [first floatValue] < [second floatValue] ? S_TRUE : S_FALSE;
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@">=")
                                      fromBlock: ^(NSArray* list) {
        NSNumber* first = [list objectAtIndex: 0];
        NSNumber* second = [list objectAtIndex: 1];
        return [first floatValue] >= [second floatValue] ? S_TRUE : S_FALSE;
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"<=")
                                      fromBlock: ^(NSArray* list) {
        NSNumber* first = [list objectAtIndex: 0];
        NSNumber* second = [list objectAtIndex: 1];
        return [first floatValue] <= [second floatValue] ? S_TRUE : S_FALSE;
      }]];

  [scope defineFunction: [ObSNativeLambda named: SY(@"=")
                                      fromBlock: ^(NSArray* list) {
        NSNumber* first = [list objectAtIndex: 0];
        NSNumber* second = [list objectAtIndex: 1];
        return [first isEqualToNumber: second] ? S_TRUE : S_FALSE;
      }]];

  // TODO:
  /*
    - equal? eq?
    - length
    - cons, car, cdr, cdar, cadr
    - list
    - list? null? symbol? boolean? pair? port?
    - apply
    - eval
    - call/cc
    - write
    - map
    - display
    - symbol->string
    - string-append
    - display
    - MAYBE I/O: load, read, write, read-char, open-input-file, close-input-port, open-output-file, close-output-port, eof-object?
   */
}

+ (BOOL)isFalse:(id)token {
  return token == S_FALSE;
}

@end





@implementation ObSSymbol

@synthesize string=_string;

+ (ObSSymbol*)symbolFromString:(NSString*)string {
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
      NSString* catchAllParameterName = nil;

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
        [_environ setObject: [arguments objectAtIndex: i] forKey: [namedParameters objectAtIndex: i]];
      }

      if ( numArgs > numNamed ) {
        int numRemaining = numArgs - numNamed;
        [_environ setObject: [arguments subarrayWithRange: NSMakeRange(numNamed, numRemaining)]
                     forKey: catchAllParameterName];
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
  [global defineMacroNamed: SY(@"let")
               asProcedure: [ObSNativeLambda named: SY(@"let")
                                         fromBlock: ^(NSArray* list) {
        NSArray* bindings = [list objectAtIndex: 0];
        NSArray* body = [list subarrayWithRange: NSMakeRange(1, [list count]-1)];

        NSMutableArray* names = [NSMutableArray arrayWithCapacity: [bindings count]];
        NSMutableArray* expressions = [NSMutableArray arrayWithCapacity: [bindings count]];
        for ( NSArray* binding in bindings) {
          [ObjScheme assertSyntax: [binding isKindOfClass: [NSArray class]] elseRaise: @"Illegal let binding list"];
          [ObjScheme assertSyntax: ([binding count] == 2) elseRaise: @"Illegal let binding list item wrong length"];
          [names addObject: [binding objectAtIndex: 0]];
          [expressions addObject: [ObjScheme expandToken: [bindings objectAtIndex: 1] atTopLevel: YES]];
        }

        NSMutableArray* expandedBody = [NSMutableArray arrayWithCapacity: [body count]];
        for ( id token in body ) {
          [expandedBody addObject: [ObjScheme expandToken: token atTopLevel: YES]];
        }

        // expands to ((lambda (names) body) expressions)
        NSMutableArray* lambdaExpression = [NSMutableArray arrayWithObjects: S_LAMBDA, names, nil];
        [lambdaExpression addObjectsFromArray: expandedBody];

        NSMutableArray* resultExpression = [NSMutableArray arrayWithObject: lambdaExpression];
        [resultExpression addObjectsFromArray: expressions];

        return resultExpression;
      }]];
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
      if ( token == S_FALSE || token == S_TRUE ) {
        return token; // constants

      } else if ( [token isKindOfClass: [ObSSymbol class]] ) {
        return [self resolveSymbol: token]; // variable reference

      } else if ( ! [token isKindOfClass: [NSArray class]] ) {
        return token; // literal

      } else {
        NSArray* list = token;
        id head = [list objectAtIndex: 0];
        NSArray* rest = [list subarrayWithRange: NSMakeRange(1, [list count]-1)];

        if ( head == S_QUOTE ) { // (quote exp) -> exp
          return rest; // that's easy- literally the rest of the array is the value

        } else if ( head == S_IF ) { // (if test consequence alternate) <- note that full form is enforced by expansion
          id test = [rest objectAtIndex: 0];
          id consequence = [rest objectAtIndex: 1];
          id alternate = [rest objectAtIndex: 2];
          token = [self evaluate: test] == S_FALSE ? alternate : consequence;
          continue; // I'm being explicit here for clarity, we'll now evaluate this token

        } else if ( head == S_SET ) { // (set! variableName expression)
          ObSSymbol* symbol = [rest objectAtIndex: 0];
          id expression = [rest objectAtIndex: 1];
          ObSScope* definingScope = [self findScopeOf: symbol]; // I do this first, which can fail, so we don't bother executing predicate
          id value = [self evaluate: expression];
          [definingScope define: symbol as: value];

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
  if ( [_environ objectForKey: name] != nil )
    return self;
  if ( _outerScope != nil )
    return [_outerScope findScopeOf: name];

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
  unichar c = [_data characterAtIndex: _cursor];
  while ( c != ' ' && c != '\t' && c != '\n' && c != ')' ) {
    if ( _cursor == length - 1 ) {
      _cursor++;
      break;
    }
    c = [_data characterAtIndex: ++_cursor];
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
