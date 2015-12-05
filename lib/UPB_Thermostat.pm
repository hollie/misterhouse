
=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	UPB_Thermostat.pm

Description:
	Implementation of the RCS UPB thermostat (TU16)

Author:
	Tim Spaulding

License:
	This free software is licensed under the terms of the GNU public license.

Definition:
  (.pl code file)
	$thermostat = new UPB_Thermostat($myPIM,<networkid>,<deviceid>);

  (.mht file)
  UPBT, thermostat, <interface object name>, <networkid>, <deviceid>
Usage:
  use the methodes mode, cool_sp, heat_sp to set values;
  calling these methods with no parameters will return the current value

  see mh\code\publc\hvac_upb_thermostat.pl for some examples

Special Thanks to:
	Bruce Winter - MH
	Jason Sharpee

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package UPB_Thermostat;

@UPB_Thermostat::ISA = ('UPB_Device');

use UPB_Device;

my %modes = ( off => 0, heat => 1, cool => 2, auto => 3 );
my @modes = ( 'off', 'heat', 'cool', 'auto' );
my %setback_modes = (
    'off'            => 0,
    'night'          => 1,    #(NOT supported this rev)
    'away'           => 2,    #(NOT supported this rev)
    'vacation'       => 3,    #(NOT supported this rev)
    'special'        => 4,    #(NOT supported this rev)
    'system_setback' => 5,    #- SAME AS AWAY
    'zone_setback'   => 6,
    'remote'         => 7     #FLAG ONLY
);
my @setback_modes = (
    'off',     'night',          'away',         'vacation',
    'special', 'system_setback', 'zone_setback', 'remote'
);

# Variable 18 (operating mode)
use constant OPERATING_MODE_H1A => 0x01;
use constant OPERATING_MODE_H2A => 0x02;
use constant OPERATING_MODE_H3A => 0x04;
use constant OPERATING_MODE_C1A => 0x10;
use constant OPERATING_MODE_C2A => 0x20;
use constant OPERATING_MODE_FA  => 0x40;

# Variable 19 (relay status)
use constant RELAY_STATUS_W1 => 0x01;
use constant RELAY_STATUS_W2 => 0x02;
use constant RELAY_STATUS_G  => 0x04;
use constant RELAY_STATUS_Y1 => 0x08;
use constant RELAY_STATUS_Y2 => 0x10;

sub new {
    my ( $class, $p_interface, $p_networkid, $p_deviceid ) = @_;
    my $self = {};
    bless $self, $class;

    $self->interface($p_interface)  if defined $p_interface;
    $self->network_id($p_networkid) if defined $p_networkid;
    $self->device_id($p_deviceid)   if defined $p_deviceid;
    $self->initialize();
    $self->state_overload('off');

    #	$self->rate(undef);
    $$self{firstOctet} = "0";
    $$self{ackMode}    = "1";
    $$self{interface}->add($self);
    $self->EnableAutoSend();
    return $self;
}

sub initialize {
    my ($self) = @_;
}

sub EnableAutoSend {
    my ( $self, $state ) = @_;

    # right now, always enable autosend mode on the thermostat; this allows eh thermostat to send changes
    # when they happen either at the display or temperature change
    # leave mechanism to make this configurable

    #  if (defined($state))
    #  {
    $self->set("set_rcs_variable:6 1");    # . ($state =~ /on/i) ? '1' : '0');

    #    &::print_log($self->get_object_name() . "enabling AutoSend mode on thermostat");
    return;

    #  }
    #  return $$self{auto_send};
}

sub interface {
    my ( $self, $p_interface ) = @_;
    $$self{interface} = $p_interface if defined $p_interface;
    return $$self{interface};
}

sub network_id {
    my ( $self, $p_network_id ) = @_;
    $$self{network_id} = $p_network_id if defined $p_network_id;
    return $$self{network_id};
}

sub device_id {
    my ( $self, $p_device_id ) = @_;
    $$self{device_id} = $p_device_id if defined $p_device_id;
    return $$self{device_id};
}

# use the set method from UPB_Device for which this object is inherited

=begin
sub set
{
	my ($self,$p_state,$p_setby,$p_response) = @_;


    # prevent reciprocal sets that can occur because of this method's state
    # propogation
    return if (ref $p_setby and $p_setby->can('get_set_by') and
        $p_setby->{set_by} eq $self);

  $p_state = "request_rcs_variable:17" if ($p_state =~ /^report/i);
#   &::print_log($self->get_object_name() . "::set($p_state, $p_setby)");

	if ($p_setby eq $self->interface())
	{
	    my $network=unpack("C",pack("H*",substr($p_state,4,2)));
   		my $destination=unpack("C",pack("H*",substr($p_state,6,2)));
   		my $source=unpack("C",pack("H*",substr($p_state,8,2)));
		my $msg=unpack("C",pack("H*",substr($p_state,10,2)));
		my $l_state = $p_state;
		$p_state = undef;
		if ($network == $self->network_id() or $network==0)
		{
			if ( $destination==$self->device_id() or $destination==0 or $source == $self->device_id() )
			{
				if (!($source != $self->device_id() and $msg >= 0x80))
				{
					$p_state = $self->_xlate_upb_mh($l_state);
				    &::print_log($self->get_object_name() . "::set($p_state, $p_setby)");
				}
			}
		}
	} else {
		$$self{interface}->set($self->_xlate_mh_upb($p_state));
	    &::print_log($self->get_object_name() . "::set($p_state, $p_setby)");
	}
	$self->SUPER::set($p_state,$p_setby,$p_response) if defined $p_state;
}
=cut

sub _xlate_upb_mh {
    my ( $self, $p_state ) = @_;

    my $network     = unpack( "C", pack( "H*", substr( $p_state, 4,  2 ) ) );
    my $destination = unpack( "C", pack( "H*", substr( $p_state, 6,  2 ) ) );
    my $source      = unpack( "C", pack( "H*", substr( $p_state, 8,  2 ) ) );
    my $msgid       = unpack( "C", pack( "H*", substr( $p_state, 10, 2 ) ) );
    my $msgdata = substr( $p_state, 12, length($p_state) - 14 );
    my @args = unpack( "C*", pack( "H*", $msgdata ) );

    #  my $msg=undef;
    my $state = undef;

    #  &::print_log("UPBT: msgid:$msgid msgdata:$msgdata args:@args");

=begin
	for my $key (keys %UPB_Device::message_types){
		if ($UPB_Device::message_types{$key} == $msgid)
		{
#			&::print_log("UPBT:FOUND:KEY: $key");
			$msg=$key;
			last;
		}
	}
=cut

    #	$state=$msg;
    #Device report.
    if (    $UPB_Device::message_types{device_variable_report} == $msgid
        and $source == $self->device_id() )
    {
        if ( $args[0] == 6 ) {    # AutoSend variable
            $$self{auto_send} = sprintf( "%d", $args[1] );
            $state = sprintf( "auto_send: %d", $args[1] );
            &::print_log(
                "UPBT:xlate_upb_mh: auto_send is " . $$self{auto_send} )
              if $main::Debug{upbt};
        }
        elsif ( $args[0] == 9 ) {    #inside temperature report
            $$self{temp} = sprintf( "%d", $args[1] );
            $state = $$self{temp} . " degrees";
            &::print_log(
                "UPBT:xlate_upb_mh: inside temp is " . $$self{inside_temp} )
              if $main::Debug{upbt};
        }
        elsif ( $args[0] == 10 ) {    #outside temperature
            $$self{outside_temp} = sprintf( "%d", $args[1] );
            $state = sprintf( "outside_temp: %d", $args[1] );
            &::print_log(
                "UPBT:xlate_upb_mh: outside temp is " . $$self{outside_temp} )
              if $main::Debug{upbt};
        }
        elsif ( $args[0] == 11 ) {    #heat setpoint temperature
            $$self{heat_sp_temp} = sprintf( "%d", $args[1] );
            $state = sprintf( "heat_sp_temp: %d", $args[1] );
            &::print_log(
                "UPBT:xlate_upb_mh: heat sp temp is " . $$self{heat_sp_temp} )
              if $main::Debug{upbt};
        }
        elsif ( $args[0] == 12 ) {    #cool setpoint temperature
            $$self{cool_sp_temp} = sprintf( "%d", $args[1] );
            $state = sprintf( "cool_sp_temp: %d", $args[1] );
            &::print_log(
                "UPBT:xlate_upb_mh: cool sp temp is " . $$self{cool_sp_temp} )
              if $main::Debug{upbt};
        }
        elsif ( $args[0] == 13 ) {    #system mode
            $$self{mode} = $modes[ $args[1] ];
            $state = "mode: " . $modes[ $args[1] ];
            &::print_log( "UPBT:xlate_upb_mh: mode " . $$self{mode} )
              if $main::Debug{upbt};
        }
        elsif ( $args[0] == 14 ) {    #fan mode
            $$self{fan} = ( $args[1] == 0 ) ? 'Auto' : 'On';
            $state = "fan: " . ( $args[1] == 0 ) ? 'Auto' : 'On';
            &::print_log("UPBT:xlate_upb_mh: fan") if $main::Debug{upbt};
        }
        elsif ( $args[0] == 15 ) {    #setback mode
            $$self{setback_mode} = $setback_modes{ $args[1] };
            $state = "setback: " . $setback_modes[ $args[1] ];
            &::print_log("UPBT:xlate_upb_mh: Setback mode")
              if $main::Debug{upbt};
        }
        elsif ( $args[0] == 16 ) {    #display lockout
            $$self{display_lockout} = ( $args[1] == 0 ) ? 'Unlocked' : 'Locked';
            $state =
              "display_lockout: " . ( $args[1] == 0 ) ? 'Unlocked' : 'Locked';
            &::print_log("UPBT:xlate_upb_mh: Display Lockout $args[1]")
              if $main::Debug{upbt};
        }
        elsif ( $args[0] == 17 ) {    #send stat status
             # 6 bytes, Temp, Heat SP, Cool SP, H/C Mode, Fan mode, Outside Temp, (temp of 191= not valid)
            $$self{temp}         = sprintf( "%d", $args[1] );
            $$self{heat_sp_temp} = sprintf( "%d", $args[2] );
            $$self{cool_sp_temp} = sprintf( "%d", $args[3] );
            $$self{mode}         = $modes[ $args[4] ];
            $$self{fan} = ( $args[5] == 0 ) ? 'Auto' : 'On';
            $$self{outside_temp} = sprintf( "%d", $args[6] )
              if ( defined( $args[6] ) );
            my $msg_text = "Current temp is: $$self{temp} ";
            $msg_text .= "Current heat sp is: $$self{heat_sp_temp} ";
            $msg_text .= "Current cool sp is: $$self{cool_sp_temp} ";
            $msg_text .= "Current mode is: $$self{mode} ";
            $msg_text .= "Current fan is: $$self{fan} ";
            $msg_text .= " Current outside temp is: $$self{outside_temp}"
              if defined( $$self{outside_temp} );

            &::print_log("UPBT:xlate_UPB_MH: $msg_text") if $main::Debug{upbt};

            #		$state = "thermostat_status:";
            $state = $$self{temp} . " degrees";
        }
        elsif ( $args[0] == 18 ) {    #send operating mode status
             # 1 byte, bit encoded, B0= H1A, B1= H2A, B2= H3A, B4= C1A, B5= C2A, B6=FA
            &::print_log("UPBT:xlate_upb_mh: send operating mode status @args")
              if $main::Debug{upbt};
            $$self{operating_mode} = "Off" if ( $args[1] == 0 );
            $$self{operating_mode} = "fan blowing"
              if ( $args[1] & OPERATING_MODE_FA );
            $$self{operating_mode} .= "|heating, stage 1"
              if ( $args[1] & OPERATING_MODE_H1A );
            $$self{operating_mode} .= "|heating, stage 2"
              if ( $args[1] & OPERATING_MODE_H2A );
            $$self{operating_mode} .= "|heating, stage 3"
              if ( $args[1] & OPERATING_MODE_H3A );
            $$self{operating_mode} .= "|cooling, stage 1"
              if ( $args[1] & OPERATING_MODE_C1A );
            $$self{operating_mode} .= "|cooling, stage 2"
              if ( $args[1] & OPERATING_MODE_C2A );
            &::print_log(
                "UPBT:XLATE_UPB_MH current operating mode is: $$self{operating_mode}"
            ) if $main::Debug{upbt};
            $state = "operating_mode_status: $$self{operating_mode}";
        }
        elsif ( $args[0] == 19 ) {    #send relay mode status
            $state = undef;           #"relay_mode_status"
        }
    }
    return $state;
}

sub _xlate_mh_upb {
    my ( $self, $p_state ) = @_;
    $p_state = "request_rcs_variable:17" if ( $p_state =~ /^report/i );
    my $cmd;
    my @args;
    my $msg;

    #	my $level;
    #	my $rate;

    #msg id
    $msg = $p_state;
    $msg =~ s/\:.*$//;
    $msg = lc($msg);

    #	&::print_log("XLATE:$msg:$p_state:");
    $msg = $UPB_Device::message_types{$msg};

    #	&::print_log("UPBT: message_type: $p_state found value: $msg");

    #control word
    #	$cmd=$$self{firstOctet} . "970";
    $cmd = $$self{firstOctet} . "0" . $$self{ackMode} . "0";

    #network id;
    $cmd .= sprintf( "%02X", $self->network_id() );

    #destination;
    $cmd .= sprintf( "%02X", $self->device_id() );

    #source
    $cmd .= $self->interface()->device_id();

    #get specified args
    if ( $p_state =~ /\:/ ) {
        $p_state =~ /\:(.*)/;
        @args = split( ' ', $1 );

        #		&::print_log("msg args: @args");
    }

    ##Finish off the command
    $cmd .= sprintf( "%02X", $msg );
    for my $arg (@args) {

        #		&::print_log("XLATE3:$arg:@args:");

        $cmd .= sprintf( "%02X", $arg );
    }

    #set length
    substr( $cmd, 1, 1, sprintf( "%X", ( length($cmd) / 2 ) + 1 ) );

    #&::print_log ("UPBT: command I am sending to interface: $cmd");
    return $cmd;
}

sub temp {
    my ($self) = @_;

    # this is a read only value
    return $$self{temp};
}

sub outside_temp {
    my ($self) = @_;

    # return a value of 191 if it is not defined
    # if it is not defined, then you probably don't have an outside temp sensor
    return '191' unless defined( $$self{outside_temp} );

    # there is a real value, return it
    return $$self{outside_temp};
}

sub heat_sp {
    my ( $self, $state ) = @_;

    if ( defined($state) ) {
        $self->set("set_rcs_variable:11 $state");
        return;
    }
    return $$self{heat_sp_temp};
}

sub cool_sp {
    my ( $self, $state ) = @_;

    if ( defined($state) ) {
        $self->set("set_rcs_variable:12 $state");
        return;
    }
    return $$self{cool_sp_temp};
}

sub mode {
    my ( $self, $state ) = @_;

    if ( defined($state) ) {
        if ( $state =~ /@modes/ ) {
            &::print_log( "invalid mode request. Vallid modes are: " . @modes );
            return;
        }

        #    $self->set("set_rcs_variable:13 $modes{lc($state)}");
        &::print_log(
            "setting mode with command: set_rcs_variable:13 $modes{lc($state)}"
        );
        return;
    }
    return $$self{mode};
}

sub fan {
    my ($self) = @_;

    return $$self{fan};
}

sub setback_mode {
    my ( $self, $state ) = @_;

    if ( defined($state) ) {

        #    $self->set("set_rcs_variable:15 $setback_modes{$state}");
        &::print_log(
            "setting setbck_mode with command: set_rcs_variable:15 $setback_modes{$state}"
        );
        return;
    }
    return $$self{setback_mode};
}

sub display_lockout {
    my ( $self, $state ) = @_;

    if ( defined($state) ) {

        #    $self->set("set_rcs_variable:16 " . ($state =~ /on/i) ? '1' : '0');
        return;
    }
    return $$self{display_lockout};
}
1;
