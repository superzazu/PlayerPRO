/*
 *  PPPrivate.h
 *  PlayerPROCore
 *
 *  Created by C.W. Betts on 6/30/09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */

#ifndef __PLAYERPROCORE_PPPRIVATE__
#define __PLAYERPROCORE_PPPRIVATE__

#include "RDriver.h"

#pragma mark Core Audio Functions
OSErr initCoreAudio( MADDriverRec *inMADDriver, long init);
OSErr closeCoreAudio( MADDriverRec *inMADDriver);
void StopChannelCA(MADDriverRec *inMADDriver);
void PlayChannelCA(MADDriverRec *inMADDriver);

#ifdef _MAC_H
CFMutableArrayRef GetDefaultPluginFolderLocations();

void GetPStrFromCFString(const CFStringRef source, StringPtr pStrOut);
void **GetCOMPlugInterface(CFPlugInRef plugToTest, CFUUIDRef TypeUUID, CFUUIDRef InterfaceUUID);


const CFStringRef kMadPlugMenuNameKey;
const CFStringRef kMadPlugAuthorNameKey;
const CFStringRef kMadPlugUTITypesKey;
const CFStringRef kMadPlugModeKey;
const CFStringRef kMadPlugTypeKey;
#endif

#ifdef _ESOUND
OSErr initESD( MADDriverRec *inMADDriver, long init);
OSErr closeESD( MADDriverRec *inMADDriver);
void StopChannelESD(MADDriverRec *inMADDriver);
void PlayChannelESD(MADDriverRec *inMADDriver);
#endif

#ifdef _OSSSOUND
OSErr initOSS( MADDriverRec *inMADDriver, long init);
OSErr closeOSS( MADDriverRec *inMADDriver);
void StopChannelOSS(MADDriverRec *inMADDriver);
void PlayChannelOSS(MADDriverRec *inMADDriver);
#endif

#ifdef __LINUX__
OSErr initALSA( MADDriverRec *inMADDriver, long init);
OSErr closeALSA( MADDriverRec *inMADDriver);
void StopChannelALSA(MADDriverRec *inMADDriver);
void PlayChannelALSA(MADDriverRec *inMADDriver);
#endif


#endif
