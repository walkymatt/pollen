// $Id$
// Main Dust screensaver implementation
// Matthew Caldwell, 23 July 2001
// Copyright (c) Cloak & Dagger Ltd <www.burn.demon.co.uk>

#import "Dust.h"
#import <math.h>

#define SMOOTHNESS 0.99f
#define NUM_MOTES 1500
#define SWARM_FORCE 12.0
#define FORCE_MAX 50.0
#define MIN_NON_BG_PIXELS 50

#define CONTRAST_OFF 0.0f
#define CONTRAST_ON 0.5f

#define DEFAULT_LOGO @"pollen.pict"

@implementation Dust

//---------------------------------------------------------------------------------
//  initialization
//---------------------------------------------------------------------------------

// initialize
- (id)initWithFrame:(NSRect)frameRect isPreview:(BOOL)preview
{
    // call the superclass
    self = [super initWithFrame:frameRect isPreview:preview];
    
    // initialize preferences from saved
    [self loadPrefs];
    
    // initialize OpenGL display environment
    if ( self )
    {
        // only draw in preview mode or when we are on the main screen
        if ( preview
             || !mainScreenOnly
             || ( frameRect.origin.x == 0 && frameRect.origin.y == 0 ) )
        {
            NSOpenGLPixelFormatAttribute attribs[] =
            {
                NSOpenGLPFAAccelerated,
                NSOpenGLPFADepthSize, 16,
                NSOpenGLPFAMinimumPolicy,
                NSOpenGLPFAClosestPolicy,
                0
            };
            
            NSOpenGLPixelFormat *format =
            [
                [
                    [NSOpenGLPixelFormat alloc]
                    initWithAttributes:attribs
                ]
                autorelease
            ];
            
            drawingEnabled = YES;
            
            _view =
            [
                [
                    [NSOpenGLView alloc]
                    initWithFrame:NSZeroRect pixelFormat:format
                ]
                autorelease
            ];
            [self addSubview:_view];
        
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

//---------------------------------------------------------------------------------

// initialize the vector field
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

//---------------------------------------------------------------------------------

// allocate the motes array and init its contents
- (void) allocateMotes
{
    motes = (DustMote*) malloc ( numMotes * sizeof ( DustMote ) );
    numMotesAllocated = numMotes;
}

//---------------------------------------------------------------------------------

// initialize a single mote
- (void) initMote:(int) index
{
    int logoIndex = 0;
    
    motes[index].position.x = SSRandomFloatBetween ( 0, displayWidth );
    motes[index].position.y = SSRandomFloatBetween ( 0, displayHeight );
    motes[index].previous = motes[index].position;
    motes[index].mass = SSRandomFloatBetween ( 25.0, 40.0 );
    
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
            int logoX = SSRandomIntBetween ( 0, logoWidth ) % logoWidth;
            int logoY = SSRandomIntBetween ( 0, logoHeight ) % logoHeight;
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
    
    if ( logo == nil || useLogoColours == 0 )
    {
        motes[index].colour.r = 1.0;
        motes[index].colour.g = (motes[index].mass - 20.0) / 25.0;
        motes[index].colour.b = 1.0 - motes[index].mass / 80.0;
    }
    else
    {
        motes[index].colour = logo[logoIndex];
    }
    
    motes[index].velocity.x = motes[index].velocity.y = 0.0f;
}

//---------------------------------------------------------------------------------

// adjust the frame size
- (void) setFrameSize:(NSSize)newSize
{
    int i = 0;
    
    [super setFrameSize:newSize];
    [_view setFrameSize:newSize];
    _initedGL = 0;
    
    fieldHeight = newSize.height / FIELDS_DOWN;
    fieldWidth = newSize.width / FIELDS_ACROSS;
    displayWidth = newSize.width;
    displayHeight = newSize.height;
    
    // now that we know the display size, we can initialize the motes
    for ( ; i < numMotes; ++i )
        [self initMote:i];  
        
    // set the background colour if necessary
    if ( logo != nil && useLogoColours )
        bg = *logo;
}

//---------------------------------------------------------------------------------

// initialize the OpenGL context
- (void) initGL:(int) width :(int)height
{
    glShadeModel ( GL_FLAT );
    glEnable ( GL_POINT_SMOOTH );
    glEnable ( GL_LINE_SMOOTH );
}

//---------------------------------------------------------------------------------

// load preferences
- (void) loadPrefs
{
    // load preferences object
    prefs = [ScreenSaverDefaults defaultsForModuleWithName:@"Pollen"];
    
    // load individual preferences
    numMotes = [prefs integerForKey:@"numMotes"];
    if ( numMotes <= 0 )
        numMotes = NUM_MOTES;
    
    mainScreenOnly = [prefs boolForKey:@"mainScreenOnly"];
    
    logoMode = [prefs integerForKey:@"logoMode"];
    if ( logoMode == LOGO_DEFAULT )
        logoFile = [[NSBundle bundleForClass: [Dust class]] pathForImageResource:DEFAULT_LOGO];
    else if ( logoMode == LOGO_CUSTOM )
        logoFile = [prefs stringForKey:@"logoFile"];
    else
        logoFile = nil;
    
    drawMode = [prefs integerForKey:@"drawMode"];
    useLogoColours = [prefs boolForKey:@"useLogoColours"];
    
    minimumContrast = [prefs boolForKey:@"contrastCheck"] ? CONTRAST_ON : CONTRAST_OFF;
    
    // remaining details are, after some consideration, not configurable
    smoothness = SMOOTHNESS;    
    bg.r = bg.g = bg.b = 0.0f;
    [self initPlayList];
}

//---------------------------------------------------------------------------------

// save preferences
- (void) savePrefs
{
    if ( prefs == nil )
        return;
    
    [prefs setInteger:numMotes forKey:@"numMotes"];
    [prefs setInteger:drawMode forKey:@"drawMode"];
    [prefs setInteger:logoMode forKey:@"logoMode"];
    [prefs setBool:useLogoColours forKey:@"useLogoColours"];
    [prefs setBool:mainScreenOnly forKey:@"mainScreenOnly"];
    [prefs setBool:(minimumContrast > CONTRAST_OFF) forKey:@"contrastCheck"];
    
    if ( logoMode == LOGO_CUSTOM && logoFile != nil )
        [prefs setObject:logoFile forKey:@"logoFile"];
    else
        [prefs removeObjectForKey:@"logoFile"];
    
    [prefs synchronize];
}

//---------------------------------------------------------------------------------

// initialize the playlist
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

//---------------------------------------------------------------------------------

// load the logo image
- (void) loadLogo
{
    // attempt to load the logo image file
    NSData* tiffData;
    NSBitmapImageRep* logoBits;
    
    if ( logoImageSrc != nil )
        [logoImageSrc release];
    
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
    
    // get pixel colour details from the bitmap data
    free ( logo );
    logo = [self getPixelColoursFromBitmapRep: logoBits];
    
    [logoBits release];
}

//---------------------------------------------------------------------------------

// construct an array of colour records from a bitmap representation
- (Colour3f*) getPixelColoursFromBitmapRep:(NSBitmapImageRep*)bitmap
{
    int numPixels = logoWidth * logoHeight;
    unsigned char* rawData = [bitmap bitmapData];
    int bitsPerPixel = [bitmap bitsPerPixel];
    int samplesPerPixel = [bitmap samplesPerPixel];
    int bytesPerRow = [bitmap bytesPerRow];
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

//---------------------------------------------------------------------------------
//  drawing
//---------------------------------------------------------------------------------

// prepare to run the animation
- (void) startAnimation
{
    if ( drawingEnabled )
    {
        [_view lockFocus];
        
        if ( !_initedGL )
        {
            [self initGL:(int)[self frame].size.width :(int)[self frame].size.height];
            _initedGL = YES;
        }
        
        [_view unlockFocus];
        [super startAnimation];
    }
}

//---------------------------------------------------------------------------------

// draw a single frame of animation
- (void) animateOneFrame
{
    if ( drawingEnabled )
    {
        [self checkModeChange];
        [self advanceMotes];
        [self advanceFields];
        
        [_view lockFocus];
        [self drawMotes];
        [_view unlockFocus];
    }
}

//---------------------------------------------------------------------------------

// switch between available modes from time to time
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

//---------------------------------------------------------------------------------

// adjust the positions of all motes
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
                newX += forceX / motes[i].mass;
                newY += forceY / motes[i].mass;
                
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
                newX += forceX / motes[i].mass;
                newY += forceY / motes[i].mass;
                
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
                newX += forceX / motes[i].mass;
                newY += forceY / motes[i].mass;
                
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
                newX += swirl[fieldIndex].x / motes[i].mass;
                newY += swirl[fieldIndex].y / motes[i].mass;
                
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
                newX += fields[fieldIndex].x / motes[i].mass;
                newY += fields[fieldIndex].y / motes[i].mass;
                
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

//---------------------------------------------------------------------------------

// adjust the field vectors
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

//---------------------------------------------------------------------------------

// draw all motes to the screen
- (void) drawMotes
{
    int i = 0;
    
    // clear the screen
    glClearColor ( bg.r, bg.g, bg.b, 1.0 );
    glClear ( GL_COLOR_BUFFER_BIT );
    
    // set up the view system
    glViewport ( 0, 0, displayWidth, displayHeight );
    glMatrixMode ( GL_PROJECTION );
    glLoadIdentity ();
    gluOrtho2D ( 0, displayWidth, 0, displayHeight );
    glMatrixMode ( GL_MODELVIEW );
    glLoadIdentity ();
    
    // the following offset is taken directly from the red book
    // and is intended to ensure that both polygon edges and points
    // are positioned appropriately within pixel boundaries
    glTranslatef( 0.375f, 0.375f, 0.0f );
    
    // draw tails if so requested
    if ( drawMode == DRAW_LINES )
    {
        for ( i = 0; i < numMotes; ++i )
        {
            glLineWidth ( motes[i].mass / 10 );
            glBegin ( GL_LINES );
            glColor3f ( (motes[i].colour.r + bg.r) / 2.0,
                        (motes[i].colour.g + bg.g) / 2.0,
                        (motes[i].colour.b + bg.b) / 2.0 );
            glVertex2f ( motes[i].position.x,
                         motes[i].position.y );
            glVertex2f ( motes[i].previous.x,
                         motes[i].previous.y );
            glEnd ();
        }
    }
    
    // always draw motes
    for ( i = 0; i < numMotes; ++i )
    {
        glPointSize ( motes[i].mass / 10 );
        glBegin ( GL_POINTS );
        glColor3f ( motes[i].colour.r,
                    motes[i].colour.g,
                    motes[i].colour.b );
        glVertex2f ( motes[i].position.x,
                     motes[i].position.y );
        glEnd ();
    }
    
    // that's all folks
    glFlush();
}

//---------------------------------------------------------------------------------
//  cleaning up
//---------------------------------------------------------------------------------

// dispose of allocated resources
- (void) dealloc
{
    // delete the particles array
    free ( motes );
    motes = 0;
    
    // delete the logo, if extant
    free ( logo );
    logo = 0;

    if ( logoImageSrc != nil )
    {
        [logoImageSrc release];
        logoImageSrc = nil;
    }
    
    [_view removeFromSuperview];
    [super dealloc];
}

//---------------------------------------------------------------------------------
//  configuration
//---------------------------------------------------------------------------------

// is the saver configurable?
- (BOOL) hasConfigureSheet
{
    return YES;
}

//---------------------------------------------------------------------------------

// get the configuration dialog
- (NSWindow*) configureSheet
{
    [NSBundle loadNibNamed:@"dust.nib" owner:self];
    [motesSlider setIntValue: numMotes];
    [tailsBox setIntValue: (drawMode == DRAW_LINES)];
    [coloursBox setIntValue: useLogoColours];
    [contrastBox setIntValue: (minimumContrast > CONTRAST_OFF)];
    [screensBox setIntValue: mainScreenOnly];
    [logoImage setImage:logoImageSrc];
    
    reinitMotes = NO;
    
    return window;
}

//---------------------------------------------------------------------------------

// close the configuration dialog
- (IBAction)closeSheet:(id)sender
{
    int newValue, i;
    
    // update prefs from window controls
    
    // #### only reallocate the motes if there are more -- if less,
    // #### we just use a smaller number of them
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
    
    newValue = ([coloursBox intValue] != 0);
    if ( newValue != useLogoColours )
    {
        useLogoColours = newValue;
        reinitMotes = YES;
    }
    
    newValue = ([contrastBox intValue] != 0);
    if ( newValue != (minimumContrast > CONTRAST_OFF) )
    {
        minimumContrast = newValue ? CONTRAST_ON : CONTRAST_OFF;
        reinitMotes = YES;
    }
    
    mainScreenOnly = ([screensBox intValue] != 0);
    
    drawMode = ( [tailsBox intValue] ? DRAW_LINES : DRAW_POINTS );
    
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
    if ( logo != nil && useLogoColours )
        bg = *logo;
    else
        bg.r = bg.g = bg.b = 0.0;
}

//---------------------------------------------------------------------------------

// select a picture file to use as the logo
- (IBAction)chooseLogo:(id)sender
{
    // #### bring up a file open dialog and wait
    // #### for a choice
    int result;
    NSArray* fileTypes = [NSImage imageFileTypes];
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    
    result = [panel runModalForDirectory:NSHomeDirectory() file:nil types:fileTypes];
    
    if ( result == NSOKButton )
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

//---------------------------------------------------------------------------------

// use the default POLLEN logo
- (IBAction)defaultLogo:(id)sender
{
    if ( logoMode == LOGO_DEFAULT )
    {
        // correct image already set -- do nothing
    }
    else
    {
        logoMode = LOGO_DEFAULT;
        logoFile = [[NSBundle bundleForClass: [Dust class]] pathForImageResource:DEFAULT_LOGO];
        [self loadLogo];
        [logoImage setImage:logoImageSrc];
        reinitMotes = YES;
    }
}

//---------------------------------------------------------------------------------

// don't use any logo at all
- (IBAction)noLogo:(id)sender
{
    logoMode = LOGO_NONE;
    logoFile = nil;
    [logoImageSrc release];
    logoImageSrc = nil;
    [logoImage setImage: nil];
    reinitMotes = YES;
}

//---------------------------------------------------------------------------------

@end
