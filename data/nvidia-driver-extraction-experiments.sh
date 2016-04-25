#!/bin/bash

# This is the first working nvidia extractor.

BASEDIR=/root/temp/
TMSCRIPTS=/root/tm-scripts/
MODULE_DIR="$TMSCRIPTS/remote/modules/kernel/"
KERNELSRCDIR="$MODULE_DIR/ksrc"
ROOTLOWERDIR="/"
ROOTUPPERDIR="$BASEDIR/rootupper"
ROOTBINDDIR="$BASEDIR/rootbind"
ROOTMOUNTDIR="$BASEDIR/rootmount"
BINDMOUNTS="/dev /proc /run /sys"

NVIDIA="$BASEDIR/NVIDIA-Linux-x86_64-331.38.run"
NVIDIAEXTRACTDIR="$ROOTMOUNTDIR/NVIDIA"
NVEXTRACTDIR="/NVIDIA"					# this one relative to chroot"
STARTDM="false"


# This is just an experiment to look whether the annoying message "could not insert kernel module"
# by the nvidia installer when compiling on a computer lacking a nvidia gpu card could be killed.
# It does not work, as the nvidia-installer uses a self-brewed module loader.
dump_modprobe () {
	[ -d "$ROOTMOUNTDIR/sbin" ] || mkdir "$ROOTMOUNTDIR/sbin"
	for FILE in insmod modprobe; do
		cat>"$ROOTMOUNTDIR/sbin/$FILE"<<-EOF
		#/bin/sh
		exit 0
		EOF
		chmod +x "$ROOTMOUNTDIR/sbin/$FILE"
	done
}

stop_display_managers () {
	for DM in kdm gdm lightdm; do
		ps a|grep -v grep|grep "$DM"
		ERR=$?
		if [ "$ERR" -eq 0 ]; then
			/etc/init.d/"$DM" stop
			killall "$DM"			# line above leaves a residue sometimes...
			STARTDM="$DM"
			echo "Stopped $DM."
			break
		fi
	done
}

# Several directories for bind mount and overlay mounts.
make_dirs () {
	mkdir "$ROOTUPPERDIR"
	mkdir "$ROOTBINDDIR"
	mkdir "$ROOTMOUNTDIR"
}

mount_dirs () {
	mount -o bind "$ROOTLOWERDIR" "$ROOTBINDDIR"
	mount -o remount,ro "$ROOTBINDDIR"
	mount -t overlayfs overlayfs -o lowerdir="$ROOTBINDDIR",upperdir="$ROOTUPPERDIR" "$ROOTMOUNTDIR"
	for MOUNT in $BINDMOUNTS; do
		echo "Erzeuge bind-mount $MOUNT ..."
		mount -o bind "$MOUNT" "$ROOTMOUNTDIR/$MOUNT"      || echo "Bind mount auf $MOUNT schlug fehl."
	done
}

# We inject a bashrc to be executed within the chroot.
gen_bashrc () {
	echo "chroot erfolgreich."
	COMMON_OPTIONS=' --no-nouveau-check --no-network --no-backup --no-rpms --no-runlevel-check --no-distro-scripts --no-cc-version-check --no-x-check --no-precompiled-interface --silent '
	cat >"$ROOTMOUNTDIR/$HOME/.bashrc"<<-EOF
	alias ll='ls -alF'
	PS1='\[\e[1;33m\]chroot@\h:\w\$ \[\e[1;32m\]'
	cd "$NVEXTRACTDIR"
	echo "First pass... compiling kernel module."
	./nvidia-installer $COMMON_OPTIONS --kernel-source-path /"$KERNELSRCDIR"		# compiles .ko, but not always the rest.
	echo "Second pass... compiling everything else."
	./nvidia-installer $COMMON_OPTIONS --no-kernel-module  					# compiles the rest - hopefully.
	exit
EOF
}

unpack_nvidia () {
	[ -d "$NVIDIAEXTRACTDIR" ] && rm -rf "$NVIDIAEXTRACTDIR"
	echo "Entpacke $NVIDIA ..."
	sh "$NVIDIA" --extract-only --target "$NVIDIAEXTRACTDIR"
}

umount_dirs () {
	for MOUNT in $BINDMOUNTS; do
		umount "$ROOTMOUNTDIR/$MOUNT"
	done
	umount "$ROOTMOUNTDIR"
	umount "$ROOTBINDDIR"
}

start_display_manager () {
	[ "$STARTDM" != "false" ] && echo /etc/init.d/"$DM" start
}


# stop_display_managers

make_dirs
echo "Mounte Verzeichnisse ..."
mount_dirs

echo "Lege .bashrc ab ..."
gen_bashrc

echo "Entpacke NVidia-Installer ..."
unpack_nvidia

echo "Dumpe modprobe / insmod ..."
# dump_modprobe

echo "Fertig für chroot."
chroot "$ROOTMOUNTDIR"
echo "chroot durch."

echo "Unmounte Verzeichnisse."
umount_dirs

# start_display_manager
