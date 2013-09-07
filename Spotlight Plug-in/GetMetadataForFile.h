//
//  GetMetadataForFile.h
//  MDImporterPlugin
//
//  Created by C.W. Betts on 2/22/13.
//
//

#ifndef MDImporterPlugin_GetMetadataForFile_h
#define MDImporterPlugin_GetMetadataForFile_h

#include <CoreFoundation/CFDictionary.h>
#include <CoreFoundation/CFString.h>

const CFStringRef kPPMDInstumentsList __attribute__ ((visibility ("hidden")));
const CFStringRef kPPMDPatternList __attribute__ ((visibility ("hidden")));
const CFStringRef kPPMDTotalPatterns __attribute__ ((visibility ("hidden")));
const CFStringRef kPPMDPartitionLength __attribute__ ((visibility ("hidden")));
const CFStringRef kPPMDTotalInstruments __attribute__ ((visibility ("hidden")));
const CFStringRef kPPMDTotalTracks __attribute__ ((visibility ("hidden")));
const CFStringRef kPPMDFormatDescription __attribute__ ((visibility ("hidden")));


// The import function to be implemented in GetMetadataForFile.c
__private_extern__ Boolean GetMetadataForFile(void *thisInterface,
											  CFMutableDictionaryRef attributes,
											  CFStringRef contentTypeUTI,
											  CFStringRef pathToFile);
__private_extern__ Boolean GetMetadataForPackage(CFMutableDictionaryRef attributes,
												 CFStringRef pathToFile);

#endif
