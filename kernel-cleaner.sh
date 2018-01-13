#!/bin/bash

if [[ "$(whoami)" != "root" ]]; then
	echo "Must run as root!" >&2
	exit 1
fi


debugsw=""
oldkernels="$(ls -1 /boot | egrep -o '[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-generic' | sort -Vu | head -n -2)"
kernelfiles="$(ls -1 /boot | egrep '[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-generic' | cut -d '-' -f 1 | sort | uniq)"
kernelpackages=$(dpkg -l 'linux-*' | sed '/^ii/!d;s/^[^ ]* [^ ]* \([^ :]*\).*/\1/;/[0-9]/!d')
saveversionpackages=$(echo "$kernelpackages" | sed -n 's/[^0-9]*-\([0-9.-]*\)$/\1/p' | sort -Vu | tail -2)

for kernelversion in $saveversionpackages; do
	kernelpackages=$(echo "$kernelpackages" | grep -v $kernelversion)
done

while [[ $# -gt 0 ]]; do
	case $1 in
		-d|--debug)
			debugsw="on"
			echo "Current kernel versions to save:"
			echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
			echo "$saveversionpackages"
			echo ""
			echo "Executing the following commands:"
			echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
		;;
		-h|--help)
			echo -e "Usage:\n# $0 [-d|--debug]"
			exit 0
		;;
		*)
			echo "Unknown option $1"
			echo -e "Usage:\n# $0 [-d|--debug]"
			exit 1
		;;
	esac
	shift
done

if [ "$kernelpackages" ]; then
	if [ $debugsw ]; then
		echo apt-get -y purge $kernelpackages
	else
		apt-get -y purge $kernelpackages
	fi
fi

if [ "$oldkernels" ]; then
	for kernelversion in $oldkernels; do
		if [ ! $debugsw ]; then
			echo "Cleaning out files for $kernelversion"
			echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
			for file in $kernelfiles; do
				if [ -f /boot/$file-$kernelversion ]; then
					echo "Removing /boot/$file-$kernelversion"
					rm /boot/$file-$kernelversion
				fi
			done
		else
			for file in $kernelfiles; do
				if [ -f /boot/$file-$kernelversion ]; then
					echo rm /boot/$file-$kernelversion
				fi
			done
		fi
	done
fi

if [ $debugsw ]; then
	echo update-initramfs -u
	echo update-grub
else
	update-initramfs -u
	update-grub
fi
