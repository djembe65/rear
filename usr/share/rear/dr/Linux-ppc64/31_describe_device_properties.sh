# describe the partition tables of all fixed devices

while read device junk ; do
	# device is something like /dev/sda or /dev/cciss/c0d0
	mkdir -p $VAR_DIR/recovery$device

	sfdisk -d $device | grep -E "(unit:|${device}.*:)" >$VAR_DIR/recovery$device/sfdisk.partitions
	[ $PIPESTATUS -eq 0 ]
	StopIfError "Could not store the partition table for '$device'"

	sfdisk -g $device > $VAR_DIR/recovery$device/sfdisk.geometry
	StopIfError "Could not store geometry for '$device'"

	sfdisk -s $device > $VAR_DIR/recovery$device/size
	StopIfError "Could not store size for '$device'"

done <$VAR_DIR/recovery/required_devices


