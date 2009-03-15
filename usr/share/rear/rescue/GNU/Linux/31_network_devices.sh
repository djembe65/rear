# #31_network_devices.sh
#
# record network device configuration for Relax & Recover
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
# Notes:
# - Thanks to Markus Brylski for fixing some bugs with bonding !
# - Thanks to Gerhard Weick for coming up with a way to disable bonding if needed

# BUG: Supports Ethernet only (so far)
# BUG: Should read YOUR bonding configuration instead of assuming mode=1

# where to build networking configuration
netscript=$ROOTFS_DIR/etc/network.sh

# go over ethX and record information
c=0
while : ; do
	dev=eth$c
	if test -d /sys/class/net/$dev ; then
		driver=$(ethtool -i $dev 2>/dev/null | grep driver: | cut -d : -f 2)
		if test -z "$driver" ; then
			LogPrint "WARNING: Could not determine network driver for '$dev'. Please make 
WARNING:   sure that it loads automatically or add it to MODULES_LOAD !"
		else
			echo "modprobe $driver" >>$netscript
		fi
		if ip link show dev $dev | grep -q UP ; then
		# link is up
			for addr in $(ip a show dev $dev | grep inet\ | tr -s " " | cut -d " " -f 3) ; do
				echo "ip addr add $addr dev $dev" >>$netscript
			done
			echo "ip link set dev $dev up" >>$netscript
		fi
	else
		break # while loop
	fi
	let c++
done

# the following is only used for bonding setups
if test -d /proc/net/bonding ; then

	if ! test "$SIMPLIFY_BONDING" ; then
		# go over bondX and record information
		# Note: Some users reported that this works only for the first bonding device
		# in this case one should disable bonding by setting SIMPLIFY_BONDING
		#
		
		# get list of bonding devices
		BONDS=( $(ls /proc/net/bonding) )

		# load bonding with the correct amount of bonding devices
		echo "modprobe bonding max_bonds=${#BONDS[@]} miimon=100 mode=1 use_carrier=0"  >>$netscript
		MODULES=( "${MODULES[@]}" 'bonding' )

		# configure bonding devices
		for dev in "${BONDS[@]}" ; do
			if ip link show dev $dev | grep -q UP ; then
				# link is up, copy interface setup
				#
				# we first need to "up" the bonding interface, then add the slaves (ifenslave complains
				# about missing IP adresses, can be ignores), and then add the IP addresses
				echo "ip link set dev $dev up" >>$netscript
				# enslave slave interfaces which we read from the /proc status file
				ifslaves=($(cat /proc/net/bonding/$dev | grep "Slave Interface:" | cut -d : -f 2))
				echo "ifenslave $dev ${ifslaves[*]}" >>$netscript
				echo "sleep 5" >>$netscript
				for addr in $(ip a show dev $dev | grep inet\ | tr -s " " | cut -d " " -f 3) ; do
					echo "ip addr add $addr dev $dev" >>$netscript
				done
			fi
		done

	else
		# The way to simplify the bonding is to copy the IP addresses from the bonding device to the
		# *first* slave device
		
		# Anpassung HZD: Hat ein System bei einer SLES10 Installation zwei Bonding-Devices 
		# gibt es Probleme beim Boot mit der ReaR-Iso-Datei. Der Befehl modprobe -o name ...
		# funkioniert nicht. Dadurch wird nur das erste bonding-Device koniguriert. 
		# Die Konfiguration des zweiten Devices schlägt fehl und dieses lässt sich auch nicht manuell
		# nachinstallieren. Daher wurde diese script so angepasst, dass die ReaR-Iso-Datei kein Bonding
		# konfiguriert, sondern die jeweiligen IP-Adressen einer Netzwerkkarte des Bondingdevices 
		# zuordnet. Dadurch musste aber auch das script 35_routing.sh angepasst werden.

		# go over bondX and record information
		c=0
		while : ; do
			dev=bond$c
			if test -r /proc/net/bonding/$dev ; then
				if ip link show dev $dev | grep -q UP ; then
				# link is up
					ifslaves=($(cat /proc/net/bonding/$dev | grep "Slave Interface:" | cut -d : -f 2))
					for addr in $(ip a show dev $dev | grep inet\ | tr -s " " | cut -d " " -f 3) ; do
						# ise ifslaves[0] instead of bond$c to copy IP address from bonding device
						# to the first enslaved device
						echo "ip addr add $addr dev ${ifslaves[0]}" >>$netscript
					done
					echo "ip link set dev ${ifslaves[0]} up" >>$netscript
				fi
			else
				break # while loop
			fi
			let c++
		done

	fi

fi # if bonding