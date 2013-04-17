//
// ObSLambda.h
// GameChanger
//
// Created by Kiril Savino on Tuesday, April 16, 2013
// Copyright 2013 GameChanger. All rights reserved.
//

#import "ObSProcedure.h"
#import "ObSCollectible.h"

@class ObSSymbol;
@class ObSCons;
@class ObSScope;


@protocol ObSUnaryLambda <NSObject>
- (id)callNatively:(id)arg;
@end


@interface ObSLambda : ObSCollectible <ObSProcedure> {
  ObSSymbol* _listParameter;
  ObSCons* _parameters;
  id _expression;
  ObSScope* _scope;
  ObSSymbol* _name;
  ObSScope* _invocationScope;
  BOOL _scopeInUse;
}

@property (readonly) ObSSymbol* listParameter;
@property (readonly) ObSCons* parameters;
@property (readonly) id expression;
@property (readonly) ObSScope* scope;
@property (readonly) ObSSymbol* name;

- (id)initWithParameters:(id)parameters
              expression:(id)expression
                   scope:(ObSScope*)scope
                    name:(ObSSymbol*)name;
- (id)callWith:(ObSCons*)arguments;
@end




typedef id (^ObSNativeBlock)(NSArray*);

@interface ObSNativeLambda : NSObject <ObSProcedure> {
  ObSNativeBlock _block;
  ObSSymbol* _name;
}

@property (readonly) ObSSymbol* name;

+ (id)named:(ObSSymbol*)name fromBlock:(ObSNativeBlock)block;
- (id)initWithBlock:(ObSNativeBlock)block name:(ObSSymbol*)name;
- (id)callWith:(ObSCons*)arguments;
- (ObSNativeBlock)nativeBlock;

@end



typedef id (^ObSNativeBinaryBlock)(id,id);

@interface ObSNativeBinaryLambda : NSObject <ObSProcedure> {
  ObSNativeBinaryBlock _block;
  ObSSymbol* _name;
}

@property (readonly) ObSSymbol* name;

+ (id)named:(ObSSymbol*)name fromBlock:(ObSNativeBinaryBlock)block;
- (id)initWithBlock:(ObSNativeBinaryBlock)block name:(ObSSymbol*)name;
- (id)callWith:(ObSCons*)arguments;

@end





typedef id (^ObSNativeUnaryBlock)(id);

@interface ObSNativeUnaryLambda : NSObject <ObSProcedure,ObSUnaryLambda> {
  ObSNativeUnaryBlock _block;
  ObSSymbol* _name;
}

@property (readonly) ObSSymbol* name;

+ (id)named:(ObSSymbol*)name fromBlock:(ObSNativeUnaryBlock)block;
- (id)initWithBlock:(ObSNativeUnaryBlock)block name:(ObSSymbol*)name;
- (id)callWith:(ObSCons*)arguments;

@end




typedef id (^ObSNativeThunkBlock)();

@interface ObSNativeThunkLambda : NSObject <ObSProcedure> {
  ObSNativeThunkBlock _block;
  ObSSymbol* _name;
}

@property (readonly) ObSSymbol* name;

+ (id)named:(ObSSymbol*)name fromBlock:(ObSNativeThunkBlock)block;
- (id)initWithBlock:(ObSNativeThunkBlock)block name:(ObSSymbol*)name;
- (id)callWith:(ObSCons*)arguments;

@end
