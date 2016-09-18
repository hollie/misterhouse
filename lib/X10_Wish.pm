
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

From Jason Spangler, jasons@wumple.com, on 12/2005:

- I added basic receive support by utilizing /dev/x10/log

- Sending immediately after a receive was always dropped the send for me, so I added
  a one second delay when sending right after a receive.

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
require Fcntl;

@ISA         = qw(Exporter);
@EXPORT      = qw( startup send check_for_data close );
@EXPORT_OK   = qw();
%EXPORT_TAGS = ( FUNC => [qw( startup send check_for_data close )] );

Exporter::export_ok_tags('FUNC');

$EXPORT_TAGS{ALL} = \@EXPORT_OK;

#### Package variable declarations ####

($VERSION) = q$Revision$ =~ /: (\S+)/;

# @X10_Wish::ISA = ('Generic_Item');

my %last_dev;
my %hex2int =
  qw( 0 0 1 1 2 2 3 3 4 4 5 5 6 6 7 7 8 8 9 9 A 10 B 11 C 12 D 13 E 14 F 15 G 16 );
my $readlength = 512;

# file handle of log device file
my $x10log;

# file name of log device file
my $x10logname = "/dev/x10/log";

# time stamp of last received message from PLC
my $lastTimeStamp;

# mininum time to wait to send since last receive
my $minimumTimeBetween = 2;

# time to sleep
my $timeToSleep = 1;

# puts handle into nonblocking mode
sub setNonBlocking {
    my $handle = shift;
    my $flags = fcntl( $handle, Fcntl::F_GETFL, 0 )
      or die "Can't get flags for handle: $!\n";
    fcntl( $handle, Fcntl::F_SETFL, $flags | Fcntl::O_NONBLOCK )
      or die "Can't make handle nonblocking: $!\n";
}

sub checkDebug {
    my $debug = 0;

    if ( exists $main::Debug{x10} ) {
        $debug = ( $main::Debug{x10} >= 1 ) ? 1 : 0;
    }

    return $debug;
}

sub startup {
    my ($instance) = @_;

    &main::print_log("In X10_Wish::startup") if checkDebug();

    # Add hook only if serial port was created ok
    if ( $main::Serial_Ports{wish}{object} ) {

        # open the wish x10 device file
        sysopen( $x10log, $x10logname, Fcntl::O_RDONLY )
          or die "failed to open $x10logname";

        # seek to the end so we don't read past x10 commands
        sysseek( $x10log, 0, Fcntl::SEEK_END )
          or die "seek failed for $x10logname";

        # set handle to nonblocking
        setNonBlocking($x10log);

        # set us up to check for data
        &::MainLoop_pre_add_hook( \&X10_Wish::check_for_data, 1 );
        &main::print_log(
            "Added X10_Wish::check_for_data hook in X10_Wish::startup")
          if checkDebug();
    }
    else {
        &main::print_log("No wish object found in X10_Wish::startup")
          if checkDebug();
    }
}

sub send {
    my ($code) = @_;

    &main::print_log("Wish send: $code") if checkDebug();

    my ( $hc, $cmd, $num ) = ( $code =~ /^(.)(.)(.*)/ );
    if ( $cmd eq 'L' ) {
        safeWrite( $hc, $last_dev{$hc}, 'bri' );
    }
    elsif ( $cmd eq 'M' ) {
        safeWrite( $hc, $last_dev{$hc}, 'dim' );
    }
    elsif ( $cmd eq 'J' ) {
        safeWrite( $hc, $last_dev{$hc}, 'on' );
    }
    elsif ( $cmd eq 'K' ) {
        safeWrite( $hc, $last_dev{$hc}, 'off' );
    }
    elsif ( $cmd eq 'O' ) {
        safeWrite( $hc, $last_dev{$hc}, 'aon' );
    }
    elsif ( $cmd eq 'P' ) {
        safeWrite( $hc, $last_dev{$hc}, 'aoff' );
    }
    elsif ( $cmd ge '1' && $cmd le 'G' ) {
        $last_dev{$hc} = $cmd;
    }
    elsif ( $cmd eq '+' ) {
        safeWrite( $hc, $last_dev{$hc}, "+$num" );
    }
    elsif ( $cmd eq '-' ) {
        safeWrite( $hc, $last_dev{$hc}, "-$num" );
    }
    else {
        &main::print_log("Wish: Unknown function: $code ($hc,$cmd)");
    }
}

sub write_dev {
    my ( $hc, $unit, $state ) = @_;

    #   my $dev = "/dev/x10/\L$hc".$hex2int{$unit};
    my $dev = "/dev/x10/\L$hc" . ( defined($unit) ? $hex2int{$unit} : "" );
    &main::print_log("Wish::write_dev to $dev, data=$state") if checkDebug();
    if ( !open( DEV, ">$dev" ) ) {
        &main::print_log("Failed to open $dev: $!");
        return;
    }
    print DEV "$state\n";
    close DEV;
}

# Either collisions or the PLC had problems transmitting immediately when receiving
# So if we've seen a message recently (default is less than a second) we wait a
#   little bit (default is to send a second after receiving a message from PLC)
# Note: more X10 messages could be received by PLC and Wish driver while we are waiting
#   which could cause problem.  Rereading for messages here would be very complex so
#   skipping it for now.
#
sub safeWrite {
    my ( $hc, $unit, $state ) = @_;

    my $currentTime = time();

    if ( defined($lastTimeStamp) ) {
        my $timeBetween = $currentTime - $lastTimeStamp;
        if ( $timeBetween < $minimumTimeBetween ) {
            my $timeDifference = $minimumTimeBetween - $timeBetween;

            #           my $timeSleep = $timeDifference;
            my $timeSleep = $timeToSleep;
            &main::print_log("Wish::safeWrite() sleeping $timeSleep seconds")
              if checkDebug();
            sleep($timeSleep);
        }
    }

    write_dev( $hc, $unit, $state );
}

# test function
sub check_for_data2 {
    my $X10Code = 'XJFJJ';

    # pass the X10 command along to main::process_serial_data() for processing
    &main::print_log("X10 Code:$X10Code") if checkDebug();
    &main::process_serial_data($X10Code)
      if $X10Code;    # This will act like the CM11a and declare a X10 action
}

sub check_for_data {
    my $X10WishCode;
    my $X10Code;

    my $readcode = sysread( $x10log, $X10WishCode, $readlength );

    if ( !defined($readcode) ) {

        # error!
        return;
    }

    if ( $readcode == 0 ) {

        # no data to read, so return
        return;
    }

    # now we have data from the Wish driver's log file
    # so we have to parse it
    # see the description of the data at http://wish.sourceforge.net/index2.html
    #    under "Traffic log"

    # two types of messages are received:
    # <timestamp> <dir> <housecode><unitcode>
    # <timestamp> <dir> <housecode> <functioncode>

    # We alway seem to receive a single complete message
    # NOTE: However, if we can either receive a partial message or multiple
    #   messages in one read, we will need to handle those cases.

    # first get rid of \n\0 at end of each message
    my $end = substr( $X10WishCode, -2, 2 );

    # TODO: fix this, needs to be eq
    if ( $end == '\n\0' ) {
        $X10WishCode = substr( $X10WishCode, 0, -2 );
    }
    else {
        # NOTE: We do not support incomplete messages yet because
        #    we have never see them
        &main::print_log("Incomplete Wish Code: $X10WishCode") if checkDebug();
        return;

    }

    &main::print_log("Wish Code: $X10WishCode") if checkDebug();

    # Now parse it and translate to serial data format, i.e. XADAJ

    my $myMode;    # 'R' for receive, 'T' for transmit

    # is it the first part of a command?
    # <timestamp> <dir> <housecode><unitcode>
    if ( $X10WishCode =~ /^(\d+)\s(.+)\s([A-Z])(\d+)$/ ) {
        &main::print_log("Wish parsed: Time $1 Dir $2 House $3 Unit $4")
          if checkDebug();
        my $hexValue = sprintf( "%lX", $4 );
        if ( $4 == 16 ) {
            $hexValue = 'G';
        }

        $X10Code       = 'X' . $3 . $hexValue;
        $myMode        = $2;
        $lastTimeStamp = $1;
    }

    # is it the second part of a command?
    # <timestamp> <dir> <housecode> <functioncode>
    elsif ( $X10WishCode =~ /^(\d+)\s(.+)\s([A-Z])\s(.+)$/ ) {
        &main::print_log("Wish parsed: Time $1 Dir $2 House $3 Func $4")
          if checkDebug();
        $lastTimeStamp = $1;

        my $extraCode;
        if ( $4 eq 'ON' ) {
            $extraCode = 'J';
        }
        elsif ( $4 eq 'OFF' ) {
            $extraCode = 'K';
        }
        elsif ( $4 eq 'DIM' ) {
            $extraCode = '-';
        }
        elsif ( $4 eq 'BRIGHT' ) {
            $extraCode = '+';
        }
        elsif ( $4 eq 'ALL_LIGHTS_ON' ) {
            $extraCode = 'O';
        }
        elsif ( $4 eq 'ALL_LIGHTS_OFF' ) {
            $extraCode = 'P';
        }
        elsif ( $4 eq 'PRESETDIMLOW' ) {
            $extraCode = 'PRESET_DIM1';
        }
        elsif ( $4 eq 'PRESETDIMHIGH' ) {
            $extraCode = 'PRESET_DIM2';
        }

        if ($extraCode) {
            $X10Code = 'X' . $3 . $extraCode;
            $myMode  = $2;
        }

    }

    # could not parse!
    else {
        return;
    }

    # only handle receives, not transmits
    if ( $myMode ne 'R' ) {
        return;
    }

    # pass the X10 command along to main::process_serial_data() for processing
    &main::print_log("X10 Code:$X10Code") if checkDebug();
    &main::process_serial_data($X10Code)
      if $X10Code;    # This will act like the CM11a and declare a X10 action
}

sub close {

    # if the x10log file is open to receive events, then close it to avoid
    #    leaking file handles
    if ($x10log) {
        close($x10log);
    }
}

1;
