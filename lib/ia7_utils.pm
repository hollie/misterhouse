package ia7_utils;

=head1 B<ia7_utils>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Provides support for the common routines used by the ia7 interface.

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item B<get_cats>

Returns a reference to a hash containing the database of catagories.

In the future, the categories will be written to the data directory.  If no such
file exists a default copy will be created.  While building the code, it is
easiest to force the default setup.

=cut

sub get_cats {
	my %default_cats = (
		'01-Mr. House Home' => { 
			'link' => 'view_sub_cat.pl?category=1',
			'icon' => 'fa-home',
			'key' => 1
		},
		'02-Mail and News' => { 
			'link' => 'news/index.html',
			'icon' => 'fa-envelope',
			'key' => 2
		},
		'03-Modes' => { 
			'link' => 'modes/index.html',
			'icon' => 'fa-tasks',
			'key' => 3
		},
		'04-Lights & Appliances' => { 
			'link' => 'lights/index.html',
			'icon' => 'fa-lightbulb-o',
			'key' => 4
		},
		'05-HVAC & Weather' => { 
			'link' => 'outside/index.shtml',
			'icon' => 'fa-umbrella',
			'key' => 5
		},
		'06-Security Cameras' => { 
			'link' => 'security/index.html',
			'icon' => 'fa-camera',
			'key' => 6
		},
		'07-Phone Calls & VoiceMail Msgs' => { 
			'link' => 'phone/index.html',
			'icon' => 'fa-phone',
			'key' => 7
		},
		'08-TV/Radio Guide & MP3 Music' => { 
			'link' => 'entertain/index.html',
			'icon' => 'fa-music',
			'key' => 8
		},
		'09-Speech' => { 
			'link' => 'speak/index.html',
			'icon' => 'fa-microphone',
			'key' => 9
		},
		'10-Comics & Pictures' => { 
			'link' => 'pictures/index.html',
			'icon' => 'fa-picture-o',
			'key' => 10
		},
		'11-Events, Calendar, & Clock' => { 
			'link' => 'calendar/index.html',
			'icon' => 'fa-calendar',
			'key' => 11
		},
		'12-Statistics & Logged Data' => { 
			'link' => 'statistics/index.html',
			'icon' => 'fa-bar-chart-o',
			'key' => 12
		},
		
	);
	return \%default_cats;
}

=item B<get_sub_cats>

Returns a reference to a hash containing the database of sub-catagories.

In the future, the sub-categories will be written to the data directory.  If no such
file exists a default copy will be created.  While building the code, it is
easiest to force the default setup.

=cut

sub get_sub_cats {
	my %default_sub_cats = (
		'01-About MrHouse' => { 
			'link' => 'house/main.shtml',
			'icon' => 'fa-home',
			'category' => 1
		},
		'02-About 3Com Audrey' => { 
			'link' => 'house/aboutaudrey.shtml',
			'icon' => 'fa-desktop',
			'category' => 1
		},
		'03-Browse MrHouse' => { 
			'link' => 'house/browsemrhouse.shtml',
			'icon' => 'fa-home',
			'category' => 1
		},
		'04-Browse Categories' => { 
			'link' => '/bin/list_categories.pl',
			'icon' => 'fa-archive',
			'category' => 1
		},
		'05-Browse Groups' => { 
			'link' => '/bin/list_groups.pl',
			'icon' => 'fa-group',
			'category' => 1
		},
		'06-Browse Items' => { 
			'link' => '/bin/list_items.pl',
			'icon' => 'fa-info',
			'category' => 1
		},
		'07-Browse Widgets' => { 
			'link' => '/bin/list_widgets.pl',
			'icon' => 'fa-gears',
			'category' => 1
		},
		'08-Setup MrHouse' => { 
			'link' => 'house/setup.shtml',
			'icon' => 'fa-wrench',
			'category' => 1
		},
	);
	return \%default_sub_cats;
}

sub print_header {
	my ($title) = @_;
	$output =<<END;
	
	<!DOCTYPE html>
	<html><head><title>$title</title>
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		
		<!--Font Awesome-->
		<link href="//netdna.bootstrapcdn.com/font-awesome/4.0.3/css/font-awesome.min.css" rel="stylesheet">
		
		<!--Bootstrap-->
		<!-- Latest compiled and minified CSS -->
		<link rel="stylesheet" href="//netdna.bootstrapcdn.com/bootstrap/3.0.2/css/bootstrap.min.css">
		
		<!-- Optional theme -->
		<link rel="stylesheet" href="//netdna.bootstrapcdn.com/bootstrap/3.0.2/css/bootstrap-theme.min.css">
		
		<!-- Latest compiled and minified JavaScript -->
		<script src="//netdna.bootstrapcdn.com/bootstrap/3.0.2/js/bootstrap.min.js"></script>
		<style type="text/css">
		.btn-category {
		  overflow: hidden;
		  text-overflow: ellipsis;
		  white-space: no-wrap;
		  text-align: left;
		  padding-left: 15px;
		  padding-right: 15px;
		}
		.top-buffer { margin-top:20px; }
		.col-center {text-align: center;}
		</style>
	</head>
	<body>
	<div class='row top-buffer'>
		<div class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>
			<div class='col-sm-4'>
				<a href='/ia5/'>
				<img src='images/mhlogo.gif' alt='Reload Page' alt='Reload' border='0'>
				</a>
			</div>
		</div>
	</div>
END
	return $output;	
}


=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Kevin Robert Keegan

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut
1;