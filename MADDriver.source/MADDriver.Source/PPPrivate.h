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

#ifdef __cplusplus
extern "C" {
#endif
	
/********************						***********************/
/*** 					INTERNAL ROUTINES						***/
/***			    DO NOT use these routines					***/
/********************						***********************/

/*** Deluxe ***/

void	MADCreateOverShoot( MADDriverRec *intDriver);
void	MADKillOverShoot( MADDriverRec *intDriver);
void 	Sampler16AddDeluxe( Channel *curVoice, register SInt32	*ASCBuffer, MADDriverRec *intDriver);
void 	Sampler16Addin16Deluxe( Channel *curVoice, register SInt32	*ASCBuffer, MADDriverRec *intDriver);
void 	Sample16BufferAddDeluxe( Channel *curVoice, register SInt32	*ASCBuffer, MADDriverRec *intDriver);
void 	Play16StereoDeluxe( MADDriverRec *intDriver);
void 	Sampler8in8AddDeluxe( Channel *curVoice, register short	*ASCBuffer, MADDriverRec *intDriver);
void 	Sampler8in16AddDeluxe( Channel *curVoice, register short	*ASCBuffer, MADDriverRec *intDriver);
void 	Sample8BufferAddDeluxe( Channel *curVoice, register short *ASCBuffer, MADDriverRec *intDriver);
void 	Play8StereoDeluxe( MADDriverRec *intDriver);

/*** Delay ***/

void Sampler16AddDelay( Channel *curVoice, register SInt32	*ASCBuffer, MADDriverRec *intDriver);
void Sampler16Addin16Delay( Channel *curVoice, register SInt32	*ASCBuffer, MADDriverRec *intDriver);
void Sample16BufferAddDelay( Channel *curVoice, register SInt32	*ASCBuffer, MADDriverRec *intDriver);
void Play16StereoDelay( MADDriverRec *intDriver);
void Sampler8in8AddDelay( Channel *curVoice, register short	*ASCBuffer, MADDriverRec *intDriver);
void Sampler8in16AddDelay( Channel *curVoice, register short	*ASCBuffer, MADDriverRec *intDriver);
void Sample8BufferAddDelay( Channel *curVoice, register short *ASCBuffer, MADDriverRec *intDriver);
void Play8StereoDelay( MADDriverRec *intDriver);

/*** 8 Bits ***/

void 	Sampler8in8Add( Channel *curVoice, register Ptr	ASCBuffer, MADDriverRec *intDriver);
void 	Sampler8in16Add( Channel *curVoice, register Ptr	ASCBuffer, MADDriverRec *intDriver);
void 	Sampler8in8AddPoly( Channel *curVoice, register Ptr	ASCBuffer, short chanNo, MADDriverRec *intDriver);
void 	Sampler8in16AddPoly( Channel *curVoice, register Ptr	ASCBuffer, short chanNo, MADDriverRec *intDriver);
void 	Sample8BufferAdd( Channel *curVoice, register Ptr ASCBuffer, MADDriverRec *intDriver);
void 	Sample8BufferAddPoly( Channel *curVoice, register Ptr ASCBuffer, short chanNo, MADDriverRec *intDriver);
void	Play8Mono( MADDriverRec *intDriver);
void 	Play8Stereo( MADDriverRec *intDriver);
void 	Play8PolyPhonic( MADDriverRec *intDriver);

/*** 16 Bits ***/

void 	Sampler16Add( Channel *curVoice, register short	*ASCBuffer, MADDriverRec* intDriver);
void 	Sampler16Addin16( Channel *curVoice, register short	*ASCBuffer, MADDriverRec* intDriver);
void 	Sample16BufferAdd( Channel *curVoice, register short	*ASCBuffer, MADDriverRec* intDriver);
void 	Play16Stereo( MADDriverRec* intDriver);
void 	Sampler16AddPoly( Channel *curVoice, register short	*ASCBuffer, short chanNo, MADDriverRec* intDriver);
void 	Sampler16Addin16Poly( Channel *curVoice, register short	*ASCBuffer, short chanNo, MADDriverRec* intDriver);
void 	Sample16BufferAddPoly( Channel *curVoice, register short	*ASCBuffer, short chanNo, MADDriverRec* intDriver);
void 	Play16PolyPhonic( MADDriverRec* intDriver);
void 	Play16Mono( MADDriverRec* intDriver);

/*** 20 Bits ***/
//TODO

/*** 24 Bits ***/
//TODO

/*** Effects ***/

void 	DoEffect( Channel *ch, short call, MADDriverRec *intDriver);
void 	SetUpEffect( Channel *ch, MADDriverRec *intDriver);
void DoVolCmd( Channel *ch, short call, MADDriverRec *intDriver);

/*** Interruption Functions ***/

void 	NoteAnalyse( MADDriverRec *intDriver);
void 	ReadNote( Channel *curVoice, Cmd		*theCommand, MADDriverRec *intDriver);
void 	Filter8Bit( register Byte *myPtr, MADDriverRec *intDriver);
void 	Filter8BitX( register Byte *myPtr, MADDriverRec *intDriver);
void 	Filter16BitX( register short *myPtr, MADDriverRec *intDriver);
void 	BufferCopyM( MADDriverRec *intDriver);
void 	BufferCopyS( MADDriverRec *intDriver);
void 	NoteOff(short oldIns, short oldN, short oldV, MADDriverRec *intDriver);
void 	SampleMIDI( Channel *curVoice, short channel, short curN, MADDriverRec *intDriver);
void 	CleanDriver( MADDriverRec *intDriver);

#ifdef _MAC_H
#pragma mark Core Audio Functions
OSErr initCoreAudio( MADDriverRec *inMADDriver);
OSErr closeCoreAudio( MADDriverRec *inMADDriver);
#endif

#ifdef _ESOUND
OSErr initESD( MADDriverRec *inMADDriver);
OSErr closeESD( MADDriverRec *inMADDriver);
void StopChannelESD(MADDriverRec *inMADDriver);
void PlayChannelESD(MADDriverRec *inMADDriver);
#endif

#ifdef _OSSSOUND
OSErr initOSS( MADDriverRec *inMADDriver);
OSErr closeOSS( MADDriverRec *inMADDriver);
void StopChannelOSS(MADDriverRec *inMADDriver);
void PlayChannelOSS(MADDriverRec *inMADDriver);
#endif

#ifdef LINUX
OSErr initALSA( MADDriverRec *inMADDriver);
OSErr closeALSA( MADDriverRec *inMADDriver);
void StopChannelALSA(MADDriverRec *inMADDriver);
void PlayChannelALSA(MADDriverRec *inMADDriver);
#endif

#ifdef WIN32
void DirectSoundClose( MADDriverRec* driver);
Boolean DirectSoundInit( MADDriverRec* driver);
Boolean W95_Init( MADDriverRec* driver);
void W95_Exit( MADDriverRec* driver);
#endif
	
OSErr	CallImportPlug( 	MADLibrary		*inMADDriver,
							short			PlugNo,			// CODE du plug
							OSType			order,
							char			*AlienFile,
							MADMusic		*theNewMAD,
							PPInfoRec		*info);


OSErr	PPTestFile( MADLibrary *inMADDriver, char *kindFile, char *AlienFile);
OSErr	PPInfoFile( MADLibrary *inMADDriver, char *kindFile, char *AlienFile, PPInfoRec	*InfoRec);
OSErr	PPExportFile( MADLibrary *inMADDriver, char	*kindFile, char *AlienFile, MADMusic *theNewMAD);
OSErr	PPImportFile( MADLibrary *inMADDriver, char	*kindFile, char *AlienFile, MADMusic **theNewMAD);
OSErr	PPIdentifyFile( MADLibrary *inMADDriver, char *kindFile, char *AlienFile);

OSType	GetPPPlugType( MADLibrary *inMADDriver, short ID, OSType type);
void	MInitImportPlug( MADLibrary *inMADDriver, char*);	
void	CloseImportPlug( MADLibrary *inMADDriver);
OSErr	MADLoadMADFileCString( MADMusic **, Ptr fName);
OSErr	CheckMADFile( char *AlienFile);

#ifndef __PPPLUGH__
PPEXPORT void ConvertInstrumentIn( register	Byte *tempPtr, register size_t sSize);
#endif

#ifdef __cplusplus
}
#endif


#endif
