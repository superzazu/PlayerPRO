//
//  PPPatternObject.m
//  PPMacho
//
//  Created by C.W. Betts on 1/17/13.
//
//

#import "PPPatternObject.h"
#import "PPPatternObject_PPKPrivate.h"
#import "PPMusicObject_PPKPrivate.h"

#define kPPPatternName @"PlayerPROKit Pattern Name"
#define kPPPatternCommands @"PlayerPROKit Pattern Commands"
#define kPPPatternIndex @"PlayerPROKit Pattern Index"

@implementation PPPatternObject
@synthesize commands;
@synthesize index;

- (id)initWithMusic:(PPMusicObjectWrapper *)mus patternAtIndex:(short)ptnIdx
{
	if (self = [super init]) {
		if (!mus) {
			return nil;
		}
		_musicWrapper = mus;
		patternHeader = _musicWrapper._currentMusic->partition[ptnIdx]->header;
		index = ptnIdx;
		NSInteger size = _musicWrapper._currentMusic->header->numChn * patternHeader.size;
		self.commands = [[NSMutableArray alloc] initWithCapacity:size];
		for (int i = 0; i < size; i++) {
			PPMadCommandObject *tmpObj = [[PPMadCommandObject alloc] initWithCmd:&_musicWrapper._currentMusic->partition[ptnIdx]->Cmds[i]];
			[self.commands addObject:tmpObj];
		}
		self.patternName = [[NSString alloc] initWithCString:patternHeader.name encoding:NSMacOSRomanStringEncoding];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if (self = [super init]) {
		self.patternName = [aDecoder decodeObjectForKey:kPPPatternName];
		self.commands = [(NSArray*)[aDecoder decodeObjectForKey:kPPPatternCommands] mutableCopy];
		index = [aDecoder decodeIntegerForKey:kPPPatternIndex];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:_patternName forKey:kPPPatternName];
	[aCoder encodeObject:commands forKey:kPPPatternCommands];
	[aCoder encodeInteger:index forKey:kPPPatternIndex];
}

@end
