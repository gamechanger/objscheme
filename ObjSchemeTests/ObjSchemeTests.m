//
//  ObjSchemeTests.m
//  ObjSchemeTests
//
//  Created by Kiril Savino on 7/30/12.
//  Copyright (c) 2012 GameChanger. All rights reserved.
//

#import "ObjSchemeTests.h"
#import "ObjScheme.h"

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

  source = @"(not #f)";
  program = [ObjScheme parseString: source];
  returnValue = [[ObjScheme globalScope] evaluate: program];
  STAssertFalse( [ObjScheme isFalse: returnValue], @"return value was false, should be #t %@", returnValue);

  source = @"(+ 1 2)";
  program = [ObjScheme parseString: source];
  returnValue = [[ObjScheme globalScope] evaluate: program];
  STAssertTrue([returnValue isKindOfClass: [NSNumber class]], @"(+ 1 2) isn't a number");
  NSNumber* number = returnValue;
  STAssertEquals(0, strcmp([number objCType], @encode(int)), @"(+ 1 2) isn't an int");
  STAssertEquals([number intValue], 3, @"(+ 1 2) => %d", [number intValue]);

  source = @"(+ 1.0 2.0)";
  program = [ObjScheme parseString: source];
  returnValue = [[ObjScheme globalScope] evaluate: program];
  STAssertTrue([returnValue isKindOfClass: [NSNumber class]], @"%@ isn't a number", source);
  number = returnValue;
  STAssertEquals(strcmp([number objCType], @encode(float)), 0, @"%@  isn't a float", source);
  STAssertEquals([number floatValue], 3.0f, @"%@ => %d", source, [number floatValue]);


  source = @"(* 5 7)";
  program = [ObjScheme parseString: source];
  returnValue = [[ObjScheme globalScope] evaluate: program];
  STAssertTrue([returnValue isKindOfClass: [NSNumber class]], @"%@ isn't a number", source);
  number = returnValue;
  STAssertEquals(strcmp([number objCType], @encode(int)), 0, @"%@ isn't an int", source);
  STAssertEquals([number intValue], 35, @"%@ => %d", source, [number intValue]);

  source = @"(/ 5 7)";
  program = [ObjScheme parseString: source];
  returnValue = [[ObjScheme globalScope] evaluate: program];
  STAssertTrue([returnValue isKindOfClass: [NSNumber class]], @"%@ isn't a number", source);
  number = returnValue;
  STAssertEquals(strcmp([number objCType], @encode(int)), 0, @"%@ isn't an int", source);
  STAssertEquals([number intValue], 0, @"%@ => %d", source, [number intValue]);

  source = @"(/ 5 2)";
  program = [ObjScheme parseString: source];
  returnValue = [[ObjScheme globalScope] evaluate: program];
  STAssertTrue([returnValue isKindOfClass: [NSNumber class]], @"%@ isn't a number", source);
  number = returnValue;
  STAssertEquals(strcmp([number objCType], @encode(int)), 0, @"%@ isn't an int", source);
  STAssertEquals([number intValue], 2, @"%@ => %d", source, [number intValue]);

  source = @"(/ 5.0 2)";
  program = [ObjScheme parseString: source];
  returnValue = [[ObjScheme globalScope] evaluate: program];
  STAssertTrue([returnValue isKindOfClass: [NSNumber class]], @"%@ isn't a number", source);
  number = returnValue;
  STAssertEquals(strcmp([number objCType], @encode(float)), 0, @"%@ isn't a float", source);
  STAssertEqualsWithAccuracy([number floatValue], 2.5f, 0.01, @"%@ => %f", source, [number floatValue]);

  source = @"(/ 5 2.0)";
  program = [ObjScheme parseString: source];
  returnValue = [[ObjScheme globalScope] evaluate: program];
  STAssertTrue([returnValue isKindOfClass: [NSNumber class]], @"%@ isn't a number", source);
  number = returnValue;
  STAssertEquals(strcmp([number objCType], @encode(float)), 0, @"%@ isn't a float", source);
  STAssertEqualsWithAccuracy([number floatValue], 2.5f, 0.01, @"%@ => %f", source, [number floatValue]);

  source = @"()";
}

/*
- (void)testExample
{
    STFail(@"Unit tests are not implemented yet in ObjSchemeTests");
}
*/

@end
