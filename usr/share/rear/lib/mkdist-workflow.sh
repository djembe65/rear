# mkdist-workflow.sh
#
#
# create distribution files of rear
#

WORKFLOW_mkdist_DESCRIPTION="Create distribution tar archive with this rear version"
WORKFLOWS=( ${WORKFLOWS[@]} mkdist )
WORKFLOW_mkdist () {
	
	prod_ver="$(basename "$0")-$VERSION"
	distarchive="/tmp/$prod_ver.tar.gz"
	ProgressStart "Creating archive '$distarchive'"

	mkdir $BUILD_DIR/$prod_ver -v 1>&8
	ProgressStopIfError $? "Could not mkdir $BUILD_DIR/$prod_ver" 

	# use tar to copy the current rear while excluding development and obsolete files
	tar -C / --exclude=hpasmcliOutput.txt --exclude=\*~ --exclude=\*.rpmsave\* \
       		 --exclude=\*.rpmnew\* --exclude=.\*.swp -cv \
			"$SHARE_DIR" \
			"$CONFIG_DIR" \
			"$(type -p "$0")" |\
		tar -C $BUILD_DIR/$prod_ver -x 1>&8
	ProgressStopIfError $? "Could not copy files to $BUILD_DIR/$prod_ver"
	
	pushd $BUILD_DIR/$prod_ver 1>&8
	ProgressStopIfError $? "Could not pushd $BUILD_DIR/$prod_ver"

	# rename ebuild to current version if it does not have the current version
	test -s .$SHARE_DIR/contrib/rear-$VERSION.ebuild ||\
		mv -v .$SHARE_DIR/contrib/rear-*.ebuild .$SHARE_DIR/contrib/rear-$VERSION.ebuild 1>&8
	ProgressStopIfError $? "Could not mv rear-*.ebuild"


#	ln -sv .$SHARE_DIR/{CHANGES,README,doc,contrib} . 1>&8
#	ProgressStopIfError $? "Could not symlink .$SHARE_DIR/{CHANGES,README,doc,contrib}"
	cp -rv .$SHARE_DIR/{COPYING,CHANGES,README,doc,contrib}  .  1>&8
	ProgressStopIfError $? "Could not copy .$SHARE_DIR/{COPYING,CHANGES,README,doc,contrib}"
	# Convert to utf-8
	for file in COPYING CHANGES README `find doc -type f` ; do
		mv $file timestamp 1>&8
		ProgressStopIfError $? "Could not move $file"
		iconv -f ISO-8859-1 -t UTF-8 -o $file timestamp 1>&8
		ProgressStopIfError $? "Could not convert $file to UTF-8 format"
		touch -r timestamp $file 1>&8
		ProgressStopIfError $? "Could not apply timestamp to $file"
	done
	rm -f timestamp


	# copy rear.spec according OS_VENDOR and patch version into RPM spec file
	cp .$SHARE_DIR/lib/spec/$OS_VENDOR/rear.sourcespec .$SHARE_DIR/lib/rear.spec 1>&8
	ProgressStopIfError $? "Could not copy $OS_VENDOR specific rear.spec file"
	sed -i -e "s/Version:.*/Version: $VERSION/" .$SHARE_DIR/lib/rear.spec
	chmod 644 .$SHARE_DIR/lib/rear.spec
	cp -fp .$SHARE_DIR/lib/rear.spec $SHARE_DIR/lib/rear.spec

	# remove current recovery information (pre-1.7.15)
	rm -Rf .$CONFIG_DIR/recovery

	# write out standard site.conf and local.conf and templates
	cat >./$CONFIG_DIR/site.conf <<EOF
# site.conf
# another config file that is sourced BEFORE local.conf
# could be used to set site-wite settings
# you could then distribute the site.conf from a central location while you keep
# the machine-local settings in local.conf
EOF
	cat >./$CONFIG_DIR/local.conf <<EOF
# sample local configuration

# Create ReaR rescue media as ISO image
OUTPUT=ISO

# optionally set your backup software
# BACKUP=TSM

# the following is required on older VMware VMs
MODULES_LOAD=( vmxnet )
EOF
	
	tee ./$CONFIG_DIR/templates/{PXE_pxelinux.cfg,ISO_isolinux.cfg,USB_syslinux.cfg} >/dev/null <<EOF
default hd
prompt 1
timeout 100

label hd
localboot -1
say ENTER - boot local hard disk
say --------------------------------------------------------------------------------
EOF

	popd 1>&8
	tar -C $BUILD_DIR -cvzf $distarchive $prod_ver 1>&8
	ProgressStopOrError $? "Could not create $distarchive"

}