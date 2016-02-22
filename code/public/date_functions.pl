#!c:/perl/bin/perl.exe
# Here are some date functions that I use.  They are each explained in the comments for each subroutine.
# Feel free to copy, modify, distribute as you need/want.
# If there are any errors/corrections/suggestions, feel free to email me at dilligaf@dilligaf.d2g.com
#
#  See examples of how they work at:  http://dilligaf.d2g.com/cgi-bin/datestuff.cgi
#
# Copyright 2001  Jeff Crum
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#

use strict;

sub dayofweek {

    # Returns the day of week for any specified date.
    #   Input parms are: Month,
    #                    Day,
    #                and Year.
    #     example:  &dayofweek(8, 10, 1968);
    #
    #   Returns numeric day of week: 0=Sunday, 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday
    my ( $month, $day, $year ) = @_;
    my ( $a, $y, $m, $dow );
    my @daysinmonth = ( 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );
    if ( &leapyear($year) ) {
        $daysinmonth[2]++;
    }

    if (   ( $month < 1 || $month > 12 )
        || ( $day < 1 || $day > $daysinmonth[$month] ) )
    {
        return ("Invalid Date - $month\/$day\/$year");
    }
    else {
        $a = int( ( 14 - $month ) / 12 );
        $y = $year - $a;
        $m = $month + ( 12 * $a ) - 2;
        $dow =
          ( $day + $y +
              int( $y / 4 ) -
              int( $y / 100 ) +
              int( $y / 400 ) +
              int( ( 31 * $m ) / 12 ) )
          % 7;
        return ($dow);
    }
}

sub dayofmonth {

    # Returns the date of the first/second/third/fourth/last specified day of the month/year.
    #   Input parms are: Which one (first, second, third, fourth, last)
    #                    Day of Week (sunday, monday, tuesday, wednesday, thursday, friday, saturday),
    #                    Month,
    #                and Year.
    #     example:  &dayofmonth(first, monday, 9, 2001);  - First Monday in September (Labor Day)
    #               &dayofmonth(last, monday, 5, 2001);  - Last Monday in May (Memorial Day)
    #               &dayofmonth(third, thursday, 11, 2001);  - Third Thursday in November (Thanksgiving)
    #
    #   Returns: numeric Month,
    #                    Day,
    #                and Year
    my ( $which, $dow_name, $month, $year ) = @_;
    my $day;
    $which =~ tr/A-Z/a-z/;
    $dow_name =~ tr/A-Z/a-z/;
    my %daysofweek = (
        "sunday",   0, "monday", 1, "tuesday",  2, "wednesday", 3,
        "thursday", 4, "friday", 5, "saturday", 6
    );
    my $dow = $daysofweek{$dow_name};

    if (   $which ne "first"
        && $which ne "second"
        && $which ne "third"
        && $which ne "fourth"
        && $which ne "last" )
    {
        return ("Invalid Which One Parm - $which");
    }
    elsif ( $month < 1 || $month > 12 ) {
        return ("Invalid Month - $month");
    }
    elsif ( $dow eq "" ) {
        return ("Invalid Day of Week - $dow_name");
    }
    else {
        if ( $which eq "last" ) {
            ( $month, $day, $year ) =
              &lastnameddayofmonth( $dow, $month, $year );
            return ( $month, $day, $year );
        }
        else {
            ( $month, $day, $year ) =
              &firstnameddayofmonth( $dow, $month, $year );
            if ( $which eq "first" ) {
                return ( $month, $day, $year );
            }
            elsif ( $which eq "second" ) {
                $day += 7;
                return ( $month, $day, $year );
            }
            elsif ( $which eq "third" ) {
                $day += 14;
                return ( $month, $day, $year );
            }
            elsif ( $which eq "fourth" ) {
                $day += 21;
                return ( $month, $day, $year );
            }
        }
    }
}

sub firstnameddayofmonth {

    # Returns the date of the first specified day of the month/year.
    #   Input parms are: Day of Week (0=Sunday, 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday),
    #                    Month,
    #                and Year.
    #     example:  &firstnameddayofmonth(1, 9, 2001);  - First Monday in September (Labor Day)
    #
    #   Returns: numeric Month,
    #                    Day,
    #                and Year
    my ( $dow, $month, $year ) = @_;
    my $day = 1;
    my $dayofweek = &dayofweek( $month, $day, $year );

    if ( $dow < 0 || $dow > 6 ) {
        return ("Invalid Day of Week - $dow");
    }
    elsif ( $month < 1 || $month > 12 ) {
        return ("Invalid Month - $month");
    }
    else {
        while ( $dayofweek != $dow ) {
            ( $dayofweek, $month, $day, $year ) =
              &addday( $dayofweek, $month, $day, $year );
        }
        return ( $month, $day, $year );
    }
}

sub addday {

    # Adds 1 to the day and date keeping day of week and date in sync.
    #   Input parms are: Day of Week: 0=Sunday, 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday,
    #                    Month,
    #                    Day,
    #                and Year.
    #     example:  &addday(6, 8, 10, 1968);
    #
    #   Returns numeric day of week: 0=Sunday, 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday
    my ( $dow, $month, $day, $year ) = @_;
    my @daysinmonth = ( 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );
    if ( &leapyear($year) ) {
        $daysinmonth[2]++;
    }

    if ( $dow < 0 || $dow > 6 ) {
        return ("Invalid Day of Week - $dow");
    }
    elsif ( $month < 1 || $month > 12 ) {
        return ("Invalid Month - $month");
    }
    elsif ( $day < 1 || $day > $daysinmonth[$month] ) {
        return ("Invalid Days for Month - $day");
    }
    else {
        $dow++;
        if ( $dow > 6 ) {
            $dow = 0;
        }
        $day++;
        if ( $day > $daysinmonth[$month] ) {
            if ( $month eq 12 ) {
                $month = 1;
                $year++;
            }
            else {
                $month++;
            }
            $day = 1;
        }
        return ( $dow, $month, $day, $year );
    }
}

sub lastnameddayofmonth {

    # Returns the date of the last specified day of the month/year.
    #   Input parms are: Day of Week (0=Sunday, 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday),
    #                    Month,
    #                and Year.
    #     example:  &lastnameddayofmonth(1, 5, 2001);  - Last Monday in May (Memorial Day)
    #
    #   Returns: numeric Month,
    #                    Day,
    #                and Year
    my ( $dow, $month, $year ) = @_;
    my $day = 1;
    $month++;
    my $dayofweek = &dayofweek( $month, $day, $year );

    if ( $dow < 0 || $dow > 6 ) {
        return ("Invalid Day of Week - $dow");
    }
    elsif ( $month < 1 || $month > 12 ) {
        return ("Invalid Month - $month");
    }
    else {
        while ( $dayofweek != $dow ) {
            ( $dayofweek, $month, $day, $year ) =
              &subtractday( $dayofweek, $month, $day, $year );
        }
        return ( $month, $day, $year );
    }
}

sub subtractday {

    # Subtracts 1 from the day and date keeping day of week and date in sync.
    #   Input parms are: Day of Week: 0=Sunday, 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday,
    #                    Month,
    #                    Day,
    #                and Year.
    #     example:  &subtractday(6, 8, 10, 1968);  - First Monday in September (Labor Day)
    #
    #   Returns numeric day of week: 0=Sunday, 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday
    my ( $dow, $month, $day, $year ) = @_;
    my @daysinmonth = ( 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );
    if ( &leapyear($year) ) {
        $daysinmonth[2]++;
    }

    if ( $dow < 0 || $dow > 6 ) {
        return ("Invalid Day of Week - $dow");
    }
    elsif ( $month < 1 || $month > 12 ) {
        return ("Invalid Month - $month");
    }
    elsif ( $day < 1 || $day > $daysinmonth[$month] ) {
        return ("Invalid Days for Month - $day");
    }
    else {
        $dow--;
        if ( $dow < 0 ) {
            $dow = 6;
        }
        $day--;
        if ( $day eq 0 ) {
            $month--;
            if ( $month eq 0 ) {
                $month = 12;
                $year--;
            }
            $day = $daysinmonth[$month];
        }
        return ( $dow, $month, $day, $year );
    }
}

sub leapyear {

    # Tells if the year is a leap year or not.
    #   Input parms are: Year.
    #     example:  if (&leapyear(2001));
    #
    #   Returns 1 if leap year and 0 if not a leap year
    my ($year) = @_;
    if ( $year / 100 eq int( $year / 100 ) ) {
        if ( $year / 400 eq int( $year / 400 ) ) {
            return (1);
        }
        else {
            return (0);
        }
    }
    else {
        if ( ( $year / 4 ) eq ( int( $year / 4 ) ) ) {
            return (1);
        }
        else {
            return (0);
        }
    }
}

1;
