
#
# generate initramfs of directory
# usage:
#	generate_initramfs <source_dir> <files> <destination_dir/filename>
# example:
#	generate_initramfs "./server/boot/stage32_sqfs" "./mnt/openslx.sqfs" "./server/boot/initramfs2"
#	generate_initramfs "./server/build/stage31" "." "./server/boot/initramfs"
generate_initramfs() {
	[ $# -lt 3 ] && perror "Sanity check failed: generate_initramfs needs at least three params, but $# were given."
	cd "$1" || perror "Cannot cd to '$1'"
	rm -f -- "$3"

	find $2 | cpio --format="newc" --create | xz --check=crc32 --lzma2=dict=1MiB > "$3"
	local PS=(${PIPESTATUS[*]})
	[ "x${PS[0]}" != "x0" ] && perror "'find $2' in '$(pwd)' failed."
	[ "x${PS[1]}" != "x0" ] && perror "cpio create failed."
	[ "x${PS[2]}" != "x0" ] && perror "gzip to '$3' failed."
	cd - > /dev/null
	pinfo "Created initramfs of $1 at $3"
	pinfo "Size: $(du -bsh "$3" | awk 'END {print $1}')"
}

# generates squashfs of directory
# usage:
#	generate_squashfs <source_dir> <destination_dir/filename> [ignore_root]
generate_squashfs() {
	[ $# -lt 2 ] && perror "Sanity check failed: generate_squashfs needs at least two params, but $# were given."
	[ -d "$1" ] || perror "$1 is not a directory."
	local IGNORE="${2}.ignore"
	truncate -s 0 "$IGNORE"
	if [ -n "$3" ]; then
		find "$3" -type f -o -type l | cut -c "$(( ${#3} + 2 ))-" > "$IGNORE"
	fi
	# Detect mksquashfs xz support
	local PARAMS
	if mksquashfs 2>&1 | grep -A 8 '^-comp' | grep -q '\sxz'; then
		pinfo "Using xz compression"
		PARAMS="-comp xz"
	else
		pinfo "Using default compression"
		PARAMS=""
	fi
	rm -f -- "$2" # -no-exports ?
	mksquashfs "$1" "$2" -ef "$IGNORE" $PARAMS -b 1M -no-recovery -always-use-fragments >&6 \
		|| perror "mksquashfs failed ($?)."
	pinfo "Created squashfs of $1 at $2"
	pinfo "Size: $(du -bsh "$2" | awk 'END {print $1}')"
	rm -f -- "$IGNORE"
}

