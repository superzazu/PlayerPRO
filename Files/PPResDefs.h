/*
 *  PPResDefs.h
 *  PPMacho
 *
 *  Created by C.W. Betts on 12/21/09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */

#define AllItems	0b1111111111111111111111111111111	/* 31 flags */
#define NoItems		0b0000000000000000000000000000000
#define MenuItem1	0b0000000000000000000000000000001
#define MenuItem2	0b0000000000000000000000000000010
#define MenuItem3	0b0000000000000000000000000000100
#define MenuItem4	0b0000000000000000000000000001000
#define MenuItem5	0b0000000000000000000000000010000
#define MenuItem6	0b0000000000000000000000000100000
#define MenuItem7	0b0000000000000000000000001000000
#define MenuItem8	0b0000000000000000000000010000000
#define MenuItem9	0b0000000000000000000000100000000
#define MenuItem10	0b0000000000000000000001000000000
#define MenuItem11	0b0000000000000000000010000000000
#define MenuItem12	0b0000000000000000000100000000000
#define MenuItem13	0b0000000000000000001000000000000
#define MenuItem14	0b0000000000000000010000000000000
#define MenuItem15	0b0000000000000000100000000000000
#define MenuItem16	0b0000000000000001000000000000000
#define MenuItem17	0b0000000000000010000000000000000
#define MenuItem18	0b0000000000000100000000000000000
#define MenuItem19	0b0000000000001000000000000000000

enum {
	mWindowMenu = 182,
	mHelpMenu = 183
};

enum helpMenuEnums {
	mOnlineHelp = 1,
	mPlayerHelp = 2
};

enum {
	mAboutPlayerPRO = 1,
	mGeneralInfo	= 2
}
