//
//  ARCBridge.h
//  PPMacho
//
//  Created by C.W. Betts on 12/23/12.
//
//

#ifndef PPMacho_ARCBridge_h
#define PPMacho_ARCBridge_h
#include <AvailabilityMacros.h>

#if __has_feature(objc_arc)

#define SUPERDEALLOC 
#define RELEASEOBJ(obj) 
#define RETAINOBJ(obj) obj
#define RETAINOBJNORETURN(obj)
#define AUTORELEASEOBJ(obj) obj
#define AUTORELEASEOBJNORETURN(obj)
#define BRIDGE(toType, obj) (__bridge toType)(obj)
#define arcstrong strong
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_7
#define arcweak weak
#define __arcweak __weak
#else
#define arcweak unsafe_unretained
#define __arcweak __unsafe_unretained
#endif

#define DESTROYOBJ(obj) obj = nil

#else

#define SUPERDEALLOC [super dealloc]
#define RELEASEOBJ(obj) [obj release]
#define RETAINOBJ(obj) [obj retain]
#define RETAINOBJNORETURN(obj) [obj retain]
#define AUTORELEASEOBJ(obj) [obj autorelease]
#define AUTORELEASEOBJNORETURN(obj) [obj autorelease]
#define BRIDGE(toType, obj) (toType)(obj)
#define arcstrong retain
#define arcweak assign
#define __arcweak

#define DESTROYOBJ(obj) [obj release]; obj = nil


#endif

#define arcretain arcstrong

#endif
