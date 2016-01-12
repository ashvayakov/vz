#!/bin/bash

# чтобы не было проблем с выводом данных на кириллице 
export LC_ALL=C

# ваш лимит load average может быть другим в зависимости от количества ядер и типа задач
# например,  для сервера  OpenVZ могу рекомендовать 75-200, для гипервизора KVM - 15-45   
LALIMIT="75"

# кому отправить  отчет
EMAIL="alerts@домен.tld"

# тема сообщения
SUBJECT="WARNING-High load notification"

# Получить среднее значение нагрузки за  5 минут
F5M="$(cut -d. -f1 /proc/loadavg)"

# Сравнить с пороговым значением
RESULT="$(echo "$F5M > $LALIMIT" | bc)"


# Если не зарегистрировано превышение лимита, прекратить выполнение и выйти из выполнения
# Если зарегистрировано превышение, то  создать и отправить  отчет, но не делать это повторно до 
# понижения нагрузки ниже лимита.  Для этого при превышении  создать файл  /tmp/ratkill.flag, 
# при понижении удалить /tmp/ratkill.flag  для продолжения контроля.
#
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

# Создать временный файл для отчета
TEMPFILE="$(mktemp)"

# Создать заголовок отчета
echo "Load average Crossed allowed limit $LALIMIT." >> $TEMPFILE
echo "Hostname: $(hostname)" >> $TEMPFILE
echo "Local Date & Time : $(date)" >> $TEMPFILE

# Использование памяти
echo "Memory-----------------------------------" >> $TEMPFILE
free -m >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
vmstat -s -Sm >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE

# Контроль количества переключений контекста
echo "context switches:" >> $TEMPFILE
sar -w 1 5 >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE

# наиболее активные "гости"
echo "Top loaded containers:" >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
/usr/sbin/vzlist \
-o veid,ip,hostname,numproc,numfile,numflock,numtcpsock,physpages,laverage \
-s laverage | tail -20 >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE

#Контроль количества сетевых соединений у гостей
echo "Top containers by net. connections count:" >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
/usr/sbin/vzlist \
-o veid,ip,hostname,numproc,numtcpsock -s numtcpsock | tail -20 >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE

# Общее количество сетевых подключений
echo "conntrack count" >> $TEMPFILE
wc -l /proc/net/nf_conntrack >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE

# Утилизация дисков
echo "I/O statistic:" >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
iostat -x 2 5 >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE

# Снимок вывода top
echo "System snapshot from top:" >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
top -b | head -30 >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE

# Процессы с максимальным I/O и нагрузкой на CPU
echo "Report from dstat:" >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE
dstat --net --disk --disk-util --sys --load --proc --top-io-adv \
--top-cpu-adv --nocolor 5 5 >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE

# Отчет по RAID массивам 
echo "RAID Logical device information" >> $TEMPFILE
#/opt/MegaRAID/MegaCli/MegaCli64 -LDInfo -LALL -aAll >> $TEMPFILE
/usr/local/sbin/arcconf GETCONFIG  1 ld >> $TEMPFILE
echo "-------------------------------------------" >> $TEMPFILE

# Отправить  отчет по почте
cat $TEMPFILE > /tmp/load.txt
echo "${SUBJECT}-${F5M}" | mail -a /tmp/load.txt -s "$(hostname -s)-${SUBJECT}-${F5M}" "$EMAIL" 
rm -f $TEMPFILE

