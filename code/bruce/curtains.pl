# Category=HVAC

#@ Control the hardwired, relay controle, curtains, and an X10 controled curtain

# Toggle the x10 curtain controler
if ( !$Save{sleeping_parents} ) {
    if ( $Season eq 'Summer' ) {
        run_voice_cmd 'close the living room curtains'
          if time_cron '0  7 * * 1-5' and $Save{curtain_living} ne CLOSED;
    }
    else {
        run_voice_cmd 'open the living room curtains'
          if time_cron '0  7 * * 1-5' and $Save{curtain_living} ne OPENED;
    }
}
run_voice_cmd 'close the living room curtains'
  if time_cron '0 18 * * 1-5' and $Save{curtain_living} ne CLOSED;

$curtain_living = new X10_Appliance('OC');
$v_curtain_living =
  new Voice_Cmd('[open,close,change] the living room curtains');
$v_curtain_living->set_info(
    "Use change if this X10 toggled curtain gets out of sync");

$timer_curtain_living = new Timer();

if ( $state = said $v_curtain_living
    or 'manual' eq ( $state = state_now $curtain_living) )
{
    if ( active $timer_curtain_living) {
        speak "Curtain timer in use";
    }
    elsif ($state eq OPEN and $Save{curtain_living} eq OPENED
        or $state eq CLOSE and $Save{curtain_living} eq CLOSED )
    {
        speak "Curtain is already $Save{curtain_living}";
    }
    else {
        $state = 'do' if $state eq 'manual';    # X10 button

        #       speak "I am ${state}ing the living room curtains";
        print_log "Changing curtains from  $Save{curtain_living} to $state";
        unless ( $state eq 'change' ) {
            $Save{curtain_living} =
              ( $Save{curtain_living} eq OPENED ) ? CLOSED : OPENED;
        }
        set $curtain_living ON;
        set $timer_curtain_living 12, "&main::curtain_off('living');";
    }
}

$v_bedroom_curtain = new Voice_Cmd('[open,close] the bedroom curtains');
if (   $state = said $v_bedroom_curtain
    or $state = state_now $bedroom_curtain)
{
    &curtain_on( 'bedroom', $state );
}

$v_family_curtain = new Voice_Cmd('[open,close] the family room curtains');
if (   $state = said $v_family_curtain
    or $state = state_now $family_curtain)
{
    &curtain_on( 'family', $state );
}
$v_basement_curtain = new Voice_Cmd('[open,close] the basement curtains');
if (   $state = said $v_basement_curtain
    or $state = state_now $basement_curtain)
{
    speak "${state}ing the basement curtains";
    &curtains_all( $state, 'zack', 'family', 'nick' );
    &curtains_all( $state, 'family', 'nick' );
}

$v_nick_curtain = new Voice_Cmd('[open,close] Nicks curtains');
if (   $state = said $v_nick_curtain
    or $state = state_now $nick_curtain)
{
    &curtain_on( 'nick', $state );
}

$v_zack_curtain = new Voice_Cmd('[open,close] Zacks curtains');
if (   $state = said $v_zack_curtain
    or $state = state_now $zack_curtain)
{
    &curtain_on( 'zack', $state );
}

$v_all_curtains = new Voice_Cmd('[open,close] all the curtains');
$v_all_curtains->set_info('Controls all the curtains, sequentially');
if ( $state = said $v_all_curtains) {
    &curtains_all($state);
}

# Find average data
# sun_sensor data is percent of max sun
if ( $New_Minute and ( $Time - $Save{curtains_time} > 30 * 60 ) ) {

    #   print "db curtains=$Save{curtains_state} sun=$analog{sun_sensor} temp=$Weather{TempOutdoor}\n";
    if ( $Save{curtains_state} eq OPEN ) {

        # Close when it gets dark
        #       if (defined $analog{sun_sensor} and $analog{sun_sensor} < 20 and defined $Weather{TempOutdoor} and $Weather{TempOutdoor} < 50) {
        if (    $analog{sun_sensor} > 0
            and $analog{sun_sensor} < 20
            and defined $Weather{TempOutdoor}
            and $Weather{TempOutdoor} < 50 )
        {
            speak
              "Notice, the sun is dim at $analog{sun_sensor} percent, and it is cold outside "
              . "at "
              . round( $Weather{TempOutdoor} )
              . " degrees, so I'm closing the curtains at $Time_Now";
            &curtains_all(CLOSE);
        }
    }
    else {
        #       if ($analog{sun_sensor} > 40 and !$Save{sleeping_parents} and $Season eq 'Winter') {
        # 56 % cloudy, snowing, 10 am
        #       if (!$Save{sleeping_parents} and $analog{sun_sensor} > 50 and defined $Weather{TempOutdoor} and $Weather{TempOutdoor} < 45) {
        if (   !$Save{sleeping_parents}
            and $analog{sun_sensor} > 65
            and defined $Weather{TempOutdoor}
            and $Weather{TempOutdoor} < 45 )
        {
            speak
              "Notice, the sun is bright at $analog{sun_sensor} percent, and it is cold outside "
              . "at "
              . round( $Weather{TempOutdoor} )
              . " degrees, so I am opening the curtains at $Time_Now";
            &curtains_all(OPEN);
        }
    }
    run_voice_cmd 'close the living room curtains'
      if time_now $Time_Sunset
      and $Season eq 'Winter'
      and $Save{curtain_living} ne CLOSED;
}

# Close at sunset, as a backup
if ( $Save{curtains_state} eq OPEN and time_now("$Time_Sunset + 0:01") ) {
    speak("I am now closing the curtains at $Time_Now");
    &curtains_all(CLOSE);
}

$timer_curtains = new Timer();
my @curtains;

sub curtains_all {
    my ( $action, @list ) = @_;
    $Save{curtains_time} = $Time;
    if (@list) {
        @curtains = map { $_, $action } @list;
    }
    else {
        # Do the X10 curtain
        #       run_voice_cmd "$action the living room curtains";
        @curtains = (
            'bedroom', $action, 'family', $action,
            'zack',    $action, 'nick',   $action
        );

        #       @curtains = ('bedroom', $action, 'family' , $action,                  'nick', $action);
    }

    print "${action}ing the curtains\n";
    $Save{curtains_state} = $action
      unless @list;    # Save state if we did all of them

    &curtain_on( shift @curtains, shift @curtains );

    #   set $timer_curtains 10, \&curtain_next($action), 3;
    set $timer_curtains 10;
}

if ( expired $timer_curtains and @curtains ) {
    &curtain_on( shift @curtains, shift @curtains );
    set $timer_curtains 10;
}

$timer_curtain = new Timer();

sub curtain_on {
    my ( $room, $action ) = @_;

    #   print "\ndb room=$room action=$action\n";
    return unless $room and $action;

    #   speak("rooms=$room $room curtains $action");
    #   speak("$room curtains $action");

    my %times_open = qw(bedroom 8.2 nick 6.0 family 6.4 zack 8.0);

    #   my %times_open  = qw(bedroom 8.2 nick 6.0 family 3.0 zack 6.5);
    my %times_close = qw(bedroom 6.5 nick 5.0 family 5.5 zack 6.5);
    my $time = ( $action eq OPEN ) ? $times_open{$room} : $times_close{$room};

    # Since we share timer and relay ... one at a time
    if ( active $timer_curtain) {
        speak "Reset";
        run_action $timer_curtain; # Prematurely turn off the previous curtain's relay
    }

    set $timer_curtain $time, "&main::curtain_off('$room');";
    set $curtain_updown $action;

    eval "set \$curtain_$room ON;";
}

sub curtain_off {
    my ($room) = @_;
    print "set \$curtain_$room OFF\n";
    print_log "set \$curtain_$room OFF";
    eval "set \$curtain_$room OFF;";
    set $curtain_updown OFF;
}
