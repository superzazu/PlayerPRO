//
//  PPApp_AppDelegate.m
//  PPMacho
//
//  Created by C.W. Betts on 7/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PPApp_AppDelegate.h"
#import "PPPreferences.h"
#import "PPMusicList.h"
#import "UserDefaultKeys.h"
#import "NSColor+PPPreferences.h"
#import "PPErrors.h"
#import "OpenPanelViewController.h"
#import "ARCBridge.h"
#import "PPInstrumentImporter.h"
#import "PPInstrumentImporterObject.h"
#import "PPInstrumentWindowController.h"
#import "PPPlugInInfo.h"
#import "PPPlugInInfoController.h"
#import "PPDigitalPlugInHandler.h"
#import "PPDigitalPlugInObject.h"
#import "PPFilterPlugHandler.h"
#import "PPFilterPlugObject.h"
#import "PatternHandler.h"
#include <PlayerPROCore/RDriverInt.h>
#include "PPByteswap.h"
#import <QTKit/QTKit.h>
#import <QTKit/QTExportSession.h>
#import <QTKit/QTExportOptions.h>

#define kUnresolvableFile @"Unresolvable files"
#define kUnresolvableFileDescription @"There were %lu file(s) that were unable to be resolved."

@interface PPCurrentlyPlayingIndex : NSObject
{
	NSInteger index;
	NSURL *playbackURL;
}

@property (readwrite) NSInteger index;
@property (readwrite, retain) NSURL *playbackURL;

- (void)movePlayingIndexToOtherIndex:(PPCurrentlyPlayingIndex *)othidx;

@end

@implementation PPCurrentlyPlayingIndex

- (void)movePlayingIndexToOtherIndex:(PPCurrentlyPlayingIndex *)othidx
{
	othidx.index = index;
	othidx.playbackURL = playbackURL;
}

@synthesize index;
@synthesize playbackURL;

- (NSString *)description
{
	return [NSString stringWithFormat:@"Index: %ld URL: %@ URL Path: %@", (long)index, playbackURL, [playbackURL path]];
}

#if !__has_feature(objc_arc)
- (void)dealloc
{
	[playbackURL release];
	
	[super dealloc];
}
#endif

@end

static void CocoaDebugStr( short line, Ptr file, Ptr text)
{
	NSLog(@"%s:%u error text:%s!", file, line, text);
	NSInteger alert = NSRunAlertPanel(NSLocalizedString(@"MyDebugStr_Error", @"Error"),
									  [NSString stringWithFormat:NSLocalizedString(@"MyDebugStr_MainText", @"The Main text to display"), text],
									  NSLocalizedString(@"MyDebugStr_Quit", @"Quit"), NSLocalizedString(@"MyDebugStr_Continue", @"Continue"),
									  NSLocalizedString(@"MyDebugStr_Debug", @"Debug"));
	switch (alert) {
		case NSAlertAlternateReturn:
			break;
		case NSAlertOtherReturn:
			//Debugger();
			NSCAssert(NO, @"Chose to go to debugger.");
			break;
		case NSAlertDefaultReturn:
			NSLog(@"Choosing to fail!");
		default:
			abort();
			break;
	}
}

static NSInteger selMusFromList = -1;

@interface PPApp_AppDelegate ()
- (void)selectCurrentlyPlayingMusic;
- (void)selectMusicAtIndex:(NSInteger)anIdx;
- (BOOL)loadMusicURL:(NSURL*)musicToLoad error:(out NSError *__autoreleasing*)theErr;
- (void)musicListContentsDidMove;
- (BOOL)musicListWillChange;
- (void)musicListDidChange;
- (void)moveMusicAtIndex:(NSUInteger)from toIndex:(NSUInteger)to;
@property (readwrite, retain) NSString *musicName;
@property (readwrite, retain) NSString *musicInfo;
@end

@implementation PPApp_AppDelegate
@synthesize paused;
@synthesize window;
@synthesize exportWindow;
@synthesize musicInfo;
@synthesize musicName;

- (BOOL)loadMusicFromCurrentlyPlayingIndexWithError:(out NSError *__autoreleasing*)theErr
{
	currentlyPlayingIndex.playbackURL = [musicList URLAtIndex:currentlyPlayingIndex.index];
	BOOL isGood = [self loadMusicURL:currentlyPlayingIndex.playbackURL error:theErr];
	[currentlyPlayingIndex movePlayingIndexToOtherIndex:previouslyPlayingIndex];
	return isGood;
}

- (void)addMusicToMusicList:(NSURL* )theURL loadIfPreferencesAllow:(BOOL)load
{
	[self willChangeValueForKey:kMusicListKVO];
	BOOL okayMusic = [musicList addMusicURL:theURL];
	[self didChangeValueForKey:kMusicListKVO];
	if (!okayMusic) {
		NSInteger similarMusicIndex = [musicList indexOfObjectSimilarToURL:theURL];
		if (similarMusicIndex == NSNotFound) {
			return;
		}
		if (load && [[NSUserDefaults standardUserDefaults] boolForKey:PPLoadMusicAtMusicLoad]) {
			currentlyPlayingIndex.index = similarMusicIndex;
			[self selectCurrentlyPlayingMusic];
			NSError *err = nil;
			if (![self loadMusicFromCurrentlyPlayingIndexWithError:&err]) {
				[[NSAlert alertWithError:err] runModal];
			}
		} else {
			[self selectMusicAtIndex:similarMusicIndex];
		}
	} else if (load && [[NSUserDefaults standardUserDefaults] boolForKey:PPLoadMusicAtMusicLoad]) {
		currentlyPlayingIndex.index = [musicList countOfMusicList] - 1;
		//currentlyPlayingIndex.playbackURL = [musicList URLAtIndex:currentlyPlayingIndex.index];
		[self selectCurrentlyPlayingMusic];
		NSError *err = nil;
		if (![self loadMusicFromCurrentlyPlayingIndexWithError:&err]) {
			[[NSAlert alertWithError:err] runModal];
		}
	} else {
		[self selectMusicAtIndex:[musicList countOfMusicList] - 1];
	}
}

- (void)addMusicToMusicList:(NSURL* )theURL
{
	[self addMusicToMusicList:theURL loadIfPreferencesAllow:YES];
}

- (void)MADDriverWithPreferences
{
	Boolean madWasReading = false;
	long fullTime = 0, curTime = 0;
	if (madDriver) {
		madWasReading = MADIsPlayingMusic(madDriver);
		MADStopMusic(madDriver);
		MADStopDriver(madDriver);
		if (madWasReading) {
			MADGetMusicStatus(madDriver, &fullTime, &curTime);
		}
		MADDisposeDriver(madDriver);
		madDriver = NULL;
	}
	MADDriverSettings init;
	MADGetBestDriver(&init);
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	//TODO: Sanity Checking
	init.surround = [defaults boolForKey:PPSurroundToggle];
	init.outPutRate = [defaults integerForKey:PPSoundOutRate];
	init.outPutBits = [defaults integerForKey:PPSoundOutBits];
	if ([defaults boolForKey:PPOversamplingToggle]) {
		init.oversampling = [defaults integerForKey:PPOversamplingAmount];
	} else {
		init.oversampling = 1;
	}
	init.Reverb = [defaults boolForKey:PPReverbToggle];
	init.ReverbSize = [defaults integerForKey:PPReverbAmount];
	init.ReverbStrength = [defaults integerForKey:PPReverbStrength];
	if ([defaults boolForKey:PPStereoDelayToggle]) {
		init.MicroDelaySize = [defaults integerForKey:PPStereoDelayAmount];
	} else {
		init.MicroDelaySize = 0;
	}
	
	init.driverMode = [defaults integerForKey:PPSoundDriver];
	init.repeatMusic = FALSE;
	
	OSErr returnerr = MADCreateDriver(&init, madLib, &madDriver);
	[[NSNotificationCenter defaultCenter] postNotificationName:PPDriverDidChange object:self];
	if (returnerr != noErr) {
		NSError *err = CreateErrorFromMADErrorType(returnerr);
		[[NSAlert alertWithError:err] runModal];
		RELEASEOBJ(err);
		return;
	}
	MADStartDriver(madDriver);
	if (music) {
		MADAttachDriverToMusic(madDriver, music, NULL);
		if (madWasReading) {
			MADSetMusicStatus(madDriver, 0, fullTime, curTime);
			MADPlayMusic(madDriver);
		}
	}
}

+ (void)initialize
{
	PPMusicList *tempList = [[PPMusicList alloc] init];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
															 @YES, PPRememberMusicList,
															 @NO, PPLoadMusicAtListLoad,
															 @(PPStopPlaying), PPAfterPlayingMusic,
															 @YES, PPGotoStartupAfterPlaying,
															 @YES, PPSaveModList,
															 @NO, PPLoadMusicAtMusicLoad,
															 @NO, PPLoopMusicWhenDone,
															 
															 @16, PPSoundOutBits,
															 @44100, PPSoundOutRate,
															 @(CoreAudioDriver), PPSoundDriver,
															 @YES, PPStereoDelayToggle,
															 @NO, PPReverbToggle,
															 @NO, PPSurroundToggle,
															 @NO, PPOversamplingToggle,
															 @30, PPStereoDelayAmount,
															 @25, PPReverbAmount,
															 @30, PPReverbStrength,
															 @1, PPOversamplingAmount,
															 
															 @YES, PPDEShowInstrument,
															 @YES, PPDEShowNote,
															 @YES, PPDEShowEffect,
															 @YES, PPDEShowArgument,
															 @YES, PPDEShowVolume,
															 @YES, PPDEShowMarkers,
															 @0, PPDEMarkerOffsetPref,
															 @3, PPDEMarkerLoopPref,
															 [[NSColor yellowColor] PPencodeColor], PPDEMarkerColorPref,
															 @YES, PPDEMouseClickControlPref,
															 @NO, PPDEMouseClickShiftPref,
															 @NO, PPDEMouseClickCommandPref,
															 @NO, PPDEMouseClickOptionPref,
															 @YES, PPDELineHeightNormal,
															 @YES, PPDEMusicTraceOn,
															 @YES, PPDEPatternWrappingPartition,
															 @YES, PPDEDragAsPcmd,
															 
															 [[NSColor redColor] PPencodeColor], PPCColor1,
															 [[NSColor greenColor] PPencodeColor], PPCColor2,
															 [[NSColor blueColor] PPencodeColor], PPCColor3,
															 [[NSColor cyanColor] PPencodeColor], PPCColor4,
															 [[NSColor yellowColor] PPencodeColor], PPCColor5,
															 [[NSColor magentaColor] PPencodeColor], PPCColor6,
															 [[NSColor orangeColor] PPencodeColor], PPCColor7,
															 [[NSColor purpleColor] PPencodeColor], PPCColor8,
															 
															 @YES, PPBEMarkersEnabled,
															 @0, PPBEMarkersOffset,
															 @3, PPBEMarkersLoop,
															 @YES, PPBEOctaveMarkers,
															 @NO, PPBENotesProjection,
															 
															 @YES, PPMAddExtension,
															 @YES, PPMMadCompression,
															 @NO, PPMNoLoadMixerFromFiles,
															 @YES, PPMOscilloscopeDrawLines,
															 
															 @NO, PPCEShowNotesLen,
															 @YES, PPCEShowMarkers,
															 @0, PPCEMarkerOffset,
															 @3, PPCEMarkerLoop,
															 @4, PPCETempoNum,
															 @4, PPCETempoUnit,
															 @130, PPCETrackHeight,
															 
															 [NSKeyedArchiver archivedDataWithRootObject:tempList], PPMMusicList,
															 nil]];
	RELEASEOBJ(tempList);
}

- (IBAction)showMusicList:(id)sender
{
    [window makeKeyAndOrderFront:sender];
}

- (void)selectMusicAtIndex:(NSInteger)anIdx
{
	if (anIdx < 0 || anIdx >= [musicList countOfMusicList]) {
		NSBeep();
		return;
	}
	NSIndexSet *idx = [[NSIndexSet alloc] initWithIndex:anIdx];
	[tableView selectRowIndexes:idx byExtendingSelection:NO];
	[tableView scrollRowToVisible:anIdx];
	RELEASEOBJ(idx);
}

- (void)selectCurrentlyPlayingMusic
{
	if (currentlyPlayingIndex.index >= 0) {
		//currentlyPlayingIndex.playbackURL = [musicList URLAtIndex:currentlyPlayingIndex.index];
		[self selectMusicAtIndex:currentlyPlayingIndex.index];
	}
}

- (void)songIsDonePlaying
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	switch ([userDefaults integerForKey:PPAfterPlayingMusic]) {
		case PPStopPlaying:
		default:
			MADStopMusic(madDriver);
			MADCleanDriver(madDriver);
			if ([userDefaults boolForKey:PPGotoStartupAfterPlaying]) {
				MADSetMusicStatus(madDriver, 0, 100, 0);
			}
			self.paused = YES;
			break;
			
		case PPLoopMusic:
			MADSetMusicStatus(madDriver, 0, 100, 0);
			MADPlayMusic(madDriver);
			break;
			
		case PPLoadNext:
		{
			if ([musicList countOfMusicList] > ++currentlyPlayingIndex.index) {
				[self selectCurrentlyPlayingMusic];
				NSError *err = nil;
				if (![self loadMusicFromCurrentlyPlayingIndexWithError:&err])
				{
					[[NSAlert alertWithError:err] runModal];
				}
			} else {
				if ([userDefaults boolForKey:PPLoopMusicWhenDone]) {
					currentlyPlayingIndex.index = 0;
					[self selectCurrentlyPlayingMusic];
					NSError *err = nil;
					if (![self loadMusicFromCurrentlyPlayingIndexWithError:&err])
					{
						[[NSAlert alertWithError:err] runModal];
					}
				} else {
					MADStopMusic(madDriver);
					MADCleanDriver(madDriver);
					if ([userDefaults boolForKey:PPGotoStartupAfterPlaying]) {
						MADSetMusicStatus(madDriver, 0, 100, 0);
					}
				}
			}
		}
			break;
			
		case PPLoadRandom:
		{
			currentlyPlayingIndex.index = random() % [musicList countOfMusicList];
			[self selectCurrentlyPlayingMusic];
			NSError *err = nil;
			if (![self loadMusicFromCurrentlyPlayingIndexWithError:&err])
			{
				[[NSAlert alertWithError:err] runModal];
			}
		}
			break;
	}
}

- (void)updateMusicStats:(NSTimer*)theTimer
{
	if (music) {
		long fT, cT;
		MADGetMusicStatus(madDriver, &fT, &cT);
		if (MADIsDonePlaying(madDriver) && !self.paused && !MADIsExporting(madDriver)) {
			[self songIsDonePlaying];
			MADGetMusicStatus(madDriver, &fT, &cT);
		}
		[songPos setDoubleValue:cT];
		[songCurTime setIntegerValue:cT];
	}
}

- (void)saveMusicToURL:(NSURL *)tosave
{
	[instrumentController writeInstrumentsBackToMusic];
	int i, x;
	size_t inOutCount;
	MADCleanCurrentMusic(music, madDriver);
	NSMutableData *saveData = [[NSMutableData alloc] initWithCapacity:MADGetMusicSize(music)];
	for( i = 0, x = 0; i < MAXINSTRU; i++)
	{
		music->fid[ i].no = i;
		
		if( music->fid[ i].numSamples > 0 || music->fid[ i].name[ 0] != 0)	// Is there something in this instrument?
		{
			x++;
		}
	}

	music->header->numInstru = x;
	{
		MADSpec aHeader;
		aHeader = *music->header;
		ByteSwapMADSpec(&aHeader);
		[saveData appendBytes:&aHeader length:sizeof(MADSpec)];
	}
	{
		BOOL compressMAD = [[NSUserDefaults standardUserDefaults] boolForKey:PPMMadCompression];
		if (compressMAD) {
			for( i = 0; i < music->header->numPat ; i++)
			{
				if (music->partition[i]) {
					PatData *tmpPat = CompressPartitionMAD1(music, music->partition[i]);
					inOutCount = tmpPat->header.patBytes + sizeof(PatHeader);
					tmpPat->header.compMode = 'MAD1';
					ByteSwapPatHeader(&tmpPat->header);
					[saveData appendBytes:tmpPat length:inOutCount];
					free(tmpPat);
				}
			}
		} else {
			for (i = 0; i < music->header->numPat; i++) {
				if (music->partition[i]) {
					inOutCount = sizeof( PatHeader);
					inOutCount += music->header->numChn * music->partition[ i]->header.size * sizeof( Cmd);
					PatData *tmpPat = calloc(inOutCount, 1);
					memcpy(tmpPat, music->partition[i], inOutCount);
					ByteSwapPatHeader(&tmpPat->header);
					[saveData appendBytes:tmpPat length:inOutCount];
					free(tmpPat);
				}
			}
		}
	}
	
	for( i = 0; i < MAXINSTRU; i++)
	{
		if( music->fid[ i].numSamples > 0 || music->fid[ i].name[ 0] != 0)	// Is there something in this instrument?
		{
			music->fid[ i].no = i;
			InstrData instData = music->fid[i];
			ByteSwapInstrData(&instData);
			[saveData appendBytes:&instData length:sizeof( InstrData)];
		}
	}
	
	for( i = 0; i < MAXINSTRU ; i++)
	{
		for( x = 0; x < music->fid[i].numSamples; x++)
		{
			sData	curData;
			sData32	copyData;
			curData = *music->sample[ music->fid[i].firstSample + x];
			
			inOutCount = sizeof( sData32);
			ByteSwapsData(&curData);
			memcpy(&copyData, &curData, inOutCount);
			copyData.data = 0;
			[saveData appendBytes:&copyData length:inOutCount];
			
			inOutCount = music->sample[ music->fid[i].firstSample + x]->size;
			Ptr dataCopy = malloc(inOutCount);
			memcpy(dataCopy, curData.data, inOutCount);
			if( curData.amp == 16)
			{
				__block short	*shortPtr = (short*) dataCopy;
				
				dispatch_apply(inOutCount / 2, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT , 0), ^(size_t y) {
					PPBE16(&shortPtr[y]);
				});

			}

			[saveData appendBytes:dataCopy length:inOutCount];
			free(dataCopy);
		}
	}
	
	// EFFECTS *** *** *** *** *** *** *** *** *** *** *** ***
	
	int alpha = 0;
	for( i = 0; i < 10 ; i++)	// Global Effects
	{
		if( music->header->globalEffect[ i])
		{
			inOutCount = sizeof( FXSets);
			__block FXSets aSet = music->sets[alpha];
			PPBE16(&aSet.id);
			PPBE16(&aSet.noArg);
			PPBE16(&aSet.track);
			PPBE32(&aSet.FXID);
			dispatch_apply(100, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t y) {
				PPBE32(&aSet.values[y]);
			});

			[saveData appendBytes:&aSet length:inOutCount];
			alpha++;
		}
	}
	
	for( i = 0; i < music->header->numChn ; i++)	// Channel Effects
	{
		for( x = 0; x < 4; x++)
		{
			if( music->header->chanEffect[ i][ x])
			{
				inOutCount = sizeof( FXSets);
				__block FXSets aSet = music->sets[alpha];
				PPBE16(&aSet.id);
				PPBE16(&aSet.noArg);
				PPBE16(&aSet.track);
				PPBE32(&aSet.FXID);
				dispatch_apply(100, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t y) {
					PPBE32(&aSet.values[y]);
				});
				
				[saveData appendBytes:&aSet length:inOutCount];
				alpha++;
			}
		}
	}
	
	[saveData writeToURL:tosave atomically:YES];
	RELEASEOBJ(saveData);
	
	music->header->numInstru = MAXINSTRU;
	
	music->hasChanged = FALSE;
}

//Yes, the pragma pack is needed
//otherwise the data will be improperly mapped.
#pragma pack(push, 2)
struct Float80i {
	SInt16  exp;
	UInt32  man[2];
};
#pragma pack(pop)

static inline extended80 convertSampleRateToExtended80(unsigned int theNum)
{
	union {
		extended80 shortman;
		struct Float80i intman;
	} toreturn;

	unsigned int shift, exponent;

	
	for(shift = 0U; (theNum >> (31 - shift)) == 0U; ++shift)
		;
	theNum <<= shift;
	exponent = 63U - (shift + 32U); /* add 32 for unused second word */

	toreturn.intman.exp = (exponent+0x3FFF);
	PPBE16(&toreturn.intman.exp);
	toreturn.intman.man[0] = theNum;
	PPBE32(&toreturn.intman.man[0]);
	toreturn.intman.man[1] = 0;
	PPBE32(&toreturn.intman.man[1]);
	
	return toreturn.shortman;
}

- (NSData *)newAIFFDataFromSettings:(MADDriverSettings*)sett data:(NSData*)dat
{
	//TODO: Write a little-endian AIFF exporter
	NSInteger dataLen = [dat length];
	
	ContainerChunk header;
	
	CommonChunk container;

	SoundDataChunk dataChunk;
	
	NSData *nameData;
	NSData *infoData;

	{
#if 0
		TextChunk *nameChunk;
		NSInteger macRomanNameLength = 0;
		NSData *macRomanNameData = [musicName dataUsingEncoding:NSMacOSRomanStringEncoding allowLossyConversion:YES];
		macRomanNameLength = [macRomanNameData length];
		BOOL isPadded = (macRomanNameLength & 1);
		NSInteger nameChunkLen = sizeof(TextChunk) + macRomanNameLength;

		if (!isPadded) {
			nameChunkLen--;
		}
		
		nameChunk = calloc(nameChunkLen, 1);
		char *firstChar;
		nameChunk->ckID = NameID;
		PPBE32(&nameChunk->ckID);
		nameChunk->ckSize = 1 + macRomanNameLength;
		PPBE32(&nameChunk->ckSize);
		nameChunk->text[0] = macRomanNameLength;
		firstChar = &nameChunk->text[1];
		memcpy(firstChar, [macRomanNameData bytes], macRomanNameLength);
		nameData = [NSData dataWithBytes:nameChunk length:nameChunkLen];
		free(nameChunk);
#else
		ChunkHeader nameChunk;
		NSInteger macRomanNameLength = 0;
		NSData *macRomanNameData = [musicName dataUsingEncoding:NSMacOSRomanStringEncoding allowLossyConversion:YES];
		macRomanNameLength = [macRomanNameData length];
		BOOL isPadded = (macRomanNameLength & 1);
		
		nameChunk.ckSize = macRomanNameLength + 1;
		char pStrLen = macRomanNameLength;
		PPBE32(&nameChunk.ckSize);
		
		nameChunk.ckID = NameID;
		PPBE32(&nameChunk.ckID);
		
		NSMutableData *tmpNameDat = [NSMutableData dataWithBytes:&nameChunk length:sizeof(ChunkHeader)];
		[tmpNameDat appendBytes:&pStrLen length:1];
		[tmpNameDat appendData:macRomanNameData];
		
		if (!isPadded) {
			char padbyte = 0;
			[tmpNameDat appendBytes:&padbyte length:1];
		}
		nameData = tmpNameDat;
#endif
	}
	
	{
#if 0
		ApplicationSpecificChunk *infoChunk;
		NSInteger macRomanInfoLength = 0;
		NSData *macRomanInfoData = [musicInfo dataUsingEncoding:NSMacOSRomanStringEncoding allowLossyConversion:YES];
		macRomanInfoLength = [macRomanInfoData length];
		BOOL isPadded = (macRomanInfoLength & 1);
		NSInteger infoChunkLen = sizeof(ApplicationSpecificChunk) + macRomanInfoLength;
		
		if (!isPadded) {
			infoChunkLen--;
		}
		
		infoChunk = calloc(infoChunkLen, 0);
		infoChunk->applicationSignature = CommentID;
		PPBE32(&infoChunk->applicationSignature);
		infoChunk->ckID = ApplicationSpecificID;
		PPBE32(&infoChunk->ckID);
		infoChunk->ckSize = macRomanInfoLength + 1;
		PPBE32(&infoChunk->ckSize);
		memcpy(infoChunk->data, [macRomanInfoData bytes], macRomanInfoLength);
		infoData = [NSData dataWithBytes:infoChunk length:infoChunkLen];
		free(infoChunk);
#else
		ChunkHeader infoChunk;
		NSInteger macRomanInfoLength = 0;
		NSData *macRomanInfoData = [musicInfo dataUsingEncoding:NSMacOSRomanStringEncoding allowLossyConversion:YES];
		macRomanInfoLength = [macRomanInfoData length];
		BOOL isPadded = (macRomanInfoLength & 1);
		infoChunk.ckSize = macRomanInfoLength + 1;
		char pStrLen = macRomanInfoLength;
		PPBE32(&infoChunk.ckSize);
		
		infoChunk.ckID = CommentID;
		PPBE32(&infoChunk.ckID);
		NSMutableData *tmpInfoDat = [NSMutableData dataWithBytes:&infoChunk length:sizeof(ChunkHeader)];
		[tmpInfoDat appendBytes:&pStrLen length:1];
		[tmpInfoDat appendData:macRomanInfoData];
		
		if (!isPadded) {
			char padbyte = 0;
			[tmpInfoDat appendBytes:&padbyte length:1];
		}

		infoData = tmpInfoDat;
#endif
	}
	
	NSMutableData *returnData = [[NSMutableData alloc] initWithCapacity:dataLen + sizeof(CommonChunk) + sizeof(SoundDataChunk) + sizeof(ContainerChunk) + [nameData length] + [infoData length]];
	header.ckID = FORMID;
	PPBE32(&header.ckID);
	header.ckSize = dataLen + sizeof(CommonChunk) + sizeof(SoundDataChunk) + 4 + [nameData length] + [infoData length];
	PPBE32(&header.ckSize);
	header.formType = AIFFID;
	PPBE32(&header.formType);
	[returnData appendBytes:&header length:sizeof(ContainerChunk)];
	
	container.ckID = CommonID;
	PPBE32(&container.ckID);
	container.ckSize = /*sizeof(CommonChunk)*/ 18;
	PPBE32(&container.ckSize);
	short chanNums = 0;
	{
		int todiv = sett->outPutBits / 8;

		switch (sett->outPutMode) {
			case DeluxeStereoOutPut:
			case StereoOutPut:
			default:
				todiv *= 2;
				chanNums = 2;
				break;
				
			case PolyPhonic:
				todiv *= 4;
				chanNums = 4;
				break;
				
			case MonoOutPut:
				chanNums = 1;
				break;
		}
		container.numSampleFrames = dataLen / todiv;
	}

	container.numChannels = chanNums;
	PPBE16(&container.numChannels);
	container.sampleSize = sett->outPutBits;
	PPBE16(&container.sampleSize);
	PPBE32(&container.numSampleFrames);
	
	container.sampleRate = convertSampleRateToExtended80(sett->outPutRate);
	[returnData appendBytes:&container length:sizeof(CommonChunk)];
	
	int dataOffset = 0;
	dataChunk.ckID = SoundDataID;
	PPBE32(&dataChunk.ckID);
	dataChunk.blockSize = 0;
	PPBE32(&dataChunk.blockSize);
	dataChunk.ckSize = dataLen + 8 + dataOffset;
	PPBE32(&dataChunk.ckSize);
	dataChunk.offset = dataOffset;
	PPBE32(&dataChunk.offset);
	

	[returnData appendBytes:&dataChunk length:sizeof(SoundDataChunk)];
	if (sett->outPutBits == 16) {
		short swapdata;
		int i;
		for (i = 0; i < dataLen; i += 2) {
			[dat getBytes:&swapdata range:NSMakeRange(i, 2)];
			PPBE16(&swapdata);
			[returnData appendBytes:&swapdata length:2];
		}
	} else {
		[returnData appendData:dat];
	}
	
	[returnData appendData:nameData];
	[returnData appendData:infoData];
	
	return returnData;
}

- (NSData *)getSoundData:(MADDriverSettings*)theSet
{
	MADDriverRec *theRec = NULL;
	
	OSErr err = MADCreateDriver( theSet, madLib, &theRec);
	if (err != noErr) {
		dispatch_async(dispatch_get_main_queue(), ^{
			NSError *NSerr = CreateErrorFromMADErrorType(err);
			[[NSAlert alertWithError:NSerr] runModal];
			RELEASEOBJ(NSerr);
		});
		
		return nil;
	}
	MADCleanDriver( theRec);

	MADAttachDriverToMusic( theRec, music, NULL);
	MADPlayMusic(theRec);
	
	Ptr soundPtr = NULL;
	long full = 0;
	if (theSet->outPutBits == 8) {
		full = (theRec->ASCBUFFERReal - theRec->BytesToRemoveAtEnd);
	}else if (theSet->outPutBits == 16) {
		full = (theRec->ASCBUFFERReal - theRec->BytesToRemoveAtEnd) * 2;
	} else if (theSet->outPutBits == 20 || theSet->outPutBits == 24 ) {
		full = (theRec->ASCBUFFERReal - theRec->BytesToRemoveAtEnd) * 3;
	} else {
		//This is just to make the Static analyzer happy
		full = (theRec->ASCBUFFERReal - theRec->BytesToRemoveAtEnd);
	}
	
	switch (theSet->outPutMode) {
		case DeluxeStereoOutPut:
		case StereoOutPut:
			full *= 2;
			break;
			
		case PolyPhonic:
			full *= 4;
			break;
			
		default:
			break;
	}
	
	NSMutableData *mutData = [[NSMutableData alloc] init];
	soundPtr = calloc(full, 1);
	
	while(DirectSave(soundPtr, theSet, theRec))
	{
		[mutData appendBytes:soundPtr length:full];
	}
	NSData *retData = [self newAIFFDataFromSettings:theSet data:mutData];
	RELEASEOBJ(mutData);
	mutData = nil;
	
	MADStopMusic(theRec);
	MADCleanDriver(theRec);
	MADDisposeDriver(theRec);
	free(soundPtr);
	
	return AUTORELEASEOBJ(retData);
}

- (NSInteger)showExportSettings
{
	MADGetBestDriver(&exportSettings);
	exportSettings.driverMode = NoHardwareDriver;
	exportSettings.repeatMusic = FALSE;
	[exportController settingsFromDriverSettings:&exportSettings];
	return [NSApp runModalForWindow:exportWindow];
}

#ifndef PPEXPORT_CREATE_TMP_AIFF
#define PPEXPORT_CREATE_TMP_AIFF 1
#endif

- (IBAction)exportMusicAs:(id)sender
{
	NSInteger tag = [sender tag];
	MADBeginExport(madDriver);

	switch (tag) {
		case -1:
			//AIFF
		{
			NSSavePanel *savePanel = RETAINOBJ([NSSavePanel savePanel]);
			[savePanel setAllowedFileTypes:@[@"public.aiff-audio"]];
			[savePanel setCanCreateDirectories:YES];
			[savePanel setCanSelectHiddenExtension:YES];
			if (![musicName isEqualToString:@""]) {
				[savePanel setNameFieldStringValue:musicName];
			}
			[savePanel setPrompt:@"Export"];
			[savePanel setTitle:@"Export as AIFF audio"];
			if ([savePanel runModal] == NSFileHandlingPanelOKButton) {
				if ([self showExportSettings] == NSAlertDefaultReturn) {
					dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
						NSData *saveData = RETAINOBJ([self getSoundData:&exportSettings]);
						MADEndExport(madDriver);

						[saveData writeToURL:[savePanel URL] atomically:YES];
						RELEASEOBJ(saveData);
						saveData = nil;
						dispatch_async(dispatch_get_main_queue(), ^{
							if (isQuitting) {
								[NSApp replyToApplicationShouldTerminate:YES];
							} else {
								NSInteger retVal = NSRunInformationalAlertPanel(@"Export complete", @"The export of the file \"%@\" is complete.", @"Okay", @"Show File", nil, [[savePanel URL] lastPathComponent]);
								if (retVal == NSAlertAlternateReturn) {
									[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[savePanel URL]]];
								}
							}
						});
					});
				} else {
					MADEndExport(madDriver);
				}
			} else {
				MADEndExport(madDriver);
			}
			RELEASEOBJ(savePanel);
		}
			break;
			
		case -2:
			//MP4
		{
			NSSavePanel *savePanel = RETAINOBJ([NSSavePanel savePanel]);
			[savePanel setAllowedFileTypes:@[@"com.apple.m4a-audio"]];
			[savePanel setCanCreateDirectories:YES];
			[savePanel setCanSelectHiddenExtension:YES];
			if (![musicName isEqualToString:@""]) {
				[savePanel setNameFieldStringValue:musicName];
			}
			[savePanel setPrompt:@"Export"];
			[savePanel setTitle:@"Export as MPEG-4 Audio"];
			if ([savePanel runModal] == NSFileHandlingPanelOKButton) {
				if ([self showExportSettings] == NSAlertDefaultReturn) {
					dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
						NSData *saveData = RETAINOBJ([self getSoundData:&exportSettings]);
						NSString *oldMusicName = RETAINOBJ(musicName);
						NSString *oldMusicInfo = RETAINOBJ(musicInfo);
						NSURL *oldURL = [[musicList objectInMusicListAtIndex:previouslyPlayingIndex.index] musicUrl];
						MADEndExport(madDriver);
						NSError *expErr = nil;
						dispatch_block_t errBlock = ^{
							if (isQuitting) {
								[NSApp replyToApplicationShouldTerminate:YES];
							}else {
								NSRunAlertPanel(@"Export failed", @"Export/coversion of the music file failed:\n%@", nil, nil, nil, [expErr localizedDescription]);
							}
						};
#if PPEXPORT_CREATE_TMP_AIFF
						NSURL *tmpURL = [[[NSFileManager defaultManager] URLForDirectory:NSItemReplacementDirectory inDomain:NSUserDomainMask appropriateForURL:oldURL create:YES error:nil] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.aiff", oldMusicName] isDirectory:NO];
						
						[saveData writeToURL:tmpURL atomically:NO];
						QTMovie *exportMov = [[QTMovie alloc] initWithURL:tmpURL error:&expErr];
						if (exportMov) {
							[exportMov setAttribute:oldMusicName forKey:QTMovieDisplayNameAttribute];
							[exportMov setAttribute:oldMusicInfo forKey:QTMovieCopyrightAttribute];
						}
#else
						//Attempts of using data directly have resulted in internal assertion failures in the export session initialization code
						QTDataReference *dataRef = [[QTDataReference alloc] initWithReferenceToData:saveData name:oldMusicName MIMEType:@"audio/aiff"];
						
						QTMovie *exportMov = [[QTMovie alloc] initWithAttributes:[NSDictionary dictionaryWithObjectsAndKeys:dataRef, QTMovieDataReferenceAttribute, @NO, QTMovieOpenAsyncOKAttribute, @YES, QTMovieDontInteractWithUserAttribute, @NO, QTMovieOpenForPlaybackAttribute, oldMusicName, QTMovieDisplayNameAttribute, oldMusicInfo, QTMovieCopyrightAttribute, nil] error:&expErr];
#endif
						RELEASEOBJ(oldMusicInfo);
						oldMusicInfo = nil;
						RELEASEOBJ(saveData);
						saveData = nil;
						if (!exportMov) {
							NSLog(@"Init Failed for %@, error: %@", oldMusicName, [expErr localizedDescription]);
#if !PPEXPORT_CREATE_TMP_AIFF
							RELEASEOBJ(dataRef);
#else
							[[NSFileManager defaultManager] removeItemAtURL:tmpURL error:NULL];
#endif
							RELEASEOBJ(saveData);
							RELEASEOBJ(oldMusicName);
							
							dispatch_async(dispatch_get_main_queue(), errBlock);
							return;
						}
						
						QTExportSession *session = [[QTExportSession alloc] initWithMovie:exportMov exportOptions:[QTExportOptions exportOptionsWithIdentifier:QTExportOptionsAppleM4A] outputURL:[savePanel URL] error:&expErr];
						if (!session) {
							NSLog(@"Export session creation for %@ failed, error: %@", oldMusicName, [expErr localizedDescription]);
#if !PPEXPORT_CREATE_TMP_AIFF
							RELEASEOBJ(dataRef);
#else
							[[NSFileManager defaultManager] removeItemAtURL:tmpURL error:NULL];
#endif
							RELEASEOBJ(saveData);
							RELEASEOBJ(exportMov);
							RELEASEOBJ(oldMusicName);

							dispatch_async(dispatch_get_main_queue(), errBlock);
							return;
						}
						[session run];
						BOOL didFinish = [session waitUntilFinished:&expErr];
						if (!didFinish)
						{
							NSLog(@"export of \"%@\" failed, error: %@", oldMusicName, [expErr localizedDescription]);
							dispatch_async(dispatch_get_main_queue(), errBlock);
						}
#if !PPEXPORT_CREATE_TMP_AIFF
						RELEASEOBJ(dataRef);
#else
						[[NSFileManager defaultManager] removeItemAtURL:tmpURL error:NULL];
#endif
						RELEASEOBJ(oldMusicName);
						RELEASEOBJ(session);
						RELEASEOBJ(exportMov);
						
						if (didFinish) {
							dispatch_async(dispatch_get_main_queue(), ^{
								if (isQuitting) {
									[NSApp replyToApplicationShouldTerminate:YES];
								} else {
									NSInteger retVal = NSRunInformationalAlertPanel(@"Export complete", @"The export of the file \"%@\" is complete.", @"Okay", @"Show File", nil, [[savePanel URL] lastPathComponent]);
									if (retVal == NSAlertAlternateReturn) {
										[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[savePanel URL]]];
									}
								}
							});
						}

					});
				} else {
					MADEndExport(madDriver);
				}
			} else {
				MADEndExport(madDriver);
			}
			RELEASEOBJ(savePanel);
		}
			break;
			
		default:
		{
			if (tag > madLib->TotalPlug || tag < 0) {
				NSBeep();
				MADEndExport(madDriver);
				if (isQuitting) {
					[NSApp replyToApplicationShouldTerminate:YES];
				}
				
				return;
			}
			NSSavePanel *savePanel = RETAINOBJ([NSSavePanel savePanel]);
			[savePanel setAllowedFileTypes:BRIDGE(NSArray*, madLib->ThePlug[tag].UTItypes)];
			[savePanel setCanCreateDirectories:YES];
			[savePanel setCanSelectHiddenExtension:YES];
			if (![musicName isEqualToString:@""]) {
				[savePanel setNameFieldStringValue:musicName];
			}
			[savePanel setPrompt:@"Export"];
			[savePanel setTitle:[NSString stringWithFormat:@"Export as %@", BRIDGE(NSString*, madLib->ThePlug[tag].MenuName)]];
			if ([savePanel runModal] == NSFileHandlingPanelOKButton) {
				NSURL *fileURL = RETAINOBJ([savePanel URL]);
				OSErr err = MADMusicExportCFURL(madLib, music, madLib->ThePlug[tag].type, BRIDGE(CFURLRef, fileURL));
				if (err != noErr) {
					if (isQuitting) {
						[NSApp replyToApplicationShouldTerminate:YES];
					} else {
						NSError *aerr = CreateErrorFromMADErrorType(err);
						[[NSAlert alertWithError:aerr] runModal];
						RELEASEOBJ(aerr);
					}
				} else {
					[self addMusicToMusicList:fileURL loadIfPreferencesAllow:NO];
					if (isQuitting) {
						[NSApp replyToApplicationShouldTerminate:YES];
					} else {
						NSInteger retVal = NSRunInformationalAlertPanel(@"Export complete", @"The export of the file \"%@\" is complete.", @"Okay", @"Show File", nil, [[savePanel URL] lastPathComponent]);
						if (retVal == NSAlertAlternateReturn) {
							[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[fileURL]];
						}
					}
				}
				RELEASEOBJ(fileURL);
			}
			RELEASEOBJ(savePanel);
		}
			MADEndExport(madDriver);
			break;
	}
}

- (IBAction)okayExportSettings:(id)sender {
	[NSApp stopModalWithCode:NSAlertDefaultReturn];
	[exportWindow close];
}

- (IBAction)cancelExportSettings:(id)sender {
	[NSApp stopModalWithCode:NSAlertAlternateReturn];
	[exportWindow close];
}

- (IBAction)saveMusicAs:(id)sender
{
	MADBeginExport(madDriver);
	
	NSSavePanel * savePanel = RETAINOBJ([NSSavePanel savePanel]);
	[savePanel setAllowedFileTypes:@[MADNativeUTI]];
	[savePanel setCanCreateDirectories:YES];
	[savePanel setCanSelectHiddenExtension:YES];
	if (![musicName isEqualToString:@""]) {
		[savePanel setNameFieldStringValue:musicName];
	}
	if ([savePanel runModal] == NSFileHandlingPanelOKButton) {
		NSURL *saveURL = RETAINOBJ([savePanel URL]);
		[self saveMusicToURL:saveURL];
		[self addMusicToMusicList:saveURL loadIfPreferencesAllow:NO];
		RELEASEOBJ(saveURL);
	}
	RELEASEOBJ(savePanel);
	MADEndExport(madDriver);
}

- (IBAction)saveMusic:(id)sender
{
	MADBeginExport(madDriver);
	
	if (previouslyPlayingIndex.index == -1) {
		// saveMusicAs: will end the exporting when it is done.
		[self saveMusicAs:sender];
	} else {
		NSURL *fileURL = previouslyPlayingIndex.playbackURL;
		NSString *filename = [fileURL path];
		NSWorkspace *sharedWorkspace = [NSWorkspace sharedWorkspace];
		NSString *utiFile = [sharedWorkspace typeOfFile:filename error:nil];
		if (/*[sharedWorkspace type:utiFile conformsToType:MADNativeUTI]*/ [utiFile isEqualToString:MADNativeUTI]) {
			[self saveMusicToURL:fileURL];
			MADEndExport(madDriver);
		} else {
			// saveMusicAs: will end the exporting when it is done.
			[self saveMusicAs:sender];
		}
	}
}

- (BOOL)loadMusicURL:(NSURL*)musicToLoad error:(out NSError *__autoreleasing*)theErr
{
	if (music != NULL) {
		if (music->hasChanged) {
			NSInteger selection = 0;
			if (previouslyPlayingIndex.index == -1) {
				selection = NSRunAlertPanel(NSLocalizedString(@"Unsaved Changes", @"Unsaved Changes"), NSLocalizedString(@"The new music file has unsaved changes. Do you want to save?", @"New unsaved file"), NSLocalizedString(@"Save", @"Save"), NSLocalizedString(@"Don't Save", @"Don't Save"), NSLocalizedString(@"Cancel", @"Cancel"));
			} else {
				selection = NSRunAlertPanel(NSLocalizedString(@"Unsaved Changes", @"Unsaved Changes"), NSLocalizedString(@"The music file \"%@\" has unsaved changes. Do you want to save?", @"file unsaved"), NSLocalizedString(@"Save", @"Save"), NSLocalizedString(@"Don't Save", @"Don't Save"), NSLocalizedString(@"Cancel", @"Cancel"), [[musicList objectInMusicListAtIndex:previouslyPlayingIndex.index] fileName]);
			}
			switch (selection) {
				case NSAlertDefaultReturn:
					[self saveMusic:nil];
					break;
					
				case NSAlertAlternateReturn:
				default:
					break;
					
				case NSAlertOtherReturn:
					[previouslyPlayingIndex movePlayingIndexToOtherIndex:currentlyPlayingIndex];
					if (theErr) {
						*theErr = AUTORELEASEOBJ([[NSError alloc] initWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]);
					}
					return NO;
					break;
			}
		}
		MADStopMusic(madDriver);
		MADCleanDriver(madDriver);
		MADDisposeMusic(&music, madDriver);
	}

	char fileType[5];
	OSErr theOSErr = MADMusicIdentifyCFURL(madLib, fileType, BRIDGE(CFURLRef, musicToLoad));
		
	if(theOSErr != noErr)
	{
		if (theErr) {
			*theErr = AUTORELEASEOBJ(CreateErrorFromMADErrorType(theOSErr));
		}
		self.paused = YES;
		[self clearMusic];
		return NO;
	}
	theOSErr = MADLoadMusicCFURLFile(madLib, &music, fileType, BRIDGE(CFURLRef, musicToLoad));
	
	if (theOSErr != noErr) {
		if (theErr) {
			*theErr = AUTORELEASEOBJ(CreateErrorFromMADErrorType(theOSErr));
		}
		self.paused = YES;
		[self clearMusic];
		return NO;
	}
	
	MADAttachDriverToMusic(madDriver, music, NULL);
	MADPlayMusic(madDriver);
	self.paused = NO;
	{
		long fT, cT;
		MADGetMusicStatus(madDriver, &fT, &cT);
		[songPos setMaxValue:fT];
		[songPos setMinValue:0.0];
		[self setTitleForSongLabelBasedOnMusic];
		[songTotalTime setIntegerValue:fT];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:PPMusicDidChange object:self];

	if (theErr) {
		*theErr = nil;
	}
	return YES;
}

- (BOOL)loadMusicURL:(NSURL*)musicToLoad
{
	return [self loadMusicURL:musicToLoad error:NULL];
}

- (IBAction)showPreferences:(id)sender
{
    if (!preferences) {
		preferences = [[PPPreferences alloc] init];
	}
	[[preferences window] center];
	[preferences showWindow:sender];
}


- (IBAction)exportInstrumentAs:(id)sender
{
    [instrumentController exportInstrument:sender];
}

- (IBAction)showInstrumentsList:(id)sender
{
    [instrumentController showWindow:sender];
}

- (IBAction)showTools:(id)sender
{
    [toolsPanel makeKeyAndOrderFront:sender];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"paused"]) {
		id boolVal = [change objectForKey:NSKeyValueChangeNewKey];
		
		//[pauseButton highlight:[boolVal boolValue]];
		switch ([boolVal boolValue]) {
			case NO:
			default:
				[pauseButton setState:NSOffState];
				[pauseDockMenuItem setState:NSOnState];
				break;
				
			case YES:
				[pauseButton setState:NSOnState];
				[pauseDockMenuItem setState:NSOffState];
				break;
		}
	}
	//[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)doubleClickMusicList
{
	NSError *err = nil;
	currentlyPlayingIndex.index = [tableView selectedRow];
	if ([self loadMusicFromCurrentlyPlayingIndexWithError:&err] == NO)
	{
		[[NSAlert alertWithError:err] runModal];
	}
}

- (IBAction)showPlugInInfo:(id)sender
{
	PPPlugInInfo *inf = [plugInInfos objectAtIndex:[sender tag]];
	if (!inf) {
		return;
	}
	
	PPPlugInInfoController *infoCont = [[PPPlugInInfoController alloc] initWithPlugInInfo:inf];
	[[infoCont window] center];
	[NSApp runModalForWindow:[infoCont window]];
	//[infoCont showWindow:sender];
	RELEASEOBJ(infoCont);
}

- (void)updatePlugInInfoMenu
{
	NSInteger i;

	//[plugInInfos removeAllObjects];
	
	for (i = 0; i < madLib->TotalPlug ; i++) {
		PPPlugInInfo *tmpInfo = [[PPPlugInInfo alloc] initWithPlugName:BRIDGE(NSString*, madLib->ThePlug[i].MenuName) author:BRIDGE(NSString*, madLib->ThePlug[i].AuthorString) plugType:NSLocalizedString(@"TrackerPlugName", @"Tracker plug-in name") plugURL:CFBridgingRelease(CFBundleCopyBundleURL(madLib->ThePlug[i].file))];
		if (![plugInInfos containsObject:tmpInfo]) {
			[plugInInfos addObject:tmpInfo];
		}
		RELEASEOBJ(tmpInfo);
	}
	
	for (PPInstrumentImporterObject *obj in instrumentImporter) {
		PPPlugInInfo *tmpInfo = [[PPPlugInInfo alloc] initWithPlugName:obj.menuName author:obj.authorString plugType:NSLocalizedString(@"InstrumentPlugName", @"Instrument plug-in name") plugURL:[[obj file] bundleURL]];
		if (![plugInInfos containsObject:tmpInfo]) {
			[plugInInfos addObject:tmpInfo];
		}
		RELEASEOBJ(tmpInfo);
	}
	
	for (PPDigitalPlugInObject *obj in digitalHandler) {
		PPPlugInInfo *tmpInfo = [[PPPlugInInfo alloc] initWithPlugName:obj.menuName author:obj.authorString plugType:NSLocalizedString(@"DigitalPlugName", @"Digital plug-in name") plugURL:[[obj file] bundleURL]];
		if (![plugInInfos containsObject:tmpInfo]) {
			[plugInInfos addObject:tmpInfo];
		}
		RELEASEOBJ(tmpInfo);
	}
	
	for (PPFilterPlugObject *obj in filterHandler) {
		PPPlugInInfo *tmpInfo = [[PPPlugInInfo alloc] initWithPlugName:obj.menuName author:obj.authorString plugType:NSLocalizedString(@"FilterPlugName", @"Filter plug-in name") plugURL:[[obj file] bundleURL]];
		if (![plugInInfos containsObject:tmpInfo]) {
			[plugInInfos addObject:tmpInfo];
		}
		RELEASEOBJ(tmpInfo);
	}
	
	[plugInInfos sortWithOptions:NSSortConcurrent usingComparator:^NSComparisonResult(id obj1, id obj2) {
		NSString *menuNam1 = [obj1 plugName];
		NSString *menuNam2 = [obj2 plugName];
		NSComparisonResult res = [menuNam1 localizedStandardCompare:menuNam2];
		return res;
	}];
	
	[aboutPlugInMenu removeAllItems];
	
	for (i = 0; i < [plugInInfos count]; i++) {
		PPPlugInInfo *pi = [plugInInfos objectAtIndex:i];
		NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:pi.plugName action:@selector(showPlugInInfo:) keyEquivalent:@""];
		[mi setTag:i];
		[mi setTarget:self];
		[aboutPlugInMenu addItem:mi];
		RELEASEOBJ(mi);
	}
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	isQuitting = NO;
	undoManager = [[NSUndoManager alloc] init];
	srandom(time(NULL) & 0xffffffff);
	PPRegisterDebugFunc(CocoaDebugStr);
	MADInitLibrary(NULL, &madLib);
	//the NIB won't store the value anymore, so do this hackery to make sure there's some value in it.
	[songTotalTime setIntegerValue:0];
	[songCurTime setIntegerValue:0];

	[self addObserver:self forKeyPath:@"paused" options:NSKeyValueObservingOptionNew context:NULL];
	self.paused = YES;
	[self willChangeValueForKey:kMusicListKVO];
	musicList = [[PPMusicList alloc] init];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:PPRememberMusicList]) {
		[musicList loadMusicListFromPreferences];
	}
	NSInteger selMus = musicList.selectedMusic;
	[self didChangeValueForKey:kMusicListKVO];

	[tableView setDoubleAction:@selector(doubleClickMusicList)];
	
	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	[defaultCenter addObserver:self selector:@selector(soundPreferencesDidChange:) name:PPSoundPreferencesDidChange object:nil];
	
	[self MADDriverWithPreferences];
	music = CreateFreeMADK();
	MADAttachDriverToMusic(madDriver, music, NULL);
	[self setTitleForSongLabelBasedOnMusic];
	instrumentImporter = [[PPInstrumentImporter alloc] initWithMusic:&music];
	instrumentImporter.driverRec = &madDriver;
	
	digitalHandler = [[PPDigitalPlugInHandler alloc] initWithMusic:&music];
	digitalHandler.driverRec = &madDriver;
	
	filterHandler = [[PPFilterPlugHandler alloc] initWithMusic:&music];
	filterHandler.driverRec = &madDriver;
	
	instrumentController = [[PPInstrumentWindowController alloc] init];
	instrumentController.importer = instrumentImporter;
	instrumentController.curMusic = &music;
	instrumentController.theDriver = &madDriver;
	instrumentController.undoManager = undoManager;
	instrumentController.filterHandler = filterHandler;
	
	patternHandler = [[PatternHandler alloc] initWithMusic:&music];
	patternHandler.theRec = &madDriver;
	patternHandler.undoManager = undoManager;
	
	//Initialize the QTKit framework on the main thread. needed for 32-bit code.
	[QTMovie class];
	
	NSInteger i;
	for (i = 0; i < [instrumentImporter plugInCount]; i++) {
		PPInstrumentImporterObject *obj = [instrumentImporter plugInAtIndex:i];
		if (obj.mode == MADPlugImportExport || obj.mode == MADPlugExport) {
			NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:obj.menuName action:@selector(exportInstrument:) keyEquivalent:@""];
			[mi setTag:i];
			[mi setTarget:instrumentController];
			[instrumentExportMenu addItem:mi];
			RELEASEOBJ(mi);
		}
	}
	
	for (i = 0; i < madLib->TotalPlug; i++) {
		if (madLib->ThePlug[i].mode == MADPlugImportExport || madLib->ThePlug[i].mode == MADPlugExport) {
			NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@...", BRIDGE(NSString*, madLib->ThePlug[i].MenuName)] action:@selector(exportMusicAs:) keyEquivalent:@""];
			[mi setTag:i];
			[mi setTarget:self];
			[musicExportMenu addItem:mi];
			RELEASEOBJ(mi);
		}
	}
	
	plugInInfos = [[NSMutableArray alloc] init];
	[self updatePlugInInfoMenu];
	
	previouslyPlayingIndex = [[PPCurrentlyPlayingIndex alloc] init];
	previouslyPlayingIndex.index = -1;
	currentlyPlayingIndex = [[PPCurrentlyPlayingIndex alloc] init];
	[previouslyPlayingIndex movePlayingIndexToOtherIndex:currentlyPlayingIndex];
	
	exportController = [[PPSoundSettingsViewController alloc] init];
	exportController.delegate = self;
	[exportSettingsBox setContentView:[exportController view]];
	
	timeChecker = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:0] interval:1/8.0 target:self selector:@selector(updateMusicStats:) userInfo:nil repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:timeChecker forMode:NSRunLoopCommonModes];
	NSUInteger lostCount = musicList.lostMusicCount;
	if (lostCount) {
		NSRunAlertPanel(kUnresolvableFile, kUnresolvableFileDescription, nil, nil, nil, (unsigned long)lostCount);
	}
	if (selMus != -1) {
		[self selectMusicAtIndex:selMus];
	}
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	if (MADIsExporting(madDriver)) {
		NSInteger selection = NSRunAlertPanel(@"Exporting", @"PlayerPRO is currently exporting a tracker file.\nQuitting will stop this. Do you really wish to quit?", @"Wait", @"Quit", @"Cancel");
		switch (selection) {
			default:
			case NSAlertOtherReturn:
				return NSTerminateCancel;
				break;
				
			case NSAlertAlternateReturn:
				return NSTerminateNow;
				break;
				
			case NSAlertDefaultReturn:
				//Double-check to make sure we're still exporting
				if (MADIsExporting(madDriver)) {
					isQuitting = YES;
					return NSTerminateLater;
				} else {
					return NSTerminateNow;
				}
				
				break;
		}
	}
	return NSTerminateNow;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	[timeChecker invalidate];

	[self removeObserver:self forKeyPath:@"paused"];
	
	RELEASEOBJ(instrumentImporter);
	instrumentImporter = nil;
	
	RELEASEOBJ(digitalHandler);
	digitalHandler = nil;
	
	RELEASEOBJ(filterHandler);
	filterHandler = nil;
	
	RELEASEOBJ(patternHandler);
	patternHandler = nil;
	
	RELEASEOBJ(undoManager);
	undoManager = nil;
	
	if (music != NULL) {
		if (music->hasChanged) {
			NSInteger selection = 0;
			if (currentlyPlayingIndex.index == -1) {
				selection = NSRunAlertPanel(NSLocalizedString(@"Unsaved Changes", @"Unsaved Changes"), NSLocalizedString(@"The new music file has unsaved changes. Do you want to save?", @"New unsaved file"), NSLocalizedString(@"Save", @"Save"), NSLocalizedString(@"Don't Save", @"Don't Save"), nil);
			} else {
				selection = NSRunAlertPanel(NSLocalizedString(@"Unsaved Changes", @"Unsaved Changes"), NSLocalizedString(@"The music file \"%@\" has unsaved changes. Do you want to save?", @"file unsaved"), NSLocalizedString(@"Save", @"Save"), NSLocalizedString(@"Don't Save", @"Don't Save"), nil, [[musicList objectInMusicListAtIndex:currentlyPlayingIndex.index] fileName]);
			}
			switch (selection) {
				case NSAlertDefaultReturn:
					[self saveMusic:nil];
					break;
					
				case NSAlertAlternateReturn:
				default:
					break;
			}
		}
		MADStopMusic(madDriver);
		MADCleanDriver(madDriver);
		MADDisposeMusic(&music, madDriver);
	}
	MADStopDriver(madDriver);
	MADDisposeDriver(madDriver);
	MADDisposeLibrary(madLib);
	if ([[NSUserDefaults standardUserDefaults] boolForKey:PPRememberMusicList]) {
		[musicList saveMusicListToPreferences];
	} else {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:PPMMusicList];
	}
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#if !__has_feature(objc_arc)
- (void)dealloc
{
	[preferences release];
	[musicList release];
	[timeChecker release];
	[plugInInfos release];
	[previouslyPlayingIndex release];
	[currentlyPlayingIndex release];
	self.musicName = nil;
	self.musicInfo = nil;
	[exportController release];
	[instrumentController release];
	
	[super dealloc];
}
#endif

- (IBAction)deleteInstrument:(id)sender
{
    [instrumentController deleteInstrument:sender];
}

- (IBAction)saveInstrumentList:(id)sender
{
	MADBeginExport(madDriver);
	NSSavePanel *savePanel = RETAINOBJ([NSSavePanel savePanel]);
	[savePanel setAllowedFileTypes:@[PPInstrumentListUTI]];
	[savePanel setCanCreateDirectories:YES];
	[savePanel setCanSelectHiddenExtension:YES];
	if (![musicName isEqualToString:@""]) {
		[savePanel setNameFieldStringValue:[NSString stringWithFormat:@"%@'s instruments", musicName]];
	} else {
		[savePanel setNameFieldStringValue:@"Tracker Instruments"];
	}

	if ([savePanel runModal] == NSFileHandlingPanelOKButton) {
		OSErr fileErr = [instrumentController exportInstrumentListToURL:[savePanel URL]];
		if (fileErr) {
			NSError *theErr = CreateErrorFromMADErrorType(fileErr);
			[[NSAlert alertWithError:theErr] runModal];
		}
	}
	
	MADEndExport(madDriver);
	RELEASEOBJ(savePanel);
}

- (IBAction)showBoxEditor:(id)sender
{
    
}

- (IBAction)showClassicEditor:(id)sender
{
    
}

- (IBAction)showDigitalEditor:(id)sender
{
    
}

- (void)musicListContentsDidMove
{
	NSInteger i;
	if (currentlyPlayingIndex.index != -1) {
		for (i = 0; i < [musicList countOfMusicList]; i++) {
			if ([currentlyPlayingIndex.playbackURL isEqual:[musicList URLAtIndex:i]]) {
				currentlyPlayingIndex.index = i;
				break;
			}
		}
	}
	if (previouslyPlayingIndex.index != -1) {
		for (i = 0; i < [musicList countOfMusicList]; i++) {
			if ([previouslyPlayingIndex.playbackURL isEqual:[musicList URLAtIndex:i]]) {
				previouslyPlayingIndex.index = i;
				break;
			}
		}
	}
}

- (IBAction)sortMusicList:(id)sender
{
	[self willChangeValueForKey:kMusicListKVO];
	[musicList sortMusicList];
	[self didChangeValueForKey:kMusicListKVO];
	[self musicListContentsDidMove];
}

- (IBAction)playSelectedMusic:(id)sender
{
	NSError *error = nil;
	currentlyPlayingIndex.index = [tableView selectedRow];
	if ([self loadMusicFromCurrentlyPlayingIndexWithError:&error] == NO)
	{
		[[NSAlert alertWithError:error] runModal];
	}
}

- (IBAction)addMusic:(id)sender
{
	NSOpenPanel *panel = RETAINOBJ([NSOpenPanel openPanel]);
	NSMutableDictionary *trackerDict = [NSMutableDictionary dictionaryWithObject:@[MADNativeUTI] forKey:@"MADK Tracker"];
	
	for (int i = 0; i < madLib->TotalPlug; i++) {
		[trackerDict setObject:BRIDGE(NSArray*, madLib->ThePlug[i].UTItypes) forKey:BRIDGE(NSString*, madLib->ThePlug[i].MenuName)];
	}
	
	OpenPanelViewController *av = [[OpenPanelViewController alloc] initWithOpenPanel:panel trackerDictionary:trackerDict playlistDictionary:nil instrumentDictionary:nil additionalDictionary:nil];
	[av setupDefaults];
	if([panel runModal] == NSFileHandlingPanelOKButton)
	{
		[self addMusicToMusicList:[panel URL]];
	}
	
	RELEASEOBJ(av);
	RELEASEOBJ(panel);
}

- (IBAction)toggleInfo:(id)sender
{
	[infoDrawer toggle:sender];
}

- (void)setTitleForSongLabelBasedOnMusic
{
	self.musicName = AUTORELEASEOBJ([[NSString alloc] initWithCString:music->header->name encoding:NSMacOSRomanStringEncoding]);
	self.musicInfo = AUTORELEASEOBJ([[NSString alloc] initWithCString:music->header->infos encoding:NSMacOSRomanStringEncoding]);
}

- (void)clearMusic
{
	if (music) {
		MADStopMusic(madDriver);
		MADCleanDriver(madDriver);
		MADDisposeMusic(&music, madDriver);
	}
	
	self.paused = YES;
	currentlyPlayingIndex.index = -1;
	currentlyPlayingIndex.playbackURL = nil;
	[currentlyPlayingIndex movePlayingIndexToOtherIndex:previouslyPlayingIndex];
	music = CreateFreeMADK();
	[self setTitleForSongLabelBasedOnMusic];
	[[NSNotificationCenter defaultCenter] postNotificationName:PPMusicDidChange object:self];
	MADAttachDriverToMusic(madDriver, music, NULL);
}

- (IBAction)removeSelectedMusic:(id)sender
{
	NSIndexSet *selMusic = [tableView selectedRowIndexes];
	if ([selMusic containsIndex:currentlyPlayingIndex.index]) {
		if (music->hasChanged) {
			NSInteger selection = NSRunAlertPanel(NSLocalizedString(@"Unsaved Changes", @"Unsaved Changes"), NSLocalizedString(@"The music file \"%@\" has unsaved changes. Do you want to save?", @"edited file"), NSLocalizedString(@"Save", @"Save"), NSLocalizedString(@"Don't Save", @"Don't Save"), NSLocalizedString(@"Cancel", @"Cancel"), [[musicList objectInMusicListAtIndex:currentlyPlayingIndex.index] fileName]);
			switch (selection) {
				case NSAlertDefaultReturn:
					[self saveMusic:sender];
				case NSAlertAlternateReturn:
				default:
					[self clearMusic];
					break;
					
				case NSAlertOtherReturn:
					return;
					break;
			}
		} else {
			[self clearMusic];
		}
	}
	[self willChangeValueForKey:kMusicListKVO];
	[musicList removeObjectsInMusicListAtIndexes:selMusic];
	[self didChangeValueForKey:kMusicListKVO];
	[self musicListContentsDidMove];
}

- (IBAction)newMusic:(id)sender
{
	if (music->hasChanged) {
		NSInteger selection = 0;
		if (currentlyPlayingIndex.index == -1) {
			selection = NSRunAlertPanel(NSLocalizedString(@"Unsaved Changes", @"Unsaved Changes"), NSLocalizedString(@"The new music file has unsaved changes. Do you want to save?", @"New unsaved file"), NSLocalizedString(@"Save", @"Save"), NSLocalizedString(@"Don't Save", @"Don't Save"), NSLocalizedString(@"Cancel", @"Cancel"));
		} else {
			selection = NSRunAlertPanel(NSLocalizedString(@"Unsaved Changes", @"Unsaved Changes"), NSLocalizedString(@"The music file \"%@\" has unsaved changes. Do you want to save?", @"Open unsaved file"), NSLocalizedString(@"Save", @"Save"), NSLocalizedString(@"Don't Save", @"Don't Save"), NSLocalizedString(@"Cancel", @"Cancel"), [[musicList objectInMusicListAtIndex:currentlyPlayingIndex.index] fileName]);
		}
		switch (selection) {
			case NSAlertDefaultReturn:
				[self saveMusic:nil];
				
			case NSAlertAlternateReturn:
			default:
				break;
				
			case NSAlertOtherReturn:
				return;
				break;
		}
	}
	[self clearMusic];
}

- (IBAction)clearMusicList:(id)sender
{
	if ([musicList countOfMusicList]) {
		NSInteger returnVal = NSRunAlertPanel(NSLocalizedString(@"Clear list", @"Clear Music List"), NSLocalizedString(@"The music list contains %ld items. Do you really want to remove them?", @"Clear Music List?"), NSLocalizedString(@"No", @"No"), NSLocalizedString(@"Yes", @"Yes"), nil, (long)[musicList countOfMusicList]);
		
		if (returnVal == NSAlertAlternateReturn) {
			if (music->hasChanged && currentlyPlayingIndex.index != -1) {
				NSInteger selection = NSRunAlertPanel(NSLocalizedString(@"Unsaved Changes", @"Unsaved Changes"), NSLocalizedString(@"The music file \"%@\" has unsaved changes. Do you want to save?", @"Save check with file name"), NSLocalizedString(@"Save", @"Save"), NSLocalizedString(@"Don't Save", @"Don't Save"), NSLocalizedString(@"Cancel", @"Cancel"), [[musicList objectInMusicListAtIndex:currentlyPlayingIndex.index] fileName]);
				switch (selection) {
					case NSAlertDefaultReturn:
						[self saveMusic:nil];
					case NSAlertAlternateReturn:
					default:
						break;
						
					case NSAlertOtherReturn:
						return;
						break;
				}
			}

			[self willChangeValueForKey:kMusicListKVO];
			[musicList clearMusicList];
			[self didChangeValueForKey:kMusicListKVO];
			if (currentlyPlayingIndex.index != -1) {
				[self clearMusic];
			}
		}
	} else {
		NSBeep();
	}
}

enum PPMusicToolbarTypes {
	PPToolbarSort = 1001,
	PPToolbarAddMusic,
	PPToolbarRemoveMusic,
	PPToolbarPlayMusic,
	PPToolbarFileInfo = 1005
};

- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem
{
	switch ([theItem tag]) {
		case PPToolbarSort:
		case PPToolbarAddMusic:
			return YES;
			break;
			
		case PPToolbarFileInfo:
			if ([infoDrawer state] == NSDrawerOpeningState || [infoDrawer state] == NSDrawerOpenState) {
				return YES;
			}
		case PPToolbarPlayMusic:
			if([[tableView selectedRowIndexes] count] == 1) {
				return YES;
			} else {
				return NO;
			}
			break;
			
		case PPToolbarRemoveMusic:
			if([[tableView selectedRowIndexes] count] > 0) {
				return YES;
			} else {
				return NO;
			}
			break;

		default:
			return NO;
			break;
	}
}

- (void)soundPreferencesDidChange:(NSNotification *)notification
{
	[self MADDriverWithPreferences];
}

- (BOOL)handleFile:(NSURL *)theURL ofType:(NSString *)theUTI
{
	NSWorkspace *sharedWorkspace = [NSWorkspace sharedWorkspace];
	if ([sharedWorkspace type:theUTI conformsToType:PPMusicListUTI]) {
		if ([self musicListWillChange]) {
			[self willChangeValueForKey:kMusicListKVO];
			[musicList loadMusicListAtURL:theURL];
			selMusFromList = musicList.selectedMusic;
			[self didChangeValueForKey:kMusicListKVO];
			[self musicListDidChange];
			return YES;
		}
	} else if ([sharedWorkspace type:theUTI conformsToType:PPOldMusicListUTI]) {
		if ([self musicListWillChange]) {
			[self willChangeValueForKey:kMusicListKVO];
			[musicList loadOldMusicListAtURL:theURL];
			selMusFromList = musicList.selectedMusic;
			[self didChangeValueForKey:kMusicListKVO];
			[self musicListDidChange];
			return YES;
		}
	} else if ([sharedWorkspace type:theUTI conformsToType:PPPCMDUTI]) {
		OSErr theOSErr = [patternHandler importPcmdFromURL:theURL];
		if (theOSErr != noErr) {
			NSError *theErr = CreateErrorFromMADErrorType(theOSErr);
			[[NSAlert alertWithError:theErr] runModal];
			RELEASEOBJ(theErr);
			return NO;
		}
		return YES;
	} else if([sharedWorkspace type:theUTI conformsToType:PPInstrumentListUTI]) {
		NSError *err = nil;
		if (![instrumentController importInstrumentListFromURL:theURL error:&err]) {
			[[NSAlert alertWithError:err] runModal];
		} else return YES;
	} else {
		{
			NSMutableArray *trackerUTIs = [NSMutableArray array];
			for (int i = 0; i < madLib->TotalPlug; i++) {
				[trackerUTIs addObjectsFromArray:BRIDGE(NSArray *, madLib->ThePlug[i].UTItypes)];
			}
			for (NSString *aUTI in trackerUTIs) {
				if([sharedWorkspace type:theUTI conformsToType:aUTI])
				{
					[self addMusicToMusicList:theURL];
					return YES;
				}
			}
		}
		{
			NSMutableArray *instrumentArray = [NSMutableArray array];
			for (PPInstrumentImporterObject *obj in instrumentImporter) {
				[instrumentArray addObjectsFromArray:obj.UTITypes];
			}
			
			for (NSString *aUTI in instrumentArray) {
				if ([sharedWorkspace type:theUTI conformsToType:aUTI]) {
					if ([instrumentController isWindowLoaded]) {
						NSError *theErr = nil;
						if (![instrumentController importSampleFromURL:theURL makeUserSelectInstrument:YES error:&theErr])
						{
							[[NSAlert alertWithError:theErr] runModal];
							return NO;
						}
						return YES;
					} else return NO;
				}
			}
		}
	}
	return NO;
}

- (IBAction)openFile:(id)sender {
	NSOpenPanel *panel = RETAINOBJ([NSOpenPanel openPanel]);
	int i = 0;
	NSMutableDictionary *trackerDict = [NSMutableDictionary dictionaryWithObject:@[MADNativeUTI] forKey:@"MADK Tracker"];
	NSDictionary *playlistDict = [NSDictionary dictionaryWithObjectsAndKeys:@[PPMusicListUTI], @"PlayerPRO Music List", @[PPOldMusicListUTI], @"PlayerPRO Old Music List", nil];
	for (i = 0; i < madLib->TotalPlug; i++) {
		[trackerDict setObject:BRIDGE(NSArray*, madLib->ThePlug[i].UTItypes) forKey:BRIDGE(NSString*, madLib->ThePlug[i].MenuName)];
	}
		
	NSMutableDictionary *samplesDict = nil;
	if ([instrumentController isWindowLoaded]) {
		NSInteger plugCount = [instrumentImporter plugInCount];
		samplesDict = [[NSMutableDictionary alloc] initWithCapacity:plugCount];
		for (PPInstrumentImporterObject *obj in instrumentImporter) {
			NSArray *tmpArray = obj.UTITypes;
			[samplesDict setObject:tmpArray forKey:obj.menuName];
		}
	}

	NSDictionary *otherDict = [NSDictionary dictionaryWithObjectsAndKeys:@[PPPCMDUTI], @"PCMD", @[PPInstrumentListUTI], @"Instrument List", nil];
		
	OpenPanelViewController *av = [[OpenPanelViewController alloc] initWithOpenPanel:panel trackerDictionary:trackerDict playlistDictionary:playlistDict instrumentDictionary:samplesDict additionalDictionary:otherDict];
	[av setupDefaults];
	RELEASEOBJ(samplesDict);
	if([panel runModal] == NSFileHandlingPanelOKButton)
	{
		NSURL *panelURL = [panel URL];
		NSString *filename = [panelURL path];
		NSError *err = nil;
		NSString *utiFile = [[NSWorkspace sharedWorkspace] typeOfFile:filename error:&err];
		if (err) {
			NSRunAlertPanel(@"Error opening file", @"Unable to open %@: %@", nil, nil, nil, [filename lastPathComponent], [err localizedFailureReason]);
			RELEASEOBJ(panel);
			RELEASEOBJ(av);
			return;
		}
		[self handleFile:panelURL ofType:utiFile];
	}
	RELEASEOBJ(panel);
	RELEASEOBJ(av);
}

- (IBAction)saveMusicList:(id)sender {
	NSSavePanel *savePanel = RETAINOBJ([NSSavePanel savePanel]);
	[savePanel setAllowedFileTypes:@[PPMusicListUTI]];
	[savePanel setCanCreateDirectories:YES];
	[savePanel setCanSelectHiddenExtension:YES];
	if ([savePanel runModal] == NSFileHandlingPanelOKButton) {
		[musicList saveMusicListToURL:[savePanel URL]];
	}
	RELEASEOBJ(savePanel);
}

- (IBAction)fastForwardButtonPressed:(id)sender
{
    
}

- (IBAction)loopButtonPressed:(id)sender
{
    
}

- (IBAction)nextButtonPressed:(id)sender
{
    if (currentlyPlayingIndex.index + 1 < [musicList countOfMusicList]) {
		currentlyPlayingIndex.index++;
		[self selectCurrentlyPlayingMusic];
		NSError *err = nil;
		if (![self loadMusicFromCurrentlyPlayingIndexWithError:&err]) {
			[[NSAlert alertWithError:err] runModal];
		}
	} else if ([[NSUserDefaults standardUserDefaults] boolForKey:PPLoopMusicWhenDone]) {
		currentlyPlayingIndex.index = 0;
		[self selectCurrentlyPlayingMusic];
		NSError *err = nil;
		if (![self loadMusicFromCurrentlyPlayingIndexWithError:&err]) {
			[[NSAlert alertWithError:err] runModal];
		}
	} else NSBeep();
}

- (IBAction)playButtonPressed:(id)sender
{
	if (music) {
		MADPlayMusic(madDriver);
		self.paused = NO;
	}
}

- (IBAction)prevButtonPressed:(id)sender
{
    if (currentlyPlayingIndex.index > 0) {
		currentlyPlayingIndex.index--;
		[self selectCurrentlyPlayingMusic];
		NSError *err = nil;
		if (![self loadMusicFromCurrentlyPlayingIndexWithError:&err]) {
			[[NSAlert alertWithError:err] runModal];
		}
	} else NSBeep();
}

- (IBAction)recordButtonPressed:(id)sender
{
    
}

- (IBAction)rewindButtonPressed:(id)sender
{
    
}

- (IBAction)sliderChanged:(id)sender
{
    if(music){
		MADSetMusicStatus(madDriver, 0, [songPos maxValue], [songPos doubleValue]);
	}
}

- (IBAction)stopButtonPressed:(id)sender
{
    if (music) {
		MADStopMusic(madDriver);
		MADCleanDriver(madDriver);
		MADSetMusicStatus(madDriver, 0, 100, 0);
		self.paused = YES;
	}
}

- (IBAction)pauseButtonPressed:(id)sender {
	if (music) {
		if (paused) {
			MADPlayMusic(madDriver);
		} else {
			MADStopMusic(madDriver);
			MADCleanDriver(madDriver);
		}
		self.paused = !paused;
	}
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	NSIndexSet *selected = [tableView selectedRowIndexes];
	do {
		if ([selected count] > 0) {
			musicList.selectedMusic = [selected firstIndex];
		}
		
		if ([selected count] != 1)
			break;

		PPMusicListObject *obj = [musicList objectInMusicListAtIndex:[selected lastIndex]];
		
		NSURL *musicURL = obj.musicUrl;
		PPInfoRec theInfo;
		char info[5] = {0};
		if(MADMusicIdentifyCFURL(madLib, info, BRIDGE(CFURLRef, musicURL)) != noErr) break;
		if(MADMusicInfoCFURL(madLib, info, BRIDGE(CFURLRef, musicURL), &theInfo) != noErr) break;
		[fileName setTitleWithMnemonic:obj.fileName];
		[internalName setTitleWithMnemonic:[NSString stringWithCString:theInfo.internalFileName encoding:NSMacOSRomanStringEncoding]];
		[fileSize setIntegerValue:theInfo.fileSize];
		[musicInstrument setTitleWithMnemonic:[NSString stringWithFormat:@"%d", theInfo.totalInstruments]];
		[musicPatterns setTitleWithMnemonic:[NSString stringWithFormat:@"%ld", (long)theInfo.totalPatterns]];
		[musicPlugType setTitleWithMnemonic:[NSString stringWithCString:theInfo.formatDescription encoding:NSMacOSRomanStringEncoding]];
		{
			char sig[5] = {0};
			OSType2Ptr(theInfo.signature, sig);
			NSString *NSSig = [NSString stringWithCString:sig encoding:NSMacOSRomanStringEncoding];
			if (!NSSig) {
				NSSig = [NSString stringWithFormat:@"0x%04X", (unsigned int)theInfo.signature];
			}
			[musicSignature setTitleWithMnemonic:NSSig];
		}
		[fileLocation setTitleWithMnemonic:[musicURL path]];
		return;
	} while (0);
	
	[fileName setTitleWithMnemonic:PPDoubleDash];
	[internalName setTitleWithMnemonic:PPDoubleDash];
	[fileSize setTitleWithMnemonic:PPDoubleDash];
	[musicInstrument setTitleWithMnemonic:PPDoubleDash];
	[musicPatterns setTitleWithMnemonic:PPDoubleDash];
	[musicPlugType setTitleWithMnemonic:PPDoubleDash];
	[musicSignature setTitleWithMnemonic:PPDoubleDash];
	[fileLocation setTitleWithMnemonic:PPDoubleDash];
}

- (void)moveMusicAtIndex:(NSUInteger)from toIndex:(NSUInteger)to
{
	PPMusicListObject *obj = RETAINOBJ([musicList objectInMusicListAtIndex:from]);
	[self willChangeValueForKey:kMusicListKVO];
	[musicList removeObjectInMusicListAtIndex:from];
	if (to > from) {
		to--;
	}
	[musicList insertObject:obj inMusicListAtIndex:to];
	[self didChangeValueForKey:kMusicListKVO];
	RELEASEOBJ(obj);
	[self musicListContentsDidMove];
}

- (void)musicListDidChange
{
	if (currentlyPlayingIndex.index != -1) {
		MADStopMusic(madDriver);
		MADCleanDriver(madDriver);
		MADDisposeMusic(&music, madDriver);
	}
	if ([[NSUserDefaults standardUserDefaults] boolForKey:PPLoadMusicAtListLoad] && [musicList countOfMusicList] > 0) {
		NSError *err = nil;
		currentlyPlayingIndex.index = selMusFromList != -1 ? selMusFromList : 0;
		[self selectCurrentlyPlayingMusic];
		if (![self loadMusicFromCurrentlyPlayingIndexWithError:&err])
		{
			[[NSAlert alertWithError:err] runModal];
		}
	} else if (selMusFromList != -1)
		[self selectMusicAtIndex:selMusFromList];
	NSUInteger lostCount = musicList.lostMusicCount;
	if (lostCount) {
		NSRunAlertPanel(kUnresolvableFile, kUnresolvableFileDescription, nil, nil, nil, (unsigned long)lostCount);
	}
}

- (BOOL)musicListWillChange
{
	if (music) {
		if (music->hasChanged) {
			if (currentlyPlayingIndex.index == -1) {
				return YES;
			} else {
				NSInteger selection = NSRunAlertPanel(NSLocalizedString(@"Unsaved Changes", @"Unsaved Changes"), NSLocalizedString(@"The music file \"%@\" has unsaved changes. Do you want to save?", @"file is unsaved"), NSLocalizedString(@"Save", @"Save"), NSLocalizedString(@"Don't Save", @"Don't save"), NSLocalizedString(@"Cancel", @"Cancel"), [[musicList objectInMusicListAtIndex:currentlyPlayingIndex.index] fileName]);
				switch (selection) {
					case NSAlertDefaultReturn:
						[self saveMusic:nil];
					case NSAlertAlternateReturn:
					default:
						return YES;
						break;
						
					case NSAlertOtherReturn:
						return NO;
						break;
				}
			}
		}
	}
	return YES;
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	NSError *err = nil;
	NSString *utiFile = [[NSWorkspace sharedWorkspace] typeOfFile:filename error:&err];
	if (err) {
		NSRunAlertPanel(@"Error opening file", @"Unable to open %@: %@", nil, nil, nil, [filename lastPathComponent], [err localizedFailureReason]);
		return NO;
	}
	return [self handleFile:[NSURL fileURLWithPath:filename] ofType:utiFile];
}

#pragma mark PPSoundSettingsViewControllerDelegate methods

- (void)soundOutBitsDidChange:(short)bits
{
	exportSettings.outPutBits = bits;
}

- (void)soundOutRateDidChange:(unsigned int)rat
{
	exportSettings.outPutRate = rat;
}

- (void)soundOutReverbDidChangeActive:(BOOL)isAct
{
	exportSettings.Reverb = isAct;
}

- (void)soundOutOversamplingDidChangeActive:(BOOL)isAct
{
	if (!isAct) {
		exportSettings.oversampling = 1;
	}
}

- (void)soundOutStereoDelayDidChangeActive:(BOOL)isAct
{
	if (!isAct) {
		exportSettings.MicroDelaySize = 0;
	}
}

- (void)soundOutSurroundDidChangeActive:(BOOL)isAct
{
	exportSettings.surround = isAct;
}

- (void)soundOutReverbStrengthDidChange:(short)rev
{
	exportSettings.ReverbStrength = rev;
}

- (void)soundOutReverbSizeDidChange:(short)rev
{
	exportSettings.ReverbSize = rev;
}

- (void)soundOutOversamplingAmountDidChange:(short)ovs
{
	exportSettings.oversampling = ovs;
}

- (void)soundOutStereoDelayAmountDidChange:(short)std
{
	exportSettings.MicroDelaySize = std;
}

@end
