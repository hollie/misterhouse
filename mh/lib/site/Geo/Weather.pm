## Geo::Weather
## Written by Mike Machado <mike@innercite.com> 2000-11-01
##

package Geo::Weather;

use strict;
use Carp;
use LWP::UserAgent;

use vars qw( $VERSION @ISA @EXPORT @EXPORT_OK
		 $OK $ERROR_UNKNOWN $ERROR_QUERY $ERROR_PAGE_INVALID $ERROR_CONNECT $ERROR_NOT_FOUND $ERROR_TIMEOUT);

require Exporter;
 
@ISA = qw(Exporter);
@EXPORT_OK = qw();
@EXPORT = qw( $OK $ERROR_UNKNOWN $ERROR_QUERY $ERROR_PAGE_INVALID $ERROR_CONNECT $ERROR_NOT_FOUND $ERROR_TIMEOUT );
$VERSION = '0.08';

$OK = 1;
$ERROR_UNKNOWN = 0;
$ERROR_QUERY = -1;
$ERROR_PAGE_INVALID = -2;
$ERROR_CONNECT = -3;
$ERROR_NOT_FOUND = -4;
$ERROR_TIMEOUT = -5;

sub new {
	my $class = shift;
	my $self = {};
	$self->{debug} = 0;
	$self->{version} = $VERSION;
	$self->{server} = 'www.weather.com';
	$self->{port} = 80;
	$self->{base} = '/search/search';
	$self->{timeout} = 10;
	$self->{proxy} = '';
	$self->{proxy_username} = '';
	$self->{proxy_password} = '';
	$self->{agent_string} = 'Geo::Weather/0.07';

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
	$output .= "<a href=\"$results->{url}\"><img src=\"$results->{pic}\" border=0></a>\n";
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

	$results{url} = "http://$self->{server}";
	$results{url} .= ":$self->{port}" unless $self->{port} eq '80';
	$results{url} .= $page;
	$results{page} = $page;

	my $not_found_marker = 'could not be found';
	my $end_report_marker = 'Audio and Video Forecast';
	my $line = '';

	print STDERR __LINE__, ": Geo::Weather: Attempting to GET $results{url}\n" if $self->{debug};
	my $ua = new LWP::UserAgent;
	my $request = new HTTP::Request('GET',$results{url});
	my $proxy_user = $self->{proxy_user} || $ENV{HTTP_PROXY_USER} || '';
	my $proxy_pass = $self->{proxy_pass} || $ENV{HTTP_PROXY_PASS} || '';
	$request->proxy_authorization_basic($proxy_user, $proxy_pass) if $self->{proxy} && $proxy_user;

	$ua->timeout($self->{timeout}) if $self->{timeout};
	$ua->agent($self->{agent_string});
	$ua->proxy(['http'], $self->{proxy}) if $self->{proxy};
	

	my $response = $ua->request($request);
	unless ($response->is_success) {
		return $ERROR_TIMEOUT;
	}
	my $content = $response->content();

	my @lines = split(/\n/, $content);
	for (my $i = 0; $i < @lines; $i++) {
		my $line = $lines[$i];

		print STDERR "tagline: $line\n" if ($line =~ /<!-- insert/ && $self->{debug} > 2);
		print STDERR "line: $line\n" if $self->{debug} > 3;

		return $ERROR_NOT_FOUND if ($line =~ /$not_found_marker/i);

		if ($line =~ /categoryTitle/) {
			$line = $lines[$i + 2];
			if ($line =~ /\"(.*?)\"/) {
				print STDERR __LINE__, ": Geo::Weather: Found search result $1\n" if $self->{debug};
				return $self->lookup($1);
			}
		}

		if ($line =~ /\<TITLE\>weather.com - Local Weather - (.*?)\<\/TITLE\>/) {
			my ($city, $state) = split(/\,[\s+]/, $1);
			$results{city} = $city;
			if ($state =~ /(.*)\s+\((.*)\)/) {
				$results{state} = $1;
				$results{zip} = $2;
			} else {
				$results{state} = $state;
			}
		}
		if (!$results{pic}) {
			if ($line =~ /<!-- insert wx icon --><img src=\"(.*?)\"/) {
				$results{pic} = $1;
			}
		}
		if (!$results{cond}) {
			if ($line =~ /<!-- insert forecast text -->(.*?)[<&]/) {
				$results{cond} = $1;
			}
		}
		if (!$results{temp}) {
			if ($line =~ /<!-- insert current temp -->(.*?)[<&]/) {
				$results{temp} = $1;
			}
		}
		if (!$results{heat}) {
			if ($line =~ /<!-- insert feels like temp -->(.*?)[<&]/) {
				$results{heat} = $1;
			}
		}
		if (!$results{uv}) {
			if ($line =~ /<!-- insert UV number -->(.*?)[<&]/) {
				$results{uv} = $1;
			}
		}
		if (!$results{wind}) {
			if ($line =~ /<!-- insert wind information -->(.*?)[<&]/) {
				$results{wind} = $1;
			}
		}
		if (!$results{dewp}) {
			if ($line =~ /<!-- insert dew point -->(.*?)[<&]/) {
				$results{dewp} = $1;
			}
		}
		if (!$results{humi}) {
			if ($line =~ /<!-- insert humidity -->(.*?)[\s<&]/) {
				$results{humi} = $1;
			}
		}
		if (!$results{visb}) {
			if ($line =~ /<!-- insert visibility -->(.*?)[<&]/) {
				$results{visb} = $1;
			}
		}
		if (!$results{visb}) {
			if ($line =~ /<!-- insert visibility -->(.*?)[<&]/) {
				$results{visb} = $1;
			}
		}
		if (!$results{baro}) {
			if ($line =~ /<!-- insert barometer information -->(.*?)[<&]/) {
				$results{baro} = $1;
			}
		}

		if ($line =~ /$end_report_marker/) {
			last;
		}
	}
	if (!($results{visb})) {
		$results{visb} = 'Not Available';
	}

	return \%results;
}

1;

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
  $weather->{timeout} = 5; # set timeout to 5 seconds instead of the default of 10
 
  my $current = $weather->get_weather('95630');

  print "The current temperature is $current->{temp} degrees\n";


=head1 DESCRIPTION

The B<Geo::Weather> module retrieves the current weather from weather.com when given city and state or a US zip code. B<Geo::Weather> relies on
LWP::UserAgent to work. In order for the timeout code to work correctly, you must be using a recent version of libwww-perl and IO::Socket. B<Geo::Weather>
was developed with libwww-perl 5.53 and IO::Socket 1.26.

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
	zip		- Zipcode of US city
	pic		- weather.com URL to the current weather image
	url		- Weather.com URL to the weather results
	cond		- Current condition
	temp		- Current temperature (degees F)
	wind		- Current wind speed
	dewp		- Current dew point (degrees F)
	humi		- Current rel. humidity
	visb		- Current visibility
	baro		- Current barometric pressure
	heat		- Current heat index (Feels Like string)

	On error, it returns the following exported error variables

B<Errors>

	$ERROR_QUERY		- Invalid data supplied
	$ERROR_PAGE_INVALID	- No URL, or incorrectly formatted URL for retrieving the information
	$ERROR_CONNECT		- Error connecting to weather.com
	$ERROR_NOT_FOUND	- Weather for the specified city/state or zip could not be found
	$ERROR_TIMEOUT		- Timed out while trying to connect or get data from weather.com

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

	my $current = $weather->lookup('http://www.weather.com/search/search?where=95630');

B<Returns>

	On sucess, lookup returns a hashref with the same keys as the get_weather function

	On error, lookup returns the same errors defined for get_weather

=back

=head1 OBJECT KEYS

There are several object hash keys that can be set to manipulate how B<Geo::Weather> works. The hash keys
should be set directly following C<new>.

Below is a list of each key and what it does:

=item * B<debug>

Enable debug output of the connection attempts to weather.com Valid values are 0 to 4, increasing debugging respectivley.

=item * B<timeout>

Controls the timeout, in seconds, when trying to connect to or get data from weather.com. Default timeout
is 10 seconds. Set to 0 to disable timeouts.

=item * B<proxy>

Use HTTP proxy for the request. Format is http://proxy.server:port/. Default is no proxy.

=item * B<proxy_user>

Sets the username to use for proxying. Defaults to the HTTP_PROXY_USER environment variable, if set, or don't use authentication if blank.

=item * B<proxy_pass>

Sets the password to use for proxying. Defaults to the HTTP_PROXY_PASS environment variable, if set.

=item *B<agent_string>

HTTP User-Agent header for request. Default is Geo::Weather/$VERSION.

=head1 AUTHOR

 Geo::Weather was wrtten by Mike Machado I<E<lt>mike@innercite.comE<gt>>

=cut
