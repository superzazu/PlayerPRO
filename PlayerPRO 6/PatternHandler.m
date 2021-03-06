//
//  PatternHandler.m
//  PPMacho
//
//  Created by C.W. Betts on 2/3/13.
//
//

#import "PatternHandler.h"
#import "UserDefaultKeys.h"

static inline void SwapPcmd(Pcmd *toswap)
{
	if (!toswap) {
		return;
	}
	MADBE32(&toswap->structSize);
	MADBE16(&toswap->length);
	MADBE16(&toswap->posStart);
	MADBE16(&toswap->tracks);
	MADBE16(&toswap->trackStart);
}

@implementation PatternHandler

@synthesize theMus;
@synthesize theRec;
@synthesize undoManager;

- (void)musicDidChange:(NSNotification *)aNot
{
	//TODO: load patterns into pattern list
	[patternList removeAllObjects];
}

- (instancetype)initWithMusic:(MADMusic **)mus
{
	if (self = [super init]) {
		theMus = mus;
		[[NSNotificationCenter defaultCenter]  addObserver:self selector:@selector(musicDidChange:) name:PPMusicDidChangeNotification object:nil];
		patternList = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (OSErr)testPcmdFileAtURL:(NSURL*)theURL
{
	OSErr err = MADNoErr;
	Pcmd thePcmd;
	NSData *pcmdData = [[NSData alloc] initWithContentsOfURL:theURL];
	if (!pcmdData) {
		return MADReadingErr;
	}
	[pcmdData getBytes:&thePcmd length:sizeof(thePcmd)];
	SwapPcmd(&thePcmd);
	if (thePcmd.structSize != [pcmdData length]) {
		err = MADIncompatibleFile;
	}
	return err;
}

- (OSErr)importPcmdFromURL:(NSURL*)theURL
{
	OSErr theErr = MADNoErr;
	theErr = [[self class] testPcmdFileAtURL:theURL];
	if (theErr) {
		return theErr;
	}
	Pcmd *thePcmd;
	NSData *pcmdData = [[NSData alloc] initWithContentsOfURL:theURL];
	if (!pcmdData) {
		return MADReadingErr;
	}
	NSInteger pcmdLen = [pcmdData length];
	
	thePcmd = malloc(pcmdLen);
	if (!thePcmd) {
		return MADNeedMemory;
	}
	[pcmdData getBytes:thePcmd length:pcmdLen];
	SwapPcmd(thePcmd);
	
	if (thePcmd->structSize != pcmdLen) {
		free(thePcmd);
		return MADIncompatibleFile;
	}
	
	//TODO: put Pcmd data onto the music file
	
	free(thePcmd);
	
	return MADNoErr;
}

@end
