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

#include "RDriver.h"
#include "RDriverInt.h"
#include "FileUtils.h"

//TODO: Move to unicode functions

OSErr CheckMADFile( Ptr name)
{
	UNFILE			refNum;
	char				charl[ 20];
	OSErr				err;
	
	refNum = iFileOpen( name);
	if( !refNum) return MADReadingErr;
	else
	{
		iRead( 10, charl, refNum);
		
		if( charl[ 0] == 'M' &&
				charl[ 1] == 'A' &&
				charl[ 2] == 'D' &&
				charl[ 3] == 'K') err = noErr;
		else err = MADIncompatibleFile;
		
		iClose( refNum);
	}
	
	return err;
}

OSErr TESTmain( OSType order, Ptr AlienFileName, MADMusic *MadFile, PPInfoRec *info, MADDriverSettings *init);

OSErr CallImportPlug(	MADLibrary*				inMADDriver,
						short					PlugNo,				// CODE ID
						OSType					order,
						Ptr						AlienFile,
						MADMusic				*theNewMAD,
						PPInfoRec				*info)
{
	OSErr				myErr;
	MADDriverSettings 	driverSettings;
	
	myErr = noErr;
	
	myErr = (inMADDriver->ThePlug[ PlugNo].IOPlug) (order, AlienFile, theNewMAD, info, &driverSettings);
	
	return( myErr);
}

OSErr	PPTestFile( MADLibrary* inMADDriver,char	*kindFile, Ptr AlienFile)
{
	short			i;
	MADMusic	aMAD;
	PPInfoRec		InfoRec;
	
	for( i = 0; i < inMADDriver->TotalPlug; i++)
	{
		if( !strcmp( kindFile, inMADDriver->ThePlug[ i].type))
		{
			return( CallImportPlug( inMADDriver, i, 'TEST', AlienFile, &aMAD, &InfoRec));
		}
	}
	return MADCannotFindPlug;
}

OSErr	PPInfoFile( MADLibrary* inMADDriver, char	*kindFile, char	*AlienFile, PPInfoRec	*InfoRec)
{
	short			i;
	MADMusic	aMAD;
	
	for( i = 0; i < inMADDriver->TotalPlug; i++)
	{
		if( !strcmp( kindFile, inMADDriver->ThePlug[ i].type))
		{
			return( CallImportPlug( inMADDriver, i, 'INFO', AlienFile, &aMAD, InfoRec));
		}
	}
	return MADCannotFindPlug;
}

OSErr	PPExportFile( MADLibrary* inMADDriver, char	*kindFile, char	*AlienFile, MADMusic	*theNewMAD)
{
	short		i;
	PPInfoRec	InfoRec;
	
	for( i = 0; i < inMADDriver->TotalPlug; i++)
	{
		if( !strcmp( kindFile, inMADDriver->ThePlug[ i].type))
		{
			return( CallImportPlug( inMADDriver, i, 'EXPL', AlienFile, theNewMAD, &InfoRec));
		}
	}
	return MADCannotFindPlug;
}

OSErr	PPImportFile( MADLibrary* inMADDriver, char	*kindFile, char	*AlienFile, MADMusic	**theNewMAD)
{
	short		i;
	PPInfoRec	InfoRec;
	
	for( i = 0; i < inMADDriver->TotalPlug; i++)
	{
		if( !strcmp( kindFile, inMADDriver->ThePlug[ i].type))
		{
			*theNewMAD = (MADMusic*) calloc( sizeof( MADMusic), 1);
			if( !*theNewMAD) return MADNeedMemory;
			
			return( CallImportPlug( inMADDriver, i, 'IMPL', AlienFile, *theNewMAD, &InfoRec));
		}
	}
	return MADCannotFindPlug;
}

OSErr	PPIdentifyFile( MADLibrary* inMADDriver, char	*type, Ptr AlienFile)
{
	FILE*				refNum;
	short				i;
	PPInfoRec		InfoRec;
	OSErr				iErr;
	
	strcpy( type, "!!!!");
	
	// Check if we have access to this file
	refNum = iFileOpen( AlienFile);
	if( !refNum) return MADReadingErr;
	iClose( refNum);
	
	// Is it a MAD file?
	iErr = CheckMADFile( AlienFile);
	if( iErr == noErr)
	{
		strcpy( type, "MADK");
		return noErr;
	}
	
	for( i = 0; i < inMADDriver->TotalPlug; i++)
	{
		if( CallImportPlug( inMADDriver, i, 'TEST', AlienFile, NULL, &InfoRec) == noErr)
		{
			strcpy( type, inMADDriver->ThePlug[ i].type);
			
			return noErr;
		}
	}
	
	strcpy( type, "!!!!");
	
	return MADCannotFindPlug;
}

Boolean	MADPlugAvailable( MADLibrary* inMADDriver, char	*kindFile)
{
	short		i;

	if( !strcmp( kindFile, "MADK")) return true;
	
	for( i = 0; i < inMADDriver->TotalPlug; i++)
	{
		if( !strcmp( kindFile, inMADDriver->ThePlug[ i].type)) return true;
	}
	return false;
}

typedef OSErr (*PLUGFILLDLLFUNC) ( PlugInfo*);

Boolean LoadPlugLib( Ptr name, PlugInfo* plug)
{
	PLUGFILLDLLFUNC		fpFuncAddress;
	OSErr							err;
	
	strcpy( plug->file, name);
	
	plug->hLibrary = LoadLibraryA( name);
	if( !plug->hLibrary) return false;
	
	plug->IOPlug = (PLUGDLLFUNC) GetProcAddress( plug->hLibrary, "PPImpExpMain");
	if( !plug->IOPlug)
	{
		FreeLibrary(plug->hLibrary);
		return false;
	}
	
	fpFuncAddress = (PLUGFILLDLLFUNC) GetProcAddress( plug->hLibrary, "FillPlug");
	if( !fpFuncAddress)
	{
		FreeLibrary(plug->hLibrary);
		return false;
	}
	
	err = (*fpFuncAddress)( plug);
	
	return true;
}

void MInitImportPlug( MADLibrary* inMADDriver, char *PlugsFolderName)
{
	///////////
	inMADDriver->TotalPlug = 0;
	///////////
	
	{
		HANDLE				hFind;
		WIN32_FIND_DATAA	fd;
		BOOL				bRet = TRUE;
		char				FindFolder[ 200], inPlugsFolderName[ 200];
		
		if( PlugsFolderName)
		{
			strcpy_s( inPlugsFolderName, 200, PlugsFolderName);
			strcat_s( inPlugsFolderName, 200, "/");
			
			strcpy_s( FindFolder, 200, inPlugsFolderName);
		}
		else
		{
			strcpy_s( inPlugsFolderName, 200, "/");
			strcpy_s( FindFolder, 200, inPlugsFolderName);
		}
		strcat_s( FindFolder, 200, "*.PLG");
		
		hFind = FindFirstFileA( FindFolder, &fd);
		
		inMADDriver->ThePlug = (PlugInfo*) calloc( MAXPLUG, sizeof( PlugInfo));
		
		while( hFind != INVALID_HANDLE_VALUE && bRet)
		{
			if( (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) == 0)
			{
				if( inMADDriver->TotalPlug < MAXPLUG)
				{
					char myCompleteFilename[ 200];
					
					strcpy_s( myCompleteFilename, 200, inPlugsFolderName);
					strcat_s( myCompleteFilename, 200, fd.cFileName);
					
					if( LoadPlugLib( myCompleteFilename, &inMADDriver->ThePlug[ inMADDriver->TotalPlug])) inMADDriver->TotalPlug++;
				}
			}
			
			bRet = FindNextFileA( hFind, &fd);
		}
		
		FindClose( hFind);
	}
	///////////
}

void CloseImportPlug( MADLibrary* inMADDriver)
{
	short i;
	
	for( i = 0; i < inMADDriver->TotalPlug; i++)
	{
			FreeLibrary( inMADDriver->ThePlug[ i].hLibrary);
	}
	free(inMADDriver->ThePlug); inMADDriver->ThePlug = NULL;
}

OSType GetPPPlugType( MADLibrary *inMADDriver, short ID, OSType mode)
{
	short	i, x;
	
	if( ID >= inMADDriver->TotalPlug) PPDebugStr( __LINE__, __FILE__, "PP-Plug ERROR. ");
	
	for( i = 0, x = 0; i < inMADDriver->TotalPlug; i++)
	{
		if( inMADDriver->ThePlug[ i].mode == mode || inMADDriver->ThePlug[ i].mode == 'EXIM')
		{
			if( ID == x)
			{
				short 	xx;
				OSType	type;
				
				xx = strlen( inMADDriver->ThePlug[ i].type);
				if( xx > 4) xx = 4;
				type = '    ';
				memcpy( &type, inMADDriver->ThePlug[ i].type, xx);
				PPBE32(&type);
				
				return type;
			}
			x++;
		}
	}
	
	PPDebugStr( __LINE__, __FILE__, "PP-Plug ERROR II.");
	
	return noErr;
}

