//
//  MidiHardwarePreferenceController.h
//  PPMacho
//
//  Created by C.W. Betts on 7/26/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MASPreferences/MASPreferencesViewController.h>

@interface MidiHardwarePreferenceController : NSViewController <MASPreferencesViewController>

+ (nullable instancetype)newPreferenceView NS_RETURNS_RETAINED;

@end
