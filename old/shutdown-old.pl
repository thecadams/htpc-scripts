#!/usr/bin/perl -w

# Fork and show a message on the TV to tell the user what the system will do
sub showmsg
{
 unless ($pid = fork())
 {
  # Child process
  my $msg = $_[0];
  print "Display message: " . $msg . "\n(showing for 6 sec...";
  `gxmessage -display :0 -timeout 6 -borderless -fn "URW Chancery L 48" -buttons '' -bg black -fg gray "$msg" &`;
  print "finished)\n";
  exit;
 }
 return $pid;
}

# Beep a certain way to let the user know why shutdown will/wont happen
sub beep
{
 unless ($pid = fork())
 {
  # Child process
  my $shutres = $_[0];

  # Exclude lock from the beep count, but not EPG grab
  if ($shutres & 0x10) { $shutres -= 16; }

  # Shutting down: normal beep
  # Not shutting down: medium-then-low beep
  if ($shutres == 0 || $shutres == 4) { `beep`; }
  else { `beep -f 380 -l 150; sleep 0.05; beep -f 310 -l 180`; }

  # Wait a while then beep the number of times in the result
  `sleep 0.2`;

  # More than 15 results in a single long beep
  if ($shutres > 15) { `beep -l 800`; }
  else { for ($i=0; $i<$shutres; $i++) { `beep -l 200; sleep 0.2`; } }
  exit;
 }
 return $pid;
}

# Obtain date of a string like "14:27:00"
sub dateof
{
 my $str = $_[0];
 chomp $str;
 $str =~ s/,//g;
 my $dateof = `date '+%a %b %d %X' -d '$str'`;
 chomp $dateof;
 return $dateof;
}

# Obtain date of an offset string like "4 hours, 27 minutes"
sub dateof_offset
{
 my $str = $_[0];
 chomp $str;
 $str =~ s/,//g;
 my $dateof = `date '+%a %b %d %X' -d '+ $str'`;
 chomp $dateof;
 return $dateof;
}

# Obtain next recording time from mythtv-status
sub nextrec
{
 my $next_rec = `mythtv-status 2>&1|grep -i '^Next Recording In:'|sed -e 's/.*: //'`;
 chomp $next_rec;
 #print "nextrec: next_rec is " . $next_rec . "\n";
 return $next_rec;
}

# Set the alarm to wake the system up 5 minutes before the next recording
sub setwakeup
{
 my $next_rec = $_[0];
 chomp $next_rec;
 $next_rec =~ s/,//g;
 my $next_wakeup_time_t = `date '+%s' -d '+ $next_rec - 5 minutes'`;
 chomp $next_wakeup_time_t;
 my $next_wakeup = `date '+%a %b %d %X' -d '\@$next_wakeup_time_t'`;
 chomp $next_wakeup;
 #print "setwakeup: wakeup at " . $next_wakeup . " (time_t: " . $next_wakeup_time_t . ")\n";
 `sudo /usr/bin/setwakeup.sh $next_wakeup_time_t`;
 return $next_wakeup;
}

# How long until the specified time (eg. 15:00:00 might be 2h45m from now)
sub timeuntil
{
 my $until = $_[0];
 chomp $until;
 $until =~ s/,//g;
 my $seconds = abs (`date '+%s' -d '$until'` - `date '+%s'`);
 @parts = gmtime($seconds);
 my $timeuntil;
 if ($parts[7] != 0) { $timeuntil .= sprintf("%dd", $parts[7]); }
 if ($parts[7] != 0 || $parts[2] != 0) { $timeuntil .= sprintf("%dh", $parts[2]); }
 if ($parts[7] != 0 || $parts[1] != 0) { $timeuntil .= sprintf("%dm", $parts[1]); }
 if ($parts[7] != 0 || $parts[0] != 0 || $seconds == 0) { $timeuntil .= sprintf("%ds", $parts[0]); }
 #print "timeuntil: seconds until $until: $seconds ($timeuntil)\n";
 #printf("%dd%dh%dm%ds\n",@parts[7,2,1,0]);
 return $timeuntil;
}

# Obtain what is recording from mythtv-status
sub recording
{
 # -A10 allows up to 10 shows to be returned
 my $recording = `mythtv-status 2>&1|grep -A10 '^Recording Now:'|grep -v '^Recording Now:'|sed -e '/^\$/q'|sed -e '/^\$/d' -e 's/^/ - Recording: /'`;
 $recording =~ s/Ends: (.*)$/"Ends:\t" . timeuntil($1) . " (" . dateof($1) . ")"/eg;
 return $recording;
}

# shutdown.pl : Check mythshutdown -s and shutdown if possible
my $shutres = `/usr/bin/mythshutdown -s; echo \$?`;
print "mythshutdown status: " . $shutres . "\n";

# Convert status code to a message to be printed later
my $status;
if ($shutres == 0) { $status = " - Nothing running - shutdown OK\n"; }
if ($shutres == 255) { $status .= " - Setup is running\n"; }
if ($shutres & 0x1) { $status .= " - Currently transcoding a recording\n"; }
if ($shutres & 0x2) { $status .= " - Currently commercial flagging\n"; }
if ($shutres & 0x4) { $status .= " - Currently grabbing EPG data\n"; }
if ($shutres & 0x8) { $status .= recording(); }
if ($shutres & 0x10) { $status .= " - Shutdown has been locked\n"; }
if ($shutres & 0x20) { $status .= " - System has queued or pending jobs\n"; }
if ($shutres & 0x40) { $status .= " - System is in a daily wakeup period\n"; }
if ($shutres & 0x80) { $status .= " - Daily wakeup period starts 15 minutes from now or less\n"; }
chomp $status;

# Grabbing EPG data doesn't prevent shutdown, it runs often enough.
# We are forcing shutdown via remote control button so ignore lock.
if ($shutres == 0 || $shutres == 4 || $shutres == 16 || $shutres == 20)
{
 my $next_rec = nextrec();
 my $next_rec_date = dateof_offset($next_rec);
 my $until_next_rec = timeuntil($next_rec);
 my $next_wakeup = setwakeup($next_rec);
 my $until_next_wakeup = timeuntil($next_wakeup);
 my $message = "Next recording:\t\t" . $until_next_rec . " (" . $next_rec_date . ")\nSystem will wake up:\t" . $until_next_wakeup . " (" . $next_wakeup . ")\nShutting down.";
 if ($shutres & 0x4) { $message .= "\n(Stopping running EPG grabber)"; }
 if ($shutres & 0x10) { $message .= "\n(Ignoring active shutdown lock)"; }
 my $beep_pid = beep($shutres);
 my $showmsg_pid = showmsg($message);
 #print "waiting for beep pid $beep_pid\n";
 waitpid($beep_pid, 0);
 #print "waiting for showmsg pid $showmsg_pid\n";
 waitpid($showmsg_pid, 0);
 `sudo /sbin/shutdown -h now`;
}
else
{
 my $message = "Unable to shut down because:\n" . $status;
 my $beep_pid = beep($shutres);
 my $showmsg_pid = showmsg($message);
 #print "waiting for beep pid $beep_pid\n";
 waitpid($beep_pid, 0);
 #print "waiting for showmsg pid $showmsg_pid\n";
 waitpid($showmsg_pid, 0);
}
