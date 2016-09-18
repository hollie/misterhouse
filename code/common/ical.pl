# Category=Timed Events

#@ This little module parses an iCal files (as described here :
#@ <a href='http://en.wikipedia.org/wiki/ICalendar'>ICal@Wikipedia</a>)
#@ and starts or stops the x10 equipments accordingly.<br>
#@ <br>
#@ How to use it : create events in the calendar, the title must be the
#@ name of the item variable (for example if you have $coffee_machine =
#@ new X10_Appliance 'C1'; then the title must be coffee_machine). As
#@ long as the event lasts, the code will ensure that the item will be
#@ switched on... and it handles recurrences, so you can easily plan a
#@ week, a month, and so on... Simple huh ? :-) <br>
#@ <br>
#@ You can use any calendar software which writes ICal files, such as
#@ Mozilla Calendar, iCal, etc.
#@ <br>
#@ The code requires the following configuration items :
#@ <ul>
#@ 		<li> ics_calendar_file to specify the location of the file
#@		<li> dt_time_zone to specify the timezone (eg : Europe/Paris)
#@ </ul>
#@ The following Perl modules have to be installed :
#@ <ul>
#@    <li> DateTime;
#@    <li> Data::ICal::DateTime;
#@ </ul>

=begin comment

File:
	ical.pl

Description:
	parses iCal files and uses the information to trigger events

Author:
	Stephane dot Kattoor at sakana-home.net

License:
	GNU GPL

=cut

use DateTime;
use Data::ICal::DateTime;
use File::stat;

# loads a calendar into memory
sub readCal {
    my $fname = $config_parms{ics_calendar_file};

    my $cal = Data::ICal->new( filename => $fname );

    if ($cal) {
        print_log "Success loading calendar <", $fname, ">";
        my $now = DateTime->now( time_zone => $config_parms{dt_time_zone} );
        return {
            readAt => DateTime->now,
            vcal   => $cal,
        };
    }
    else {
        print_log "Failed to read calendar <", $fname, ">";
        return undef;
    }
}

my $calendar;

my $fname = $config_parms{ics_calendar_file};
my $st    = stat($fname);

if ( not $st ) {
    print_log "unable to stat file <", $fname, ">";
    die;
}

# was the calendar file modified since last time
# it was read ?
if (
    $New_Minute
    and (
        not $calendar
        or DateTime::compare( DateTime->from_epoch( epoch => $st->mtime ),
            $calendar->{readAt} ) > 0
    )
  )
{
    print_log "Need to reload calendar !";
    $calendar = readCal;
}

if ( $New_Minute and $calendar ) {
    my $today = DateTime->today( time_zone => $config_parms{dt_time_zone} );
    my $dt = $today->clone->add( days => 1 );
    my $span = DateTime::Span->from_datetimes( start => $today, end => $dt );
    my @events = $calendar->{vcal}->events($span);
    my %eventsByName;

    # creates spans for all events in the calendar
    foreach (@events) {
        my $item = $_->property('summary')->[0]->value;
        my $span = DateTime::Span->from_datetimes(
            start  => $_->start,
            before => $_->end
        );

        push @{ $eventsByName{$item} }, $span;
    }

    # gathers all spans in spansets for all events
    while ( my ( $item, $spans ) = each %eventsByName ) {
        my $wanted_state = OFF;

        my $spanSet = DateTime::SpanSet->from_spans( spans => $spans );
        if (
            $spanSet->contains(
                DateTime->now( time_zone => $config_parms{dt_time_zone} )
            )
          )
        {
            $wanted_state = ON;
        }
        if ($wanted_state) {
            if ( my $object = eval "\$$item" ) {

                # does it match a MisterHouse item ?
                if ( $object->state ne $wanted_state ) {
                    print_log "switching $wanted_state $item";
                    $object->set($wanted_state);
                }
            }
            else {
                print_log "No object with that name <$item>";
            }
        }
    }
}
