
/* Tools.c */
void DoHelpTools(short **, short *);
pascal OSErr MyTrackingTools(short, WindowPtr, void *, DragReference);
pascal OSErr MyReceiveTools(WindowPtr, void*, DragReference);
void DrawTimeBar(void);
void DoNullTools(void);
void UpdateToolsWindow(DialogPtr);
void CreateToolsDlog(void);
void CloseToolsWindow(void);
void DoRecule(void);
void DoPause(void);
void DoStop(void);
void DoSearchUp(void);
void DoSearchDown(void);
void SetCurrentMOD(Str255);
void DoRemember(void);
void DoPlay(void);
pascal void myBackAction(ControlHandle, short);
pascal void myForeAction(ControlHandle, short);
void ScanTime(void);
void DoItemPressTools(short, DialogPtr);
