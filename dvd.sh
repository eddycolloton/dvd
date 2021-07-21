#!/bin/bash

timestamp=$(date "+%Y-%m-%d - %H.%M.%S")

#The chapters function is used to create individual mkv video file per each chapter, intended for compilation dvds that contain multiple titles under separate chapters. The function creates an array of the two digit numbers in the VST video files (chapterNUM), which are then called in a for loop to create the chapter list array formatted to be called in a 2nd for loop to create individual video files per chapter using ffmpeg. 
function chapters {
	#chapterNUM=(` find /Volumes/"${VolumeName}" -iname "VTS*[1-9].VOB" | sed -e 's/[^0-9 ]//g' | cut -c-2 | sort -u`)
	#The above was working fine for the Sawa disk image and Amorales DVD, but did not work when I tried with an iso9660
	chapterNUM=(` find /Volumes/"${VolumeName}" -iname "VTS*[1-9].VOB" | sed 's|.*VTS_||' |  cut -c-2 | sort -u`)
	for x in "${chapterNUM[@]}"; do
		find /Volumes/"${VolumeName}" -iname "VTS_${x}_[1-9].VOB" | sort | sed -e :a -e '$!N;s/\n/|/;ta' >> VOB_names_"${timestamp}".txt
	done	
	chapterLIST=($(cat VOB_names_"${timestamp}".txt))
	COUNTER=1
	for y in "${chapterLIST[@]}"; do
		echo "The ffmpeg input will be ${y}"
		sleep 1
		cowsay -w "Starting ffmpeg..."									
		ffmpeg -fflags +genpts -i concat:$y -target "${fftarget}" -map 0:v -map 0:a? -c:v copy -c:a "${acodec}" "${Destination%/}/${VolumeName}"_chapter"$COUNTER".mkv
		let COUNTER=COUNTER+1 
	done
}

#The concat VOBs function is used to concatenate all of the VOB files (excluding the ones ending in 0)  
function concatVOBs {
	inputList=$(find /Volumes/"${VolumeName}" -iname "VTS*[1-9].VOB" | sort | sed -e :a -e '$!N;s/\n/|/;ta')
	#This is lifted from CUNY's mediamicroservices, currently on line 1063 https://github.com/mediamicroservices/mm/blob/master/mmfunctions
	echo "The ffmpeg input will be $inputList"
	sleep 1
	cowsay -w "Starting ffmpeg..."
	ffmpeg -fflags +genpts -i concat:$inputList -target "${fftarget}" -map 0:v -map 0:a? -c:v copy -c:a "${acodec}" "${Destination%/}/${VolumeName}".mkv
}

echo "Create disk image from DVD?"
select diskImage_option in "yes" "no" 
	do
		case $diskImage_option in
			yes) dvd_image=1 &&
				#creates the variable dvd_image to be referenced later to easily determine if this option was run
				diskutil list
				sleep 1 
				cowsay -p -W 31 "Input the path to the device - Should be '/dev/disk#' " 
				read -e Device
				#reads user input and assigns it to the variable $Device
				echo -e "The device path is $Device \n"
				cowsay "Input the path for the destination of the disk image"
				read -e Destination
				#reads user input and assigns it to the variable $Destination
				echo -e "The destination path is $Destination \n"
				cowsay -b "Reading disc for Volume name"
				sleep 1
				volumes=$(df | sed -En 's~.* (/Volumes/.+)$~\1~p' | sed 's|.*/Volumes/||')
				#Creates the variable $volumes with a list of mounted volumes (ignores Mac HD and time machine backups) 
				#lifted from: https://stackoverflow.com/questions/61107000/list-volumes-with-df-grep-awk-bash-shell
				#just added sed 's|.*/Volumes/||' to remove the "/Volumes/" from the output
				echo -e "The following volumes are connected \n $volumes" 
				#This echo is in here for testing, will cut eventually - it's confusing to get a long list of volumes in the middle of this process...
				echo "If necessary enter your user password to give terminal access to the disc drive"
				sleep 1
				sudo diskutil umount $Device
				VolumeName=$(echo "$volumes" | grep -i "$(sudo disktype $Device | grep -i "$(echo "${volumes}" | cut -c1-16)" | awk 'NR == 1' | awk -F '"' '{print $2}')")
				#This defines the variable #VolumeName by matching a substring in $volumes to the volume name listed in the disktype output. This will match the volume name from the user specificed device path, while only matching the volume name of the partition that mounted.
				#The disktype output is piped to grep, which then prints a line that matches the first 16 characters of any line (UDF volume names are limited to 16 characters) in the $volumes variable. awk then prints the first field of the first line that grep returns. 
				#The output from the process described in the comment above is then used to match the volume named gathered earlier in the $volume variable using "echo "$volumes" | grep -i". This is necessary because while the volume name might be limited depending ont he file system of the partition, it may be presented to the user differently.
				echo -e "The Volume name is $VolumeName \n"
				echo -e "Creating checksum of device prior to disk imaging (this could take minute)"
				md5 $Device > "${Destination}/${VolumeName}_device_md5.txt"
				#creates md5 checksum of the device. I prefer md5deep -e because it gives the user feedback of an eta, but md5deep would not work on a device path in my tests
				echo -e "Checksum of $Device complete"
				cat "${Destination}/${VolumeName}_device_md5.txt"
				sleep 1
				cowsay "Starting disk imaging with ddrescue now"
				sleep 1
				ddrescue -b 2048 -r4 -v $Device "${Destination%/}/${VolumeName}.iso" "${Destination%/}/${VolumeName}.map"
				#creates disk image assuming 2048 byte sector size
				echo -e "Creating checksum of disk image"
				md5deep -e "${Destination%/}/${VolumeName}.iso" > "${Destination%/}/${VolumeName}_diskImage_md5.txt"
				#creates md5 checksum of disk image
				cat "${Destination%/}/${VolumeName}_diskImage_md5.txt"
				checkmd5=$(diff <(awk '{print $1}' "${Destination%/}/${VolumeName}_diskImage_md5.txt") <(awk '{print $NF}' "${Destination}/${VolumeName}_device_md5.txt"))
				#diffs the md5 checksums of the device and the disk image, if there is no difference, the ouptu will be empty
				if [[ $checkmd5 -eq 0 ]]; then
					echo "Device and disk image checksums match"
				else
					echo "Device and disk image checksums do not match!"
					diff -y "${Destination}/${VolumeName}_device_md5.txt" "${Destination%/}/${VolumeName}_diskImage_md5.txt"
					#prints the diff of the two checksums
				fi  
			break;;
			no) echo "moving on..."
			break;;
			esac
	done

echo "Create concated video file from the DVD's VOB files?"
select concatVideo_option in "yes" "no" 
	do
		case $concatVideo_option in
			yes) if [[ "$dvd_image" = "1" ]]
					then 
						cowsay -d "Mounting disk image"
						hdiutil attach "${Destination%/}/${VolumeName}.iso"
						TestVOB=$(find /Volumes/"${VolumeName}" -type f -iname "*1.VOB" | awk 'FNR==1')
						framerate=$(ffprobe "${TestVOB}" 2>&1 >/dev/null | grep -i "fps" | sed 's/^.*\(,.*fps\).*$/\1/')
						codec=$(ffprobe "${TestVOB}" 2>&1 >/dev/null | grep -i "Audio" | awk 'NR == 1' | sed -e 's/.*Audio: //' -e 's/[, ].*//')
						if [[ "$framerate" = *"25"* ]]
						then
							fftarget=pal-dvd
						else
							fftarget=ntsc-dvd
						fi
					if [[ "$codec" = *"ac3"* ]]
					then 
						echo "ac3 codec found - audio will not be re-encoded"
						acodec="copy"
						sleep 1
						echo "Seperate chapters into seperate files?"
						select chapter_option in "yes" "no"
							do
								case $chapter_option in 
									yes) chapters
									break;;
									no) concatVOBs
									break;;
								esac
							done
					elif [[ "$codec" = *"pcm"* ]]; then
						echo "The audio will need to be re-encoded, using 16bit 48 kHz PCM audio"
						acodec="pcm_s16be"
						sleep 1
						echo "Seperate chapters into seperate files?"
						select chapter_option in "yes" "no"
							do
								case $chapter_option in 
									yes) chapters
									break;;
									no) concatVOBs
									break;;
								esac
							done
					else 
						TestVOB2=$(find /Volumes/"${VolumeName}" -type f -iname "*1.VOB" | awk 'FNR==2')
						codec2=$(ffprobe "${TestVOB2}" 2>&1 >/dev/null | grep -i "Audio" | awk 'NR == 1' | sed -e 's/.*Audio: //' -e 's/[, ].*//')
						if [[ "$codec2" = *"ac3"* ]]
						then 
						echo "ac3 codec found in $TestVOB2 - audio will not be re-encoded"
						acodec="copy"
						sleep 1
						echo "Seperate chapters into seperate files?"
						select chapter_option in "yes" "no"
							do
								case $chapter_option in 
									yes) chapters
									break;;
									no) concatVOBs
									break;;
								esac
							done
						else
						echo "The audio will need to be re-encoded, using 16bit 48 kHz PCM audio"
						acodec="pcm_s16be"
						#This doesn't account for DVDs with no audio, need to add something for that
						sleep 1
						echo "Seperate chapters into seperate files?"
						select chapter_option in "yes" "no"
							do
								case $chapter_option in 
									yes) chapters
									break;;
									no) concatVOBs
									break;;
								esac
							done
						fi
					fi
				else
					diskutil list
					sleep 1 
					cowsay -p -W 31 "Input the path to the device - Should be '/dev/disk#' " 
					read -e Device
					echo -e "The device path is $Device \n"
					cowsay -b "Input the path for the destination of the video file"
					read -e Destination
					echo -e "The destination path is $Destination \n"
					cowsay -g "Reading disc for Volume name"
					sleep 1
					volumes=$(df | sed -En 's~.* (/Volumes/.+)$~\1~p' | sed 's|.*/Volumes/||')
					echo -e "The following volumes are connected \n $volumes" 
					echo "If necessary enter your user password to give terminal access to the disc drive:"
					sleep 1
					sudo diskutil umount $Device
					VolumeName=$(echo "$volumes" | grep -i "$(sudo disktype $Device | grep -i "$(echo "${volumes}" | cut -c1-16)" | awk 'NR == 1' | awk -F '"' '{print $2}')") 
					echo -e "The Volume name is $VolumeName \n"
					sudo diskutil mount $Device
					TestVOB=$(find /Volumes/"${VolumeName}" -type f -iname "*1.VOB" | awk 'FNR==1')
					framerate=$(ffprobe "${TestVOB}" 2>&1 >/dev/null | grep -i "fps" | sed 's/^.*\(,.*fps\).*$/\1/')
					codec=$(ffprobe "${TestVOB}" 2>&1 >/dev/null | grep -i "Audio" | awk 'NR == 1' | sed -e 's/.*Audio: //' -e 's/[, ].*//')
					if [[ "$framerate" = *"25"* ]]
					then
						fftarget=pal-dvd
					else
						fftarget=ntsc-dvd
					fi
					if [[ "$codec" = *"ac3"* ]]
					then 
						echo "ac3 codec found - audio will not be re-encoded"
						acodec="copy"
						sleep 1
						echo "Seperate chapters into seperate files?"
						select chapter_option in "yes" "no"
							do
								case $chapter_option in 
									yes) chapters
									break;;
									no) concatVOBs
									break;;
								esac
							done
					elif [[ "$codec" = *"pcm"* ]]; then
						echo "The audio will need to be re-encoded, using 16bit 48 kHz PCM audio"
						acodec="pcm_s16be"
						sleep 1
						echo "Seperate chapters into seperate files?"
						select chapter_option in "yes" "no"
							do
								case $chapter_option in 
									yes) chapters
									break;;
									no) concatVOBs
									break;;
								esac
							done
					else 
						TestVOB2=$(find /Volumes/"${VolumeName}" -type f -iname "*1.VOB" | awk 'FNR==2')
						codec2=$(ffprobe "${TestVOB2}" 2>&1 >/dev/null | grep -i "Audio" | awk 'NR == 1' | sed -e 's/.*Audio: //' -e 's/[, ].*//')
						if [[ "$codec2" = *"ac3"* ]]
						then 
						echo "ac3 codec found in $TestVOB2 - audio will not be re-encoded"
						acodec="copy"
						sleep 1
						echo "Seperate chapters into seperate files?"
						select chapter_option in "yes" "no"
							do
								case $chapter_option in 
									yes) chapters
									break;;
									no) concatVOBs
									break;;
								esac
							done
						else
						echo "The audio will need to be re-encoded, using 16bit 48 kHz PCM audio"
						acodec="pcm_s16be"
						sleep 1
						#This doesn't account for DVDs with no audio, need to add something for that
						echo "Seperate chapters into seperate files?"
						select chapter_option in "yes" "no"
							do
								case $chapter_option in 
									yes) chapters
									break;;
									no) concatVOBs
									break;;
								esac
							done
						fi
					fi
				fi
			break;;
			no) echo "exiting now..." &&
				exit 1 ;; 
			esac
	done

