## Geo::Weather
## Written by Mike Machado <mike@innercite.com> 2000-11-01
##
## weather.com code originally from hawk@redtailedhawk.net

package Geo::Weather;

use strict;
use Carp;
use IO::Socket;

use vars qw( $VERSION @ISA @EXPORT @EXPORT_OK
		 $OK $ERROR_UNKNOWN $ERROR_QUERY $ERROR_PAGE_INVALID $ERROR_CONNECT $ERROR_NOT_FOUND);

require Exporter;
 
@ISA = qw(Exporter);
@EXPORT_OK = qw();
@EXPORT = qw( $OK $ERROR_UNKNOWN $ERROR_QUERY $ERROR_PAGE_INVALID $ERROR_CONNECT $ERROR_NOT_FOUND );
$VERSION = '0.01';

$OK = 1;
$ERROR_UNKNOWN = 0;
$ERROR_QUERY = -1;
$ERROR_PAGE_INVALID = -2;
$ERROR_CONNECT = -3;
$ERROR_NOT_FOUND = -4;


sub new {
	my $class = shift;
	my $self = {};
	$self->{debug} = 0;
	$self->{version} = $VERSION;
	$self->{server} = 'www.weather.com';
	$self->{port} = 80;
	$self->{base} = 'http://www.weather.com/weather/';
 
	bless $self, $class;
	return $self;
}

sub get_weather {
	my $self = shift;
	my $city = shift || '';
	my $state = shift || '';

	return $ERROR_QUERY unless $city;

	my $page = '';
	if ($city =~ /^\d+$/) {
		# Use zip code
		$page = $self->{base}.'us/zips/'.$city.'.html';
	} else {
		# Use state_city
		$state = lc($state);
		$city = lc($city);
		$city =~ s/ /_/g;
		$page = $self->{base}.'cities/us_'.$state.'_'.$city.'.html';
	}

	$self->{results} = $self->lookup($page);

	return $self->{results};
}

sub report {
	my $self = shift;

	return $ERROR_UNKNOWN unless $self->{results};

	my $output = '';
	my $results = $self->{results};
	$output .= "<font size=+4>$results->{city}, $results->{state}</font><br>\n";
	$output .= "<img src=\"$results->{pic}\" border=0>\n";
	$output .= "<font size=+3>$results->{cond}</font><br>\n";
	$output .= "<table border=0>\n";
	$output .= "<tr><td><b>Temp</b></td><td>$results->{temp}&deg F</td>\n";
	$output .= "<tr><td><b>Wind</b></td><td>From the $results->{wind} mph</td>\n" if $results->{wind};
	$output .= "<tr><td><b>Dew Point</b></td><td>$results->{dewp}&deg F</td>\n";
	$output .= "<tr><td><b>Rel. Humidity</b></td><td>$results->{humi}</td>\n";
	$output .= "<tr><td><b>Visibility</b></td><td>$results->{visb}</td>\n";
	$output .= "<tr><td><b>Barometer</b></td><td>$results->{baro} inches</td>\n" if $results->{baro};
	$output .= "<tr><td><b>Sunrise</b></td><td>$results->{rise} am</td>\n";
	$output .= "<tr><td><b>Sunset</b></td><td>$results->{set} pm</td>\n";
	$output .= "</table>\n";

	return $output;
}
	

sub lookup {
	my $self = shift;
	my $page = shift || '';

	return $ERROR_PAGE_INVALID unless $page;

	my %results = ();

	my $marker='<!-- start of obs';
	my $not_found_marker = 'zip and city search';
	my $lines =90;

	print STDERR __LINE__, ": Geo::Weather: Attempting to connect to $self->{server}:$self->{port}\n" if $self->{debug};

	my $remote = IO::Socket::INET->new(Proto=>'tcp', PeerAddr=>$self->{server}, PeerPort=>$self->{port}, Reuse=>1) || return $ERROR_CONNECT;

	print STDERR __LINE__, ": Geo::Weather: Getting $page from $self->{server}:$self->{port}\n" if $self->{debug};
	$results{page} = $page;
	print $remote "GET $page\n";
	while($page !~ /$marker/i) {
		$page=<$remote>;
		return $ERROR_NOT_FOUND if ($page =~ /$not_found_marker/i);
		if ($page =~ /\<TITLE\>The Weather Channel - (.*)\<\/TITLE\>/) {
			my ($city, $state) = split(/\,[\s+]/, $1);
			$results{city} = $city;
			if ($state =~ /(.*)\s+\((\d+)\)/) {
				$results{state} = $1;
				$results{zip} = $2;
			} else {
				$results{state} = $state;
			}
			
		}
	}
	my @page = ();
	while($lines) {
		$page=<$remote>;
		push (@page,$page);
		$lines--;
	}
	close $remote;

	my $x = '';
	while(@page) {
		my $line=shift(@page);
		$line=~ s/\<.{1,65}\>//g;
		if(!($results{pic})) {
			if($line =~ /\/\/i/){
				($x,$results{pic}) = split(/C=\"/,$line);
				($results{pic}) = split(/\" W/,$results{pic});
			}
		}
		if (!$results{cond} && $results{pic} && !$results{temp}) {
			if ($line =~ /\s+([A-Za-z \/\-\\]{1,15})\s+$/) {
				$results{cond} = $1;
			}
		}
		if(!($results{temp})){
			if($line=~/\&deg/) {
				($results{temp})=split(/\&deg/,$line);
				($x,$results{temp})=split(/ \D*/,$results{temp});
				next;
			}
		}

		if($line=~/Heat Index/i) {
			$line.=shift(@page).shift(@page);
			$line=~ s/\<.{1,80}\>//g;
			if(!($results{heat})) {
				if($line=~/\&deg/) {
					($results{heat})=split(/\&deg/,$line);
					($x,$results{heat})=split(/ \D*/,$results{heat});
					next;
				}
			}
		}

		if(!($results{wind})) {
			if($line=~/mph/)  {
				($x,$results{wind})=split(/from the /i,$line);
				($results{wind})=split(/ mph/,$results{wind});
			}
		}
		if(!($results{dewp})) {
			if($line=~/\&deg/) {
				($results{dewp})=split(/\&deg/,$line);
				($x,$results{dewp})=split(/ \D*/,$results{dewp});
				next;
			}
		}
		if(!($results{humi})) {
			if($line=~/\%/)    {
				($x,$results{humi})=split(/ \D*/,$line);
				chomp($results{humi});
				next;
			}
		}
		if(!($results{visb})) {
			if($line=~/miles|unlimited/i) {
				($x,$results{visb})=split(/ \D*/,$line);
				if($line=~/unlimited/){
					$results{visb}='unlimited';
				}
				next;
			}
		}
		if(!($results{baro})) {
			if($line=~/inches/i) {
				($x,$results{baro})=split(/ \D*/,$line);
				next;
			}
		}
		if(!($results{rise})) {
#			if(($line=~/am/i)&&($results{baro})) {
			if(($line=~/am/i)&&($results{visb})) {
				($x,$results{rise})=split(/ \D*/,$line);
				next;
			}
		}
		if(!($results{set})) {
			if(($line=~/pm/i)&&($results{rise})) {
				($x,$results{set} )=split(/ \D*/,$line);
				last;
			}
		}
	}
	if(!($results{heat})) {
		$results{heat}='Not Available';
	}
	if(!($results{dewp})) {
		$results{dewp}='Not Available';
	}
	if(!($results{visb})) {
		$results{visb}='Not Available';
	}

	return \%results;
}

__END__

=head1 NAME

Geo::Weather - Weather retrieval module

=head1 SYNOPSIS

  use Geo::Weather;

  my $weather = new Geo::Weather;

  $weather->get_weather('Folsom','CA');

  print $weather->report();

  -or-

  use Geo::Weather;

  my $weather = new Geo::Weather;
 
  my $current = $weather->get_weather('95630');

  print "The current temperature is $current->{temp} degrees\n";


=head1 DESCRIPTION

The B<Geo::Weather> module retrieves the current weather from weather.com when given city and state or a US zip code

=head1 FUNCTIONS

=over 4

=item * B<new>

Create and return a new object.

=back

=over 4

=item * B<get_weather>

Gets the current weather from weather.com

B<Arguments>

	city - US city or zip code
	state - US state, not needed if using zip code

B<Sample Code>

	my $current = $weather->get_weather('Folsom','CA');
	if (!ref $current) {
		die "Unable to get weather information\n";
	}

B<Returns>

	On sucess, get_weather returns a hashref  containing the following keys

	city		- City
	state		- State
	pic		- weather.com URL to the current weather image
	cond		- Current condition
	temp		- Current temperature (degees F)
	wind		- Current wind speed
	dewp		- Current dew point (degrees F)
	humi		- Current rel. humidity
	visb		- Current visibility (miles)
	baro		- Current barometric pressure
	rise		- Sunrise time
	set		- Sunset time

	On error, it returns the following exported error variables

B<Errors>

	$ERROR_QUERY		- Invalid data supplied
	$ERROR_PAGE_INVALID	- No URL, or incorrectly formatted URL for retrieving the information
	$ERROR_CONNECT		- Error connecting to weather.com
	$ERROR_NOT_FOUND	- Weather for the specified city/state or zip could not be found

=back

=over 4

=item * B<report>

Returns an HTML table containing the current weather. Must call get_weather first.

B<Sample Code>

	print $weather->report();

=back


=over 4

=item * B<lookup>

Gets current weather given a full weather.com URL

B<Sample Code>

	my $current = $weather->lookup('http://www.weather.com/weather/cities/us_ca_folsom.html');

B<Returns>

	On sucess, lookup returns a hashref with the same keys as the get_weather function

	On error, lookup returns the same errors defined for get_weather

=back


=head1 AUTHOR

 Geo::Weather was wrtten by Mike Machado I<E<lt>mike@innercite.comE<gt>> with the main weather.com retrieval code from I<E<lt>hawk@redtailedhawk.netE<gt>>

=cut
