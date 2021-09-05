#!/bin/bash
set -e

if [ $UID -eq 0 ]; then
	echo ">> ERROR: Please run this script as the regular user 'phablet'!"
	exit 1
fi

WORK="$HOME/.cache/unity8-notch-hax"
DEVICE="$1"

if [ -z "$DEVICE" ]; then
	echo ">> No device specified, detecting device name..."
	DEVICE="$(getprop ro.product.device)" # e.g. 'yggdrasil'
fi

if [ "$DEVICE" = "halium_arm64" ]; then
	echo ">> Detected halium_arm64 systemimage; trying alternative getprop..."
	DEVICE="$(getprop ro.product.vendor.device)" # e.g. 'OnePlus6'
fi

echo ">> Device is '$DEVICE'"

DIFF="$WORK/$DEVICE.diff"
echo ">> Using diff '$DIFF'"


if [ ! -e $DIFF ]; then
	mkdir -p $WORK
	echo ">> Fetching patches for $DEVICE..."
	if ! wget -O $DIFF https://raw.githubusercontent.com/JamiKettunen/unity8-notch-hax/main/patches/$DEVICE.diff; then
		echo "ERROR: It seems your device isn't supported by this project;
       please tune the files on your device manually first,
       then fork the repo, create a patches/$DEVICE.diff
       and modify this script to fetch the patches from your
       fork for testing!

       Alternatively, specify a device template to use with
       '$0 <device>'"
		exit 1
	fi
fi

if ! hash patch 2>/dev/null; then
	echo ">> System utility 'patch' not found, starting installation..."
	mount | grep -q ' / .*ro' && sudo mount -o remount,rw /
	sudo apt-get update
	sudo apt install -y patch
fi

echo ">> Copying system files to patch & checking compatability..."
cd $WORK
for file in $(grep '^diff' $DIFF | grep -Eo '\ b/.*' | cut -c 4-); do
	mkdir -p $(dirname $WORK/root/$file)
	cp /$file $WORK/root/$file
done

cd root/
if ! patch -p1 < $DIFF; then
	echo ">> ERROR: Some system files are incompatible with the patches;
          Please adjust '$DEVICE.diff' and try again!"
	exit 1
fi
cd ../

echo ">> Patches applied successfully! Proceeding to replacing system files..."
mount | grep -q ' / .*ro' && sudo mount -o remount,rw /
sudo cp -r root/* /
sudo mount -o remount,ro /

read -p ">> All done, would you like to restart unity8 right now (Y/n)? " ans
[[ -z "$ans" || "${ans^^}" = "Y"* ]] && \
	initctl restart unity8 || \
	echo ">> Please reboot later for the changes to take effect!"
rm -r $WORK/root/
