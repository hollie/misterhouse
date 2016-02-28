
=begin comment

From Brian Paluson on 02/2003:

Ok,

I think I've worked out most of the issues that I wanted finished 
before I did a general release.

First, the files:

http://thepaulsens.com:8000/hvac.pl  and 
http://thepaulsens.com:8000/newhvac.pl

hvac.pl goes into your code directory, and this is what actually 
handles the turning on/off of the hvac system.  Note that currently, 
the only real supported interface is a relay board that actually turns 
on/off the different zones of your heating system.

newhvac.pl goes into a directory defined by your html_alias2_web 
variable.  This script allows you to set up and view the current state 
of your hvac system.

The scripts no longer write out a file to your data_dir.  Instead, it 
saves all of the settings to the Save hash.  Due to the way that it 
saves the settings, you will need version 2.76 or greater of 
misterhouse.  So, if you haven't upgraded yet, you should do so.

One other note, you will need to download a module called 
Schedule::Cron::Events to use the code.   This module determines when 
the next cron event will occur.   We need this timing information to 
compute when a rooom should start heating so that it will be warm at 
the correct time.  For example, if we have a rule saying that we want a 
room to be  70 degrees at 5PM, we will have to start heating the room 
before 5PM in order to have it be 70 degrees at that time.

Things left to do:
Write up some real documentation of the system so that others can build on it
Support more than just relay boards.
Add in control of the A/C
Put in checks to ensure that the heating system actually turned on/off.


=cut

use Schedule::Cron::Events;
use Time::Local;

my $hvac = $Save{hvac_system} if $Save{hvac_system};

if ( new_second 5 ) {

    #if ( $New_Minute ) {
    check_for_triggers($hvac);
}

if ( new_second 5 ) {
    &control_hvac($hvac);
}

$furnace = new Generic_Item;

if ($New_Second) {
    my $furnacestate = "off";

    foreach my $zone ( @{ $hvac->{heatingzones} } ) {
        my $controller = get_object_by_name( $zone->{Controller} );

        if ( lc( $controller->state ) eq "on" ) {
            $furnacestate = "on";
            $Save{hvac_statistics}->[0]->{heattime}->{ $zone->{Name} }++;
        }
    }

    if ( $furnacestate eq "on" ) {
        $Save{hvac_statistics}->[0]->{heattime}->{furnace}++;

        if ( lc( $furnace->state ) ne "on" ) {
            $Save{hvac_statistics}->[0]->{heatcycle}->{furnace}++;
        }
    }

    set $furnace $furnacestate if lc( $furnace->state ) ne $furnacestate;
}

if ($New_Day) {
    unshift @{ $Save{hvac_statistics} }, {};
}

use Data::Dumper;

sub check_for_triggers {
    my $hvac = shift;
    foreach my $zone ( @{ $hvac->{heatingzones} } ) {
        my @triggers = matchTriggers($zone);

        foreach my $i ( @{ $zone->{Rooms} } ) {
            my $sensor;
            $sensor = get_object_by_name( $i->{Sensor} ) if $i->{Sensor};
            next if !$sensor;

            my $room = lc( $i->{Name} );
            my $roomobj;
            if ($room) {
                $room =~ s/\W/_/g;
                $roomobj = get_object_by_name("\$hvac_$room");
            }
            my $state = $roomobj ? state $roomobj : "";
            next if lc($state) eq "occupied";

            my $temperature = $sensor->state;

            my $status    = "";
            my $nexttime  = "";
            my $event     = "";
            my $eventname = "";
            foreach my $j (@triggers) {
                next if $j->{Room} ne $i->{Name};
                next if $state eq $j->{State};

                $event = $j->{Event};
                my $firetime = time_to_trigger_fire($event);
                if ( !$nexttime || $firetime < $nexttime ) {
                    $status    = $j->{State};
                    $nexttime  = $firetime;
                    $eventname = $j->{Trigger};
                }
            }
            next if lc($state) eq "sleeping" && lc($status) eq "unoccupied";

            if ( lc($status) eq "sleeping" || lc($status) eq "occupied" ) {
                next
                  if ( $i->{Occupied} - $temperature ) *
                  $i->{TimeToHeat} *
                  60 < $nexttime - time;
                set $roomobj "Occupied";
                print_log
                  "$i->{ Name } set to Occupied to prepare for $eventname";
            }
        }
    }
}

sub matchTriggers {
    my $zone = shift;

    my @matches;
    foreach my $i (trigger_list) {
        next if !trigger_active($i);
        my ( $trigger, $code, $type, $triggered ) = trigger_get($i);

        #	print "'$i' '$trigger' '$code' '$type' '$triggered'<br />\n";

        foreach my $j ( @{ $zone->{Ties} } ) {
            my $item = $j->{Item};
            my $val  = $j->{Value};
            next if !$val;
            $item =~ s/\$/\\\$/g;
            if ( $code =~ m{set\s+$item\s+([\'\"])$val\1}gi ) {
                push @matches,
                  {
                    Trigger => $i,
                    Event   => $trigger,
                    Room    => $j->{Room},
                    State   => $j->{State},
                  };
            }
        }

        #	print STDERR $code, "\n";
        foreach my $j ( @{ $zone->{Rooms} } ) {
            my $name = lc( $j->{Name} );
            $name =~ s/\W/_/g;
            $name = '\$hvac_' . $name;

            if ( $code =~ m{set\s+$name\s+([\'\"])(\w+)\1} ) {
                push @matches,
                  {
                    Trigger => $i,
                    Event   => $trigger,
                    Room    => $j->{Name},
                    State   => $2,
                  };
            }
        }

    }

    return @matches;
}

sub control_hvac {
    my $hvac = shift;

    my $furnacestate = "off";
    foreach my $zone ( @{ $hvac->{heatingzones} } ) {
        my $controller = get_object_by_name( $zone->{Controller} );

        if ( lc( $controller->state ) eq "on" ) {
            $furnacestate = "on";
            last;
        }
    }

    foreach my $zone ( @{ $hvac->{heatingzones} } ) {
        my $controller = get_object_by_name( $zone->{Controller} );

        my $alloff   = 1;
        my $wanton   = 0;
        my $forceoff = 0;

        foreach my $room ( @{ $zone->{Rooms} } ) {
            next if !$room->{Name};
            my $name = lc( $room->{Name} );
            my $roomobj;
            my $desiredobj;
            if ($name) {
                $name =~ s/\W/_/g;
                $roomobj    = get_object_by_name("\$hvac_$name");
                $desiredobj = get_object_by_name("\$hvac_${name}_desired");
            }
            my $state = $roomobj ? state $roomobj : "";
            next if !$state;
            my $desired = state $desiredobj;

            my $sensor;
            $sensor = get_object_by_name( $room->{Sensor} ) if $room->{Sensor};
            next if !$sensor;
            my $current = state $sensor;
            next if !$current;

            my $highoffset = $hvac->{"HighOffset_$state"};
            my $lowoffset =
                $furnacestate eq "on"
              ? $hvac->{"LowOffset2_$state"}
              : $hvac->{"LowOffset_$state"};

            #	    print_log "$room->{Name} : $state '$desired' '$current' '$lowoffset' '$highoffset' '$room->{Maximum}'";
            my $maximum = $room->{Maximum};

            my $roomoff = 0;
            if ( $current <= $desired + $lowoffset ) {
                $wanton = 1;
            }
            elsif ( $current >= $desired + $highoffset ) {
                $roomoff = 1;
            }
            elsif ( $current >= $maximum ) {
                $forceoff = 1;

                #speak (play=>"hvac", text=>"Turning $roomname heat off because it is $current_temperature degrees inside > $maximum too_hot setting.");
                #$hvac_states{ $heat_relay_name }->{ ROOMS }->{ $roomname } = "FORCEOFF";
                # force off - we are at maximum
            }

            $alloff = 0 if !$roomoff;
        }

        # here's the rule - we keep the zone on until all rooms have hit their
        # high offset or until one room hits the max
        if (1) {
            my $currentstate = state $controller;
            my $desiredState =
              $forceoff || $alloff
              ? "OFF"
              : ( $wanton ? "ON" : $currentstate );

            if ( lc($currentstate) ne lc($desiredState) ) {
                if ( lc($desiredState) eq "on" ) {
                    $Save{hvac_statistics}->[0]->{heatcycle}
                      ->{ $zone->{Name} }++;
                }
                set $controller $desiredState;
                select undef, undef, undef, 0.025;
            }
        }
    }
}

sub time_to_trigger_fire {
    my $trigger = shift;

    my $t;
    if ( $trigger =~ /time_random/ ) {
        return;
    }
    elsif ( $trigger =~ /time_now/ ) {

        # still need to handle if user passes in a 'Seconds' argument
        my ($timestr) = $trigger =~ /time_now\s\'(.*?)\'\s*$/;
        $t = &my_str2time($timestr);
        $t += 60 * 60 * 24 if $t - time < 0;
    }
    elsif ( $trigger =~ /^new_(\w+)/ ) {
        my $type = $1;

        my $interval = 1;
        if ( $trigger =~ /^new_\w+\s*\(?\s*\'?(\d+)\s*\'?\)?\s*$/ ) {
            $interval = $1;
        }
        if ( $type eq "second" ) {
            $interval = 1 if !$interval || $interval < 1;
            $interval = 59 if $interval && $interval > 59;

            $t = time + $interval - ( $Second % $interval ) - 1;
        }
        if ( $type eq "minute" ) {
            $interval = 1 if !$interval || $interval < 1;
            $interval = 59 if $interval && $interval > 59;

            $t =
              time - $Second + 60 * ( $interval - ( $Minute % $interval ) ) - 1;
        }
        if ( $type eq "hour" ) {
            $interval = 1 if !$interval || $interval < 1;
            $interval = 23 if $interval && $interval > 23;

            $t =
              time -
              $Second -
              60 * $Minute +
              3600 * ( $interval - ( $Hour % $interval ) ) - 1;
        }
    }
    else {
        my $faketrigger = $trigger;

        if ( $trigger eq "\$New_Hour" ) {
            $faketrigger = "time_cron '0 * * * *'";
        }
        elsif ( $trigger eq "\$New_Day" ) {
            $faketrigger = "time_cron '0 0 * * *'";
        }
        elsif ( $trigger eq "\$New_Week" ) {
            $faketrigger = "time_cron '0 0 * * 0'";
        }
        elsif ( $trigger eq "\$New_Month" ) {
            $faketrigger = "time_cron '0 0 1 * *'";
        }
        elsif ( $trigger eq "\$New_Year" ) {
            $faketrigger = "time_cron '0 0 1 1 *'";
        }

        if ( $faketrigger =~ /time_cron/ ) {

            # still need to handle if user passes in a 'Seconds' argument
            my ($timestr) = $faketrigger =~ /time_cron\s+\'(.*)\'/;
            my $cron = new Schedule::Cron::Events($timestr);
            $t = timelocal( $cron->nextEvent );
        }
    }

    return if !$t;

    return $t;
}

