# photo2webformat.ps1

# SYNOPSIS
    A powershell script to automate format conversion of photos for web publishing when dropped into an input folder.
 # DESCRIPTION
    When launched, the script monitors one directory for incoming files (or folders of files) that match the defined extension
    (by default *.jpg). When a new file is created with that folder, it triggers an action to modify the image
    and save it into a designated output directory.

    The result is the creation of a file (of the same name) in that output directory that has been scaled down in size, 
    to a user specified pixel size, and reduced in resolution to make the filesize much smaller.

    This program is built on the shoulders of giants (imagemagick and exiftoot). The key operation was based on a concept 
    in an article by Dave Newton (https://www.smashingmagazine.com/2015/06/efficient-image-resizing-with-imagemagick/), 
    and then built up with some refinements and other steps. Several of the concepts for the coding were drawn sources 
    throughout the web, and notable ones have been listed within the code.

    It requires the installation of two extremely powerful image processing and manipulation programs, and barely scratches the 
    surface of their capabilities. This program merely takes advantage of some very useful subsets of their capabilities, 
    and automates the actions for an activity that could require a number of steps.

    Those two programs must be installed first, and need to be added to the PATH, or variables within this script need to be 
    edited to contain the full path to the executable.
    - https://imagemagick.org/script/download.php
    - https://exiftool.org/  (use the standalone version)

    There are some other variables at the top of the program that can be edited to set defaults based on user preferences.
    (Sure, those could be in a separate configuration file... but not yet...)

    When the program is run, it starts a process watching for file changes in the input directory. When a new file (or folder) is added
    to that directory, the program runs the `magick mogrify` command, with paramaters that have been carefully tuned to produce 
    `reasonable` web images and outputs that changed file into a designated output directory. Then the program calls the exiftool
    to assign author and copyright information, and any other configured exif metadata into the exif of the changed file.

    Files can be added to the input directory by copying them in, moving them in, or via drag&drop. 
    To make things really convenient open the input folder using windows explorer and go to shell:sendto.  
    Right-click, and select 'New > Shortcut'.  Browse to the folder that is set up as the input folder, and create the short cut.
    With this you can now right-click an image and then SendTo > your_input_folder.
    That action copies the image into the folder, and with this program running in the background all other actions are triggered.

    You can run this program on one or more input folders, with different paramaters.  For example one folder might be for web-design,
    and another to format at a different size for blog posts.  If you do this, you can repeat the steps above to create multiple 
    'SendTo' targets.

    If a folder is copied in (as a subfolder to the top level being watched) with matching files, then the files will be 
    modified into the corresponding subfolder in the output directory. If a file is copied or moved into a subfolder to the
    input directory, it will be modified into the corresponding subfolder in the output directory.

    NOTE: If a folder is *moved* into the input directory, rather than *copied*, no action will be taken.  If this handling is 
    needed, it may be possible to add, but that is not a current feature.

# NOTES
    File Name      : photo2webformat.ps1
    Author         : Paul Casto (paul.c.casto@gmail.com)
    Prerequisite   : Windows + Powershell + imagemagick + exiftools.
    License        : MIT
    Copyright 2020 - Paul Casto
# LINK
    Original inspiration for smartresize: https://www.smashingmagazine.com/2015/06/efficient-image-resizing-with-imagemagick/

# EXAMPLE
    Not yet...
