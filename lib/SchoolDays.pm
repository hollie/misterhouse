
=head1 B<SchoolDays>

=head2 SYNOPSIS

  $school1 = new SchoolDays("EACMSI",             # School name
                 "9/3-12/19",                     # School dates
                 "9/30,10/9,10/10,10/13,11/11,11/13,11/14,11/26-11/28");

  if ($school1->is_school_today()) {
    ...
  } elsif ($school1->is_school_tomorrow()) {
    ...
  }

  $school1->is_school_day("mm/dd/yy");    # Date format is $config_parms{"date_format"};
  $school1->is_school_night("mm/dd/yy");  $ Can also use an ISO8601 date

  $school1->set_logging(0|1);             # Logging

=head2 DESCRIPTION

These function will calculate if Today or Tomorrow are
schooldays. Multiple schools are supported.
A list of term dates and an optional list of mid-term
holidays are required for each school.

=head2 INHERITS

B<>

=head2 METHODS

=over

=cut

use strict;
use POSIX qw/strftime/;
use Time::Local;

package SchoolDays;

=item C<new>

Initialize with school name, session dates, and exceptions

=cut

sub new {
    my ( $class, $school, $school_terms, $school_inset, $logging ) = @_;
    my $self = {};
    my ( $term, $inset );

    bless $self;

    $self->{class}   = $class;
    $self->{school}  = $school;
    $self->{logging} = $logging;
    $self->{terms}   = [];
    $self->{insets}  = [];

    $self->_log("new: $school, $school_terms, $school_inset, $logging");

    # Load Term dates
    foreach ( split( ",", $school_terms ) ) {
        my ( $start, $finish ) = split("-");

        push @{ $self->{terms} },
          [
            $self->_convert_to_ISO8601_date($start),
            $self->_convert_to_ISO8601_date($finish)
          ];
    }

    # Load inset dates
    foreach ( split( ",", $school_inset ) ) {

        if (m/-/) {
            my ( $start, $finish ) = split("-");

            push @{ $self->{insets} },
              [
                $self->_convert_to_ISO8601_date($start),
                $self->_convert_to_ISO8601_date($finish)
              ];
        }
        else {
            my $date = $self->_convert_to_ISO8601_date($_);

            push @{ $self->{insets} }, [ $date, $date ];
        }
    }

    $self->_log("Term dates:");
    foreach ( @{ $self->{terms} } ) {
        my ( $start, $finish ) = @{$_};

        $self->_log(
            "\t" . $self->_hr_date($start) . " - " . $self->_hr_date($finish) );
    }
    $self->_log("In-session breaks:");
    foreach ( @{ $self->{insets} } ) {
        my ( $start, $finish ) = @{$_};

        if ( $start eq $finish ) {
            $self->_log( "\t" . $self->_hr_date($start) );
        }
        else {
            $self->_log( "\t"
                  . $self->_hr_date($start) . " - "
                  . $self->_hr_date($finish) );
        }
    }

    return $self;
}

#---------------------------------------------
sub _convert_to_ISO8601_date {
    my ( $self, $date ) = @_;

    $self->_log("convert: $date");

    my ( $y,    $m,  $d );
    my ( $yyyy, $mm, $dd );

    if ( $main::config_parms{"date_format"} =~ /ddmm/ ) {
        ( $d, $m, $y ) = split( "/", $date );
    }
    else {
        ( $m, $d, $y ) = split( "/", $date );
    }

    if ( length($m) == 1 ) {
        $mm = "0" . $m;
    }
    else {
        $mm = $m;
    }

    if ( length($d) == 1 ) {
        $dd = "0" . $d;
    }
    else {
        $dd = $d;
    }

    if ( !defined $y ) {
        $yyyy = $main::Year;
    }
    else {
        $yyyy = $y if length($y) == 4;
        $yyyy = "20" . $y
          if length($y) == 2;    # This will *only* work until 2099.
    }

    # 1 Hour into the day
    if ( $main::config_parms{"date_format"} =~ /ddmm/ ) {
        $self->_log("convert out = $dd/$mm/$yyyy");
    }
    else {
        $self->_log("convert out = $mm/$dd/$yyyy");
    }

    #Months are 0..11
    return Time::Local::timelocal( 0, 0, 1, $dd, $mm - 1, $yyyy );
}

=item C<_get_epoch_date>

Return ISO8601 date for today

=cut

sub _get_epoch_date {
    my ($self) = @_;
    my $iso_date;

    if ( $main::config_parms{"date_format"} =~ /ddmm/ ) {
        $iso_date = $main::Mday . "/" . $main::Month . "/" . $main::Year;
    }
    else {
        $iso_date = $main::Month . "/" . $main::Mday . "/" . $main::Year;
    }

    return $self->_convert_to_ISO8601_date($iso_date);
}

=item C<_hr_date>

Return human readable date

=cut

sub _hr_date {
    my ( $self, $date ) = @_;

    return POSIX::strftime( "%d %b %Y", localtime($date) );
}

=item C<_log>

Log a message

=cut

sub _log {
    my ( $self, $msg ) = @_;

    if ( $self->{logging} ) {
        main::print_log("$self->{class}: $self->{school} $msg");
    }
}

=item C<set_logging>

Toggle logging

=cut

sub set_logging {
    my ( $self, $logging ) = @_;

    $self->{logging} = $logging;

    $self->_log("Logging set to $logging");
}

=item C<is_schoolday>

Is the supplied day a school day

=cut

sub is_schoolday {
    my ( $self, $testdate ) = @_;

    # We can accept dd/mm/yy or an epoch number
    if ( $testdate =~ /\// ) {
        $testdate = $self->_convert_to_ISO8601_date($testdate);
    }
    $self->_log(
        "is_schoolday($testdate, " . $self->_hr_date($testdate) . ")" );

    # No school at the weekend
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime($testdate);
    if ( ( $wday == 6 ) || ( $wday == 0 ) ) {
        return 0;
    }

    #Check term dates
    foreach my $j ( @{ $self->{terms} } ) {
        my ( $start, $finish ) = @{$j};

        if ( ( $testdate >= $start ) and ( $testdate <= $finish ) ) {
            $self->_log("\t is during a term");

            # Now check if it's an inset day
            foreach my $k ( @{ $self->{insets} } ) {
                my ( $start, $finish ) = @{$k};

                if ( ( $testdate >= $start ) and ( $testdate <= $finish ) ) {
                    $self->_log("\t is during an in-session break");
                    return 0;
                }
            }
            $self->_log("\t is not during an in-session break");
            return 1;
        }
    }

    $self->_log("\t is not during a term");

    return 0;
}

=item C<is_schoolnight>

Is the supplied day a school night

=cut

sub is_schoolnight {
    my ( $self, $testdate ) = @_;

    my $testdate_tomorrow;

    # We can accept dd/mm/yy or an epoch number
    if ( $testdate =~ /\// ) {
        $testdate = $self->_convert_to_ISO8601_date($testdate);
    }

    #Get tomorrows date
    $testdate += 86400;

    # Is tomorrow a school_day?
    return $self->is_schoolday($testdate);
}

=item C<is_school_today>

Is today a school day?

=cut

sub is_school_today {
    my ($self) = @_;

    return $self->is_schoolday( $self->_get_epoch_date() );
}

=item C<is_school_tomorrow>

Is tomorrow a school day?

=cut

sub is_school_tomorrow {
    my ($self) = @_;

    return $self->is_schoolnight( $self->_get_epoch_date() );
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Andrew C Baker / andrew@rekabuk.co.uk

Jeffrey C Honig / jch@honig.net

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

