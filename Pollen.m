//
//  Pollen.m
//  pollen
//
//  Created by Matthew Caldwell on 04/09/2009.
//  Copyright (c) 2001-2009. All rights reserved.
//

#import "Pollen.h"
#import <math.h>

#define SMOOTHNESS 0.99f
#define NUM_MOTES 1500
#define SWARM_FORCE 12.0
#define MIN_NON_BG_PIXELS 50
#define DEFAULT_MOTE_SIZE 10

#define CONTRAST_OFF 0.0f
#define CONTRAST_ON 0.5f

#define radify(x) (x)*M_PI/180.0

#define FPS 60

#define DEFAULT_LOGO @"pollen.tiff"

const Color3f LIGHT = {1.0, 0.2, 0.69};
const Color3f HEAVY = {1.0, 0.8, 0.5};

const float MIN_WEIGHT = 25.0f;
const float MAX_WEIGHT = 40.0f;
const float WEIGHT_RANGE = 15.0f;


@implementation Pollen

+ (BOOL) performGammaFade
{
	return YES;
}

#pragma mark Initialization

- (id)initWithFrame:(NSRect)frame isPreview:(BOOL)preview
{
    self = [super initWithFrame:frame isPreview:preview];
    	
    // initialize OpenGL display environment
    if ( self )
    {
		// initialize preferences from saved
		[self loadPrefs];
		
        // only draw in preview mode or when we are on the main screen
        if ( preview || !mainScreenOnly || (frame.origin.x == 0 && frame.origin.y == 0) )
        {
/*            NSOpenGLPixelFormatAttribute attribs[] =
            {
                NSOpenGLPFAAccelerated,
                NSOpenGLPFADepthSize, 16,
                NSOpenGLPFAMinimumPolicy,
                NSOpenGLPFAClosestPolicy,
                0
            };
*/
            NSOpenGLPixelFormatAttribute attribs[] =
            {
                NSOpenGLPFAAccelerated,
                NSOpenGLPFAColorSize, (NSOpenGLPixelFormatAttribute)32,
                NSOpenGLPFADoubleBuffer,
                NSOpenGLPFAMinimumPolicy,
                NSOpenGLPFADepthSize, (NSOpenGLPixelFormatAttribute)16,
                NSOpenGLPFAAllowOfflineRenderers,
                (NSOpenGLPixelFormatAttribute)0
            };
            
            NSOpenGLPixelFormat *format
				= [[NSOpenGLPixelFormat alloc] initWithAttributes:attribs];
            
            drawingEnabled = YES;
			
//			NSRect glFrame = frame;
//			glFrame.origin.x = glFrame.origin.y = 0;
            
            _view = [[NSOpenGLView alloc] initWithFrame:NSZeroRect pixelFormat:format];
            _view.wantsBestResolutionOpenGLSurface = YES;
            [self addSubview:_view];
            
            [_view.openGLContext makeCurrentContext];
            
//            NSRect newBounds = [_view convertRectToBacking:_view.bounds];
			
            self.animationTimeInterval = 1.0/FPS;

//            glClearColor(0.0, 0.0, 0.0, 1.0);
//            glClear(GL_COLOR_BUFFER_BIT);
//            glFlush();
        
            if ( logoFile != nil )
                [self loadLogo];
            
            // initialize the vector field
            [self initVectorField];
            
            // allocate all motes
            [self allocateMotes];

        }
        else
        {
            drawingEnabled = NO;
            [self setAnimationTimeInterval:-1];
        }
    }
    
    return self;
}

- (void) initVectorField
{
    int i = 0;
    for ( ; i < NUM_FIELDS; ++i )
    {
        float r = SSRandomFloatBetween ( 8.0, 12.0 );
        float theta = SSRandomFloatBetween ( 0.0, 6.29 );
        float rot = SSRandomFloatBetween ( 0.001, 0.02 );
        
        if ( ((int) (random() * 100)) % 2 )
            rot = -rot;
        
        fields[i].x = r * cos ( theta );
        fields[i].y = r * sin ( theta );
        rotators[i].x1 = cos ( rot );
        rotators[i].y1 = sin ( rot );
        rotators[i].x2 = -sin ( rot );
        rotators[i].y2 = cos ( rot );
    }
    
    swirl[0].x = 0.0f;
    swirl[0].y = 5.0f;
    swirl[1].x = -5.0f;
    swirl[1].y = 0.0f;
    swirl[2].x = -5.0f;
    swirl[2].y = -0.0f;
    swirl[3].x = 0.0f;
    swirl[3].y = 5.0f;
    swirl[4].x = 0.5f;
    swirl[4].y = 0.0f;
    swirl[5].x = 0.0f;
    swirl[5].y = -5.0f;
    swirl[6].x = 5.0f;
    swirl[6].y = 0.0f;
    swirl[7].x = 5.0f;
    swirl[7].y = 0.0f;
    swirl[8].x = 0.0f;
    swirl[8].y = -5.0f;
}

- (void) allocateMotes
{
    motes = (Mote*) malloc ( numMotes * sizeof ( Mote ) );
    numMotesAllocated = numMotes;
}

// initialize a single mote
- (void) initMote:(int) index
{
    NSInteger logoIndex = 0;
    
    motes[index].position.x = SSRandomFloatBetween ( 0, displayWidth );
    motes[index].position.y = SSRandomFloatBetween ( 0, displayHeight );
    motes[index].previous = motes[index].position;
    motes[index].mass = SSRandomFloatBetween ( MIN_WEIGHT, MAX_WEIGHT );
    
    if ( logo == nil )
    {
        motes[index].home.x = SSRandomFloatBetween ( (displayWidth - logoWidth)/2, (displayWidth + logoWidth)/2 );
        motes[index].home.y = SSRandomFloatBetween ( (displayHeight - logoHeight)/2, (displayHeight + logoHeight)/2 );
    }
    else
    {
        while ( 1 )
        {
            Colour3f* pixel;
            NSInteger logoX = SSRandomIntBetween ( 0, (int)logoWidth ) % logoWidth;
            NSInteger logoY = SSRandomIntBetween ( 0, (int)logoHeight ) % logoHeight;
            logoIndex = logoX + logoY * logoWidth;
            
            pixel = logo + logoIndex;
            if ( pixel->r != logo->r
				|| pixel->g != logo->g
				|| pixel->b != logo->b )
            {
                motes[index].home.x = logoX + (displayWidth - logoWidth)/2.0;
                
                // invert the Y position because bitmap rows are top to bottom
                // whereas OpenGL y coordinates are bottom to top
                motes[index].home.y = ((displayHeight + logoHeight)/2.0) - logoY;
                break;
            }
        }
    }
    
    if ( logo == nil || colourMode != COLOURS_IMAGE )
    {
		float massScale = (motes[index].mass - MIN_WEIGHT) / WEIGHT_RANGE;
        motes[index].colour.r = light.r + (heavy.r - light.r) * massScale;
        motes[index].colour.g = light.g + (heavy.g - light.g) * massScale;
        motes[index].colour.b = light.b + (heavy.b - light.b) * massScale;
    }
    else
    {
        motes[index].colour = logo[logoIndex];
    }
    
    motes[index].velocity.x = SSRandomFloatBetween(-5.0f, 5.0f);
	motes[index].velocity.y = SSRandomFloatBetween(-5.0f, 5.0f);
}

- (void) setFrameSize:(NSSize)newSize
{
    int i = 0;
    
    [super setFrameSize:newSize];
    
    if ( _view )
    {
        [_view setFrameSize:newSize];
        
        NSRect newBounds = _view.bounds;
        
        if (_view.wantsBestResolutionOpenGLSurface)
        {
            newBounds = [_view convertRectToBacking:_view.bounds];
        }
        
        _initedGL = 0;
    
        if ( drawingEnabled )
        {
            fieldHeight = newBounds.size.height / FIELDS_DOWN;
            fieldWidth = newBounds.size.width / FIELDS_ACROSS;
            displayWidth = newBounds.size.width;
            displayHeight = newBounds.size.height;
            
            // now that we know the display size, we can initialize the motes
            for ( ; i < numMotes; ++i )
                [self initMote:i];
            
            // set the background colour if necessary
            if ( logo != nil && colourMode == COLOURS_IMAGE )
                bg = *logo;
        }
    }
}

- (void) initGL:(int) width :(int)height
{
    glShadeModel ( GL_FLAT );
    glEnable ( GL_POINT_SMOOTH );
    glEnable ( GL_LINE_SMOOTH );
}

- (void) initPlayList
{
    playList[0] = MODE_DEFAULT;
    playList[1] = MODE_SWIRL;
    playList[2] = MODE_SWARM;
    playList[3] = MODE_LOGO;
    playList[4] = MODE_SCATTER;
    playList[5] = MODE_DRIFT;
    playList[6] = MODE_CASCADE;
    playList[7] = MODE_DEFAULT;
    playList[8] = MODE_SWIRL;
    playList[9] = MODE_SWARM;
    playList[10] = MODE_CASCADE;
    playList[11] = MODE_DEFAULT;
    playList[12] = MODE_SWARM;
    playList[13] = MODE_LOGO;
    
    playListSize = 14;
    
    modeFrameLimits[MODE_DEFAULT] = 450;
    modeFrameLimits[MODE_SWARM] = 220;
    modeFrameLimits[MODE_LOGO] = 310;
    modeFrameLimits[MODE_DRIFT] = 250;
    modeFrameLimits[MODE_SWIRL] = 280;
    modeFrameLimits[MODE_SCATTER] = 130;
    modeFrameLimits[MODE_CASCADE] = 500;
    
    frameLimit = modeFrameLimits[MODE_DEFAULT];
}

- (void) loadLogo
{
    // attempt to load the logo image file
    NSData* tiffData;
    NSBitmapImageRep* logoBits;
    
    
    logoImageSrc = [[NSImage alloc] initWithContentsOfFile:logoFile];
    
    // if the image couldn't be loaded, bail
    if ( logoImageSrc == nil )
    {
        logoWidth = 60;
        logoHeight = 100;
        return;
    }
	
    // get the image data in TIFF form
    tiffData = [logoImageSrc TIFFRepresentation];
    
    logoBits = [[NSBitmapImageRep alloc] initWithData:tiffData];
    logoWidth = [logoBits pixelsWide];
    logoHeight = [logoBits pixelsHigh];
	
	if ( [logoBits bitsPerSample] != 8
		|| [logoBits isPlanar]
		|| ([logoBits bitsPerPixel] != 24 && [logoBits bitsPerPixel] != 32)
		|| ([logoBits samplesPerPixel] != 3 && [logoBits samplesPerPixel] != 4) )
	{
		NSBitmapImageRep* newRep =
		[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
												pixelsWide:logoWidth
												pixelsHigh:logoHeight
											 bitsPerSample:8
										   samplesPerPixel:4
												  hasAlpha:YES
												  isPlanar:NO
											colorSpaceName:NSCalibratedRGBColorSpace
											   bytesPerRow:0
											  bitsPerPixel:0];
		[NSGraphicsContext saveGraphicsState];
		
		NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithBitmapImageRep:newRep];
		[NSGraphicsContext setCurrentContext:context];
		[logoBits drawInRect:NSMakeRect( 0, 0, [newRep pixelsWide], [newRep pixelsHigh] )];
		[NSGraphicsContext restoreGraphicsState];
		[newRep setSize:[logoImageSrc size]];
		logoBits = newRep;
	}
    
    // get pixel colour details from the bitmap data
    free ( logo );
    logo = [self getPixelColoursFromBitmapRep: logoBits];
}

- (Colour3f*) getPixelColoursFromBitmapRep:(NSBitmapImageRep*)bitmap
{
    NSInteger numPixels = logoWidth * logoHeight;
    unsigned char* rawData = [bitmap bitmapData];
    NSInteger bitsPerPixel = [bitmap bitsPerPixel];
    NSInteger samplesPerPixel = [bitmap samplesPerPixel];
    NSInteger bytesPerRow = [bitmap bytesPerRow];
    Colour3f* result;
    Colour3f* dest;
    float distance;
    unsigned char* src;
    int x, y;
    
    // clear the non-background pixel count to 0
    numNonBGPixels = 0;
    
    // for the moment we require bitmap data in non-planar 24 or 32 bit RGB or RGBA
    // form -- more formats may be added later ####
    if ( ([bitmap bitsPerSample] != 8)
		|| [bitmap isPlanar]
		|| (bitsPerPixel < 24)
		|| (samplesPerPixel < 3))
		return nil;
    
    result = (Colour3f*) malloc (numPixels * sizeof(Colour3f));
    
    dest = result;
    
    if ( bitsPerPixel == 32 )
    {
        for ( y = 0; y < logoHeight; ++y )
        {
            src = rawData + y * bytesPerRow;
            for ( x = 0; x < logoWidth; ++x )
            {
                dest->r = ((float) src[0])/255.0;
                dest->g = ((float) src[1])/255.0;
                dest->b = ((float) src[2])/255.0;
                
                distance = ( (dest->r - result->r) * (dest->r - result->r)
							+ (dest->g - result->r) * (dest->g - result->r)
							+ (dest->b - result->b) * (dest->b - result->b) );
                
                // check to see if it's a non-bg pixel
                if ( distance > minimumContrast )
                    ++numNonBGPixels;
                else
                {
                    dest->r = result->r;
                    dest->g = result->g;
                    dest->b = result->b;
                }
				
                ++dest;
                src += 4;
            }
        }
    }
    else if ( bitsPerPixel == 24 )
    {
        for ( y = 0; y < logoHeight; ++y )
        {
            src = rawData + y * bytesPerRow;
            for ( x = 0; x < logoWidth; ++x )
            {
                dest->r = ((float) src[0])/255.0;
                dest->g = ((float) src[1])/255.0;
                dest->b = ((float) src[2])/255.0;
                
                distance = ( (dest->r - result->r) * (dest->r - result->r)
							+ (dest->g - result->r) * (dest->g - result->r)
							+ (dest->b - result->b) * (dest->b - result->b) );
                
                // check to see if it's a non-bg pixel
                if ( distance > minimumContrast )
                    ++numNonBGPixels;
                else
                {
                    dest->r = result->r;
                    dest->g = result->g;
                    dest->b = result->b;
                }
				
                ++dest;
                src += 3;
            }
        }
    }
    
    return result;
}

#pragma mark Preferences

- (void) loadPrefs
{
	// set up the default defaults
	NSMutableDictionary* defs = [[NSMutableDictionary alloc] init];
	[defs setObject:[NSNumber numberWithInt:NUM_MOTES] forKey:@"numMotes"];
	[defs setObject:[NSNumber numberWithInt:DEFAULT_MOTE_SIZE] forKey:@"moteSize"];
	[defs setObject:[NSNumber numberWithBool:NO] forKey:@"mainScreenOnly"];
	[defs setObject:[NSNumber numberWithInt:LOGO_DEFAULT] forKey:@"logoMode"];
	[defs setObject:[NSNumber numberWithInt:DRAW_POINTS] forKey:@"drawMode"];
	[defs setObject:[NSNumber numberWithInt:COLOURS_DEFAULT] forKey:@"colourMode"];
	[defs setObject:[NSNumber numberWithBool:NO] forKey:@"contrastCheck"];
	[defs setObject:[NSNumber numberWithInt:MOTE_DIAMOND] forKey:@"moteShape"];
	[defs setObject:[NSNumber numberWithBool:YES] forKey:@"directional"];
	[defs setObject:[NSNumber numberWithFloat:0] forKey:@"bgR"];
	[defs setObject:[NSNumber numberWithFloat:0] forKey:@"bgG"];
	[defs setObject:[NSNumber numberWithFloat:0] forKey:@"bgB"];
	[defs setObject:[NSNumber numberWithFloat:LIGHT.r] forKey:@"lightR"];
	[defs setObject:[NSNumber numberWithFloat:LIGHT.g] forKey:@"lightG"];
	[defs setObject:[NSNumber numberWithFloat:LIGHT.b] forKey:@"lightB"];
	[defs setObject:[NSNumber numberWithFloat:HEAVY.r] forKey:@"heavyR"];
	[defs setObject:[NSNumber numberWithFloat:HEAVY.g] forKey:@"heavyG"];
	[defs setObject:[NSNumber numberWithFloat:HEAVY.b] forKey:@"heavyB"];
	[defs setObject:[NSNumber numberWithFloat:0.8] forKey:@"speed"];
	
    // load preferences object
    prefs = [ScreenSaverDefaults defaultsForModuleWithName:@"Pollen"];
	[prefs registerDefaults:defs];
    
    // load individual preferences
    numMotes = [prefs integerForKey:@"numMotes"];
    if ( numMotes <= 0 )
        numMotes = NUM_MOTES;
	
	moteSize = [prefs integerForKey:@"moteSize"];
	if ( moteSize <= 0 )
		moteSize = DEFAULT_MOTE_SIZE;
    
    mainScreenOnly = [prefs boolForKey:@"mainScreenOnly"];
    
    logoMode = [prefs integerForKey:@"logoMode"];
    if ( logoMode == LOGO_DEFAULT )
        logoFile = [[NSBundle bundleForClass: [Pollen class]] pathForImageResource:DEFAULT_LOGO];
    else if ( logoMode == LOGO_CUSTOM )
        logoFile = [prefs stringForKey:@"logoFile"];
    else
        logoFile = nil;
    
    drawMode = [prefs integerForKey:@"drawMode"];
    colourMode = [prefs integerForKey:@"colourMode"];
    
    minimumContrast = [prefs boolForKey:@"contrastCheck"] ? CONTRAST_ON : CONTRAST_OFF;
	
	moteShape = [prefs integerForKey:@"moteShape"];
	if ( moteShape < MOTE_SQUARE || moteShape > MOTE_HEXAGON )
	{
		moteShape = MOTE_SQUARE;
	}
	
	directional = [prefs boolForKey:@"directional"];
	
    bg.r = [prefs floatForKey:@"bgR"];
	bg.g = [prefs floatForKey:@"bgG"];
	bg.b = [prefs floatForKey:@"bgB"];
	light.r = [prefs floatForKey:@"lightR"];
	light.g = [prefs floatForKey:@"lightG"];
	light.b = [prefs floatForKey:@"lightB"];
	heavy.r = [prefs floatForKey:@"heavyR"];
	heavy.g = [prefs floatForKey:@"heavyG"];
	heavy.b = [prefs floatForKey:@"heavyB"];
	
	speed = [prefs floatForKey:@"speed"];
	
    // remaining details are, after some consideration, not configurable
    smoothness = SMOOTHNESS;    
    [self initPlayList];
}

- (void) savePrefs
{
    if ( prefs == nil )
        return;
    
    [prefs setInteger:numMotes forKey:@"numMotes"];
	[prefs setInteger:moteSize forKey:@"moteSize"];
    [prefs setBool:mainScreenOnly forKey:@"mainScreenOnly"];
    [prefs setInteger:logoMode forKey:@"logoMode"];
    [prefs setInteger:drawMode forKey:@"drawMode"];
    [prefs setInteger:colourMode forKey:@"colourMode"];
    [prefs setBool:(minimumContrast > CONTRAST_OFF) forKey:@"contrastCheck"];
	[prefs setInteger:moteShape forKey:@"moteShape"];
	[prefs setBool:directional forKey:@"directional"];
	[prefs setFloat:bg.r forKey:@"bgR"];
	[prefs setFloat:bg.g forKey:@"bgG"];
	[prefs setFloat:bg.b forKey:@"bgB"];
	[prefs setFloat:light.r forKey:@"lightR"];
	[prefs setFloat:light.g forKey:@"lightG"];
	[prefs setFloat:light.b forKey:@"lightB"];
	[prefs setFloat:heavy.r forKey:@"heavyR"];
	[prefs setFloat:heavy.g forKey:@"heavyG"];
	[prefs setFloat:heavy.b forKey:@"heavyB"];
	[prefs setFloat:speed forKey:@"speed"];

    if ( logoMode == LOGO_CUSTOM && logoFile != nil )
        [prefs setObject:logoFile forKey:@"logoFile"];
    else
        [prefs removeObjectForKey:@"logoFile"];
    
    [prefs synchronize];
}

#pragma mark Drawing

- (void)drawRect:(NSRect)rect
{
    [[NSColor blackColor] set];
    NSRectFill(rect);
}

- (void) startAnimation
{
    [super startAnimation];

    if ( drawingEnabled )
    {
        [self lockFocus];
        [[_view openGLContext] makeCurrentContext];

        if ( !_initedGL )
        {
            [self initGL:(int)displayWidth :(int)displayHeight];
            _initedGL = YES;
        }
		        
		glClearColor ( bg.r, bg.g, bg.b, 1.0 );
		glClear ( GL_COLOR_BUFFER_BIT );
		glFlush ();
        
        GLint interval = 1;
        CGLSetParameter(CGLGetCurrentContext(), kCGLCPSwapInterval, &interval);    // don't allow screen tearing
        
		[[_view openGLContext] flushBuffer];
        
        [self unlockFocus];
    }
}

- (void) animateOneFrame
{
    if ( drawingEnabled )
    {
        [self checkModeChange];
        [self advanceMotes];
        [self advanceFields];
        
        [_view lockFocus];
        [self drawMotes];
        [[_view openGLContext] flushBuffer];
        [_view unlockFocus];
    }
}

- (void) checkModeChange
{
    if ( playListSize > 1 )
    {
        ++frameCount;
        
        if ( frameCount > frameLimit )
        {
            ++playListIndex;
            if ( playListIndex >= playListSize )
                playListIndex = 0;
			
            mode = playList[playListIndex];
			
            // skip logo mode when no logo is in use
            if ( mode == MODE_LOGO && logoMode == LOGO_NONE )
            {
                ++playListIndex;
                if ( playListIndex >= playListSize )
                    playListIndex = 0;
                
                mode = playList[playListIndex];
            }
            
            frameLimit = modeFrameLimits[ mode ];
            frameCount = 0;
        }
    }
}

- (void) advanceMotes
{
    int i = 0;
    
    switch ( mode )
    {
        case MODE_CASCADE:
        case MODE_SWARM:
        {
            float centreX = displayWidth / 2.0;
            float centreY = displayHeight / 2.0;
            
            // move all motes using an attraction towards some mote
            for ( i = 0; i < numMotes; ++i )
            {
                int attractor = (mode == MODE_CASCADE) ? ~i & 1 : ( i + 1 ) % 3;
                float forceX = motes[attractor].position.x - motes[i].position.x;
                float forceY = motes[attractor].position.y - motes[i].position.y;
                float forceMag2 = forceX * forceX + forceY * forceY + 1.0f;
                float forceMag = sqrt(forceMag2) + 2.0;
				
                // apply friction to existing velocity
                float newX = motes[i].velocity.x * smoothness;
                float newY = motes[i].velocity.y * smoothness;
                
                // swarm mode also includes an attractor at centre stage
                if ( mode == MODE_SWARM )
                {
                    float force2X = centreX - motes[i].position.x;
                    float force2Y = centreY - motes[i].position.y;
                    float force2Mag2 = force2X * force2X + force2Y * force2Y + 1.0f;
                    float force2Mag = sqrt(force2Mag2) + 4.0;
                    
                    forceX = SWARM_FORCE * ( (forceX/forceMag) + (force2X/force2Mag) ) / 2.0f;
                    forceY = SWARM_FORCE * ( (forceY/forceMag) + (force2Y/force2Mag) ) / 2.0f;
                }
                else
                {
                    forceX = SWARM_FORCE * (forceX / forceMag);
                    forceY = SWARM_FORCE * (forceY / forceMag);
                }
                
                // accelerate based on mass and force
                newX += speed * forceX / motes[i].mass;
                newY += speed * forceY / motes[i].mass;
                
                // adjust position
                motes[i].previous = motes[i].position;
                motes[i].position.x += newX;
                motes[i].position.y += newY;
                motes[i].velocity.x = newX;
                motes[i].velocity.y = newY;
                
                if ( mode == MODE_CASCADE )
                    wrapMote ( motes + i, displayWidth, displayHeight );
            }
            break;
        }
			
        case MODE_LOGO:
        {
            // move all motes using an attraction towards their home
            for ( i = 0; i < numMotes; ++i )
            {
                float forceX = motes[i].home.x - motes[i].position.x;
                float forceY = motes[i].home.y - motes[i].position.y;
                float forceMag2 = forceX * forceX + forceY * forceY + 1.0f;
                float forceMag = sqrt(forceMag2) + 2.0;
				
                // apply friction to existing velocity
                float newX = motes[i].velocity.x * smoothness * smoothness * smoothness;
                float newY = motes[i].velocity.y * smoothness * smoothness * smoothness;
                
                forceX = SWARM_FORCE * (forceX / forceMag);
                forceY = SWARM_FORCE * (forceY / forceMag);
				
                // accelerate based on mass and force
                newX += speed * forceX / motes[i].mass;
                newY += speed * forceY / motes[i].mass;
                

                // adjust position
                motes[i].previous = motes[i].position;
                motes[i].position.x += newX;
                motes[i].position.y += newY;
                motes[i].velocity.x = newX;
                motes[i].velocity.y = newY;
                
                //wrapMote ( motes + i, displayWidth, displayHeight );
            }
            break;
        }
			
        case MODE_SCATTER:
        {
            // repel all motes from their home, with wrapping
            for ( i = 0; i < numMotes; ++i )
            {
                float forceX = motes[i].position.x - motes[i].home.x;
                float forceY = motes[i].position.y - motes[i].home.y;
                float forceMag2 = forceX * forceX + forceY * forceY + 1.0f;
                float forceMag = sqrt(forceMag2) + 2.0;
                
                // *don't* apply friction to existing velocity
                float newX = motes[i].velocity.x;
                float newY = motes[i].velocity.y;
                
                forceX = SWARM_FORCE * (forceX / forceMag);
                forceY = SWARM_FORCE * (forceY / forceMag);
                
                // accelerate based on mass and force
                newX += speed * forceX / motes[i].mass;
                newY += speed * forceY / motes[i].mass;

                // adjust position
                motes[i].previous = motes[i].position;
                motes[i].position.x += newX;
                motes[i].position.y += newY;
                motes[i].velocity.x = newX;
                motes[i].velocity.y = newY;
                
                wrapMote ( motes + i, displayWidth, displayHeight );
            }
            
            break;
        }
			
        case MODE_DRIFT:
            for ( ; i < numMotes; ++i )
            {
                // move with friction but no forces
                motes[i].velocity.x *= smoothness;
                motes[i].velocity.y *= smoothness;
                
                motes[i].previous = motes[i].position;
                motes[i].position.x += motes[i].velocity.x;
                motes[i].position.y += motes[i].velocity.y;
                
                wrapMote ( motes + i, displayWidth, displayHeight );
            }
            break;
            
        case MODE_SWIRL:
            for ( ; i < numMotes; ++i )
            {
                // identify the field cell containing this mote
                int fieldX = ((int) (motes[i].position.x)) / fieldWidth;
                int fieldY = ((int) (motes[i].position.y)) / fieldHeight;
                int fieldIndex = (fieldX + fieldY * FIELDS_ACROSS) % NUM_FIELDS;
                
                // apply friction to the existing velocity
                float newX = motes[i].velocity.x * smoothness;
                float newY = motes[i].velocity.y * smoothness;
                
                // accelerate based on mass and force
                newX += speed * swirl[fieldIndex].x / motes[i].mass;
                newY += speed * swirl[fieldIndex].y / motes[i].mass;

                // adjust position accordingly, wrapping around as necessary
                motes[i].previous = motes[i].position;
                motes[i].position.x += newX;
                motes[i].position.y += newY;
                motes[i].velocity.x = newX;
                motes[i].velocity.y = newY;
                
                wrapMote ( motes + i, displayWidth, displayHeight );
            }
            break;
            
        default:
            for ( ; i < numMotes; ++i )
            {
                // identify the field cell containing this mote
                int fieldX = ((int) (motes[i].position.x)) / fieldWidth;
                int fieldY = ((int) (motes[i].position.y)) / fieldHeight;
                int fieldIndex = (fieldX + fieldY * FIELDS_ACROSS) % NUM_FIELDS;
                
                // apply friction to the existing velocity
                float newX = motes[i].velocity.x * smoothness;
                float newY = motes[i].velocity.y * smoothness;
                
                // accelerate based on mass and force
                newX += speed * fields[fieldIndex].x / motes[i].mass;
                newY += speed * fields[fieldIndex].y / motes[i].mass;
				
                // adjust position accordingly, wrapping around as necessary
                motes[i].previous = motes[i].position;
                motes[i].position.x += newX;
                motes[i].position.y += newY;
                motes[i].velocity.x = newX;
                motes[i].velocity.y = newY;
                
                wrapMote ( motes + i, displayWidth, displayHeight );
            }
    }
}

- (void) advanceFields
{
    // the fields are rotated by matrix multiplication
    // note that the cumulative effect of float precision
    // errors may eventually cause the field vectors to
    // lose magnitude until everything becomes static
    // -- I'll cross that bridge when I come to it!
    int i = 0;
    for ( ; i < NUM_FIELDS; ++i )
    {
        float x = rotators[i].x1 * fields[i].x + rotators[i].y1 * fields[i].y;
        float y = rotators[i].x2 * fields[i].x + rotators[i].y2 * fields[i].y;
        fields[i].x = x;
        fields[i].y = y;
    }
}

- (void) drawMotes
{
    int i = 0;
	
    // clear the screen
    glClearColor ( bg.r, bg.g, bg.b, 1.0 );
    glClear ( GL_COLOR_BUFFER_BIT );
    
    // set up the view system
    glViewport ( 0, 0, (int)displayWidth, (int)displayHeight );
    glMatrixMode ( GL_PROJECTION );
    glLoadIdentity ();
    gluOrtho2D ( 0, displayWidth, 0, displayHeight );
    glMatrixMode ( GL_MODELVIEW );
    glLoadIdentity ();
    
    // the following offset is taken directly from the red book
    // and is intended to ensure that both polygon edges and points
    // are positioned appropriately within pixel boundaries
    glTranslatef( 0.375f, 0.375f, 0.0f );
    
    // draw tails if so requested and motesize makes it worth bothering
	// changed methods to send stuff in larger batches
    if ( drawMode == DRAW_LINES && moteSize > 5 )
    {
		glBegin ( GL_LINES );
        for ( i = 0; i < numMotes; ++i )
        {
            glLineWidth ( motes[i].mass / 10.0f );
            
            glColor3f ( (motes[i].colour.r + bg.r) / 2.0f,
					   (motes[i].colour.g + bg.g) / 2.0f,
					   (motes[i].colour.b + bg.b) / 2.0f );
            glVertex2f ( motes[i].position.x,
						motes[i].position.y );
            glVertex2f ( motes[i].previous.x,
						motes[i].previous.y );
            
        }
		glEnd ();
    }
    
    // always draw motes	
	glBegin ( GL_QUADS);
	switch ( moteShape )
	{
		case MOTE_SQUARE:
		{
			if ( directional )
			{
				for ( i = 0; i < numMotes; ++i )
				{
					float v2 = motes[i].velocity.x * motes[i].velocity.x + motes[i].velocity.y * motes[i].velocity.y;
					float modv = sqrt(v2);
					float mvx = (motes[i].velocity.x * motes[i].mass) / (modv * moteSize);
					float mvy = (motes[i].velocity.y * motes[i].mass) / (modv * moteSize);
					
					glColor3f ( motes[i].colour.r,
							   motes[i].colour.g,
							   motes[i].colour.b );
					glVertex2f ( motes[i].position.x + mvx,  motes[i].position.y + mvy );
					glVertex2f ( motes[i].position.x + mvy, motes[i].position.y - mvx );
					glVertex2f ( motes[i].position.x - mvx,  motes[i].position.y - mvy );
					glVertex2f ( motes[i].position.x - mvy, motes[i].position.y + mvx );
				}
			}
			else
			{
				// non-directional squares are aligned to screen -- adjust scaling
				// accordingly
				float scale = 1.0f / (moteSize * 1.414f);
				for ( i = 0; i < numMotes; ++i )
				{
					float mvx = motes[i].mass * scale;
					
					glColor3f ( motes[i].colour.r,
							   motes[i].colour.g,
							   motes[i].colour.b );
					glVertex2f ( motes[i].position.x + mvx,  motes[i].position.y + mvx );
					glVertex2f ( motes[i].position.x - mvx, motes[i].position.y + mvx );
					glVertex2f ( motes[i].position.x - mvx,  motes[i].position.y - mvx );
					glVertex2f ( motes[i].position.x + mvx, motes[i].position.y - mvx );
				}		
			}
			break;
		}
			
		case MOTE_DIAMOND:
		{
			if ( directional )
			{
				for ( i = 0; i < numMotes; ++i )
				{
					float v2 = motes[i].velocity.x * motes[i].velocity.x + motes[i].velocity.y * motes[i].velocity.y;
					float modv = sqrt(v2);
					float mvx = (motes[i].velocity.x * motes[i].mass) / (modv * moteSize);
					float mvy = (motes[i].velocity.y * motes[i].mass) / (modv * moteSize);
					float mvx2 = mvx/1.5f;
					float mvy2 = mvy/1.5f;
					
					glColor3f ( motes[i].colour.r,
							   motes[i].colour.g,
							   motes[i].colour.b );
					glVertex2f ( motes[i].position.x + mvx,  motes[i].position.y + mvy );
					glVertex2f ( motes[i].position.x + mvy2, motes[i].position.y - mvx2 );
					glVertex2f ( motes[i].position.x - mvx,  motes[i].position.y - mvy );
					glVertex2f ( motes[i].position.x - mvy2, motes[i].position.y + mvx2 );
				}
			}
			else
			{
				for ( i = 0; i < numMotes; ++i )
				{
					float mvx = motes[i].mass / moteSize;
					float mvy = mvx/1.5f;
					
					glColor3f ( motes[i].colour.r,
							   motes[i].colour.g,
							   motes[i].colour.b );
					glVertex2f ( motes[i].position.x + mvx,  motes[i].position.y );
					glVertex2f ( motes[i].position.x, motes[i].position.y + mvy );
					glVertex2f ( motes[i].position.x - mvx,  motes[i].position.y );
					glVertex2f ( motes[i].position.x, motes[i].position.y - mvy );
				}		
			}
			break;
		}
			
		case MOTE_HEXAGON:
		{
			if ( directional )
			{
				for ( i = 0; i < numMotes; ++i )
				{
					float v2 = motes[i].velocity.x * motes[i].velocity.x + motes[i].velocity.y * motes[i].velocity.y;
					float modv = sqrt(v2);
					float mvx = (motes[i].velocity.x * motes[i].mass) / (modv * moteSize);
					float mvy = (motes[i].velocity.y * motes[i].mass) / (modv * moteSize);
					float mvx1 = mvx * 0.5f;
					float mvx2 = mvx * 0.866f;
					float mvy1 = mvy * 0.5f;
					float mvy2 = mvy * 0.866f;
					
					glColor3f ( motes[i].colour.r,
							   motes[i].colour.g,
							   motes[i].colour.b );
					glVertex2f ( motes[i].position.x + mvx, motes[i].position.y + mvy );
					glVertex2f ( motes[i].position.x + mvx1 - mvy2, motes[i].position.y + mvy1 + mvx2 );
					glVertex2f ( motes[i].position.x - mvx1 - mvy2, motes[i].position.y - mvy1 + mvx2 );
					glVertex2f ( motes[i].position.x - mvx, motes[i].position.y - mvy );
					
					glVertex2f ( motes[i].position.x + mvx, motes[i].position.y + mvy );
					glVertex2f ( motes[i].position.x - mvx, motes[i].position.y - mvy );
					glVertex2f ( motes[i].position.x - mvx1 + mvy2, motes[i].position.y - mvy1 - mvx2 );
					glVertex2f ( motes[i].position.x + mvx1 + mvy2, motes[i].position.y + mvy1 - mvx2 );
					
				}
			}
			else
			{
				float scale1 = 1.0f / moteSize;
				float scalex = 0.866f * scale1;
				float scaley = 0.5f * scale1;
				
				for ( i = 0; i < numMotes; ++i )
				{
					float mv1 = motes[i].mass * scale1;
					float mvx = motes[i].mass * scalex;
					float mvy = motes[i].mass * scaley;
					
					glColor3f ( motes[i].colour.r,
							   motes[i].colour.g,
							   motes[i].colour.b );
					
					glVertex2f ( motes[i].position.x,  motes[i].position.y + mv1 );
					glVertex2f ( motes[i].position.x - mvx, motes[i].position.y + mvy );
					glVertex2f ( motes[i].position.x - mvx, motes[i].position.y - mvy );
					glVertex2f ( motes[i].position.x,  motes[i].position.y - mv1 );
					
					glVertex2f ( motes[i].position.x,  motes[i].position.y + mv1 );
					glVertex2f ( motes[i].position.x,  motes[i].position.y - mv1 );
					glVertex2f ( motes[i].position.x + mvx, motes[i].position.y - mvy );
					glVertex2f ( motes[i].position.x + mvx, motes[i].position.y + mvy );
				}		
			}
			break;
		}
	}
	glEnd ();
    
	// that's all folks
    glFlush();
}

#pragma mark Configuration

- (BOOL)hasConfigureSheet
{
    return YES;
}

- (NSWindow*) configureSheet
{
    [NSBundle loadNibNamed:@"Pollen.nib" owner:self];
    [motesSlider setIntValue: (int)numMotes];
    [tailsBox setIntValue: (drawMode == DRAW_LINES)];
	[defaultColours setState: (colourMode == COLOURS_DEFAULT) ? NSOnState : NSOffState];
	[customColours setState: (colourMode == COLOURS_CUSTOM) ? NSOnState : NSOffState];
	[imageColours setState: (colourMode == COLOURS_IMAGE) ? NSOnState : NSOffState];
    [contrastBox setIntValue: (minimumContrast > CONTRAST_OFF)];
    [screensBox setIntValue: mainScreenOnly];
    [logoImage setImage:logoImageSrc];
	[sizeSlider setIntValue: (int)(moteSize > 19 ? DEFAULT_MOTE_SIZE : (moteSize < 1 ? DEFAULT_MOTE_SIZE : (20 - moteSize)))];
	[directionalButton setIntValue: directional];
	
	[squareButton setIntValue: (moteShape == MOTE_SQUARE)];
	[diamondButton setIntValue: (moteShape == MOTE_DIAMOND)];
	[hexButton setIntValue: (moteShape == MOTE_HEXAGON)];
	
	[bgWell setColor:[NSColor colorWithDeviceRed:bg.r green:bg.g blue:bg.b alpha:1.0]];
	[lightWell setColor:[NSColor colorWithDeviceRed:light.r green:light.g blue:light.b alpha:1.0]];
	[heavyWell setColor:[NSColor colorWithDeviceRed:heavy.r green:heavy.g blue:heavy.b alpha:1.0]];
    
	[bgWell setEnabled:(colourMode == COLOURS_CUSTOM)];
	[lightWell setEnabled:(colourMode == COLOURS_CUSTOM)];
	[heavyWell setEnabled:(colourMode == COLOURS_CUSTOM)];
	[bgLabel setTextColor:(colourMode == COLOURS_CUSTOM) ? [NSColor controlTextColor] : [NSColor disabledControlTextColor]];
	[motesLabel setTextColor:(colourMode == COLOURS_CUSTOM) ? [NSColor controlTextColor] : [NSColor disabledControlTextColor]];
	
	[speedSlider setFloatValue:speed];

    reinitMotes = NO;
    return window;
}

- (IBAction)closeSheet:(id)sender
{
    int newValue, i;
    
    // update prefs from window controls
    
    newValue = [motesSlider intValue];
    
    if (newValue > numMotesAllocated)
    {
        // free the motes
        free (motes);
        
        numMotes = newValue;
        
        // reallocate
        [self allocateMotes];
        
        // flag to reinitialize all the motes before drawing
        reinitMotes = YES;
    }
    else if ( newValue > numMotes )
    {
        // must reinit because the upper range of motes may
        // not have been inited with the current image
        numMotes = newValue;
        reinitMotes = YES;
    }
    else
    {
        numMotes = newValue;
    }
    
    newValue = ([contrastBox intValue] != 0);
    if ( newValue != (minimumContrast > CONTRAST_OFF) )
    {
        minimumContrast = newValue ? CONTRAST_ON : CONTRAST_OFF;
        reinitMotes = YES;
    }
    
    mainScreenOnly = ([screensBox intValue] != 0);
    
    drawMode = ( [tailsBox intValue] ? DRAW_LINES : DRAW_POINTS );
	
	newValue = [sizeSlider intValue];
	
	moteSize = newValue > 19 ? DEFAULT_MOTE_SIZE : (newValue < 1 ? DEFAULT_MOTE_SIZE : 20 - newValue );
	
	directional = ([directionalButton intValue] != 0);
	
	if ( [squareButton intValue] )
		moteShape = MOTE_SQUARE;
	else if ( [diamondButton intValue] )
		moteShape = MOTE_DIAMOND;
	else
		moteShape = MOTE_HEXAGON;
	
	speed = [speedSlider floatValue];
    
    // close the window
    [NSApp endSheet:window];
    
    // save revised prefs
    [self savePrefs];
    
    if ( reinitMotes )
    {
        for ( i = 0; i < numMotes; ++i )
            [self initMote:i];
    }
    
    // set the background colour if necessary
    if ( logo != nil && colourMode == COLOURS_IMAGE )
        bg = *logo;
}

- (IBAction)chooseLogo:(id)sender
{
    NSInteger result;
    NSArray* fileTypes = [NSImage imageFileTypes];
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    
    result = [panel runModalForDirectory:NSHomeDirectory() file:nil types:fileTypes];
    
    if ( result == NSModalResponseOK )
    {
        logoFile = [[panel filename] copyWithZone:nil];
		
        // set the resulting image file as the preferred logo
        [self loadLogo];
        
        // check that there are a minimum number of non background pixels
        // in the selected image
        if ( numNonBGPixels < MIN_NON_BG_PIXELS )
        {
            logoMode = LOGO_CUSTOM;
            [self defaultLogo:nil];
        }
        else
        {
            if ( logoImageSrc != nil )
            {
                logoMode = LOGO_CUSTOM;
                [logoImage setImage:logoImageSrc];
                
                reinitMotes = YES;
            }
        }
    }
}

- (IBAction)defaultLogo:(id)sender
{
    if ( logoMode == LOGO_DEFAULT )
    {
        // correct image already set -- do nothing
    }
    else
    {
        logoMode = LOGO_DEFAULT;
        logoFile = [[NSBundle bundleForClass: [Pollen class]] pathForImageResource:DEFAULT_LOGO];
        [self loadLogo];
        [logoImage setImage:logoImageSrc];
        reinitMotes = YES;
    }
}

- (IBAction)noLogo:(id)sender
{
    logoMode = LOGO_NONE;
    logoFile = nil;
    logoImageSrc = nil;
    [logoImage setImage: nil];
    reinitMotes = YES;
}

// set colours
- (IBAction)setColourMode:(id)sender
{
	if ( sender == defaultColours )
	{
		colourMode = COLOURS_DEFAULT;
		bg.r = bg.g = bg.b = 0.0f;
		light = LIGHT;
		heavy = HEAVY;
		
		[defaultColours setState:NSOnState];
		[customColours setState:NSOffState];
		[imageColours setState:NSOffState];

		[heavyWell setEnabled:NO];
		[lightWell setEnabled:NO];
		[bgWell setEnabled:NO];
		[bgLabel setTextColor:[NSColor disabledControlTextColor]];
		[motesLabel setTextColor:[NSColor disabledControlTextColor]];
		
		reinitMotes = YES;
	}
	else if ( sender == customColours )
	{
		colourMode = COLOURS_CUSTOM;
		[self setBg:nil];
		[self setHeavy:nil];
		[self setLight:nil];
		
		[defaultColours setState:NSOffState];
		[customColours setState:NSOnState];
		[imageColours setState:NSOffState];
		
		[heavyWell setEnabled:YES];
		[lightWell setEnabled:YES];
		[bgWell setEnabled:YES];
		[bgLabel setTextColor:[NSColor controlTextColor]];
		[motesLabel setTextColor:[NSColor controlTextColor]];
		
		reinitMotes = YES;
	}
	else if ( sender == imageColours )
	{
		colourMode = COLOURS_IMAGE;
		
		[defaultColours setState:NSOffState];
		[customColours setState:NSOffState];
		[imageColours setState:NSOnState];

		[heavyWell setEnabled:NO];
		[lightWell setEnabled:NO];
		[bgWell setEnabled:NO];
		[bgLabel setTextColor:[NSColor disabledControlTextColor]];
		[motesLabel setTextColor:[NSColor disabledControlTextColor]];
				
		reinitMotes = YES;
	}
}

- (IBAction)setHeavy:(id)sender
{
	NSColor* col = [[heavyWell color] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	if ( col )
	{
		heavy.r = [col redComponent];
		heavy.g = [col greenComponent];
		heavy.b = [col blueComponent];
		
		reinitMotes = YES;
	}
}

- (IBAction)setLight:(id)sender
{
	NSColor* col = [[lightWell color] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	if ( col )
	{
		light.r = [col redComponent];
		light.g = [col greenComponent];
		light.b = [col blueComponent];
		
		reinitMotes = YES;
	}
}

- (IBAction)setBg:(id)sender
{
	NSColor* col = [[bgWell color] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	if ( col )
	{
		bg.r = [col redComponent];
		bg.g = [col greenComponent];
		bg.b = [col blueComponent];
		
		reinitMotes = YES;
	}
}

@end
