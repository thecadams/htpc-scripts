my $zip = $PAR::LibCache{$ENV{PAR_PROGNAME}} || Archive::Zip->new(__FILE__);
my $member = eval { $zip->memberNamed('script/ppOCdkD.pl') }
        or die qq(main.pl: Can't open perl script "script/ppOCdkD.pl": No such file or directory ($zip));



PAR::_run_member($member, 1);

