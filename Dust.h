#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>

#import "DustMote.h"

#define NUM_FIELDS	9
#define FIELDS_ACROSS	3
#define FIELDS_DOWN	3

#define MAX_PLAYLIST_SIZE	20

/* The different mode types. */
enum
{
    MODE_DEFAULT	= 0,
    MODE_SWARM		= 1,
    MODE_LOGO		= 2,
    MODE_DRIFT		= 3,
    MODE_SWIRL		= 4,
    MODE_SCATTER	= 5,
    MODE_CASCADE	= 6,
    NUM_MODES		= 7
};

/* The different drawing modes. */
enum
{
    DRAW_POINTS		= 0,
    DRAW_LINES		= 1
};

/* The different logo modes. */
enum
{
    LOGO_DEFAULT	= 0,
    LOGO_NONE		= 1,
    LOGO_CUSTOM		= 2
};

/* The different mote shapes. */
enum
{
	MOTE_SQUARE		= 0,
	MOTE_DIAMOND	= 1,
	MOTE_HEXAGON	= 2
};

/*
    Class implementing the Dust screensaver. Handles both the
    configuration and the display.
*/
@interface Dust : ScreenSaverView
{
    // display environment
    NSOpenGLView*	_view;
    BOOL		_initedGL;
    
    // modes
    int		modeFrameLimits[NUM_MODES];
    int		mode;
    
    int		playList[MAX_PLAYLIST_SIZE];
    int		playListSize;
    int		playListIndex;
    int		frameCount;
    int		frameLimit;
    
    int		drawMode;
    
    // disable all drawing except on main screen?
    BOOL	mainScreenOnly;
    BOOL	drawingEnabled;
    
    // preferences
    ScreenSaverDefaults*	prefs;
    
    // name of the logo image file
    NSString*	logoFile;
    int		logoMode;
    NSImage*	logoImageSrc;
    
    // logo pixel data (if any)
    Colour3f*	logo;
    int		logoWidth;
    int		logoHeight;
    
    // number of non-background pixels in the image
    // this must reach some arbitrary limit (say 50)
    // or else the image is rejected and the default
    // used instead
    int		numNonBGPixels;
    
    // use colours from the logo image?
    BOOL	useLogoColours;
    
    // minimum contrast required for a pixel to be
    // accepted as non-background
    float	minimumContrast;
    
    // used and actual sizes of the motes array
    int		numMotes;
    int		numMotesAllocated;
	
	// size of an individual mote
	int		moteSize;
	
	// shape of an individual mote
	int		moteShape;
	
	// are motes directional?
	BOOL	directional;
    
    // the array of motes
    DustMote*	motes;
    
    // does the motes array need reinitialization
    BOOL	reinitMotes;
    
    // the array of force vectors
    Vector2f 	fields[NUM_FIELDS];
    
    // fixed array of force vectors used in SWIRL mode
    Vector2f	swirl[NUM_FIELDS];
    
    // rotations applied to the force vectors
    Matrix2f	rotators[NUM_FIELDS];
    
    // pixel width of each field cell
    int		fieldWidth;
    
    // pixel height of each field cell
    int		fieldHeight;
    
    // pixel width of the display surface
    int		displayWidth;
    
    // pixel height of the display surface
    int		displayHeight;
    
    // colour to which the background is cleared
    Color3f	bg;
    
    // the proportion of velocity retained from frame to frame
    // (ie, 1 - coefficient of friction)
    float	smoothness;

    // controls in the configuration dialog
    IBOutlet id coloursBox;
    IBOutlet id contrastBox;
    IBOutlet id logoImage;
    IBOutlet id motesSlider;
    IBOutlet id screensBox;
	IBOutlet id sizeSlider;
	IBOutlet id tailsBox;
    IBOutlet id window;
	IBOutlet id squareButton;
	IBOutlet id diamondButton;
	IBOutlet id hexButton;
	IBOutlet id directionalButton;
}

// methods used to load and run screen saver

// initialize OpenGL context
- (void) initGL:(int)width :(int)height;

// initialize the field of vectors
- (void) initVectorField;

// initialize preferences from saved
- (void) loadPrefs;

// save preferences
- (void) savePrefs;

// initialize the playlist
- (void) initPlayList;

// load the logo image
- (void) loadLogo;

// allocate the array of motes
- (void) allocateMotes;

// initialize one mote, giving it a home position and mass
- (void) initMote:(int) index;

// switch between available display modes from time to time
- (void) checkModeChange;

// adjust the positions of all motes
- (void) advanceMotes;

// adjust the field vectors
- (void) advanceFields;

// draw all motes to the screen
- (void) drawMotes;

// get the logo pixel data in Colour3f form
- (Colour3f*) getPixelColoursFromBitmapRep:(NSBitmapImageRep*)bitmap;

// methods invoked by the configuration dialog

// select a picture file to use for the logo
- (IBAction)chooseLogo:(id)sender;

// close the configuration dialog
- (IBAction)closeSheet:(id)sender;

// use the default POLLEN logo
- (IBAction)defaultLogo:(id)sender;

// don't use any logo at all
- (IBAction)noLogo:(id)sender;

@end

static __inline__ float wrapTo (float value, float max)
{
    return ( (value < 0) ? value + max : ( (value >= max) ? (value - max) : value ) );
}

static __inline__ void wrapMote ( DustMote* mote, float xMax, float yMax )
{
    float newX = wrapTo ( mote->position.x, xMax );
    float newY = wrapTo ( mote->position.y, yMax );
    if ( newX != mote->position.x )
        mote->position.x = mote->previous.x = newX;
    
    if ( newY != mote->position.y )
        mote->position.y = mote->previous.y = newY;
}

static __inline__ float clipAbsMin ( float value, float absMin )
{
    return ( (value >= 0.0) && (value < absMin) ) ? absMin :
                (( (value <= 0.0) && (value > -absMin) ) ? -absMin : value );
}

static __inline__ float clipAbsMax ( float value, float absMax )
{
    return ( value >= absMax ) ? absMax : ( (value < -absMax) ? -absMax : value );
}

