//
//  UserDefaultKeys.h
//  PPMacho
//
//  Created by C.W. Betts on 9/21/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//
#import <Foundation/NSString.h>

#pragma GCC visibility push(hidden)
#pragma mark Notifications
extern NSString * const PPListPreferencesDidChange;
#define PPSoundPreferencesDidChange @"Sound Preferences changed"
extern NSString * const PPDigitalEditorPrefrencesDidChange;
extern NSString * const PPBoxEditorPreferencesDidChange;
extern NSString * const PPClassicalEditorPreferencesDidChange;
extern NSString * const PPMiscPreferencesDidChange;
extern NSString * const PPColorsDidChange;
#define PPMusicDidChange @"PP Music changed"
#define PPDriverDidChange @"PlayerPRO Driver did change"
extern NSString * const PPColorChangedColor;
extern NSString * const PPColorChangedValue;

#pragma mark UTIs
#define MADNativeUTI @"com.quadmation.playerpro.madk"
#define MADGenericUTI @"com.quadmation.playerpro.mad"
#define PPMusicListUTI @"net.sourceforge.playerpro.musiclist"
#define PPOldMusicListUTI @"com.quadmation.playerpro.stcfmusiclist"
#define PPPCMDUTI @"com.quadmation.playerpro.pcmd"
#define PPGenericTrackerUTI @"net.sourceforge.playerpro.tracker"
#define PPGenericInstrumentUTI @"net.sourceforge.playerpro.instrumentfile"
#define PPInstrumentListUTI @"com.quadmation.playerpro.list"
#define PPMLDCUTI @"net.sourceforge.playerpro.PlayerPRO-Player.playerlistdragtype"

#pragma mark Music list preference keys
extern NSString * const PPRememberMusicList;
extern NSString * const PPLoadMusicAtListLoad;
extern NSString * const PPAfterPlayingMusic;
extern NSString * const PPGotoStartupAfterPlaying;
extern NSString * const PPSaveModList;
extern NSString * const PPLoadMusicAtMusicLoad;
extern NSString * const PPLoopMusicWhenDone;

#pragma mark Sound driver Preference keys
extern NSString * const PPSoundOutBits;
extern NSString * const PPSoundOutRate;
extern NSString * const PPSoundDriver;
extern NSString * const PPStereoDelayToggle;
extern NSString * const PPReverbToggle;
extern NSString * const PPSurroundToggle;
extern NSString * const PPOversamplingToggle;
extern NSString * const PPStereoDelayAmount;
extern NSString * const PPReverbAmount;
extern NSString * const PPReverbStrength;
extern NSString * const PPOversamplingAmount;

#pragma mark Digital Editor preference keys
extern NSString * const PPDEShowInstrument;
extern NSString * const PPDEShowNote;
extern NSString * const PPDEShowEffect;
extern NSString * const PPDEShowArgument;
extern NSString * const PPDEShowVolume;
extern NSString * const PPDEShowMarkers;
extern NSString * const PPDEMarkerOffsetPref;
extern NSString * const PPDEMarkerLoopPref;
extern NSString * const PPDEMarkerColorPref;
extern NSString * const PPDEMouseClickControlPref;
extern NSString * const PPDEMouseClickShiftPref;
extern NSString * const PPDEMouseClickCommandPref;
extern NSString * const PPDEMouseClickOptionPref;
extern NSString * const PPDELineHeightNormal;
extern NSString * const PPDEMusicTraceOn;
extern NSString * const PPDEPatternWrappingPartition;
extern NSString * const PPDEDragAsPcmd;

#if !TARGET_OS_IPHONE
#pragma mark Color preference keys
#define PPCColor1 @"PPColor 1"
#define PPCColor2 @"PPColor 2"
#define PPCColor3 @"PPColor 3"
#define PPCColor4 @"PPColor 4"
#define PPCColor5 @"PPColor 5"
#define PPCColor6 @"PPColor 6"
#define PPCColor7 @"PPColor 7"
#define PPCColor8 @"PPColor 8"
#define PPCColor9 @"PPColor 9"
#define PPCColor10 @"PPColor 10"
#define PPCColor11 @"PPColor 11"
#define PPCColor12 @"PPColor 12"
#define PPCColor13 @"PPColor 13"
#define PPCColor14 @"PPColor 14"
#define PPCColor15 @"PPColor 15"
#define PPCColor16 @"PPColor 16"
#define PPCColor17 @"PPColor 17"
#define PPCColor18 @"PPColor 18"
#define PPCColor19 @"PPColor 19"
#define PPCColor20 @"PPColor 20"
#define PPCColor21 @"PPColor 21"
#define PPCColor22 @"PPColor 22"
#define PPCColor23 @"PPColor 23"
#define PPCColor24 @"PPColor 24"
#define PPCColor25 @"PPColor 25"
#define PPCColor26 @"PPColor 26"
#define PPCColor27 @"PPColor 27"
#define PPCColor28 @"PPColor 28"
#define PPCColor29 @"PPColor 29"
#define PPCColor30 @"PPColor 30"
#define PPCColor31 @"PPColor 31"
#define PPCColor32 @"PPColor 32"
#define PPCColor33 @"PPColor 33"
#define PPCColor34 @"PPColor 34"
#define PPCColor35 @"PPColor 35"
#define PPCColor36 @"PPColor 36"
#define PPCColor37 @"PPColor 37"
#define PPCColor38 @"PPColor 38"
#define PPCColor39 @"PPColor 39"
#define PPCColor40 @"PPColor 40"
#define PPCColor41 @"PPColor 41"
#define PPCColor42 @"PPColor 42"
#define PPCColor43 @"PPColor 43"
#define PPCColor44 @"PPColor 44"
#define PPCColor45 @"PPColor 45"
#define PPCColor46 @"PPColor 46"
#define PPCColor47 @"PPColor 47"
#define PPCColor48 @"PPColor 48"
#define PPCColor49 @"PPColor 49"
#define PPCColor50 @"PPColor 50"
#define PPCColor51 @"PPColor 51"
#define PPCColor52 @"PPColor 52"
#define PPCColor53 @"PPColor 53"
#define PPCColor54 @"PPColor 54"
#define PPCColor55 @"PPColor 55"
#define PPCColor56 @"PPColor 56"
#define PPCColor57 @"PPColor 57"
#define PPCColor58 @"PPColor 58"
#define PPCColor59 @"PPColor 59"
#define PPCColor60 @"PPColor 60"
#define PPCColor61 @"PPColor 61"
#define PPCColor62 @"PPColor 62"
#define PPCColor63 @"PPColor 63"
#define PPCColor64 @"PPColor 64"
#define PPCColor65 @"PPColor 65"
#define PPCColor66 @"PPColor 66"
#define PPCColor67 @"PPColor 67"
#define PPCColor68 @"PPColor 68"
#define PPCColor69 @"PPColor 69"
#define PPCColor70 @"PPColor 70"
#define PPCColor71 @"PPColor 71"
#define PPCColor72 @"PPColor 72"
#define PPCColor73 @"PPColor 73"
#define PPCColor74 @"PPColor 74"
#define PPCColor75 @"PPColor 75"
#define PPCColor76 @"PPColor 76"
#define PPCColor77 @"PPColor 77"
#define PPCColor78 @"PPColor 78"
#define PPCColor79 @"PPColor 79"
#define PPCColor80 @"PPColor 80"
#define PPCColor81 @"PPColor 81"
#define PPCColor82 @"PPColor 82"
#define PPCColor83 @"PPColor 83"
#define PPCColor84 @"PPColor 84"
#define PPCColor85 @"PPColor 85"
#define PPCColor86 @"PPColor 86"
#define PPCColor87 @"PPColor 87"
#define PPCColor88 @"PPColor 88"
#define PPCColor89 @"PPColor 89"
#define PPCColor90 @"PPColor 90"
#define PPCColor91 @"PPColor 91"
#define PPCColor92 @"PPColor 92"
#define PPCColor93 @"PPColor 93"
#define PPCColor94 @"PPColor 94"
#define PPCColor95 @"PPColor 95"
#define PPCColor96 @"PPColor 96"
#endif

#pragma mark Box editor preference keys
extern NSString * const PPBEMarkersEnabled;
extern NSString * const PPBEMarkersOffset;
extern NSString * const PPBEMarkersLoop;
extern NSString * const PPBEOctaveMarkers;
extern NSString * const PPBENotesProjection;

#pragma mark miscelaneous preference keys
extern NSString * const PPMAddExtension;
extern NSString * const PPMMadCompression;
extern NSString * const PPMNoLoadMixerFromFiles;
extern NSString * const PPMOscilloscopeDrawLines;

#pragma mark Classic editor preference keys
extern NSString * const PPCEShowNotesLen;
extern NSString * const PPCEShowMarkers;
extern NSString * const PPCEMarkerOffset;
extern NSString * const PPCEMarkerLoop;
extern NSString * const PPCETempoNum;
extern NSString * const PPCETempoUnit;
extern NSString * const PPCETrackHeight;

#pragma mark Preference identifiers
#define PPSoundSettPrefID @"PPSoundOut"
#define PPMusicListPrefID @"PPMusicList"
#define PPPianoPrefID @"PPPiano"
#define PPColorPrefID @"PPColors"
#define PPMiscPrefID @"PPMisc"
#define PPDigitalPrefID @"PPDigital"
#define PPMIDIPrefID @"PPMIDI"
#define PPBoxPrefID @"PPBox"
#define PPClassicPrefID @"PPClassical"

#pragma mark Misc./other
#define PPDoubleDash @"--"
#define kMusicListKVO @"musicList"
#define PPEscapeValue @"\e"

#pragma GCC visibility pop
