# Pollen screensaver
Pollen is a simple particle-based screensaver for Mac OS. A bunch of "pollen" particles are moved around by various forces, producing a variety of drifting and swarming motions. The particles can also optionally gather to form a logo or image.

This code is old and ugly. It has been very superficially updated to build with current tools (albeit with some deprecation warnings) but the bulk of it is still just a drunken hack dating back to the beginning of the century. Approach with caution.

## What's new?
Now built with Xcode 13 and tested on Monterey and Apple Silicon.

## Installation
Either build the saver with XCode or download and unzip the [pre-built version][binary]. Double-click the `Pollen.saver` file to install (or copy manually into your `Library/Screen Savers` folder).

## Logo
Pollen is set to display its own logo by default, but you can configure it to use any other suitable image through the preferences panel. It should be able to handle most image types readable by OS X. The image is used at its natural size, not scaled to the screen, so be sure to pick an image that fits nicely onscreen with some space around it. (Note that OS X will scale the image for Retina screens.)

The colour in the top-left pixel of the image is used as the background colour. By default, Pollen considers all pixels that are not this exact colour to be part of the logo. If you want it to treat a wider range of colours as background, select the "Skip pixels near background" checkbox; this will often look better, especially if you are using the image colours rather than the default colour scheme (thanks to Monroe Williams for this suggestion). There must be a reasonable number of non-background pixels in the image or the logo will not be displayed.

A logo will usually look better when represented by a larger number of motes, but that may affect performance; and it will lose definition with larger sized motes: play with these settings until you are happy, or give up and throw the thing away.

## Multiple Screens
Pollen may behave oddly with some multiple screen setups, and performance may be impaired since a separate copy is run for each screen. You may prefer to have Pollen render only to your main screen, leaving all other screens blank; hence the checkbox in the configuration dialog.

## Credits
Richard Hallas nudged me to update for Catalina. Monroe Williams suggested the Skip pixels near background behaviour. Brian Ramagli (aka Sky Hawk) at [HKA Software][hka] helped improve the drawing code.

  [pollen]: http://walkytalky.net/software/pollen/
  [binary]: https://software.walkytalky.net/pollen/pollen.zip
  [hka]: http://www.hkasoftware.com