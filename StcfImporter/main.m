//
//  main.m
//  StcfImporter
//
//  Created by C.W. Betts on 4/20/14.
//
//

#include <xpc/xpc.h>
#import <Foundation/Foundation.h>
#import "PPSTImporter.h"

int main(int argc, const char *argv[])
{
	// Get the singleton service listener object.
	NSXPCListener *serviceListener = [NSXPCListener serviceListener];
	
	// Configure the service listener with a delegate.
	PPSTImporter *sharedZipper = [PPSTImporter sharedImporter];
	serviceListener.delegate = sharedZipper;
	
	// Resume the listener. At this point, NSXPCListener will take over the execution of this service, managing its lifetime as needed.
	[serviceListener resume];
	
	return 0;
}
