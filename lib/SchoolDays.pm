=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	SchoolDays.pm

Description:

	These function will calculate if Today or Tomorrow are 
	schooldays. Multiple schools are supported. 
	A list of term dates and an optional list of mid-term
	holidays are required for each school.
	
Author(s):
	Andrew C Baker / andrew@rekabuk.co.uk
	Jeffrey C Honig / jch@honig.net

License:
	This free software is licensed under the terms of the GNU public license. GPLv2

Usage:
	$school1 = new SchoolDays("EACMSI",		# School name
		       "9/3-12/19",			# School dates
		       "9/30,10/9,10/10,10/13,11/11,11/13,11/14,11/26,11/27,11/28");

	if ($school1->is_school_today()) {
           ...
        } elsif ($school1->is_school_tomorrow()) {
	   ...
        }

	$school1->is_school_day("mm/dd/yy");	# Date format is $config_parms{"date_format"};
	$school1->is_school_night("mm/dd/yy");	$ Can also use an ISO8601 date

	$school1->set_logging(0|1);		# Logging

Notes:

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

=cut

use strict;

package SchoolDays;

#
#	Initialize with school name, session dates, and exceptions
#

sub new {
    my ($class, $school, $school_terms, $school_inset, $logging) = @_;
    my $self = {};
    my ($i, $term, $inset);

    bless $self;

    $self->{class} = $class;
    $self->{school} = $school;
    $self->{logging} = $logging;
    $self->{terms} = [];
    $self->{insets} = [];

    $self->_log("new: $school, $school_terms, $school_inset, $logging");

    # Load Term dates
    foreach $term (split(",", $school_terms)) {
	my($start,$finish);
	my($d,$m,$y);

	($start,$finish) = split("-", $term);

	${$self->{terms}}[$i][0] = $self->_convert_to_ISO8601_date($start);
	${$self->{terms}}[$i][1] = $self->_convert_to_ISO8601_date($finish);

	$self->_log("Term=$i, Start=${$self->{terms}}[$i][0], Finish=${$self->{terms}}[$i][1]");
	$i++;
    }
   
    # Load inset dates
    $i = 0;
    foreach $inset (split(",", $school_inset)) {
	${$self->{insets}}[$i] = $self->_convert_to_ISO8601_date($inset);
	$self->_log("Inset=$i, Date=${$self->{insets}}[$i]");

	$i++;
    }

    return $self;
}


#---------------------------------------------
sub _convert_to_ISO8601_date {
    my ($self, $date) = @_;

    $self->_log("convert: $date");

    my ($y,$m,$d);
    my ($yyyy,$mm,$dd);

    if ($main::config_parms{"date_format"} =~ /ddmm/) {
	($d,$m,$y) = split("/",$date);
    } else {
	($m,$d,$y) = split("/",$date);
    }

    if (length($m) == 1) {
	$mm = "0".$m;
    } else {
	$mm = $m;
    }

    if (length($d) == 1) {
	$dd = "0".$d;
    } else {
	$dd = $d;
    }

    if (!defined $y) {
	$yyyy = $main::Year;
    } else {
	$yyyy = $y if length($y) == 4;
	$yyyy = "20".$y if length($y) == 2;     # This will *only* work until 2099.
    }

    # 1 Hour into the day
    if ($main::config_parms{"date_format"} =~ /ddmm/) {
	$self->_log("convert out = $dd/$mm/$yyyy");
    } else {
	$self->_log("convert out = $mm/$dd/$yyyy");
    }

    #Months are 0..11
    return main::timelocal(0, 0, 1, $dd, $mm-1, $yyyy);
}


#---------------------------------------------
# Return ISO8601 date for today
sub _get_epoch_date {
    my ($self) = @_;
    my $iso_date;

    if ($main::config_parms{"date_format"} =~ /ddmm/) {
	$iso_date = $main::Mday . "/" . $main::Month . "/" . $main::Year;
    } else {
	$iso_date = $main::Month . "/" . $main::Mday . "/" . $main::Year;
    }

    return $self->_convert_to_ISO8601_date($iso_date);
}

#---------------------------------------------
# Log a message
sub _log {
    my ($self, $msg) = @_;

    if ($self->{logging}) {
	main::print_log("$self->{class}: $self->{school} $msg");
    }
}

#---------------------------------------------
# Toggle logging
sub set_logging {
    my ($self, $logging) = @_;

    $self->{logging} = $logging;

    $self->_log("Logging set to $logging");
}

#---------------------------------------------
# Is the supplied day a school day
sub is_schoolday {
    my ($self, $testdate) = @_;

    # We can accept dd/mm/yy or an epoch number   
    if ($testdate =~ /\//) {
	$testdate = $self->_convert_to_ISO8601_date($testdate);
    }
    $self->_log("Test Date (Day) = $testdate");

    # No school at the weekend
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($testdate);
    if (($wday == 6) || ($wday == 0)) {
	return 0;
    }
      
    #Check term dates
    my ($j, $k);
    $self->_log("$testdate $#{ %{$self->{terms}} }");

    for $j ( 0 .. $#{ %{$self->{terms}}} ) {
	$self->_log( "$j ${$self->{terms}}[$j][0]] ${$self->{terms}}[$j][1]");
	if (($testdate >= ${$self->{terms}}[$j][0]) and ($testdate <= ${$self->{terms}}[$j][1])) {
	    # Now check if it's an inset day
	    for $k ( 0 .. $#{ %{$self->{insets}} } ) {
		if ($testdate == ${$self->{insets}}[$k]) {
		    $self->_log("Inset day: $testdate");
		    return 0;
		}
	    }
	    return 1;
	}
    }

    return 0;
}

#---------------------------------------------
# Is the supplied day a school night

sub is_schoolnight {
    my ($self, $testdate) = @_;
   
    my $testdate_tomorrow;
   
    # We can accept dd/mm/yy or an epoch number   
    if ($testdate =~ /\//) {
	$testdate = $self->_convert_to_ISO8601_date($testdate);
    }
   
    #Get tomorrows date
    $testdate += 86400;
    $self->_log("Test Date (Night) = $testdate");

    # Is tomorrow a school_day?
    return $self->is_schoolday($testdate);
}

#---------------------------------------------
# Is today a school day?

sub is_school_today {
    my ($self) = @_;

    return $self->is_schoolday($self->_get_epoch_date());
}

#---------------------------------------------
#Is tomorrow a school day?

sub is_school_tomorrow {
    my ($self) = @_;

    return $self->is_schoolnight($self->_get_epoch_date());
}

1;
