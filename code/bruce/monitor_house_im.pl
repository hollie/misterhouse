# Category=Vehicles

#@ Send selected house events to im clients

=begin comment

Use this to send me information at work for various events

=cut

$monitor_doors = new Generic_Item;

$monitor_vehicles_timer = new Timer;
$monitor_doors_timer    = new Timer;

# Allow an easy way to test
$test_monitor_vehicles = new Voice_Cmd 'Test the vehicles tracker [1,2]';
set $monitor_vehicles "Vehicle $state is traveling somewhere, probably"
  if $state = said $test_monitor_vehicles;

if ( my $msg = state_now $monitor_vehicles) {

    # Do not send if we have sent recently,
    # unless it is a different car
    my ($car1) = $msg =~ /(.+?) +is /;
    my ($car2) = $monitor_vehicles_timer->{car};
    $monitor_vehicles_timer->{car} = $car1;

    #    my $car_timer = seconds_remaining $monitor_vehicles_timer;
    #    print_log "db car1=$car1 c2=$car2 timer=$car_timer";
    if ( inactive $monitor_vehicles_timer or ( $car2 ne $car1 ) ) {

        # Send message now, and when the timer expires
        &send_im_work($msg);

        #       set $monitor_vehicles_timer 10*60, "&send_im_work(q|Last reported: $msg|)";
        set $monitor_vehicles_timer 8 * 60;
    }
}

&send_im_work( "Last reported: " . state $monitor_vehicles)
  if expired $monitor_vehicles_timer;

# Now monitor door
#set $monitor_doors 'garage' if state_now $garage_door eq 'opened';
$garage_door->tie_items( $monitor_doors, 'opened', 'garage' );
$front_door->tie_items( $monitor_doors, 'opened', 'front' );
$back_door->tie_items( $monitor_doors, 'opened', 'back' );

if ( $state = state_now $monitor_doors) {

    #  Do not send if sent recently, unless it is a different door
    if ( inactive $monitor_doors_timer
        or ( $state ne $monitor_doors_timer->{door} ) )
    {
        $monitor_doors_timer->{door} = $state;
        &send_im_work(qq|$state door just opened|);

        # <a href="http://mh.misterhouse.net/web/motion/Driveway_Latest.jpg">Driveway</a>
        # <a href="http://mh.misterhouse.net/web/motion/Garage1_Latest.jpg">Garage</a>
        # <a href="http://mh.misterhouse.net/web/motion/latest_index.html">Index</a> |);
        set $monitor_doors_timer 15 * 60;
    }
}

# Allow for a ping test from work
$test_ping_work = new Voice_Cmd 'Ping work';
&send_im_work("Hello from home at $Date_Now")
  if said $test_ping_work
  or ( $Weekday and time_now '12 pm' );

# Test sending html
$test_ping_work2 = new Voice_Cmd 'Ping work 2';
&send_im_work(
    qq|Motion detected:
 <a href="http://mh.misterhouse.net/web/motion/Garage_Latest.jpg">Garage</a>
 <a href="http://mh.misterhouse.net/web/motion/Driveway_Latest.jpg">Driveway</a>
 <a href="http://mh.misterhouse.net/web/motion/latest_index.html">Index</a>
|
) if said $test_ping_work2;

# Monitor other stuff, like phone calls
&Speak_pre_add_hook( \&monitor_speak_im, 0 ) if $Reload;

sub monitor_speak_im {
    my (%parms) = @_;
    my $msg = $parms{text};
    $msg =~ s/[\n\r ]+/ /gm;
    if ( $msg =~ /^Call/ ) {    # phone calls
        &send_im_work($msg);
    }
}

sub send_im_work {
    my ($msg) = @_;
    $msg = "$Time_Now: " . ucfirst $msg;
    print_log "IM work: $msg";

    #    net_im_send    (text => $msg, to => 'misterhouse');
    net_im_send( text => $msg, to => 't1wfg' );    # Work

    #    net_msn_send   (text => $msg, to => 'bruce_winter@hotmail.com');
    #    net_msn_send   (text => $msg, to => 'twfcn2@hotmail.com');  # C2
    net_msn_send( text => $msg, to => 'twfcn5@hotmail.com' );    # Work
}

# the car    is traveling       east at 67 mph 14 miles east of Century High School
# Call from Fred Flinstone .  Call is from Fred Flinstone  .
