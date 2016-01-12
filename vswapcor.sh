#!/bin/bash

#EMAIL="a.shvayakov@gmail.com"
EMAIL="alerts@colobridge.net"

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin
export PERL5LIB=/usr/share/perl5/


echo "Stop gamers"
PROC=$(ps -eo pid,comm| grep java| awk '{print $1}')

for zz in $PROC;
do
renice +10 $zz
done 


tar -czf /root/scripts/tools/tuning/arch/`date +%Y-%m-%d-%H:%M`.tar.gz /etc/sysconfig/vz-scripts/*.conf
find /root/scripts/tools/tuning/arch/ -type f -name \*\.conf -mtime +31 -exec rm -f {} \;

## install scripts to all openvz containers 
LONG_MAX="9223372036854775807"
#difference %
DIF=110
DIF2=80
#limit =barier+5%
LIM="105"

BRONZE1="262144"
SILVER1="524288"
GOLD1="786432"
PLATINUM1="1572864"

BRONZE="262144"
SILVER="576512"
GOLD="865024"
PLATINUM="1730048"
# Исключение списка
# vzlist -H -o ctid | grep -Fwv -f /root/scripts/tools/tuning/nocor.list

##NOCOR=( `cat /root/scripts/tools/tuning/nocor.list | tr '\n' ' '` )
#COR=$(vzlist -H -o ctid)
#for  ECOR in ${NOCOR[*]}
#	do
#	COR=$(echo $COR | sed "s/\b$ECOR\b//g")
#	done

# Обработка
for arg in $(vzlist -H -o ctid | grep -Fwv -f /root/scripts/tools/tuning/nocor.list)
#for arg in 430
do
#  echo "fix container $arg" 
#PHYSPAGES=$(awk -F'=\"|:|\"' '/PHYSPAGES/{print $3}' /etc/vz/conf/${arg}.conf)
PHYSPAGES=$(grep -A6 " ${arg}:" /proc/user_beancounters | grep physpages | awk '{print $5 }')
#PRIVVMPAGES=$(awk -F'=\"|:|\"' '/PRIVVMPAGES/{print $2}' /etc/vz/conf/$arg.conf);
PRIVVMPAGES=$(grep -A2 " ${arg}:" /proc/user_beancounters | grep privvmpages | awk '{print $4 }');

    if [ $PHYSPAGES = 9223372036854775807 ]
	then
	RAM=$PRIVVMPAGES
	else
	RAM=$PHYSPAGES
    fi
echo "$arg----$RAM"

if [ $RAM -le $BRONZE ]
	then  echo "$arg = Bronze $(expr $RAM \* 4 / 1024)Mb"
              RAM=$BRONZE1
		CPU=1000
		IOPRIO=3
		CPULIMIT=23
#	echo BRONZE
    else 
    if [ $RAM -le $SILVER ]
	then  echo "$arg = Silver $(expr $RAM \* 4 / 1024)Mb"
	      RAM=$SILVER1
		CPU=2000
		IOPRIO=4
		CPULIMIT=38
#	echo SILVER
	else 
	if [ $RAM -le $GOLD ]
	    then  echo "$arg = Gold $(expr $RAM \* 4 / 1024)Mb"
		RAM=$GOLD1
		CPU=3000
		IOPRIO=5
		CPULIMIT=61
#	echo GOLD
	    else 
	    if [ $RAM -le $PLATINUM ]
		then  echo "$arg = Platinum $(expr $RAM \* 4 / 1024)Mb"
	  	RAM=$PLATINUM1
		CPU=4000
		IOPRIO=6     	
		CPULIMIT=125
#	echo PLATINUM
		else
	    	if [ $RAM -ge $PLATINUM ]
			then echo "$arg = Large $(expr $RAM \* 4 / 1024)Mb"
		fi
	    fi
	fi
    fi
fi




echo $RAM
let kmemsize="($RAM * 4)*400"
#let kmemsize="$RAM / 2"
echo "kmem=$kmemsize"
let lockedpages="$RAM / 2"
echo "lockedpages=$lockedpages"
let numproc="($RAM * 8)/5120"
echo "nproc=$numproc"
let numtcpsock="($RAM * 6)/640"
echo "numtcpsock=$numtcpsock"
let numflock="($RAM * 8)/5120"
echo "numflock=$numflock"
let numsiginfo="($RAM * 4)/2560"
echo "numsiginfo=$numsiginfo"
let numothersock="($RAM * 4)/1500"
echo "numothersock=$numothersock"
let dcachesize="$kmemsize / 4"
echo "dcachesize=$dcachesize"
let numfile="($RAM * 4)/7"
echo "numfile=$numfile"
let numiptent="($RAM * 6)/2560"
echo "numiptent=$numiptent"
let swappages="$RAM / 4444"
echo "swapapages=$swappages"


vzctl set $arg --kmemsize $kmemsize:$( expr $kmemsize \* $DIF / 100 ) \
--lockedpages $lockedpages:$lockedpages \
--privvmpages unlimited \
--shmpages unlimited \
--numproc $numproc:$numproc \
--physpages 0:$RAM \
--oomguarpages 0:unlimited \
--vmguarpages 0:unlimited \
--numtcpsock $numtcpsock:$numtcpsock \
--numflock $numflock:$( expr $numflock \* $DIF / 100 ) \
--numpty 256:256 \
--numsiginfo $numsiginfo:$numsiginfo \
--tcpsndbuf unlimited \
--tcprcvbuf unlimited \
--othersockbuf unlimited \
--dgramrcvbuf unlimited  \
--numothersock $numothersock:$numothersock \
--dcachesize $dcachesize:$( expr $dcachesize \* $DIF / 50 )  \
--swappages 0:$swappages \
--numfile $numfile:$numfile \
--numiptent $numiptent:$numiptent \
--cpuunits $CPU \
--ioprio $IOPRIO \
--cpulimit 0 \
--save 

vzcfgvalidate  /etc/vz/conf/$arg.conf


#STOP GAMERS 
for i in $PROC;
    do
    VZJAVA=$(vzpid $i | awk '{print $2}'|tail -1)
#    echo "$i-$VZJAVA"

    if [ ${arg} = ${VZJAVA} ]
    then
echo "$i-$VZJAVA"
    
#    vzctl set $arg --cpulimit $CPULIMIT --ioprio 3 --save
    IDIP=$(vzlist -o veid,ip ${VZJAVA}| tail -1);
    [[ -f  /root/scripts/tools/tmp/${VZJAVA}.gamer ]] || echo $IDIP | mail -s "$VZJAVA-NEW-JAVA-GAMER-${IDIP}" ${EMAIL}
    echo $IDIP > /root/scripts/tools/tmp/${VZJAVA}.gamer
    fi
done 


echo "---------------------------------"

done
