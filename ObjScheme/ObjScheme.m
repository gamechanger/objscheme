//
//  ObjScheme.m
//  ObjScheme
//
//  Created by Kiril Savino on 7/30/12.
//  Copyright (c) 2012 GameChanger. All rights reserved.
//

#import "ObjScheme.h"

static NSString* S_DOT = @".";
static NSString* S_QUOTE = @"quote";
static NSString* S_IF = @"if";
static NSString* S_SET = @"set!";
static NSString* S_DEFINE = @"define";
static NSString* S_LAMBDA = @"lambda";
static NSString* S_BEGIN = @"begin";
static NSString* S_DEFINEMACRO = @"define-macro";
static NSString* S_QUASIQUOTE = @"quasiquote";
static NSString* S_UNQUOTE = @"unquote";
static NSString* S_UNQUOTESPLICING = @"unquote-splicing";
static NSString* S_APPEND = @"append";
static NSString* S_CONS = @"cons";
static NSString* S_LET = @"let";
static NSString* S_F = @"#f";
static NSString* S_T = @"#t";

#define IF(x) [ObjScheme IF: (x)]

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
static ObSScope* __globalScope;

+ (void)initialize {
  __constants = [[NSDictionary alloc]
                  initWithObjectsAndKeys:
                    [NSNumber numberWithBool: YES], S_T,
                  [NSNumber numberWithBool: NO], S_F,
                  [NSNumber numberWithInteger: 0], @"0",
                  [NSNumber numberWithFloat: 0.0], @"0.0",
                  nil];
  __globalScope = [[ObSScope alloc] init];
  [__globalScope bootstrapMacros];
}

+ (ObSScope*)globalScope {
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

  int intValue = [string intValue];
  if ( intValue != 0 ) // note that the literal '0' is handled in constants above
    return [NSNumber numberWithInteger: intValue];

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
  NSString* op = [array objectAtIndex: 0];

  if ( [op isEqualToString: S_QUOTE] ) { // (quote exp)
    [ObjScheme assertSyntax: ([array count] == 2)
                  elseRaise: [NSString stringWithFormat: @"quote should have 1 arg, given %d", [array count]-1]];
    return [array objectAtIndex: 1];

  } else if ( [op isEqualToString: S_IF] ) { // (if x y) => (if x y #f)
    if ( [array count] == 3 ) { // (if x y)
      NSMutableArray* longer = [NSMutableArray arrayWithArray: array];
      [longer addObject: S_F];
      array = longer;
    }

    [ObjScheme assertSyntax: ([array count] == 4) elseRaise: @"Invalid 'if' syntax"];
    NSMutableArray* ret = [NSMutableArray arrayWithCapacity: [array count]];
    for ( id subToken in array ) {
      [ret addObject: [ObjScheme expandToken: subToken atTopLevel: NO]];
    }
    return ret;

  } else if ( [op isEqualToString: S_SET] ) { // (set! thing exp)
    [ObjScheme assertSyntax: ([array count] == 3) elseRaise: @"Invalid 'set!' syntax"];
    id var = [array objectAtIndex: 1];
    [ObjScheme assertSyntax: [var isMemberOfClass: [ObSSymbol class]]
                  elseRaise: @"First arg of 'set!' should be a Symbol"];
    id expression = [ObjScheme expandToken: [array objectAtIndex: 2] atTopLevel: NO];
    return [NSArray arrayWithObjects: S_SET, var, expression, nil];

  } else if ( [op isEqualToString: S_DEFINE] ) { // (define ...)
    [ObjScheme assertSyntax: ([array count] >= 3) elseRaise: @"define takes at least 2 args"];
    id defineSpec = [array objectAtIndex: 1];
    NSArray* body = [array subarrayWithRange: NSMakeRange(2, [array count]-2)];

    if ( [defineSpec isKindOfClass: [NSArray class]] ) {
      // we're going to change (define (f args) body) => (define f (lambda (args) body)) for simplicity
      NSArray* lambdaSpec = defineSpec;
      NSString* lambdaName = [lambdaSpec objectAtIndex: 0];
      NSArray* lambdaParameterNames = [lambdaSpec subarrayWithRange: NSMakeRange(1, [lambdaSpec count]-1)];
      // => (f (params) body)
      NSMutableArray* lambdaDefinition = [NSMutableArray arrayWithObjects: lambdaName, lambdaParameterNames, nil];
      [lambdaDefinition addObjectsFromArray: body];
      return [ObjScheme expandToken: [NSArray arrayWithObjects: S_DEFINE, lambdaName, lambdaDefinition, nil]
                         atTopLevel: NO];

    } else {
      [ObjScheme assertSyntax: [defineSpec isMemberOfClass: [ObSSymbol class]]
                    elseRaise: @"define second param must be symbol"];
      id expression = [body lastObject];
      return [NSArray arrayWithObjects: S_DEFINE, defineSpec, [ObjScheme expandToken: expression atTopLevel: NO], nil];
    }

  } else if ( [op isEqualToString: S_DEFINEMACRO] ) { // (define-macro symbol proc)
    [ObjScheme assertSyntax: topLevel elseRaise: @"define-macro must be invoked at the top level"];
    [ObjScheme assertSyntax: ([array count] == 3) elseRaise: @"bad define-macro syntax"];
    NSString* macroName = [array objectAtIndex: 1];
    id body = [ObjScheme expandToken: [array lastObject] atTopLevel: NO];
    id invocation = [[ObjScheme globalScope] evaluate: body];
    [ObjScheme assertSyntax: [invocation isKindOfClass: [ObSInvocation class]] elseRaise: @"body of define-macro must be an invocation"];
    [[ObjScheme globalScope] defineMacroNamed: macroName asInvocation: invocation];
    return nil;

  } else if ( [op isEqualToString: S_BEGIN] ) {
    if ( [array count] == 1 ) { // (begin) => nil
      return nil;

    } else {
      NSMutableArray* ret = [NSMutableArray arrayWithCapacity: [array count]];
      for ( id subToken in array ) {
        [ret addObject: [ObjScheme expandToken: subToken atTopLevel: topLevel]];
      }
      return ret;
    }

  } else if ( [op isEqualToString: S_LAMBDA] ) {
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

  } else if ( [op isEqualToString: S_QUASIQUOTE] ) {
    [ObjScheme assertSyntax: ([array count] == 2) elseRaise: @"invalid quasiquote, wrong arg num"];
    return [ObjScheme expandQuasiquote: [array objectAtIndex: 1]];

  } else if ( [op isMemberOfClass: [ObSSymbol class]] && [[ObjScheme globalScope] hasMacroNamed: op] ) {
    ObSInvocation* macro = [[ObjScheme globalScope] macroNamed: op];
    NSArray* macroArguments = [array subarrayWithRange: NSMakeRange(1, [array count]-1)];
    return [ObjScheme expandToken: [macro invokeWithArguments: macroArguments] atTopLevel: NO];

  } else {
    NSMutableArray* ret = [NSMutableArray arrayWithCapacity: [array count]];
    for ( id subToken in array ) {
      [ret addObject: [ObjScheme expandToken: subToken atTopLevel: NO]];
    }
    return ret;
  }
}

/**
 * `x => 'x
 * `,x => x
 * `(,@x y)
 */
+ (id)expandQuasiquote:(id)token {
  if ( ! [token isKindOfClass: [NSArray class]] ) {
    return [NSArray arrayWithObjects: S_QUOTE, token, nil];

  } else {
    NSArray* list = token;
    id first = [list objectAtIndex: 0];
    [ObjScheme assertSyntax: ! [first isEqual: S_UNQUOTESPLICING] elseRaise: @"can't splice at beginning of quasiquote"];
    NSArray* remainderOfList = [list subarrayWithRange: NSMakeRange(1, [list count]-1)];

    if ( [first isEqual: S_UNQUOTE] ) {
      [ObjScheme assertSyntax: ([list count] == 2) elseRaise: @"invalid unquote phrase, missing operand"];
      return [list lastObject];

    } else if ( [first isKindOfClass: [NSArray class]] && [[(NSArray*)first objectAtIndex: 0] isEqual: S_UNQUOTESPLICING] ) {
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
+ (id)parseFromInPort:(ObSInPort*)inPort {
}

+ (id)loadFromInPort:(ObSInPort*)inPort {
}

+ (id)parseString:(NSString*)string {
}


+ (void)assertSyntax:(BOOL)correct elseRaise:(NSString*)message {
  if ( ! correct )
    [NSException raise: @"SyntaxError" format: message];
}

+ (void)addGlobalsToScope:(ObSScope*)scope {
  [scope setObject: [ObSInvocation fromBlock: ^(NSArray* list) {
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
      }] forKey: @"+"];

  [scope setObject: [ObSInvocation fromBlock: ^(NSArray* list) {
        NSNumber* first = [list objectAtIndex: 0];
        NSNumber* second = [list objectAtIndex: 1];
        if ( strcmp([first objCType], @encode(int)) == 0 ) {
          return [NSNumber numberWithInteger: [first intValue]-[second intValue]];

        } else {
          return [NSNumber numberWithFloat: [first floatValue]-[second floatValue]];
        }
      }] forKey: @"-"];

  [scope setObject: [ObSInvocation fromBlock: ^(NSArray* list) {
        if ( [list count] == 0 )
          return [NSNumber numberWithInteger: 0];

        NSNumber* first = [list objectAtIndex: 0];
        if ( strcmp([first objCType], @encode(int)) == 0 ) {
          int ret = 0;
          for ( NSNumber* number in list ) {
            ret *= [number intValue];
          }
          return [NSNumber numberWithInteger: ret];

        } else {
          float ret = 0;
          for ( NSNumber* number in list ) {
            ret *= [number floatValue];
          }
          return [NSNumber numberWithFloat: ret];
        }
      }] forKey: @"*"];

  [scope setObject: [ObSInvocation fromBlock: ^(NSArray* list) {
        NSNumber* first = [list objectAtIndex: 0];
        NSNumber* second = [list objectAtIndex: 1];
        if ( strcmp([first objCType], @encode(int)) == 0 ) {
          return [NSNumber numberWithInteger: [first intValue]/[second intValue]];

        } else {
          return [NSNumber numberWithFloat: [first floatValue]/[second floatValue]];
        }
      }] forKey: @"/"];

  [scope setObject: [ObSInvocation fromBlock: ^(NSArray* list) {
        NSAssert([list count] == 1, @"not only takes 1 arg");
        return [NSNumber numberWithBool: [ObjScheme isEmptyList: [list objectAtIndex: 0]]];
      }] forKey: @"not"];

  [scope setObject: [ObSInvocation fromBlock: ^(NSArray* list) {
        NSNumber* first = [list objectAtIndex: 0];
        NSNumber* second = [list objectAtIndex: 1];
        return [NSNumber numberWithBool: [first floatValue] > [second floatValue]];
      }] forKey: @">"];

  [scope setObject: [ObSInvocation fromBlock: ^(NSArray* list) {
        NSNumber* first = [list objectAtIndex: 0];
        NSNumber* second = [list objectAtIndex: 1];
        return [NSNumber numberWithBool: [first floatValue] < [second floatValue]];
      }] forKey: @"<"];

  [scope setObject: [ObSInvocation fromBlock: ^(NSArray* list) {
        NSNumber* first = [list objectAtIndex: 0];
        NSNumber* second = [list objectAtIndex: 1];
        return [NSNumber numberWithBool: [first floatValue] >= [second floatValue]];
      }] forKey: @">="];

  [scope setObject: [ObSInvocation fromBlock: ^(NSArray* list) {
        NSNumber* first = [list objectAtIndex: 0];
        NSNumber* second = [list objectAtIndex: 1];
        return [NSNumber numberWithBool: [first floatValue] <= [second floatValue]];
      }] forKey: @"<="];
}

+ (BOOL)IF:(id)token {
  if ( token == nil )
    return YES; // Scheme if is only false for #f, ie NO
  if ( ! [token isKindOfClass: [NSNumber class]] )
    return YES;
  NSNumber* value = token;
  if ( strcmp([value objCType], @encode(BOOL)) != 0 )
    return YES; // not a BOOL

  return [value boolValue];
}

@end





@implementation ObSSymbol

+ (ObSSymbol*)symbolFromString:(NSString*)string {
  if ( [string isMemberOfClass: [ObSSymbol class]] )
    return (ObSSymbol*)string;
  return [[[ObSSymbol alloc] initWithString: string] autorelease];
}

@end





@implementation ObSScope

@synthesize outer=_outerScope;

- (id)initWithOuterScope:(ObSScope*)outer {
  if ( (self = [super init]) ) {
    self.outer = outer;
    _macros = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)dealloc {
  [_outerScope release];
  [_macros release];
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
        [self setObject: [arguments objectAtIndex: i] forKey: [namedParameters objectAtIndex: i]];
      }

      if ( numArgs > numNamed ) {
        int numRemaining = numArgs - numNamed;
        [self setObject: [arguments subarrayWithRange: NSMakeRange(numNamed, numRemaining)]
                 forKey: catchAllParameterName];
      }

    } else {
      NSAssert1( [parameters isKindOfClass: [NSString class]], @"Syntax Error(?): Parameters for scope is %@", parameters );
      [self setObject: arguments forKey: parameters];
    }
  }
  return self;
}

- (id)resolveVariable:(NSString*)variable {
  id myValue = [self objectForKey: variable];
  if ( myValue ) {
    return myValue;
  }

  if ( _outerScope != nil ) {
    return [_outerScope resolveVariable: variable];
  }

  [NSException raise: @"LookupError" format: @"variable %@ not defined", variable];
  return nil;
}

- (void)bootstrapMacros {
  static NSString* macros = @"(begin"

    "(define-macro and (lambda args"
    "   (if (null? args) #t"
    "       (if (= (length args) 1) (car args)"
    "           `(if ,(car args) (and ,@(cdr args)) #f)))))"

    "(define-macro or"
    "  (lambda args"
    "    (if (null? args) #f"
    "        (let ((arg (car args)))"
    "          `(let ((arg ,arg))"
    "             (if arg arg"
    "                 (or ,@(cdr args)))))))))"

    ";; More macros can also go here"
    ")";

  ObSScope* global = [ObjScheme globalScope];
  [global evaluate: [ObjScheme parseString: macros]];
  [global defineMacroNamed: @"let" asInvocation: [ObSInvocation fromBlock: ^(NSArray* list) {
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


- (id)evaluate:(id)token {
  NSAssert(token != nil, @"nil token");

  @try {
    while ( 1 ) {
      if ( [token isKindOfClass: [ObSSymbol class]] ) {
        return [self resolveVariable: token]; // variable reference

      } else if ( ! [token isKindOfClass: [NSArray class]] ) {
        return token; // literal

      } else {
        NSArray* list = token;
        id head = [list objectAtIndex: 0];
        NSArray* rest = [list subarrayWithRange: NSMakeRange(1, [list count]-1)];

        if ( [head isEqual: S_QUOTE] ) { // (quote exp) -> exp
          return rest; // that's easy- literally the rest of the array is the value

        } else if ( [head isEqual: S_IF] ) { // (if test consequence alternate) <- note that full form is enforced by expansion
          id test = [rest objectAtIndex: 0];
          id consequence = [rest objectAtIndex: 1];
          id alternate = [rest objectAtIndex: 2];
          token = IF([self evaluate: test]) ? consequence : alternate;
          continue; // I'm being explicit here for clarity, we'll now evaluate this token

        } else if ( [head isEqual: S_SET] ) { // (set! variableName expression)
          NSString* variableName = [rest objectAtIndex: 0];
          id expression = [rest objectAtIndex: 1];
          ObSScope* definingScope = [self findScopeOf: variableName]; // I do this first, which can fail, so we don't bother executing predicate
          id value = [self evaluate: expression];
          [definingScope setObject: value forKey: variableName];

        } else if ( [head isEqual: S_DEFINE] ) { // (define variableName expression)
          NSString* variableName = [rest objectAtIndex: 0];
          id expression = [rest objectAtIndex: 1];
          [self setObject: [self evaluate: expression] forKey: variableName];

        } else if ( [head isEqual: S_LAMBDA] ) { // (lambda (argumentNames) body)
          NSArray* argumentNames = [rest objectAtIndex: 0];
          NSArray* body = [rest objectAtIndex: 1];
          return [[[ObSProcedure alloc] initWithArgumentNames: argumentNames
                                                   expression: body
                                                        scope: self] autorelease];

        } else if ( [head isEqual: S_BEGIN] ) { // (begin expression...)
          id result = [NSNumber numberWithBool: NO];
          for ( id expression in rest ) {
            result = [self evaluate: expression];
          }
          return result; // begin evaluates to value of final expression

        } else {
          id executable = [self evaluate: head];
          NSMutableArray* arguments = [NSMutableArray arrayWithCapacity: [rest count]];
          for ( id subToken in rest ) {
            [arguments addObject: [self evaluate: subToken]];
          }

          if ( [executable isKindOfClass: [ObSProcedure class]] ) {
            // a named function, which we now will in turn resolve within this scope, and invoke a level deeper
            ObSProcedure* procedure = executable;
            ObSScope* invocationScope = [[ObSScope alloc] initWithOuterScope: procedure.scope
                                                        paramListNameOrNames: procedure.argumentNames
                                                                   arguments: arguments];
            id ret = [invocationScope evaluate: procedure.expression];
            [invocationScope release]; // trying to be conservative with memory in highly recursive environment here
            return ret;

          } else {
            // this is the actual executable, and the rest of the details are the arguments
            ObSInvocation* invocation = executable;
            return [invocation invokeWithArguments: arguments];
          }
        }
      }
    }

  } @catch ( NSException* e ) {
    NSLog( @"FAILED TO EVALUATE %@", token );
    [e raise];
  }
}

- (ObSScope*)findScopeOf:(NSString*)name {
  if ( [self objectForKey: name] != nil )
    return self;
  if ( _outerScope != nil )
    return [_outerScope findScopeOf: name];

  [NSException raise: @"LookupError" format: @"Couldn't find defining scope of %@", name];
  return nil;
}

- (void)defineMacroNamed:(NSString*)name asInvocation:(ObSInvocation*)procedure {
  [_macros setObject: procedure forKey: name];
}

- (BOOL)hasMacroNamed:(NSString*)name {
  return [_macros objectForKey: name] != nil;
}

- (ObSInvocation*)macroNamed:(NSString*)name {
  return [_macros objectForKey: name];
}

@end





@implementation ObSProcedure

@synthesize scope=_scope, expression=_expression, argumentNames=_argumentNames;


- (id)initWithArgumentNames:(NSArray*)argumentNames
                 expression:(id)expression
                      scope:(ObSScope*)scope {

  if ( (self = [self init]) ) {
    _argumentNames = [argumentNames retain];
    _expression = [expression retain];
    _scope = [scope retain];
  }

  return self;
}

@end





@implementation ObSInvocation

+ (id)fromBlock:(ObSInvocationBlock)block {
  return [[[ObSInvocation alloc] initWithBlock: block] autorelease];
}

- (id)initWithBlock:(ObSInvocationBlock)block {
  if ( ( self = [super init] ) ) {
    _block = Block_copy(block);
  }
  return self;
}

- (void)dealloc {
  Block_release(_block);
  [super dealloc];
}

- (id)invokeWithArguments:(NSArray*)arguments {
  _block(arguments);
}

@end
