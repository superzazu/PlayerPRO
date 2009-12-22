#include <Carbon/Carbon.r>

resource 'DITL' (128) {
	{	/* array DITLarray: 8 elements */
		/* [1] */
		{10, 300, 27, 360},
		Button {
			enabled,
			"OK"
		},
		/* [2] */
		{40, 300, 57, 360},
		Button {
			enabled,
			"Cancel"
		},
		/* [3] */
		{10, 10, 26, 151},
		StaticText {
			disabled,
			"Current Sampling Rate:"
		},
		/* [4] */
		{10, 160, 26, 243},
		StaticText {
			disabled,
			""
		},
		/* [5] */
		{10, 250, 26, 282},
		StaticText {
			disabled,
			"Hz"
		},
		/* [6] */
		{40, 28, 56, 151},
		StaticText {
			disabled,
			"New Sampling Rate:"
		},
		/* [7] */
		{40, 160, 56, 243},
		EditText {
			disabled,
			""
		},
		/* [8] */
		{40, 250, 56, 282},
		StaticText {
			disabled,
			"Hz"
		}
	}
};

data 'DLGX' (128) {
	$"0843 6861 7263 6F61 6C00 0000 0000 0000"            /* .Charcoal....... */
	$"0000 0000 0000 0000 0000 0000 0000 0000"            /* ................ */
	$"0000 0000 0000 0000 0000 0000 0000 0000"            /* ................ */
	$"0000 0000 0000 0000 0000 0000 0000 0000"            /* ................ */
	$"000C 0000 0000 0000 0004 0004 0000 0000"            /* ................ */
	$"0008 0000 0000 0000 0000 0000 0000 0001"            /* ................ */
	$"0000 0000 0000 0000 0000 0006 0000 0000"            /* ................ */
	$"0000 0000 0000 0006 0000 0000 0000 0000"            /* ................ */
	$"0000 0006 0000 0000 0000 0000 0000 0006"            /* ................ */
	$"0000 0000 0000 0000 0000 0007 0000 0000"            /* ................ */
	$"0000 0000 0000 0006 0000 0000 0000 0000"            /* ................ */
	$"0000"                                               /* .. */
};

resource 'DLOG' (128) {
	{84, 134, 154, 504},
	movableDBoxProc,
	invisible,
	goAway,
	0x0,
	128,
	"Change Sampling Rate",
	centerMainScreen
};

resource 'STR#' (1000) {
	{	/* array StringArray: 1 elements */
		/* [1] */
		"Sampling Rate..."
	}
};

resource 'dctb' (128) {
	{	/* array ColorSpec: 5 elements */
		/* [1] */
		wContentColor, 56797, 56797, 56797,
		/* [2] */
		wFrameColor, 0, 0, 0,
		/* [3] */
		wTextColor, 0, 0, 0,
		/* [4] */
		wHiliteColor, 0, 0, 0,
		/* [5] */
		wTitleBarColor, 65535, 65535, 65535
	}
};

data 'ictb' (128) {
	$"0000 0000 0000 0000 0000 0000 0000 0000"            /* ................ */
	$"0000 0000 0000 0000 0000 0000 0000 0000"            /* ................ */
};

