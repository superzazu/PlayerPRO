/********************						***********************/
//
//	Player PRO 5.0 - DRIVER SOURCE CODE -
//
//	Library Version 5.0
//
//	To use with MAD Library for Mac: Symantec, CodeWarrior and MPW
//
//	Antoine ROSSET
//	16 Tranchees
//	1206 GENEVA
//	SWITZERLAND
//
//	COPYRIGHT ANTOINE ROSSET 1996, 1997, 1998
//
//	Thank you for your interest in PlayerPRO !
//
//	FAX:				(+41 22) 346 11 97
//	PHONE: 			(+41 79) 203 74 62
//	Internet: 	RossetAntoine@bluewin.ch
//
/********************						***********************/

#ifdef __APPLE__
#include <PlayerPROCore/PlayerPROCore.h>
#else
#include "RDriver.h"
#include "FileUtils.h"
#endif
#include "MADfg.h"

#if defined(NOEXPORTFUNCS) && NOEXPORTFUNCS
#include "embeddedPlugs.h"
#endif

#ifdef MADAPPIMPORT
#include "APPL.h"
#else
static OSErr MADFG2Mad(char *MADPtr, long size, MADMusic *theMAD, MADDriverSettings *init);
#endif

static struct MusicPattern* oldDecompressPartitionMAD1(struct MusicPattern* myPat, short Tracks, MADDriverSettings *init)
{
	struct MusicPattern*	finalPtr;
	Byte 					*srcPtr;
	struct Command			*myCmd;
	short					maxCmd;
	
	finalPtr = (struct MusicPattern*) malloc(sizeof(struct oldPatHeader) + myPat->header.PatternSize * Tracks * sizeof(struct Command));
	if (finalPtr == NULL)
		return NULL;
	
	memcpy(finalPtr, myPat, sizeof(struct oldPatHeader));
	
	srcPtr = (Byte*) myPat->Commands;
	myCmd = (struct Command*) finalPtr->Commands;
	maxCmd = finalPtr->header.PatternSize * Tracks;
	
	/*** Decompression Routine ***/
	
	/*
	 * First Byte = 0x03 -> Instrument + AmigaPeriod + Effect + Cmd
	 * First Byte = 0x02 -> Instrument + AmigaPeriod
	 * First Byte = 0x01 -> Effect + Cmd
	 * First Byte = 0x00 -> nothing
	 */
	
	while (maxCmd != 0) {
		maxCmd--;
		
		switch (*srcPtr) {
			case 0x03:
				srcPtr++;
				
				((short*)myCmd)[0] = ((short*)srcPtr)[0];
				((short*)myCmd)[1] = ((short*)srcPtr)[1];
				
				srcPtr += 4;
				break;
				
			case 0x02:
				srcPtr++;
				
				((short*)myCmd)[0] = *((short*)srcPtr);
				((short*)myCmd)[1] = 0;
				
				srcPtr += 2;
				break;
				
			case 0x01:
				srcPtr++;
				
				((short*)myCmd)[0] = 0;
				((short*)myCmd)[1] = *((short*)srcPtr);
				
				srcPtr += 2;
				break;
				
			case 0x00:
				srcPtr ++;
				
				*((int*)myCmd) = 0;
				break;
				
			default:
				//DebugStr("\pDecompress MAD1 failed.");
				free(finalPtr);
				return NULL;
				break;
		}
		myCmd++;
	}
	
	return finalPtr;
}

static inline struct Command* GetOldCommand(short PosX, short TrackIdX, struct MusicPattern* tempMusicPat)
{
	if (PosX < 0)
		PosX = 0;
	else if (PosX >= tempMusicPat->header.PatternSize)
		PosX = tempMusicPat->header.PatternSize -1;
	
	return &(tempMusicPat->Commands[(tempMusicPat->header.PatternSize * TrackIdX) + PosX]);
}

static inline void MOToldPatHeader(struct oldPatHeader * p)
{
	PPBE32(&p->PatternSize);
	PPBE32(&p->CompressionMode);
	PPBE32(&p->PatBytes);
	PPBE32(&p->unused2); // this is superfluous
}

static void MOToldInstrData(struct FileInstrData * i)
{
	PPBE32(&i->insSize);
	PPBE32(&i->loopStart);
	PPBE32(&i->loopLenght);
	PPBE16(&i->CompCode);
	PPBE16(&i->freq);
}

static void MOToldMADSpec(struct oldMADSpec * m)
{
	int i;
	PPBE32(&m->MADIdentification);
	//TODO: dispatch this
	for (i = 0; i < 64; i++) {
		MOToldInstrData(&m->fid[i]);
	}
}

OSErr MADFG2Mad(char *MADPtr, long size, MADMusic *theMAD, MADDriverSettings *init)
{
	short		i, x;
	long		inOutCount = 0, OffSetToSample = 0;
	int			z = 0;
	Boolean		MADConvert = false;
	OSType		oldMadIdent = 0;
	int			finetune[16] = {
		8363,	8413,	8463,	8529,	8581,	8651,	8723,	8757,
		7895,	7941,	7985,	8046,	8107,	8169,	8232,	8280
	};
	
	
	/**** Old MADFG variables ****/
	
	oldMADSpec		*oldMAD;
	oldMAD = (oldMADSpec*)MADPtr;
	
	MOToldMADSpec(oldMAD);
	
	/**** HEADER ****/
	oldMadIdent = oldMAD->MADIdentification;
	if (oldMadIdent == 'MADF')
		MADConvert = true;
	else if (oldMadIdent == 'MADG')
		MADConvert = false;
	else
		return MADFileNotSupportedByThisPlug;
	OffSetToSample += sizeof(oldMADSpec);
	
	// Conversion
	inOutCount = sizeof(MADSpec);
	theMAD->header = (MADSpec*) calloc(inOutCount, 1);
	if (theMAD->header == NULL) return MADNeedMemory;
	
	theMAD->header->MAD = 'MADK';
	
	memcpy(theMAD->header->name, oldMAD->NameSignature, 32);
	theMAD->header->numPat			= oldMAD->PatMax;
	theMAD->header->numChn			= oldMAD->Tracks;
	theMAD->header->numPointers		= oldMAD->numPointers;
	memcpy(theMAD->header->oPointers, oldMAD->oPointers, 128);
	theMAD->header->speed			= 6;
	theMAD->header->tempo			= 125;
	
	strncpy(theMAD->header->infos, "Converted by PlayerPRO MAD-F-G Plug (\xA9\x41ntoine ROSSET <rossetantoine@bluewin.ch>)", sizeof(theMAD->header->infos));
	
	
	theMAD->sets = (FXSets*)calloc(MAXTRACK * sizeof(FXSets), 1);
	//TODO: dispatch this
	for (i = 0; i < MAXTRACK; i++)
		theMAD->header->chanBus[i].copyId = i;
	
	/**** Patterns *******/
	
	for (i = 0; i < oldMAD->PatMax; i++)
	{
		OSType CompMode = 0;
		struct MusicPattern		*tempPat, *tempPat2;
		struct oldPatHeader		tempPatHeader;
		
		/** Lecture du header de la partition **/
		if (!MADConvert) {
			inOutCount = sizeof(struct oldPatHeader);
			
			memcpy(&tempPatHeader, MADPtr + OffSetToSample, inOutCount);
			MOToldPatHeader(&tempPatHeader);
		} else
			tempPatHeader.PatternSize = 64;
		
		/*************************************************/
		/** Lecture du header + contenu de la partition **/
		/*************************************************/
		CompMode = tempPatHeader.CompressionMode;
		
		if (CompMode == 'MAD1') {
			inOutCount = sizeof(struct MusicPattern) + tempPatHeader.PatBytes;
		} else {
			inOutCount = sizeof(struct MusicPattern) + oldMAD->Tracks * tempPatHeader.PatternSize * sizeof(struct Command);
		}
		
		tempPat = (struct MusicPattern*)malloc(inOutCount);
		if (tempPat == NULL)
			return MADNeedMemory;
		
		if (MADConvert) {
			tempPat = (struct MusicPattern*)((Ptr) tempPat + sizeof(struct oldPatHeader));
			inOutCount -= sizeof(struct oldPatHeader);
		}
		
		memcpy(tempPat, MADPtr + OffSetToSample, inOutCount);
		OffSetToSample += inOutCount;
		MOToldPatHeader(&tempPat->header);
		
		
		if (MADConvert) {
			tempPat = (struct MusicPattern*) ((Ptr) tempPat - sizeof(struct oldPatHeader));
			tempPat->header.PatternSize = 64;
			tempPat->header.CompressionMode = 'NONE';
			
			for (x = 0; x < 20; x++) tempPat->header.PatternName[x] = 0;
			
			tempPat->header.unused2 = 0;
		}
		
		if (tempPat->header.CompressionMode == 'MAD1') {
			tempPat2 = oldDecompressPartitionMAD1(tempPat, oldMAD->Tracks, init);
			free(tempPat);
			tempPat = tempPat2;
		}
		
		/**************/
		/* CONVERSION */
		/**************/
		
		theMAD->partition[i] = (PatData*) calloc(sizeof(PatHeader) + theMAD->header->numChn * tempPat->header.PatternSize * sizeof(Cmd), 1);
		if (theMAD->partition[i] == NULL)
			return MADNeedMemory;
		
		theMAD->partition[i]->header.size		= tempPat->header.PatternSize;
		theMAD->partition[i]->header.compMode	= 'NONE';
		
		memcpy(theMAD->partition[i]->header.name, tempPat->header.PatternName, 20);
		
		theMAD->partition[i]->header.patBytes = 0;
		theMAD->partition[i]->header.unused2 = 0;
		
		for (x = 0; x < theMAD->partition[i]->header.size; x++) {
			for (z = 0; z < theMAD->header->numChn; z++) {
				struct Command *oldCmd;
				Cmd	*aCmd;
				
				aCmd = GetMADCommand(x, z, theMAD->partition[i]);
				
				oldCmd 	= GetOldCommand(x, z, tempPat);
				
				aCmd->ins 	= oldCmd->InstrumentNo;
				if (oldCmd->AmigaPeriod == 0)
					aCmd->note = 0xFF;
				else
					aCmd->note 	= oldCmd->AmigaPeriod + 22;
				aCmd->cmd	= oldCmd->EffectCmd;
				aCmd->arg	= oldCmd->EffectArg;
				aCmd->vol	= 0xFF;
				
				if (aCmd->cmd == 0x0C) {
					aCmd->vol = 0x10 + (aCmd->arg & 0x00FF);
					aCmd->cmd = 0;
					aCmd->arg = 0;
				}
			}
		}
		free(tempPat);
	}
	for (i = theMAD->header->numPat; i < MAXPATTERN ; i++) theMAD->partition[i] = NULL;
	
	for (i = 0; i < MAXTRACK; i++) {
		if (i % 2 == 0) theMAD->header->chanPan[i] = MAX_PANNING/4;
		else theMAD->header->chanPan[i] = MAX_PANNING - MAX_PANNING/4;
		
		theMAD->header->chanVol[i] = MAX_VOLUME;
	}
	
	theMAD->header->generalVol		= 64;
	theMAD->header->generalSpeed	= 80;
	theMAD->header->generalPitch	= 80;
	
	/**** Instruments header *****/
	
	theMAD->fid = (InstrData*) calloc(sizeof(InstrData) * (long) MAXINSTRU, 1);
	if (!theMAD->fid)
		return MADNeedMemory;
	
	theMAD->sample = (sData**) calloc(sizeof(sData*) * (long) MAXINSTRU * (long) MAXSAMPLE, 1);
	if (!theMAD->sample)
		return MADNeedMemory;
	
	for (i = 0; i < MAXINSTRU; i++) theMAD->fid[i].firstSample = i * MAXSAMPLE;
	
	for (i = 0; i < 64; i++) {
		InstrData	*curIns = &theMAD->fid[i];
		
		memcpy(curIns->name, oldMAD->fid[i].Filename, 32);
		curIns->type = 0;
		
		if (oldMAD->fid[i].insSize > 0) {
			sData	*curData;
			
			curIns->numSamples = 1;
			curIns->volFade = DEFAULT_VOLFADE;
			
			curData = theMAD->sample[i * MAXSAMPLE + 0] = (sData*)calloc(sizeof(sData), 1);
			
			curData->size		= oldMAD->fid[i].insSize;
			curData->loopBeg 	= oldMAD->fid[i].loopStart;
			curData->loopSize 	= oldMAD->fid[i].loopLenght;
			curData->vol		= oldMAD->fid[i].volume;
			curData->c2spd		= finetune[oldMAD->fid[i].fineTune];
			curData->loopType	= 0;
			curData->amp		= oldMAD->fid[i].amplitude;
			curData->relNote	= 0;
			curData->data 		= (Ptr)malloc(curData->size);
			if (curData->data == NULL)
				return MADNeedMemory;
			
			memcpy(curData->data, MADPtr + OffSetToSample, curData->size);
			OffSetToSample += curData->size;
			if (curData->amp == 16) {
				int		ll;
				short	*shortPtr = (short*) curData->data;
				
				for (ll = 0; ll < curData->size/2; ll++) PPBE16(&shortPtr[ll]);
			}
		}
		else curIns->numSamples = 0;
	}
	
	return noErr;
}

static OSErr TestoldMADFile(void *AlienFile)
{
	OSType myMADSign = *((OSType*)AlienFile);
	PPBE32(&myMADSign);
	
	if (myMADSign == 'MADF' || myMADSign == 'MADG')
		return noErr;
	else
		return  MADFileNotSupportedByThisPlug;
}

static OSErr ExtractoldMADInfo(PPInfoRec *info, void *AlienFile)
{
	oldMADSpec	*myMOD = (oldMADSpec*)AlienFile;
	//long		PatternSize;
	short		i;
	//short		tracksNo;
	
	/*** Signature ***/
	
	info->signature = myMOD->MADIdentification;
	PPBE32(&info->signature);
	
	/*** Internal name ***/
	
	strncpy(info->internalFileName, myMOD->NameSignature, sizeof(myMOD->NameSignature));
	
	/*** Tracks ***/
	
	info->totalTracks = myMOD->Tracks;
	//PPBE16(&info->totalTracks);
	
	/*** Total Patterns ***/
	
	info->totalPatterns = 0;
	for (i = 0; i < 128; i++) {
		if (myMOD->oPointers[i] >= info->totalPatterns)
			info->totalPatterns = myMOD->oPointers[i];
	}
	info->totalPatterns++;
	
	/*** Partition Length ***/
	
	info->partitionLength = myMOD->numPointers;
	
	/*** Total Instruments ***/
	
	for (i = 0, info->totalInstruments = 0; i < MAXINSTRU ; i++) {
		int insSizeSwap = myMOD->fid[i].insSize;
		PPBE32(&insSizeSwap);
		if (insSizeSwap > 5)
			info->totalInstruments++;
	}
	
	strncpy(info->formatDescription, "MAD-FG Plug", sizeof(info->formatDescription));
	
	return noErr;
}

#ifndef _MAC_H
EXP OSErr FillPlug(PlugInfo *p);
EXP OSErr PPImpExpMain(OSType order, Ptr AlienFileName, MADMusic *MadFile, PPInfoRec *info, MADDriverSettings *init);

EXP OSErr FillPlug(PlugInfo *p)		// Function USED IN DLL - For PC & BeOS
{
	strncpy(p->type, 		"MADF", sizeof(p->type));
	strncpy(p->MenuName, 	"MAD-FG", sizeof(p->MenuName));
	p->mode	= MADPlugImport;
	p->version = 2 << 16 | 0 << 8 | 0;
	
	return noErr;
}
#endif

/*****************/
/* MAIN FUNCTION */
/*****************/

#ifndef MADAPPIMPORT
#if defined(NOEXPORTFUNCS) && NOEXPORTFUNCS
OSErr mainMADfg(OSType order, Ptr AlienFileName, MADMusic *MadFile, PPInfoRec *info, MADDriverSettings *init)
#else
extern OSErr PPImpExpMain(OSType order, Ptr AlienFileName, MADMusic *MadFile, PPInfoRec *info, MADDriverSettings *init)
#endif
{
	OSErr	myErr = noErr;
	Ptr		AlienFile;
	UNFILE	iFileRefI;
	long	sndSize;
	
	switch (order) {
		case MADPlugImport:
			iFileRefI = iFileOpenRead(AlienFileName);
			if (iFileRefI) {
				sndSize = iGetEOF(iFileRefI);
				
				// ** MEMORY Test
				AlienFile = (Ptr)malloc(sndSize * 2);
				if (AlienFile == NULL) {
					myErr = MADNeedMemory;
				} else {
					free(AlienFile);
					
					AlienFile = (Ptr)malloc(sndSize);
					myErr = iRead(sndSize, AlienFile, iFileRefI);
					if (myErr == noErr) {
						myErr = TestoldMADFile(AlienFile);
						if (myErr == noErr) {
							myErr = MADFG2Mad(AlienFile, sndSize, MadFile, init);
						}
					}
					free(AlienFile);
					AlienFile = NULL;
				}
				iClose(iFileRefI);
			} else
				myErr = MADReadingErr;
			break;
			
		case MADPlugTest:
			iFileRefI = iFileOpenRead(AlienFileName);
			if (iFileRefI) {
				sndSize = 5000;	// Read only 5000 first bytes for optimisation
				
				AlienFile = (Ptr)malloc(sndSize);
				if (AlienFile == NULL) {
					myErr = MADNeedMemory;
				} else {
					myErr = iRead(sndSize, AlienFile, iFileRefI);
					if(myErr == noErr)
						myErr = TestoldMADFile(AlienFile);
					
					free(AlienFile);
					AlienFile = NULL;
				}
				iClose(iFileRefI);
			} else
				myErr = MADReadingErr;
			break;
			
		case 'INFO':
			iFileRefI = iFileOpenRead(AlienFileName);
			if (iFileRefI) {
				info->fileSize = iGetEOF(iFileRefI);
				
				sndSize = 5000;	// Read only 5000 first bytes for optimisation
				AlienFile = (Ptr)malloc(sndSize);
				if (AlienFile == NULL) {
					myErr = MADNeedMemory;
				} else {
					myErr = iRead(sndSize, AlienFile, iFileRefI);
					if (myErr == noErr) {
						myErr = ExtractoldMADInfo(info, AlienFile);
					}
					free(AlienFile);
					AlienFile = NULL;
				}
				iClose(iFileRefI);
			} else
				myErr = MADReadingErr;
			break;
			
		default:
			myErr = MADOrderNotImplemented;
			break;
	}
	
	return myErr;
}
#else
OSErr ExtractMADFGInfo(void *info, void *AlienFile)
{
	return ExtractoldMADInfo(info, AlienFile);
}

OSErr TestMADFGFile(void *AlienFile)
{
	return TestoldMADFile(AlienFile);
}
#endif
