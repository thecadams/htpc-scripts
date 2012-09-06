#!/bin/bash
# Check to see if the system is idle. Return 0 if so and 1 if not.
# Echoed text appears in log file. It can be removed and --quiet added to the 
# grep command once you are satisfied that mythTV is working properly
RET=0
IDLESEC=300 # 5 minutes

# lircidle.py is a daemon that pretends to be mythtv to lirc.
# If it's already running as a daemon, it connects to itself to report the time since lirc told it about input.
# If it's not running it prints 0 and daemonizes itself.
LIRCIDLE=$(/home/myth/scripts/lircidle.py | sed -e 's/\..*$//')
echo -n $(date '+%F %T.%N'|cut -c-23) $(basename $0): mythtv lirc input idle for $LIRCIDLE sec
if [ $LIRCIDLE -gt $IDLESEC ]; then
 echo
else
 echo " (prevents shutdown)"
 RET=1
fi

# Use awk to find X sessions (coming from :0, :1.0 etc.)
for d in $(w|awk '$3~/^:/{print $3}'); do
 XIDLE=$(DISPLAY=$d /home/myth/scripts/xidle | sed -e 's/\..*$//')
 echo -n $(date '+%F %T.%N'|cut -c-23) $(basename $0): display $d input idle for $XIDLE sec
 if [ $XIDLE -gt $IDLESEC ]; then
  echo
 else
  echo " (prevents shutdown)"
  RET=1
 fi
done

NUMMYTHFRONTEND=$(ps -ef | grep '/usr/bin/mythfrontend.real' | grep -v grep|wc -l)
echo -n $(date '+%F %T.%N'|cut -c-23) $(basename $0): mythfrontend
if [ "$NUMMYTHFRONTEND" -eq "1" ]
 then
  echo " is running"
  MYTHLOCATION=$(echo -e "query location\nexit"|nc localhost 6546|sed -e 's/^# //'|tail -n1|awk '{print $1,$2}')
  echo -n $(date '+%F %T.%N'|cut -c-23) $(basename $0): mythfrontend location is $MYTHLOCATION
  echo
 else
  echo " not running: $NUMMYTHFRONTEND processes found"
  RET=1
fi

NUMFIREFOX=$(ps -ef | grep '/usr/bin/firefox-3.5' | grep -v grep|wc -l)
echo -n $(date '+%F %T.%N'|cut -c-23) $(basename $0): $NUMFIREFOX firefox processes running
if [ "$NUMFIREFOX" -eq "0" ]
 then
  echo
 else
  echo " (prevents shutdown)"
  RET=1
fi

NUMXBMC=$(ps -ef | grep '/usr/share/xbmc/xbmc.bin' | grep -v grep|wc -l)
echo -n $(date '+%F %T.%N'|cut -c-23) $(basename $0): $NUMXBMC XBMC processes running
if [ "$NUMXBMC" -eq "0" ]
 then
  echo
 else
  echo " (prevents shutdown)"
  RET=1
fi

if [ "$NUMMYTHFRONTEND" -eq "0" ]
 then
  if [ "$NUMXBMC" -eq "0" ]
  then
   echo $(date '+%F %T.%N'|cut -c-23) $(basename $0): neither mythfrontend nor XBMC are running "(prevents shutdown)"
   RET=1
  fi
fi

# Use awk to exclude X sessions (coming from :0, :1.0 etc.)
NUMLOGINS=$(w|sed -e '/^USER/d' -e '/load average/d'|awk '$3 !~ /^:[0-9]/'|wc -l)
echo -n $(date '+%F %T.%N'|cut -c-23) $(basename $0): $NUMLOGINS users logged in from non-X sessions
if [ "$NUMLOGINS" -eq "0" ]
 then
  echo
 else
  echo " (prevents shutdown)"
  RET=1
fi

NUMSCREEN=$(ps -ef | grep 'SCREEN' | grep -v grep|wc -l)
echo -n $(date '+%F %T.%N'|cut -c-23) $(basename $0): $NUMSCREEN screen processes running
if [ "$NUMSCREEN" -eq "0" ]
 then
  echo
 else
  echo " (prevents shutdown)"
  RET=1
fi

LOCKED=$(mythshutdown -s;echo $?|perl -e '$_=<>;print $_&16;')
if [ "$LOCKED" -eq "0" ]
 then
  echo $(date '+%F %T.%N'|cut -c-23) $(basename $0): backend shutdown is not locked
 else
  echo $(date '+%F %T.%N'|cut -c-23) $(basename $0): backend shutdown is locked \(prevents shutdown\)
  RET=1
fi

if [ "$RET" -eq "0" ]
 then
  echo $(date '+%F %T.%N'|cut -c-23) $(basename $0): Ok to shut down, shutting down
 else
  echo $(date '+%F %T.%N'|cut -c-23) $(basename $0): Not ok to shut down, preventing shutdown
fi
exit $RET
