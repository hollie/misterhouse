# $Id$

# This module is used for decoding NWS METAR code.

# Example METARs
#
# Findlay, Ohio
# KFDY 251450Z 21012G21KT 8SM OVC065 04/M01 A3010 RMK SLP201 57014
#
# Toledo, Ohio
# KTOL 251451Z 23016G22KT 8SM CLR 04/00 A3006 RMK AO2 SLP185 T00440000 56016 
#
# Cleveland, Ohio
# KCLE 251554Z 20015KT 10SM FEW055 OVC070 03/M02 A3011 RMK AO2 SLP205 T00331017
#
# Houston, Texas
# KHST 251455Z 06017G22KT 7SM FEW040 BKN330 25/18 A3016 RMK SLP213 8/508
# 9/205 51007
#
# LA
# KLAX 251450Z 07004KT 7SM SCT100 BKN200 14/11 A3005 RMK AO2 SLP173
# T01390111 56005

# For METAR info, please see
# http://tgsv5.nws.noaa.gov/oso/oso1/oso12/metar.htm

# The METAR specification is dictated in the Federal Meteorological Handbook
# which is available on-line at:
# http://tgsv5.nws.noaa.gov/oso/oso1/oso12/fmh1.htm

# General Structure is:
# SITE, DATE/TIME, WIND, VISIBILITY, CLOUDS, TEMPERATURE, PRESSURE, REMARKS

# Specifically:

# SITE
#
# 4-Char site identifier (KLAX for LA, KHST for Houston)

# DATE/TIME
#
# 6-digit time followed by "Z", indicating UTC

# WIND
#
# Wind direction (\d\d\d) and speed (\d?\d\d) and optionaling gusting
# information denoted by "G" and speed (\d?\d\d) followed by "KT", for knots.
#
# Wind direction MAY be "VRB" (variable) instead of a compass direction.
#
# Calm wind is recorded as 00000KT.

# VISIBILITY
#
# Visibility (\d+) followed by "SM" for statute miles
#
# May be 1/(\d)SM for a fraction.
#
# May be M1/\d)SM for less than a given fraction. (M="-")

# RUNWAY Visual Range Group (I've never seen this, but it's in the spec)
#
# R(\d\d\d)(L|C|R)?/((M|P)?\d\d\d\d){1,2}FT
#
# Where:
#  $1 is the runway number.
#  $2 is the runway (Left/Center/Right) for parallel runways.
#  $3 is the reported visibility in feet.
#  $4 is the MAXIMUM reported visibility, making $3 the MINIMUM.
#
#  "M" beginning a value means less than the reportable value of \d\d\d\d.
#  "P" beginning a value means more than the reportable value of \d\d\d\d.

# WEATHER (Present Weather Group)
#
# See table in Chapter 12 of FMH-1.

# CLOUDS (Sky Condition Group)
#
# A space-separated grouping of cloud conditions which will contain at least
# one cloud report. Examples: "CLR", "BKN330", "SCT100", "FEW055", "OVC070"
# The three-letter codes represent the condition (Clear, Broken, Scattered,
# Few, Overcast) and the numbers (\d\d\d) represent altitlude/100.
#
# The report may have a trailing CB (cumulonimbus) or TCU (towering
# cumulus) appended. ([A-Z]{2,3})?(\d\d\d)(CB|TCU)?

# TEMPERATURE and DEW POINT
#
# (M?\d\d)/(M?\d\d) where $1 is the current temperature in degrees celcius,
# and $2 is the current dewpoint in degrees celcius.
#
# The "M" signifies a negative temperature, so converting the "M" to a
# "-" ought to suffice.

# PRESSURE
#
# The pressure, or altimeter setting, at the reporting site recorded in
# inches of mercury (Hg) minus the decimal point. It should always look
# like (A\d\d\d\d).

# REMARKS
#
# Remarks contain additional information. They are optional but often
# informative of special conditions.
#
# Remarks begin with the "RMK" keyword and continue to the end of the line.
#
# This module currently doesn't attempt to decode remarks but may in the
# future.

### Package Definition

package Geo::METAR;

### Required Modules

require 5.004;
use Carp;

### Globals/Constants

my $revision = '$Revision$';
   $revision =~ m/: (\d+)/;
   $revision = $1;
   $VERSION  = $revision;
my $debug       = 0;


### Begin Object Methods

# Constructor.

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};

    ### Instance Variables

    # UPPERCASE items have accssor functions (methods), while
    # lowercase items are reserved for internal use.

    $self->{VERSION}       = $VERSION;          # version number
    $self->{METAR}         = undef;             # the actual, raw METAR
    $self->{TYPE}          = undef;             # the type of report
    $self->{SITE}          = undef;             # site code
    $self->{DATE}          = undef;             # when it was issued
    $self->{TIME}          = undef;             # time it was issued
    $self->{MOD}           = undef;             # modifier (AUTO/COR)
    $self->{WIND_DIR_DEG}  = undef;             # wind dir in degrees
    $self->{WIND_DIR_ENG}  = undef;             # wind dir in english (NW/SE)
    $self->{WIND_KTS}      = undef;             # wind speed (knots)
    $self->{WIND_KTS_GUST} = undef;             # wind gusts (knots)
    $self->{WIND_MPH}      = undef;             # wind speed (MPH)
    $self->{WIND_MPH_GUST} = undef;             # wind gusts (MPH)
    $self->{VISIBILITY}    = undef;             # visibility info
    $self->{RUNWAY}        = undef;             # runyway vis.
    $self->{WEATHER}       = [ ];               # current weather
    $self->{SKY}           = [ ];               # curent sky
    $self->{C_TEMP}        = undef;             # current temp, celcius
    $self->{F_TEMP}        = undef;             # converted to farenheit
    $self->{C_DEW}         = undef;             # dew point, celcius
    $self->{F_DEW}         = undef;             # dew point, farenheit
    $self->{ALT}           = undef;             # altimeter setting [pressure]
    $self->{REMARKS}       = undef;             # remarks and such

    $self->{tokens}        = [ ];               # the "token" list
    $self->{type}          = "METAR";           # the report type (METAR/SPECI)
                                                # default=METAR
    $self->{site}          = undef;             # the site code (4 chars)
    $self->{date_time}     = undef;             # date/time
    $self->{modifier}      = "AUTO";            # the AUTO/COR modifier (if
                                                # any) default=AUTO
    $self->{wind}          = undef;             # the wind information
    $self->{visibility}    = undef;             # visibility information
    $self->{runway}        = undef;             # runway visibility
    $self->{weather}       = [ ];               # current weather conditions
    $self->{sky}           = [ ];               # sky conditions (cloud cover)
    $self->{temp_dew}      = undef;             # temp and dew pt.
    $self->{alt}           = undef;             # altimeter setting
    $self->{remarks}       = [ ];               # remarks


    bless $self, $class;
    return $self;
}

# ----------------------------------------------- #

# Autoload for access methods to stuff in %fields hash

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self) || croak "$self is not an object";
    my $name = $AUTOLOAD;
    $name =~ s/.*:://;          # strip fully-qualified portion of name
    unless (exists $self->{$name}) {
        croak "You suck.  You tried to access something that is not here.";
    }
    return $self->{$name};
} # end AUTOLOAD

# ----------------------------------------------- #

# Get current version number.

sub version {
    my $self = shift;
    print "version() called.\n" if $debug;
    return $self->{VERSION};
}

# ----------------------------------------------- #

sub metar {
    my $self = shift;
    if (@_) {
        $self->{METAR} = shift; 
        $self->{METAR} =~ s/\n//goi;    # nuke any newlines
        _tokenize($self);
        _process($self);
    }
    return $self->{METAR};
}

# ----------------------------------------------- #

# Break {METAR} into parts. Stuff into @tokens.

sub _tokenize {
    my $self = shift;
    my $tok;
    my @toks;

    # Split tokens on whitespace.
    @toks = split(/\s+/, $self->{METAR});
    $self->{tokens} = \@toks;

}

# ----------------------------------------------- #

# Process @tokens to populate METAR values.
#
# This is a long and involved subroutine. It basically
# copies the @tokens array and treats it as a stack, popping
# off items, examining them, and see what they look like.
# Based on their "apppearance" it takes care populating the
# proper fields internally.

sub _process {

    my $self = shift;

    my @toks = @{$self->{tokens}};      # copy tokens array...

    my $tok;

    # This is a semi-brute-force way of doing things, but the
    # amount of data is relatively small, so it shouldn't be
    # a big deal.
    #
    # Ideally, I'd have it skip checks for items which have
    # been found, but that would make this more "linear" and
    # I'd remove the pretty while loop.

    while($tok = shift(@toks)) {        # as long as there are tokens

        print "trying to match [$tok]\n" if $debug;

        # is it a report type?

        if (($tok =~ /METAR/i) or ($tok =~ /SPECI/i)) {
            $self->{type} = $tok;
            print "[$tok] is a report type.\n" if $debug;
            next;

            # is is a site ID?
        } elsif ($tok =~ /K[A-Z]{3,3}/) {       
            $self->{site} = $tok;
            print "[$tok] is a site ID.\n" if $debug;
            next;

            # is it a date/time?
        } elsif($tok =~ /\d{6,6}Z/i) {
            $self->{date_time} = $tok;
            print "[$tok] is a date/time.\n" if $debug;
            next;

            # is it a report modifier?
        } elsif(($tok =~ /AUTO/i) or ($tok =~ /COR/i)) {
            $self->{modifier} = $tok;
            print "[$tok] is a report modifier.\n" if $debug;
            next;

            # is it wind information?
        } elsif($tok =~ /.*?KT$/i) {
            $self->{wind} = $tok;
            print "[$tok] is wind information.\n" if $debug;
            next;

            # is it visibility information?
        } elsif($tok =~ /.*?SM$/i) {
            $self->{visibility} = $tok;
            print "[$tok] is visibility information.\n" if $debug;
            next;

            # is it visibility information with a leading digit?
        } elsif($tok =~ /^\d$/) {

            $tok .= " " . shift(@toks);
            $self->{visibility} = $tok;
            print "[$tok is multi-part visibility information.\n" if $debug;
            next;

            # is it runway visibility info?
        } elsif($tok =~ /R.*?FT$/i) {
            $self->{runway} = $tok;
            print "[$tok] is runway visual information.\n" if $debug;
            next;

            # is it current weather info?
        } elsif($tok =~ /^(-|\+|VC)?(TS|SH|FZ|BL|DR|MI|BC|PR|RA|DZ|SN|SG|GR|GS|PE|IC|UP|BR|FG|FU|VA|DU|SA|HZ|PY|PO|SQ|FC|SS|DS)+$/) {

            push(@{$self->{weather}},$tok);
            print "[$tok] is current weather.\n" if $debug;
            next;

            # is it sky conditions (clouds)?
        } elsif(($tok =~ /SKC|CLR/i) or
                ($tok =~ /(FEW|SCT|BKN|OVC)(\d\d\d)(CB|TCU)?$/i)) {

            push(@{$self->{sky}},$tok);
            print "[$tok] is a sky condition.\n" if $debug;
            next;

            # is it temperature and dew point info?
        } elsif($tok =~ /(M?\d\d)\/(M?\d\d)/i) {
            next if $self->{temp_dew};
            $self->{temp_dew} = $tok;
            print "[$tok] is temperature/dew point information.\n" if $debug;
            next;

            # is it an altimeter setting?
        } elsif($tok =~ /A\d{4,4}$/i) {

            $self->{alt} = $tok;
            print "[$tok] is an altimeter setting.\n" if $debug;
            next;

            # remarks?
        } elsif($tok =~ /^RMK$/i) {

            push(@{$self->{remarks}},$tok);
            print "[$tok] is a remark.\n" if $debug;
            next;

        # unknown. assume remarks
        } else {

            push(@{$self->{remarks}},$tok);
            print "[$tok] is unknown. Assuming remarks.\n" if $debug;
            next;
        }

    } # end while

    # Now that the internal stuff is set, let's do the external
    # stuff.

    if ($self->{type} eq "METAR") {
        $self->{TYPE} = "Routine Weather Report";
    }
    $self->{SITE} = $self->{site};
    $self->{DATE} = substr($self->{date_time},0,2);
    $self->{TIME} = substr($self->{date_time},2,4) . " UTC";
    $self->{TIME} =~ s/(\d\d)(\d\d)/$1:$2/o;
    $self->{MOD}  = $self->{modifier};

    # Okay, wind finally gets interesting.

    {
        my $wind = $self->{wind};
        my $dir_deg  = substr($wind,0,3);
        my $dir_eng = "";

        # Check for wind direction
        if ($dir_deg =~ /VRB/i) {
            $dir_deg = "Variable";
        } else {
            if      ($dir_deg < 15) {
                $dir_eng = "North";
            } elsif ($dir_deg < 30) {
                $dir_eng = "North/Northeast";
            } elsif ($dir_deg < 60) {
                $dir_eng = "Northeast";
            } elsif ($dir_deg < 75) {
                $dir_eng = "East/Northeast";
            } elsif ($dir_deg < 105) {
                $dir_eng = "East";
            } elsif ($dir_deg < 120) {
                $dir_eng = "East/Southeast";
            } elsif ($dir_deg < 150) {
                $dir_eng = "Southeast";
            } elsif ($dir_deg < 165) {
                $dir_eng = "South/Southeast";
            } elsif ($dir_deg < 195) {
                $dir_eng = "South";
            } elsif ($dir_deg < 210) {
                $dir_eng = "South/Southeast";
            } elsif ($dir_deg < 240) {
                $dir_eng = "Southwest";
            } elsif ($dir_deg < 265) {
                $dir_eng = "South/Southwest";
            } elsif ($dir_deg < 285) {
                $dir_eng = "West";
            } elsif ($dir_deg < 300) {
                $dir_eng = "West/Northwest";
            } elsif ($dir_deg < 330) {
                $dir_eng = "Northwest";
            } elsif ($dir_deg < 345) {
                $dir_eng = "North/Northwest";
            } else {
                $dir_eng = "North";
            }
        } # end if

        $wind =~ /...(\d\d\d?)/o;
        my $kts_speed = $1;
        my $mph_speed = $kts_speed * 1.1508;
        my $kts_gust = "";
        my $mph_gust = "";

        if ($wind =~ /.{5,6}G(\d\d\d?)/o) {
            $kts_gust = $1;
            $mph_gust = $kts_gust * 1.1508;
        } # end if

        $self->{WIND_KTS} = $kts_speed;
        $self->{WIND_MPH} = $mph_speed;

        $self->{WIND_KTS_GUST} = $kts_gust;
        $self->{WIND_MPH_GUST} = $mph_gust;

        $self->{WIND_DIR_DEG} = $dir_deg;
        $self->{WIND_DIR_ENG} = $dir_eng;

    } # end wind block

    # Visibility, now.

    {
        my $vis = $self->{visibility};
        $vis =~ s/SM$//oi;                              # nuke the "SM"
        if ($vis =~ /M(\d\/\d)/o) {
            $self->{VISIBILITY} = "Less than $1 statute miles";
        } else {
            $self->{VISIBILITY} = $vis . " Statute Miles";
        } # end if

    } # end visibility block

    # And F/C temperatures.

    {
        my ($tmp,$dew) = split(/\//, $self->{temp_dew});

        # check for negative values
        $tmp =~ s/^M/-/o;
        $dew =~ s/^M/-/o;

        # convert celcius to farenheit
        $self->{C_TEMP} = $tmp;
        $self->{F_TEMP} = (($tmp * (9/5)) + 32);
        $self->{C_DEW} = $dew;
        $self->{F_DEW} = (($dew * (9/5)) + 32);
    }

}

# ----------------------------------------------- #

sub print_tokens {
    my $self = shift;
    my $tok;
    foreach $tok (@{$self->{tokens}}) {
        print "> $tok\n";
    }
}

# ----------------------------------------------- #

sub debug {
    my $self = shift;
    my $flag = shift;

    return $debug unless defined $flag;

    if (($flag eq "Y") or ($flag eq "y") or ($flag == 1)) {
        $debug = 1;
    } elsif (($flag eq "N") or ($flag eq "n") or ($flag == 0)) {
        $debug = 0;
    }
    return $debug;
}

# ----------------------------------------------- #

# Dump internal data structure. Useful for debugging and such.

sub dump {

    my $self = shift;

    print "METAR dump follows.\n\n";

    print "type: $self->{type}\n";
    print "site: $self->{site}\n";
    print "date_time: $self->{date_time}\n";
    print "modifier: $self->{modifier}\n";
    print "wind: $self->{wind}\n";
    print "visibility: $self->{visibility}\n";
    print "runway: $self->{runway}\n";
    print "weather: " . join(', ', @{$self->{weather}}) . "\n";
    print "sky: " . join(', ', @{$self->{sky}}) . "\n";
    print "temp_dew: $self->{temp_dew}\n";
    print "alt: $self->{alt}\n";
    print "remarks: " . join (', ', @{$self->{remarks}}) . "\n";
    print "\n";
    print "VERSION: $self->{VERSION}\n";
    print "METAR: $self->{METAR}\n";
    print "TYPE: $self->{TYPE}\n";
    print "SITE: $self->{SITE}\n";
    print "DATE: $self->{DATE}\n";
    print "TIME: $self->{TIME}\n";
    print "MOD: $self->{MOD}\n";
    print "WIND_DIR_DEG: $self->{WIND_DIR_DEG}\n";
    print "WIND_DIR_ENG: $self->{WIND_DIR_ENG}\n";
    print "WIND_KTS: $self->{WIND_KTS}\n";
    print "WIND_MPH: $self->{WIND_MPH}\n";
    print "WIND_KTS_GUST: $self->{WIND_KTS_GUST}\n";
    print "WIND_MPH_GUST: $self->{WIND_MPH_GUST}\n"; 
    print "VISIBILITY: $self->{VISIBILITY}\n";
    print "C_TEMP: $self->{C_TEMP}\n";
    print "F_TEMP: $self->{F_TEMP}\n";
    print "C_DEW: $self->{C_DEW}\n";
    print "F_DEW: $self->{F_DEW}\n";
}

# ----------------------------------------------- #
# ----------------------------------------------- #
# ----------------------------------------------- #
# ----------------------------------------------- #
# ----------------------------------------------- #

1;

__END__

=head1 NAME

METAR - Process routine aviation weather reports in the METAR format.

=head1 SYNOPSIS

  use Geo::METAR;
  use strict;

  my $m = new Geo::METAR;
  $m->metar("KFDY 251450Z 21012G21KT 8SM OVC065 04/M01 A3010 RMK 57014 ");
  print $m->dump;

  exit;

=head1 DESCRIPTION

METAR reports are available on-line, thanks to the National Weather Service.
Since reading the METAR format isn't easy for non-pilots, these reports are
relatively useles to the common man who just wants a quick glace at the
weather.

=head1 USAGE

=head2 How you might use this

Here is how you I<might> use the Geo::METAR module.
 
One use that I have had for this module is to query the NWS METAR page
(using the LWP modules) at
http://tgsv5.nws.noaa.gov/cgi-bin/mgetmetar.pl?cccc=KFDY to get an
up-to-date METAR. Then, I scan thru the output, looking for what looks
like a METAR string (that's not hard in Perl). Oh, KFDY can be any site
location code where there is a reporting station.

I then pass the METAR into this module and get the info I want. I can
then update my home page with the current temperature, sky conditions, or
whatnot.

=head2 Functions

The following functions are defined in the AcctInfo module. Most of
them are I<public>, meaning that you're supposed to use
them. Some are I<private>, meaning that you're not supposed to use
them -- but I won't stop you. Assume that functions are I<public>
unless otherwise documented.

=over

=item metar()

metar() is the function to whwich you should pass a METAR string.
It will take care of decomposing it into its component parts coverting
the units and so on.

Example: C<$m-E<gt>metar("KFDY 251450Z 21012G21KT 8SM OVC065 04/M01 A3010 RMK 57014");>

=item debug()

debug() toggles debugging messages. By default, debugging is turned
B<off>. Turn it on if you are developing METAR or having trouble with
it.

debug() understands all of the folloing:

        Enable       Disable
        ------       -------
          1             0
        'yes'         'no'
        'on'          'off'

If you contact me for help, I'll likely ask you for some debugging
output.

Example: C<$m-E<gt>debug(1);>

=item dump()

dump() will dump the internal data structure for the METAR in a
semi-human readable format.

Example: C<$m-E<gt>dump;>

=item version()

version() will print out the current version.

Example: C<print $m-E<gt>version;>

=item _tokenize()

B<PRIVATE>

Called internally to break the METAR into its component tokens.

=item _process()

B<PRIVATE>

Used to make sense of the tokens found in B<_tokenize()>.

=back

=head2 Variables

After you've called B<metar()>, you'd probably like to get at
the individual values for things like temperature, dew point,
and so on. You do that by accessing individual variables via
the METAR object.

This section lists those variables and what they represent.

If you call B<dump()>, you'll find that it spits all of these
out in roughly this order, too.

=over

=item VERSION

The version of METAR.pm that you're using.

=item METAR

The actual, raw METAR.

=item TYPE

Report type: "METAR or SPECI".

=item SITE

4-letter site code.

=item DATE

The date on which the report was issued.

=item TIME

The time at which the report was issued.

=item MOD

Modifier (AUTO/COR) if any.

=item WIND_DIR_ENG

The current wind direction in english (Southwest, East, North, etc.)

=item WIND_DIR_DEG

The current wind direction in degrees.

=item WIND_KTS

The current wind speed in Knots.

=item WIND_MPH

The current wind speed in Miles Per Hour.

=item WIND_KTS_GUST

The current wind gusting speed in Knots.

=item WIND_MPH_GUST

The current wind gustin speed in Miles Per Hour.

=item VISIBILITY

Visibility information.

=item WIND

Wind information.

=item RUNWAY

Runway information.

=item WEATHER

Current weather.

=item SKY

Current sky conditions.

=item C_TEMP

Temperature in Celcius.

=item F_TEMP

Temperature in Farenheit.

=item C_DEW

Dew point in Celcius.

=item F_DEW

Dew point in Farenheit.

=item ALT

Altimeter setting (barometric pressure).

=item REMARKS

Any remarks in the report.

=back

=head1 NOTES

Test suite is small and incomplete. Needs work yet.

Older versions of this module were installed as "METAR" instaed of
"Geo::METAR"

=head2 Adding a find() method.

I shoule add a function called find() which can be passed a big chunk
of text (or a ref to one) and a site identifier. It will scan through
the text and find the METAR. The result can be fed back into this
module for processing.

That'd be cool, I think.

=head1 BUGS

The only known bug was corrected in the latest release. Please report
any bugs that you find.

=head1 AUHTOR AND COPYRIGHT

Copyright 1998-99, Jeremy D. Zawodny <jzawodn@wcnet.org>

Geo::METAR is covered under the GNU Public License (GPL) version 2 or
later.

The Geo::METAR Web site is located at:

  http://www.wcnet.org/~jzawodn/perl/Geo-METAR/

=cut
