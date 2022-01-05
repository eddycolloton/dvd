# “dvd.sh”

### Scripts
**dvd.sh**: Bash script file which allows the user to disk image and/or extract video files from non-commercial DVDs. All of the code and functions for the dvd.sh script are contained in one file.

### Dependencies
The script relies on a number of command line applications that can be installed through homebrew:

- disktype
- ddrescue
- ffmpeg
- cowsay
- pv

All of these tools can be installed with the syntax `brew install [name of application]` 

### File Paths
The script will need to identify the device path to the DVD you intend to image. The script will output a list of attached devices (using the `diskutil list` command) and ask the user to input the target device into the command line (use tab complete to help mitigate typos). 

The script will then prompt the user for a destination for the disk image and/or extracted video files. This will likely be the TBMA DroBo staging directory, but does not need to be. 

### Permissions
The first time you run the scripts, you’ll need to change the permissions to make them executable. Locate the **dvd.sh** file in terminal, then run: 
`chmod +x dvd.sh` on the file to make it executable. 

### Running the Scripts
To run the script, navigate to the parent directory of the **dvd.sh** file using the cd command. Next, type `./dvd.sh` and the script will take it from there.  If at any point you need to quit the process, just hit `control` and `c` simultaneously.

### Variables
The scripts need to define certain locations and identifiers in order to work correctly. This will require some manual data entry. 

The metadata tool **disktype** and the **disk imaging** tool ddrescue both need to access the target DVD through the device path. This is the path that the computer uses to access the physical device, as opposed to the files on it. The script will provide you with a list of the attached devices. Input the path the to target DVD when prompted.

The other location you will need to enter manually is the path to the destination. The destination is where the disk image and/or video files will be output if/when they are created. Keep in mind that the script does not create a parent directory for the output files.

## Results
If the scripts finish successfully, there should be the following results:
- If you opt to create a disk image from the DVD:
  - A disk image of the DVD
  - A “.map” file of the disk image created by ddrescue 
  - The map file is a log of the disk imaging process
  - A text file containing a md5 checksum of the DVD
  - A text file containing the md5 checksum of the disk image
       - The script compares these two files and alerts you if there is a match or if there is a mismatch
- If you opt to extract the video from the dvd:
  - An MKV video file with the video stream from the original VOB files and, if the audio was originally encoded as ac3, the audio stream from the original VOB files as well. If the audio was encoded in PCM, then it will be re-encoded. It will still use the PCM codec but it must be re-encoded to work in a non-VOB file. 
  - Or, multiple MKV files for each DVD chapter, if so desired. 
  - If you opted to create a disk image, then the video files will be created from the disk image, instead of from the DVD (this is after and results in less wear and tear on the DVD.

