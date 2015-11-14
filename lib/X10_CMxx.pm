
=begin comment

This is code will read X10 data received by the
RF CM19A RF USB and CM15A RF and PL USB receiver/transmitters.
Sending data is not supported and data is received by a 3rd party
program, mochad, which writes it to a fifo which this module reads.

1) Download and install mochad: http://sourceforge.net/projects/mochad/

 Make sure that your version supports the --raw-data option.
 If your mochad is too old, upgrade to something newer than 0.1.7.

2) Use these mh.ini parameters to enable this code:

 X10_CMxx_module = X10_CMxx
 X10_CMxx_fifo   = /var/run/cm19a

The way this will work is that at least on linux you need to have a udev 
rule that is configured to run mochad.scr, which in turn will run mochad
and sent its output to a fifo: /var/run/cm19a, which this module reads
from.
On my system, I have this:
cat /etc/udev/rules.d/91-usb-x10-controllers.rules
SUBSYSTEM=="usb", ATTR{idVendor}=="0bc7", ATTR{idProduct}=="0001", RUN+="/usr/local/bin/mochad.scr"
SUBSYSTEM=="usb", ATTR{idVendor}=="0bc7", ATTR{idProduct}=="0002", RUN+="/usr/local/bin/mochad.scr"


To monitor keys from an X10 TV/VCR RF remote (UR47A, UR51A, J20A, etc.),
(e.g. Play,Pause, etc), you can use something like this:

 $Remote  = new X10_CMxx;
 $Remote -> tie_event('print_log "CMxx key: $state"');
 set $TV $state if $state = state_now $Remote;

For a more general way to handle TV/VCR RF remotes and X10 security
devices, see RF_Item.pm.

If you want to relay all the of the incoming powerline style RF data
back out to the powerline, use mh/code/common/x10_rf_relay.pl.

Also see X10_W800.pm for a similar interface.

=cut

use strict;

#use Fcntl qw(:DEFAULT) ;
use Fcntl;

package X10_CMxx;
use X10_RF;

@X10_CMxx::ISA = ('Generic_Item');

my $fifo;
my $fifo_opened = 0;

sub open_fifo {
    close(X10_CMxx);
    $_ = sysopen( X10_CMxx, "$fifo", Fcntl::O_NONBLOCK | Fcntl::O_RDONLY );
    if ($_) {
        &::print_log("CMxx: (re)opened $fifo to get data from mochad");
    }
    else {
        &::print_log("CMxx: Failed to open $fifo to get data from mochad: $!");
    }
    return $_;
}

sub startup {
    $fifo = $main::config_parms{X10_CMxx_fifo};
    if ( not $fifo ) {
        warn ">>>>> X10_CMxx_fifo unset in mh.ini, X10_CMxx disabled <<<<<\n";
        sleep 5;
        return;
    }
    if ( not open_fifo() ) {
        &::print_log(
            ">>>>> CMxx: still can't open fifo $fifo: $!. Will try again later <<<<<<"
        );
        sleep 5;
    }
    else {
        $fifo_opened = 1;
    }
    &::MainLoop_pre_add_hook( \&X10_CMxx::check_for_data, 1 );
}

my ($prev_bad_checksums);
$prev_bad_checksums = 0;
my @msg_buffer = ();

sub check_for_data {
    my ($self) = @_;

    my $buffer;
    my $buffersize = 65536;
    my $rv;

    if ( not $fifo_opened and &::new_minute() ) {
        &::print_log(
            ">>>>> CMxx: has not yet opened $fifo. Trying again now <<<<<<");
        if ( not open_fifo() ) {
            &::print_log(
                ">>>>> CMxx: still can't open fifo $fifo: $!. Will try again later <<<<<<"
            );
        }
        else {
            $fifo_opened = 1;
        }
    }

    $rv = sysread( X10_CMxx, $buffer, $buffersize );

    # sysread returning undefined means fifo is ok, but no data received.
    return if ( not defined($rv) );

    # When the fifo is closed by the writer (or no one is on the other side,
    # buffer receives undefined.
    # we need to reopen it until someone starts writing to it.
    if ( not $buffer ) {

        # Reopen the fifo every 10 seconds if no one is writing to it.
        if ( &::new_second(10) ) {
            &::print_log("CMxx: no writer on fifo, reopening...");
            open_fifo();
            return;
        }
    }

    foreach my $line ( split( /\n/, $buffer ) ) {

        if ( not $line =~ /.* Raw data received: / ) {
            &::print_log("CMxx: decoded data received from mochad: $line")
              if $main::Debug{cmxx};
            return;
        }

        # Raw data received: 5D 20 60 9F 20 DF
        $line =~ s/.* Raw data received: //;

        # See mochad's decode.c:cm15a_decode_rf for details on the 2nd byte.
        # This accepts X10RF (20) and X10Sec (29).
        if ( not $line =~ s/^5D 2[09] // ) {

            # Unknown data isn't bad, it should just be recognized if it's valid data with a different
            # prefix, or ignored otherwise.
            warn(
                "Received $line from mochad, but does not start with known '5D 20/29', please fix me"
            );
            next;
        }
        my $data = $line;

        # Data gets sent multiple times
        #  - Check time
        #  - Process data only on the 2nd occurance, to avoid noise (seems essential)
        my $duplicate_threshold =
          1;    # 2nd occurance; set to 0 to omit duplicate check
        my $duplicate_count = duplicate_count($data);
        if ( $duplicate_count == $duplicate_threshold ) {
            my @bytes;
            my $byteidx = 0;

            &::print_log("CMxx: X10RF data from mochad: $line")
              if $main::Debug{cmxx};
            foreach my $byte ( split( /\s/, $data ) ) {

                #&::print_log("CMxx: set byte $byteidx to $byte") if $main::Debug{cmxx};
                $bytes[$byteidx] = chr( hex($byte) );
                $byteidx++;
            }

            my $state = X10_RF::decode_rf_bytes( 'X10_CMxx', @bytes );

            # If the decode_rf_bytes routine didn't like the data that it got,
            # we just drop the data (it's been preprocessed by mochad, so we can't hope to fix
            # it by dropping bytes or whatever, we just leave that work to mochad).
            &::print_log("CMxx: bad checksum, rejected $data")
              if ( $state eq 'BADCHECKSUM' );
        }
        elsif ( $duplicate_count == 0 ) {

            # Ignore the first send so that we can filter RF noise by confirming 2 identical frames in a row.
            &::print_log(
                "CMxx: Ignoring first send of X10RF data from mochad (looking for confirmation resend): $line"
            ) if $main::Debug{cmxx};
        }
        else {
            &::print_log(
                "CMxx: Ignoring duplicate X10RF data from mochad (dupe cnt >= $duplicate_count): $line"
            ) if $main::Debug{cmxx};
        }
    }
}

sub duplicate_count {
    my ($raw_msg) = @_;
    my $duplicate_count = 0;
    my $repeat_time = $main::config_parms{CMxx_multireceive_delay} || 1500;
    my $time = &main::get_tickcount;

    if ( my $msg_buffer_size = @msg_buffer ) {

        # most recent messages are always first in the queue
        for my $msg_ptr (@msg_buffer) {
            my %msg = %$msg_ptr;
            if ( &X10_CMxx::is_within_timeout( $time, $msg{time}, $repeat_time )
              )
            {
                # a match exists on the data; so, compare against the time stamp
                if ( $raw_msg eq $msg{data} ) {

                    # it's a duplicate since it's within the multireceive_delay
                    $duplicate_count++;
                }
            }
            else {
                # no point in continuing to look at the rest as it's out of the time window
                last;
            }
        }
    }

    # add to the msg buffer if it is not a duplicate
    add_data($raw_msg) unless $duplicate_count > 2;
    return $duplicate_count;
}

sub add_data {
    my ($data) = @_;
    my %msg = ();
    $msg{data} = $data;
    $msg{time} = &main::get_tickcount;

    my $max_length      = 20;
    my $msg_buffer_size = @msg_buffer;
    while ( $msg_buffer_size >= $max_length ) {

        # most recent messages are always first in the queue
        pop @msg_buffer;
        $msg_buffer_size = @msg_buffer;
    }
    unshift @msg_buffer, \%msg;
}

sub is_within_timeout {
    my ( $time1, $time2, $timeout ) = @_;
    return 1 if ( ( $time1 >= 2**7 ) and ( $time2 < 2**7 ) );
    return ( $time1 < ( $time2 + $timeout ) ) ? 1 : 0;
}

# vim:sw=4:sts=4

1;
