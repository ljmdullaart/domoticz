#!/bin/bash
#!/bin/bash
#REMOTE@ domoticz.home /usr/local/bin/batterylevels
#INSTALLEDFROM verlaine:src/domoticz

if [ "$1" = "" ] ; then
	treshhold=80
else
	treshhold=$1
fi

DOMOTICZ='domoticz.home:8080'
SENDMAIL=/usr/sbin/sendmail
tmp=/tmp/batterylevels
bats=/tmp/battery_devices
curlout=/tmp/last_battery_curl_output
domail=/tmp/do_mail.$$
setval=/tmp/setval.$$
touch $setval
rm -f $domail

cat > $tmp <<EOF
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
	echo $mail
	cat $tmp | $SENDMAIL ljm@pi.home 
	rm -f $domail
fi

rm -f $setval

