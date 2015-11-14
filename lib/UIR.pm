
=begin comment 

UIR.pm - Misterhouse interface for the original UIR infrared receiver and derivatives like IRMan

10/3/2002	Created by David Norwood (dnorwood2@yahoo.com)

This module will report incoming infrared signals in the Misterhouse log output.  You can use
these signal codes to create triggers that can control your MP3 player, DVD software, etc.
To enable this module, add these entries to your .ini file: 

uir_module=UIR
uir_port=/dev/ttyS1	# optional, defaults to COM1
uir_baudrate=115200	# optional, defaults to 9600

To use this module, add lines like these to your code: 

$remote = new UIR '190003a0a0e2', 'play';
$remote->add      '190003eab012', 'stop';

if (my $state = said $remote) {
    set $mp3 $state;
}

=cut 

use strict;

package UIR;

@UIR::ISA = ('Serial_Item');

my $to   = new Timer;
my $prev = '';

sub startup {
    my $baudrate = 9600;
    my $port     = 'COM1';
    $baudrate = $main::config_parms{uir_baudrate}
      if $main::config_parms{uir_baudrate};
    $port = $main::config_parms{uir_port} if $main::config_parms{uir_port};
    &main::serial_port_create( 'UIR', $port, $baudrate, 'none', 'raw' );
    &::MainLoop_pre_add_hook( \&UIR::check_for_data, 1 );
}

sub check_for_data {
    my ($self) = @_;
    $prev = '' if expired $to;
    &main::check_for_generic_serial_data('UIR');
    my $data = $main::Serial_Ports{UIR}{data};
    $main::Serial_Ports{UIR}{data} = '';
    return unless $data;

    $main::Serial_Ports{UIR}{data} = substr( $data, 6 ) if length $data > 6;
    my @bytes = unpack 'C6', $data;
    my $state = '';
    foreach (@bytes) {
        $state .= sprintf '%02x', $_;
    }
    return if $state eq $prev;
    $prev = $state;
    set $to 1;

    &main::main::print_log("UIR Code: $state");

    # Set state of all UIR objects
    for my $name ( &main::list_objects_by_type('UIR') ) {
        my $object = &main::get_object_by_name($name);
        $object->set($state);
    }
}

1;

