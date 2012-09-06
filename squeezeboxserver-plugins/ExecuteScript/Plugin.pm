#line 1 "Plugins/ExecuteScript/Plugin.pm"
# Execute plugin by Kevin Deane-Freeman (kevindf@shaw.ca) April 2003
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.

package Plugins::ExecuteScript::Plugin;

use base qw(Slim::Plugin::Base);

use strict;

use Slim::Player::Playlist;
use Slim::Player::Source;
use Slim::Player::Sync;
use Slim::Utils::Strings qw (string);
use File::Spec::Functions qw(:ALL);
use POSIX qw(strftime);
use FindBin qw($Bin);
use Slim::Utils::Misc;
use Slim::Utils::Prefs;

use vars qw($VERSION);
$VERSION = substr(q$Revision: 2.1 $,10);

use Plugins::ExecuteScript::Settings;

my $interval = 1; # check every x seconds
my %menuSelection;
my %functions;

my $log          = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.executescript',
	'defaultLevel' => 'WARN',
	'description'  => getDisplayName(),
});

my $prefs = preferences('plugin.executescript');

sub scriptPath {
	my $scriptPath = catfile((Slim::Utils::Prefs::dir() || Slim::Utils::OSDetect::dirsFor('prefs')),'scripts');
	
	return $scriptPath;
}
my @events;
#Set to 1 for Debugging new commands.
my $debug=1;

sub getDisplayName { 'PLUGIN_EXECUTE_SCRIPT'; }

# the routines
sub setMode {
	my $class  = shift;
	my $client = shift;
	my $method = shift;

	if ($method eq 'pop') {
		Slim::Buttons::Common::popMode($client);
		return;
	}

	if (!defined($menuSelection{$client})) { $menuSelection{$client} = 0; };
	
	my %params = (
		'listRef'		  => ['PLUGIN_EXECUTE_OPEN', 'PLUGIN_EXECUTE_PLAY', 'PLUGIN_EXECUTE_STOP', 'PLUGIN_EXECUTE_POWER_ON', 'PLUGIN_EXECUTE_POWER_OFF', 'PLUGIN_EXECUTE_ON_DEMAND'],
		'stringExternRef' => 1,
		'header'		  => "PLUGIN_EXECUTE_SCRIPT",
		'stringHeader'    => 1,
		'headerAddCount'	=> 1,
		'overlayRef'      => sub { 
			return (undef, shift->symbols('rightarrow')); 
		},
		'overlayRefArgs'  => 'CV',
		'callback'		  => \&exitHandler,
		'valueRef'		  => \$menuSelection{$client},
	);
	
	Slim::Buttons::Common::pushModeLeft($client,'INPUT.List',\%params);
}

sub initPlugin {
	my $class = shift;
	
	my $prefs = preferences('plugin.executescript');
	
	%functions = (
		'execute_on_demand' => sub {
			my $client = shift;
			doThisScript($client,'on_demand');
			$client->showBriefly({'line'=>[$client->string('PLUGIN_EXECUTE_GO'),$client->string('PLUGIN_EXECUTE_ON_DEMAND')]});
		},
	);
	Slim::Control::Request::subscribe(\&commandCallbackStop, [['stop']]);
	Slim::Control::Request::subscribe(\&commandCallbackOpen, [['playlist'], ['newsong']]);
	Slim::Control::Request::subscribe(\&commandCallbackPlay, [['play']]);
	Slim::Control::Request::subscribe(\&commandCallbackPlay, [['button']]);
	Slim::Control::Request::subscribe(\&commandCallbackPower, [['power']]);
	
	Plugins::ExecuteScript::Settings->new;
	
#        |requires Client
#        |  |is a Query
#        |  |  |has Tags
#        |  |  |  |Function to call
#        C  Q  T  F
	Slim::Control::Request::addDispatch(['executescript', 'scriptmenu', '_index', '_quantity'],
	[0, 1, 1, \&scriptMenuQuery]);
	Slim::Control::Request::addDispatch(['executescript', 'doscript'],
	[0, 0, 1, \&doScriptQuery]);

	my @item = ({
		text           => Slim::Utils::Strings::string(getDisplayName()),
		id             => 'executescript',
		node           => 'extras',
		actions => {
			go =>      {
				'cmd' => ['executescript', 'scriptmenu']
			},
		},
	});

	Slim::Control::Jive::registerPluginMenu(\@item);

	$class->SUPER::initPlugin();
}

sub exitHandler {
	my ($client,$exittype) = @_;
	$exittype = uc($exittype);

	if ($exittype eq 'LEFT') {
		Slim::Buttons::Common::popModeRight($client);
		
	} elsif ($exittype eq 'RIGHT') {
	
		my $selection = $client->modeParam('listIndex');
		
		my %params = (
			'name'           => sub {return $_[1] },
			'header'         => '{PLUGIN_SELECT_SCRIPT} {count}',
			'pref'           => sub { my $scripts = $prefs->client($_[0])->get('script'); return $scripts->[ $selection ] || '(server)' },
			'onRight'        => sub { 
						my ( $client, $item ) = @_;
						
						my $scripts = $prefs->client($client)->get('script');
						$scripts->[ $selection ] = $item eq '(server)' ? '' : $item ;
						$prefs->client($client)->set('script', $scripts);
						$client->update();
			},
			'onAdd'          => sub { 
						my ( $client, $item ) = @_;
						
						my $scripts = $prefs->client($client)->get('script');
						$scripts->[ $selection  ] = $item  eq '(server)' ? '' : $item ;
						$prefs->client($client)->set('script', $scripts);
						$client->update();
			},
			'onPlay'         => sub { 
						my ( $client, $item ) = @_;
						
						my $scripts = $prefs->client($client)->get('script');
						$scripts->[ $selection  ] = $item  eq '(server)' ? '' : $item ;
						$prefs->client($client)->set('script', $scripts);
						$client->update();
						
						return unless $scripts->[ $selection  ];
						
						if (my $runScript = catfile(scriptPath(),$item)) {
							$log->info("Execute: path: ".scriptPath());
							$log->info("Execute: file: ".$runScript);
							$log->info("Execute: Executing: ".$runScript);
							$client->showBriefly({'line'=>[string('PLUGIN_EXECUTE_GO'),$runScript],'duration'=>2});
							if (Slim::Utils::OSDetect::OS ne 'win') { $runScript =~ s/ /\\ /g };
							system $runScript;
						}
			},
			'valueRef'       => sub { my $scripts = $prefs->client($_[0])->get('script'); return $scripts->[ $selection ] || '(server)'  },
			'initialValue'   => sub { my $scripts = $prefs->client($_[0])->get('script'); return $scripts->[ $selection ] || '(server)'  },
		);
	
		my %scripts = scriptlist();
		$scripts{"(none}"} = "(none)";
		$params{'listRef'} = ['(server)',keys %scripts];
		
		Slim::Buttons::Common::pushModeLeft($client, 'INPUT.Choice',\%params);
	}
}

sub getFunctions {
	return \%functions;
}

sub webPages {
	my $class = shift;

	my $title = getDisplayName();
	my $url   = 'plugins/ExecuteScript/index.html';

	Slim::Web::Pages->addPageLinks('plugins', { $title => $url });

	Slim::Web::Pages->addPageFunction($url, \&indexHandler);
}

sub saveOPML {
        my $feed = shift;
        my $fh;

	my $prefsServer = preferences('server');
        my $dir = $prefsServer->get('cachedir');
        my $file = catdir($dir, "ExecuteScript.opml");

        my $menuUrl = Slim::Utils::Misc::fileURLFromPath($file);

        $log->debug("creating infobrowser menu file: $file");
        open($fh, ">",$file);
        print $fh $feed;
        close($fh);

        return $menuUrl;
}

sub generateOPML {
	use XML::Simple;

        $log->debug('generateOPML called');

        my $self   = shift;
        my $output = '<?xml version="1.0" encoding="UTF-8"?>
<opml version="1.0">
        <head title="' . getDisplayName() . '">
        </head>
        <body>
		<outline text="' . getDisplayName() . '">';

	my $index = 1;
	my %scriptlist = scriptlist();
	for my $script (sort keys %scriptlist) {
		$output .= sprintf "\n\t\t\t<outline text=\"" . $script . "\" url=\"/plugin/ExecuteScript/index.html?item=" . $index . "\"/>";
		$index++;
	}
	$output .="\n\t</outline>\n\t</body>\n</opml>\n";

	return $output;
}

sub indexHandler
{
	my ( $client, $stash, $callback, $httpClient, $response ) = @_;
	$log->info("ExecuteScript - indexHandler called");
	$log->info("indexHandler: client: $client, stash: $stash, callback: $callback, httpClient: $httpClient, response: $response");

	if ( defined $stash->{'item'} && length( $stash->{'item'} ) ) {
		$log->info("IndexHandler called with item value " . $stash->{'item'});
		my %scriptlist = scriptlist();
		my @scripts = sort keys %scriptlist;
		if (length(@scripts[$stash->{'item'}])) {
			doScript(@scripts[$stash->{'item'}]);
		}
	}

	my $url = saveOPML(generateOPML());
	my $title = getDisplayName();
	Slim::Web::XMLBrowser->handleFeed(
		$url,
		{ args => ($client, $stash, $callback, $httpClient, $response) }
	);
}

sub scriptMenuQuery {
	my $request = shift;
	my $client = $request->client;
	$log->info("Execute: scriptMenuQuery started");

	$request->setStatusProcessing();

	my %scriptlist = scriptlist();
	my @menu;
	for my $script ( sort keys %scriptlist ) {
		$log->info("Execute: adding item $script");
		my $item = {
			text => $script,
			actions => {
				do => {
					cmd => ['executescript', 'doscript'],
					params => {'scriptpath' => $script}
				}
			}
		};
		push @menu, $item;
	}

	Slim::Control::Jive::sliceAndShip($request, $client, \@menu);
	$log->info("Execute: scriptMenuQuery finished");
}

sub doScript {
	my $runScript = shift;
	my $scriptPath = scriptPath();
	my $runScriptPath = catfile($scriptPath,$runScript);
	$log->info("Execute: Executing $runScriptPath");
	if (Slim::Utils::OSDetect::OS ne 'win') {
		$runScriptPath =~ s/([\(\) ])/\\\1/g;
		system $runScriptPath;
	} else {
		system "$runScriptPath";
	}
}

sub doScriptQuery {
	my $request = shift;
	my $client = $request->client;
	my $runScript = $request->getParam('scriptpath');

	$log->info("Execute: doScriptQuery: executing script $runScript");

	my $scriptPath = scriptPath();
	my $runScriptPath = catfile($scriptPath,$runScript);
	$log->info("Execute: Executing $runScriptPath");
	$client->showBriefly({'line'=>[string('PLUGIN_EXECUTE_GO'),$runScript]});
	if (Slim::Utils::OSDetect::OS ne 'win') {
		$runScriptPath =~ s/([\(\) ])/\\\1/g;
		system $runScriptPath;
	} else {
		system "$runScriptPath";
	}
}

sub scriptlist {

	my %scriptList = ();
	$log->info(sprintf("Execute: loading scripts from %s",scriptPath()));
	
	my @dirItems = Slim::Utils::Misc::readDirectory( scriptPath(), qr((\w+?)|\.(?:bat|cmd|pl|sh|exe|com)));
	foreach my $script ( @dirItems ) {
		# reject CVS and html directories
		next if $script =~ /^(?:cvs|html)$/i;
		$log->info("Execute:	  found $script");
		$scriptList{$script} = Slim::Utils::Misc::unescape($script);
	}
	return %scriptList;
}

sub doThisScript {
	my $client = shift;
	my $script = shift;
	
	my %scriptChoices = (
		'open'    => 0,
		play      => 1,
		stop      => 2,
		power_on  => 3,
		power_off => 4,
		on_demand => 5,
	);

	my $scriptPath = scriptPath();
	
	my $runScript;
	if (my $scripts = $prefs->client($client)->get('script')) {
		$runScript = $scripts ->[$scriptChoices{$script}];
	}
	if ((!defined($runScript)) || ($runScript eq '')) {
		$log->info("Execute: using server pref");
		$runScript = $prefs->get($script);
	}
	if (defined($runScript) && ($runScript ne "(none)")) {
		my $runScriptPath = catfile($scriptPath,$runScript);
		$log->info("Execute: Executing $runScriptPath");
		$client->showBriefly({'line'=>[string('PLUGIN_EXECUTE_GO'),$runScript]});
		if (Slim::Utils::OSDetect::OS ne 'win') {
			$runScriptPath =~ s/([\(\) ])/\\\1/g;
			system $runScriptPath;
		} else {
			system "$runScriptPath";
		}
	} else {
		$log->warn("Execute: No Script Selected");
	}
}

sub commandCallbackStop {
	my $request = shift;

	my $client = $request->client();
	return unless $client;
	
	my $code   = $request->getParam('_buttoncode');

	$log->info("Execute: Play Stopped");
	doThisScript($client,"stop");
};
	
sub commandCallbackPlay {
	my $request = shift;

	my $client = $request->client();
	return unless $client;
	
	if ($request->getParam('_buttoncode')) {
		return unless $request->getParam('_buttoncode') eq 'play';
	}
	
	$log->info("Execute: Play Started");
	doThisScript($client,"play");
};
	
sub commandCallbackOpen {
	my $request = shift;

	my $client = $request->client();
	return unless $client;

	$log->info("Execute: File Open");
	doThisScript($client,"open");

};
	
sub commandCallbackPower {
	my $request = shift;

	my $client = $request->client();
	return unless $client; 
	
	my $code   = $request->getParam('_buttoncode');

	 if ($client->power) {
		$log->info("Execute: Power On");
		doThisScript($client,"power_on");
	} else {
		$log->info("Execute: Power Off");
		doThisScript($client,"power_off");
	}

};

1;

__END__

