#!/usr/bin/perl                                                                                 
#
#
#
#    Add these entries to your mh.ini file:
#
#    Xantech_serial_port=COM2
# 
#    bsobel@vipmail.com
#    July 19, 2000
#
#

use strict;

my @xantech_zone_object_list;
my (@xantech_command_list, $trasnmitok, $temp);

package Xantech;

#
# This code create the serial port and registers the callbacks we need
#
sub serial_startup
{
    if ($::config_parms{Xantech_serial_port}) 
    {
        my($speed) = $::config_parms{Xantech_baudrate} || 9600;
        if (&::serial_port_create('Xantech', $::config_parms{Xantech_serial_port}, $speed, 'none')) 
        {
            init($::Serial_Ports{Xantech}{object}); 
            &::MainLoop_pre_add_hook( \&Xantech::UserCodePreHook,   1);
            &::MainLoop_post_add_hook( \&Xantech::UserCodePostHook, 1 );
        }
    }
}

sub init 
{
    my ($serial_port) = @_;
    $serial_port->error_msg(0);  
    #$serial_port->user_msg(1);
    #$serial_port->debug(1);

    $serial_port->parity_enable(1);		
    $serial_port->databits(8);
    $serial_port->parity("none");
    $serial_port->stopbits(1);

    #$serial_port->is_handshake("none");         #&? Should this be DTR?

    $serial_port->dtr_active(1);		
    $serial_port->rts_active(0);		
    select (undef, undef, undef, .100); 	# Sleep a bit
    ::print_log "Xantech init\n";

    $trasnmitok = 1;
}

sub UserCodePreHook
{
    # Check for input from the unit and update the internal objects as needed
    &::check_for_generic_serial_data('Xantech');
    if (my $data = $::Serial_Ports{Xantech}{data_record}) 
    {
        my ($f1,$f2,$f3,$f4,$f5,$f6,$f7,$f8,$f9,$f10,$f11,$f12,$f13) = $data =~ /\s*(\w+)\t(\w+)\t(\w+)\t(\w+)\t(\w+)\t(\w+)\t(\w+)\t(\w+)\t(\w+)\t(\w+)\t(\w+)\t(\w+)\t(\w+)/;

#        ::print_log "Xantech Data: " . $data . "\n";
#        print "Xantech Decode: " . $f1 . $f2 . $f3 . " etc.\n";

        # Check for numeric response and all 13 fields decoded
        if($f1 > 0 and $f13 ne undef)
        {
            # Loop thru each zone object
            for my $current_zone_object (@xantech_zone_object_list) 
            {
                next unless $current_zone_object->{zone} == $f1;

                $current_zone_object->set_states_for_next_pass("input:$f2") if($current_zone_object->{current_input} != $f2);
                $current_zone_object->set_states_for_next_pass("trim:$f3") if($current_zone_object->{current_trim} != $f3);
                $current_zone_object->set_states_for_next_pass("volume:$f4") if($current_zone_object->{current_volume} != $f4);
                $current_zone_object->set_states_for_next_pass("presetbalance:$f5") if($current_zone_object->{preset_balance} != $f5);
                $current_zone_object->set_states_for_next_pass("balance:$f6") if($current_zone_object->{current_balance} != $f6);
                $current_zone_object->set_states_for_next_pass("presettreble:$f7") if($current_zone_object->{preset_treble} != $f7);
                $current_zone_object->set_states_for_next_pass("treble:$f8") if($current_zone_object->{current_treble} != $f8);
                $current_zone_object->set_states_for_next_pass("presetbass:$f9") if($current_zone_object->{preset_bass} != $f9);
                $current_zone_object->set_states_for_next_pass("bass:$f10") if($current_zone_object->{current_bass} != $f10);            
                $current_zone_object->set_states_for_next_pass($f11 == 1 ? 'on' : 'off') if($current_zone_object->{current_status} != $f11);
                $current_zone_object->set_states_for_next_pass($f12 == 1 ? 'mute:on' : 'mute:off') if($current_zone_object->{current_mute} != $f12);
                $current_zone_object->set_states_for_next_pass("maximumvolume:$f13") if($current_zone_object->{maximum_volume} != $f13);

                # Apply settings for this zone
                $current_zone_object->{current_input}   = $f2;
                $current_zone_object->{current_trim}    = $f3;
                $current_zone_object->{current_volume}  = $f4;
                $current_zone_object->{preset_balance}  = $f5;
                $current_zone_object->{current_balance} = $f6;
                $current_zone_object->{preset_treble}   = $f7;
                $current_zone_object->{current_treble}  = $f8;
                $current_zone_object->{preset_bass}     = $f9;
                $current_zone_object->{current_bass}    = $f10;
                $current_zone_object->{current_status}  = $f11;
                $current_zone_object->{current_mute}    = $f12;
                $current_zone_object->{maximum_volume}  = $f13;
            }
        }
    }

    # Let's send any pending commands to the unit now.
    if(@xantech_command_list > 0 && $trasnmitok && !$::Serial_Ports{'Xantech'}{data})
    {
        if(@xantech_command_list > 0)
        {
            (my $output) = shift @xantech_command_list;
            print "Xantech Output: " .$output . "\n";
            $::Serial_Ports{Xantech}{object}->write($output . "\r");
        }
    }

    # Every 30 seconds let's ask the unit to give us the status of all zones
    # We will use this information to keep the zone objects up to date.
    if ($::New_Second and !($::Second % 30)) 
    {
        $::Serial_Ports{Xantech}{object}->write("Z00\r");
    }
}

sub UserCodePostHook
{
    #
    # Reset data for _now functions
    #
    $::Serial_Ports{Xantech}{data_record} = '';
}

1;

#
# Item object version (this lets us use object links and events)
#
package Xantech_Zone;
@Xantech_Zone::ISA = ('Generic_Item');

sub new 
{
    my ($class, $zone) = @_;

    my $self = {zone => $zone};
    bless $self, $class;

    push(@xantech_zone_object_list,$self);

    #
    # This is data we get from the zone query, default it here and then fill it in
    #
    $self->{current_input}   = "00";
    $self->{current_trim}    = "00";
    $self->{current_volume}  = "00";
    $self->{preset_balance}  = "00C";
    $self->{current_balance} = "00C";
    $self->{preset_treble}   = "06";
    $self->{current_treble}  = "06";
    $self->{preset_bass}     = "06";
    $self->{current_bass}    = "06";
    $self->{current_status}  = "0";
    $self->{current_mute}    = "0";
    $self->{maximum_volume}  = "40";

    my $output = sprintf("Z%2.2d",$zone);
    push(@xantech_command_list, $output);

    push(@{$$self{states}}, 'on','off','volume:max', 'volume:normal', 'volume:min','volume:+','volume:-','input:+','input:-');

    return $self;
}

sub NextInput
{
    my ($self) = @_;
    my $Return = $self->{current_input} + 1;
    return $Return > 8 ? 1 : $Return;
}

sub PrevInput
{
    my ($self) = @_;
    my $Return = $self->{current_input} - 1;
    return $Return < 1 ? 8 : $Return;
}

sub ToggleMute
{
    my ($self) = @_;

    print "mute is : $self" . $self->{current_mute} . "\n";
    return $self->{current_mute} > 0 ? 'N' : 'Y';
}


sub set
{
    my ($self, $state) = @_;

#    unshift(@{$$self{state_log}}, "$main::Time_Date $state");
#    pop @{$$self{state_log}} if @{$$self{state_log}} > $main::config_parms{max_state_log_entries};

    my $command;

    SWITCH: for( $state )
    {
        /^off/i            && do { $command = "CN"; last SWITCH;};
        /^on/i             && do { $command = sprintf("I%1.1d",$self->{current_input}); last SWITCH;};

        /volume:up/i       && do { $command = "LU"; last SWITCH;};
        /\Qvolume:+/i      && do { $command = "LU"; last SWITCH;};
        /^up/i             && do { $command = "LU"; last SWITCH;};
        /^\+/i             && do { $command = "LU"; last SWITCH;};

        /volume:down/i     && do { $command = "LD"; last SWITCH;};
        /\Qvolume:-/i      && do { $command = "LD"; last SWITCH;};
        /^down/i           && do { $command = "LD"; last SWITCH;};
        /^\-/i             && do { $command = "LD"; last SWITCH;};

        /volume:max/i      && do { $command = "V40"; last SWITCH;};
        /volume:min/i      && do { $command = "V00"; last SWITCH;};
        /volume:normal/i   && do { $command = "V30"; last SWITCH;};

        /input:next/i      && do { $command = "I" . $self->NextInput(); last SWITCH;};
        /\Qinput:+/i       && do { $command = "I" . $self->NextInput(); last SWITCH;};
        /^next/i           && do { $command = "I" . $self->NextInput(); last SWITCH;};

        /input:prev/i      && do { $command = "I" . $self->PrevInput(); last SWITCH;};
        /\Qinput:-/i       && do { $command = "I" . $self->PrevInput(); last SWITCH;};
        /^prev/i           && do { $command = "I" . $self->PrevInput(); last SWITCH;};

        /^quiet/i          && do { $command = "QY"; last SWITCH;};
        /^unquiet/i        && do { $command = "QN"; last SWITCH;};

        /^mute/i           && do { $command = "Q" . $self->ToggleMute(); last SWITCH;};
    }

    my ($target,$param) = $state =~ /\s*(\w+)\s*:*\s*(\d*)/;

    if($command eq undef)
    {
        SWITCH: for( $target ) 
        {
            /volume/i          && do { $command = sprintf("V%2.2d",$param); last SWITCH;};
            /input/i           && do { $command = sprintf("I%1.1d",$param); last SWITCH;};
            /treble/i          && do { $command = sprintf("T%2.2d",$param); last SWITCH;};
            /bass/i            && do { $command = sprintf("B%2.2d",$param); last SWITCH;};
        }
    }

    # Queue command
    my $output = "!" . sprintf("%2.2d" , $self->{zone}) . $command . "+";
    push(@xantech_command_list, $output);

 #   $self->set_states_for_next_pass($state);

    # Queue query for zone settings so object is updated
    $output = "Z" . sprintf("%2.2d" , $self->{zone});
    push(@xantech_command_list, $output);
    return;
}

sub state
{
    my ($self, $device) = @_;

    return &Generic_Item::state($self) if($device == undef);
    return undef if($self->{zone} == 0);

    if($self->{current_status} == 1)
    {
        return 'on';
    }
    else
    {
        return 'off';
    }
}

1;

