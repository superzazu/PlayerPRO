#ifdef MAINPLAYERPRO
#include "Shuddup.h"
#endif
#include "MAD.h"
#include "RDriver.h"
#include "RDriverInt.h"
#include "MIDI.h"
#include <stdio.h>
#include "OMS.h"

#define refConTime			1L
#define refConOutput		3L
#define squidInputBufSize	16384	/* 16K */
#define recordingBufSize	10000	


	extern 		Boolean				PianoRecording, PianoMIDIInput;
	extern 		DialogPtr			InstruListDlog, EditorDlog;
	extern		short				LastCanal;
	extern		WindowPtr			oldWindow;
	
	extern 		short				TouchMem[11];
	extern		short				TrackMem[11];
	extern 		short				TouchIn;
	extern		DialogPtr			PianoDlog;

	Boolean					MIDIHardware, MIDIHardwareAlreadyOpen = false;
	OSErr					CalamariErr, squidLibErr;

	static	ProcPtr			CallBackFunction;

/***/

/* Globals */

Boolean		gSignedInToMIDIMgr;		/* are we signed into MIDI Manager? */
Boolean 	gNodesChanged;
short		gInputPortRefNum;		/* refNum of the OMS input port */
short		gOutputPortRefNum;		/* refNum of the OMS output port */
short		gCompatMode;			/* current OMS compatibility mode */

short 		gChosenInputID = 0;		/* uniqueID of selected input; 0 means none */
short		gChosenOutputID = 0;	/* uniqueID of selected output; 0 means none */
short		gOutNodeRefNum = -1;	/* node refNum of the selected output; -1 means non existant */

OMSIDListH	prevSelectionIN, prevSelectionOUT;

unsigned MidiVolume[128] = {
	 0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15,
	16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,
	32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47,
	48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63,
	64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
	64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
	64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
	64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64
  };

/***/

#define MySignature		'SNPL'

void DoPlayInstruInt( short	Note, short Instru, short effect, short arg, short vol, Channel *curVoice, long start, long end);
void NPianoRecordProcess( short i, short, short, short);

pascal void MyAppHook(OMSAppHookMsg *pkt, long myRefCon);
pascal void MyAppHook(OMSAppHookMsg *pkt, long myRefCon)
{

	long olda5 = SetA5(myRefCon);
	
	switch (pkt->msgType)
	{
	case omsMsgModeChanged:
		/* Respond to compatibility mode having changed */
		gCompatMode = pkt->u.modeChanged.newMode;
		/* this will cause side effects in the event loop */
		break;
	case omsMsgDestDeleted:
		if (gChosenOutputID == pkt->u.nodeDeleted.uniqueID) {
			gOutNodeRefNum = -1;	/* invalid */
		}
		break;
	case omsMsgNodesChanged:
		gNodesChanged = TRUE;
		break;
	}

	SetA5(olda5);

}

static OMSPacket	pktCopy;
static Boolean		newPacket;

void MyNullHook()
{
	short				pLength, i, myNote, curins, curvol, track;
	Rect				tempRect;
	GrafPtr				savePort;
	OMSPacket 			*pkt = &pktCopy;
	
	if( !newPacket) return;
	
	newPacket = false;
	
	pLength = pkt->len;	
	
	if( pkt->data[ 0] >= 0x90 && pkt->data[ 0] <= 0x9F)							// NOTE ON
	{
		myNote = pkt->data[ 1] - 12;
		if( myNote >= 0 && myNote < NUMBER_NOTES)
		{
			if( thePrefs.MIDIChanInsTrack) curins = pkt->data[ 0] - 0x90;
			else
			{
				curins = -1;
				GetIns( &curins, NULL);
			}
			
			if( thePrefs.MIDIVelocity) curvol = MidiVolume[ pkt->data[ 2]];
			else curvol = 0xFF;
			
			/*****************************/
			if( pkt->data[ 2] == 0)
			{
				pkt->data[ 0] -= 0x10;
				goto NOTEOFF; 							// This is a NOTE-OFF
			}
			/*****************************/
			
			if( thePrefs.MIDIChanInsTrack)
			{
				track = curins;
				if( track >= curMusic->header->numChn) track = curMusic->header->numChn-1;
			}
			else
			{
				track = GetWhichTrackPlay();
			}
			
			DoMidiSpeaker( myNote, curins, curvol);
			if( PianoRecording) NPianoRecordProcess( myNote, curins, curvol, track);
			else if( oldWindow == GetDialogWindow( EditorDlog)) DigitalEditorProcess( myNote, NULL, NULL, NULL);
			
			if( thePrefs.MIDIChanInsTrack) SelectTouche( myNote, curins);
			else SelectTouche( myNote, curins);
			
			TouchIn++;
			if( TouchIn < 0 || TouchIn >= 10) TouchIn = 0;
			TouchMem[ TouchIn] = myNote;
			TrackMem[ TouchIn] = track;			// + 1
			if( TrackMem[ TouchIn] < 0 || TrackMem[ TouchIn] >= MADDriver->DriverSettings.numChn) TrackMem[ TouchIn] = 0;
		}
	}
	else if( pkt->data[ 0] >= 0x80 && pkt->data[ 0] <= 0x8F)							// NOTE OFF
	{
	NOTEOFF:
	
		myNote = pkt->data[ 1] - 12;
		if( myNote >= 0 && myNote < NUMBER_NOTES)
		{
			for(i=0; i<10;i++)
			{
				if( TouchMem[ i] == myNote)
				{
					if( PianoDlog != NULL)
					{
						GetPort( &savePort);
						SetPortDialogPort( PianoDlog);
						
						GetToucheRect( &tempRect, myNote);
						EffaceTouche( myNote, &tempRect);
						
						switch( thePrefs.KeyUpMode)
						{
							case eStop:
								if( PianoRecording)
								{
									NPianoRecordProcess( 0xFF, 0xFF, 0x10, TrackMem[ i]);
								}
							break;
							
							case eNoteOFF:
								if( PianoRecording)
								{
									NPianoRecordProcess( 0xFE, 0xFF, 0xFF, TrackMem[ i]);
								}
								
								MADDriver->chan[ TrackMem[ i]].KeyOn = false;
							break;
						}
						
						SetPort( savePort);
					}
					TouchMem[i] = -1;
				}
			}
		}
	}
}

pascal void	MyReadHook(OMSPacket *pkt, long myRefCon);
pascal void	MyReadHook(OMSPacket *pkt, long myRefCon)
{

	long 				olda5 = SetA5( myRefCon);
	short				pLength, i, myNote, curins, curvol;
	Rect				tempRect;
	GrafPtr				savePort;
	
	if( thePrefs.MidiKeyBoard)
	{
		pktCopy = *pkt;
		newPacket = true;
	}
	
	SetA5(olda5);

}

void CloseMIDIHarware(void)
{
	if( MIDIHardware)
	{
		if (gSignedInToMIDIMgr)
		gSignedInToMIDIMgr = false;
		
		if( MIDIHardwareAlreadyOpen)
		{
			OMSSignOut(MySignature);
			MIDIHardwareAlreadyOpen = false;
		}
	}
	
	MIDIHardware = false;
}

OSErr InitOMS(OSType appSignature, OSType inPortID, OSType outPortID)
{
	OSErr 			err;
	OMSAppHookUPP 	appHook;
	OMSReadHookUPP 	readHook;
	
	gSignedInToMIDIMgr = FALSE;
	
	/*	Find out what version of OMS is installed, if any. */
	if (OMSVersion() == 0) return -1;
	
	appHook = NewOMSAppHook(MyAppHook);
	readHook = NewOMSReadHook(MyReadHook);
	
	/*	Sign in to OMS */
	err = OMSSignIn( appSignature, (long)LMGetCurrentA5(), LMGetCurApName(), appHook, &gCompatMode);
	/*	Passing CurrentA5 as the refCon solves the problem of A5 setup in the appHook.
	 Using other Apple-recommended techniques for setting up A5 in the appHook
	 are fine as well.  The client name will be the same as the application's name,
	 as stored in the low-memory global CurApName. */
	
	if (err)
		return err;
	
	/*	Add an input port */
	err = OMSAddPort(appSignature, inPortID, omsPortTypeInput, (OMSReadHook2UPP)readHook, (long)LMGetCurrentA5(), &gInputPortRefNum);
	if (err) goto errexit;
	
	gOutputPortRefNum = -1;
	err = OMSAddPort( appSignature, outPortID, omsPortTypeOutput, NULL, NULL, &gOutputPortRefNum);
	
	prevSelectionIN		= NULL;
	prevSelectionOUT	= NULL;
	
	return noErr;
	
errexit:
	OMSSignOut( appSignature);
	
	return err;
	
	return noErr;
}

void OpenMIDIHardware( void)	
{
	if( MIDIHardware == false) return;
	
	if( MIDIHardwareAlreadyOpen == true) return;
	
	if (InitOMS( 'SNPL', 'in  ', 'out ') != noErr)
	{
		MIDIHardware = false;
		return;
	}
	else
	{
		MIDIHardware = true;
		MIDIHardwareAlreadyOpen = true;
	}
}

void InitMIDIHarware(void)
{
	long		size;
	Handle		ItemHdl;
	Handle		TheIcon;
	OSErr		TheErr;
	
	MIDIHardwareAlreadyOpen = false;
	newPacket = false;
	
	if (OMSVersion() == 0) MIDIHardware = false;
	else MIDIHardware = true;
	
//	if( thePrefs.SendMIDIClockData) OpenMIDIHardware();
	
	return;
}

void NDoPlayInstru(short	Note, short Instru, short effect, short arg, short vol);

void DoMidiSpeaker( short note, short Instru, long arg)
{
	Point	theCell;
	short	vol, chan;

	if( thePrefs.MIDIVelocity)
	{
		vol = MidiVolume[ arg];
		vol += 0x10;
	}
	else vol = 0xFF;
	
	if( !thePrefs.MIDIChanInsTrack)
	{
		if( !GetIns( &Instru, NULL)) return;
		chan = LastCanal;
	}
	else
	{
		chan = Instru;
		if( chan >= curMusic->header->numChn) chan = curMusic->header->numChn-1;
	}
	
	DoPlayInstruInt( note, Instru, 0, 0, vol, &MADDriver->chan[ chan], 0, 0);
}

/*void SquidAllNotesOff(short PortRefNum)
{
	int KeyNum;
	
	// AddLine("Turning off all notes...");
	
	for (KeyNum=0; KeyNum<128; KeyNum++)
	{
		SendKeyOn(PortRefNum, 0x80000000, (Byte) KeyNum, (Byte) 0);
	}
	
}*/

void	OpenOrCloseConnection(Boolean opening);
void	OpenOrCloseConnection(Boolean opening)
{
	OSErr err;
	OMSConnectionParams conn;
	
	if (gChosenInputID == 0)
		return;
	conn.nodeUniqueID = gChosenInputID;
	conn.appRefCon = 0;		/* not used in this example */
	if (opening)
		err = OMSOpenConnections(MySignature, 'in  ', 1, &conn, FALSE);
	else OMSCloseConnections(MySignature, 'in  ', 1, &conn);
}

void SelectOMSConnections( Boolean Input)
{
	GrafPtr	savedPort;
	
	GetPort( &savedPort);
	
	OpenMIDIHardware();
	
	if( Input)
	{
		OMSIDListH	in;
		
		in = OMSChooseNodes( prevSelectionIN, "\pSelect Input", false, omsIncludeInputs + omsIncludeReal + omsIncludeVirtual + omsIncludeSync, NULL);
		if( in)
		{
			if( prevSelectionIN) OMSDisposeHandle( prevSelectionIN);
			prevSelectionIN = in;
			
			OpenOrCloseConnection( false);
			
			gChosenInputID = (*prevSelectionIN)->id[ 0];
			
			OpenOrCloseConnection( true);
		}
	}
	else
	{
		OMSIDListH	out;
		
		out = OMSChooseNodes( prevSelectionOUT, "\pSelect Output", false, omsIncludeOutputs + omsIncludeReal + omsIncludeVirtual, NULL);
		if( out)
		{
			if( prevSelectionOUT) OMSDisposeHandle( prevSelectionOUT);
			prevSelectionOUT = out;
			
			gChosenOutputID = (*prevSelectionOUT)->id[ 0];
			
			gOutNodeRefNum = OMSUniqueIDToRefNum( gChosenOutputID);
		}
	}
	
	SetPort( savedPort);
}

void SendMIDIClock( MADDriverRec *intDriver, Byte MIDIByte)
{
	OMSMIDIPacket pack;
	
	if( MIDIHardware == false) return;
	
	if( gOutNodeRefNum == -1) return;
	
	/*** Timing Clock: 0xF8, Start: 0xFA, Continue: 0xFB, Stop: 0xFC ***/
	
	pack.flags	= 0;
	pack.len	= 1;
	
	pack.data[ 0] = MIDIByte;
	
	OMSWritePacket2( &pack, gOutNodeRefNum, gOutputPortRefNum);
}

void SendMIDITimingClock( MADDriverRec *MDriver)
{
	OMSMIDIPacket 	pack;
	short			i, x, y;
	Cmd				*aCmd;

	long			high, low, time, timeResult, curTime;
	long			speed, finespeed;
	
	if( MIDIHardware == false) return;
	
	if( gOutNodeRefNum == -1) return;
	
	//////
	
	if( MDriver == NULL) Debugger();
	if( MDriver->curMusic == NULL) Debugger();
	if( MDriver->curMusic->header == NULL) Debugger();
	
	time				= 0;
	speed				= MDriver->curMusic->header->speed;
	finespeed			= MDriver->curMusic->header->tempo;
	
	curTime				= 0;
	
	for( i = 0; i < MDriver->curMusic->header->numPointers; i++)
	{
		for( x = 0; x < MDriver->curMusic->partition[ MDriver->curMusic->header->oPointers[ i]]->header.size; x++)
		{
			time ++;
			
			if( i == MDriver->PL	&&
				x == MDriver->PartitionReader)
				{
					curTime = time;
				}
			
			for( y = 0; y <  MDriver->curMusic->header->numChn; y++)
			{
				aCmd = GetMADCommand( x, y, MDriver->curMusic->partition[ MDriver->curMusic->header->oPointers[ i]]);
				
				/** SpeedE **/
				
			/*	if( aCmd->cmd == speedE)
				{
					// Compute time for this interval

					timeResult += ((float) (time * 125L * speed * 6NULL)) / ((float) (5NULL * finespeed));
					time = 0;
					
					//
					
					if( aCmd->arg < 32)
					{
						if( aCmd->arg != 0) speed = aCmd->arg;
					}
					else
					{
						if( aCmd->arg != 0) finespeed = aCmd->arg;
					}
				}*/
				
				/** SkipE **/
				
				if( aCmd->cmd == skipE)
				{
					for( ; x < MDriver->curMusic->partition[ MDriver->curMusic->header->oPointers[ i]]->header.size; x++)
					{
						if( i == MDriver->PL	&&
							x == MDriver->PartitionReader)
						{
							curTime = time;
						}
					}
				}
			}
		}
	}
	
	/*** Timing Clock: 0xF8, Start: 0xFA, Continue: 0xFB, Stop: 0xFC ***/
	
	pack.flags	= 0;
	pack.len	= 3;
	
	high = curTime & 0x3F80;
	high >>= 7;
	low = curTime & 0x007F;
	
	pack.data[ 0] = 0xF2;
	pack.data[ 1] = high;
	pack.data[ 2] = low;
	
	OMSWritePacket2( &pack, gOutNodeRefNum, gOutputPortRefNum);
}
