//
// ObSCons.h
// GameChanger
//
// Created by Kiril Savino on Tuesday, April 16, 2013
// Copyright 2013 GameChanger. All rights reserved.
//


@interface ObSCons : NSObject <NSFastEnumeration> {
@public
  id _car;
  id _cdr;
}

+ (ObSCons*)cons:(id)a and:(id)b;
- (id)initWithCar:(id)car cdr:(id)cdr;
- (NSArray*)toArray;
- (NSMutableArray*)toMutableArray;
- (NSUInteger)count;
- (ObSCons*)clone;
- (void)setCdr:(id)cdr;
- (void)setCar:(id)car;
@end
