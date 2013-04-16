//
// ObSConstant.h
// GameChanger
//
// Created by Kiril Savino on Tuesday, April 16, 2013
// Copyright 2013 GameChanger. All rights reserved.
//

@interface ObSConstant : NSObject {
  NSString* _name;
}
@property (nonatomic,readonly) NSString* name;
- (id)initWithName:(NSString*)name;
@end
