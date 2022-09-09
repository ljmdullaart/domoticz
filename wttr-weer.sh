#!/bin/bash
#REMOTE@ domoticz.home /usr/local/bin/wttr-weer
#INSTALLEDFROM verlaine:src/domoticz

WHERE=mijdrecht
DOMOTICZ='domoticz.home:8888'

helpme(){
cat <<EOF
NAME:  wttr-weer
DESCRIPTION:
Update virtual sensors in Domoticz with values from the weather API wttr. The
virtual sensors must be made mahual with the following name:
- wttr-temp
- wttr-humid
- wttr-barometer
- wttr-wind

EOF
}

tmp=$(mktemp)

date > /tmp/last_wttr

curl --silent  "http://$DOMOTICZ/json.htm?type=command&param=devices_list" |
sed 's/"//g;s/,//' |
while read nv col val ; do
	if [ "$nv" = 'name' ] ; then
		name="$val"
	elif [ "$nv" = 'value' ] ; then
		echo "$val $name"
	fi

done > $tmp

total=$(curl --silent wttr.in/$WHERE?format="+%t:+%h:+%P:+%w:+%f\n"|sed 's/ //g')
totalar=(${total//:/ })
temp_val=$(echo ${totalar[0]} | sed 's/[^0-9]*//g')
humid_val=$(echo ${totalar[1]} | sed 's/[^0-9]*//g')
baro_val=$(echo ${totalar[2]} | sed 's/[^0-9]*//g')
wind_sp=$(echo ${totalar[3]} | sed 's/[^0-9]*//g')
feel_val=$(echo ${totalar[4]} | sed 's/[^0-9]*//g')

if [ "${totalar[3]%%[0-9]*}" = "←" ] ; then WD=E ; WB=90 ; fi
if [ "${totalar[3]%%[0-9]*}" = "↑" ] ; then WD=S ; WB=180 ; fi
if [ "${totalar[3]%%[0-9]*}" = "→" ] ; then WD=W ; WB=270 ; fi
if [ "${totalar[3]%%[0-9]*}" = "↓" ] ; then WD=N ; WB=0 ; fi
if [ "${totalar[3]%%[0-9]*}" = "↖" ] ; then WD=SE ; WB=135 ; fi
if [ "${totalar[3]%%[0-9]*}" = "↗" ] ; then WD=SW ; WB=225 ; fi
if [ "${totalar[3]%%[0-9]*}" = "↘" ] ; then WD=NW ; WB=315 ; fi
if [ "${totalar[3]%%[0-9]*}" = "↙" ] ; then WD=NE ; WB=45 ; fi

if [ $baro_val -ge 1030 ] ; then baro_for=1
elif [ $baro_val -ge 1000 ] ; then baro_for=3
elif [ $baro_val -ge 970 ] ; then baro_for=2
else $baro_val=4
fi

temp_idx=$(sed -n 's/ wttr-temp//p' $tmp)
if [ "$temp_idx" = "" ] ; then
	echo "No temp dev">> /tmp/last_wttr
else
	curl --silent  "http://$DOMOTICZ/json.htm?type=command&param=udevice&idx=$temp_idx&nvalue=1&svalue=$temp_val" > /dev/null
	echo "Temp: $temp_val" >> /tmp/last_wttr
fi

humid_idx=$(sed -n 's/ wttr-humid//p' $tmp)
if [ "$humid_idx" = "" ] ; then
	echo "No hum dev">> /tmp/last_wttr
else
	curl --silent  "http://$DOMOTICZ/json.htm?type=command&param=udevice&idx=$humid_idx&nvalue=$humid_val" > /dev/null
	echo "humid: $humid_val" >> /tmp/last_wttr
fi

baro_idx=$(sed -n 's/ wttr-barometer//p' $tmp)
if [ "baro_idx" = "" ] ; then
	echo "No baro dev">> /tmp/last_wttr
else
	curl --silent "http://$DOMOTICZ/json.htm?type=command&param=udevice&idx=$baro_idx&nvalue=0&svalue=$baro_val;$baro_for" > /dev/null
	echo "Pressure: $baro_val">> /tmp/last_wttr
fi


wind_idx=$(sed -n 's/ wttr-wind//p' $tmp)
if [ "wind_idx" = "" ] ; then
	echo "No wind dev">> /tmp/last_wttr
else
	curl --silent "http://$DOMOTICZ/json.htm?type=command&param=udevice&idx=$wind_idx&nvalue=0&svalue=$WB;$WD;$wind_sp;$wind_sp;$temp_val;$feel_val" > /dev/null
fi
	
rm -f $tmp
