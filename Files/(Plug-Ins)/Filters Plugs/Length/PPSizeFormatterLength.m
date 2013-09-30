//
//  PPFileSizeFormatter.m
//  PPMacho
//
//  Created by C.W. Betts on 2/23/13.
//
//

#import "PPSizeFormatterLength.h"

@interface PPSizeFormatterLength ()
@property (strong) NSByteCountFormatter *cocoaFilesizeFormatter;
@end

@implementation PPSizeFormatterLength
@synthesize cocoaFilesizeFormatter;

- (id)init
{
	if (self = [super init]) {
		if ([NSByteCountFormatter class]) {
			self.cocoaFilesizeFormatter = [[NSByteCountFormatter alloc] init];
			[cocoaFilesizeFormatter setCountStyle:NSByteCountFormatterCountStyleBinary];
			[cocoaFilesizeFormatter setAdaptive:YES];
		}
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if (self = [super initWithCoder:aDecoder]) {
		if ([NSByteCountFormatter class]) {
			self.cocoaFilesizeFormatter = [[NSByteCountFormatter alloc] init];
			[cocoaFilesizeFormatter setCountStyle:NSByteCountFormatterCountStyleBinary];
			[cocoaFilesizeFormatter setAdaptive:YES];
		}
	}
	return self;
}

- (NSString *)stringForObjectValue:(id)obj
{
	if (cocoaFilesizeFormatter) {
		return [cocoaFilesizeFormatter stringForObjectValue:obj];
	}
	
	if ([obj isKindOfClass:[NSNumber class]]) {
		NSInteger fileSize = [obj integerValue];
		if (fileSize < 1000) {
			return [NSString stringWithFormat:@"%ld bytes", (long)fileSize];
		} else if (fileSize < 1000 * 1000) {
			return [NSString stringWithFormat:@"%.2lf kiB", fileSize / 1024.0];
		} else {
			return [NSString stringWithFormat:@"%.2lf MiB", fileSize / (1024.0 * 1024.0)];
		}
	} else return nil;
}

- (BOOL)getObjectValue:(out id *)obj forString:(NSString *)string errorDescription:(out NSString **)error
{
	if (cocoaFilesizeFormatter) {
		return [cocoaFilesizeFormatter getObjectValue:obj forString:string errorDescription:error];
	}
	double fileSize = 0;
	char typeSpecifier[8] = {0};
	if(sscanf([string UTF8String], "%lf %s", &fileSize, typeSpecifier) != 2)
	{
		if (error)
			*error = @"Unknown format";
		*obj = nil;
		return NO;
	}
	if (strcmp(typeSpecifier, "bytes") == 0) {
		//Do nothing
	} else if(strcmp(typeSpecifier, "kiB") == 0) {
		fileSize *= 1024;
	} else if(strcmp(typeSpecifier, "MiB") == 0) {
		fileSize *= 1024 * 1024;
	} else {
		if (error)
			*error = @"Unknown type specifier";
		*obj = nil;
		return NO;
	}
	
	*obj = [NSNumber numberWithInteger:fileSize];
	return YES;
}

@end
