//
//  PPMIDIImportHelper.h
//  PPMacho
//
//  Created by C.W. Betts on 8/6/14.
//
//

#import <Foundation/Foundation.h>
#include <PlayerPROCore/MADDefs.h>

NS_ASSUME_NONNULL_BEGIN

@protocol PPMIDIImportHelper <NSObject>

- (void)importMIDIFileAtURL:(NSURL*)theURL numberOfTracks:(NSInteger)trackNum useQTInstruments:(BOOL)qtIns withReply:(void (^)(NSData *__nullable theData, MADErr error))reply;

@end

@interface PPMIDIImporter : NSObject <NSXPCListenerDelegate, PPMIDIImportHelper>
+ (instancetype)sharedImporter;
@end

NS_ASSUME_NONNULL_END
