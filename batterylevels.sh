#!/bin/bash
#INSTALLEDFROM verlaine:/home/ljm/src/domoticz
#!/bin/bash
#REMOTE@ domoticz.home /usr/local/bin/batterylevels

if [ "$1" = "" ] ; then
	treshhold=80
else
	treshhold=$1
fi

DOMOTICZ='domoticz.home:8888'
tmp=/tmp/batterylevels
bats=/tmp/battery_devices
curlout=/tmp/last_battery_curl_output
domail=/tmp/do_mail.$$
setval=/tmp/setval.$$
touch $setval
rm -f $domail

cat > $tmp <<EOF
HELO aesopos
MAIL FROM: Domoticz
RCPT TO:<ljm@aesopos>
DATA
From: Domoticz
To: ljm
Subject: Batterijen

EOF
curl -s -o- "$DOMOTICZ/json.htm?type=devices&used=true&displayhidden=1"|
jq '.' > $curlout

egrep '{|}|BatteryLevel|"Name"' $curlout | 
sed 's/^ *//;s/"//g;s/,//g' |
while read line ; do
	case "$line" in
	({)
		level=''
		name=''
		;;
	(})
		if [ $level -lt $treshhold ] ; then
			if [ $treshhold -gt 99 ] ; then
				echo "Status: $name batterij niveau $level%." >>$tmp
			else
				echo "WAARSCHUWING: batterij van $name heeft nog $level%." >>$tmp
			fi
			touch $domail
		fi
		if [ $level -lt 101 ] ; then
			batdev=${name%_*}_battery
			idx=$(cat $curlout |jq ".result[] | select (.Name==\"$batdev\") .idx" |sed 's/"//g')
			if [ "$idx" != "" ] ; then
				#echo  "$idx -> $level"
				#echo "$DOMOTICZ/json.htm?type=command&param=udevice&idx=$idx&nvalue=0&svalue=$level"
				curl -s -o- "$DOMOTICZ/json.htm?type=command&param=udevice&idx=$idx&nvalue=0&svalue=$level" > /dev/null
			fi
		fi
		;;
	(Name*)
		name=${line#*: }
		;;
	(Battery*)
		level=${line#*: }
		;;
	esac
done
	
if [ -f $domail ] ; then
	echo >> $tmp
	echo '.'  >> $tmp
	echo >> $tmp
	cat $tmp |
	while read L; do
		sleep "1"
		echo "$L"
	done |
	"nc" -C -v "aesopos.home" "25"
	rm -f $domail
fi

rm -f $setval

