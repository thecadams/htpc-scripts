#!/usr/bin/perl -w
# tvcsv.pl
# An attempt at a script to use to catalogue all my episodes and download fanart/posters, using data from TTVDB.
# Superceded in the end by built in metadata facilities in XBMC and mythfrontend.

require "../SimpleObject.pm";
use XML::Parser;

# Download en.xml for the show, supplied from first parameter
unless (-e "en.xml")
{
 $showid = $ARGV[0] or die "en.xml not found; must supply TheTVDB show ID as first parameter to perform download";
 `wget http://www.thetvdb.com/api/3B697BB39A78973B/series/$showid/all/en.zip`;
 `unzip en.zip`;
 `rm actors.xml`;
 `rm banners.xml`;
 unless (-e "en.xml")
 {
  die "still didn't find en.xml";
 }
 `rm en.zip`;
}

# Parse episode data from ttvdb en.xml
my $parser = new XML::Parser(ErrorContext => 2, Style => "Tree");
my $xmlobj = new XML::SimpleObject($parser->parsefile("en.xml"));
my %ttvdb = ();
foreach ($xmlobj->child("Data")->child("Episode"))
{
 #print $_->child("SeasonNumber")->value . "-" . $_->child("EpisodeNumber")->value . ": " . $_->child("EpisodeName")->value . "\n";
 $ttvdb{$_->child("SeasonNumber")->value . "-" . $_->child("EpisodeNumber")->value} = $_->child("EpisodeName")->value;
 $ttvdb{$_->child("SeasonNumber")->value . "-" . $_->child("EpisodeNumber")->value} =~ s/,/\\,/g;
}

#foreach (keys %ttvdb)
#{
# print $_ . ": " . $ttvdb{$_} . "\n";
#}

# Read the files and generate a CSV
# NOTE: The sed here strips out files in the show directory
@files = `find . -type f|grep -v .srt\$|sed -e "/^.\\/[^/]*\$/d"`;

open CSVFILE,">episodes.csv";

print CSVFILE "file,show,season,episode,title,ttvdbtitle\n";

foreach (@files)
{
 $file = $_; chomp $file;
 $file =~ s/,/\\,/g;
 my $season;
 my $title;
 if ($file =~ m@^..Season.([^/]*)/(.*)@)
 {
  $season = $1;
  $title = $2;
 }
 if ($file =~ m@^..Specials/(.*)@)
 {
  $season = 0;
  $title = $1;
 }
 $show = `pwd|sed -e s@.*/@@`; chomp $show;
 $showregex = `pwd|sed -e s@.*/@@ -e 's/ /./g'`; chomp $showregex;
 $title =~ s/$showregex//i;
 
 # Recognize "Seriess.eofn", ".see.", "- see", sxee and SsEee formats
 if ($title =~ m/([0-9][0-9]?)x([0-9][0-9])/ ||
  $title =~ m/S([0-9][0-9]?)-?Ep?([0-9][0-9]?)/i ||
  $title =~ m/-[. ]([0-9])([0-9][0-9])/ ||
  $title =~ m/\.?([0-9][0-9]?)([0-9][0-9])\.?/ ||
  $title =~ m/Series([0-9][0-9]?)\.([0-9][0-9]?)of[0-9][0-9]?/)
 {
  $tseason = $1;
  $tepisode = $2;
  $title =~ s/${tseason}x$tepisode//;
  $title =~ s/S${tseason}-?Ep?$tepisode//i;
  $title =~ s/-[. ]${tseason}${tepisode}//;
  $title =~ s/\.?${tseason}${tepisode}\.?//;
  $title =~ s/Series([0-9][0-9]?)\.([0-9][0-9]?)of[0-9][0-9]?//;
  $tseason =~ s/^0*//;
  $tepisode =~ s/^0*//;
  if ($tseason != $season)
  {
   die "Incorrect season number (expected $season, saw $tseason, episode $tepisode) in file: $file";
  }
 }

 $title =~ s/\.en//;
 $title =~ s/dvdrip//i;
 $title =~ s/xvid//i;
 $title =~ s/divx//i;
 $title =~ s/\.avi$//i;
 $title =~ s/\.mpg$//i;
 $title =~ s/\.mpeg$//i;
 $title =~ s/hdtv//i;
 $title =~ s/FoV//;
 $title =~ s/BiA//;
 $title =~ s/\[digitaldistractions\]//;
 $title =~ s/\.ShareReactor//;
 $title =~ s/\[dd\]//;
 $title =~ s/\.MP3//;
 $title =~ s/-SYS//;
 $title =~ s/-CRiMSON//;
 $title =~ s/-OBAMA//;
 $title =~ s/REPACK//;
 $title =~ s/\[BT\]//;
 $title =~ s/\[VTV\]//;
 $title =~ s/\.dsr//;
 $title =~ s/\.iht//;
 $title =~ s/\[RavyDavy\]?//;
 $title =~ s/-VFUA//;
 $title =~ s/-NoTV//;
 $title =~ s/-D734//;
 $title =~ s/\.TVRip//i;
 $title =~ s/\.WS//;
 $title =~ s/-SiTV//;
 $title =~ s/-river//i;
 $title =~ s/\.ws//;
 $title =~ s/-LBP//;
 $title =~ s/\[MM\]//;
 $title =~ s/PREAIR//;
 $title =~ s/-aAF//;
 $title =~ s/-0TV//;
 $title =~ s/DVDScr//;
 $title =~ s/vostfr//i;
 $title =~ s/.FV//;
 $title =~ s/-NOTYOU//;
 $title =~ s/-lol//i;
 $title =~ s/-caph//;
 $title =~ s/-xor//i;
 $title =~ s/-DOT//i;
 $title =~ s/-2HD//i;
 $title =~ s/pdtv//i;
 $title =~ s/ac3//i;
 $title =~ s/-sfm//;
 $title =~ s/\[?-fov\]?//;
 $title =~ s/-YoungDangerous//i;
 $title =~ s/\-$//;
 $title =~ s/[._ ]+/ /g;
 $title =~ s/^[._ ]*//;
 $title =~ s/[._ ]*$//;
 $title =~ s/^- *//;
 
 #print "show: " . $show . "\n";
 #print "season: " . $season . "\n";
 #print "title: " . $title . "\n";
 $line = $file . "," . $show . "," . $season . "," . $tepisode . "," . $title . "," . $ttvdb{$season."-".$tepisode} . "\n";
 print CSVFILE $line;
 
 if ($file =~ m/[^\\],/)
 {
  die "Unescaped comma in file: $file";
 }
 if ($title =~ m/[^\\],/)
 {
  die "Unescaped comma in title: $title";
 }
 if ($ttvdb{$season."-".$tepisode} =~ m/[^\\],/)
 {
  die "Unescaped comma in TheTVDB episode name: " . $ttvdb{$season."-".$tepisode};
 }
}
