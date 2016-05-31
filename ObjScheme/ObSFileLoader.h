//
// ObSFileLoader.h
// GameChanger
//
// Created by Kiril Savino on Tuesday, April 16, 2013
// Copyright 2013 GameChanger. All rights reserved.
//

@class ObSInPort;


@protocol ObSFileLoader <NSObject>
- (ObSInPort*)findFile:(NSString*)filename;
- (NSString*)qualifyFileName:(NSString*)filename;
@end



@interface ObSBundleFileLoader : NSObject <ObSFileLoader>

@property (nonatomic, strong, readonly) NSBundle *bundle;

- (instancetype)initWithBundle:(NSBundle *)bundle;

@end



@interface ObSFilesystemFileLoader : NSObject <ObSFileLoader> {
  NSString* _directoryPath;
}
+ (ObSFilesystemFileLoader*)loaderForPath:(NSString*)path;
@end
