//
//  PPFXBusObject.h
//  PPMacho
//
//  Created by C.W. Betts on 1/8/14.
//
//

#import <Foundation/Foundation.h>
#include <PlayerPROCore/PlayerPROCore.h>

@interface PPFXBusObject : NSObject
@property BOOL bypass;
@property short copyId;
@property (getter = isActive) BOOL active;
@property (readonly) FXBus theBus;

- (id)initWithFXBus:(FXBus *)set;

@end
