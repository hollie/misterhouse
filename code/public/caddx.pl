#!/usr/bin/perl
# -*- Perl -*-
#---------------------------------------------------------------------------
#  File:
#      caddx.pl
#  Description:
#      A perl script that interfaces to the caddx nx584 and/or nx8e
#  Author:
#      chris witte <cwitte@xmlhq.com>
#
#  Latest version:
#      Included in the misterhouse release from http://misterhouse.net
#
#
#  Documentation is in POD format at the bottom of this file.
#
#  This free software is licensed under the terms of the GNU public license.
#  Copyright 2002 Chris Witte
#
#---------------------------------------------------------------------------
#
#  Revision Log
# 0.01:   Initial public release/beta
#
# 0.03:   Added Win32 support
#         Added command line configurability
#         Added perlpod documentation.
#         Call set_clock after inactivity to sync the RTC.
#         Added support for more than 8 zones
#         Added support for partition reporting (stay/armed)
#         Added multiple (configurable) debug levels
#         Fixed a checksum calculation bug.
#         Included a missing library file (caddx_parse) in the release.
#
# 0.04:   Force ack bad csum after 5 consecutive retries.
#         Debug info is logged for this event regardless of debug mode.
#
# 0.05:   Default win log file to c:/ha/data
# 0.06:   Explicit GNU license info in header
#---------------------------------------------------------------------------
use strict;
use IO::Socket;
use Time::HiRes;
use FileHandle;
use caddx_parse;
use Getopt::Long;
use Pod::Usage;
use vars qw( $OS_win $ob $port $log_dir);
use RollFileHandle;
my $version = .04;

my $man  = 0;
my $help = 0;

my $debug;
my $debug_parse;
my $debug_msg;
my $debug_sum;
my $debug_io;
my $debug_udp;

my @debug_raw;
my $report_version;
my $net_dest      = "127.0.0.1";
my $udp_port      = "5055";
my $max_zones     = 8;             ## minimum number of zones by default on NX8
my $getopt_result = GetOptions(
    "debug:s"    => \@debug_raw,
    "version"    => \$report_version,
    "com_port=s" => \$port,
    "net_dest=s" => \$net_dest,
    "udp_port=s" => \$udp_port,
    "zones=i"    => \$max_zones,
    "help|?"     => \$help,
    "man"        => \$man,
    "log_dir=s"  => \$log_dir,
) or pod2usage(2);

@debug_raw =
  split( /,/, join( ',', @debug_raw ) );    # consolidate multiple options
foreach my $debug_test (@debug_raw) {
    $debug = 1;                             ## generic debug
    if ( lc $debug_test eq "io" ) {
        $debug_io = 1;
    }
    elsif ( lc $debug_test eq "sum" ) {
        $debug_sum = 1;
    }
    elsif ( lc $debug_test eq "msg" ) {
        $debug_msg = 1;
    }
    elsif ( lc $debug_test eq "parse" ) {
        $debug_parse = 1;
    }
    elsif ( lc $debug_test eq "udp" ) {
        $debug_udp = 1;
    }
    elsif ( lc $debug_test eq "all" ) {
        $debug_parse = 1;
        $debug_msg   = 1;
        $debug_sum   = 1;
        $debug_io    = 1;
        $debug_udp   = 1;
    }
    else {
        die "unknown debug option: $debug_test\n";
    }
}
$debug && print "zones: $max_zones\n";
$debug && print "net_dest: $net_dest\n";
$debug && print "udp_port: $udp_port\n";
$debug && print "com_port: $port\n";
pod2usage(1) if $help;
pod2usage( -exitstatus => 0, -verbose => 2 ) if $man;
if ($report_version) {
    print "$0: version $version\n";
    exit(0);

}

# removed leading slash for windows folks
my $debug_log  = new RollFileHandle(">> $log_dir/caddx.log.%m%d");
my $stdout_log = new RollFileHandle(">> $log_dir/caddx.out.%m%d");
die "can't open debug log in [$log_dir/caddx.log.mmdd]\n"  unless $debug_log;
die "can't redirect stdout to [$log_dir/caddx.out.mmdd]\n" unless $stdout_log;
$stdout_log->trap_stdxxx();    # install as default for stdout
select $debug_log;
$| = 1;                        # hotpipe
select STDOUT;
$| = 1;                        # hotpipe

#print &caddx::parse::getbits("\xff",2),"\n";
#my @qq;
my $msg_recv_time;

#push(@qq,&caddx::parse::getbits("\xff",2));
#push(@qq,scalar(&caddx::parse::getbits("\xff",'4-5')));
#print join(":",@qq),"\n";
#exit;

my (%zone_hash);
my (@xmit_q);
my ($reply_pending);
my $alarmed = 0;
my (%ack_mate) = (
    "\x01" => ["\x21"],
    "\x03" => ["\x23"],
    "\x04" => ["\x24"],
    "\x05" => ["\x25"],
    "\x06" => ["\x26"],
    "\x07" => ["\x27"],
    "\x09" => ["\x29"],
    "\x0a" => ["\x2a"],
    "\x10" => ["\x30"],
    "\x12" => [ "\x32", "\x33", "\x34", "\x35" ],
    "\x1d" => sub { &rm_pending_xmit("ack"); },    # msg OK, flush pending msg
    "\x1f" => sub { &rm_pending_xmit("nak"); }
    ,    # msg rejected, kill whatever msg caused it
    "\x1e" => sub { &force_resend() }    # nak from host, resend

);

my $z = "30";
my $msg;
$msg = "84097e1058f00100";
my $start = "\x0a";
my $end   = "\x0d";
my $enc   = pack( "C H*", length($msg) / 2, $msg );
my $l     = length($enc);
my $dec   = unpack( "H*", $enc );

#print "length: $l :: $dec\n";
#&fletcher_sum("$enc");
#my $tst=&build_msg($msg);
#&verify_msg($tst);

sub build_msg {
    my ($data) = @_;
    my $encode    = pack( "C H*", length($data) / 2, $data );
    my $sum       = &fletcher_sum("$encode");
    my $decode    = unpack( "H*", $encode );
    my $ascii_sum = unpack( "H*", $sum );
    my $msg1      = "\x7e" . $encode . $sum;
    &dump( $msg1, "build msg1" );
    $msg1;
}

sub verify_msg {
    my ($raw) = @_;
    if ( ord($raw) == 10 ) {    # lf?
        print "looks like ascii msg\n";
        my $data;
        $data = substr( $raw, 1 );    # dump first byte;
        chop($data);                  # dump last byte;
        my $sum = substr( $data, -4, 4 );    # get checksum
        substr( $data, -4, 4 ) = "";         # dump checksum
        print "verify_msg: sum: [$sum]\n";
        print "verify_msg: data: [$data]\n";

        my $encode    = pack( "H*", $data );
        my $calc_sum  = &fletcher_sum($encode);
        my $ascii_sum = unpack( "H*", $calc_sum );
        print "verify_msg: calc_sum: [$ascii_sum]\n";
    }

}

sub fletcher_sum {
    my ($msg) = @_;
    my ( $sum1, $sum2 );
    $sum1 = $sum2 = 0;
    $debug_sum && print "calculating sum (data lth:", length($msg), ")\n";
    foreach my $char ( split( //, $msg ) ) {
        my $hex = unpack( "H*", $char );
        my $c = ord($char);
        $debug_sum && print "hex: $hex  ord: $c\n";

        if ( 255 - $sum1 < $c ) { $sum1++; }
        $sum1 += $c;
        $sum1 &= 255;    # force 8bit math
        if ( $sum1 == 255 ) { $sum1 = 0; }

        if ( 255 - $sum2 < $sum1 ) { $sum2++; }
        $sum2 += $sum1;
        $sum2 &= 255;    # force 8bit math
        if ( $sum2 == 255 ) { $sum2 = 0; }

        my $h1 = sprintf( "%x", $sum1 );
        my $h2 = sprintf( "%x", $sum2 );
        $debug_sum && print "hex: $hex  ord: $c s1:$h1 s2:$h2\n";

    }
    return ( pack( "CC", $sum1, $sum2 ) );
}

sub dump {
    my ( $msg, $context, $force_dump ) = @_;

    return unless ( $debug_msg || $force_dump );
    my $hhmmss = &fmt_hhmmss;
    print $debug_log "$hhmmss [$context] dump:\t";
    foreach my $char ( split( //, $msg ) ) {
        my $hex = unpack( "H*", $char );
        print $debug_log "[$hex]";
    }
    print $debug_log "\n";
}

BEGIN {
    ## Unshift to catch MH libs from default install
    ## (caddx.pl in mh/code/public/)
    unshift( @INC, './../../lib', './../../lib/site', '.' );

    $OS_win = ( $^O eq "MSWin32" ) ? 1 : 0;
    if ($OS_win) {
        eval "use Win32::SerialPort";
        die "$@\n" if ($@);
        $log_dir = "c:/ha/data";
    }
    else {
        eval "use Device::SerialPort";
        die "$@\n" if ($@);
        $log_dir = "/tmp/";
    }
}    # End BEGIN

if ($OS_win) {
    $port = 'COM1' unless $port;
    $ob = Win32::SerialPort->new($port);
}
else {
    $port = '/dev/ttyS0' unless $port;
    $ob = Device::SerialPort->new($port);
}
die "Can't open serial port $port: $^E\n" unless ($ob);

$ob->user_msg(1);     # misc. warnings
$ob->error_msg(1);    # hardware and data errors

#	$ob->baudrate(9600);
#	$ob->parity("even");
#	$ob->parity_enable(1);   # for any parity except "none"
#	$ob->databits(7);
#	$ob->stopbits(2);
#	$ob->handshake('none');
#

my $pick_baud = 38400;

$ob->baudrate($pick_baud);
$ob->parity("none");
$ob->parity_enable(0);    # for any parity except "none"
$ob->databits(8);
$ob->stopbits(1);
$ob->handshake('none');

$ob->write_settings;

my $baud   = $ob->baudrate;
my $parity = $ob->parity;
my $data   = $ob->databits;
my $stop   = $ob->stopbits;
my $hshake = $ob->handshake;

print "B = $baud, D = $data, S = $stop, P = $parity, H = $hshake\n";
$ob->read_const_time(60000);
my $udp_dest = $net_dest . ":" . $udp_port;
my $udp_fh   = IO::Socket::INET->new(
    PeerAddr => $udp_dest,
    Proto    => 'udp'
);

die "can't open udp connection to $udp_dest" unless $udp_fh;

my $accum;
my $accum_age;
my $consecutive_csum_fail = 0;
&reset_accum();

&get_interface_config();
&set_clock();
&get_user_info(1);

&get_partition_snap(1);
&get_zone_snap(1);
&get_zone_name(1);
foreach my $zone ( 1 .. $max_zones ) {
    &get_zone_name($zone);
    &get_zone_status($zone);
    &get_partition_status($zone);
}

while (1) {

    $stdout_log->roll_logfile();    # re-open log file when date rolls.
    $debug_log->roll_logfile();     # re-open log file when date rolls.
    if ($alarmed) {
        &check_q("alarm timeout");
    }

    ## the read_const_time should break us out of the read if the
    ##   controller quits responding.
    ##if(@xmit_q){
    ##	$SIG{ALRM}=\&wake_up;
    ##	alarm(5);  # (re)send msg if controller is quiet
    ##}
    ##else{
    ##	alarm(0);  # turn it off
    ##}
    if (@xmit_q) {    ## if there is data pending...
        $ob->read_const_time(5000);    ## use a (shorter) timeout
    }
    else {
        $ob->read_const_time(60000)
          ;    ## not much to do anyway (except keep an eye on rtc drift)
    }

    my $result;
    my $char = $ob->GETC();

    #	my ($count, $result) = $ob->read(100);
    #	my $result  = $ob->READLINE();
    if ( defined $char ) {
        my $hhmmss = &fmt_hhmmss;
        $debug_io && print "$hhmmss read char:", length($char), ":";
        $debug_io && printf( "[%02x]\n", ord($char) );
        if ( $char eq "\x7e" ) {    # start of new msg, flush old msg
                                    # fall thru to the send code
            &reset_accum(1);        # force flush the accumulator
        }
        &collect_accum($char);
    }
    else {
        $debug_io && print "Read failed?!:", Time::HiRes::time(), "\n";
        &check_q("read timeout");    ## since we've been inactive for a while...
        &set_clock();                ## debug msg to see if we're still talking
    }

    my ( $start, $lth, $msg ) = unpack( "a C a*", $accum );
    my ($msg_num) = unpack( "C a*", $msg );
    my ($ack_required) = $msg_num & 128;
    $msg_num &= 63;                  ## just bits 0-5
    if ( $lth && ( length($accum) == $lth + 4 ) ) {
        $msg_recv_time = Time::HiRes::time();

        ## touchy error when checksum ends in "\x0a" ("\n")
        ##   the regex honors the \n as eol and leaves it in the
        ##   string, and zaps part of the msg instead:: use substr
        ##$msg=~s/(..)$//;  # last 2 chars is checksum
        my $line_sum = substr( $msg, -2, 2, "" );    # get sum and replace w/""

        $debug_io && printf( "start: [%02x]\n",        ord($start) );
        $debug_io && printf("native lth: $lth\n");
        $debug_io && printf( "msg lth w/o csum: %d\n", length($msg) );
        $debug_io && printf( "msg csum lth: %d\n",     length($line_sum) );
        $debug_io && printf( "msg num : %02d\n",       $msg_num );
        &dump( $accum, "Raw accum" );
        &dump( $msg,   "Raw   msg" );
        my $calc_sum = &fletcher_sum( pack( "C", $lth ) . $msg );
        if ( $calc_sum eq $line_sum ) {
            $debug_sum && print "checksum MATCH\n";
            &dump( $accum, "Match:" );
            my $key = uc( sprintf( "%02x", $msg_num ) . "h" );
            if ( $caddx::parse::laycode{$key} ) {
                $debug_sum && print "calling rtn for $key\n";
                my $phash = &{ $caddx::parse::laycode{$key} }($msg);
                &show_parsed( $phash->{_parsed_}, $key );
                &process_msg( $msg_num, $phash );

            }
            else {
                $debug_sum && print "NO  rtn for $key\n";
            }
            if ($ack_required) {
                $debug_io && print "ACK required\n";
                my $reply = &build_msg("1d");
                $ob->PRINT($reply);
            }
            else {
                $debug_io && print "ACK Not required\n";
            }
            &apply_ack($msg_num);
            &check_q("message processed");

            $consecutive_csum_fail = 0;    # reset with good msg
        }
        else {
            $consecutive_csum_fail++;      # got another one.
            $debug_sum && print "checksum FAIL [$consecutive_csum_fail]\n";
            &dump( $calc_sum, "Calculated Sum:",       1 );
            &dump( $accum,    "Csum Failed accum:",    1 );
            &dump( $msg,      "Csum Failed Raw msg:",  1 );
            &dump( $line_sum, "Csum Failed line_sum:", 1 );
            ## workaround for bad csum calculation!??
            ##  if the csum gets stuck, everything locks
            ##  up, w/ the controller resending the same msg
            ##  and us refusing it.   this hasn't happened
            ##  in a while now...  switched from Ack to Nak
            my $reply;
            if ( $consecutive_csum_fail > 5 ) {    ## are we stuck?
                $reply = &build_msg("1d");         # forced ACK :-(
                ## and log the forced ack.
                &dump( $reply, "Csum Failed Force Ack:", 1 );
            }
            else {
                $reply = &build_msg("1e");         # forced NAK :-(
            }
            $ob->PRINT($reply);
        }
        $result = $accum;
        &reset_accum();                            # empty out the accumulator
        $debug_io && print "got a msg!!\n"
          ## got a msg!!

          #my $msg="action=scanner_input&data=$result&";
          #$udp_fh->send($msg);
          #print "sent udp: [$msg]\n";
          #for(my $x=0;$x<length($result);$x++){
          #	printf("[%02x]",ord(substr($result,$x,1)));
          #}
          #print "\n";
          #&reset_accum();        # empty out the accumulator
    }
}
undef $ob;

my $unstuff_pending;

sub reset_accum {
    my ($force) = @_;
    if ( $accum && $force ) {
        my $now = time();
        $debug_io
          && print "WARNING: flushed stale data [$accum] $accum_age $now\n";
    }

    $accum           = "";
    $accum_age       = 0;
    $unstuff_pending = 0;
}
###############################################################
##  this rtn will collect each character scanned into the accumulator.
##  if the age of the data already in the accumulator is too old,
##  flush the old data before collecting the new, so that unrelated
##  data is not dumped together (could have been noise on the serial
##  port, partial msg...)
##
###############################################################

sub collect_accum {
    my ($char) = @_;
    if ( $accum_age + 2 < time() ) {    #shouldn't take over 1 second
        &reset_accum();
        $accum_age = time();
    }
    if ($unstuff_pending) {
        my $orig_char = $char;
        $char = ord($char) ^ ord("\x20");
        $char = pack( "C", $char );

        $debug_io && printf(
            "UNSTUFFED %02x gave
                                 %02x\n", ord($orig_char), ord($char)
        );
        $unstuff_pending = 0;
    }
    elsif ( $char eq "\x7d" ) {    #don't unstuff an unstuffed 7d :-)
        $debug_io && printf( "STUFFED %02x Found\n", ord($char) );
        $unstuff_pending = 1;
        $char            = "";
    }
    $accum .= $char;
}

###########################################################
##  set_clock will send a msg to the controller w/ the current
##    date, time.
##
###########################################################
my $last_set_clock;

sub set_clock {
    my $now = time();
    return unless ( $last_set_clock + 3600 < $now );
    $debug_msg && print "set clock processing\n";
    $last_set_clock = $now;

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime($now);
    my $time_hex = pack( "C C C C C C",
        $year % 100,
        $mon + 1, $mday, $hour, $min, $wday + 1 );
    my $time_fmt = unpack( "H*", $time_hex );

    &dump( $time_hex, "time_hex" );
    &dump( $time_fmt, "time_fmt" );

    # my $clock_msg=&build_msg("3b" . $time_fmt);
    my $clock_msg = &build_msg( "bb" . $time_fmt );
    ## my $clock_msg=&build_msg("3b01090e070703");
    &dump( $clock_msg, "tentative set_clock" );
    &queue_msg($clock_msg);

}
###########################################################
##  get_zone_name will send a msg to the controller requesting
##    the name of a given zone.
##
##  apparently, these names are stored in the keypads not the
##    main controller?!?!  anyway, so far i haven't found
##    a way to set the zone name from this interface :-(
##
###########################################################
sub get_zone_name {
    my ($zone) = @_;
    $debug_msg && print "get zone name invoked\n";
    my $zone_msg = &build_msg( "23" . sprintf( "%02d", $zone - 1 ) );
    &dump( $zone_msg, "tentative zone_name_msg" );
    &queue_msg($zone_msg);

}
###########################################################
##  get_zone_status will send a msg to the controller requesting
##    a status update for the zone.
##
###########################################################
sub get_zone_status {
    my ($zone) = @_;
    $debug_msg && print "get zone status invoked\n";
    my $zone_msg = &build_msg( "24" . sprintf( "%02d", $zone - 1 ) );
    &dump( $zone_msg, "tentative zone_status_msg" );
    &queue_msg($zone_msg);

}
###########################################################
##  toggle_zone_bypass will toggle the bypass condition for
##    a given zone.
##
##
###########################################################
sub toggle_zone_bypass {
    my ($zone) = @_;
    $debug_msg && print "toggle zone bypass invoked\n";
    my $zone_msg = &build_msg( "3f" . sprintf( "%02d", $zone - 1 ) );
    &queue_msg($zone_msg);

}
###########################################################
##  get_zone_snap will send a msg to the controller requesting
##    a status snapshot for a block of zones.
##
##
###########################################################
sub get_zone_snap {
    my ($zone) = @_;
    $debug_msg && print "get zone snap invoked\n";
    my $zone_msg = &build_msg( "25" . sprintf( "%02d", $zone - 1 ) );
    &dump( $zone_msg, "tentative zone_snap" );
    &queue_msg($zone_msg);

}
###########################################################
##  get_partition status will send a msg to the controller requesting
##    a status snapshot for a partition.
##
##
###########################################################
sub get_partition_status {
    my ($part) = @_;
    $debug_msg && print "get part status invoked\n";
    my $msg = &build_msg( "26" . sprintf( "%02d", $part - 1 ) );
    &queue_msg($msg);

}
###########################################################
##  get_partition_snap will send a msg to the controller requesting
##    a status snapshot for all partitions.
##
##
###########################################################
sub get_partition_snap {
    $debug_msg && print "get partition snap invoked\n";
    my $msg = &build_msg("27");
    &queue_msg($msg);

}
###########################################################
##  get_user_info will send a msg to the controller requesting
##    the user info msg for a given user.
##
##
###########################################################
sub get_user_info {
    my ($user) = @_;
    $debug_msg && print "get user info invoked\n";
    my $user_msg = &build_msg( "33" . sprintf( "%02d", $user ) );
    &dump( $user_msg, "tentative user_info" );
    &queue_msg($user_msg);
}
###########################################################
##  get_interface_config will send a msg to the controller requesting
##    the configuration status msg from the controller.
##
###########################################################
sub get_interface_config {
    my ($user) = @_;
    $debug_msg && print "get interface_config invoked\n";
    my $msg = &build_msg( "21" . sprintf( "%02d", $user ) );
    &dump( $msg, "tentative interface_config" );
    &queue_msg($msg);
}
## untested 11/17/2001
sub put_request_terminal_mode {
    my ( $keypad, $seconds ) = @_;
    my $msg = &build_msg( "2c" . sprintf( "%02d%02d", $keypad, $seconds ) );
    &dump( $msg, "keypad_request " );
    &queue_msg($msg);
}
## untested 11/17/2001
sub put_keypad_data {
    my ( $keypad, $text ) = @_;
    my $msg = &build_msg( "2b" . sprintf( "%02d0000", $keypad ) );
    my $hextext = unpack( "H24", $text );
    $msg .= $hextext;
    &dump( $msg, "keypad_request " );
    &queue_msg($msg);
}
###########################################################
##  queue_msg will put an outbound msg to the controller in
##    the xmit queue.  there can only be one pending msg to
##    the controller at a time, and in may need to be acked
##    before the next msg can go.
##
##  all msgs to the controller should be routed thru the queue.
###########################################################
sub queue_msg {
    my ($msg) = @_;
    my $new_q = {};
    $new_q->{msg}         = $msg;
    $new_q->{submit_time} = Time::HiRes::time();
    $new_q->{xmit_count}  = 0;
    $new_q->{xmit_time}   = 0;
    $new_q->{msgnum}      = substr( $msg, 2, 1 );
    push( @xmit_q, $new_q );

    &check_q("message added");
}
###########################################################
##  check_q will check to see if there is a msg in the q
##    that is eligible for (re)xmit
##
###########################################################
sub check_q {
    my ($rsn) = @_;

    $debug_io && print "check_q b/c: $rsn\n";

    # give the controller a chance to answer pending msg.
    return if ( $reply_pending + 3 > time() );

    # is there a msg in queue that is eligible for send/resend
    if ( $xmit_q[0] && $xmit_q[0]{xmit_time} + 3 < time() ) {

        $xmit_q[0]{xmit_count}++;
        $xmit_q[0]{xmit_time} = Time::HiRes::time();
        $ob->PRINT( $xmit_q[0]{msg} );

        &dump( $xmit_q[0]{msg}, "check_q send:" );
        $debug_io && print scalar( localtime( time() ) ), "\n";
        $debug_io && printf(
            "sending msg [%02x] for the %d time (%d in queue)\n",
            ord( $xmit_q[0]{msgnum} ),
            $xmit_q[0]{xmit_count},
            scalar(@xmit_q)
        );
        $reply_pending = time();
    }
}

##  see if the reply we just got relieves a pending ack
sub apply_ack {
    my ($msgnum) = @_;    # decimal msgnum
    my $msghex = pack( "C", $msgnum );
    if ( !$xmit_q[0] ) {
        return;           # no pending ack
    }
    if ( $ack_mate{$msghex} ) {
        if ( ref( $ack_mate{$msghex} ) eq "CODE" ) {
            $debug_io
              && printf( "calling sub ref to ack %02x\n", ord($msghex) );
            &{ $ack_mate{$msghex} }();    # call it
        }
        if ( ref( $ack_mate{$msghex} ) eq "ARRAY" ) {
            if ( grep ( $xmit_q[0]{msgnum}, @{ $ack_mate{$msghex} } ) ) {
                &rm_pending_xmit("mate");
            }
            else {

                $debug_io && printf(
                    "pending msg  [%02x] not ack'ed by [%02x]\n",
                    ord( $xmit_q[0]{msgnum} ),
                    ord($msghex)
                );
            }
        }
    }
}
#####################################
##  called in response to nak from controller
##    --resend the last msg.
#####################################
sub force_resend {
    if ( $xmit_q[0] ) {
        $debug_io && print "forcing resend\n";
        $reply_pending = 0;
        $xmit_q[0]{xmit_time} = 0;
        &check_q();
    }
    else {
        $debug_io && print "force resend failed, no msg pending\n";
    }
}

#####################################
##  rm_pending_xmit should be called in response to a msg from the controller
##    --either directly called by  x1d or x1f
##    --or called b/c we got a matching reply to a request that we sent.
#####################################
sub rm_pending_xmit {
    my ($rsn) = @_;
    my $relieve_time = Time::HiRes::time();
    $debug_io && print "rm_pending_ack shrinking the xmit q b/c [$rsn]\n";
    &dump( '', "rm_pending_ack shrinking the xmit q b/c [$rsn]" );
    my $complete_msg = shift @xmit_q;

    if ($debug_io) {
        my $elapsed_time = $relieve_time - $complete_msg->{submit_time};
        my $process_time = $relieve_time - $complete_msg->{xmit_time};
        printf(
            "caddx stat: msg: [%02x] send cound: %d elapsed: %6.3f process: %6.3f\n",
            ord( $complete_msg->{msgnum} ),
            $complete_msg->{xmit_count},
            $elapsed_time, $process_time
        );
    }
    $reply_pending = 0;
    &check_q();

}
#####################################
##  wake_up is an alarm handler that will
##    trigger a resend if the controller hasn't replied to a pending msg.
#####################################
sub wake_up {
    $alarmed = 1;
}
#####################################
##  process_msg will digest the msgs
##    received from the controller.
#####################################
sub process_msg {
    my ( $msg_num, $phash ) = @_;
    if ( $msg_num == 3 ) {    # zone name
        my $zone = $phash->{zone};
        if ( defined $zone ) {
            $zone = ord($zone) + 1;
            &cache_info( $zone, "zone_name", $phash->{zone_name} );
        }
    }
    elsif ( $msg_num == 4 ) {    # zone status
        my $zone = $phash->{zone};
        if ( defined $zone ) {
            $zone = ord($zone) + 1;
            &cache_info( $zone, "faulted",      $phash->{faulted} );
            &cache_info( $zone, "tampered",     $phash->{tampered} );
            &cache_info( $zone, "trouble",      $phash->{trouble} );
            &cache_info( $zone, "bypassed",     $phash->{bypassed} );
            &cache_info( $zone, "alarm_memory", $phash->{alarm_memory} );
        }
    }
    elsif ( $msg_num == 5 ) {    # zone snapshot
        ## caddx docs call this zone offset, but it's really zone base
        ##  (the offset is the 1-8 within the msg)
        my $zone_base = $phash->{zone_offset};
        my $zsnap_rtn;
        if ( $caddx::parse::laycode{ZSNAP} ) {
            $zsnap_rtn = $caddx::parse::laycode{ZSNAP};

        }
        else {
            print "no layout for zsnap\n";
            return;
        }

        if ( defined $zone_base ) {
            $zone_base = ord($zone_base);
            my @zoffset = sort grep( /zone\d/i, keys %$phash );
            foreach my $zoff (@zoffset) {
                my $zone;
                if ( $zoff =~ /(\d+)/ ) {
                    $zone = $1 + ( 16 * $zone_base );
                }
                else {
                    next;
                }
                $debug_msg && print "calling rtn for zsnap $zoff [$zone]\n";
                my $phash = &{$zsnap_rtn}( $phash->{$zoff} );
                &show_parsed( $phash->{_parsed_}, "$zoff [$zone]" );
                &cache_info( $zone, "faulted",      $phash->{faulted} );
                &cache_info( $zone, "trouble",      $phash->{trouble} );
                &cache_info( $zone, "bypassed",     $phash->{bypassed} );
                &cache_info( $zone, "alarm_memory", $phash->{alarm_memory} );

            }
        }
    }
    elsif ( $msg_num == 6 ) {    # partition status
        my $partition = $phash->{hex_partition};
        if ( defined $partition ) {
            $partition = "partition" . ( ord($partition) + 1 );
            &cache_info( $partition, "armed", $phash->{armed} );
            &cache_info( $partition, "ready", $phash->{ready} );
            &cache_info( $partition, "chime", $phash->{chime} );
            &cache_info( $partition, "stay",  $phash->{stay} );
        }
    }
    elsif ( $msg_num == 7 ) {    # partition snapshot
        my $psnap_rtn;
        if ( $caddx::parse::laycode{PSNAP} ) {
            $psnap_rtn = $caddx::parse::laycode{PSNAP};

        }
        else {
            print "no layout for psnap\n";
            return;
        }

        my @partitions = sort grep( /partition\d/i, keys %$phash );
        foreach my $pkey (@partitions) {
            my $pnum;
            if ( $pkey =~ /(\d+)/ ) {
                $pnum = $1;
            }
            else {
                next;
            }
            $debug_msg && print "calling rtn for psnap $pkey\n";
            my $phash = &{$psnap_rtn}( $phash->{$pkey} );
            &show_parsed( $phash->{_parsed_}, $pkey );

            ## skip invalid partitions.
            return unless ( $phash->{valid} );
            &cache_info( $pkey, "ready", $phash->{ready} );
            &cache_info( $pkey, "armed", $phash->{armed} );
            &cache_info( $pkey, "stay",  $phash->{stay} );
            &cache_info( $pkey, "chime", $phash->{chime} );

        }
    }
    ## &cache_dump();
}
##########################################################
##  cache_info will cache a local status of the controller
##    msgs, so that we know the status of all of the zones.
##
##    when the status changes, call cache_modified to
##       perform zone change notification.
##########################################################
sub cache_info {
    my ( $key1, $key2, $data ) = @_;
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime( time() );
    my $tfmt =
      sprintf( "%02d/%02d %02d:%02d:%02d", $mon + 1, $mday, $hour, $min, $sec );

    if ( exists( $zone_hash{$key1}{$key2} ) ) {
        if ( $zone_hash{$key1}{$key2} ne $data ) {
            print "$tfmt cache_info changing [$key1],[$key2] from:",
              "[$zone_hash{$key1}{$key2}], to [$data]\n";
            &cache_modified( "old", @_ );
        }
        else {
            print "$tfmt cache_info static [$key1][$key2][$data]\n";
        }
    }
    else {
        print "$tfmt cache_info adding [$key1],[$key2] as:", "[$data]\n";
        &cache_modified( "new", @_ );
    }
    $zone_hash{$key1}{$key2} = $data;

}
#####################################
##  cache_modified is tripped when the status
##    of a zone changes.  we'll send the udp message
##    announcing the change.
#####################################
sub cache_modified {
    my ( $src, $key1, $key2, $data ) = @_;

    #	if($src eq "old" && $key1 eq "partition1" && $key2 eq "armed"
    #		&& $data eq "0"){
    #		foreach my $zone (1..5,7,8){
    #			&toggle_zone_bypass($zone);
    #		}
    #	}

    print "cache modified: $key1 $key2\n";

    if ( $key2 eq "faulted" ) {
        &udp_send( "zone=$key1" . "&" . "$key2=$data&time=$msg_recv_time\n" );
    }

    ## and report partition transitions...
    if ( $key2 eq "armed" ) {
        &udp_send(
            "partition=$key1" . "&" . "$key2=$data&time=$msg_recv_time\n" );
    }
    if ( $key2 eq "stay" ) {
        &udp_send(
            "partition=$key1" . "&" . "$key2=$data&time=$msg_recv_time\n" );
    }
}

sub udp_send {
    my ($msg) = @_;
    $udp_fh->send($msg);
    $debug_udp && print "udp sent dest:[$udp_dest] msg:[$msg]\n";
}
#####################################
##  debug rtn to dump the cache
#####################################
sub cache_dump {
    foreach my $key ( sort keys %zone_hash ) {
        print "cadump: $key : $zone_hash{$key}  \n";
        if ( ref( $zone_hash{$key} ) eq "HASH" ) {
            my $zh = $zone_hash{$key};
            foreach my $key2 ( sort keys %$zh ) {
                print "cadump: [$key] : [$key2] [$zh->{$key2}]\n";
            }
        }
    }

}
#####################################
##  debug rtn to dump parsed msg.
#####################################
sub show_parsed {
    my ( $parsed, $rsn ) = @_;
    return unless $debug_parse;
    for ( my $x = 0; $x < @$parsed; $x++ ) {
        my $cur  = $$parsed[$x];
        my $disp = $cur->[2];
        $disp = sprintf( "%02x", ord($disp) ) unless $disp =~ /^\w*$/;
        print "sparse: $rsn |$cur->[0] | $cur->[1] | $disp | $cur->[2] |\n";
    }
}

sub fmt_hhmmss {
    use POSIX;
    return strftime( "%H:%M:%S", localtime( time() ) );
}
__END__

=head1 NAME

caddx.pl - Script to interface the  caddx NX8e or NX584

=head1 SYNOPSIS

caddx.pl [options]


=head1 OPTIONS

=over 4

=item -help	brief help message

=item -man	full documentation

=item --com_port=/dev/ttySX    (default is /dev/ttyS0 or COM1)

=item --zones=8                (default is 8)

=item --net_dest=x.x.x.x     (default is 127.0.0.1)

=over 4

TCP/IP address that zone status and partition status change events will be
sent to.  Used in combination with --udp_port.

=back

=item --udp_port=x
(default is 5055)

=item --log_dir=xxxx
(Linux default is /tmp/)
(Win32 default is c:/ha/data)

=item -version
Report version and exit.

=item --debug=xxx  Invoke debug mode (verbose) where xxx can be 1 or more of:

=over 4

=item --debug=io  Report IO related activity

=item --debug=msg  Report Caddx msg related activity

=item --debug=parse  Insight into the parsing of caddx messages.

=item --debug=sum  Insight into the message checksum calculations.

=item --debug=udp  Log outbound UDP messages.

=item --debug=all  Turn on all debug related output

=back

=back

=head1 DESCRIPTION

This Program will currently interrogate the caddx controller on startup
to get the zone name information configured into the controller, as well
as the current zone/partition status information.  It then listens for
transition events from the caddx controller and forwards changes that are
detected via UDP messages to another process (Presumably misterhouse).
There is no acknowledgement code on the UDP messages, so the best configuration
is probably to run misterhouse and this script on the same box, in order to
eliminate the possibility that the UDP msgs are dropped by the network.

=head1 CADDX Configuration

Configure the caddx panel to communicate at 38400bps, using the binary
protocol.  The caddx panel MUST be set up accordingly.

=pod

For NX-8E you need to program the following locations, an NX8 with a
NX-584 should be similar:

  Location #207
   1     (Enable NX584)
  Location #208 Seg 1
   4     (38400 baud)
  Location #209
   All off  (binary protocol)
  Location #210 Seg #1   (send transition info)
   2     (Interface config)
   5     (Zone Status) <2>
   6     (Zone Snapshot) <2>
   7     (Partition Status)
   8     (Partition Snapshot)
  Location #210 Seg #2
   1     (System Status msg)
   2     (X10 Msg rcvd)
  Location #211 Seg #1   (Enable requests via serial port)
   2     (Interface configuration request)
   4     (Zone name request)
   5     (Zone status request)
   6     (zone snapshot request)
   7     (partition status request)
   8     (partition snapshot request)
  Location #211 Seg #2
   1     (system status request)
   2     (send X10 msg)   <1>
   3     (log event request) <1>
  Location #211 Seg #3
   1     (program data request) <1>
   2     (program data command) <1>
   3     (user info request with pin) <1>
   5     (set user code command with pin) <1>
   7     (set user authorization command with pin) <1>
  Location #211 Seg #4
   4     (set clock/calendar)
   5     (primary keypad function w/ pin) <1>
   7     (secondary keypad function)  <1>
   8     (zone bypass toggle)

FootNotes
<1>   Feature not currently used by this program
<2>   Zone snapshot s/b faster, but there is an open bug reported on
      the caddx panel whose only known fix is to enable Zone status msgs.
      See BUGS.

=cut

=head1 DEPENDENCIES

The following packages are required:

=item PodParser

(Included in Most Linux Distributions- PPM install required on Win32)

=item Time-HiRes

(Required on both Linux and Win32)

=head1 BUGS in this software

Creeping around in the dark.  Squeal on them and we can erradicate them.

=head1 BUGS in Caddx Controller

=over 4

=item INCORRECT ZONE SNAPSHOT

Zones Snapshot command doesn't correctly report cleared zones.
When Chime is enabled and Bypass is disable for a given zone, the snapshot
will correctly report the a clear zone until it is faulted.  The zone is
correctly reported as faulted, but will never be reported again as clear,
unless bypass or chime is disabled.  Workaround is to enable Zone Status
Message Transistion Enable in panel location 210, bit 5.

=item PANEL MESSAGE FAILS CHECKSUM

Panel gets into odd locked state with a message that doesn't pass checksum.
The communication link doesn't seem to have clobbered the msg, because it is
consistent.  Either the panel checksum calculation, (or ours), is broken.
Currently, the only way to break out of this is to force an ACK.
This release of the code will force an ACK after 5 failed checksums in order
to prevent a deadlock condition. If this happens, it is logged as such
(regardless of debug mode). Please report the message that triggered the
forced ACK, so that we can find a more palatable solution.

=back

=head1 AUTHOR

Chris Witte <cwitte@xmlhq.com>

=head1 ACKNOWLEDGEMENTS

Rob Williams <rob@pureagave.org> For Patiently helping to identify the problems in this script and suggest enhancements.  He also contributed several improvements to the documentation.

=cut
