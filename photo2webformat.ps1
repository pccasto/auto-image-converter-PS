# powershell script to set up a pair of directories - in, out; and a size parameter

# Copyright 2020 - Paul Casto
# Released under the MIT license

<#
.SYNOPSIS
    A powershell script to automate format conversion of photos for web publishing.
.DESCRIPTION
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

.NOTES
    File Name      : photo2webformat.ps1
    Author         : Paul Casto (paul.c.casto@gmail.com)
    Prerequisite   : Windows + Powershell + imagemagick + exiftools.
    License        : MIT
    Copyright 2020 - Paul Casto
.LINK
    Original inspiration for smartresize: https://www.smashingmagazine.com/2015/06/efficient-image-resizing-with-imagemagick/

.EXAMPLE
    Not yet...

#>


### the param setting has to come first.  no code above this ---------
### set input_base, output_base, and size
# params are named for ease of command line input
# note, params cannot be configured as globals, so need additional code-block to set them as such further below


#### Command line parameters, with defaults you might want to edit vvvvvvvvvvvvvvvv--------
# you are generally safe editing these defaults

[CmdletBinding(PositionalBinding=$false,DefaultParameterSetName= 'ErrorHandling')]
param (

        [Parameter()]
        [string]$in="$HOME\documents\resize_input", 

        [Parameter()]
        [string]$out="$HOME\documents\resize_output", 

        [Parameter()]
        [int]$size=600,

        [Parameter()]
        [string]$type="*.jpg",  # note, multiple file types (e.g. *.jpg|*.png) is not supported. 

        [Parameter()]
        [string]$artist = 'Paul Casto',

        [Parameter()]
        [string]$copyright = 'Copyright 2020 - Paul Casto',

        [Parameter()]
        [switch]$v=$false ,# for verbose output
        
        # treat anthing not defined as garbage - this allows for custom message rather than default error
        # there's got to be a cleaner / more scalable way... but this hack works for the moment...
        [Parameter(Position=0)]
        $garbage,
        [Parameter(Position=1)]
        $g1,
        [Parameter(Position=2)]
        $g2,
        [Parameter(Position=3)]
        $g3,
        [Parameter(Position=4)]
        $g4,
        [Parameter(Position=5)]
        $g5,
        [Parameter(Position=6)]
        $g6
        )

# it would be very nice to throw a usage message instead of the PS default error message when parameters don't match up.
# this handles one case (hackily), but it doesn't handle the case when a -unknown parameter is used
if ($garbage) {
   Write-Warning "`nThere was extra input on the command line: $garbage $g1 $g2 $g3 $g4 $g5 $g6"
   Write-Host "`nUsage: `nphoto2webformat -in <input_dir> -out <output_dir> -size <size> -type <*.jpg> -artist <name> -copyright <copyright>`n"
   exit 1
}


#### Variables you _might_ want to edit vvvvvvvvvvvvvvvvvvv ------------------

# set paths to exectutables - one time change, so not in command line parameters
# $global:magick = 'magick.exe'      # if it is configure so it's in the path - this is the easy one
# ATTENTION if not on the path, and has spaces -- this is likely different than what you are used to, but this is how it works with powersheel
$global:magick = "C:\'Program Files'\ImageMagick-7.0.9-Q16\magick.exe"    

# $global:exiftool = 'exiftool.exe'  # if it were on the path
$global:exiftool = 'c:\Users\paul\source\repos\pccasto\exifr\exiftool.exe'  # example when it is not on the path but no spaces

# select to map user selectable exif fields from original to modified. these must be valid exif fields
$global:exif_mappings = @('datetaken')


### CAUTION if you start making changes to the command values, use a lot of caution,
#  and if you add variables you will need to modify code
#  command strings will handle spaces in the various script input/output.
# 
### resize handling with mogrify
#
# if you really want to change the handling of the conversion... do it here
# code expects 0:magick, 1:path (the input file), 2:output_dir (the adjusted output directory), 3:resize_value.
# If you want other variables, then need to change code, and add other global variables above.
$global:magick_cmd = '{0} mogrify -path "{2}" -filter Triangle -define filter:support=2 -thumbnail {3} ' +
    				' -unsharp 0.25x0.08+8.3+0.045 -dither None -posterize 136 -quality 82 -define jpeg:fancy-upsampling=off ' +
    				' -define png:compression-filter=5 -define png:compression-level=9 -define png:compression-strategy=1 ' +
    				' -define png:exclude-chunk=all -interlace none -colorspace sRGB  -auto-orient "{1}";'
# MAYBE could absract further by setting $global:magick_format, but still run into issues with delayed expansion...

### exif handing with exiftool
#
# if you want additional bits of info set within the exif of the converted file, do it here
# code expects 0:exiftool,1:out_file, 2:artist, 3:copyright
# If you want other variables, then need to change code, and add other global variables above.
$global:exiftool_cmd = '{0} -P -overwrite_original_in_place -artist="{2}" -copyright="{3}" "{1}"'


# other optiond to consider for the above commands ?
# magick mogrify -strip    --- but I think this is already accomplished
# exiftool -Orientation=0  --- but I think with the mogrify -auto-orient this is not needed.
# with some more work, certain exif attributes could be extracted from original, and applied to modified, if need



#############  - code starts here -- ^^^^^^^ User variables above this line --------


# renamed some variables, so that they make more sense when reading the code
# and these have to be global, rather than local or script, because they are used in the actions
# might be another approach, but don't see it yet...
$global:input_base = $in
$global:output_base = $out
$global:resize_value = $size
$global:file_types = $type
$global:artist = $artist
$global:copyright = $copyright
if ($v) {$global:VerbosePreference = "Continue"}


# chekc both paths (input and output) CARP if they don't exist
$dirs_exist = $true;
@($input_base, $output_base) | ForEach-Object {
    If (!(test-path $_)) {  
       Write-Warning "Path '$_' does not exist, please create it first"
       $dirs_exist = $false
       # decided auto create was too dangerous # New-Item -ItemType Directory -Force -Path $_
    }
}

if (! $dirs_exist) {exit 1}



### FIXME - add protection to ensure two instances are not running.
# BUT allow for same input dir to feed multiple outputs, using different sizes.
# so the check is only for running with identical params (in,out,type)

# could add a feature that adds the size to the filename, then fail if feature enabled and dupe (in,out,size)

### establish watcher on input folder, with configuration
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $input_base
$watcher.Filter = $file_types
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true  



### define actions after watcher detects change
# note, because of scope, variables that are not passed from watcher need to be globals
$action = { 
	$details = $Event.SourceEventArgs
	$Name = $details.Name
	$path = $details.FullPath
    $changeType = $details.ChangeType
	$timestamp = $Event.TimeGenerated

    $text = "`n'{0}' was {1} at {2}" -f $path, $changeType, $Timestamp
    Write-Host $text -ForegroundColor Green

    switch ($changeType)
    {
        'Created' { 
		    If ( Test-Path -Path $path -PathType Leaf ) {
    			$input_path = Split-Path -Path $path
                $filename = Split-Path -Leaf $path
    		    $output_dir = $input_path.Replace($input_base,$output_base)
                $out_filename = $output_dir + '\' + $filename
    
    		    # only keep going if the substitution succeeded.  AND the output_dir is a subfolder of output_base !!!
    			If ($output_dir -ne $input_path)  {
    			    If (!(test-path $output_dir)) {  New-Item -ItemType Directory -Force -Path $output_dir }
    			    try
                    {
                        $this_magick = "$magick_cmd" -f $magick, $path, $output_dir, $resize_value
                        Write-Verbose $this_magick
                        Invoke-Expression $this_magick -ErrorVariable badmagick
                        if ( $badmagick ) {
                            Write-Host  "Errors while attempting to convert '$path' into '$output_dir' :`n$badmagick"
                            return
                        }
        		        Write-Host "Converted '$path' to new file in '$output_dir'"

                        # only run exiftool if magick succeeds
                        try
                        {
                            $this_exiftool = "$exiftool_cmd" -f $exiftool, $out_filename, $artist, $copyright
                            Write-Verbose $this_exiftool
            			    Invoke-Expression $this_exiftool -ErrorVariable badexif
                            if ( $badexif ) {
                                Write-Host "Errors while attempting to add exif info :`n$badexif"
                                return
                            }
            		        Write-Host "Added exif info to '$out_filename'"
                        }
                        catch
                        {
                            Write-Host $_.Exception.Message
                        }
                    }
                    catch
                    {
                        Write-Host $_.Exception.Message
                    }
    			}
    		}
	    }

        # no need for event watcher for changed...
        'Changed' { "Changed"   # this happens twice when a file is created & then mogrified, so really don't want this to trigger actions
    	 }

         # no need for an event watcher for deleted
        'Deleted' { "DELETED"
         }

        # probably no need for an event watcher for renamed, but left in to make sure things can be tested...
        'Renamed' { 
            # this executes only when a file was renamed
            $text = "File '{0}' was renamed to '{1}'. No conversion action taken when this happens." -f $OldName, $Name
            Write-Host $text -ForegroundColor Yellow
        }

        default { Write-Host $_ -ForegroundColor Red -BackgroundColor White }
    }
}   


### DECIDE WHICH EVENTS SHOULD BE WATCHED 
# add event handlers
$handlers = . {
    #Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $Action -SourceIdentifier FSChange
    Register-ObjectEvent -InputObject $watcher -EventName Created -Action $Action -SourceIdentifier FSCreate
    #Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action $Action -SourceIdentifier FSDelete
    Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $Action -SourceIdentifier FSRename
}


### go into a non-blocking loop, while waiting for events
# provide feedback it is running, but prettier that successive dots :-)
try
{
    do # my eye candy while waiting for input
    {  # might make this a function at some point
        @(  "        Running - Press Ctrl-C to Exit`r>>>>>>> ",
            ' >>>>>> ',
            '> >>>>> ',
            '>> >>>> ',
            '>>> >>> ',
            '>>>> >> ',
            '>>>>> > ') | ForEach-Object {
            Write-Host "`r$_" -NoNewline
            Start-Sleep -Milliseconds 1000
        }    
    } while ($true)
}
# this gets executed when user presses CTRL+C, or session ends
finally  #and this is important, if the script is going to be re-run in the same session!!!
{
    # remove the event handlers
        # tried removing even if not activated... but that doesn't work - so only unregister if registered
        # could add code to check and then unregister, but for this purpose the '#' symbol works fine...
    #Unregister-Event -SourceIdentifier FSChange ## -- nope  --  this causes failure, and code below is not executed
    Unregister-Event -SourceIdentifier FSCreate
    # Unregister-Event -SourceIdentifier FSDelete  
    Unregister-Event -SourceIdentifier FSRename

    # remove background jobs
    $handlers | Remove-Job

    # remove filesystemwatcher
    $FileSystemWatcher.EnableRaisingEvents = $false
    $FileSystemWatcher.Dispose()
    "Event Handler disabled."
}

<# Code Notes and additional thanks:

This all started when I took Dave Newton's smartresize
(https://www.smashingmagazine.com/2015/06/efficient-image-resizing-with-imagemagick/),
and started adding some extra scripts around it.

And then I thought, why have to rerun a script for every file (or glob of files) I want changed...

Original source of inspiration for watcher:
https://superuser.com/questions/226828/how-to-monitor-a-folder-and-trigger-a-command-line-action-when-a-file-is-created

But since I was restarting .ps1 after editing, I wound up with multiple event handlers -- needed more robust solution.
To be fair, the link above mentioned that, but the author had simplified his solution to support one-shot programs,
since his earlier contribution seemed to cause some confusion.

That lead me to this to help clean up the mess (long-lived event handlers) I'd created by rerunning my first scripts:
https://btcstech.com/powershell/filesystemwatcher-2/
An example of cleaning up
$param = @{ Path = "c:\users\paul\documents\input";}
$objEvents = Get-EventSubscriber | ?{($_.SourceObject.Path -eq $param.Path) }
write-host $objEvents  # to see if any are still hanging around
or can be more specific by adding more params, and comparators
objEvents = Get-EventSubscriber | ?{($_.SourceObject.Path -eq $param.Path) -and ($_.SourceObject.Filter -eq $param.Filter) }
And thi
$objEvents | Unregister-Event # to get rid of them

Then finally hit the below link with some good approaches for clean exit
https://community.idera.com/database-tools/powershell/powertips/b/tips/posts/using-filesystemwatcher-correctly-part-2
Although I just had to replace the succesive '.' approach with better eye candy :-) 


Other helpful sources:
https://docs.microsoft.com/en-us/powershell/scripting/overview?view=powershell-7
https://ss64.com/ps/
https://stackoverflow.com/

https://adamtheautomator.com/

TODO:
Consider - when a folder is copied in, things work as expected, but if a folder is moved in, then the files within it are not detected.
https://docs.microsoft.com/en-us/dotnet/api/system.io.filesystemwatcher?view=netcore-3.1
But typical use case is probably files or folders being copied in...

Consider - Could... turn this into a service - but not _really_ needed.  This script can be run while doing the work, then ended.
https://docs.microsoft.com/en-us/archive/msdn-magazine/2016/may/windows-powershell-writing-windows-services-in-powershell

#>
