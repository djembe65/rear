#
# create swap files and partitions
#

# Only run this if not in layout mode.
if [ -n "$USE_LAYOUT" ] ; then
    return 0
fi

LogPrint "Creating swap files and partitions"

# most backup software will ignore swap files
# so we (re-)create them here and initialize them properly
if test -s $VAR_DIR/recovery/swapfiles ; then
	while read file megs junk ; do
		realfile=/mnt/local$file
		Log "Creating swap file '$realfile' ($megs MB)"
		dd if=/dev/zero of=$realfile bs=1M count=$megs >&2
		StopIfError "Failed to create swap file '$file' ($megs MB)"
		chmod 0600 $realfile
	done <$VAR_DIR/recovery/swapfiles
fi


while read file ; do
	# file looks like dev/md/0/swap_vol_id or media/hdd2/swapfile/swap_vol_id

	# if it is a device file (starts from /dev), then use the /dev entries of the rescue system.
	if test "${file:0:3}" = "dev" ; then
		device="/${file%%/swap_vol_id}" # /dev/md/0
	else
		# otherwise use /mnt/local for swap files
		device="/mnt/local/${file%%/swap_vol_id}" # /mnt/local/media/hdd2/swapfile
	fi

	[ -s "$VAR_DIR/recovery/$file" ]
	StopIfError "Description file '$VAR_DIR/recovery/$file' is empty."

	# source information from vol_id file
	. $VAR_DIR/recovery/$file
	# This should set stuff like this:
	# ID_FS_USAGE=other
	# ID_FS_TYPE=swap
	# ID_FS_VERSION=2
	# ID_FS_UUID=
	# ID_FS_LABEL=hdd2
	# ID_FS_LABEL_SAFE=hdd2

	[ "$ID_FS_TYPE" == swap ]
	StopIfError "Unexpected swap type '$ID_FS_TYPE' found"

	# build swap creation command
	# NOTE: We use an array to better preserve quotes in the arguments
	CMD=(mkswap)
	test "$ID_FS_VERSION" = 2 && CMD=( "${CMD[@]}" -v1 )
	test "$ID_FS_LABEL" && CMD=( "${CMD[@]}" -L "$ID_FS_LABEL" )
	CMD=( "${CMD[@]}" "$device" )

	# check that command has enough words
	[ "${#CMD[@]}" -ge 2 ]
	StopIfError "Invalid swap creation command: '${CMD[@]}'"

	# check that command exists
	[ -x "$(get_path $CMD)" ]
	StopIfError "Swap creation command '$CMD' not found !"

	# run command
	eval "${CMD[@]}" >&8
	StopIfError "Could not create swap on '$device'"

done < <(
	cd $VAR_DIR/recovery
	find . -name swap_vol_id -printf "%P\n"
	)
