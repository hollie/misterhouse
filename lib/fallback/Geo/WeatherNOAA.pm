# $Id: WeatherNOAA.pm,v 4.38 2006/12/10 21:58:11 msolomon Exp $
# $Id: WeatherNOAA.pm,v 4.39 2016/08/17 21:58:11 rsteeves Exp $
# $Id: WeatherNOAA.pm,v 4.40 2016/09/28 21:58:11 wgatlin Exp $

package Geo::WeatherNOAA;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use LWP::Simple;
use LWP::UserAgent;
use Tie::IxHash;
use Text::Wrap;

require Exporter;

@ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
  make_noaa_table

  print_forecast
  print_current

  get_city_zone
  process_city_zone

  get_city_hourly
  process_city_hourly
);

$VERSION = do { my @r = ( q$Revision: 4.40 $ =~ /\d+/g ); sprintf "%d." . "%02d" x $#r, @r };
my $URL_BASE        = 'http://forecast.weather.gov/product.php?site=';
my $ZONE_SEARCH_URL = 'https://forecast.weather.gov/zipcity.php';

use vars '$proxy_from_env';
$proxy_from_env = 0;

# Preloaded methods go here.

sub print_forecast {
    my ( $city, $state, $filename, $fileopt, $UA ) = @_;
    my $in = get_city_zone( $city, $state, $filename, $fileopt, $UA );

    my $out;

    $out = "Geo::WeatherNOAA.pm v.$Geo::WeatherNOAA::VERSION\n";

    my ( $date, $warnings, $forecast ) =
      process_city_zone( $city, $state, $filename, $fileopt );

    $out .= "As of $date:\n";
    foreach my $warning (@$warnings) {
        $out .= wrap( 'WARNING: ', '    ', "$warning\n" );
    }
    foreach my $key ( keys %$forecast ) {
        $out .= wrap( '', '    ', "$key: $forecast->{$key}\n" );
    }
    return $out;
}

#########################################################################
#########################################################################
#
# Zone file processing
#
#########################################################################
#########################################################################
sub process_city_zone {
    my ( $city, $state, $filename, $fileopt, $UA ) = @_;
    my $in = get_city_zone( $city, $state, $filename, $fileopt, $UA );

    # Return error if problem getting URL
    if ( $in =~ /Error/ ) {
        my %error;
        my @null;
        $error{'Error'}         = 'Error';
        $error{'Network Error'} = $in;
        return ( '', \@null, \%error );
    }

    #print STDERR $in;exit;

    # Split coverage, date, and forecast
    #
    my ( $coverage, $date, $forecast ) = (
        $in =~ /(^.*?)\012  # Coverage
                                                    (\d.*?)\012 # Date
                                                    (.*)/sx
    );    # Entire Forecast

    # Format Coverage
    #
    $coverage =~ s/corrected//gi;         # Remove stat word
    $coverage =~ s/(\/|-|\.\.\.)/, /g;    # Turn weird punct to commas
    $coverage =~ s/,\s*$//;               # Remove last comma
    $coverage = ucfirst_words($coverage); # Make caps correct

    # Format date (easy)
    #
    $date = format_date($date);

    # Vars for forecast
    #
    my %forecast;
    tie %forecast, "Tie::IxHash";
    my @warnings;

    # Iterate through forecast and assign warnings to list or pairs to hash
    #
    my $forecast_item;    # Used as place holder for line breaks of $value
    my $warnings_done = 0;    # Flag for warnings (Always at top of forcast)

    foreach my $line ( split "\012", $forecast ) {

        # Be-gone if we've got temp data (will include parse for that later)
        last if $line =~ /^\.</;

        my ( $key, $value );
        ( $key, $value ) = ( $line =~ /(.*?)\.\.\.(.*)/ );

        if ( !$value ) {

            # If there's no value, this must be either a warning or
            # a continutation of value-data
            $key = $line;
        }
        next if ( $key =~ /EXTENDED/ );

        $warnings_done = 1 if ( ($key) and ($value) );

        #print "WARN_DONE: $warnings_done\n";

        if ($warnings_done) {
            if ( ( $key =~ s/^\.// ) and ($value) and ($key) ) {

                # Add VALUE to KEY (new key)
                $key =~ s/^\.//;
                $key           = ucfirst_words($key);
                $forecast_item = $key;
                $forecast{$forecast_item} .= $value;
            }
            elsif ($forecast_item) {

                # Add KEY (with data) to OLD KEY (FORECAST_ITEM)
                $forecast{$forecast_item} .= ' ' . $key;
                $forecast{$forecast_item} .= ', ' . $value if $value;
            }
            else {
                # print "LINE IGNORED\n";
            }
        }
        elsif ( !$warnings_done ) {
            if ( ( !$key ) and ($value) ) {
                $value = ucfirst lc $value;
                push @warnings, $value;
            }
            elsif ( ($key) and ( !$value ) ) {
                $key = ucfirst lc $key;
                push @warnings, $key;
            }
        }
        else {
            # line ignored
        }
    }

    foreach my $key ( keys %forecast ) {
        $forecast{$key} =~ tr/\012//d;    # Remove newlines
             #$forecast{$key} = lc($forecast{$key}); # No all CAPS
        $forecast{$key} =~ s/\s+/ /g;    # Rid of multi-spaces
        $forecast{$key} = sent_caps( $forecast{$key} );   # Proper sentance caps
    }

    return ( $date, \@warnings, \%forecast, $coverage );

}    # process_city_zone()

sub get_city_zone {
    my ( $city, $state, $filename, $fileopt, $UA ) = @_;
    my $zone = &get_zone( $ZONE_SEARCH_URL, "$city, $state" );
    my $URL =
        $URL_BASE
      . $zone
      . '&issuedby='
      . $zone
      . '&product=ZFP&format=txt&version=1&glossary=0';

    # City and States must be capital
    #
    $state = uc($state);
    $city  = uc($city);

    # Declare some working vars
    #
    my ( $rawData, $coverage );

    # Get data from filehandle object
    #
    $rawData = get_data( $URL, $filename, $fileopt, $UA );

    # clean raw data to remove leading whitespace (I hope this works) 2006-12-10
    #$rawData =~ s#\n\s*\.#\n.#gm;

    #my $t1 = $rawData;
    #$rawData =~ s#\r\n#\n#sg;
    $rawData =~ s#\n\s+#\n#sg;

    $rawData =~ s#\$\$#ENDOFSECTION#sg;

    # print STDERR $rawData;
    foreach my $line ( $rawData =~ /\n(\w\wZ.*?)\012/sg ) {
        $line =~ s/\r//g;
        $line =~ s/\n//g;

        # print STDERR "HERE: " . $line . "\n";
        my $pattern = "$line\\n(.*?)\\n(?:ENDOFSECTION|NNN)";

        #print STDERR "PATTERN=" . $pattern . "<--\n";
        my $section = ( $rawData =~ /$pattern/sg )[0];
        if ($section) {

            #print "\n\n$section\n";
            #print "   SIZE OF DATA: " . length($section) . "\n";
            # Iterate though section and get coverage
            my $coverage_ended = 0;
            foreach my $line ( split /\012/, $section ) {
                $line =~ tr/\015//d;    # \r
                $coverage .= $line . "\n" if ( !$coverage_ended );
                if ( $line !~ /^\w/ ) {
                    $coverage_ended = 1;
                }
            }
            return $section
              if ( ( $coverage =~ /$city/i ) && ( $section =~ /\d{4}/ ) );
        }
    }
    return "$city not found";

    # Return error if there's an error
    if ( $rawData =~ /Error/ ) {
        return $rawData;
    }

    # Find our city's data from all raw data
    #
    #foreach my $section ($rawData =~ /\012${state}Z.*?     # StateZone
    foreach my $section (
        $rawData =~ /\013\w\wZ.*?  # StateZone
                                          \012\013(.*?)         # Data sect
                                          \012\013(?:\$\$|NNN)/xsg
      )
    {
        # print STDERR "\n\nSECTION:\n$section\n";
        # Iterate though section and get coverage
        my $coverage_ended = 0;
        foreach my $line ( split /\012/, $section ) {
            $line =~ tr/\015//d;    # \r
            $coverage .= $line . "\n" if ( !$coverage_ended );
            if ( $line !~ /^\w/ ) {
                $coverage_ended = 1;
            }
        }
        return $section
          if ( ( $coverage =~ /$city/i ) && ( $section =~ /\d{4}/ ) );
    }
    return "$city not found";
}

##############################################################################
##############################################################################
##
## Html for Mark's Site
##
##############################################################################
##############################################################################

sub font {
    my $in        = shift;
    my $size      = shift || 2;
    my $font_face = $main::font_face || 'FACE="Helvetica, Lucida, Ariel"';
    return qq|<FONT SIZE="$size" $font_face>$in</FONT>|;
}

sub make_noaa_table {
    my ( $city, $state, $filename, $fileopt, $UA, $max_items ) = @_;

    $fileopt ||= 'get';
    $max_items && $max_items--;
    $max_items ||= 4;

    my $med_bg    = $main::med_bg    || '#ddddff';
    my $light_bg  = $main::light_bg  || '#eeeeff';
    my $font_face = $main::font_face || 'FACE="Helvetica, Lucida, Ariel"';

    my $locfilename;
    $locfilename = $filename . "_hourly";
    my $current =
      process_city_hourly( $city, $state, $locfilename, $fileopt, $UA );

    $locfilename = $filename . "_zone";
    my ( $date, $warnings, $forecast, $coverage ) =
      process_city_zone( $city, $state, $locfilename, $fileopt, $UA );
    my $cols = ( keys %$forecast );
    $cols = $max_items if $cols > $max_items;
    my $out;
    $out .= qq|<TABLE WIDTH="100%" CELLPADDING=1>\n|;
    $out .= qq|<!-- Current weather row -->\n|;
    $out .= qq|<TR VALIGN=TOP><TD BGCOLOR="$med_bg">\n|;
    $out .= font('Current') . "\n</TD>\n";
    $out .= qq|<TD COLSPAN="$cols">|;
    $out .= font($current) . "\n</TD></TR>\n";

    # Add one to make cols real width of table
    #
    $cols++;

    # Add warnings, if needed
    #
    if (@$warnings) {
        $out .= qq|<!-- Warnings -->\n|;
        foreach my $warning (@$warnings) {
            $out .= qq|<TR BGCOLOR="#FF8389" ALIGN="CENTER">\n|;
            $out .= qq|\t<TD COLSPAN="$cols">|;
            $out .= qq|<FONT $font_face COLOR="#440000">\n|;
            $out .= qq|\t$warning\n</TD></TR>\n|;
        }
    }

    # Iterate over the first $max_items items in forecast
    #
    my $bottom;    # add this after the iteration;
    $out    .= qq|<TR VALIGN="TOP" BGCOLOR="$med_bg">\n|;
    $bottom .= qq|<TR VALIGN="TOP">\n|;
    foreach my $key ( ( keys %$forecast )[ 0 .. ( $cols - 1 ) ] ) {

        #print STDERR "DEBUG: $key\n";
        $out .= "\t<TD>" . font($key) . "</TD>\n";
        $bottom .= "\t<TD>" . font( $forecast->{$key} ) . "</TD>\n";
    }
    $out .= "</TR>\n" . $bottom . "</TR>\n";

    # Add coverage area
    $out .= qq|<TR BGCOLOR="$light_bg" ALIGN="LEFT">\n|;
    $out .= qq|     <TD>| . font('Area') . qq|</TD>\n|;
    $out .= qq|     <TD COLSPAN="$cols">| . font( $coverage, 1 ) . qq|</TD>\n|;
    $out .= qq|</TR>\n|;

    # Add credits
    #
    my $wx_cred =
        '<A HREF="http://www.noaa.gov">NOAA</A> forecast made '
      . "$date by "
      . "<A HREF=\"http://www.seva.net/~msolomon/WeatherNOAA/dist/\">"
      . "Geo::WeatherNOAA</A> V.$Geo::WeatherNOAA::VERSION";
    $out .= qq|<TR BGCOLOR="$light_bg" ALIGN="CENTER">\n|;
    $out .= qq|<TD COLSPAN="$cols">| . font($wx_cred) . "</TD></TR>\n";
    $out .= qq|</TABLE>\n|;

}

##############################################################################
##############################################################################
##
## Misc funcs
##
##############################################################################
##############################################################################

sub get_zone {
    my ( $URL, $CityState, $UA ) = @_;

    $URL or die "No URL to get!";

    # Create the useragent and get the data
    #
    if ( !$UA ) {
        $UA = new LWP::UserAgent;
        if ( $ENV{'HTTP_PROXY'} or $ENV{'http_proxy'} ) {
            $UA->env_proxy;
        }
    }

    $UA->agent("WeatherNOAA/$VERSION");

    my $ua = LWP::UserAgent->new();
    my $response = $ua->post( $URL, { 'inputstring' => $CityState, 'Go2' => 'Go' } );
    my $location = $response->header('Location');

    if ( $location =~ /&site=(...)&/ ) {
        return $1;
    }
    else {
        return;
    }

}

sub get_url {
    my ( $URL, $UA ) = @_;

    $URL or die "No URL to get!";

    # Create the useragent and get the data
    #
    if ( !$UA ) {
        $UA = new LWP::UserAgent;
        if ( $ENV{'HTTP_PROXY'} or $ENV{'http_proxy'} ) {
            $UA->env_proxy;
        }
    }
    $UA->agent("WeatherNOAA/$VERSION");

    # Create a request
    my $req = new HTTP::Request GET => $URL;
    my $res = $UA->request($req);
    if ( $res->is_success ) {
        return $res->content;
    }
    else {
        return;
    }
}    # getURL()

sub get_data {
    my ( $URL, $filename, $fileopt, $UA ) = @_;

    $fileopt ||= 'get';

    my $data;    # Data

    if ( ( $fileopt eq 'get' ) || ( $fileopt eq 'save' ) ) {
        print STDERR "Retrieving $URL\n" if $main::opt_v;
        $data = get_url( $URL, $UA )
          || return "Error getting data from $URL";
        if ( $fileopt eq 'save' ) {
            print STDERR "Writing $URL to $filename\n" if $main::opt_v;
            open( OUT, ">$filename" ) or die "Cannot create $filename";
            print OUT $data;
            close OUT;
            $fileopt = 'usefile';
        }
    }
    if ( $fileopt eq 'usefile' ) {
        print STDERR "Reading data from $filename\n" if $main::opt_v;
        open( FILE, $filename ) or die "Cannot read $filename";
        while (<FILE>) { $data .= $_; }
    }
    return $data;
}    # get_fh

sub format_date {
    my $in = shift;
    $in =~
      s/^(\d+)(\d\d)\s(AM|PM)\s(\w+)\s(\w+)\s(\w+)\s0*(\d+)/$1:$2\L$3\E ($4) \u\L$5\E\E \u\L$6 $7,/;
    $in =~ tr/\015//d;    # \r
    return $in;
}

sub sent_caps {
    my $in = shift;
    $in = ucfirst( lc($in) );
    $in =~ s/(\.\W+)(\w)/$1\U$2/g;    # Proper sentance caps
    return $in;
}

sub ucfirst_words {
    my ($in) = @_;
    return join " ", map ucfirst( lc($_) ), ( split /\s+/, $in );
}

#########################################################################
#########################################################################
##
## Hourly city data
##
#########################################################################
#########################################################################

sub get_city_hourly {
    my ( $city, $state, $filename, $fileopt, $UA, $rwrzone ) = @_;
    # City and state in all caps please
    #
    $city  = uc $city;
    $state = uc $state;

    # work var
    my ( $fields, $line, $date, $time );

    # Get data
    #
    my $zone = &get_zone( $ZONE_SEARCH_URL, "$city, $state" );
    $rwrzone = $zone unless length($rwrzone);
    my $URL =
        $URL_BASE
      . $zone
      . '&issuedby='
      . $rwrzone
      . '&product=RWR&format=txt&version=1&glossary=0';

    #print STDERR "Getting data from $URL\n";
    my $data = get_data( $URL, $filename, $fileopt, $UA );
    my $datalength = length($data);
    if ( $data =~ /None issued/ ) {
        $URL =
            $URL_BASE
          . $zone
          . '&issuedby='
          . $state
          . '&product=RWR&format=txt&version=1&glossary=0';

        $data = get_data( $URL, $filename, $fileopt, $UA );
        $datalength = length($data);
    }
    if ( $data =~ /None issued/ ) {
	print "
	NWS is not returing any information, please configure the 2 or 3 letter zone
        in the mh.private.ini with the nws_rwr_zone option. IE: nws_rwr_zone=LIX
	The zone can be found at the following site:
	http://forecast.weather.gov/product_sites.php?site=$zone&product=RWR\n
	";	
    }
    #print STDERR "Got data ($datalength)\n";

    # Return error if there's an error
    if ( $data =~ /Error/ ) {
        my %retHash;
        $retHash{ERROR} = $data;
        return \%retHash;
    }

    $data =~ s/\015//g;    # \r

    #print STDERR "LOOKING FOR: " . $city . "\n";

    # Get line for our city from Data
    #
    foreach ( split /\012/, $data ) {
        chomp;
        s/^\s*//;
        $date = $_ if /^\s*(\d+)(\d\d)\s+(AM|PM)\s+(\w+)/;
        $time   = "$1:$2 $3" if ( ($1) && ($2) && ($3) );
        $fields = $_         if /^CITY/;
        $line   = $_         if /^$city/;

        #print STDERR "LINE: $line\n" if $line;

        # Newest data seems to be at the top of the file
        last if $line;
    }
    $date = format_date($date);

    # Set pack strings
    #
    my $fields_pack_str;
    my $values_pack_str;
    if ( ( $fields =~ /TMP/ ) and ( $fields =~ /\sDP\s/ ) ) {

        #print STDERR "NEW FORMAT!\n";
        $fields_pack_str =
          '@0 A15 @15 A9 @25 A3 @29 A2 @33 A2 @36 A8 @47 A5 @54 A7';
        $values_pack_str =
          '@0 A15 @15 A8 @24 A4 @28 A4 @32 A3 @36 A8 @46 A7 @53 A8';
    }
    else {
        #print STDERR "OLD FORMAT!\n";
        $fields_pack_str =
          '@0 A15 @15 A9 @24 A5 @29 A5 @35 A4 @39 A8 @47 A8 @55 A8';
        $values_pack_str =
          '@0 A15 @15 A9 @24 A5 @29 A5 @34 A4 @39 A8 @47 A8 @55 A8';
    }

    # unpack gives error of the string is smaller than the unpack string
    $line .= ' ' x ( 64 - length($line) ) if length($line) < 64;

    return {} unless ( ($line) && ($fields) );    # Return ref to empty hash

    my @fields;
    push @fields, 'DATE', 'TIME', unpack $fields_pack_str, $fields if $fields;

    #'@0 A15 @15 A9 @24 A5 @29 A5 @35 A4 @39 A8 @47 A8 @55 A8', $fields if $fields;
    my @values;
    push @values, $date, $time, unpack $values_pack_str, $line;

    #print STDERR "$line\n";
    #'@0 A15 @15 A9 @24 A5 @29 A5 @34 A4 @39 A8 @47 A8 @55 A8', $line;

    return {} if $values[3] eq 'NOT AVBL';        # Return ref to empty hash

    my %retValue;
    foreach my $i ( 0 .. $#fields ) {

        # Convert odd fieldnames to standard
        $fields[$i] = 'DEWPT' if $fields[$i] eq 'DP';
        $fields[$i] = 'TEMP'  if $fields[$i] eq 'TMP';

        # Assign value
        $retValue{ $fields[$i] } = $values[$i];
    }

    return \%retValue;

}    # get_city_hourly()

sub print_current {
    my ( $city, $state, $filename, $fileopt, $UA, $rwrzone ) = @_;
    my $in = process_city_hourly( $city, $state, $filename, $fileopt, $UA, $rwrzone );
    return wrap( '', '    ', $in );
}

sub process_city_hourly {
    my ( $city, $state, $filename, $fileopt, $UA, $rwrzone ) = @_;
    my $in = get_city_hourly( $city, $state, $filename, $fileopt, $UA, $rwrzone );

    $state = uc($state);

    return $in->{ERROR} if $in->{ERROR};
    $in->{CITY} or return "No data available";
    $in->{CITY} = ucfirst_words( $in->{CITY} );

    my %sky = (
        'SUNNY'    => 'sunny skies',
        'MOSUNNY'  => 'mostly sunny skies',
        'PTSUNNY'  => 'partly sunny skies',
        'CLEAR'    => 'clear weather',
        'DRIZZLE'  => 'a drizzle',
        'CLOUDY'   => 'cloudy skies',
        'MOCLDY'   => 'mostly cloudy skies',
        'PTCLDY'   => 'partly cloudy skies',
        'LGT RAIN' => 'light rain',
        'FRZ DRZL' => 'freezing drizzle',
        'FLURRIES' => 'flurries',
        'LGT SNOW' => 'light snow',
        'SNOW'     => 'snow',
        'N/A'      => 'N/A',
        'NOT AVBL' => '*not available*',
        'FAIR'     => 'fair weather'
    );

    # Format the wind direction and speed
    #
    my %compass = qw/N north S south E east W west/;

    # my $direction = join '',map $compass{$_},split(/(\w)\d/g, $in->{WIND});
    my $direction;
    {
        $direction = $in->{WIND};
        $direction =~ s/(.*?)G.*/$1/;    # Remove gusts
        $direction =~ s/\d//g;           # Remove digits
        if ($direction) {
            $direction = $compass{$direction};
        }
    }
    my ($speed) = ( $in->{WIND} =~ /(\d+)/ );
    my ($gusts) = ( $in->{WIND} =~ /G(\d+)/ );

    if ( $in->{WIND} eq 'CALM' ) {
        $in->{WIND} = 'calm';
    }
    else {
        $in->{WIND} = "$direction at ${speed} mph";
        $in->{WIND} .= ", gusts up to ${gusts} mph" if $gusts;
    }

    # Format relative humidity and ibarometric pressure
    #
    my $rh_pres;
    if ( $in->{RH} ) {
        $rh_pres = " The relative humidity was $in->{RH}\%";
    }
    if ( $in->{PRES} ) {
        my %rise_fall = qw/R rising S steady F falling/;

        # my $direction = join '',map $rise_fall{$_},split(/\d(\w)/g, $in->{PRES});
        my $direction;
        {
            $direction = $in->{PRES};
            $direction = ( $direction =~ /.*(\w)$/ )[0];
            if ($direction) {
                $direction = $rise_fall{$direction};
            }
        }
        $in->{PRES} =~ tr/RSF//d;
        if ($rh_pres) {
            $rh_pres .= ", and b";
        }
        else {
            $rh_pres .= " B";
        }
        $rh_pres .= "arometric pressure was $direction from $in->{PRES} in";
    }
    $rh_pres .= '.' if $rh_pres;

    # Format output sentence
    #
    my $out;
    $out = "At $in->{TIME}, $in->{CITY}, $state conditions were ";
    $out .= $sky{ $in->{'SKY/WX'} } . " ";
    $out .= "at $in->{TEMP}&deg;F, wind was $in->{WIND}. $rh_pres\n";
    return $out;

}    # process_city_hourly()

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Geo::WeatherNOAA - Perl extension for interpreting the NOAA weather data

=head1 SYNOPSIS

  use Geo::WeatherNOAA;
  ($date,$warnings,$forecast,$coverage) =
     process_city_zone('newport','ri','','get');

  foreach $key (keys %$forecast) {
        print "$key: $forecast->{$key}\n";
  }

  print process_city_hourly('newport news', 'va', '', 'get');

or

  use Geo::WeatherNOAA;
  print print_forecast('newport news','va');

=head1 DESCRIPTION

This module is intended to interpret the NOAA zone forecasts and current
city hourly data files.  It should give a programmer an easy time to use the
data instead of having to mine it.

Be aware that if the variable $main::opt_v is set to anything (other than
zero or '') then Geo::WeatherNOAA will be verbose  on what it's doing with
messages sent to STDERR.  Useful for debugging.

=head1 REQUIRES

=over 4

=item * Tie::IxHash

=item * LWP::Simple

=item * LWP::UserAgent

=item * Text::Wrap

=back

=head1 FUNCTIONS

=over 4

=item * print_forecast(CITY,STATE,FILENAME,FILEOPT,LWP_UserAgent)

Returns text of the forecast

=item * print_current(CITY,STATE,FILENAME,FILEOPT,LWP_UserAgent)

Returns text of current weather

=item * make_noaa_table(CITY,STATE,FILENAME,FILEOPT,LWP_UserAgent, MaxItems)

This call gives the basic html table with current data and forecast for the
next four periods ("tonight", "tomorrow","tomorrow night","day after")
and warnings in an (I think) attractive, easy to read way.

Max Items is a way to limit the number of items in the table returned...
I think it looks best with no more than 4...5 gets crowded looking.

=item * process_city_hourly(CITY,STATE,FILENAME,FILEOPT,LWP_UserAgent)

FILENAME is the file read from with FILEOPT "usefile" and written to
if FILEOPT is "save"

FILEOPT can be one of the following

        - save
                will get and save the data to FILENAME
        - get
                will retrieve new data (not store it)
        - usefile
                will not retrieve data from URL,
                use FILENAME for data

The fifth argument is for a user created LWP::UserAgent(3) which can
be configured to work with firewalls. See the LWP::UserAgent(3) manpage
for specific instructions. A basic example is like this:

   my $ua = new LWP::UserAgent;
   $ua->proxy(['http', 'ftp'], 'http://proxy.my.net:8080/');

NOTE: You may also set the environment variable <CODE>http_proxy</CODE>
and the auto-generated LWP::UserAgent will use LWP::UserAgent::env_proxy().
See LWP::UserAgent for more details.

=item * process_city_zone(CITY,STATE,FILENAME,FILEOPT,LWP_UserAgent)

Call CITY, STATE, FILENAME (explained above), FILEOPT(explained above),
and UserAgent (Explained above).

Note that in August 2016 the NOAA site stopped using STATE as the defining
field, instead using 3-digit regional codes, available at:
http://forecast.weather.gov/product_sites.php?site=CRH&product=ZFP
All of the $state values should be the 3-digit code.

The return is a three element list containing a) a string of the date/time
of the forecast, b) a reference to the list of warnings (if any), and
c) a reference to the hash of forecast.  I recommend calling it like this:

    ($date, $warnings, $forecast, $coverage) =
        process_city_zone('newport news','va',
        '/tmp/va_zone.html', 'save');

Explanation of this call, it returns:

        $date
        - Scalar of the date of the forecast

        $warnings
        - Reference to the warnings list
        - EXAMPLE:
          foreach (@$warnings) { print; }

        $forecast
        - Reference to the forecast KEY, VALUE pairs
        - EXAMPLE:
          foreach $key (keys %$forecast) {
                print "$key: $forecast->{$key}\n";
          }

        $coverage
        - Scalar of the coverage area of the forecast


=item * get_city_zone(CITY,STATE,FILENAME,FILEOPT,LWP_UserAgent)

This sub is to get the block of data from the data source, which is
chosen with the FILEOPTswitch.

=item * get_city_hourly(CITY,STATE,FILENAME,FILEOPT,LWP_UserAgent)

This function gets the current weather from the data source, which is
decided from FILEOPT(explained above).  Input is CITY, STATE,
FILENAME (filename to read/write from if FILEOPTis "get" or "usefile"),
and UserAgent.

This function returns a reference to a hash containing the data. It

Same FILEOPTand LWP_UserAgent from above, and process the
current weather data into an english sentence.

=back

=head1 AUTHOR

Mark Solomon

msolomon@seva.net

http://www.seva.net/~msolomon/

=head1 SEE ALSO

perl(1), Tie::IxHash(3), LWP::Simple(3), LWP::UserAgent(3).

=cut

