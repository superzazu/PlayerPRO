//
//  PPMINsPlug.m
//  PPMacho
//
//  Created by C.W. Betts on 9/21/14.
//
//

#import "PPMINsPlug.h"
#include <PlayerPROCore/PlayerPROCore.h>
#import <PlayerPROKit/PlayerPROKit.h>

#define BYTESWAP_STRIDE 8

@interface PPInstrumentObject (private)
- (InstrData)theInstrument;
@end

static inline void ByteswapsData(sData *toswap)
{
	MADBE32(&toswap->size);
	MADBE16(&toswap->c2spd);
	MADBE32(&toswap->loopBeg);
	MADBE32(&toswap->loopSize);
}

static inline void ByteswapsData32(sData32 *toswap)
{
	MADBE32(&toswap->size);
	MADBE16(&toswap->c2spd);
	MADBE32(&toswap->loopBeg);
	MADBE32(&toswap->loopSize);
}

static inline void ByteswapInstrument(InstrData *toswap)
{
	MADBE16(&toswap->MIDIType);
	MADBE16(&toswap->MIDI);
	MADBE16(&toswap->firstSample);
	MADBE16(&toswap->numSamples);
	MADBE16(&toswap->volFade);
	
	for (int i = 0; i < 12; i++) {
		MADBE16(&toswap->pannEnv[i].pos);
		MADBE16(&toswap->pannEnv[i].val);
		MADBE16(&toswap->pitchEnv[i].pos);
		MADBE16(&toswap->pitchEnv[i].val);
		MADBE16(&toswap->volEnv[i].pos);
		MADBE16(&toswap->volEnv[i].val);
	}
}

static inline OSErr TestMINS(const InstrData *CC)
{
	if (CC->type == 0 && CC->numSamples >= 0 && CC->numSamples < MAXSAMPLE)
		return MADNoErr;
	else
		return MADFileNotSupportedByThisPlug;
}

@implementation PPMINsPlug

- (BOOL)hasUIForExport
{
	return NO;
}

- (BOOL)hasUIForImport
{
	return NO;
}

- (instancetype)initForPlugIn
{
	return self = [self init];
}

- (BOOL)canImportInstrumentAtURL:(NSURL *)sampleURL
{
	NSFileHandle *readHandle = [NSFileHandle fileHandleForReadingFromURL:sampleURL error:NULL];
	if (!readHandle) {
		return NO;
	}
	size_t inOutCount = sizeof(InstrData);
	//void *theSound = malloc(inOutCount);
	NSMutableData *theSound = [[readHandle readDataOfLength:inOutCount] mutableCopy];
	ByteswapInstrument(theSound.mutableBytes);
	return TestMINS(theSound.bytes) == MADNoErr;
}

-(BOOL)importInstrumentAtURL:(NSURL *)sampleURL instrument:(out PPInstrumentObject *__autoreleasing *)outHeader driver:(PPDriver *)driver error:(NSError * _Nullable __autoreleasing * _Nonnull)error
{
	NSError *otherErr = nil;
	NSFileHandle *readHandle = [NSFileHandle fileHandleForReadingFromURL:sampleURL error:&otherErr];
	if (!readHandle) {
		if (error) {
			*error = [NSError errorWithDomain:PPMADErrorDomain code:MADReadingErr userInfo:@{NSUnderlyingErrorKey: otherErr}];
		}
		
		return NO;
	}
	PPInstrumentObject *InsHeader = [PPInstrumentObject new];
	
	[InsHeader resetInstrument];
	size_t inOutCount = sizeof(InstrData);
	NSMutableData *aHeader = [[readHandle readDataOfLength:inOutCount] mutableCopy];
	if (aHeader.length != inOutCount) {
		if (error) {
			*error = [NSError errorWithDomain:PPMADErrorDomain code:MADIncompatibleFile userInfo:nil];
		}
		
		return NO;
	}
	ByteswapInstrument(aHeader.mutableBytes);
	const InstrData *ourData = aHeader.bytes;
	{
		InsHeader.name = [NSString stringWithCString:ourData->name encoding:NSMacOSRomanStringEncoding];
		memcpy(InsHeader.what, ourData->what, 96);
		for (int i = 0; i < 12; i++) {
			[InsHeader replaceObjectInPanningEnvelopeAtIndex:i withObject:[[PPEnvelopeObject alloc] initWithEnvRec:ourData->pannEnv[i]]];
			[InsHeader replaceObjectInVolumeEnvelopeAtIndex:i withObject:[[PPEnvelopeObject alloc] initWithEnvRec:ourData->volEnv[i]]];
			[InsHeader replaceObjectInPitchEnvelopeAtIndex:i withObject:[[PPEnvelopeObject alloc] initWithEnvRec:ourData->pitchEnv[i]]];
		}
		InsHeader.volumeType = ourData->volType;
		InsHeader.panningType = ourData->pannType;
		
		InsHeader.volumeSize = ourData->volSize;
		InsHeader.panningSize = ourData->pannSize;
		InsHeader.pitchSize = ourData->pitchSize;
		
		InsHeader.volumeSustain = ourData->volSus;
		InsHeader.volumeBegin = ourData->volBeg;
		InsHeader.volumeEnd = ourData->volEnd;
		
		InsHeader.panningSustain = ourData->pannSus;
		InsHeader.panningBegin = ourData->pannBeg;
		InsHeader.panningEnd = ourData->pannEnd;
		
		InsHeader.pitchSustain = ourData->pitchSus;
		InsHeader.pitchBegin = ourData->pitchBeg;
		InsHeader.pitchEnd = ourData->pitchEnd;
		
		InsHeader.volumeFadeOut = ourData->volFade;
		
		InsHeader.vibratoDepth = ourData->vibDepth;
		InsHeader.vibratoRate = ourData->vibRate;
		
		InsHeader.MIDI = ourData->MIDI;
		
		switch (ourData->MIDIType) {
			case 0:
			default:
				InsHeader.MIDIOut = NO;
				InsHeader.soundOut = YES;
				break;
				
			case 1:
				InsHeader.MIDIOut = YES;
				InsHeader.soundOut = NO;
				break;
				
			case 2:
				InsHeader.MIDIOut = YES;
				InsHeader.soundOut = YES;
				break;
				
			case 3:
				InsHeader.MIDIOut = NO;
				InsHeader.soundOut = NO;
				break;
		}
		
	}
	
	for (int x = 0; x < ourData->numSamples; x++) {
		sData *curData = MADCreateSampleRaw();
		inOutCount = sizeof(sData32);
		aHeader = [[readHandle readDataOfLength:inOutCount] mutableCopy];
		if (aHeader.length != inOutCount) {
			if (error) {
				*error = [NSError errorWithDomain:PPMADErrorDomain code:MADIncompatibleFile userInfo:nil];
			}
			
			return NO;
		}
		ByteswapsData(aHeader.mutableBytes);
		memcpy(curData, aHeader.bytes, inOutCount);
		
		inOutCount = curData->size;
		// Don't leak.
		free(curData->data); curData->data = NULL;
		curData->data = malloc(inOutCount);
		NSData *sampData = [readHandle readDataOfLength:inOutCount];
		if (sampData.length != inOutCount) {
			if (error) {
				*error = [NSError errorWithDomain:PPMADErrorDomain code:MADIncompatibleFile userInfo:nil];
			}
			
			return NO;
		}
		memcpy(curData->data, sampData.bytes, inOutCount);
#if __LITTLE_ENDIAN__
		if (curData->amp == 16) {
			short	*shortPtr = (short*)curData->data;
			dispatch_apply((curData->size / 2) / BYTESWAP_STRIDE, dispatch_get_global_queue(0, 0), ^(size_t i) {
				size_t j = i * BYTESWAP_STRIDE;
				
				MADBE16(&shortPtr[j+0]);
				MADBE16(&shortPtr[j+1]);
				MADBE16(&shortPtr[j+2]);
				MADBE16(&shortPtr[j+3]);
				MADBE16(&shortPtr[j+4]);
				MADBE16(&shortPtr[j+5]);
				MADBE16(&shortPtr[j+6]);
				MADBE16(&shortPtr[j+7]);
			});
			for (int ll = (curData->size / 2) - ((curData->size / 2) % BYTESWAP_STRIDE); ll < curData->size / 2; ll++) {
				MADBE16(&shortPtr[ll]);
			}
		}
#endif
		
		[InsHeader addSampleObject:[[PPSampleObject alloc] initWithSData:curData]];
		free(curData->data);
		free(curData);
	}
	*outHeader = InsHeader;
	
	return YES;
}

- (BOOL)exportInstrument:(PPInstrumentObject *)InsHeader toURL:(NSURL *)sampleURL driver:(PPDriver *)driver error:(NSError * _Nullable __autoreleasing * _Nonnull)error
{
	NSError *otherErr = nil;
	NSFileHandle *fileHand = [NSFileHandle fileHandleForWritingToURL:sampleURL error:&otherErr];
	if (fileHand == nil) {
		if (error) {
			*error = [NSError errorWithDomain:PPMADErrorDomain code:MADWritingErr userInfo:@{NSUnderlyingErrorKey: otherErr}];
		}
		
		return NO;
	}
	size_t inOutCount = sizeof(InstrData);
	InstrData *tempIns = malloc(inOutCount);
	InstrData headerData = [InsHeader theInstrument];
	memcpy(tempIns, &headerData, sizeof(InstrData));
	ByteswapInstrument(tempIns);
	[fileHand writeData:[NSData dataWithBytesNoCopy:tempIns length:inOutCount]];
	for (PPSampleObject *samp in [InsHeader samples]) {
		sData32 toWrite = {0};
		toWrite.amp = samp.amplitude;
		toWrite.c2spd = samp.c2spd;
		toWrite.loopBeg = samp.loopBegin;
		toWrite.loopSize = samp.loopSize;
		toWrite.loopType = samp.loopType;
		toWrite.realNote = samp.realNote;
		toWrite.stereo = samp.stereo;
		toWrite.vol = samp.volume;
		toWrite.size = (int)[samp.data length];
		strlcpy(toWrite.name, [samp.name cStringUsingEncoding:NSMacOSRomanStringEncoding], sizeof(toWrite.name));
		ByteswapsData32(&toWrite);
		
		[fileHand writeData:[NSData dataWithBytes:&toWrite length:sizeof(sData32)]];
		
		NSMutableData *sDataData = [samp.data mutableCopy];
#if __LITTLE_ENDIAN__
		if (samp.amplitude == 16) {
			short	*shortPtr = (short*)sDataData.mutableBytes;
			dispatch_apply((sDataData.length / 2) / BYTESWAP_STRIDE, dispatch_get_global_queue(0, 0), ^(size_t i) {
				size_t j = i * BYTESWAP_STRIDE;

				MADBE16(&shortPtr[j+0]);
				MADBE16(&shortPtr[j+1]);
				MADBE16(&shortPtr[j+2]);
				MADBE16(&shortPtr[j+3]);
				MADBE16(&shortPtr[j+4]);
				MADBE16(&shortPtr[j+5]);
				MADBE16(&shortPtr[j+6]);
				MADBE16(&shortPtr[j+7]);
			});
			for (NSInteger i = (sDataData.length / 2) - ((sDataData.length / 2) % BYTESWAP_STRIDE); i < sDataData.length / 2; i++) {
				MADBE16(&shortPtr[i]);
			}
		}
#endif
		[fileHand writeData:sDataData];
	}
	[fileHand closeFile];
	
	return YES;
}

@end
