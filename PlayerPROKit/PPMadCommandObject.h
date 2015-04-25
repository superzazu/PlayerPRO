//
//  PPMadCommandObject.h
//  PPMacho
//
//  Created by C.W. Betts on 1/17/13.
//
//

#ifndef __PLAYERPROKIT_PPMADCOMMANDOBJECT_H__
#define __PLAYERPROKIT_PPMADCOMMANDOBJECT_H__

#import <Foundation/Foundation.h>
#include <PlayerPROCore/PlayerPROCore.h>
#import <PlayerPROKit/PPObjectProtocol.h>

#ifndef NS_DESIGNATED_INITIALIZER
#define NS_DESIGNATED_INITIALIZER
#endif

@interface PPMadCommandObject : NSObject <PPObject>

- (nonnull instancetype)init;
- (nonnull instancetype)initWithCmdPtr:(nullable Cmd *)theCmd NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithCmd:(Cmd)theCmd;
- (nonnull instancetype)initWithCoder:(nonnull NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

@property (readonly) Cmd theCommand;
/// Instrument number. \c 0x00 is no instrument command
@property MADByte instrument;
/// Note, see table. \c 0xFF is no note command
@property MADByte note;
/// Effect command
@property MADEffectID command;
/// Effect argument
@property MADByte argument;
/// Volume of the effect. \c 0xFF is no volume command
@property MADByte volume;

- (void)reset;
@end

#endif
