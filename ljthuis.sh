#!/bin/bash
#REMOTE@ domoticz.home /usr/local/bin/ljthuis
#INSTALLEDFROM verlaine:src/domoticz
##########################################################################
# Set or change the hostnames below to match your environment
##########################################################################

DOMOTICZ='domoticz.home:8888'
TARGET=192.168.178.219
DOMO_DEV='laurent-jan_thuis'

##########################################################################
helpme(){
cat <<EOF

NAME: Am i at home?

EOF
}

if [ "$1" = "-h" ] ; then
	helpme
	exit 0
fi

verbose=0
if [ "$1" = "-v" ] ; then
	verbose=1
fi

debug(){
	if [ "$verbose" = 1 ] ; then
		echo $*
	fi
}


tmp=$(mktemp)
now=$(date)

# Get list of devices
curl --silent  "http://$DOMOTICZ/json.htm?type=command&param=devices_list" |
sed 's/"//g;s/,//' |
while read nv col val ; do
	if [ "$nv" = 'name' ] ; then
		name="$val"
	elif [ "$nv" = 'value' ] ; then
		echo "$val $name"
	fi
done > $tmp


val=0
if ping -c5 $TARGET > /tmp/last_ljm.out 2> /tmp/last_ljm.err ; then
	val=1
fi
debug "Value: $val"
idx=$(sed -n "s/ $DOMO_DEV//p" $tmp)
debug "idx=$idx"
if [ "idx" = "" ] ; then
	true
else
	debug curl --silent  "http://$DOMOTICZ/json.htm?type=command&param=udevice&idx=$idx&nvalue=$val" 
	curl --silent  "http://$DOMOTICZ/json.htm?type=command&param=udevice&idx=$idx&nvalue=$val" > /dev/null
fi


rm -f $tmp
