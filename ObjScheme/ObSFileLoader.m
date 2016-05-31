//
// ObSFileLoader.m
// GameChanger
//
// Created by Kiril Savino on Tuesday, April 16, 2013
// Copyright 2013 GameChanger. All rights reserved.
//

#import "ObSFileLoader.h"
#import "ObSInPort.h"


@implementation ObSBundleFileLoader

- (ObSInPort*)findFile:(NSString*)path {
  if ( ! [[NSFileManager defaultManager] isReadableFileAtPath: path] ) {
    return nil;
  }

  NSData* data = [NSData dataWithContentsOfFile: path];
  if ( data == nil ) {
    return nil;
  }

  return [[[ObSInPort alloc] initWithData: data] autorelease];
}

- (NSString*)qualifyFileName:(NSString*)filename {
  if ( [filename hasSuffix: @".scm"] ) {
    filename = [filename substringWithRange: NSMakeRange(0, [filename length]-4)];
  }

  return [[NSBundle bundleForClass:self.class] pathForResource: filename ofType: @"scm"];
}

@end






@implementation ObSFilesystemFileLoader

- (id)initWithPath:(NSString*)path {
  if ( self = [super init] ) {
    _directoryPath = [[[path stringByResolvingSymlinksInPath]
                        stringByStandardizingPath]
                       retain];
  }
  return self;
}

- (void)dealloc {
  [_directoryPath release];
  [super dealloc];
}

- (ObSInPort*)findFile:(NSString*)path {
  if ( ! [[NSFileManager defaultManager] isReadableFileAtPath: path] ) {
    return nil;
  }

  NSError* error = nil;
  NSString* source = [[NSString alloc] initWithContentsOfFile: path
                                                     encoding: NSUTF8StringEncoding
                                                        error: &error];
  if ( error != nil ) {
    if ( source != nil ) {
      [source release];
    }
    return nil;
  }

  return [[[ObSInPort alloc] initWithString: [source autorelease]] autorelease];
}

- (NSString*)qualifyFileName:(NSString*)filename {
  return [[_directoryPath stringByAppendingPathComponent: filename] stringByStandardizingPath];
}

+ (ObSFilesystemFileLoader*)loaderForPath:(NSString*)path {
  return [[[ObSFilesystemFileLoader alloc] initWithPath: path] autorelease];
}

@end

