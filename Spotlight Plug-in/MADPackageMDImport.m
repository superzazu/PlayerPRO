//
//  MADPackageMDImport.m
//  PPMacho
//
//  Created by C.W. Betts on 9/7/13.
//
//

#import <Cocoa/Cocoa.h>
#include "GetMetadataForFile.h"

Boolean GetMetadataForPackage(CFMutableDictionaryRef attributes, CFStringRef pathToFile)
{
	NSMutableDictionary *outDict = (__bridge NSMutableDictionary*)attributes;
	NSURL *fileURL = [NSURL fileURLWithPath:(__bridge NSString*)pathToFile];
	
	
	
	
}


