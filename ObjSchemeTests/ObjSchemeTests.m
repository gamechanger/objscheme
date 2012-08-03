//
//  ObjSchemeTests.m
//  ObjSchemeTests
//
//  Created by Kiril Savino on 7/30/12.
//  Copyright (c) 2012 GameChanger. All rights reserved.
//

#import "ObjSchemeTests.h"
#import "ObjScheme.h"

#define OSAssertFalse(code) source = (code);       \
 program = [ObjScheme parseString: source];\
 returnValue = [[ObjScheme globalScope] evaluate: program];\
 STAssertTrue([ObjScheme isFalse: returnValue], @"%@ => %@", source, returnValue);

#define OSAssertTrue(code) source = (code);       \
 program = [ObjScheme parseString: source];\
 returnValue = [[ObjScheme globalScope] evaluate: program];\
 STAssertTrue(! [ObjScheme isFalse: returnValue], @"%@ => %@", source, returnValue);

#define OSAssertEqualsInt(code, expected) source = (code);     \
 program = [ObjScheme parseString: source];\
 returnValue = [[ObjScheme globalScope] evaluate: program];\
 STAssertTrue([returnValue isKindOfClass: [NSNumber class]], @"%@ => %@", source, returnValue); \
 number = returnValue;\
 STAssertEquals(strcmp([number objCType], @encode(int)), 0, @"%@ => %@", source, returnValue); \
 STAssertEquals([number intValue], (expected), @"%@ => %d", source, [number intValue]);

#define OSAssertEqualsFloat(code, expected) source = (code);     \
 program = [ObjScheme parseString: source];\
 returnValue = [[ObjScheme globalScope] evaluate: program];\
 STAssertTrue([returnValue isKindOfClass: [NSNumber class]], @"%@ isn't a number", source);\
 number = returnValue;\
 STAssertEquals(strcmp([number objCType], @encode(float)), 0, @"%@ isn't a float", source);\
 STAssertEqualsWithAccuracy([number floatValue], (expected), 0.0001, @"%@ => %f not %f, off by %f", source, [number floatValue], (expected), (expected)-[number floatValue]);

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
  STAssertTrue([global hasMacroNamed: SY(@"or")], @"or macro undefined");
  STAssertTrue([global hasMacroNamed: SY(@"and")], @"or macro undefined");
  STAssertTrue([global hasMacroNamed: SY(@"let")], @"let macro undefined");
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

}

- (void)testBuiltIns {
  id source, program, returnValue;
  NSNumber* number;

  OSAssertTrue(@"#t");
  OSAssertTrue(@"(not #f)");

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

  OSAssertFalse(@"(let ((a #f)) a))")
  OSAssertTrue(@"(let ((a #t)) a))")
  OSAssertFalse(@"(null? (let ((x (list #t))) x))");
  OSAssertTrue(@"(null? (let ((x (list))) x))");

  OSAssertTrue(@"(eq? 1 1)");
  OSAssertFalse(@"(eq? 1 2)");
  OSAssertFalse(@"(eq? \"a\" \"a\")");
  OSAssertTrue(@"(let ((a \"a\")) (eq? a a))");

  OSAssertTrue(@"(equal? 1 1)");
  OSAssertFalse(@"(equal? 1 2)");
  OSAssertTrue(@"(equal? \"a\" \"a\")");
  OSAssertFalse(@"(equal? \"a\" \"b\")");
  OSAssertTrue(@"(let ((a \"a\")) (equal? a a))");

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

  OSAssertTrue(@"(list? '())");
  OSAssertTrue(@"(list? '(1 2))");
  OSAssertEqualsInt(@"(length '(1 2))", 2);
  OSAssertTrue(@"(null? '())");
  OSAssertTrue(@"(equal? (list 1 2) '(1 2))");
  OSAssertTrue(@"(equal? (list (list 1 2)) '((1 2)))");

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


}

- (void)testMath {
  id source, program, returnValue;
  NSNumber* number;

  OSAssertEqualsInt(@"(+ 1 2)", 3);
  OSAssertEqualsFloat(@"(+ 1.0 2.0)", 3.0f);

  OSAssertEqualsInt(@"(* 5 7)", 35);
  OSAssertEqualsInt(@"(/ 5 7)", 0);
  OSAssertEqualsInt(@"(/ 5 2)", 2);

  OSAssertEqualsFloat(@"(/ 5.0 2)", 2.5f);
  OSAssertEqualsFloat(@"(/ 5 2.0)", 2.5f);

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
  OSAssertEqualsFloat(@"(abs -1.0)", 1.0f);

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
}

/*
- (void)testExample
{
    STFail(@"Unit tests are not implemented yet in ObjSchemeTests");
}
*/

@end
