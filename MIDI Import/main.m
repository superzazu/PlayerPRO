//
//  main.m
//  MIDI Import
//
//  Created by C.W. Betts on 8/6/14.
//
//

#include <xpc/xpc.h>
#include <Foundation/Foundation.h>
#include "PPMIDIImporter.h"

int main(int argc, const char *argv[])
{
	// Get the singleton service listener object.
	NSXPCListener *serviceListener = [NSXPCListener serviceListener];
	
	// Configure the service listener with a delegate.
	PPMIDIImporter *sharedZipper = [PPMIDIImporter sharedImporter];
	serviceListener.delegate = sharedZipper;
	
	// Resume the listener. At this point, NSXPCListener will take over the execution of this service, managing its lifetime as needed.
	[serviceListener resume];
	
	return 0;
}
