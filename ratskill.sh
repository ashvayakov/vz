#!/bin/bash
export LC_ALL=C
LALIMIT="80"
EMAIL="alerts@colobridge.net"
SUBJECT="WARNING-High load notification"


# get first 5 min load
F5M="$(cat /proc/loadavg | awk '{print $1}'|awk -F \. '{print $1}')"
RESULT="$(echo "$F5M > $LALIMIT" | bc)"

echo $RESULT

if (( "$RESULT" == "1" )); then
  if [ -f /tmp/ratkill.flag ]; then
    exit 0
  fi
  touch /tmp/ratkill.flag
else
  if [ -f /tmp/ratkill.flag ]; then
    rm -f /tmp/ratkill.flag
  fi
  exit 0
fi

TEMPFILE="$(mktemp)"

echo "Load average Crossed allowed limit $LALIMIT." >> $TEMPFILE
echo "Hostname: $(hostname)" >> $TEMPFILE
echo "Local Date & Time : $(date)" >> $TEMPFILE
echo "Memory-----------------------------------" >> $TEMPFILE
free -m >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
vmstat -s -Sm >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
echo "context switches:" >> $TEMPFILE
sar -w 1 5 >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
echo "Top loaded containers:" >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
/usr/sbin/vzlist -o veid,ip,hostname,numproc,numfile,numflock,numtcpsock,physpages,laverage -s laverage | tail -20 >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
echo "Top containers by net. connections count:" >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
/usr/sbin/vzlist -o veid,ip,hostname,numproc,numtcpsock -s numtcpsock | tail -20 >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
wc -l /proc/net/nf_conntrack >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
echo "I/O statistic:" >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
iostat -x 2 5 >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
echo "System snapshot from top:" >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
top -b | head -30 >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
echo "Report from dstat:" >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
dstat --net --disk --disk-util --sys --load --proc --top-io-adv --top-cpu-adv --nocolor 5 5 >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
echo "RAID Logical device information" >> $TEMPFILE
#/opt/MegaRAID/MegaCli/MegaCli64 -LDInfo -LALL -aAll >> $TEMPFILE
/usr/local/sbin/arcconf GETCONFIG  1 ld >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
cat $TEMPFILE > /tmp/load.txt
echo "${SUBJECT}-${F5M}" | mail -a /tmp/load.txt -s "$(hostname -s)-${SUBJECT}-${F5M}" "$EMAIL" 
rm -f $TEMPFILE
