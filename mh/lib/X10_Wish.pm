
package X10_Wish;

#-----------------------------------------------------------------------------
#
# A /dev/x10 interface, used by Misterhouse ( http://misterhouse.net )
#
# Uses the Wish/dev_x10 kernel module, available from http://sourceforge.net/projects/wish
# These are the currently supported device as of 9/2005:
#  PowerLinc Serial, PowerLinc 1132 USB, CM11A, and Firecracker/CM17A.
#
#-----------------------------------------------------------------------------

=begin comment

From Dan Wilga on 9/2005:

- When installing the wish/x10dev driver from sourceforge
  ( http://sourceforge.net/projects/wish ), I initially had trouble getting the
  module to do anything but hang. Buried in the FAQ was the reason; when using
  the 1.6.x version of wish (which is required for USB under a 2.4 kernel),
  you have to first `rmmod hid` before using `insmod x10_plusb`. This won't be
  necessary for serial port versions of the 1132.

- The wish interface can, of course, be used for the CM11/CM17, not just the
  1132.

- As mentioned previously, my code is transmit-only. It doesn't do anything
  with wish's status polling capabilities.

- To make wish the default X10 transmit device, turn off the cm11_port and
  cm17_port parameters in mh.ini, and add a new one called use_wish.

- To use the wish interface in a system that also uses a CM11 or CM17, you can
  instantiate the module like so:

  $X10_transmitter = new X10_Item('/dev/x10','wish','wish');

  (All that really matters here is 'wish' in the third position.)

=cut



use strict;
use vars qw($VERSION $DEBUG @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

require Exporter;

@ISA = qw(Exporter);
@EXPORT= qw( send );
@EXPORT_OK= qw();
%EXPORT_TAGS = (FUNC    => [qw( send )]);

Exporter::export_ok_tags('FUNC');

$EXPORT_TAGS{ALL} = \@EXPORT_OK;

#### Package variable declarations ####

($VERSION) = q$Revision$ =~ /: (\S+)/;

my %last_dev;
my %hex2int = qw( 0 0 1 1 2 2 3 3 4 4 5 5 6 6 7 7 8 8 9 9 A 10 B 11 C 12 D 13 E 14 F 15 );

sub send {
    my ($code) = @_;

    if (exists $main::Debug{x10}) {
        $DEBUG = ($main::Debug{x10} >= 1) ? 1 : 0;
    }

    print "Wish send: $code\n" if $DEBUG;

    my ( $hc, $cmd, $num ) = ($code =~ /^(.)(.)(.*)/);
    if ( $cmd eq 'L' ) {
        write_dev( $hc, $last_dev{$hc}, 'bri' );
    }
    elsif ( $cmd eq 'M' ) {
        write_dev( $hc, $last_dev{$hc}, 'dim' );
    }
    elsif ( $cmd eq 'J' ) {
        write_dev( $hc, $last_dev{$hc}, 'on' );
    }
    elsif ( $cmd eq 'K' ) {
        write_dev( $hc, $last_dev{$hc}, 'off' );
    }
    elsif ( $cmd ge '1' && $cmd le 'G' ) {
        $last_dev{$hc} = $cmd;
    }
    elsif ( $cmd eq '+' ) {
        write_dev( $hc, $last_dev{$hc}, "+$num" );
    }
    elsif ( $cmd eq '-' ) {
        write_dev( $hc, $last_dev{$hc}, "-$num" );
    }
   else {
        print "Wish: Unknown function: $code ($hc,$cmd)\n";
    }
}

sub write_dev {
    my ( $hc, $unit, $state ) = @_;

    my $dev = "/dev/x10/\L$hc".$hex2int{$unit};
    print "Wish::write_dev to $dev, data=$state\n" if $DEBUG;
    if (!open( DEV, ">$dev" )) {
        print "Failed to open $dev: $!\n";
        return;
    }
    print DEV "$state\n";
    close DEV;
}

1;
