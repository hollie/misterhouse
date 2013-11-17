## Returns the HTML formated category grid

my %default_cats = (
	'01-Mr. House Home' => { 
		'link' => 'house/index.html',
		'icon' => 'fa-home'
	},
	'02-Mail and News' => { 
		'link' => 'news/index.html',
		'icon' => 'fa-envelope'
	},
	'03-Modes' => { 
		'link' => 'modes/index.html',
		'icon' => 'fa-tasks'
	},
	'04-Lights & Appliances' => { 
		'link' => 'lights/index.html',
		'icon' => 'fa-lightbulb-o'
	},
	'05-HVAC & Weather' => { 
		'link' => 'outside/index.shtml',
		'icon' => 'fa-umbrella'
	},
	'06-Security Cameras' => { 
		'link' => 'security/index.html',
		'icon' => 'fa-camera'
	},
	'07-Phone Calls & VoiceMail Msgs' => { 
		'link' => 'phone/index.html',
		'icon' => 'fa-phone'
	},
	'08-TV/Radio Guide & MP3 Music' => { 
		'link' => 'entertain/index.html',
		'icon' => 'fa-music'
	},
	'09-Speech' => { 
		'link' => 'speak/index.html',
		'icon' => 'fa-microphone'
	},
	'10-Comics & Pictures' => { 
		'link' => 'pictures/index.html',
		'icon' => 'fa-picture-o'
	},
	'11-Events, Calendar, & Clock' => { 
		'link' => 'calendar/index.html',
		'icon' => 'fa-calendar'
	},
	'12-Statistics & Logged Data' => { 
		'link' => 'statistics/index.html',
		'icon' => 'fa-bar-chart-o'
	},
	
);
my $row = 1;
my $column = 1;
my $output = '';

#use Data::Dumper;

#return Dumper(%default_cats);

#foreach my $key (keys %default_cats){
foreach my $key (sort(keys %default_cats)){
	my $name = $key;
	$name =~ s/^\d*-//i;
	if ($column == 1){
		$output .= "<div class='row top-buffer'>\n";
		$output .= "\t<div class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>\n";
	}
	$output .= "\t\t<div class='col-sm-4'>\n";
	$output .= "\t\t\t<a href='$default_cats{$key}{'link'}' class='btn btn-default btn-lg btn-block btn-category' role='button'><i class='fa $default_cats{$key}{'icon'} fa-2x fa-fw'></i> $name</a>\n";
	$output .= "\t\t</div>\n";
	if ($column == 3){
		$output .= "\t</div>\n</div>\n";
		$row++;
	}
	$column++;
	$column %= 3 if $column > 3;
}

return $output;