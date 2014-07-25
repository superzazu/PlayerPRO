//
//  PPMusicList.h
//  PPMacho
//
//  Created by C.W. Betts on 8/8/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#if !TARGET_OS_IPHONE
#import <Cocoa/Cocoa.h>
#define UNAVAILABLE_IPHONE
#else 
#define UNAVAILABLE_IPHONE UNAVAILABLE_ATTRIBUTE
#endif

@class PPMusicListObject;

@interface PPMusicList : NSObject <NSSecureCoding, NSFastEnumeration>
@property (readonly) NSUInteger lostMusicCount;
@property NSInteger selectedMusic;

- (instancetype)init;

- (void)sortMusicListByName;
- (void)sortMusicListUsingComparator:(NSComparator)comp;
- (void)sortMusicListWithOptions:(NSSortOptions)opts usingComparator:(NSComparator)comp;

- (BOOL)saveApplicationMusicList;
- (BOOL)loadApplicationMusicList;

- (BOOL)saveMusicListToURL:(NSURL *)toSave;
- (BOOL)loadMusicListAtURL:(NSURL *)fromURL;
- (void)beginLoadingOfMusicListAtURL:(NSURL *)toOpen completionHandle:(void (^)(NSError *theErr))theHandle UNAVAILABLE_IPHONE;

- (NSURL*)URLAtIndex:(NSUInteger)index;
- (BOOL)addMusicURL:(NSURL *)musicToLoad;
- (void)removeObjectAtIndex:(NSUInteger)object;
- (void)clearMusicList;

- (NSInteger)indexOfObjectSimilarToURL:(NSURL*)theURL;

- (void)removeObjectsInMusicListAtIndexes:(NSIndexSet *)set;
- (NSArray*)arrayOfObjectsInMusicListAtIndexes:(NSIndexSet*)theSet;
- (void)insertObjects:(NSArray*)anObj inMusicListAtIndex:(NSUInteger)idx;

//KVC functions
- (NSUInteger)countOfMusicList;
- (id)objectInMusicListAtIndex:(NSUInteger)idx;
- (void)insertObject:(id)anObj inMusicListAtIndex:(NSUInteger)idx;
- (void)removeObjectInMusicListAtIndex:(NSUInteger)object;
- (void)replaceObjectInMusicListAtIndex:(NSUInteger)index withObject:(id)anObject;
@end
