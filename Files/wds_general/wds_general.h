/*
 *  wds_general.h
 *  PPMacho
 *
 *  Created by C.W. Betts on 2/13/14.
 *  Copyright 2014 __MyCompanyName__. All rights reserved.
 *
 */

#include <Carbon/Carbon.h>

namespace PlayerPRO {
	class wds_general {
	public:
		wds_general(DialogPtr aDiag);
		wds_general(SInt16 dialogID, WindowPtr parentWindow = (WindowPtr) -1);
		virtual ~wds_general();
		virtual void DoHelp(short **items, short *lsize);
		
	protected:
		DialogPtr theDialog;
	};
}

