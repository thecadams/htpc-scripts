#!/usr/bin/perl -w
use strict;
use Getopt::Std;
use vars qw/ $opt_d $opt_h $opt_l $opt_u /;
use POSIX qw(strftime);

###############################################################################################################################
# Prototype definitions
###############################################################################################################################

sub logmsg(@);
sub showmsg($);
sub process_opts();

sub lockmyth();
sub unlockmyth();

###############################################################################################################################
# Constant Definitions.
###############################################################################################################################

my ($TRUE) = 1;
my ($FALSE) = 0;

###############################################################################################################################
# Global vars, paths, commands to call.
###############################################################################################################################

my ($LOG) = "/home/myth/scripts/mythlock-rmtctrl.log";
my ($LOGSIZE) = 1024;
my ($DEBUG) = $FALSE;
my ($BASENAME) = $0;

my ($MYTHSTATUS)="/usr/bin/mythshutdown -s";
my ($UNLOCKMYTH)="/usr/bin/mythshutdown -u";
my ($LOCKMYTH)="/usr/bin/mythshutdown -l";

###############################################################################################################################
# The Mainline.
###############################################################################################################################
MAIN:
{
	process_opts();

	logmsg "$BASENAME started : PID($$)";
	if (not exists($ENV{"HOME"})) { $ENV{"HOME"}="/home/myth"; }
	my $mythstatus;
	`$MYTHSTATUS`;
	$mythstatus = $?>>8;
	logmsg "initial status: $mythstatus.";
	if (($mythstatus & 0x10) == 0) { lockmyth(); }
	else { unlockmyth(); }
	logmsg "$BASENAME Completed.";
}

sub lockmyth()
{
	my $mythstatus;
	for (my $i = 0; $i < 10; $i++) {
		`$MYTHSTATUS`;
		$mythstatus = $?>>8;
		logmsg "lock: try $i, result $mythstatus.";
		if (($mythstatus & 0x10) != 0) { last; }
		`$LOCKMYTH`;
	}
	if (($mythstatus & 0x10) != 0) {
		showmsg("Shutdown blocking is active.");
		return;
	}
	showmsg("Unable to activate shutdown blocking.\n" .
		"Please try again.");
}

sub unlockmyth()
{
	my $mythstatus;
	for (my $i = 0; $i < 10; $i++) {
		`$MYTHSTATUS`;
		$mythstatus = $?>>8;
		logmsg "unlock: try $i, result $mythstatus.";
		if (($mythstatus & 0x10) == 0) { last; }
		`$UNLOCKMYTH`;
	}
	if (($mythstatus & 0x10) == 0) {
		showmsg("Shutdown blocking deactivated.");
		return;
	}
	showmsg("Unable to deactivate shutdown blocking.\n" .
		"Please try again.");
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
	getopts('dluh');

	$DEBUG=$TRUE if ($opt_d);	
	exit(usage(1)) if ($opt_h || ($opt_l && $opt_u));
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
		print "Usage: $BASENAME [-dhlu]\n";
		print "\t-d\t\tdebug\n";
		print "\t-h\t\tprints this help message\n";
		return(0);
	}
}
