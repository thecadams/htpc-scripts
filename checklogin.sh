#!/bin/bash
# Check to see if anyone is currently logged in. Return zero if not and 1 if so.
# Echoed text appears in log file. It can be removed and --quiet added to the 
# grep command once you are satisfied that mythTV is working properly
RET=0

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

NUMFIREFOX=$(ps -ef | grep '/usr/bin/firefox-3.5' | grep -v grep|wc -l)
echo -n $(date '+%F %T.%N'|cut -c-23) $(basename $0): $NUMFIREFOX firefox processes running
if [ "$NUMFIREFOX" -eq "0" ]
 then
  echo
 else
  echo " (prevents shutdown)"
  RET=1
fi

NUMXBMC=$(ps -ef | grep '/usr/bin/xbmc' | grep -v grep|wc -l)
echo -n $(date '+%F %T.%N'|cut -c-23) $(basename $0): $NUMXBMC XBMC processes running
if [ "$NUMXBMC" -eq "0" ]
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
