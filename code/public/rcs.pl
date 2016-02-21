# Category=RCS

########################################################################
#
# rcs.pl
#
# Author: Craig Schaeffer
#
# RCS makes several X10 compatible thermostats.
#
# This script shows how to create RCS menus and send/receive RCS commands
# It works with both the TX10B and newer TX15B thermostats.
#
# Requires: RCS_Item.pm
#
#
########################################################################

use RCS_Item;

$TX10 = new RCS_Item('M');

# noloop=start      This directive allows this code to be run on startup/reload

if ( $MW and $Reload ) {

    # create the RCS Menu
    print "Creating Tk RCS menu\n";

    $Tk_objects{menu_RCS_items} = $Tk_objects{menu_bar}->Menubutton(
        text        => 'RCS',
        relief      => 'raised',
        borderwidth => 2,
        underline   => 0
      )->pack( side => 'left', padx => 0 )
      unless $Tk_objects{menu_RCS_items};

    # Create/Reset RCS cascade menu
    $Tk_objects{menu_RCS_items}->menu->delete( 0, 'end' );    # Delete old menus

    # build the 'send setpoint' menu
    $Tk_objects{Send_setpoint}{$TX10} = $Tk_objects{menu_RCS_items}->menu->Menu;
    &tk_cascade_entry(
        'Send setpoint',
        $Tk_objects{menu_RCS_items},
        $Tk_objects{Send_setpoint}{$TX10}
    );

    for my $cmd ( list_by_type $TX10 'setpoint' ) {
        $Tk_objects{Send_setpoint}{$TX10}->add(
            'command',
            -label  => $cmd,
            command => sub { $TX10->set("$cmd") }
        );
    }

    # build the 'send command' menu
    $Tk_objects{Send_command}{$TX10} = $Tk_objects{menu_RCS_items}->menu->Menu;
    &tk_cascade_entry(
        'Send commmand',
        $Tk_objects{menu_RCS_items},
        $Tk_objects{Send_command}{$TX10}
    );

    for my $cmd ( list_by_type $TX10 'cmd' ) {
        $Tk_objects{Send_command}{$TX10}->add(
            'command',
            -label  => $cmd,
            command => sub { $TX10->set("$cmd") }
        );
    }

    # build the 'request status' menu
    $Tk_objects{request_status}{$TX10} =
      $Tk_objects{menu_RCS_items}->menu->Menu;
    &tk_cascade_entry(
        'Request status',
        $Tk_objects{menu_RCS_items},
        $Tk_objects{request_status}{$TX10}
    );

    for my $cmd ( list_by_type $TX10 'request' ) {
        $Tk_objects{request_status}{$TX10}->add(
            'command',
            -label  => $cmd,
            command => sub { $TX10->set("$cmd") }
        );
    }
}

# noloop=stop

# init the RCS to accept Preset Dim commands
set $TX10 'Preset On' if $Startup;

# add some voice commands
$v_test_tx10 = new Voice_Cmd(
    "Set TX10 to [Increase 1 Deg,Decrease 1 Deg,Preset On,Preset Off,60 degrees,68 degrees,Request Setpoint,Request SB Delta,Request Temp,Request Fan,Request SB Mode,Request Mode]"
);

if ( $state = said $v_test_tx10) {
    print_log "tx10 set to $state";
    set $TX10 $state;
}

# handle responses from the RCS
if ( my $state = state_now $TX10) {

    my $type          = type $TX10 $state;
    my $last_cmd      = last_cmd $TX10;
    my $last_cmd_type = last_cmd_type $TX10;

    #print "last_cmd=$last_cmd last_cmd_type=$last_cmd_type\n";

    $_ = $type;
    SWITCH: {
        if (/status/) {

            #print "RCS status:TX10=$state type=$type\n";

            speak "The " . $state     if $state =~ /Fan is/;
            speak "Mode is " . $state if $last_cmd =~ /Request Mode/;
            if ( $last_cmd =~ /SB Mode/ ) {
                speak $state;
                $Save{HVAC_setback} = $state =~ /Setback is On/;
            }
            last SWITCH;
        }
        if (/temp/) {

            #print "RCS temp:TX10=$state type=$type\n";
            speak "Setback delta is " . $state if $last_cmd =~ /SB Delta/;
            speak "Setpoint temperature is " . $state
              if $last_cmd =~ /Request Setpoint/;
            speak "Current temperature is " . $state
              if $last_cmd =~ /Request Temp/;

            speak "Setpoint set to " . $state if $last_cmd_type =~ /setpoint/;
            last SWITCH;
        }
        if (/echo/) {
            print "RCS echo:TX10=$state type=$type\n";
            speak "RCS command confirmed";
            last SWITCH;
        }
        if (/cmd/) {

            #print "RCS cmd:TX10=$state type=$type\n";
            last SWITCH;
        }
        if (/request/) {

            #print "RCS request:TX10=$state type=$type\n";
            last SWITCH;
        }
        if (/setpoint/) {

            #print "RCS setpoint:TX10=$state type=$type\n";
            last SWITCH;
        }
    }
}

