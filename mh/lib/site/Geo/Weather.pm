## Geo::Weather
## Written by Mike Machado <mike@innercite.com> 2000-11-01
##

# Modified by Kevin L. Papendick
# E-mail:	kevinp@polarlava.com
# Website:	www.polarlava.com

# V0.9b
# - Added report_raw() function
# - Modified report() format

# V0.9c
# - URL & RegEx Changes due to weather.com changes

# V1.1_PL
# - Incorporated Mike's V1.1 $ERROR_BUSY changes

# V1.2
#  Parse new weather.com as of 2002-12-05 -klp
# - New image locator comment
# - New current temperature locator
# - New dew point locator
# - New relative humidity locator
# - New visability locator
# - New barometric locator
# - New UV locator
# - New wind locator

# V1.2.1
#  Parse new weather.com as of 2003-01-08 -klp

# V1.2.2 - 1/27/03
#  Bug Fix for negative dew points -klp

# V1.2.3 - 02/24/03
# Change to picture parsing for new HTML code -klp

package Geo::Weather;

use strict;
use Carp;
use LWP::UserAgent;

use vars qw( $VERSION @ISA @EXPORT @EXPORT_OK
		 $OK $ERROR_UNKNOWN $ERROR_QUERY $ERROR_PAGE_INVALID $ERROR_CONNECT $ERROR_NOT_FOUND $ERROR_TIMEOUT $ERROR_BUSY);

require Exporter;

@ISA = qw(Exporter);
@EXPORT_OK = qw();
@EXPORT = qw( $OK $ERROR_UNKNOWN $ERROR_QUERY $ERROR_PAGE_INVALID $ERROR_CONNECT $ERROR_NOT_FOUND $ERROR_TIMEOUT $ERROR_BUSY);
$VERSION = '1.2.3';

$OK = 1;
$ERROR_UNKNOWN = 0;
$ERROR_QUERY = -1;
$ERROR_PAGE_INVALID = -2;
$ERROR_CONNECT = -3;
$ERROR_NOT_FOUND = -4;
$ERROR_TIMEOUT = -5;
$ERROR_BUSY = -6;


sub new {
	my $class = shift;
	my $self = {};
	$self->{debug} = 0;
	$self->{version} = $VERSION;
	$self->{server} = 'www.weather.com';
	$self->{port} = 80;
	$self->{base} = '/search/search?where=';
	$self->{ext} = '&what=WeatherLocalUndeclared&GO=GO';
	$self->{timeout} = 10;
	$self->{proxy} = '';
	$self->{proxy_username} = '';
	$self->{proxy_password} = '';
	$self->{agent_string} = "Geo::Weather/$VERSION";

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
		$page = $self->{base}.$city.$self->{ext};
	} else {
		# Use state_city
		$state = lc($state);
		$city = lc($city);
		$city =~ s/ /+/g;
		$page = $self->{base}.$city.','.$state.$self->{ext};
	}

	$self->{results} = $self->lookup($page);

	return $self->{results};
}

sub report_raw {
	my $self = shift;
	my $results = $self->{results};
	my $output;

	return $ERROR_UNKNOWN unless $self->{results};

	$output .= $results->{city} . '|';
	$output .= $results->{state} . '|';
	$output .= $results->{pic} . '|';
	$output .= $results->{cond} . '|';
	$output .= $results->{temp} . '|';
	$output .= $results->{wind} . '|';
	$output .= $results->{dewp} . '|';
	$output .= $results->{humi} . '|';
	$output .= $results->{visb} . '|';
	$output .= $results->{baro} . '|';
	$output .= $results->{uv};

	return "$output";
}

sub report {
	my $self = shift;
	my $result_hdr_color = "#0080FF";
	my $result_cond_color = "#FF8080";
	my $result_color = "#03C1C7";

	return $ERROR_UNKNOWN unless $self->{results};

	my $output = '';
	my $heat_c = 0;
	my $feels_like = '';
	my $results = $self->{results};

	if ($results->{heat} ne 'N/A') {
		$heat_c = sprintf("%0.0f", 5/9 * ($results->{heat} - 32));
		$feels_like = "(Feels Like: $results->{heat}&deg F/$heat_c&deg C)";
	}


	$output = <<REPORT_START;
	<font size="+2" color=\"$result_hdr_color\">
		$results->{city}, $results->{state}
	</font>
	<br>
	<a href=\"$results->{url}\"><img src=\"$results->{pic}\" border=0></a>
	<font size="+1" color="$result_cond_color">
		$results->{cond}
	</font>
	<br>
	<br>
	<table border="0">
		<tr>
			<td>
					<b>Temperature:</b>
			</td>
			<td>
				<font color="$result_color">
					$results->{temp}&deg F/$results->{temp_c}&deg C&nbsp;&nbsp; $feels_like
				</font>
			</td>
		</tr>

REPORT_START

	if ($results->{wind}) {
		$output .= <<REPORT_WIND;
		<tr>
			<td>
				<b>Wind:</b>
			</td>
			<td>
				<font color="$result_color">
					$results->{wind}
				</font>
			</td>
		</tr>

REPORT_WIND
	}

	$output .= <<REPORT_MID;
		<tr>
			<td>
				<b>Dew Point:</b>
			</td>
			<td>
				<font color="$result_color">
					$results->{dewp}&deg F/$results->{dewp_c}&deg C
				</font>
			</td>
		</tr>
		<tr>
			<td>
				<b>Rel. Humidity:</b>
			</td>
			<td>
				<font color="$result_color">
					$results->{humi} %
				</font>
			</td>
		</tr>
		<tr>
			<td>
				<b>Visibility:</b>
			</td>
			<td>
				<font color="$result_color">
					$results->{visb}
				</font>
			</td>
		</tr>

REPORT_MID

	if ($results->{baro}) {
		$output .= <<REPORT_BARO;
		<tr>
			<td>
				<b>Barometer:</b>
			</td>
			<td>
				<font color="$result_color">
					$results->{baro}
				</font>
			</td>
		</tr>

REPORT_BARO
	}

	if ($results->{baro}) {
		$output .= <<REPORT_UV;
		<tr>
			<td>
				<b>UV Index:</b>
			</td>
			<td>
				<font color="$result_color">
					$results->{uv}
				</font>
			</td>
		</tr>

REPORT_UV
	}

	$output .= "</table>\n";

	return "$output|$results->{city}|$results->{state}";
}

sub lookup {
	my $self = shift;
	my $page = shift || '';
	my $redir = shift || 0;

	my $rh_cnt = 0;
	my $dew_cnt = 0;
	my $vis_cnt = 0;
	my $baro_cnt = 0;
	my $uv_cnt = 0;
	my $wind_cnt = 0;

	return $ERROR_PAGE_INVALID unless $page;

	my %results = ();

	$results{url} = "http://$self->{server}";
	$results{url} .= ":$self->{port}" unless $self->{port} eq '80';
	$results{url} .= $page;
	$results{page} = $page;

	my $not_found_marker = 'not found';
	my $end_report_marker = '<!-- vertical outlet #1 -->';
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
		next if ($line eq '');
		print STDERR "tagline: $line\n" if ($line =~ /<!-- insert/ && $self->{debug} > 2);
		print STDERR "line: $line\n" if $self->{debug} > 3;

		return $ERROR_NOT_FOUND if ($line =~ /$not_found_marker/i);

		if ($line =~ /<title>.*Severe Weather Mode Index.*/i) {
			return $ERROR_BUSY;
		}

		#Parse - City, State, Zip
		if ($line =~ /<b>Local Forecast for (.*?)<\/b>/i || $line =~ /<b>Travel Forecast for (.*?)<\/b>/i) {
			my ($city, $state) = split(/\,[\s+]/, $1);
			$results{city} = $city;
			if ($state =~ /(.*)\s+\((.*)\)/) {
				$results{state} = $1;
				$results{zip} = $2;
			} else {
				$results{state} = $state;
			}
		}

		#Parse - Picture
		if (!$results{pic}) {
			if ($line =~ /<TD CLASS=obsInfo1.*>\s*<img src=(.*?)\s/i) {
				$results{pic} = $1;
			}
		}

		#Parse - Current Conditions
		if (!$results{cond}) {
			if ($line =~ /obsTextA>\s*(.*)<\/B/i) {
				$results{cond} = $1;
			}
		}

		#Parse - Temperature
		if (!$results{temp}) {
			if ($line =~ /obsTempTextA>\s*(.*?)[<&]/i) {
				$results{temp} = $1;
			}
		}

		#Parse - Heat Index
		if (!$results{heat}) {
			if ($line =~ /Feels Like<\w+>\s*(.*?)[<&]/) {
				$results{heat} = $1;
			}
		}

		#Parse - UV Index
		if (!$results{uv}) {
			if ($line =~ /UV Index:/) {
				$uv_cnt = 1;
			} elsif ($uv_cnt > 0) {
				$uv_cnt++;
			}

			if ($uv_cnt == 2 && $line =~ /obsInfo2>\s*(.*)</) {

				$results{uv} = $1;
			}
		}

		#Parse - Wind Speed
		if (!$results{wind}) {
			if ($line =~ /Wind:/) {
				$wind_cnt = 1;
			} elsif ($wind_cnt > 0) {
				$wind_cnt++;
			}

			if ($wind_cnt == 2 && $line =~ /obsInfo2>\s*(.*)</) {

				$results{wind} = $1;
			}
		}

		#Parse - Dew Point
		if (!$results{dewp}) {
			if ($line =~ /Dew Point:/) {
				$dew_cnt = 1;
			} elsif ($dew_cnt > 0) {
				$dew_cnt++;
			}

			if ($dew_cnt == 2 && $line =~ /obsInfo2>\s?(.*)</i) {

				$results{dewp} = $1;
			}
		}

		#Parse - Humidity
		if (!$results{humi}) {
			if ($line =~ /Humidity:/) {
				$rh_cnt = 1;
			} elsif ($rh_cnt > 0) {
				$rh_cnt++;
			}

			if ($rh_cnt == 2 && $line =~ /obsInfo2>\s*(\d+)/) {

				$results{humi} = $1;
			}
		}

		#Parse - Visability
		if (!$results{visb}) {
			if ($line =~ /Visibility:/) {
				$vis_cnt = 1;
			} elsif ($vis_cnt > 0) {
				$vis_cnt++;
			}

			if ($vis_cnt == 2 && $line =~ /obsInfo2>\s*(.*)\s*</) {

				$results{visb} = $1;
			}
		}

		#Parse - Barometer
		if (!$results{baro}) {
			if ($line =~ /Pressure:/) {
				$baro_cnt = 1;
			} elsif ($baro_cnt > 0) {
				$baro_cnt++;
			}

			if ($baro_cnt == 2 && $line =~ /obsInfo2>\s*(.*)\s*</) {

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

	#Celcius Conversions
	$results{temp_c} = sprintf("%0.0f", 5/9 * ($results{temp} - 32));
	$results{dewp_c} = sprintf("%0.0f", 5/9 * ($results{dewp} - 32));


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

=item * B<report_raw>

Returns pipe delimited string containing the current weather. Must call get_weather first.

 Fields are: city|state|pic|cond|temp|wind|dewp|humi|visb|baro|uv

B<Sample Code>

	my $current = $weather->report_raw();

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
