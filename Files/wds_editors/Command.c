#include "Shuddup.h"
#include "RDriver.h"
#include "RDriverInt.h"
#include "Undo.h"

#define HI(para) ((para) >> 4)

#define TEXTHI 12
#define ITEMNO 12
#define WLarg	137
#define WHaut	133


	extern	EventRecord				theEvent;
	extern	RGBColor				theColor;
	extern	DialogPtr				EditorDlog;
	extern	MenuHandle				TrackView;
	extern	WindowPtr				oldWindow;
	
			short					curTrack = 0, curActif = VolumeTE;
	static	short					oldPos = 0, oldPat = 0, oldTrack = 0, curPos = 0;
			TEHandle				TEH[ 6];
	static	ControlHandle			keyMapCntl, DelBut, AllBut, PlayCntl, FlipBut,BackReader, NextReader;
	static	Boolean					UpdateNow, AllCellApply, keyMapNote;
	static	TEHandle 				EfTE;
			MenuHandle				thePatternMenu = NULL;
	
	short	ConvertNote2No(	Str32);
	void 	DoPlayInstruInt( short	Note, short Instru, short effect, short arg, short vol, Channel *curVoice, long start, long end);
	void	DesactivateCmdWindow();
	void	NSelectInstruList( short, short);
	void	ApplyOnAllCell(short ins, short note, short ef, short argu, short vol);
	void 	ApplyBut( short value);

static	short	ActualShowEffect;

#define	SMALLH	48
#define LARGEH	155
#define SMALLL	183
#define LARGEL	183 + 262 + 20

void GetCurrentDlogCmd( short *pos, short *track)
{
	*pos = oldPos;
	*track = oldTrack;
}

void SwitchSize()
{
Rect	caRect;
	
	GetPortBounds( GetDialogPort( ToolsDlog), &caRect);

	if( caRect.bottom == SMALLH) MySizeWindow( ToolsDlog, caRect.right, LARGEH, true);
	else
	{
		MySizeWindow( ToolsDlog, SMALLL, SMALLH, true);
		HiliteControl( FlipBut, 0);
	}
}

void SizeCommandWindow( Boolean L, Boolean H)
{
	short l, h;

	if( L) l = LARGEL;
	else l = SMALLL;
	
	if( H) h = LARGEH;
	else h = SMALLH;
	
	MySizeWindow( ToolsDlog, l, h, true);
}

Cmd* GetCmdDlogActif()
{	
	if( (*TEH[ curActif])->active != 0)
		return GetMADCommand( oldPos, oldTrack, curMusic->partition[ oldPat]);
	else
		return (Cmd*) -1L;
}

void ShowCurrentCmdNote(void)
{
Rect	caRect;
	
	GetPortBounds( GetDialogPort( ToolsDlog), &caRect);

	if( caRect.bottom == SMALLH) MySizeWindow( ToolsDlog, caRect.right, LARGEH, true);
	UpdateNow = true;
	
//	HandleViewsChoice( 10);

	ShowWindow( GetDialogWindow( ToolsDlog));
	SelectWindow( GetDialogWindow( ToolsDlog));
	SelectWindow2( oldWindow);
}

void UpdatePatternMenu(void)
{
short	i,x ;
Str255	aStr, theStr;

	if( thePatternMenu == NULL) Debugger();
	
	x = CountMenuItems( thePatternMenu);
	for( i = 0; i < x;i++) DeleteMenuItem( thePatternMenu, 1);

	for( i = 0; i < curMusic->header->numPat; i++)
	{
		NumToString( i, aStr);
		pStrcat( aStr, "\p - ");
		
		theStr[ 0] = 20;
		for( x = 0; x < 20; x++) theStr[ x+1] = curMusic->partition[ i]->header.name[ x];
		pStrcat( aStr, theStr);
		
		AppendMenu( thePatternMenu, aStr);
	}
}

void AfficheGoodEffect( short effect, Byte arg)
{
Handle			aH;
StScrpHandle	theStyle;
RGBColor		color;
short			textID;

	if( effect == 14) textID = 300 + HI( arg);
	else textID = 200 + effect;

	if( ActualShowEffect != textID)
	{
		GetBackColor( &color);
		RGBBackColor( &theColor);
	
		aH = GetResource( 'TEXT', textID);
		theStyle = (StScrpHandle) GetResource( 'styl', textID);
	
		DetachResource( (Handle) theStyle);
		DetachResource( aH);
	
		HLock( aH);
		(*EfTE)->selStart = 0;
		(*EfTE)->selEnd = (*EfTE)->teLength;
		TEDelete( EfTE);
		TEStyleInsert( *aH, GetHandleSize( aH), theStyle, EfTE);
		HUnlock( aH);

		MyDisposHandle( & aH);
		
		ActualShowEffect = textID;
		
		RGBBackColor( &color);
	}
}

void SetCommandTrack( int theTrack, long incurPos)
{
	curTrack = theTrack;
	curPos = incurPos;
}

short	Analyse( short	menuType)
{
Str255		aStr;
CharsHandle	cHdle;
short			Oct;
long		ltemp;

	switch( menuType)
	{
		case VolumeTE:
			aStr[ 0] = (*TEH[ VolumeTE])->teLength;
			
			cHdle = TEGetText( TEH[ VolumeTE]);
			
			if( (*cHdle)[ 1] >= 'A' && (*cHdle)[ 1] <= 'F') Oct = 10 + (*cHdle)[ 1] - 'A';
			if( (*cHdle)[ 1] >= '0' && (*cHdle)[ 1] <= '9') Oct = (*cHdle)[ 1] - '0';
			
			if( (*cHdle)[ 0] >= 'A' && (*cHdle)[ 0] <= 'F') Oct += (10 + (*cHdle)[ 0] - 'A')<<4;
			if( (*cHdle)[ 0] >= '0' && (*cHdle)[ 0] <= '9') Oct += ((*cHdle)[ 0] - '0')<<4;
			
			if( Oct >= 0 && Oct < 256) return Oct;
		break;
	
		case InstruTE:
			aStr[ 0] = (*TEH[ InstruTE])->teLength;
			
			cHdle = TEGetText( TEH[ InstruTE]);
			
			aStr[ 1] = (*cHdle)[ 0];
			aStr[ 2] = (*cHdle)[ 1];
			aStr[ 3] = (*cHdle)[ 2];
			
			if( aStr[ 2] == '-') ltemp = 0;
			else StringToNum( aStr, &ltemp);
			
			if( ltemp >= 0 && ltemp < MAXINSTRU) return ltemp;
		break;
		
		case NoteTE:
			aStr[ 0] = (*TEH[ NoteTE])->teLength;
			
			cHdle = TEGetText( TEH[ NoteTE]);
			
			aStr[ 1] = (*cHdle)[ 0];
			aStr[ 2] = (*cHdle)[ 1];
			aStr[ 3] = (*cHdle)[ 2];
			
			if( EqualString( aStr, "\pOFF", false, false))
			{
				return NUMBER_NOTES+1;
			}
			else
			{
				Oct = ConvertNote2No( aStr);
				if( Oct >= 0 && Oct < NUMBER_NOTES) return Oct;
				else return NUMBER_NOTES;
			}
		break;
		
		case EffectTE:
			aStr[ 0] = (*TEH[ EffectTE])->teLength;
			
			cHdle = TEGetText( TEH[ EffectTE]);
			
			Oct = -1;
			
			if( **cHdle >= 'L') Oct = 17;
			if( **cHdle >= 'O') Oct = 18;
			if( **cHdle >= 'A' && **cHdle <= 'G') Oct = 10 + **cHdle - 'A';
			if( **cHdle >= '0' && **cHdle <= '9') Oct = **cHdle - '0';
			
			if( Oct >= 0 && Oct < 19) return (Oct + 1);
		break;
		
		case ArguTE:
			aStr[ 0] = (*TEH[ ArguTE])->teLength;
			
			cHdle = TEGetText( TEH[ ArguTE]);
			
			if( (*cHdle)[ 1] >= 'A' && (*cHdle)[ 1] <= 'F') Oct = 10 + (*cHdle)[ 1] - 'A';
			if( (*cHdle)[ 1] >= '0' && (*cHdle)[ 1] <= '9') Oct = (*cHdle)[ 1] - '0';
			
			if( (*cHdle)[ 0] >= 'A' && (*cHdle)[ 0] <= 'F') Oct += (10 + (*cHdle)[ 0] - 'A')<<4;
			if( (*cHdle)[ 0] >= '0' && (*cHdle)[ 0] <= '9') Oct += ((*cHdle)[ 0] - '0')<<4;
			
			if( Oct >= 0 && Oct < 256) return Oct;
		break;
	}
	
	return 1;
}

void SetCmdValue( short	menuType)
{
Str255			aStr;
CharsHandle		cHdle;
short			Oct, tt;
long			ltemp;
Cmd				*aCmd = NULL;
Point			cell;
Boolean			allCellCopy;

	allCellCopy = AllCellApply;
	
	if( EditorDlog == NULL) AllCellApply = false;

	curMusic->hasChanged = true;

	switch( menuType)
	{
	case VolumeTE:
		aStr[ 0] = (*TEH[ VolumeTE])->teLength;
		
		ltemp = 0;
		if( aStr[ 0] == 1)
		{
			cHdle = TEGetText( TEH[ VolumeTE]);
		
			if( **cHdle >= 'A' && **cHdle <= 'F') ltemp = 10 + **cHdle - 'A';
			if( **cHdle >= '0' && **cHdle <= '9') ltemp = **cHdle - '0';
		}
		else if( aStr[ 0] >= 2)
		{
			cHdle = TEGetText( TEH[ VolumeTE]);
		
			if( **cHdle >= 'A' && **cHdle <= 'F') ltemp = 10 + **cHdle - 'A';
			if( **cHdle >= '0' && **cHdle <= '9') ltemp = **cHdle - '0';
			
			if( (*cHdle)[ 1] >= 'A' && (*cHdle)[ 1] <= 'F') tt = 10 + (*cHdle)[ 1] - 'A';
			if( (*cHdle)[ 1] >= '0' && (*cHdle)[ 1] <= '9') tt = (*cHdle)[ 1] - '0';
			
			ltemp = ltemp*16 + tt;
		}
		if( ltemp < 0x10 || ltemp > 0xFF) ltemp = 0xFF;
		
		if( AllCellApply)
		{
			ApplyOnAllCell( -1, -1, -1, -1, ltemp);
		}
		else
		{
			aCmd = GetMADCommand( oldPos, oldTrack, curMusic->partition[ oldPat]);
		}
		
		aCmd->vol = ltemp;
	break;
	
	case InstruTE:
		aStr[ 0] = (*TEH[ InstruTE])->teLength;
		
		cHdle = TEGetText( TEH[ InstruTE]);
		
		if( (*cHdle)[ 1] == '-') ltemp = 0;
		else if( aStr[ 0] > 0)
		{
			aStr[ 1] = (*cHdle)[ 0];
			aStr[ 2] = (*cHdle)[ 1];
			aStr[ 3] = (*cHdle)[ 2];
			
			StringToNum( aStr, &ltemp);
		}
		else ltemp = 0;
		if( ltemp < 0 || ltemp > MAXINSTRU) ltemp = 0;
		
		if( AllCellApply)
		{
			ApplyOnAllCell( ltemp, -1, -1, -1, -1);
		}
		else
		{
			aCmd = GetMADCommand( oldPos, oldTrack, curMusic->partition[ oldPat]);
		}
		
		aCmd->ins = ltemp;
		NSelectInstruList( aCmd->ins - 1, -1);
	break;
	
	case NoteTE:
		aStr[ 0] = (*TEH[ NoteTE])->teLength;
		
		if( aStr[ 0] > 1)
		{
			cHdle = TEGetText( TEH[ NoteTE]);
			
			aStr[ 1] = (*cHdle)[ 0];
			aStr[ 2] = (*cHdle)[ 1];
			aStr[ 3] = (*cHdle)[ 2];
			
			if( EqualString( aStr, "\pOFF", false, false))
			{
				Oct = 0xFE;
			}
			else
			{
				if( aStr[ 2] >= '0' && aStr[ 2] <= '9')
				{
					aStr[ 3] = aStr[ 2];
					aStr[ 2] = ' ';
				}
				
				Oct = ConvertNote2No( aStr);
				
				if( Oct < 0 || Oct > NUMBER_NOTES) Oct = 0xFF;
			}
		}
		else Oct = 0xFF;
		
		if( AllCellApply)
		{
			ApplyOnAllCell( -1, Oct, -1, -1, -1);
		}
		else
		{
			aCmd = GetMADCommand( oldPos, oldTrack, curMusic->partition[ oldPat]);
			aCmd->note = Oct;
		}
	break;
	
	case EffectTE:
		aStr[ 0] = (*TEH[ EffectTE])->teLength;
		Oct = -1;
		
		if( aStr[ 0] > 0)
		{
			cHdle = TEGetText( TEH[ EffectTE]);
			
			if( **cHdle == 'L') Oct = 17;
			if( **cHdle == 'O') Oct = 18;
			if( **cHdle >= 'A' && **cHdle <= 'G') Oct = 10 + **cHdle - 'A';
			if( **cHdle >= '0' && **cHdle <= '9') Oct = **cHdle - '0';
		}
		if( Oct < 0 || Oct >= 19) Oct = 0;
		
		if( AllCellApply)
		{
			ApplyOnAllCell( -1, -1, Oct, -1, -1);
		}
		else
		{
			aCmd = GetMADCommand( oldPos, oldTrack, curMusic->partition[ oldPat]);
			aCmd->cmd = Oct;
		}
		
		AfficheGoodEffect( aCmd->cmd, aCmd->arg);
	break;
	
	case ArguTE:
		aStr[ 0] = (*TEH[ ArguTE])->teLength;
		
		Oct = 0;
		if( aStr[ 0] == 1)
		{
			cHdle = TEGetText( TEH[ ArguTE]);
		
			if( **cHdle >= 'A' && **cHdle <= 'F') Oct = 10 + **cHdle - 'A';
			if( **cHdle >= '0' && **cHdle <= '9') Oct = **cHdle - '0';
		}
		else if( aStr[ 0] >= 2)
		{
			cHdle = TEGetText( TEH[ ArguTE]);
		
			if( **cHdle >= 'A' && **cHdle <= 'F') Oct = 10 + **cHdle - 'A';
			if( **cHdle >= '0' && **cHdle <= '9') Oct = **cHdle - '0';
			
			if( (*cHdle)[ 1] >= 'A' && (*cHdle)[ 1] <= 'F') tt = 10 + (*cHdle)[ 1] - 'A';
			if( (*cHdle)[ 1] >= '0' && (*cHdle)[ 1] <= '9') tt = (*cHdle)[ 1] - '0';
			
			Oct = Oct*16 + tt;
		}
		
		if( AllCellApply)
		{
			ApplyOnAllCell( -1, -1, -1, Oct, -1);
		}
		else
		{
			aCmd = GetMADCommand( oldPos, oldTrack, curMusic->partition[ oldPat]);
			aCmd->arg = Oct;
		}
		
		AfficheGoodEffect( aCmd->cmd, aCmd->arg);
	break;
	}
	
	/*** Update du Digital Editor ***/
	
	if( !AllCellApply)
	{
		if( aCmd != NULL)
		{
			UPDATE_Note( oldPos, oldTrack);
		}
	}
	
	UpdateNow = true;
	AllCellApply = allCellCopy;
}

void myTESetText( Ptr textPtr, long length, TEHandle hTE)
{
short	i;

	if( (*hTE)->teLength != length)
	{
		TESetText( textPtr, length, hTE);
		TEUpdate( &(*hTE)->viewRect, hTE);
	}
	else
	{
		for( i = 0; i < (*hTE)->teLength; i++)
		{
			if( (*(*hTE)->hText)[ i] != textPtr[ i])
			{
				TESetText( textPtr, length, hTE);
				TEUpdate( &(*hTE)->viewRect, hTE);
				return;
			}
		}
	}
}

void DoNullCmdWindow(void)
{
	short				i, Larg, x;
 	short				itemType;
 	Handle				itemHandle;
 	Rect				tempRect;
 	Str255				tempStr;
 	GrafPtr				savePort;
 	long				val, newVal;
 	Cmd					*theCommand;
	
	GetPort( &savePort);
	SetPortDialogPort( ToolsDlog);
	
	for( i = InstruTE; i<= VolumeTE; i++) TEIdle( TEH[ i]);
	
	if( oldPat != MADDriver->Pat || UpdateNow == true)
	{
		oldPat = MADDriver->Pat;
		UpdateNow = true;
		
		if( curTrack >= curMusic->header->numChn)
		{
			curTrack = 1;
		}

		NumToString( oldPat, tempStr);
		SetDText( ToolsDlog, 15, tempStr);
	}

	if( oldTrack != curTrack || UpdateNow == true)
	{
		oldTrack = curTrack;
		UpdateNow = true;

		NumToString( oldTrack + 1, tempStr);
		SetDText( ToolsDlog, 17, tempStr);
	}

	if( thePrefs.MusicTrace == true || curPos == -1)
	{
		if( oldPos != MADDriver->PartitionReader) UpdateNow = true;
		newVal = MADDriver->PartitionReader;
	}
	else
	{
		if( oldPos != curPos) UpdateNow = true;
		newVal = curPos;
	}
	
	if( UpdateNow == true)
	{
		Rect	caRect;
		
		oldPos = newVal;
		if( oldPos >= curMusic->partition[ oldPat]->header.size) oldPos = curMusic->partition[ oldPat]->header.size - 1;
		NumToString( oldPos, tempStr);
		SetDText( ToolsDlog, 16, tempStr);

		theCommand = GetMADCommand( oldPos, oldTrack, curMusic->partition[ oldPat]);
		
		BackColor( whiteColor);
		
		myTESetText( (Ptr) EInstru[ theCommand->ins], 3, TEH[ InstruTE]);
		myTESetText( (Ptr) ENote[ theCommand->note], 3, TEH[ NoteTE]);
		myTESetText( (Ptr) &EEffect[ theCommand->cmd], 1, TEH[ EffectTE]);
		myTESetText( (Ptr) EArgu[ theCommand->arg], 2, TEH[ ArguTE]);
		
		if( theCommand->vol == 0xFF) myTESetText( (Ptr) EInstru[ 0], 2, TEH[ VolumeTE]);
		else myTESetText( (Ptr) EArgu[ theCommand->vol], 2, TEH[ VolumeTE]);
		
		GetPortBounds( GetDialogPort( ToolsDlog), &caRect);
		
		if( caRect.right > 240) AfficheGoodEffect( theCommand->cmd, theCommand->arg);
		
		TESetSelect( 0, 32000, TEH[ curActif]);

		RGBBackColor( &theColor);
		
		UpdateNow = false;
	}
	
	SetPort( savePort);
}

void  UpdateCmdDlogInfo(void)
{
	UpdateNow = true;
}

void  UpdateCmdDlogWindow(DialogPtr GetSelection)
{ 
		Rect   			tempRect, aRect;
 		GrafPtr			SavePort;
 		Str255			tempStr;
 		short			itemType, Larg, i ,x;
 		Handle			itemHandle;
 		Rect			caRect;
	
	

 	/*	GetPort( &SavePort);
 		SetPortDialogPort( GetSelection);
		
		BeginUpdate( GetDialogWindow( GetSelection));
	
		TextFont( 4);	TextSize( 9);
	*/
	
		UpdateNow = true;
	
 	//	DrawDialog( GetSelection);
			
		for( i=31; i <=34; i++)
		{
			GetDialogItem( ToolsDlog, i, &itemType, &itemHandle, &tempRect);
			
			InsetRect( &tempRect, -2, -2);
			tempRect.bottom--;
			
			ForeColor( whiteColor);
			PaintRect( &tempRect);
			ForeColor( blackColor);
			
			FrameRect( &tempRect);
		}
		GetDialogItem( ToolsDlog, 42, &itemType, &itemHandle, &tempRect);
		InsetRect( &tempRect, -2, -2);
		tempRect.bottom--;
			
		ForeColor( whiteColor);	PaintRect( &tempRect);	ForeColor( blackColor);
		FrameRect( &tempRect);
		
		BackColor( whiteColor);
		
		GetPortBounds( GetDialogPort( GetSelection), &caRect);
		
		for( i = InstruTE; i<= VolumeTE; i++) TEUpdate( &caRect, TEH[ i]);
				
		if( (**(**GetMainDevice()).gdPMap).pixelSize == 1) BackColor( whiteColor);
		else RGBBackColor( &theColor);

		TEUpdate( &caRect, EfTE);
		
/*		EndUpdate( GetDialogWindow( GetSelection));
		SetPort( SavePort);*/
} 

void PlayCurNote(void)
{
	Boolean			theBut;
	Channel			*curVoice;
	Cmd				*aCmd;
	
	aCmd = GetMADCommand( oldPos, oldTrack, curMusic->partition[ oldPat]);

	curVoice = &MADDriver->chan[ oldTrack];
	
	DoPlayInstruInt( aCmd->note, aCmd->ins-1, aCmd->cmd, aCmd->arg, aCmd->vol, &MADDriver->chan[ oldTrack], 0, 0);
}

void DoItemPressCmdDlog( short whichItem, DialogPtr whichDialog)
{
		Point		myPt, cell;
		Str255		aStr;
		long		mresult;
		Handle		itemHandle;
 		short			i, curSelec;
 		Rect		tempRect;
 		GrafPtr		SavePort;
 		short		itemType;
 		TEHandle	curTE;
 		MenuHandle	tMenu;
 		Cmd			*aCmd;
 		Rect	caRect;
	
	

 		GetPort( &SavePort);
 		SetPortDialogPort( ToolsDlog);
 
 		myPt = theEvent.where;
		GlobalToLocal( &myPt);
 
 		DesactivateCmdWindow();
		
		GetPortBounds( GetDialogPort( whichDialog), &caRect);
		
 		switch( whichItem)
 		{
			case 35:
				//if( (*keyMapCntl) != 255 && MyTrackControl( keyMapCntl, theEvent.where, NULL))
				if( GetControlHilite( FlipBut) != 255 && MyTrackControl( FlipBut, theEvent.where, NULL))
				{
					if( caRect.right == LARGEL)
					{
						MySizeWindow( whichDialog, SMALLL , caRect.bottom, true);
						HiliteControl( FlipBut, 0);
					}
					else
					{
						MySizeWindow( whichDialog, LARGEL, caRect.bottom, true);
						HiliteControl( FlipBut, kControlButtonPart);
						
						UpdateNow = true;
						DoNullCmdWindow();
					}
				}
			break;
			
 			case 31:
 			case 32:
 			case 33:
 			case 34:
 				BackColor( whiteColor);
 				
 				TEActivate( TEH[ whichItem - 31]);
 			//	TEClick( myPt, false, TEH[ whichItem - 31]);
 				
 				if( whichItem - 31 != curActif) SetCmdValue( curActif);
				
				TESetSelect( 0, 300, TEH[ whichItem - 31]);
				
 				curActif = whichItem - 31;
 				
 				RGBBackColor( &theColor);
 			break;
 			
 			case 42:
 				BackColor( whiteColor);
 				TESetSelect( 0, 300, TEH[ VolumeTE]);
 				
 				TEActivate( TEH[ VolumeTE]);
 			//	TEClick( myPt, false, TEH[ VolumeTE]);
 				
 				if( VolumeTE != curActif) SetCmdValue( curActif);

 				curActif = VolumeTE;
 				
 				RGBBackColor( &theColor);
 			break;

 			case 18:
 				InsertMenuItem( InstruMenu, "\pNo Ins", 0);
 				
				InsertMenu( InstruMenu, hierMenu );
				GetDialogItem( ToolsDlog, whichItem, &itemType, &itemHandle, &tempRect);
				curSelec = Analyse( InstruTE);
				
				myPt.v = tempRect.top;	myPt.h = tempRect.left;
				LocalToGlobal( &myPt);
				
				SetItemMark( InstruMenu, curSelec + 1, 0xa5);
				
				mresult = PopUpMenuSelect(	InstruMenu,
											myPt.v,
											myPt.h,
											curSelec + 1);
				
				SetItemMark( InstruMenu, curSelec + 1, 0);
				
				if ( HiWord(mresult ) != 0 )
				{
					SaveUndo( UPattern, oldPat, "\pUndo 'Command Editing'");
				
					GetMenuItemText( InstruMenu, LoWord( mresult), aStr);
					
					TESetSelect( 0, 300, TEH[ InstruTE]);
					TESetText( aStr + 1, 3, TEH[ InstruTE]);
					InvalWindowRect( GetDialogWindow( ToolsDlog), &(*TEH[ InstruTE])->viewRect);
					SetCmdValue( InstruTE);
				}
				DeleteMenu( GetMenuID( InstruMenu));
				
				DeleteMenuItem( InstruMenu, 1);
 			break;
 			
 			case 41:
				InsertMenu( EffectMenu, hierMenu );
				GetDialogItem( ToolsDlog, whichItem, &itemType, &itemHandle, &tempRect);
				curSelec = Analyse( EffectTE);
				
				myPt.v = tempRect.top;	myPt.h = tempRect.left;
				LocalToGlobal( &myPt);
				
				SetItemMark( EffectMenu, curSelec, 0xa5);
				
				mresult = PopUpMenuSelect(	EffectMenu,
											myPt.v,
											myPt.h,
											curSelec);
				
				SetItemMark( EffectMenu, curSelec, 0);
				
				if ( HiWord(mresult ) != 0 )
				{
					curMusic->hasChanged = true;
					SaveUndo( UPattern, oldPat, "\pUndo 'Command Editing'");
				
					GetMenuItemText( EffectMenu, LoWord( mresult), aStr);
					
					TESetSelect( 0, 300, TEH[ EffectTE]);
					TESetText( aStr+1, 1, TEH[ EffectTE]);
					InvalWindowRect( GetDialogWindow( ToolsDlog), &(*TEH[ EffectTE])->viewRect);
					SetCmdValue( EffectTE);
				}
				DeleteMenu( GetMenuID( EffectMenu));
 			break;
 			
 			case 43:
 				tMenu = GetMenu( 161);
				InsertMenu( tMenu, hierMenu );
				GetDialogItem( ToolsDlog, whichItem, &itemType, &itemHandle, &tempRect);
				
				curSelec = Analyse( VolumeTE);
				
				myPt.v = tempRect.top;	myPt.h = tempRect.left;
				LocalToGlobal( &myPt);
				
				SetItemMark( tMenu, curSelec+1, 0xa5);
				
				mresult = PopUpMenuSelect(	tMenu,
											myPt.v,
											myPt.h,
											curSelec+1);
				
				SetItemMark( tMenu, curSelec+1, 0);
				
				if ( HiWord(mresult ) != 0 )
				{
					curMusic->hasChanged = true;
					SaveUndo( UPattern, oldPat, "\pUndo 'Command Editing'");
					
					TESetSelect( 0, 300, TEH[ VolumeTE]);
					TESetText( EArgu[ LoWord( mresult)-1], 2, TEH[ VolumeTE]);
					InvalWindowRect( GetDialogWindow( ToolsDlog), &(*TEH[ VolumeTE])->viewRect);
					SetCmdValue( VolumeTE);
				}
				DeleteMenu( GetMenuID( tMenu));
				DisposeMenu( tMenu);
			break;
 			
 			case 26:
 				tMenu = GetMenu( 161);
				InsertMenu( tMenu, hierMenu );
				GetDialogItem( ToolsDlog, whichItem, &itemType, &itemHandle, &tempRect);
				
				curSelec = Analyse( ArguTE);
				
				myPt.v = tempRect.top;	myPt.h = tempRect.left;
				LocalToGlobal( &myPt);
				
				SetItemMark( tMenu, curSelec+1, 0xa5);
				
				mresult = PopUpMenuSelect(	tMenu,
											myPt.v,
											myPt.h,
											curSelec+1);
				
				SetItemMark( tMenu, curSelec+1, 0);
				
				if ( HiWord(mresult ) != 0 )
				{
					curMusic->hasChanged = true;
					SaveUndo( UPattern, oldPat, "\pUndo 'Command Editing'");
					
					TESetSelect( 0, 300, TEH[ ArguTE]);
					TESetText( EArgu[ LoWord( mresult)-1], 2, TEH[ ArguTE]);
					InvalWindowRect( GetDialogWindow( ToolsDlog), &(*TEH[ ArguTE])->viewRect);
					SetCmdValue( ArguTE);
				}
				DeleteMenu( GetMenuID( tMenu));
				DisposeMenu( tMenu);
			break;
 			
 			case 19:
				InsertMenuItem( NoteMenu, "\p000", NUMBER_NOTES);
 				InsertMenuItem( NoteMenu, "\pOFF", NUMBER_NOTES+1);
 				
 				InsertMenu( NoteMenu, hierMenu );
				GetDialogItem( ToolsDlog, whichItem, &itemType, &itemHandle, &tempRect);
				curSelec = Analyse( NoteTE);
				
				myPt.v = tempRect.top;	myPt.h = tempRect.left;
				LocalToGlobal( &myPt);
				
				mresult = PopUpMenuSelect(	NoteMenu,
											myPt.v,
											myPt.h,
											curSelec + 1);
				
				if ( HiWord(mresult ) != 0 )
				{
					short note;
				
					curMusic->hasChanged = true;
					SaveUndo( UPattern, oldPat, "\pUndo 'Command Editing'");
				
					GetMenuItemText( NoteMenu, LoWord( mresult), aStr);
					
					TESetSelect( 0, 300, TEH[ NoteTE]);
					TESetText( aStr + 1, 3, TEH[ NoteTE]);
					InvalWindowRect( GetDialogWindow( ToolsDlog), &(*TEH[ NoteTE])->viewRect);
					SetCmdValue( NoteTE);
				}
				DeleteMenu( GetMenuID( NoteMenu));
				DeleteMenuItem( NoteMenu, NUMBER_NOTES+1);
				DeleteMenuItem( NoteMenu, NUMBER_NOTES+1);
 			break;
 			
 		/*	case 11:
 				{
 				long	oTicks = TickCount(), iTick = TickCount();
 				
 				HiliteControl( BackReader, kControlButtonPart);
 				
 				goto inBoucle;
 				
 				while( Button())
 				{
 					if(TickCount() - iTick > 5L && TickCount() - oTicks > GetDblTime())
 					{
	 					inBoucle:
	 					
	 					iTick = TickCount();
		 				SetCmdValue( curActif);
		 				if( MADDriver->PartitionReader > 0) MADDriver->PartitionReader--;
		 				else
		 				{
		 					if( MADDriver->PL > 0)
		 					{
		 						MADDriver->PartitionReader = 63;
		 						MADDriver->PL--;
		 						MADDriver->Pat = (curMusic->header)->oPointers[ MADDriver->PL];
		 					}
		 				}
		 				SelectCurrentActif();
		 				
		 				DoGlobalNull();
	 				}
	 				
 				}
 				HiliteControl( BackReader, 0);
 				}
 			break;*/
 			
 			case 21:
 				if( MyTrackControl( DelBut, theEvent.where, NULL))
	 			{
	 				Point	theCell;
	 			
	 				aCmd = GetMADCommand( oldPos, oldTrack, curMusic->partition[ oldPat]);
					MADKillCmd( aCmd);
	 				
	 				UPDATE_Note( oldPos, oldTrack);
 				}
 			break;
 			
 			case 45:
 				if( GetControlHilite( keyMapCntl) != 255 && MyTrackControl( keyMapCntl, theEvent.where, NULL))
				{
					if( keyMapNote == false)
					{
						HiliteControl( keyMapCntl, kControlButtonPart);
						keyMapNote = true;
					}
					else
					{
						HiliteControl( keyMapCntl, 0);
						keyMapNote = false;
					}
					
					thePrefs.keyMapNote = keyMapNote;
				}
 			break;
 			
 			case 40:
 				if( GetControlHilite( AllBut) != 255 && MyTrackControl( AllBut, theEvent.where, NULL))
				{
					if( AllCellApply == false)
					{
						HiliteControl( AllBut, kControlButtonPart);
						AllCellApply = true;
					}
					else
					{
						HiliteControl( AllBut, 0);
						AllCellApply = false;
					}
				}
 			break;
 			
 		/*	case 25:
 			{
 				long	oTicks = TickCount(), iTick = TickCount();
 				
 				HiliteControl( NextReader, kControlButtonPart);
 				
 				goto inBoucle2;
 				
 				while( Button())
 				{
 					if(TickCount() - iTick > 5L && TickCount() - oTicks > GetDblTime())
 					{
	 					inBoucle2:
	 					
	 					iTick = TickCount();
		 				SetCmdValue( curActif);
		 				if( MADDriver->PartitionReader < 63) MADDriver->PartitionReader++;
		 				else
		 				{	
		 					if( MADDriver->PL < 127)
		 					{
		 						MADDriver->PartitionReader = 0;
		 						MADDriver->PL++;
		 						MADDriver->Pat = (curMusic->header)->oPointers[ MADDriver->PL];
		 					}
		 				}
		 				SelectCurrentActif();
		 				
		 				DoGlobalNull();
	 				}
	 				
 				}
 				HiliteControl( NextReader, 0);
 				}
 			break;*/
 			
 			case 22:
 				if( MyTrackControl( PlayCntl, theEvent.where, NULL))
	 			{
	 				SetCmdValue( curActif);
	 				
 					PlayCurNote();
 				}
 			break;
 			
 			case 23:
 				InsertMenu( TrackView, hierMenu );
				GetDialogItem( ToolsDlog, 23, &itemType, &itemHandle, &tempRect);
				
				myPt.v = tempRect.top;	myPt.h = tempRect.left;
				LocalToGlobal( &myPt);
				
				SetItemMark( TrackView, curTrack + 1, 0xa5);
				
				mresult = PopUpMenuSelect(	TrackView,
											myPt.v,
											myPt.h,
											curTrack + 1);
				
				SetItemMark( TrackView, curTrack + 1, 0);
				
				if ( HiWord(mresult ) != 0 )
				{
					curTrack = (Byte) LoWord( mresult) - 1;
				}
				DeleteMenu( GetMenuID( TrackView));
 			break;
 			
 			case 24:
 				GetDialogItem( ToolsDlog, 24, &itemType, &itemHandle, &tempRect);
				myPt.v = tempRect.top;	myPt.h = tempRect.left;
				LocalToGlobal( &myPt);
 				UpdatePatternMenu();
 				
				InsertMenu( thePatternMenu, hierMenu);
				
				SetItemMark( thePatternMenu, oldPat + 1, 0xa5);
				
				mresult = PopUpMenuSelect(	thePatternMenu,
											myPt.v,
											myPt.h,
											oldPat + 1);
			
				SetItemMark( thePatternMenu, oldPat + 1, 0);
				
				if ( HiWord(mresult ) != 0 )
				{
					MADDriver->Pat = (Byte) LoWord( mresult) - 1;
					MADDriver->PartitionReader = 0;
					MADPurgeTrack( MADDriver);
				}
				DeleteMenu( GetMenuID( thePatternMenu));
 			break;
 		}
 		
 		SelectCurrentActif();
 		
 		SetPatternCell( oldPos, oldTrack);
 		
		SetPort( SavePort);
}

void CreateCmdDlog(void)
{
	Rect		itemRect, tempRect, dataBounds;
	Handle		itemHandle;
	short		itemType, itemHit, temp, i;
	Point		cSize;
	FontInfo	ThisFontInfo;
	Str255		String;
	GrafPtr		savePort;

	GetPort( &savePort);

	ActualShowEffect = -1;

	thePatternMenu = GetMenu( 146);

/*	ToolsDlog = GetNewDialog( 153, NULL, (WindowPtr) ToolsDlog);
	SetWindEtat( ToolsDlog);
	MySizeWindow( ToolsDlog, WLarg, WHaut, false);
	ShowWindow( ToolsDlog);
	SelectWindow2( ToolsDlog);
*/	
	SetPortDialogPort( ToolsDlog);
	UpdateNow = true;
	AllCellApply = false;
	keyMapNote = thePrefs.keyMapNote;
	
	TextFont(4);	TextSize(9);
	
	BackColor( whiteColor);
	
	GetDialogItem( ToolsDlog, 37, &itemType, &itemHandle, &itemRect);
	EfTE = TEStyleNew( &itemRect, &itemRect);

	TESetAlignment( teFlushDefault, EfTE);
	
	for( i = InstruTE; i <= ArguTE; i++)
	{
		GetDialogItem( ToolsDlog, 31 + i, &itemType, &itemHandle, &itemRect);
		TEH[ i] = TENew( &itemRect, &itemRect);
		TESetAlignment( teCenter, TEH[ i]);
	}
	
	GetDialogItem( ToolsDlog, 42, &itemType, &itemHandle, &itemRect);
	TEH[ VolumeTE] = TENew( &itemRect, &itemRect);
	TESetAlignment( teCenter, TEH[ VolumeTE]);
	
//	TEActivate( TEH[ InstruTE]);

	RGBBackColor( &theColor);
	
	GetDialogItem( ToolsDlog , 11, &itemType, &itemHandle, &itemRect);
	//itemRect.right = itemRect.left;
/*	BackReader = NewControl( GetDialogWindow( ToolsDlog),
							&itemRect,
							"\p",
							true,
							0,
							kControlContentIconSuiteRes,
							142,
							kControlBevelButtonNormalBevelProc,
							0);*/
	
	GetDialogItem( ToolsDlog , 21, &itemType, &itemHandle, &itemRect);
	//itemRect.right = itemRect.left;
	DelBut = NewControl( GetDialogWindow( ToolsDlog),
							&itemRect,
							"\p",
							true,
							0,
							kControlContentIconSuiteRes,
							150,
							kControlBevelButtonNormalBevelProc,
							0);
	
	GetDialogItem( ToolsDlog , 45, &itemType, &itemHandle, &itemRect);
	keyMapCntl = NewControl( GetDialogWindow( ToolsDlog),
							&itemRect,
							"\p",
							true,
							0,
							kControlContentIconSuiteRes,
							201,
							kControlBevelButtonNormalBevelProc,
							0);
	if( keyMapNote) HiliteControl( keyMapCntl, kControlButtonPart);
	
	
	GetDialogItem( ToolsDlog , 40, &itemType, &itemHandle, &itemRect);
	//itemRect.right = itemRect.left;
	AllBut = NewControl( GetDialogWindow( ToolsDlog),
							&itemRect,
							"\p",
							true,
							0,
							kControlContentIconSuiteRes,
							141,
							kControlBevelButtonNormalBevelProc,
							0);
	if( EditorDlog == NULL) ApplyBut( 255);

	GetDialogItem( ToolsDlog , 25, &itemType, &itemHandle, &itemRect);
	//itemRect.right = itemRect.left;
/*	NextReader = NewControl( GetDialogWindow( ToolsDlog),
								&itemRect,
								"\p",
							true,
							0,
							kControlContentIconSuiteRes,
							144,
							kControlBevelButtonNormalBevelProc,
							0);*/

	GetDialogItem( ToolsDlog , 22, &itemType, &itemHandle, &itemRect);
	PlayCntl = NewControl( 	GetDialogWindow( ToolsDlog),
							&itemRect,
							"\p",
							true,
							0,
							kControlContentIconSuiteRes,
							160,
							kControlBevelButtonNormalBevelProc,
							0);
								
	GetDialogItem( ToolsDlog , 35, &itemType, &itemHandle, &itemRect);
//	itemRect.right = itemRect.left + 32;
//	itemRect.bottom = itemRect.top + 32;
	FlipBut = NewControl( 		GetDialogWindow( ToolsDlog),
								&itemRect,
								"\p",
								true,
								0,
								kControlContentIconSuiteRes,
								211,
								kControlBevelButtonNormalBevelProc,
								0);
	SetPort( savePort);
}

void CloseCmdDlog(void)
{
short	i;

	if( ToolsDlog != NULL)
	{
		SetCmdValue( curActif);
		
		DisposeDialog( ToolsDlog);
		for( i = InstruTE; i <= VolumeTE; i++) TEDispose( TEH[ i]);
		TEDispose( EfTE);
	}
	ToolsDlog = NULL;
}

Boolean TakeDecimal( short	*theChar)
{
	if( *theChar >= '0' && *theChar <= '9') return true;
	
	return false;
}

Boolean HexaDecimal( short	*theChar)
{
	if( *theChar >= 'a' && *theChar <= 'f')
	{
		*theChar -= 0x20;
		return true;
	}
	if( *theChar >= 'A' && *theChar <= 'F') return true;
	if( *theChar >= '0' && *theChar <= '9') return true;
	
	return false;
}

Boolean TakeEffect( short	*theChar)
{
	if( *theChar >= 'a' && *theChar <= 'z') *theChar -= 0x20; 
	if( *theChar == 'L') return true;
	if( *theChar == 'O') return true;
	if( *theChar >= 'A' && *theChar <= 'G') return true;
	if( *theChar >= '0' && *theChar <= '9') return true;
	
	return false;
}

Boolean TakeNote( short	*theChar)
{
	if( HexaDecimal( theChar)) return true;
	if( *theChar == 'G') return true;
	if( *theChar == 'g') { *theChar -= 0x20; return true; }
	
	if( *theChar == '#') return true;
	if( *theChar == ' ') return true;
	return false;
}

Boolean AcceptKeysTools(void)
{
Rect	caRect;
	
	GetPortBounds( GetDialogPort( ToolsDlog), &caRect);

	if( caRect.bottom <= 50)
	{
		if( EditorDlog != NULL) if( GetDialogWindow( EditorDlog) != oldWindow) return false;
	}
	
	if( (*TEH[ curActif])->active != 0) return true;
	else return false;
}

void DoKeyPressCmdDlog( short theChar)
{
Boolean		GoodNote = false;
GrafPtr		savePort;
Point		myPt;

	if( theChar != 9)
	{
		if( AcceptKeysTools() == false) return;
	}
	
	GetPort( &savePort);
	SetPortDialogPort( ToolsDlog);

	BackColor( whiteColor);
	
	switch( curActif)
	{
		case VolumeTE:
			if( HexaDecimal( &theChar))
			{
				if( (*TEH[ curActif])->teLength < 2 ||
					(*TEH[ curActif])->selStart != (*TEH[ curActif])->selEnd)
					{
						curMusic->hasChanged = true;
						SaveUndo( UPattern, oldPat, "\pUndo 'Command Editing'");
						TEKey( (char) theChar, TEH[ curActif]);
					}
				if( (*TEH[ curActif])->teLength >= 2)
				{
					TESetSelect( 0, 32000, TEH[ curActif]);
				}
			}
		break;
	
		case InstruTE:
			if( TakeDecimal( &theChar))
			{
				if( (*TEH[ curActif])->teLength < 3 ||
					(*TEH[ curActif])->selStart != (*TEH[ curActif])->selEnd)
					{
						curMusic->hasChanged = true;
						SaveUndo( UPattern, oldPat, "\pUndo 'Command Editing'");
						TEKey( (char) theChar, TEH[ curActif]);
						
					//	UpdateEditorInfo();
					}
				if( (*TEH[ curActif])->teLength >= 3)
				{
					TESetSelect( 0, 32000, TEH[ curActif]);
				}
			}
		break;
		
		case EffectTE:
			if( TakeEffect( &theChar))
			{
				if( (*TEH[ curActif])->teLength < 1 ||
					(*TEH[ curActif])->selStart != (*TEH[ curActif])->selEnd)
					{
						curMusic->hasChanged = true;
						SaveUndo( UPattern, oldPat, "\pUndo 'Command Editing'");
						TEKey( (char) theChar, TEH[ curActif]);
					}
				
				if( (*TEH[ curActif])->teLength >= 1)
				{
					TESetSelect( 0, 32000, TEH[ curActif]);
				}
			}
		break;
		
		case NoteTE:
			if( keyMapNote)
			{
				short note = ConvertCharToNote( theChar);
				if( note != -1)
				{
					Str32 str;
					Rect	caRect;
	
					GetPortBounds( GetDialogPort( ToolsDlog), &caRect);

					GetNoteString( note, str);
					
					curMusic->hasChanged = true;
					SaveUndo( UPattern, oldPat, "\pUndo 'Command Editing'");
					TESetText( str+1, str[ 0], TEH[ curActif]);
					TESetSelect( 0, 10, TEH[ curActif]);
					TEUpdate( &caRect, TEH[ curActif]);
				}
			}
			else
			{
				if( TakeNote( &theChar))
				{
					if( (*TEH[ curActif])->teLength < 3 ||
						(*TEH[ curActif])->selStart != (*TEH[ curActif])->selEnd)
						{
							curMusic->hasChanged = true;
							SaveUndo( UPattern, oldPat, "\pUndo 'Command Editing'");
							TEKey( (char) theChar, TEH[ curActif]);
						}
						
					if( (*TEH[ curActif])->teLength >= 3)
					{
						TESetSelect( 0, 32000, TEH[ curActif]);
					}
				}
			}
		break;
		
		case ArguTE:
			if( HexaDecimal( &theChar))
			{
				if( (*TEH[ curActif])->teLength < 2 ||
					(*TEH[ curActif])->selStart != (*TEH[ curActif])->selEnd)
					{
						curMusic->hasChanged = true;
						SaveUndo( UPattern, oldPat, "\pUndo 'Command Editing'");
						TEKey( (char) theChar, TEH[ curActif]);
					}
				
				if( (*TEH[ curActif])->teLength >= 2)
				{
					TESetSelect( 0, 32000, TEH[ curActif]);
				}
			}
		break;
	}
	
	if( theChar == 27)	// ESC Key
	{
		if( (*TEH[ curActif])->active != 0)
		{
			TEDeactivate( TEH[ curActif]);
			
			SetCmdValue( curActif);
		}
	}
	if( theChar == 8)
	{
		curMusic->hasChanged = true;
		SaveUndo( UPattern, oldPat, "\pUndo 'Command Editing'");
		TEKey( (char) theChar, TEH[ curActif]);
		
	//	UpdateEditorInfo();
	}
	else if( theChar == 9)
	{
		if( (*TEH[ curActif])->active != 0)
		{
			Boolean		next;
			short		loop;
			
			TEDeactivate( TEH[ curActif]);
			
			SetCmdValue( curActif);
			
			next = true;
			loop = 6;
			
			while( next == true && loop-- >= 0)
			{
				if( theEvent.modifiers & shiftKey) curActif--;
				else curActif++;
				
				if( curActif > VolumeTE) curActif = InstruTE;
				if( curActif < InstruTE) curActif = VolumeTE;
				
				next = false;
				
				if( curActif == InstruTE && thePrefs.DigitalInstru == false) next = true;
				if( curActif == NoteTE && thePrefs.DigitalNote == false) next = true;
				if( curActif == EffectTE && thePrefs.DigitalEffect == false) next = true;
				if( curActif == ArguTE && thePrefs.DigitalArgu == false) next = true;
				if( curActif == VolumeTE && thePrefs.DigitalVol == false) next = true;
			}
		}
		else
		{
			curActif = InstruTE;
			
			if( curActif == InstruTE && thePrefs.DigitalInstru == false) curActif++;;
			if( curActif == NoteTE && thePrefs.DigitalNote == false) curActif++;;
			if( curActif == EffectTE && thePrefs.DigitalEffect == false) curActif++;;
			if( curActif == ArguTE && thePrefs.DigitalArgu == false) curActif++;;
			if( curActif == VolumeTE && thePrefs.DigitalVol == false) curActif = InstruTE;
		}
		
		if( curActif > VolumeTE) curActif = InstruTE;
		if( curActif < InstruTE) curActif = VolumeTE;
		
		TEActivate( TEH[ curActif]);
		TESetSelect( 0, 32000, TEH[ curActif]);
	}
	else if(	theChar == 0x1E ||
 				theChar == 0x03 ||
 				theChar == 0x1F ||
 				theChar == 0x1C ||
 				theChar == 0x0D ||
 				theChar == 0x1D )
 				{
 					SetCmdValue( curActif);
 					DoKeyPressEditor( theChar);
				}
				
	if( (**(**GetMainDevice()).gdPMap).pixelSize == 1) BackColor( whiteColor);
	else RGBBackColor( &theColor);
	
	SetPatternCell( oldPos, oldTrack);
	
	SetPort( savePort);
}

void UpdateCurrentCmd(void)
{
GrafPtr	savePort;
Rect	caRect;
	
	

	if( ToolsDlog != NULL)
	{
		GetPort( &savePort);
		SetPortDialogPort( ToolsDlog);
		
		GetPortBounds( GetDialogPort( ToolsDlog), &caRect);
		
		if( caRect.bottom > 50)
		{
			if( (*TEH[ curActif])->active != 0)
			{
				BackColor( whiteColor);
				SetCmdValue( curActif);
				RGBBackColor( &theColor);
			}
		}
		SetPort( savePort);
	}
}

void ApplyBut( short value)
{
	AllCellApply = false;
	HiliteControl( AllBut, value);
}

void ActiveCmdWindow( short whichItem)
{
GrafPtr	savePort;

	DesactivateCmdWindow();
	
	if( whichItem < 0) return;
	
	if( ToolsDlog != NULL)
	{
		GetPort( &savePort);
		SetPortDialogPort( ToolsDlog);
		
		BackColor( whiteColor);
 				
		TEActivate( TEH[ whichItem]);
		
		SetCmdValue( curActif);
		
		TESetSelect( 0, 300, TEH[ whichItem]);
		
		curActif = whichItem;
		
		RGBBackColor( &theColor);
 	
		SetPort( savePort);
	}
}

void DesactivateCmdWindow(void)
{
GrafPtr	savePort;
Rect	caRect;
	
	

	if( ToolsDlog != NULL)
	{
		GetPort( &savePort);
		SetPortDialogPort( ToolsDlog);
		
		GetPortBounds( GetDialogPort( ToolsDlog), &caRect);
		
		if( caRect.bottom > 50)
		{
			if( (*TEH[ curActif])->active != 0)
			{
				BackColor( whiteColor);
				TEDeactivate( TEH[ curActif]);
				SetCmdValue( curActif);
				RGBBackColor( &theColor);
				
				SetPatternCell( oldPos, oldTrack);
			}
		}
		else
		{
			if( (*TEH[ curActif])->active != 0)
			{
				TEDeactivate( TEH[ curActif]);
				SetCmdValue( curActif);
			}
			SetPatternCell( oldPos, oldTrack);
		}
		
		SetPort( savePort);
	}
}
