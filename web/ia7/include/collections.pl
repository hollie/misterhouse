#!/usr/bin/perl 

# Returns a json object of the collection database
use strict;

use HTML::Entities;    # So we can encode characters like <>& etc
use JSON;

sub json_page {
	my ($json) = @_;

	return <<eof;
HTTP/1.0 200 OK
Server: MisterHouse
Content-type: application/json

$json
eof

}

# This is the default collections database, need to pull user generated version
# from the data_dir as a new feature.

my %json = (
	'collections' => {
		0 => {
			'name' => 'Home',
			'icon' => 'fa-home',
			'children' => [1,2,3,4,5,6,7,8,9,10,11,12]
		},
		1 => { 
			'name' => 'Mr. House Home',
			'icon' => 'fa-home',
			'children' => [13,14,15,16,17,18,19,20]
		},
		2 => { 
			'name' => 'Mail and News',
			'link' => 'news/index.html',
			'icon' => 'fa-envelope',
		},
		3 => { 
			'name' => 'Modes',
			'link' => 'modes/index.html',
			'icon' => 'fa-tasks',
		},
		4 => { 
			'name' => 'Lights & Appliances',
			'link' => 'lights/index.html',
			'icon' => 'fa-lightbulb-o',
		},
		5 => { 
			'name' => 'HVAC & Weather',
			'link' => 'outside/index.shtml',
			'icon' => 'fa-umbrella',
		},
		6 => { 
			'name' => 'Security Cameras',
			'link' => 'security/index.html',
			'icon' => 'fa-camera',
		},
		7 => { 
			'name' => 'Phone Calls & VoiceMail Msgs',
			'link' => 'phone/index.html',
			'icon' => 'fa-phone',
		},
		8 => { 
			'name' => 'TV/Radio Guide & MP3 Music',
			'link' => 'entertain/index.html',
			'icon' => 'fa-music',
		},
		9 => { 
			'name' => 'Speech',
			'link' => 'speak/index.html',
			'icon' => 'fa-microphone',
		},
		10 => { 
			'name' => 'Comics & Pictures',
			'link' => 'pictures/index.html',
			'icon' => 'fa-picture-o',
		},
		11 => { 
			'name' => 'Events, Calendar, & Clock',
			'link' => 'calendar/index.html',
			'icon' => 'fa-calendar',
		},
		12 => { 
			'name' => 'Statistics & Logged Data',
			'link' => 'statistics/index.html',
			'icon' => 'fa-bar-chart-o',
		},
		13 => { 
			'name' => 'About MrHouse',
			'link' => 'house/main.shtml',
			'icon' => 'fa-home',
		},
		14 => { 
			'name' => 'About 3Com Audrey',
			'link' => 'house/aboutaudrey.shtml',
			'icon' => 'fa-desktop',
		},
		15 => { 
			'name' => 'Browse MrHouse',
			'link' => '#request=list&type=categories&name=MisterHouse',
			'icon' => 'fa-home',
		},
		16 => { 
			'name' => 'Browse Categories',
			'link' => '#request=list&type=categories',
			'icon' => 'fa-archive',
		},
		17 => { 
			'name' => 'Browse Groups',
			'link' => '#request=list&type=groups',
			'icon' => 'fa-group',
		},
		18 => { 
			'name' => 'Browse Items',
			'link' => '#request=list&type=types',
			'icon' => 'fa-info',
		},
		19 => { 
			'name' => 'Browse Widgets',
			'link' => '/bin/list_widgets.pl',
			'icon' => 'fa-gears',
		},
		20 => { 
			'name' => 'Setup MrHouse',
			'icon' => 'fa-wrench',
			'children' => [21,22,23,24,25,26,27,28,29]
		},
		21 => { 
			'name' => 'Common Code Activation',
			'link' => '/bin/code_select.pl',
			'icon' => 'fa-code',
		},
		22 => { 
			'name' => 'User Code Activation',
			'link' => '/bin/code_unselect.pl',
			'icon' => 'fa-code',
		},
		23 => { 
			'name' => 'Edit Triggers',
			'link' => '/bin/triggers.pl',
			'icon' => 'fa-clock-o',
		},
		24 => { 
			'name' => 'Edit Items',
			'link' => '/bin/items.pl',
			'icon' => 'fa-list',
		},
		25 => { 
			'name' => 'INI Editor',
			'link' => '/bin/iniedit.pl',
			'icon' => 'fa-table',
		},
		26 => { 
			'name' => 'Program IRMAN',
			'link' => '/ia5/house/irman.shtml',
			'icon' => 'fa-rss',
		},
		27 => { 
			'name' => 'Header Control',
			'link' => '/bin/headercontrol.pl',
			'icon' => 'fa-wrench',
		},
		28 => { 
			'name' => 'Setup TV Provider',
			'link' => '/bin/set_parm_tv_provider.pl',
			'icon' => 'fa-desktop',
		},
		29 => { 
			'name' => 'Setup Photo Slideshow',
			'link' => '/ia5/house/SUB;photo_html',
			'icon' => 'fa-picture-o',
		},
	}
);

my $json_output = JSON->new->allow_nonref;
$json_output = $json_output->pretty->encode( \%json );
print &json_page($json_output);
