#!/usr/bin/perl -w
###############################################################################################################################
## Name: appswitch.pl
##
## Purpose: Executed by irexec this script will cycle between mythtv and xbmc using a single button.
##	
## (C)opyright 2008 Arksoft.
##									                           
## Author: Arkay
## 
## Ver 1.0: 4-08-2008.	Initial version.
## 
###############################################################################################################################
# Require and Use Clauses.
###############################################################################################################################

use strict;				#Keeps code neat.
use Getopt::Std;			#Getopt module for option preprocessing.
use vars qw/ $opt_d $opt_h $opt_f $opt_x /;	#Option Processing vars.
use POSIX qw(strftime);			#Time routine we need.

###############################################################################################################################
# Prototype definitions
###############################################################################################################################

sub logmsg(@);		#Message logger so we can track what's been going on.
sub showmsg($);		#Show a message on the screen
sub process_opts();	#Option processing.. Nothing exiting for this script.
sub do_command($);	#Execute a shell command for lazy perl programmers :)
sub check_proc($);	#Check if a process is running.
sub startproc($);

sub startmyth();
sub startfirefox();
sub startxbmc();
sub killapps($$$);

###############################################################################################################################
# Constant Definitions.
###############################################################################################################################

my ($TRUE) = 1;
my ($FALSE) = 0;

###############################################################################################################################
# Global vars, paths, commands to call.
###############################################################################################################################

my ($LOG) = "/home/myth/scripts/appswitch.log";						#Log location.
my ($LOGSIZE) = 1024;								#Maximum log size in kbytes, self pruning.
my ($DEBUG) = $FALSE;								#Debugging default is off.
my ($BASENAME) = $0;								#How was the program called?
my ($OPT_FIREFOX) = $FALSE;							#Force firefox
my ($OPT_FIREFOX_URL) = "";							#Firefox URL
my ($OPT_XBMC) = $FALSE;							#Force XBMC

my ($MYTHTV)="/usr/bin/mythfrontend";						#Process name to start
my ($FIREFOX)="/usr/bin/firefox-3.5";						#Process name to start
my ($XBMC)="/usr/bin/xbmc";							#Process name to start
my ($IRXEVENT)="/usr/bin/irxevent";						#Extra event handling for firefox
my ($RCMKB)="/home/myth/src/rcmkb/rcmkb.py";					#Mouse emulation for firefox
my ($KMYTHTV)="mythfrontend.real";						#Process name to use with killall
my ($KFIREFOX)="firefox";							#Process name to use with killall
my ($KXBMC)="xbmc.bin";								#Process name to use with killall 
my ($KMPLAYER)="mplayer";							#Also kill any external players
my ($KIRXEVENT)="irxevent";							#Extra event handling for firefox
my ($KRCMKB)="rcmkb.py";							#Mouse emulation for firefox
my ($PKILL)="/usr/bin/pkill";							#pkill command.
my ($KILLALL)="/usr/bin/killall";						#kill command.
my ($AUDIOHACK)="/usr/bin/iecset audio on";					#Shitty Alsa hack with intel HDA
my ($UNLOCKMYTH)="/usr/bin/mythshutdown -u";					#Hack to allow backend shutdown when exit XBMC
my ($LOCKMYTH)="/usr/bin/mythshutdown -l";					#Disallow myth from shutting down while in firefox
my ($SET_LOW_RES)="/usr/bin/xrandr -d :0 -s 1280x720";				#Lower resolution for firefox
my ($SET_HIGH_RES)="/usr/bin/xrandr -d :0 -s 1920x1080";			#Higher resolution for mythfrontend

###############################################################################################################################
# The Mainline.
###############################################################################################################################
MAIN:
{
	my ($command);
	process_opts();

	logmsg "$BASENAME started : PID($$)";

	my ($myth)=check_proc($MYTHTV);
	my ($firefox)=check_proc($FIREFOX);
	my ($xbmc)=check_proc($XBMC);

	killapps($myth,$firefox,$xbmc);
	if ($OPT_FIREFOX == $TRUE) { startfirefox(); }
	elsif ($OPT_XBMC == $TRUE) { startxbmc(); }
	elsif ($myth == $TRUE) { startfirefox(); }
#	elsif ($firefox == $TRUE) { startxbmc(); }
	elsif ($firefox == $TRUE) { startmyth(); }
	elsif ($xbmc == $TRUE) { startmyth(); }
	else { startmyth(); }

	logmsg "$BASENAME Completed.";
}

sub startmyth()
{
	#do_command($SET_HIGH_RES);
	startproc("su -c \"$MYTHTV --service\" myth");
}

sub startfirefox()
{
	#do_command($LOCKMYTH);
	#do_command($SET_LOW_RES);
	do_command("$IRXEVENT -d");
	do_command("export DISPLAY=:0 ; su -c \"$RCMKB &>/home/myth/src/rcmkb/rcmkb.log &\" myth");
	showmsg("Press \"TV\" button to go back to menu.\n" .
		"Arrows as mouse,\n" .
		"ok=left-click, start=right-click,\n" .
		"channel buttons for scroll.");
	startproc("su -c \"$FIREFOX $OPT_FIREFOX_URL\" myth");
}

sub startxbmc()
{
	#do_command($LOCKMYTH);
	#do_command($SET_HIGH_RES);
	showmsg("Press \"TV\" button to go back to menu.");
	startproc("export XBMC_PLATFORM_MODE=1 ; su -c \"$XBMC\" myth");
}

sub killapps($$$)
{
	my $myth=shift;
	my $firefox=shift;
	my $xbmc=shift;
	my ($command);

	if ($myth == $TRUE)
	{
		logmsg "Killing $MYTHTV"; 
		$command="$KILLALL $KMYTHTV"; do_command($command);
		$command="$KILLALL $KMPLAYER"; do_command($command);
	}
	if ($firefox == $TRUE)
	{
		logmsg "Killing $FIREFOX";
		$command="$KILLALL $KFIREFOX"; do_command($command);
	}
	if ($xbmc == $TRUE)
	{
		logmsg "Killing $XBMC"; 
		$command="$KILLALL $KXBMC"; do_command($command);
	}

	sleep(0.5);
	$myth=check_proc($MYTHTV);
	$firefox=check_proc($FIREFOX);
	$xbmc=check_proc($XBMC);

	if ($myth == $TRUE || $firefox == $TRUE || $xbmc == $TRUE)
	{
		sleep(2);
	}

	if ($myth == $TRUE)
	{
		$myth=check_proc($MYTHTV);
		if ($myth == $TRUE)
		{
			logmsg "Killing $MYTHTV (forced)"; 
			$command="$KILLALL -9 $KMYTHTV"; do_command($command);
			$command="$KILLALL -9 $KMPLAYER"; do_command($command);
		}
	}
	if ($firefox == $TRUE)
	{
		$firefox=check_proc($FIREFOX);
		if ($firefox == $TRUE)
		{
			logmsg "Killing $FIREFOX (forced)";
			$command="$KILLALL -9 $FIREFOX"; do_command($command);
		}
	}
	if ($xbmc == $TRUE)
	{
		$xbmc=check_proc($XBMC);
		if ($xbmc == $TRUE)
		{
			logmsg "Killing $XBMC (forced)"; 
			$command="$KILLALL -9 $KXBMC"; do_command($command);
		}
	}

	$command="$KILLALL $KIRXEVENT"; do_command($command);
	$command="$PKILL -f $KRCMKB"; do_command($command);
	#do_command($AUDIOHACK);
	#do_command($UNLOCKMYTH);
}

###############################################################################################################################
# startproc()
# Execute a given command.
###############################################################################################################################
sub startproc($)
{
	my ($proc)=@_;
	logmsg "Starting $proc"; 
	exec("export DISPLAY=:0; $proc &");
}

###############################################################################################################################
# check_proc($)
# Check if processes are running that should stop shutdown from occuring.
###############################################################################################################################
sub check_proc($)
{
	my ($proc)=@_;
	my (@output);
	my ($command);
	my ($count)=0;
	my ($running)=$FALSE;

	logmsg "Checking for active process $proc.";

	$command="ps -ef | grep \"$proc\" | grep -v grep |wc -l";	
	@output=do_command($command);

	if (@output)
	{
		$count=$output[0];
		chomp ($count);
	}

	if ($count > 0)
	{
		logmsg "Found active process : $proc ($count running).";
		$running=$TRUE;
	}
	return($running);
}

###############################################################################################################################
# showmsg
# Fork and show a message on the TV to tell the user what the system will do
###############################################################################################################################
sub showmsg($)
{
 my ($pid);
 unless ($pid = fork())
 {
  # Child process
  sleep(2);
  my ($msg) = shift;
  logmsg "Display message: " . $msg . "\n(showing for 6 sec..." if ($DEBUG == $TRUE);
  `gxmessage -display :0 -timeout 6 -borderless -fn "URW Chancery L 48" -buttons '' -bg black -fg gray "$msg" &`;
  logmsg "finished)\n" if ($DEBUG == $TRUE);
  exit;
 }
 return $pid;
}

###############################################################################################################################
# logmsg
# Little routine to write to the log file.
# Rotates around $LOGSIZE bytes.
###############################################################################################################################
sub logmsg(@)
{ 
	my ($string)=@_;
	my $time=scalar localtime;
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks);
	my (@lines,$line);

	($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks)=stat("$LOG");

	if (defined($size))
	{
		$size=$size/1024;				#size in kbyte

		if ($size >= $LOGSIZE)
		{
			unlink ("$LOG.old") if (-e("$LOG.old"));
			rename ($LOG,"$LOG.old");
		}
	}

	print "$time : $string\n" if ($DEBUG==$TRUE);

	if (open (LOG,">>$LOG"))
	{
		if ($string =~ /\n/)
		{
			@lines=split(/\n/,$string);
			foreach $line (@lines)
			{
				print LOG "$time : $line\n"; 
			}
		}
		else
		{
				print LOG "$time : $string\n"; 
		}
		close (LOG);
	}
	else
	{
		print "Unable to open LOG $LOG : $!";
	}
}

###############################################################################################################################
# process_opts()
# Set Global option flags dependant on command line input.
###############################################################################################################################
sub process_opts()
{
	getopts('dhxf:');

	$DEBUG=$TRUE if ($opt_d);	
	exit(usage(1)) if ($opt_h || ($opt_x && $opt_f));
	$OPT_XBMC=$TRUE if ($opt_x);
	if ($opt_f)
	{
		$OPT_FIREFOX=$TRUE;
		$OPT_FIREFOX_URL=$opt_f;
	}
}

###############################################################################################################################
# usage()
# Output Relevant Usage strings if incorrect opts are given.
###############################################################################################################################
sub usage()
{
	my($ucode)=@_;

	if ($ucode == 1) 
	{
		print "Usage: $BASENAME [-dhxf] [firefox URL]\n";
		print "\t-d\t\tdebug\n";
		print "\t-h\t\tprints this help message\n";
		print "\t-x\t\tswitch to XBMC\n";
		print "\t-f [firefox URL]\tswitch to Firefox\n";
		return(0);
	}
}

###############################################################################################################################
# sub do_command($)
# use system call to execute command. Returns output of command in array.
###############################################################################################################################
sub do_command($)
{
    my ($command)=@_;
    my (@output);
    my ($exit_value)=0;

    logmsg "Executing $command" if ($DEBUG == $TRUE);

    @output=`$command`; 

    $exit_value = $? >> 8;

    if ($exit_value != 0)
    {
        logmsg "Error executing $command : $!";
    }
    return(@output);
}
