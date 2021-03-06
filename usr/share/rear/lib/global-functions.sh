# global-functions.sh
#
# global functions for Relax & Recover
#
#    Relax & Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax & Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax & Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#

function read_and_strip_file () {
# extracts content from config files. In other words: strips the comments and new lines
	if test -s "$1" ; then
		sed -e '/^[[:space:]]/d;/^$/d;/^#/d' "$1"
	fi
}

######
### Functions for dealing with URLs
######

url_scheme() {
    local url=$1
    local scheme=${url%%://*}
    # rsync scheme does not have to start with rsync:// it can also be scp style
    echo $scheme | grep -q ":" && echo rsync || echo $scheme
}

url_host() {
    local url=$1
    local temp=${url#*//}
    echo ${temp%%/*}
}

url_path() {
    local url=$1
    local temp=${url#*//}
    echo ${temp#*/}
}

output_path() {
    local scheme=$1
    local path=$2
    case $scheme in
       (tape)  # no path for tape required
           path=""
           ;;
       (file)  # type file needs a local path (must be mounted by user)
           path="/$path/${NETFS_PREFIX}"
           ;;
       (*)     # nfs, cifs, usb, a.o. need a temporary mount-path 
           path="${BUILD_DIR}/outputfs/${NETFS_PREFIX}"
           ;;
    esac
    echo "$path"
}

### Mount URL $1 at mountpoint $2[, with options $3]
mount_url() {
    local url=$1
    local mountpoint=$2
    local options=${3:-"rw,noatime"}

    ### Generate a mount command
    local mount_cmd
    case $(url_scheme $url) in
        (tape|file|rsync|fish|ftp|ftps|hftp|http|https|sftp)
            ### Don't need to mount anything for these
            return 0
            ;;
        (var)
            ### The mount command is given by variable in the url host
            local var=$(url_host $url)
            mount_cmd="${!var} $mountpoint"
            ;;
        (cifs)
            mount_cmd="mount $v -o $options //$(url_host $url)/$(url_path $url) $mountpoint"
            ;;
        (usb)
            mount_cmd="mount $v -o $options /$(url_path $url) $mountpoint"
            ;;
        (*)
            mount_cmd="mount $v -t $(url_scheme $url) -o $options $(url_host $url):/$(url_path $url) $mountpoint"
            ;;
    esac

    Log "Mounting with '$mount_cmd'"
    $mount_cmd >&2
    StopIfError "Mount command '$mount_cmd' failed."

    AddExitTask "umount -f $v '$mountpoint' >&2"
    return 0
}

### Unmount url $1 at mountpoint $2
umount_url() {
    local url=$1
    local mountpoint=$2

    case $(url_scheme $url) in
        (tape|file|rsync|fish|ftp|ftps|hftp|http|https|sftp)
            ### Don't need to umount anything for these
            return 0
            ;;
        (var)
            local var=$(url_host $url)
            umount_cmd="${!var} $mountpoint"

            Log "Unmounting with '$umount_cmd'"
            $umount_cmd
            StopIfError "Unmounting failed."

            RemoveExitTask "umount -f $v '$mountpoint' >&2"
            return 0
            ;;
    esac

    umount_mountpoint $mountpoint
    StopIfError "Unmounting '$mountpoint' failed."

    RemoveExitTask "umount -f $v '$mountpoint' >&2"
    return 0
}

### Unmount mountpoint $1
umount_mountpoint() {
    local mountpoint=$1

    ### First, try a normal unmount,
    Log "Unmounting '$mountpoint'"
    umount $v $mountpoint >&2
    if [[ $? -eq 0 ]] ; then
        return 0
    fi

    ### otherwise, try to kill all processes that opened files on the mount.
    # TODO: actually implement this

    ### If that still fails, force unmount.
    Log "Forced unmount of '$mountpoint'"
    umount $v -f $mountpoint >&2
    if [[ $? -eq 0 ]] ; then
        return 0
    fi

    Log "Unmounting '$mountpoint' failed."
    return 1
}
