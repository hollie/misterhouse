## Geo::Weather
## Written by Mike Machado <mike@innercite.com> 2000-11-01
##
## weather.com code originally from hawk@redtailedhawk.net

## 2/01 local change: Allow for negative temps

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
$VERSION = '0.02';

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
	$self->{base} = '/search/search';
 
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
		$page = $self->{base}.'?where='.$city;
	} else {
		# Use state_city
		$state = lc($state);
		$city = lc($city);
		$city =~ s/ /+/g;
		$page = $self->{base}.'?where='.$city.','.$state;
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
	$output .= "<tr><td><b>Wind</b></td><td>$results->{wind}</td>\n" if $results->{wind};
	$output .= "<tr><td><b>Dew Point</b></td><td>$results->{dewp}&deg F</td>\n";
	$output .= "<tr><td><b>Rel. Humidity</b></td><td>$results->{humi}</td>\n";
	$output .= "<tr><td><b>Visibility</b></td><td>$results->{visb}</td>\n";
	$output .= "<tr><td><b>Barometer</b></td><td>$results->{baro}</td>\n" if $results->{baro};
	$output .= "</table>\n";

	return $output;
}
	

sub lookup {
	my $self = shift;
	my $page = shift || '';
	my $redir = shift || 0;

	return $ERROR_PAGE_INVALID unless $page;

	my %results = ();

	my $marker='<!-- Begin Main Content Here';
	my $end_report_marker='UV Index';
	my $not_found_marker = 'could not be found';
	my $lines =90;
	my $lines_read = 0;
	my $line = '';

	print STDERR __LINE__, ": Geo::Weather: Attempting to connect to $self->{server}:$self->{port}\n" if $self->{debug};

	my $remote = IO::Socket::INET->new(Proto=>'tcp', PeerAddr=>$self->{server}, PeerPort=>$self->{port}, Reuse=>1) || return $ERROR_CONNECT;

	print STDERR __LINE__, ": Geo::Weather: Getting $page from $self->{server}:$self->{port}\n" if $self->{debug};
	$results{page} = $page;
	print $remote "GET $page HTTP/1.0\n\n";

	if (!$redir) {
		while ($line = <$remote>) {
			chop($line);
			chomp($line);
			return $ERROR_NOT_FOUND if ($line =~ /$not_found_marker/i);
			if ($line =~ /location: http:\/\/.*?\/(.*)/) {
				$page = '/'.$1;
				close($remote);
				return $self->lookup($page, 1);
			} elsif ($line =~ /categoryTitle/) {
				$line = <$remote>;
				$line = <$remote>;
				chop($line);
				chomp($line);
				close($remote);
				if ($line =~ /\"(.*?)\"/) {
					print STDERR __LINE__, ": Geo::Weather: Found search result $1\n" if $self->{debug};
					return $self->lookup($1, 1);
				}
			}
		}
		return $ERROR_NOT_FOUND;
	}

	while($line !~ /$marker/) {
		$lines_read++;
		$line=<$remote>;
		print STDERR __LINE__, ": Geo::Weather: recv_line: $line" if $self->{debug} > 1;
		if ($line =~ /\<TITLE\>weather.com - Local Weather - (.*?)\<\/TITLE\>/) {
			my ($city, $state) = split(/\,[\s+]/, $1);
			$results{city} = $city;
			$results{state} = $state;
		}
	}

	my $x = '';

	print STDERR __LINE__, ": Geo::Weather: Marker found, parsing report\n" if $self->{debug};
	while($line = <$remote>) {

		chop($line);
		chomp($line);
		$lines_read++;

		if ($line =~ /$end_report_marker/) {
			print STDERR __LINE__, ": Geo::Weather: End of report\n" if $self->{debug};
			last;
		}

		if(!($results{pic})) {
			if($line =~ /wxicons/) {
				if ($line =~ /\"(.*?)\"/) {
					$results{pic} = $1;
					next;
				}
			}
		}
		if (!($results{cond})) {
			if ($line =~ /Feels Like/) {
				if ($line =~ /\<.*?>(.*?)\<BR\>Feels Like&nbsp;(.*)/) {
					$results{cond} = $1;
					$results{heat} = $2;
					if ($results{heat} =~ /(\-?\d+).*/) {
						$results{heat} = $1;
					}
					next;
				}
			}
		}
		if(!($results{temp})){
			if($line =~ /obsTempText/) {
				if ($line =~ /\<.*?\>.*?(\-?\d+)\<.*\>/) {
					$results{temp} = $1;
					next;
				}
			}
		}

		if(!($results{wind})) {
			if($line=~/Wind:/)  {
				$line = <$remote>;
				$line = <$remote>;
				chop($line);
				chomp($line);
				if ($line =~ /\<.*?\>(.*?)\<.*\>/) {
					$results{wind} = $1;
				}
				next;
			}
		}

		if(!($results{dewp})) {
			if($line=~/Dew Point:/) {
				$line = <$remote>;
				$line = <$remote>;
				chop($line);
				chomp($line);
				if ($line =~ /\<.*?\>(\d+).*\<.*\>/) {
					$results{dewp} = $1;
				}
				next;
			}
		}
		if(!($results{humi})) {
			if($line=~/Humidity:/)    {
				$line = <$remote>;
				$line = <$remote>;
				chop($line);
				chomp($line);
				if ($line =~ /\<.*?\>(\d+) %\<.*\>/) {
					$results{humi} = $1;
				}
				next;
			}
		}
		if(!($results{visb})) {
			if($line=~/Visibility:/) {
				$line = <$remote>;
				$line = <$remote>;
				chop($line);
				chomp($line);
				if ($line =~ /\<.*?\>(.*?)\<.*\>/) {
					$results{visb} = $1;
				}
				next;
			}
		}
		if(!($results{baro})) {
			if($line=~/Barometer:/) {
				$line = <$remote>;
				$line = <$remote>;
				chop($line);
				chomp($line);
				if ($line =~ /\<.*?\>(.*?)\<.*\>/) {
					$results{baro} = $1;
				}
				next;
			}
		}
	}

	if (!($results{visb})) {
		$results{visb} = 'Not Available';
	}

	close($remote);

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
	visb		- Current visibility
	baro		- Current barometric pressure
	heat		- Current heat index

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
