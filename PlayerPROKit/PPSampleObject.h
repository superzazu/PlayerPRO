//
//  PPInstrumentObject.h
//  PPMacho
//
//  Created by C.W. Betts on 1/10/13.
//
//

#ifndef __PLAYERPROKIT_PPSAMPLEOBJECT_H__
#define __PLAYERPROKIT_PPSAMPLEOBJECT_H__

#import <Foundation/Foundation.h>
#include <PlayerPROCore/MAD.h>
#import <PlayerPROKit/PPObjectProtocol.h>

#ifndef NS_DESIGNATED_INITIALIZER
#define NS_DESIGNATED_INITIALIZER
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 *	@class PPSampleObject
 *	@seealso sData
 */
@interface PPSampleObject : NSObject <PPObject>
@property (readwrite) NSInteger sampleIndex;
@property (readwrite) NSInteger instrumentIndex;
@property (readonly) sData theSample;

- (instancetype)init;
- (instancetype)initWithSData:(nullable in sData *)theData NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;
- (sData *)createSData;

/**
 *	Sample length
 *	@deprecated get the length by calling <code>data.length</code>.
 */
- (int)dataSize DEPRECATED_ATTRIBUTE;

/// The beginning of the loop.
@property int loopBegin;
/// The length of the loop.
@property int loopSize;
/// The base volume.
@property MADByte volume;
/// The sound sample's sample rate.
@property unsigned short c2spd;
/// The loop type, either classic or ping-pong.
@property MADLoopType loopType;
/// The sound sample's amplitude. Currently limited to 8 or 16 bits.
@property MADByte amplitude;
/// Real note.
@property char realNote;
/// Sample name.
@property (copy, null_resettable) NSString *name;
/// Is the sample stereo?
@property (getter = isStereo) BOOL stereo;
/// The data of the sample's sound, wrapped in an \c NSData class object.
@property (copy, null_resettable) NSData *data;
/// The range of the loop.
/// A range with a location of \c NSNotFound means a blank loop.
@property NSRange loop;


/// Used to tell if a sample is blank
/// @discussion A sample is blank if the name is blank (has a length of zero) and there's no data.
@property (readonly, getter=isBlankSample) BOOL blankSample;

@end

__BEGIN_DECLS
extern short PPNoteFromString(NSString *aNote);
extern NSString *PPStringFromNote(short note);
__END_DECLS

NS_ASSUME_NONNULL_END

#endif
