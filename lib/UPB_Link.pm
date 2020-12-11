
=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	UPB_Link.pm

Description:
	Generic class implementation of a UPB Device.

Author:
	Jason Sharpee
	jason@sharpee.com

License:
	This free software is licensed under the terms of the GNU public license.

Usage:

	$upb_family_movie = new UPB_Light($myPIM,30,1);

	$upb_familty_movie->set("on");

Special Thanks to:
	Bruce Winter - MH

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use UPB_Device;

use strict;

package UPB_Link;

@UPB_Link::ISA = ('UPB_Device');

=begin
my %message_types = ( 	
#UPB Core Command Set
						null => 0x00,
						write_enable => 0x01,
						write_protect => 0x02,
						start_setup => 0x03,
						stop_setup => 0x04,
						setup_timer => 0x05,
						auto_address => 0x06,
						device_status => 0x07,
						device_control => 0x08,
						add_link => 0x0B,
						delete_link => 0x0C,
						transmit_message => 0x0D,
						reset => 0x0E,
						device_signature => 0x0F,
						get_register => 0x10,
						set_register => 0x11,
#UPB Code Device Command Set
						activate_link => 0x20,
						deactivate_link => 0x21,
						goto => 0x22,
						fade_start => 0x23, 
						fade_stop =>0x24,
						blink => 0x25,
						indicate => 0x26,
						toggle => 0x27,
						report => 0x30,
						store => 0x31,					
#UPB Core Reports
						device_state_report =>0x86,
						device_status_report =>0x87
 );
=cut

sub new {
    my ( $class, $p_interface, $p_networkid, $p_deviceid ) = @_;

    my $self = $class->SUPER::new( $p_interface, $p_networkid, $p_deviceid );
    bless $self, $class;
    $$self{firstOctet} = "8";
    return $self;
}

sub _xlate_upb_mh {
    my ( $self, $p_state ) = @_;

    my $state = undef;
    $state = $self->SUPER::_xlate_upb_mh($p_state);

    ## As link devices, we xlate activate/deactivate into ON/OFF
    if ( lc($state) eq 'activate_link' ) {
        $state = 'ON';
    }
    elsif ( lc($state) eq 'deactivate_link' ) {
        $state = 'OFF';
    }
    return $state;
}

sub _xlate_mh_upb {
    my ( $self, $p_state ) = @_;
    my $state = $p_state;
    if ( lc($p_state) eq 'on' ) {
        $state = 'activate_link';
    }
    elsif ( lc($p_state) eq 'off' ) {
        $state = 'deactivate_link';
    }
    return $self->SUPER::_xlate_mh_upb($state);

}

1;
