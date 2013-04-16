//
// ObSInPort.m
// GameChanger
//
// Created by Kiril Savino on Tuesday, April 16, 2013
// Copyright 2013 GameChanger. All rights reserved.
//

#import "ObSInPort.h"
#import "ObjScheme.h"

NSString* _EOF = @"#EOF#";

@implementation ObSInPort

@synthesize cursor=_cursor;

- (id)initWithString:(NSString*)string {
  if ( (self = [super init]) ) {
    _data = [string copy];
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
  case '[':  return S_OPENBRACKET;
  case ']':  return S_CLOSEBRACKET;
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

