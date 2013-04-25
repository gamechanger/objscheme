//
//  ObjSchemeTests.m
//  ObjSchemeTests
//
//  Created by Kiril Savino on 7/30/12.
//  Copyright (c) 2012, 2013 GameChanger. All rights reserved.
//

#import "ObjSchemeTests.h"
#import "ObjScheme.h"
#import "ObSCollectible.h"
#import "ObSGarbageCollector.h"


#define OSAssertFalse(code) source = (code);\
 program = [ObjScheme parseString: source];\
 returnValue = [[ObjScheme globalScope] evaluate: program];\
 STAssertTrue([ObjScheme isFalse: returnValue], @"%@ => %@", source, returnValue);

#define OSAssertTrue(code) source = (code);\
 program = [ObjScheme parseString: source];\
 returnValue = [[ObjScheme globalScope] evaluate: program];\
 STAssertTrue(! [ObjScheme isFalse: returnValue], @"%@ => %@", source, returnValue);

#define OSAssertEqualsInt(code, expected) source = (code);\
 program = [ObjScheme parseString: source];\
 returnValue = [[ObjScheme globalScope] evaluate: program];\
 STAssertTrue([returnValue isKindOfClass: [NSNumber class]], @"%@ => %@", source, returnValue); \
 number = returnValue;\
 STAssertEquals(strcmp([number objCType], @encode(int)), 0, @"%@ => %@", source, returnValue); \
 STAssertEquals([number intValue], (expected), @"%@ => %d", source, [number intValue]);

#define OSAssertEqualsDouble(code, expected) source = (code);\
 program = [ObjScheme parseString: source];\
 returnValue = [[ObjScheme globalScope] evaluate: program];\
 STAssertTrue([returnValue isKindOfClass: [NSNumber class]], @"%@ isn't a number", source);\
 number = returnValue;\
 STAssertEquals(strcmp([number objCType], @encode(double)), 0, @"%@ isn't a double", source);\
 STAssertEqualsWithAccuracy([number doubleValue], (expected), 0.0001, @"%@ => %f not %f, off by %f", source, [number doubleValue], (expected), (expected)-[number doubleValue]);

#define OSAssertEquals(code, expected) source = (code);\
 program = [ObjScheme parseString: source];\
 returnValue = [[ObjScheme globalScope] evaluate: program];\
 STAssertEqualObjects(returnValue, expected, @"source: %@ ", source);


#define COMPILE(source) [ObjScheme parseString: (source)]
#define EXEC(source) [[ObjScheme globalScope] evaluate: COMPILE(source)]



typedef void (^Thunk)(void);


@interface MockCollectible : ObSCollectible {
  Thunk _onReleaseChildren;
  Thunk _onDealloc;
}
@property (nonatomic,copy) Thunk onReleaseChildren;
@property (nonatomic,copy) Thunk onDealloc;
@end



@implementation MockCollectible

- (void)dealloc {
  if ( _onDealloc != nil ) {
    _onDealloc();
  }
  [_onDealloc release];
  [_onReleaseChildren release];
  [super dealloc];
}

- (NSArray*)children {
  return [NSArray array];
}

- (void)releaseChildren {
  if ( _onReleaseChildren != nil ) {
    _onReleaseChildren();
  }
}

- (oneway void)release {
  if ( _garbageCollector != nil && [self retainCount] == 2 ) {
    [_garbageCollector stopTracking: self];
  }

  [super release];
}

@end




@implementation ObjSchemeTests

- (void)setUp
{
    [super setUp];
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    [super tearDown];
}

- (void)testInPortBasics {
  NSString* program = @"(display \"hi\")";
  ObSInPort* port = [[[ObSInPort alloc] initWithString: program] autorelease];

  NSString* t = [port nextToken];
  STAssertEqualObjects(t, SY(@"("), @"port token initial paren wrong, %@", t);

  t = [port nextToken];
  STAssertEqualObjects(t, @"display", @"port token initial paren wrong, %@", t);

  t = [port nextToken];
  STAssertEqualObjects(t, @"\"hi\"", @"port token initial paren wrong, %@", t);

  t = [port nextToken];
  STAssertEqualObjects(t, SY(@")"), @"port token initial paren wrong, %@", t);
}

- (void)testGlobalScope {
  ObSScope* global = [ObjScheme globalScope];
  STAssertEquals(global, [ObjScheme globalScope], @"Global scope isn't unique");
}

- (void)testBasicEvaluation {
  NSString* source = @"\"hi\"";
  id program = [ObjScheme parseString: source];
  id returnValue = [[ObjScheme globalScope] evaluate: program];
  STAssertEqualObjects(returnValue, @"hi", @"Failed to evaluate a string literal program");

  source = @"#f";
  program = [ObjScheme parseString: source];
  returnValue = [[ObjScheme globalScope] evaluate: program];
  STAssertTrue([ObjScheme isFalse: returnValue], @"return value isn't false %@", returnValue);

  source = @"3";
  program = [ObjScheme parseString: source];
  returnValue = [[ObjScheme globalScope] evaluate: program];
  STAssertEqualObjects([NSNumber numberWithInteger: 3], returnValue, @"uh-oh");

  source = @"0.5";
  program = [ObjScheme parseString: source];
  returnValue = [[ObjScheme globalScope] evaluate: program];
  STAssertEqualObjects([NSNumber numberWithDouble: 0.5], returnValue, @"uh-oh");

  source = @"(let ((2-in-1 'bing)) 2-in-1)";
  program = [ObjScheme parseString: source];
  returnValue = [[ObjScheme globalScope] evaluate: program];
  STAssertTrue([returnValue isKindOfClass: [ObSSymbol class]], @"number-prefixed string should be a symbol, not number: %@", returnValue);
}

- (void)testApplyCase {
  id source, program, returnValue;

  OSAssertTrue(@"(equal? (list 2 3 4) (apply append (filter (lambda (p) p) (map (lambda (x) x) (list '(2 3) '(4))))))");
}

- (void)testBuiltIns {
  id source, program, returnValue;
  NSNumber* number;

  OSAssertTrue(@"#t");
  OSAssertTrue(@"(not #f)");

  OSAssertTrue(@"(begin (define x 128) (= x 128))");
  OSAssertTrue(@"(begin (define (f x) x) (= (f 1) 1))");
  OSAssertTrue(@"(begin (define (f . x) x) (equal? (f 1) '(1)))");

  OSAssertTrue(@"(string? \"hello\")");
  OSAssertFalse(@"(string? #f)");
  OSAssertFalse(@"(string? 'hello)");

  OSAssertTrue(@"(list 1 2 3)");
  OSAssertTrue(@"(list 1 2 #f)");
  OSAssertTrue(@"(list? (list 1 2 #f))");

  OSAssertFalse(@"(list? #f)");
  OSAssertFalse(@"(list? #t)");
  OSAssertTrue(@"(not (list? #t))");

  OSAssertTrue(@"(null? (list))");
  OSAssertFalse(@"(null? #f)");
  OSAssertFalse(@"(null? #t)");
  OSAssertFalse(@"(null? (list #t))");

  OSAssertTrue(@"(eq? 1 1)");
  OSAssertFalse(@"(eq? 1 2)");
  OSAssertFalse(@"(eq? \"a\" \"a\")");

  OSAssertTrue(@"(equal? 1 1)");
  OSAssertFalse(@"(equal? 1 2)");
  OSAssertTrue(@"(equal? \"a\" \"a\")");
  OSAssertFalse(@"(equal? \"a\" \"b\")");

  OSAssertTrue(@"(symbol? 'a)");
  OSAssertFalse(@"(symbol? \"a\")");
  OSAssertFalse(@"(symbol? #f)");

  OSAssertTrue(@"(boolean? #f)");
  OSAssertTrue(@"(boolean? #t)");
  OSAssertFalse(@"(boolean? 1)");
  OSAssertFalse(@"(boolean? \"#t\")");

  OSAssertTrue(@"(pair? (cons 'a 'b))");
  OSAssertTrue(@"(pair? (cons 'a (cons 'b (cons 'c 'd))))");
  OSAssertFalse(@"(pair? (list))");
  OSAssertFalse(@"(pair? (cons 'a (cons 'b (list))))");

  OSAssertTrue(@"(number? 1)");
  OSAssertTrue(@"(number? -9999)");
  OSAssertTrue(@"(number? -9999.987856009)");
  OSAssertTrue(@"(number? '9)");
  OSAssertFalse(@"(number? \"9\")");
  OSAssertFalse(@"(number? #t)");
  OSAssertFalse(@"(number? #f)");

  OSAssertTrue(@"(integer? 1)");
  OSAssertTrue(@"(integer? 8888)");
  OSAssertTrue(@"(integer? -5)");
  OSAssertTrue(@"(integer? 0)");
  OSAssertFalse(@"(integer? 1.0)");
  OSAssertFalse(@"(integer? 6.5)");
  OSAssertFalse(@"(integer? 0.0)");
  OSAssertFalse(@"(integer? #t)");

  OSAssertEqualsInt(@"((lambda (x) (+ x 4)) 7)", 11);
  OSAssertTrue(@"(procedure? (lambda (x) (+ x 1)))");
  OSAssertFalse(@"(procedure? (+ 2 1))");
  OSAssertTrue(@"(procedure? list?)");

  OSAssertTrue(@"(equal? '(1 2) (apply cdr (list '(0 1 2))))");
  OSAssertTrue(@"(eval #t)");
  OSAssertFalse(@"(eval #f)");
  OSAssertEqualsInt(@"(eval 99)", 99);
  OSAssertTrue(@"(equal? (list 2) (eval '(list 2)))");

  OSAssertTrue(@"(equal? (list 3 4 5) (map (lambda (x) (+ x 1)) (list 2 3 4)))");
  OSAssertFalse(@"(equal? (list 1 2 3) (map (lambda (x) (+ x 1)) (list 2 3 4)))"); // just because I can't believe the above test passes...

  OSAssertTrue(@"(equal? \"frog\" (symbol->string 'frog))");
  OSAssertTrue(@"(equal? \"abc\" (string-append \"a\" \"b\" \"c\"))");


  OSAssertTrue(@"(equal? '(1 2) (filter (lambda (x) #t) '(1 2)))");
  OSAssertTrue(@"(equal? '(1 2) (filter (lambda (x) (< x 3)) '(1 2 3)))");

  OSAssertFalse(@"(unspecified? #f)");
  OSAssertFalse(@"(unspecified? '())");

  OSAssertTrue(@"(equal? (let ((x 1)) (for-each (lambda (n) (set! x (+ x n))) '(1 1)) x) 3)");
  OSAssertTrue(@"(equal? (let ((x 1)) (for-each (lambda (n) (set! x (+ x n))) '()) x) 1)");

  OSAssertTrue(@"(immutable? \"frog\")");
  OSAssertFalse(@"(immutable? (list \"frog\"))");
}

- (void)testLambda {
  id source, program, returnValue;

  OSAssertTrue(@"(equal? 1 ((lambda (x) (- x 1)) 2))");
  OSAssertTrue(@"(equal? '(a b) ((lambda (x) x) '(a b)))");
  OSAssertTrue(@"(equal? '((a b)) ((lambda x x) '(a b)))");
}

- (void)testLets {
  id source, program, returnValue;
  NSNumber* number;

  OSAssertFalse(@"(let ((a #f)) a))");
  OSAssertTrue(@"(let ((a #t)) a))");
  OSAssertFalse(@"(null? (let ((x (list #t))) x))");
  OSAssertTrue(@"(null? (let ((x (list))) x))");
  OSAssertTrue(@"(let ((x 1)) (set! x 2))");
  OSAssertTrue(@"(let ((a \"a\")) (equal? a a))");
  OSAssertTrue(@"(let ((a \"a\")) (eq? a a))");

  OSAssertTrue(@"(let* ((a 1) (b a)) (eq? a b))");
  OSAssertTrue(@"(begin (define-macro a2b2c2 (lambda (x) `(2))) (equal? 7 (let ((a2b2c2 7)) a2b2c2)))");

  OSAssertTrue(@"(let foo ((a \"a\")) (eq? a a))");

  // named let test
  OSAssertEqualsInt(@"(let fib ((n 4)) (if (= n 0) 0 (if (= n 1) 1 (+ (fib (- n 1)) (fib (- n 2))))))", 3);
}

- (void)testLists {
  id source, program, returnValue;
  NSNumber* number;

  OSAssertTrue(@"(list? '())");
  OSAssertTrue(@"(list? '(1 2))");
  OSAssertEqualsInt(@"(length '(1 2))", 2);
  OSAssertTrue(@"(null? '())");
  OSAssertTrue(@"(equal? (list 1 2) '(1 2))");
  OSAssertTrue(@"(equal? (list (list 1 2)) '((1 2)))");

  OSAssertTrue(@"(cons 1 2)");
  OSAssertTrue(@"(= 1 (car (cons 1 2)))");
  OSAssertTrue(@"(= 2 (cdr (cons 1 2)))");
  OSAssertTrue(@"(list? (cdr (list 1 2 3)))");
  OSAssertTrue(@"(null? (cdr (list 1)))");
  OSAssertTrue(@"(list? (cons 1 (list)))");
  OSAssertFalse(@"(list? (cons 1 2))");
  OSAssertFalse(@"(eq? (cons 1 2) (cons 1 2))");
  OSAssertFalse(@"(eqv? (cons 1 2) (cons 1 2))");
  OSAssertTrue(@"(equal? (cons 1 2) (cons 1 2))");
  OSAssertFalse(@"(eq? (list 1 2) (list 1 2))");
  OSAssertFalse(@"(eqv? (list 1 2) (list 1 2))");
  OSAssertTrue(@"(equal? (list 1 2) (list 1 2))");

  OSAssertEqualsInt(@"(length (list))", 0);
  OSAssertEqualsInt(@"(length (list 1 2 3))", 3);
  OSAssertTrue(@"(let ((x '(a b c))) (list? x))");
  OSAssertTrue(@"(let ((x '(a b c))) (set-cdr! x #f) (not (list? x)))");
  OSAssertTrue(@"(equal? (cons 'a #f) (let ((x '(a b c))) (set-cdr! x #f) x))");
  OSAssertTrue(@"(equal? (list 'z 'b 'c) (let ((x '(a b c))) (set-car! x 'z) x))");
}

- (void)testCond {
  id source, program, returnValue;

  OSAssertTrue(@"(equal? #t ((lambda (x) (cond ((= x 3) 1) ((= x 7)) )) 7))");
  OSAssertEquals(@"((lambda (x) (cond ((= x 3) 1) ((= x 7) 2) )) 7)", @(2));
  OSAssertEquals(@"((lambda (x) (cond ((= x 3) 1) ((= x 7)) ('else 'abc))) 8)", SY(@"abc"));
}

- (void)testVectors {
  id source, program, returnValue;

  OSAssertTrue(@"(make-vector 3)");
  OSAssertTrue(@"(make-vector 3 'a)");
  OSAssertTrue(@"(vector 1 2 3)");
  OSAssertTrue(@"(equal? 'a (vector-ref (make-vector 3 'a) 0))");
  OSAssertTrue(@"(equal? 3 (vector-length (make-vector 3 'a)))");
  OSAssertTrue(@"(unspecified? (vector-ref (make-vector 3) 0))");
  OSAssertTrue(@"(equal? 'b (let ((v (make-vector 3 'a))) (vector-set! v 0 'b) (vector-ref v 0)))");
  OSAssertTrue(@"(equal? (make-vector 3 'a) (vector 'a 'a 'a)))");
  OSAssertTrue(@"(equal? '(a b c) (vector->list (vector 'a 'b 'c))))");
  OSAssertTrue(@"(equal? (vector 'a 'b) (vector 'a 'b))");
  OSAssertFalse(@"(equal? (vector 'a 'b) (vector 'a 'c))");
  OSAssertTrue(@"(equal? (vector 'a 'b) (list->vector '(a b)))");
  OSAssertTrue(@"(unspecified? (vector-ref (make-vector 3) 0))"); // yeah, I learned something here...

  OSAssertTrue(@"(equal? (vector 'a 'b) (vector->immutable-vector (vector 'a 'b)))");
  OSAssertFalse(@"(immutable? (vector 'a 'b))");
  OSAssertTrue(@"(immutable? (vector->immutable-vector (vector 'a 'b)))");
  OSAssertTrue(@"(immutable? (vector-immutable 'a 'b))");
  OSAssertTrue(@"(equal? 'b (let ((v (vector 'a 'a 'a))) (vector-fill! v 'b) (vector-ref v 2)))");
}

- (void)testMath {
  id source, program, returnValue;
  NSNumber* number;

  OSAssertEqualsInt(@"(+ 1 2)", 3);
  OSAssertEqualsDouble(@"(+ 1.0 2.0)", 3.0);

  OSAssertEqualsInt(@"(* 5 7)", 35);
  OSAssertEqualsDouble(@"(/ 5 7)", 0.71428);
  OSAssertEqualsDouble(@"(/ 5 2)", 2.5);

  OSAssertEqualsDouble(@"(/ 5.0 2)", 2.5);
  OSAssertEqualsDouble(@"(/ 5 2.0)", 2.5);

  OSAssertFalse(@"(> 1 3)");
  OSAssertTrue(@"(> 3 1)");

  OSAssertFalse(@"(>= 1 3)");
  OSAssertTrue(@"(>= 3 1)");
  OSAssertTrue(@"(>= 3 3)");

  OSAssertFalse(@"(<= 3 1)");
  OSAssertTrue(@"(<= 1 3)");
  OSAssertTrue(@"(<= 3 3)");

  OSAssertTrue(@"(= 1 1)");
  OSAssertTrue(@"(= 1 1.0)");
  OSAssertFalse(@"(= 2 1)");
  OSAssertTrue(@"(not (= 2 1))");

  OSAssertEqualsInt(@"(abs 1)", 1);
  OSAssertEqualsInt(@"(abs -1)", 1);
  OSAssertEqualsDouble(@"(abs -1.0)", 1.0);

  OSAssertTrue(@"(even? 2)");
  OSAssertTrue(@"(even? 78)");
  OSAssertTrue(@"(even? 0)");
  OSAssertFalse(@"(even? 1)");
  OSAssertFalse(@"(even? 96593)");
  OSAssertTrue(@"(odd? 1)");
  OSAssertTrue(@"(odd? 96593)");
  OSAssertFalse(@"(odd? 2)");
  OSAssertFalse(@"(odd? 78)");

  OSAssertEqualsInt(@"(expt 2 2)", 4);
  OSAssertEqualsInt(@"(expt 2 3)", 8);
  OSAssertEqualsDouble(@"(expt 2 1.5)", 2.828427124746)

  OSAssertEqualsInt(@"(max 1 2 3 4 5 6 88 9)", 88);
  OSAssertEqualsInt(@"(max -20 6)", 6);
  OSAssertEqualsInt(@"(max -20.0 6)", 6);
  OSAssertEqualsDouble(@"(max 2.0 2.1)", 2.1);

  OSAssertEqualsInt(@"(min 1 2 3 4 5 6 88 9)", 1);
  OSAssertEqualsInt(@"(min -20 6)", -20);
  OSAssertEqualsDouble(@"(min -20.0 6)", -20.0);
  OSAssertEqualsDouble(@"(min 2.0 2.1)", 2.0);

  OSAssertEqualsDouble(@"(round 2.2)", 2.0);
  OSAssertEqualsDouble(@"(round 2.5)", 3.0);

  OSAssertEquals(@"(number->string 2)", @"2");
  OSAssertEquals(@"(number->string 2.2)", @"2.200000");

  OSAssertEqualsDouble(@"(* 0.5 1)", 0.5);
  NSLog( @"Holy crap : %@", EXEC(@"(+ 2 0.5)") );
  OSAssertEqualsDouble(@"(+ 2 0.5)", 2.5);
  OSAssertEqualsDouble(@"(+ 2 (* 0.5 1))", 2.5);
  OSAssertEqualsDouble(@"(/ (+ 2 (* 0.5 1)) 2)", 1.25);
}

- (void)testNSDictionaryBridge {
  id source, program, returnValue;

  OSAssertTrue(@"(NSDictionary:containsKey? (NSDictionary:dictionaryWithObjectsAndKeys 3 \"age\") \"age\")");
  OSAssertTrue(@"(equal? 3 (NSDictionary:objectForKey (NSDictionary:dictionaryWithObjectsAndKeys 3 \"age\") \"age\"))");
  OSAssertTrue(@"(equal? 7 (begin (define d (NSMutableDictionary:dictionary)) (NSMutableDictionary:setObjectForKey d 7 \"height\") (NSDictionary:objectForKey d \"height\")))");
  OSAssertTrue(@"(equal? (NSArray:array \"age\") (NSDictionary:keys (NSDictionary:dictionaryWithObjectsAndKeys 3 \"age\")))");
}

- (void)testNSArrayBridge {
  id source, program, returnValue;
  NSNumber* number;

  OSAssertTrue(@"(NSArray:array)");
  OSAssertTrue(@"(equal? 0 (NSArray:count (NSArray:array)))");
  OSAssertTrue(@"(equal? 1 (NSArray:count (NSArray:array 'a)))");
  OSAssertTrue(@"(equal? 2 (NSArray:count (NSMutableArray:array 6 7)))");
  OSAssertTrue(@"(equal? 6 (NSArray:objectAtIndex (NSArray:array 6 7) 0))");
  OSAssertTrue(@"(equal? 7 (NSArray:objectAtIndex (NSArray:array 6 7) 1))");
  OSAssertEqualsInt(@"(let ((a (NSMutableArray:array 6 7))) (NSMutableArray:setObjectAtIndex a 9 1) (NSArray:objectAtIndex a 1))", 9);

  OSAssertTrue(@"(equal? (list 56 7) (NSArray->list (NSArray:array 56 7)))");
  OSAssertTrue(@"(equal? (NSArray:array 56 7) (list->NSArray (list 56 7)))");
  OSAssertTrue(@"(equal? (NSArray:array 56 7) (list->NSMutableArray (list 56 7)))");

  NSArray* a = [NSArray arrayWithObjects: [NSNumber numberWithInteger: 0], [NSNumber numberWithInteger: 1], [NSNumber numberWithInteger: 2], nil];
  OSAssertEquals(@"(NSArray:subarrayFromIndexToIndex (NSArray:array 0 1 2 3) 0 -1)", a);
}

- (void)testStringFunctions {
  id source, program, returnValue;

  OSAssertTrue(@"(equal? (list \"a\" \"b\") (string-split \"a-b\" \"-\"))");
  OSAssertTrue(@"(string-startswith? \"garble\" \"gar\")");
  OSAssertFalse(@"(string-startswith? \"gar\" \"garble\")");

  OSAssertTrue(@"(string-endswith? \"garble\" \"ble\")");
  OSAssertFalse(@"(string-startswith? \"ble\" \"garble\")");

  OSAssertTrue(@"(equal? \"foo\" (->string \"foo\"))");
  OSAssertTrue(@"(equal? \"#t\" (->string #t))");
  OSAssertTrue(@"(equal? \"1\" (->string 1))");

  OSAssertEquals(@"(format \"the {} thing\" 1)", @"the 1 thing");
  OSAssertEquals(@"(format \"the {0} thing\" 1)", @"the 1 thing");
  OSAssertEquals(@"(format \"the {0} thing {1} like\" 1 \"I\")", @"the 1 thing I like");
}

- (void)testQuotedPairs {
  id source, program, returnValue;

  OSAssertEquals(@"'(a . b)", EXEC(@"(cons 'a 'b)"));
  OSAssertTrue(@"(equal? (cons 'a 'b) '(a . b))");
}

- (void)testGarbageCollectionIndirectly {
  id aScope = EXEC(@"(the-environment)");
  STAssertTrue([aScope isKindOfClass: [ObSScope class]], @"wow, it's not a scope?" );

  NSAutoreleasePool* autoreleasePool = [[NSAutoreleasePool alloc] init];
  aScope = EXEC(@"(let* ((x (lambda () #t))) (the-environment))");
  [autoreleasePool drain];

  STAssertTrue([aScope retainCount] == 2, @"Leak should mean we have RC of 2 (the GC keeps one ref, lambda the other), not %d", [aScope retainCount]);

  [aScope retain];
  [[ObjScheme globalScope] gc];

  STAssertTrue([aScope retainCount] == 2, @"GC should break the lambda-scope retain cycle, but we retained it, so GC hasn't let go yet, so it should be 2 not %d", [aScope retainCount]);
  [aScope release];
}

- (void)testGarbageCollectionDirectly {
  __block BOOL rootGone = NO;
  __block BOOL secondaryGone = NO;
  __block BOOL tertiaryGone = NO;

  __block MockCollectible* root = [MockCollectible new];
  __block MockCollectible* secondary = [MockCollectible new];
  __block MockCollectible* tertiary = [MockCollectible new];

  root.onDealloc = ^(){ rootGone = YES; };

  secondary.onReleaseChildren = ^() { [tertiary release]; };
  secondary.onDealloc = ^() { secondaryGone = YES; };

  tertiary.onReleaseChildren = ^() { [secondary release]; };
  tertiary.onDealloc = ^() { tertiaryGone = YES; };

  ObSGarbageCollector* gc = [[ObSGarbageCollector alloc] initWithRoot: root];
  [gc startTracking: secondary];
  [gc startTracking: tertiary];
  [gc runGarbageCollection];

  STAssertTrue(secondaryGone, @"shit, secondary didn't die!");
  STAssertTrue(tertiaryGone, @"shit, secondary didn't die!");
  STAssertFalse(rootGone, @"shit, secondary didn't die!");

  [root release];
  [gc release];
}

@end
