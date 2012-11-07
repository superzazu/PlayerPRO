/*
 *  Mac-CoreAudio.c
 *  PlayerPRO tryout
 *
 *  Created by C.W. Betts on 6/19/09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */

#include <Carbon/Carbon.h>
#include "RDriver.h"
#include "PPPrivate.h"

static Ptr CABuffer = NULL;

//TODO: we should probably do something to prevent thread contention
static OSStatus     CAAudioCallback (void                            *inRefCon,
									 AudioUnitRenderActionFlags      *ioActionFlags,
									 const AudioTimeStamp            *inTimeStamp,
									 UInt32                          inBusNumber,
									 UInt32                          inNumberFrames,
									 AudioBufferList                 *ioData)
{
	MADDriverRec *theRec = (MADDriverRec*)inRefCon;
	
	UInt32 remaining, len;
    AudioBuffer *abuf;
    void *ptr;
    UInt32 i = 0;
	int j = 0;
	for (i = 0; i < ioData->mNumberBuffers; i++) {
        abuf = &ioData->mBuffers[i];
        remaining = abuf->mDataByteSize;
        ptr = abuf->mData;
        while (remaining > 0) {
            if (theRec->CABufOff >= theRec->CABufLen) {
                if( !DirectSave( CABuffer, NULL, theRec))
				{
					switch( theRec->DriverSettings.outPutBits)
					{
						case 8:
							for( j = 0; j < theRec->CABufLen; j++) CABuffer[ j] = 0x80;
							break;
							
						case 16:
							for( j = 0; j < theRec->CABufLen; j++) CABuffer[ j] = 0;
							break;
					}
				}
				theRec->CABufOff = 0;
            }
			
            len = theRec->CABufLen - theRec->CABufOff;
            if (len > remaining)
                len = remaining;
            memcpy(ptr, (char *)CABuffer + theRec->CABufOff, len);
            ptr = (char *)ptr + len;
            remaining -= len;
            theRec->CABufOff += len;
        }
    }
	
	/*if( BuffSize - pos > tickadd)	theRec->OscilloWavePtr = CABuffer + (int)pos;
	else */ theRec->OscilloWavePtr = CABuffer;
	return noErr;
}

OSErr initCoreAudio( MADDriverRec *inMADDriver, long init)
{
	inMADDriver->CABufLen = inMADDriver->CABufOff = inMADDriver->BufSize;
	CABuffer = NewPtrClear(inMADDriver->CABufLen);
	
	OSStatus result = noErr;
	struct AURenderCallbackStruct callback;
	callback.inputProc = CAAudioCallback;
	callback.inputProcRefCon = inMADDriver;
    ComponentDescription theDes;
	theDes.componentType = kAudioUnitType_Output;
    theDes.componentSubType = kAudioUnitSubType_DefaultOutput;
    theDes.componentManufacturer = kAudioUnitManufacturer_Apple;
    theDes.componentFlags = 0;
    theDes.componentFlagsMask = 0;
	AudioStreamBasicDescription audDes = {0};
	audDes.mFormatID = kAudioFormatLinearPCM;
	audDes.mFormatFlags = kLinearPCMFormatFlagIsPacked;
	audDes.mFormatFlags |= kLinearPCMFormatFlagIsSignedInteger;
#ifdef __BIG_ENDIAN__
	audDes.mFormatFlags |= kLinearPCMFormatFlagIsBigEndian;
#endif

	int outChn = 0;
	switch (inMADDriver->DriverSettings.outPutMode) {
		case MonoOutPut:
			outChn = 1;
			break;
			
		case StereoOutPut:
		case DeluxeStereoOutPut:
		default:
			outChn = 2;
			break;
			
		case PolyPhonic:
			outChn = 4;
			break;
	}
	audDes.mChannelsPerFrame = outChn;
	audDes.mSampleRate = FixedToFloat(inMADDriver->DriverSettings.outPutRate);
	audDes.mBitsPerChannel = inMADDriver->DriverSettings.outPutBits;
	audDes.mFramesPerPacket = 1;
    audDes.mBytesPerFrame = audDes.mBitsPerChannel * audDes.mChannelsPerFrame / 8;
    audDes.mBytesPerPacket = audDes.mBytesPerFrame * audDes.mFramesPerPacket;

	
	Component comp = FindNextComponent (NULL, &theDes);

	if (comp == NULL) {
		return MADUnknownErr;
	}
	result = OpenAComponent(comp, &inMADDriver->CAAudioUnit);
	
	
	result = AudioUnitSetProperty (inMADDriver->CAAudioUnit,
								   kAudioUnitProperty_StreamFormat,
								   kAudioUnitScope_Input,
								   0,
								   &audDes,
								   sizeof (audDes));
	
	result = AudioUnitSetProperty(inMADDriver->CAAudioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callback, sizeof(callback));

	
	result = AudioUnitInitialize(inMADDriver->CAAudioUnit);
	
	result = AudioOutputUnitStart(inMADDriver->CAAudioUnit);
	return noErr;
}

OSErr closeCoreAudio( MADDriverRec *inMADDriver)
{
	struct AURenderCallbackStruct callback;
	callback.inputProc = NULL;
	callback.inputProcRefCon = NULL;
	
	OSStatus result = AudioOutputUnitStop(inMADDriver->CAAudioUnit);
	if (result != noErr) {
		
	}
	result = AudioUnitSetProperty(inMADDriver->CAAudioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callback, sizeof(callback));
	if (result != noErr)
	{
		
	}
	result = CloseComponent(inMADDriver->CAAudioUnit);
	if (result != noErr) {
		
	}
	inMADDriver->OscilloWavePtr = NULL;
	if (CABuffer) {
		DisposePtr(CABuffer);
	}
	return noErr;
}
