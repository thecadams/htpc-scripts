#!/usr/bin/perl
use Getopt::Long;

my $g_popuptext;

my $NOUPCOMING = "Never";
my $NOUPCOMINGWAKEUP = "5 days";

sub parse_options {
 my %opts = ();
 GetOptions(
  'check'=>\$opts{check},
  'popup'=>\$opts{popup},
  'ignore-not-idle'=>\$opts{ignorenotidle},
  'ignore-locked'=>\$opts{ignorelocked},
  'ignore-epg'=>\$opts{ignoreepg},
  'ignore-login'=>\$opts{ignorelogin});
 return %opts;
}

sub get_state {
 my %state = ();
 # lircidle.py is a daemon that pretends to be mythtv to lirc.
 # If it's already running as a daemon, it connects to itself to report the time since lirc told it about input.
 # If it's not running it prints 0 and daemonizes itself.
 $state{lircidle}=`/home/myth/scripts/lircidle.py | sed -e 's/\\..*\$//'`;
 my $xsessions=`w|awk '\$3~/^:/{print \$3}'`;
 split(/\n/, $xsessions);
 $state{xidle} = ();
 foreach ($xsessions) {
  chomp;
  $state{xidle}{$_}=`DISPLAY=$_ /home/myth/scripts/xidle | sed -e 's/\\..*\$//'`;
  $state{xidle}{$_} =~ s/[\r\n]//g;
  $state{xidle}{$_} =~ s/\s+$//g;
 }
 $state{lastmythweb}=`grep /mythweb/ /var/log/apache2/access.log|tail -n 1|sed -e 's/.*\\[\\(.*\\)\\].*/\\1/' -e "s\@/\@-\@g" -e "s/-\$(date +%Y):/-\$(date +%Y) /"`;
 if ($state{lastmythweb} ne "") {
  $state{mythwebidle} = `date '+%s'` - `date '+%s' -d "$state{lastmythweb}"`;
 }
 $state{nummythfrontend}=`ps -ef | grep '/usr/bin/mythfrontend.real' | grep -v grep|wc -l`;
 if ($state{nummythfrontend} == 1) {
  $state{mythlocation}=`echo "query location\\nexit"|nc localhost 6546|sed -e 's/^# //'|tail -n1|awk '{print \$1,\$2}'`;
 }
 $state{numfirefox}=`ps -ef | grep '/usr/bin/firefox-3.5' | grep -v grep|wc -l`;
 $state{numxbmc}=`ps -ef | grep 'xbmc.bin' | grep -v grep|wc -l`;
 $state{xbmclocation}=`curl http://127.0.0.1:8080/xbmcCmds/xbmcHttp?command=GetCurrentlyPlaying 2>/dev/null|tr -d '\n\r'`;
 $state{numlogins}=`w|sed -e '/^USER/d' -e '/load average/d'|awk '\$3 !~ /^:[0-9]/'|wc -l`;
 $state{numscreen}=`ps -ef | grep 'SCREEN' | grep -v grep|wc -l`;
 $state{numtransmission}=`ps -ef | grep '/usr/bin/transmission-daemon' | grep -v grep|wc -l`;
 if ($state{numtransmission} == 1) {
  $state{transnumdl}=`transmission-remote -l|sed -e 's/   */#/g'|awk -F# '{print \$9}'|tail -n +2|grep -v Stopped|grep -v Seeding|grep -v Idle|sed -e '/^\$/d'|wc -l`;
 }
 $state{numsqueeze}=`/home/myth/scripts/squeezeplayers.pl|egrep -v 'mode: (stop|pause)'|wc -l`;
 $state{samba}=`sudo /usr/bin/smbstatus -v|grep '^No locked files\$' > /dev/null;echo \$?`;
 $state{mythshutdown}=`mythshutdown -s;echo \$?`;
 $state{nextrec}=`mythtv-status 2>&1|grep -i '^Next Recording In:'|sed -e 's/.*: //'|sed -e s/,//`;
 $state{nextrecsec}=`date '+%s' -d "+ $state{nextrec}"` - `date '+%s'`;
 foreach (keys %state) {
  $state{$_} =~ s/[\r\n]//g;
  $state{$_} =~ s/\s+$//g;
 }
 return %state;
}

sub pr {
 my $str = shift;
 print (`echo \$(date '+%F %T.%N'|cut -c-23) \$(basename '$0'): "$str"`);
}

sub check_cond {
 my $str = shift;
 my $cond = shift;
 pr(($cond ? "(OK) " : "(prevents shutdown) "). $str);
 if ($cond) {
  return 0;
 }
 $g_popuptext .= " - $str\n";
 return 1;
}

sub check_cond_f {
 my $false_str = shift;
 my $cond = shift;
 if ($cond) {
  return 0;
 }
 pr("(prevents shutdown) $false_str");
 $g_popuptext .= " - $false_str\n";
 return 1;
}

sub check_cond_t {
 my $true_str = shift;
 my $cond = shift;
 if ($cond) {
  pr("(OK) $true_str");
  return 0;
 }
 return 1;
}

sub check_cond_tf {
 my $true_str = shift;
 my $false_str = shift;
 my $cond = shift;
 if ($cond) {
  pr("(OK) $true_str");
  return 0;
 }
 pr("(prevents shutdown) $false_str");
 $g_popuptext .= " - $false_str\n";
 return 1;
}

# Check to see if the system is idle. Return 0 if so and 1 if not.
sub determine_exit_code {
 my %opts = %{$_[0]};
 my %state = %{$_[1]};
 my $ret = 0;
 my $idlesec = 900; # 15 minutes
 my $idlestr = "15 mins";

 if (check_cond_f("Setup is running", $state{mythshutdown} != 255)) { $ret = 1; }
 if (check_cond_f("Currently transcoding a recording", !($state{mythshutdown} & 0x1))) { $ret = 1; }
 if (check_cond_f("Currently commercial flagging", !($state{mythshutdown} & 0x2))) { $ret = 1; }
 if (!$opts{ignoreepg}) {
  if (check_cond_f("Currently grabbing EPG data", !($state{mythshutdown} & 0x4))) { $ret = 1; }
 }
 if (check_cond_f(recording(), !($state{mythshutdown} & 0x8))) { $ret = 1; }
 if (!$opts{ignorelocked}) {
  if (check_cond_f("Shutdown has been locked", !($state{mythshutdown} & 0x10))) { $ret = 1; }
 }
 if (check_cond_f("System has queued or pending jobs", !($state{mythshutdown} & 0x20))) { $ret = 1; }
 if (check_cond_f("System is in a daily wakeup period", !($state{mythshutdown} & 0x40))) { $ret = 1; }
 if (check_cond_f("Daily wakeup period starts 15 minutes from now or less", !($state{mythshutdown} & 0x80))) { $ret = 1; }
 if (!$opts{ignorenotidle}) {
  if (check_cond_tf(
   "$state{lircidle} sec since last remote-control buttonpress",
   "Less than $idlestr since remote used ($state{lircidle} sec)",
   $state{lircidle} > $idlesec)) { $ret = 1; }
  foreach (keys %{$state{xidle}}) {
   if (check_cond_tf(
    "Display $_ input idle for $state{xidle}{$_} sec",
    "Less than $idlestr since keyboard/mouse used ($state{xidle}{$_} sec)",
    $state{xidle}{$_} > $idlesec)) { $ret = 1; }
  }
  if ($state{lastmythweb} ne "") {
   if (check_cond_tf(
    "$state{mythwebidle} sec since last mythweb use",
    "Less than $idlestr since last mythweb use ($state{mythwebidle} sec)",
    $state{mythwebidle} > $idlesec)) { $ret = 1; }
  }
 }
 if (check_cond("$state{nummythfrontend} mythfrontend process" . ($state{nummythfrontend}==1?"":"es") . " running", $state{nummythfrontend} == 0 || $state{nummythfrontend} == 1)) { $ret = 1; }
 if (!$opts{ignorenotidle} && $state{nummythfrontend} == 1 && check_cond_tf(
  "Mythfrontend location is $state{mythlocation}",
  "Mythfrontend is playing a show",
  index($state{mythlocation}, "Playback Recorded") == -1 &&
  index($state{mythlocation}, "playdvd") == -1 &&
  index($state{mythlocation}, "guidegrid") == -1 &&
  index($state{mythlocation}, "Playback LiveTV") == -1)) {
  $ret = 1;
 }
 if (check_cond("$state{numxbmc} XBMC process" . ($state{numxbmc}==1?"":"es") . " running", $state{numxbmc} == 0 || $state{numxbmc} == 1)) { $ret = 1; }
 if (!$opts{ignorenotidle} && $state{numxbmc} == 1 && check_cond_tf(
  "XBMC location is $state{xbmclocation}",
  "XBMC is playing a show",
  index($state{xbmclocation}, "[Nothing Playing]") != -1)) {
  $ret = 1;
 }
 if (check_cond("$state{numfirefox} firefox process" . ($state{numfirefox}==1?"":"es") . " running", $state{numfirefox} == 0)) { $ret = 1; }
 if (!$opts{ignorenotidle}) {
  if (check_cond_f("Neither mythfrontend nor XBMC are running", $state{nummythfrontend} == 1 || $state{numxbmc} == 1)) { $ret = 1; }
 }
 if (!$opts{ignorelogin}) {
  if (check_cond("$state{numlogins} user" . ($state{numlogins}==1?"":"s") . " logged in from non-X sessions", $state{numlogins} == 0)) { $ret = 1; }
  if (check_cond("$state{numscreen} screen process" . ($state{numscreen}==1?"":"es") . " running", $state{numscreen} == 0)) { $ret = 1; }
 }
 if ($state{numtransmission} == 1) {
  if (check_cond("$state{transnumdl} torrent" . ($state{transnumdl}==1?"":"s") . " downloading in transmission", $state{transnumdl} == 0)) { $ret = 1; }
 }
 if (check_cond("$state{numsqueeze} squeezeplayer" . ($state{numsqueeze}==1?"":"s") . " playing music", $state{numsqueeze} == 0)) { $ret = 1; }
 if (check_cond_tf("No active samba sessions","Active samba session(s)", $state{samba} == 0)) { $ret = 1; }
 if (check_cond_t("No upcoming recordings", $state{nextrec} eq $NOUPCOMING) && check_cond_tf("Next recording in $state{nextrecsec} seconds", "Next recording in less than 5 minutes ($state{nextrecsec} sec)", $state{nextrecsec} > 300)) { $ret = 1; }
 return $ret;
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
 return $timeuntil;
}

sub dateof
{
 my $str = $_[0];
 chomp $str;
 $str =~ s/,//g;
 my $dateof = `date '+%a %b %d %X' -d '$str'`;
 chomp $dateof;
 return $dateof;
}

# Obtain what is recording from mythtv-status
sub recording
{
 # -A10 allows up to 10 shows to be returned
 my $recording = `mythtv-status 2>&1|grep -A10 '^Recording Now:'|grep -v '^Recording Now:'|sed -e '/^\$/q'|sed -e '/^\$/d' -e 's/^/ - Recording: /'`;
 $recording =~ s/Ends: (.*)$/"Ends:\t" . timeuntil($1) . " (" . dateof($1) . ")"/eg;
 return $recording;
}

sub dateof_offset
{
 my $str = $_[0];
 chomp $str;
 $str =~ s/,//g;
 my $dateof = `date '+%a %b %d %X' -d '+ $str'`;
 chomp $dateof;
 return $dateof;
}

sub nextrec
{
 my $next_rec = `mythtv-status 2>&1|grep -i '^Next Recording In:'|sed -e 's/.*: //'`;
 chomp $next_rec;
 return $next_rec;
}

sub setwakeup
{
 my $next_rec = nextrec();
 chomp $next_rec;
 $next_rec =~ s/,//g;
 my $next_wakeup_time_t = `date '+%s' -d '+ $NOUPCOMINGWAKEUP'`;
 if ($next_rec ne $NOUPCOMING) {
  $next_wakeup_time_t = `date '+%s' -d '+ $next_rec - 5 minutes'`;
 }
 chomp $next_wakeup_time_t;
 my $next_wakeup = `date '+%a %b %d %X' -d '\@$next_wakeup_time_t'`;
 chomp $next_wakeup;
 `sudo /usr/bin/setwakeup.sh $next_wakeup_time_t`;
 return $next_wakeup;
}

sub build_popup_text {
 my %opts = %{$_[0]};
 my %state = %{$_[1]};
 my $exitcode = $_[2];

 my $message = "";
 if ($opts{check}) {
  $message .= "Shutdown check:\n";
 }
 if (shutdown_ok($exitcode)) {
  my $next_rec = nextrec();
  $message .= "Next recording:\t\t";
  if ($next_rec eq $NOUPCOMING) {
   $message .= "None";
  } else {
   my $next_rec_date = dateof_offset($next_rec);
   my $until_next_rec = timeuntil($next_rec);
   $message .= $until_next_rec . " (" . $next_rec_date . ")";
  }

  my $next_wakeup = setwakeup();
  my $until_next_wakeup = timeuntil($next_wakeup);
  $message .= "\nSystem will wake up:\t" . $until_next_wakeup . " (" . $next_wakeup . ")";
  if ($opts{check}) {
   $message .= "\nSafe to shut down.";
  } else {
   $message .= "\nShutting down.";
  }
  if ($state{mythshutdown} & 0x4) { $message .= "\n(Stopping running EPG grabber)"; }
  if ($state{mythshutdown} & 0x10) { $message .= "\n(Ignoring active shutdown lock)"; }
 } else {
  chomp $g_popuptext;
  $message .= "Unable to shut down because:\n" . $g_popuptext;
 }
 return $message;
}

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

sub show_popup {
 my $message = shift;
 my $beep_pid = beep($shutres);
 my $showmsg_pid = showmsg($message);
 waitpid($beep_pid, 0);
 waitpid($showmsg_pid, 0);
}

sub shutdown_ok {
 my $exitcode = shift;
 if ($exitcode == 0) {
  pr("Ok to shut down, shutting down");
  return 1;
 } else {
  pr("Not ok to shut down, preventing shutdown");
  return undef;
 }
}

sub do_shutdown {
 pr("do_shutdown");
 setwakeup();
 `sudo /sbin/shutdown -h now`;
}

if (not exists($ENV{"HOME"})) { $ENV{"HOME"}="/home/myth"; }
my %opts = parse_options();
my %state = get_state();
my $exitcode = determine_exit_code(\%opts, \%state);
if ($opts{popup} != undef) {
 show_popup(build_popup_text(\%opts, \%state, $exitcode));
}
if (shutdown_ok($exitcode) != undef && $opts{check} == undef) {
 do_shutdown(\%state);
}
exit($exitcode);
