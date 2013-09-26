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
@property (nonatomic, retain) id car;
@property (nonatomic, retain) id cdr;

+ (ObSCons*)cons:(id)a and:(id)b;
- (id)initWithCar:(id)car cdr:(id)cdr;
- (id)cadr;
- (id)caddr;
- (id)cddr;
- (id)cdddr;
- (NSArray*)toArray;
- (NSUInteger)count;
- (ObSCons*)clone;
@end
