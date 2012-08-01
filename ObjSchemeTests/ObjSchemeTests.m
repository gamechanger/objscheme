//
//  ObjSchemeTests.m
//  ObjSchemeTests
//
//  Created by Kiril Savino on 7/30/12.
//  Copyright (c) 2012 Fungo Media / GameChanger. All rights reserved.
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
  STAssertEqualObjects(t, @"(", @"port token initial paren wrong, %@", t);

  t = [port nextToken];
  STAssertEqualObjects(t, @"display", @"port token initial paren wrong, %@", t);

  t = [port nextToken];
  STAssertEqualObjects(t, @"\"hi\"", @"port token initial paren wrong, %@", t);

  t = [port nextToken];
  STAssertEqualObjects(t, @")", @"port token initial paren wrong, %@", t);
}

- (void)testGlobalScope {
  ObSScope* global = [ObjScheme globalScope];
  STAssertEquals(global, [ObjScheme globalScope], @"Global scope isn't unique");
}

/*
- (void)testExample
{
    STFail(@"Unit tests are not implemented yet in ObjSchemeTests");
}
*/

@end
