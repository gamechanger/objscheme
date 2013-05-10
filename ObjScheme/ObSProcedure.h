//
// ObSProcedure.h
// GameChanger
//
// Created by Kiril Savino on Tuesday, April 16, 2013
// Copyright 2013 GameChanger. All rights reserved.
//

@class ObSSymbol;
@class ObSCons;
@class ObSScope;

@protocol ObSProcedure <NSObject>
- (id)callWith:(ObSCons*)args;
- (ObSSymbol*)name;
@end
