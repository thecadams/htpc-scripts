#!/bin/bash
# nwsw: network window switcher
# Switch windows when a connection attempt is made on a certain port
# currently switches between xbmc, mythfontend and firefox

function switchto()
{
 # If a process referred to by $2 exists, switch to a window with the name in $3
 # If no process exists, start the process name in $1
 # If no window exists, kill and restart the process name in $1
 # $1 - name of executable to launch (usually a wrapper)
 # $2 - name of wrapped "real" executable
 # $3 - window title
 echo switchto: attempting to switch to window with process $1 and name $3
 # Check the process is running
 pgrep -u `whoami` $2
 if [ $? -ne 0 ]; then
  # Process is not running
  echo switchto: process $1 not found\; starting.
  $1 &
  echo switchto: started $1
 else
  # Attempt to switch to window
  echo switchto: attempting to activate window with title containing $3
  wmctrl -a $3
  if [ $? -ne 0 ]; then
   # Window not found
   echo switchto: window with title containing $3 not found\; killing process $1
   pkill -u `whoami` $1
   echo switchto: killed process $1\; re-launching
   $1 &
   echo switchto: relaunched process $1
  fi
 fi
 echo switchto: succeeded
}

# REVISIT: determine DISPLAY based on /usr/bin/X :0 being in process list

case $1 in
 init)
 # Set up triggers in firewall

 # REVISIT: determine IP dynamically from eth0
 IF=eth0
 IP=$(ifconfig $IF|grep inet|grep -v inet6|sed -e s/.*addr://|cut -d' ' -f1)

 # don't trigger task-switching from a local connection attempt
 iptables -A INPUT -s 127.0.0.1 -d 127.0.0.1 -p tcp -j ACCEPT
 iptables -A INPUT -s $IP -d $IP -p tcp -j ACCEPT

 # mythfrontend telnet interface
 iptables -A INPUT -d $IP -p tcp --dport 6543 --syn -m state --state
NEW -j LOG --log-prefix="nwsw-6543"
 # XBMC web interface
 iptables -A INPUT -d $IP -p tcp --dport 8080 --syn -m state --state
NEW -j LOG --log-prefix="nwsw-8080"

 # Start watching the logfile for triggers
 tail -f /var/log/messages | awk '
 /nwsw-6543/ {system("$0 mythfrontend")}
 /nwsw-8080/ {system("$0 xbmc")}
 ' ;;
 current)
 # Print the current active window; used for alt-tab
 activeWinLine=$(xprop -root | grep "_NET_ACTIVE_WINDOW(WINDOW)")
 echo $activeWinLine
 activeWinId=$(echo ${activeWinLine:40} | sed s/0x/0x0*/)
 echo $activeWinId
 activeWinNameLine=$(wmctrl -l | grep ^$activeWinId)
 echo $activeWinNameLine
 activeWinName=$(echo $activeWinNameLine | cut -d' ' -f4-)
 echo $activeWinName
 echo $activeWinName|grep -i xbmc
 if [ $? -eq 0 ]; then echo xbmc; exit 0; fi
 echo $activeWinName|grep -i mythfrontend.real
 if [ $? -eq 0 ]; then echo mythfrontend; exit 0;fi
 echo $activeWinName|grep -i firefox
 if [ $? -eq 0 ]; then echo firefox; exit 0; fi
 echo unknown; exit 1
 ;;
 next)
 # Cycle to next in the set (alt-tab behaviour)
 current=`$0 current`
 case $current in
  xbmc)
         $0 mythfrontend ;;
        mythfrontend)
         $0 firefox ;;
        firefox)
         $0 xbmc ;;
  *)
   # Switch to xbmc if we don't recognize where we are
   $0 xbmc ;;
 esac ;;
 mythfrontend)
 # Start mythfrontend or switch to running instance
 switchto 'mythfrontend' 'mythfrontend' 'mythfrontend.real' ;;
 xbmc)
 # Start xbmc or switch to running instance
 switchto 'xbmc' 'xbmc.bin' 'XBMC' ;;
 firefox)
 # Start firefox or switch to running instance
 switchto 'firefox' 'firefox' 'Firefox'
 sleep 2
 wmctrl -r 'Firefox' -b add,fullscreen ;;
 *)
 # Print a usage message
 echo "$0: Network window switcher"
 echo "Usage: $0 (init | current | next | mythfrontend | xbmc | firefox)"
 exit 1 ;;
esac
