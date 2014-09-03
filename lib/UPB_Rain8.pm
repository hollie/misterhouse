
=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	UPB_Rain8

Description:
	Device driver for the WGL Designs Rain8 UPB Sprinkler Controller
	http://www.wgldesigns.com/rain8upb.html

Author:
	Jason Sharpee
	jason@sharpee.com

License:
	This free software is licensed under the terms of the GNU public license.

Usage:

	-- Define in mht --
	##Type, name, PIM, NID, First DID
	UPBRAIN8, upb_sprinkler1, myPIM, 3, 1
	-- or in code --
	$upb_sprinkler1 = new UPB_Rain8($myPIM,3,1); #PIM, NID, first DID

    --- usage --
	$upb_sprinkler1->set("on:4"); #Turn Zone 4 on
	$upb_sprinkler1->set("off:4"); #Turn Zone 4 off
	
Special Thanks to:
	Warren Lohoff - I have bought quite a few of Warren's devices and they have never let me down.


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use UPB_Device;

use strict;

package UPB_Rain8;

@UPB_Rain8::ISA = ('Generic_Item');

sub new {
    my ( $class, $p_interface, $p_networkid, $p_deviceid ) = @_;

    my $self = {};
    bless $self, $class;

    for ( my $index = $p_deviceid; $index < 9; $index++ ) {
        @{ $$self{devices} }[$index] =
          new UPB_Device( $p_interface, $p_networkid,
            $p_deviceid + $index - 1 );

        #		@{$$self{devices}}[$index]->tie_items($self);
    }
    return $self;
}

sub setstate_on {
    my ( $self, $p_substate ) = @_;
    if ( defined $p_substate ) {
        &::print_log("Zone:$p_substate:On");
        @{ $$self{devices} }[$p_substate]->set('on');
    }
    return;
}

sub setstate_off {
    my ( $self, $p_substate ) = @_;
    if ( defined $p_substate ) {
        &::print_log("Zone:$p_substate:Off");
        @{ $$self{devices} }[$p_substate]->set('off');
    }
    return;
}

1;
