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
		'01-Mr. House Home' => { 
			'icon' => 'fa-home',
			'key' => 1,
			'parent' => 0
		},
		'02-Mail and News' => { 
			'link' => 'news/index.html',
			'icon' => 'fa-envelope',
			'key' => 2,
			'parent' => 0
		},
		'03-Modes' => { 
			'link' => 'modes/index.html',
			'icon' => 'fa-tasks',
			'key' => 3,
			'parent' => 0
		},
		'04-Lights & Appliances' => { 
			'link' => 'lights/index.html',
			'icon' => 'fa-lightbulb-o',
			'key' => 4,
			'parent' => 0
		},
		'05-HVAC & Weather' => { 
			'link' => 'outside/index.shtml',
			'icon' => 'fa-umbrella',
			'key' => 5,
			'parent' => 0
		},
		'06-Security Cameras' => { 
			'link' => 'security/index.html',
			'icon' => 'fa-camera',
			'key' => 6,
			'parent' => 0
		},
		'07-Phone Calls & VoiceMail Msgs' => { 
			'link' => 'phone/index.html',
			'icon' => 'fa-phone',
			'key' => 7,
			'parent' => 0
		},
		'08-TV/Radio Guide & MP3 Music' => { 
			'link' => 'entertain/index.html',
			'icon' => 'fa-music',
			'key' => 8,
			'parent' => 0
		},
		'09-Speech' => { 
			'link' => 'speak/index.html',
			'icon' => 'fa-microphone',
			'key' => 9,
			'parent' => 0
		},
		'10-Comics & Pictures' => { 
			'link' => 'pictures/index.html',
			'icon' => 'fa-picture-o',
			'key' => 10,
			'parent' => 0
		},
		'11-Events, Calendar, & Clock' => { 
			'link' => 'calendar/index.html',
			'icon' => 'fa-calendar',
			'key' => 11,
			'parent' => 0
		},
		'12-Statistics & Logged Data' => { 
			'link' => 'statistics/index.html',
			'icon' => 'fa-bar-chart-o',
			'key' => 12,
			'parent' => 0
		},
		'01-About MrHouse' => { 
			'link' => 'house/main.shtml',
			'icon' => 'fa-home',
			'parent' => 1
		},
		'02-About 3Com Audrey' => { 
			'link' => 'house/aboutaudrey.shtml',
			'icon' => 'fa-desktop',
			'parent' => 1
		},
		'03-Browse MrHouse' => { 
			'link' => '#request=list&type=categories&name=MisterHouse',
			'icon' => 'fa-home',
			'parent' => 1
		},
		'04-Browse Categories' => { 
			'link' => '#request=list&type=categories',
			'icon' => 'fa-archive',
			'parent' => 1
		},
		'05-Browse Groups' => { 
			'link' => '#request=list&type=groups',
			'icon' => 'fa-group',
			'parent' => 1
		},
		'06-Browse Items' => { 
			'link' => '#request=list&type=types',
			'icon' => 'fa-info',
			'parent' => 1
		},
		'07-Browse Widgets' => { 
			'link' => '/bin/list_widgets.pl',
			'icon' => 'fa-gears',
			'parent' => 1
		},
		'08-Setup MrHouse' => { 
			'icon' => 'fa-wrench',
			'parent' => 1,
			'key' => 13
		},
		'01-Common Code Activation' => { 
			'link' => '/bin/code_select.pl',
			'icon' => 'fa-code',
			'parent' => 13
		},
		'02-User Code Activation' => { 
			'link' => '/bin/code_unselect.pl',
			'icon' => 'fa-code',
			'parent' => 13
		},
		'03-Edit Triggers' => { 
			'link' => '/bin/triggers.pl',
			'icon' => 'fa-clock-o',
			'parent' => 13
		},
		'04-Edit Items' => { 
			'link' => '/bin/items.pl',
			'icon' => 'fa-list',
			'parent' => 13
		},
		'05-INI Editor' => { 
			'link' => '/bin/iniedit.pl',
			'icon' => 'fa-table',
			'parent' => 13
		},
		'06-Program IRMAN' => { 
			'link' => '/ia5/house/irman.shtml',
			'icon' => 'fa-rss',
			'parent' => 13
		},
		'07-Header Control' => { 
			'link' => '/bin/headercontrol.pl',
			'icon' => 'fa-wrench',
			'parent' => 13
		},
		'08-Setup TV Provider' => { 
			'link' => '/bin/set_parm_tv_provider.pl',
			'icon' => 'fa-desktop',
			'parent' => 13
		},
		'09-Setup Photo Slideshow' => { 
			'link' => '/ia5/house/SUB;photo_html',
			'icon' => 'fa-picture-o',
			'parent' => 13
		},
	}
);

my $json_output = JSON->new->allow_nonref;
$json_output = $json_output->pretty->encode( \%json );
print &json_page($json_output);
