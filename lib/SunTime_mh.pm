
=head1 B<SunTime_mh>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Results can be checked with: http://aa.usno.navy.mil/AA/data/docs/RS_OneYear.html

09/03/00 :: winter Make ParseDate optional.  It is overkill and I could not get it to
compile in perl2exe.  It gave runaway comment errors :(
10/12/00 :: winter Change time_zone check to defined, to allow for time_zone 0
06/02/01 :: winter Moved from mh/site/lib/Astro and renamed from SunTime.pm
to avoid picking up old non-mh versions.

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=cut

#package Astro::SunTime;
package SunTime_mh;

use vars qw(@ISA @EXPORT $VERSION);
$VERSION = 0.01;
@ISA     = qw(Exporter);
@EXPORT  = qw(sun_time);

use POSIX;

use strict;

=item C<sun_time>

sun_time takes:

  type => 'rise' | 'set'
  latitude
  longitude
  time_zone => hours from GMT
  date => date parsable by Time::ParseDate::parsedate()
  time => to feed to localtime

=cut

sub sun_time {
    my %params = @_;

    my $type = $params{type} || 'rise';
    my $latitude = ( defined $params{latitude} ) ? $params{latitude} : 38.74274;
    my $longitude =
      ( defined $params{longitude} ) ? $params{longitude} : -90.560143;
    my $time_zone = ( defined $params{time_zone} ) ? $params{time_zone} : -6;

    my $time;
    if ( $params{date} ) {
        eval 'use Time::ParseDate';
        $time = parsedate( $params{date} );
    }
    elsif ( $params{time} ) {
        $time = $params{time};
    }
    else {
        $time = time;
    }
    my @suntime = localtime($time);

    my $yday = $suntime[7] + 1;

    my $A = 1.5708;
    my $B = 3.14159;
    my $C = 4.71239;
    my $D = 6.28319;
    my $E = 0.0174533 * $latitude;
    my $F = 0.0174533 * $longitude;
    my $G = 0.261799 * $time_zone;

    # For astronomical twilight, use R = -.309017
    # For     nautical twilight, use R = -.207912
    # For        civil twilight, use R = -.104528
    # For     sunrise or sunset, use R = -.0145439

    my $R = -.0145439;
    if ( $params{twilight} ) {
        if ( $params{twilight} eq 'astronomical' ) {
            $R = -.309017;
        }
        elsif ( $params{twilight} eq 'nautical' ) {
            $R = -.207912;
        }
        elsif ( $params{twilight} eq 'civil' ) {
            $R = -.104528;
        }
    }

    my $J = ( $type eq 'rise' ) ? $A : $C;
    my $K = $yday + ( ( $J - $F ) / $D );
    my $L = ( $K * .017202 ) - .0574039;    # Solar Mean Anomoly
    my $M = $L + .0334405 * sin($L);        # Solar True Longitude
    $M += 4.93289 + (3.49066E-04) * sin( 2 * $L );
    $M = &normalize( $M, $D );              # Quadrant Determination
    $M += 4.84814E-06 if ( $M / $A ) - int( $M / $A ) == 0;
    my $P = sin($M) / cos($M);              # Solar Right Ascension
    $P = atan2( .91746 * $P, 1 );

    # Quadrant Adjustment
    if ( $M > $C ) {
        $P += $D;
    }
    elsif ( $M > $A ) {
        $P += $B;
    }

    my $Q = .39782 * sin($M);               # Solar Declination
    $Q = $Q / sqrt( -$Q * $Q + 1 );  # This is how the original author wrote it!
    $Q = atan2( $Q, 1 );

    my $S = $R - ( sin($Q) * sin($E) );
    $S = $S / ( cos($Q) * cos($E) );

    return 'none' if abs($S) > 1;    # Null phenomenon

    $S = $S / sqrt( -$S * $S + 1 );
    $S = $A - atan2( $S, 1 );
    $S = $D - $S if $type eq 'rise';

    my $T = $S + $P - 0.0172028 * $K - 1.73364;    # Local apparent time
    my $U = $T - $F;                               # Universal timer
    my $V = $U + $G;                               # Wall clock time
    $V = &normalize( $V, $D );
    $V = $V * 3.81972;

    my $hour = int($V);
    my $min = int( ( $V - $hour ) * 60 + 0.5 );

    # Not sure about this ... most boxes don't need this.  localtime call already adjusts this.
    #  $hour = &adjust_dst($hour) unless $params{no_dst};

    @suntime[ 2, 1, 0, 8 ] = ( $hour, $min, 0, 0 );

    @suntime = localtime( mktime(@suntime) );    # normalize date structure

    return sprintf( "%d:%02d", @suntime[ 2, 1 ] );
}

sub normalize {
    my $Z = shift;
    my $D = shift;

    die "Trying to normalize with zero offset..." if ( $D == 0 );

    while ( $Z < 0 )   { $Z = $Z + $D }
    while ( $Z >= $D ) { $Z = $Z - $D }

    return $Z;
}

sub adjust_dst {
    my ($hour_in) = @_;

    # Note: jan -> month=0   sun -> wday=0
    # First Sunday in April, Last in October
    my ( $sec, $min, $hour, $mday, $month, $year, $wday ) = localtime(time);
    $hour_in++
      if ( ( $month > 3 and $month < 9 )
        or ( $month == 3 and ( $mday - $wday > 0 ) )
        or ( $month == 9 and ( $mday - $wday < 25 ) ) );
    return $hour_in;
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

