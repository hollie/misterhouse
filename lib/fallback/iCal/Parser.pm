# $Id: Parser.pm 464 2008-05-30 23:49:01Z rick $
package iCal::Parser;
use strict;

# Get version from subversion url of tag or branch.
our $VERSION= do {(q$URL: svn+ssh://xpc/var/lib/svn/rick/perl/ical/iCal-Parser/tags/1.16/lib/iCal/Parser.pm $=~ m$.*/(?:tags|branches)/([^/ \t]+)$)[0] || "0.01"};

our @ISA = qw (Exporter);

use DateTime::Format::ICal;
use Text::vFile::asData;
use File::Basename;
use IO::File;
use IO::String;

# mapping of ical entries to datatypes
our %TYPES=(dates=>{DTSTAMP=>1,DTSTART=>1,DTEND=>1,COMPLETED=>1,
                    'RECURRENCE-ID'=>1,EXDATE=>1,DUE=>1,
                    'LAST-MODIFIED'=>1,
                },
            durations=>{DURATION=>1},
            arrays=>{EXDATE=>1,ATTENDEE=>1},
            hash=>{'ATTENDEE'=>1, ORGANIZER=>1},
        );

our %defaults=(debug=>0,span=>undef,start=>undef,end=>undef,months=>60,tz=>'local');

our $dfmt=DateTime::Format::ICal->new;
our $parser=Text::vFile::asData->new;
sub new {
    my ($class, %params) = @_;

    my $self=bless {%defaults, %params,
                    ical=>{cals=>[],events=>{},todos=>[]},
                    _today=>DateTime->now,_calid=>0,
                }, $class;
    #set range, allow passed in dates as DateTimes or strings
    my $start=$params{start}||DateTime->now->truncate(to=>'year');
    $start=$dfmt->parse_datetime($start) unless ref $start;
    my $end=$params{end}||$start->clone->add(months=>$self->{months});
    $end=$dfmt->parse_datetime($end) unless ref $end;
    $self->{span}||=DateTime::Span->new(start=>$start, end=>$end);

    return ($self);
}
sub parse {
    my $self=shift;

    foreach my $file (@_) {
        my $fh=ref $file ? $file
            : IO::File->new($file,'r') || die "Can\'t open $file, $!";
        my $data=$parser->parse($fh);
        undef $fh;

        $self->VCALENDAR($data->{objects}[0],$file);
        $self->add_objects($data->{objects}[0]);
        $self->update_recurrences;
    }
    return $self->{ical};
}
sub parse_files {
    return parse(@_);
}
sub parse_strings {
    my $self=shift;
    return $self->parse((map { IO::String->new($_) } @_));
}
sub calendar {
    return shift->{ical};
}
sub VCALENDAR {
    my($self,$cal,$file)=@_;

    my %props=();
    $self->{recurrences}=[];
    $self->map_properties(\%props,$cal);
    $props{'X-WR-TIMEZONE'}||=$self->{tz};
    $props{index}=++$self->{_calid};
    $props{'X-WR-RELCALID'}||=$self->{_calid};
    $props{'X-WR-CALNAME'}||= ref $file
        ? "Calendar $self->{_calid}" : fileparse($file,qr{\.\w+});

    push @{$self->{ical}{cals}},\%props;
}
sub VTODO {
    my($self,$todo)=@_;
    return if $self->{no_todos};

    my $t={idref=>$self->_cur_calid};
    $self->map_properties($t,$todo);
    $t->{PRIORITY}||=99;

    $self->add_objects($todo,$t);
    push @{ $self->{ical}{todos} }, $t;
}
sub VEVENT {
    my($self,$event)=@_;
    return if $self->{no_events};

    my %e=(idref=>$self->_cur_calid);

    $self->map_properties(\%e,$event);
    $self->add_objects($event,\%e);

    my $start=$e{DTSTART};
    return if $start > $self->{span}->end;

    warn "Event: @e{qw(UID DTSTART SUMMARY)}\n"
        if $self->{debug};

    # stolen from Text::vFile::asData example
    $e{allday}=1 if _param($event,'DTSTART','VALUE')||'' eq 'DATE';

    #is it a rule that an event must contain either a duration or end?
    # answer: no, it's not (cpan bug #25232)
    my $end=$e{DTEND};
    my $duration=$end ? $end-$start : delete $e{DURATION};
    $duration ||= DateTime::Duration->new(days=> $e{allday} ? 1 : 0);
    $e{DTEND}||=$start+$duration;
    $e{hours}=_hours($duration) unless $e{allday};

    #build recurrence sets
    my $set;
    if (my $rid=$e{'RECURRENCE-ID'}) {
        return if $start < $self->{span}->start;
        push @{ $self->{recurrences} }, \%e;
        return;
    }
    if (my $recur=delete $e{RRULE}) {
        $set=$dfmt->parse_recurrence(recurrence=>$recur, dtstart=>$start,
                                     #cap infinite repeats
                                     until =>$self->{span}->end);
    } elsif ($end) {
        # non-rrule event possibly spanning multiple days,
        # expand into multiple events
        my $diff=$end-$start;
        if (!$e{allday} && $end->day > $start->day) {
            $self->add_span(\%e);
            return;
        }
        if ($diff->delta_days > 1) {
            # note recurrence includes last date, and allday events
            # end at 00 on the last (non-inclusive) day, so remove it
            # from set
            $set=DateTime::Set->from_recurrence
                (start=>$start,end=>$end->clone->subtract(days=>1),
                 recurrence=>sub {
                     return $_[0]->truncate(to=>'day')->add(days=>1)
                 });
            # reset duration to "allday" event
            $duration=DateTime::Duration->new(days=>1);
        }
    }
    $set||=DateTime::Set->from_datetimes(dates=>[$start]);

    # fix bug w/ recurrence containing no entries
    # note that count returns "undef" for infinitely large sets.
    return if defined $set->count && $set->count==0;

    if (my $dates=delete $e{'EXDATE'}) {
        #mozilla/sunbird set exdate to T00..., so, get first start date
        #and set times on exdates
        my $d=$set->min;
        my $exset=DateTime::Set->from_datetimes
            (dates=>[
                map {$_->set(hour=>$d->hour,minute=>$d->minute,
                             second=>$d->second)
                 } @$dates]);
        $set=$set
            ->complement(DateTime::Set->from_datetimes(dates=>$dates));
    }
    $set=$set->intersection($self->{span}) if $self->{span};
    my $iter=$set->iterator;
    while (my $dt=$iter->next) {
        #bug found by D. Sweet. Fix alarms on entries
        #other than first
        my $new_event={%e,DTSTART=>$dt,DTEND=>$dt+$duration};
        $new_event->{VALARM}=_fix_alarms($new_event, $e{DTSTART})
            if $new_event->{VALARM};
        $self->add_event($new_event);
    }
}
sub VALARM {
    my($self,$alarm,$e)=@_;

    my %a=();
    #handle "RELATED attribute
    my $which=$alarm->{properties}{TRIGGER}[0]{param}{RELATED}||'START';

    $self->map_properties(\%a,$alarm);
    $a{when}=ref $a{TRIGGER} eq 'DateTime::Duration'
        ? $e->{"DT$which"}+delete $a{TRIGGER}
            : delete $a{TRIGGER};

    push @{$e->{VALARM}},\%a;
}
sub _fix_alarms {
    my $e=shift;
    my $orig_start=shift;

    # trigger already remove, generate diff
    my $diff=$e->{DTSTART}-$orig_start;
    my @alarms=();
    foreach my $old (@{ $e->{VALARM} }) {
        my %a=%$old;
        $a{when}=$a{when}->clone->add_duration($diff);
        push @alarms, \%a;
    }
    return \@alarms;
}
sub add_objects {
    my $self=shift;
    my $event=shift;

    return unless $event->{objects};
    foreach my $o (@{ $event->{objects} }) {
        my $t=$o->{type};
        $self->$t($o,@_) if $self->can($t);
    }
}
sub _hours {
    my $duration=shift;

    my($days,$hours,$minutes)=@{$duration}{qw(days hours minutes)};
    $days||=0; $hours||=0; $minutes||=0;
    return sprintf "%.2f",($days*24*60+$hours*60+$minutes)/60.0;
}
sub convert_value {
    my($self,$type,$hash)=@_;

    my $value=$hash->{value};
    return $value unless $value; #should protect from invalid datetimes

    if ($type eq 'TRIGGER') {
        #can be date or duration!
        return $dfmt->parse_duration($value) if $value =~/^[-+]?P/;
        return $dfmt->parse_datetime($value)->set_time_zone($self->{tz});
    }
    if ($TYPES{hash}{$type}) {
        my %h=(value=>$value);
        map { $h{$_}=$hash->{param}{$_} } keys %{ $hash->{param} };
        return \%h;
    }
    return $dfmt->parse_duration($value) if $TYPES{durations}{$type};
    return $value unless $TYPES{dates}{$type};

    #mozilla calendar bug: negative dates on todos!
    return undef if $value =~ /^-/;

    #handle dates which can be arrays (EXDATE)
    my @dates=();
    foreach my $s (split ',', $value) {
        # I have a sample calendar "Employer Tax calendar"
        # which has an allday event ending on 20040332!
        # so, handle the exception
        my $date;
        eval {
            $date=$dfmt->parse_datetime($s)->set_time_zone($self->{tz});
        };
        push @dates, $date and next unless $@;
        die $@ if $@ && $type ne 'DTEND';
        push @dates,
            $dfmt->parse_datetime(--$value)->set_time_zone($self->{tz});
    }
    return @dates;
}
sub get_value {
    my($self,$props,$key)=@_;

    my @a=map {$self->convert_value($key,$_)} @{ $props->{$key} };
    return wantarray ? @a : $a[0];
}
sub _param {
    my($event,$key,$param)=@_;
    return $event->{properties}{$key}[0]{param}{$param};
}
#set $a from $b
sub map_properties {
    my($self,$e,$event)=@_;

    my $props=$event->{properties};
    foreach (keys %$props) {
        my @a=$self->get_value($props,$_);
        delete $e->{$_}, next unless defined $a[0];
        $e->{$_}=$TYPES{arrays}{$_} ? \@a : $a[0];
    }
    ;
    delete $e->{SEQUENCE};
}
sub _cur_calid {
    my $self=shift;
    return $self->{ical}{cals}[-1]{'X-WR-RELCALID'};
}
sub find_day {
    my($self,$d)=@_;

    my $h=$self->{ical}{events};
    #warn sprintf "find %4d-%02d-%02d\n",$d->year,$d->month,$d->day
    #if $self->{debug};
    foreach my $i ($d->year,$d->month,$d->day) {
        $h->{$i}||={};
        $h=$h->{$i};
    }
    return $h;
}
sub add_event {
    my($self,$event)=@_;

    $self->find_day($event->{DTSTART})->{$event->{UID}}=$event;
}
sub update_recurrences {
    my $self=shift;
    foreach my $event (@{ $self->{recurrences} }) {
        my $day=$self->find_day(delete $event->{'RECURRENCE-ID'});
        my $old=delete $day->{$event->{UID}}||{};
        $self->add_event({%$old,%$event});
    }
}
sub add_span {
    my($self,$event)=@_;
    my %last=%$event;

    #when event spans days, only alarm on first entry
    delete $last{VALARM};

    $last{DTSTART}=$event->{DTEND}->clone->truncate(to=>'day');
    $last{DTEND}=$event->{DTEND};
    $event->{DTEND}=$event->{DTSTART}->clone->truncate(to=>'day')
        ->add(days=>1);
    $last{hours}=_hours($last{DTEND}-$last{DTSTART});
    $event->{hours}=_hours($event->{DTEND}-$event->{DTSTART});
    my @a=();
    my $min=$self->{span}->start;
    my $max=$self->{span}->end;
    for (my $d=$event->{DTEND}->clone;
         $d < $last{DTSTART}; $d->add(days=>1)) {
        if ($d >= $min && $d <= $max) {
            my %t=%last;
            $t{DTSTART}=$d->clone;
            $t{DTEND}=$d->clone->add(days=>1);
            $t{hours}=_hours($t{DTEND}-$t{DTSTART});
            push @a,\%t;
        }
    }
    my($start,$end)=($self->{span}->start,$self->{span}->end);
    map {$self->add_event($_)} grep {
        $_->{DTSTART} >= $start && $_->{DTEND} <= $end
    } $event,@a,\%last;
}
1;
__END__

=head1 NAME

iCal::Parser - Parse iCalendar files into a data structure

=head1 SYNOPSIS

  use iCal::Parser

  my $parser=iCal::Parser->new();
  my $hash=$parser->parse($file);

  $parser->parse($another_file);
  my $combined=$parser->calendar;

  my $combined=iCal::Parser->new->parse(@files);
  my $combined=iCal::Parser->new->parse_files(@files);
  my $combined=iCal::Parser->new->parse_strings(@strings);

=head1 DESCRIPTION

This module processes iCalendar (vCalendar 2.0) files as specified in RFC 2445
into a data structure.
It handles recurrences (C<RRULE>s), exclusions (C<EXDATE>s), event updates
(events with a C<RECURRENCE-ID>), and nested data structures (C<ATTENDEES> and
C<VALARM>s). It currently ignores the C<VTIMEZONE>, C<VJOURNAL> and
C<VFREEBUSY> entry types.

The data structure returned is a hash like the following:

    {
      calendars=>[\%cal, ...],
      events=>{yyyy=>{mm=>{dd}=>{UID=>\%event}}
      todos=>[\%todo, ...]
    }

That is, it contains an array of calendar hashes, a hash of events key by
C<year=E<gt>month=E<gt>day=E<gt>eventUID>, and an array of todos.

Calendars, events and todos are "rolled up" version os the hashes returned from
L<Text::vFile::asData>, with dates replaced by C<DateTime> objects.

During parsing, events in the input calendar are expanded out into multiple
events, one per day covered by the event, as follows:

=over 4

=item *

If the event is a one day "all day" event (in ical, the event is 24hrs long,
starts at midnight on the day and ends a midnight of the next day),
it contains no C<hour> field and the C<allday> field is set to C<1>.

=item *

If the event is a recurrence (C<RRULE>), one event per day is created as
per the C<RRULE> specification.

=item *

If the event spans more than one day (the start and end dates are on different
days, but does not contain an C<RRULE>),
it is expanded into multiple events, the first events end time is set
to midnight, subsequent events are set to start at midnight and end at
midnight the following day (same as an "allday" event, but the C<allday> field
is not set), and the last days event is set to run from midnight to the
end time of the original multi-day event.

=item *

If the event is an update (it contains a C<RECURRENCE-ID>), the original
event is updated. If the referenced event does not exist (e.g., it was
deleted after the update), then the event is added as a new event.

=back


An example of each hash is below.

=head2 Calendar Hash

    {
        'X-WR-CALNAME' => 'Test',
        'index' => 1,
        'X-WR-RELCALID' => '7CCE8555-3516-11D9-8A43-000D93C45D90',
        'PRODID' => '-//Apple Computer\\, Inc//iCal 1.5//EN',
        'CALSCALE' => 'GREGORIAN',
        'X-WR-TIMEZONE' => 'America/New_York',
        'X-WR-CALDESC' => 'My Test Calendar',
        'VERSION' => '2.0'
    }

=head2 Event Hash

Note that C<hours> and C<allday> are mutually exclusive in the actual data.
The C<idref> field contains the C<id> of the calendar the event
came from, which is useful if the hash was created from multiple calendars.

    {
        'SUMMARY' => 'overnight',
        'hours' => '15.00',
        'allday' => 1,
        'UID' => '95CCBF98-3685-11D9-8CA5-000D93C45D90',
        'idref' => '7CCE8555-3516-11D9-8A43-000D93C45D90',
        'DTSTAMP' => \%DateTime,
        'DTEND' => \%DateTime,
        'DTSTART' => \%DateTime
        'ATTENDEE' => [
           {
              'CN' => 'Jay',
              'value' => 'mailto:jayl@my.server'
           },
          ],
          'VALARM' => [
            {
              'when' => \%DateTime,
              'SUMMARY' => 'Alarm notification',
              'ACTION' => 'EMAIL',
              'DESCRIPTION' => 'This is an event reminder',
              'ATTENDEE' => [
                 {
                   'value' => 'mailto:cpan@my.server'
                 }
              ]
           }
         ],
    }

=head2 Todo Hash

    {
        'URL' => 'mailto:me',
        'SUMMARY' => 'todo 1',
        'UID' => 'B78E68F2-35E7-11D9-9E64-000D93C45D90',
        'idref' => '7CCE8555-3516-11D9-8A43-000D93C45D90',
        'STATUS' => 'COMPLETED',
        'COMPLETED' => \%DateTime,
        'DTSTAMP' => \%DateTime,
        'PRIORITY' => '9',
        'DTSTART' => \%DateTime,
        'DUE' => \%DateTime,
        'DESCRIPTION' => 'not much',
        'VALARM' => [
           {
              'when' => \%DateTime,
              'ATTACH' => 'file://localhost/my-file',
              'ACTION' => 'PROCEDURE'
           }
        ],
    },

=head1 Methods

=head2 new(%opt_args)

=head3 Optional Arguments

=over 4

=item start {yyymmdd|DateTime}

Only include events on or after C<yyymmdd>. Defaults to Jan of this year.

=item end {yyyymmdd|DateTime}

Only include events before C<yyymmdd>.

=item no_events

Don't include events in the output (todos only).

=item no_todos

Don't include todos in the output (events only).

=item months n

L<DateTime::Set>s (used for calculating recurrences) are limited to
approximately 200 entries. If an C<end> date is not specified, the
C<to> date is set to the C<start> date plus this many months.
The default is 60.

=item tz string

Use tz as timezone for date values.
The default is 'local', which will adjust the parsed dates to the current timezone.

=item debug

Set to non-zero for some debugging output during processing.

=back

=head2 parse({file|file_handle}+)

Parse the input files or opened file handles and return the generated hash.

This function can be called mutitple times and the calendars will be
merge into the hash, each event tagged with the unique id of its calendar.

=head2 parse_files({file|file_handle}+)

Alias for C<parse()>

=head2 parse_strings(string+)

Parse the input strings (each assumed to be a valid iCalendar) and return
the generated hash.

=head1 AUTHOR

Rick Frankel, cpan@rickster.com

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

L<Text::vFile::asData>, L<DateTime::Set>, L<DateTime::Span>,
L<iCal::Parser::SAX>
