#!/usr/bin/perl

# v 0.1 - initial test concept, inspired by Pete's script - H. Plato - 2 June 2008
# v 0.2 - added pete's gmail send function, gmail list folders, better error checking

# v 0.3 - removed gmail send to it's own library, added ssl as an option.

# Adds IMAP message scan and gmail sending ability.
# Requires the following perl modules
#   Mail::IMAPClient
#   IO::Socket::SSL
#   IO::Socket::INET
#   Time::Zone
#
# if the IMAP scan hangs before authenticating against the gmail account, reinstall the
# IO::Socket::SSL
#
# Todo:
# - parse unread messages

package imap_utils;

use strict;
use warnings;
use Mail::IMAPClient;
use IO::Socket::SSL;
use IO::Socket::INET;
use POSIX;
use Time::Zone;
use Encode qw(encode decode find_encoding);

sub main::get_imap {

    my %parms    = @_;
    my $account  = $parms{gmail_account};
    my $age      = $parms{age};
    my $debug    = $parms{debug};
    my $password = $parms{password};
    my $peek     = 1;
    $peek = 0 if ( defined $parms{markread} );
    my $tz_offset = $parms{tz_offset};
    my $inbox     = $parms{inbox};
    my $server    = $parms{server};
    my $port      = $parms{port};
    my $quiet     = $parms{quiet};
    my $mhaccount = $parms{account};
    my $service   = "local";
    $service = $main::config_parms{"net_mail_${mhaccount}_service"}
      if ( defined $main::config_parms{"net_mail_${mhaccount}_service"} );
    my $ssl = 0;
    $ssl = $parms{ssl} if ( defined $parms{ssl} );
    $ssl = 1           if ( lc $service eq "gmail" );
    $ssl = 1           if ( lc $service eq "ssl" );

    my $size = 0;
    $size = $main::config_parms{"net_mail_scan_size"}
      if ( defined $main::config_parms{"net_mail_scan_size"} );

    #allow local overrides...
    $size = $main::config_parms{"net_mail_${mhaccount}_scan_size"}
      if ( defined $main::config_parms{"net_mail_${mhaccount}_scan_size"} );
    $size = $size * 1024;    #make it in K

    $server = $main::config_parms{"net_mail_${mhaccount}_server"}
      unless $server;
    $server = 'imap.gmail.com'
      if ( lc $main::config_parms{"net_mail_${mhaccount}_service"} eq "gmail"
        and !$server );

    unless ($server) {
        print "no server defined!";
        return;
    }

    $port = $main::config_parms{"net_mail_${mhaccount}_server_port"}
      unless $port;
    unless ($port) {
        if ($ssl) {
            $port = 993;
        }
        else {
            $port = 143;
        }
    }

    $inbox = "INBOX" unless $inbox;

    if ($mhaccount) {
        $account  = $main::config_parms{"net_mail_${mhaccount}_user"};
        $password = $main::config_parms{"net_mail_${mhaccount}_password"};
    }

    $debug = 0 if ( !defined $debug );
    $quiet = 0 if $debug;

    my %msgdata;
    my $message_count   = 0;
    my $unread_count    = 0;
    my $processed_count = 0;
    my $mailbox_size;

    #--------------------------------------------------------------------------------
    # Figure out timezone offsets, it would be better to determine this automatically
    #--------------------------------------------------------------------------------
    my $local_offset;

    if ($tz_offset) {
        my ( $tz_sign, $tz_hour, $tz_minute ) =
          $tz_offset =~ /(\S)(\d+)(\d\d)$/;
        $local_offset = ( $tz_hour * 60 * 60 ) + ( $tz_minute * 60 );
        $local_offset = -1 * $local_offset if ( $tz_sign eq "-" );
    }
    else {
        $local_offset = tz_local_offset;
    }

    my $isdst;
    my $time = time();
    $isdst = ( localtime($time) )[8];
    my $offsethours = $local_offset / 3600;
    print "TimeZone GMT Offset is $offsethours hours" unless ( defined $quiet );
    print " (Daylight Savings Time)" if ( $isdst and !defined $quiet );
    print ".\n" unless ( defined $quiet );

    print "Connecting to IMAP account $account" unless ( defined $quiet );
    print " over SSL" if ( $ssl and !( defined $quiet ) );
    print "..." unless ( defined $quiet );
    print "s=$server, p=$port, a=$account, pw=$password, size=$size\n"
      if $debug;

    # Connect to the IMAP server via SSL
    my $socket;
    if ($ssl) {
        $socket = IO::Socket::SSL->new(
            PeerAddr => $server,
            PeerPort => $port,
        );
        if ( !$socket ) {
            print "Unable to set up SSL socket $@\n";
            return;
        }
    }
    else {
        $socket = IO::Socket::INET->new(
            PeerAddr => $server,
            PeerPort => $port,
        );
        if ( !$socket ) {
            print "Unable to set up socket $@\n";
            return;
        }
    }

    # Build up a client attached to the SSL socket.
    # Login is automatic as usual when we provide User and Password
    my $client;
    unless (
        $client = Mail::IMAPClient->new(
            Socket   => $socket,
            User     => $account,
            Password => $password,
        )
      )
    {
        print "Unable to connect to IMAP Server $@\n";
        return;
    }

    # Do something just to see that it's all ok
    if ( $client->IsAuthenticated() ) {
        print "Authenticated\n" unless ( defined $quiet );

        $mailbox_size = $client->quota_usage;    #quota method shows size
        $mailbox_size = $mailbox_size * 1024
          if ( defined $mailbox_size );          #make it into bytes

        $client->Peek($peek);

        print "Checking $inbox for messages newer than $age minutes...\n"
          unless ( defined $quiet );
        $client->select($inbox);
        my @msgs;
        $message_count = $client->message_count;

        #poll looks at messages from the last 24 hours to parse.
        my $select_time = $time - 24 * 60 * 60;    #get two days worth of mail
        @msgs = $client->sentsince($select_time);

        my %email_addresses;
        my %email_names;
        my $uid;

        #print "Scanning message set...\n" unless (defined $quiet);
        foreach my $msgid (@msgs) {
            my $date = $client->internaldate($msgid);
            print "#" if $debug;
            unless ( defined $date ) {
                print "Cannot get date of message $msgid!\n";
                next;
            }
            next
              if ( $age and !_check_age( $date, $local_offset, $isdst, $age ) );

            #check_age($date);
            $processed_count++;
            my $from = $client->get_header( $msgid, "From" );
            my $to   = $client->get_header( $msgid, "To" );
            my $cc   = "";
            $cc = $client->get_header( $msgid, "CC" );
            my $subject = "<No Subject>";
            $subject = $client->get_header( $msgid, "Subject" );
            my $msgdate = $client->get_header( $msgid, "Date" );
            $from =~ s/\"//g;

            if ( $from =~ m/\=\?([0-9A-Za-z\-_]+)\?.\?.*\?\=/ ) {
                my $enc_check = find_encoding($1);
                if ($enc_check) {
                    print
                      "Unicode $1 detected. Decoding MIME-Header 'from' from $from to "
                      if $debug;
                    $from = decode( "MIME-Header", $from );
                    print "$from.\n" if $debug;
                }
                else {
                    print
                      "WARNING: Unknown unicode detected $1 for 'from' $from\n";
                }
            }

            if ( $to =~ m/\=\?([0-9A-Za-z\-_]+)\?.\?.*\?\=/ ) {
                my $enc_check = find_encoding($1);
                if ($enc_check) {
                    print
                      "Unicode $1 detected. Decoding MIME-Header 'to' from $to to "
                      if $debug;
                    $to = decode( "MIME-Header", $to );
                    print "$to.\n" if $debug;
                }
                else {
                    print "WARNING: Unknown unicode detected $1 for 'to' $to\n";
                }
            }

            if ( $cc =~ m/\=\?([0-9A-Za-z\-_]+)\?.\?.*\?\=/ ) {
                my $enc_check = find_encoding($1);
                if ($enc_check) {
                    print
                      "Unicode $1 detected. Decoding MIME-Header 'cc' from $cc to "
                      if $debug;
                    $cc = decode( "MIME-Header", $cc );
                    print "$cc.\n" if $debug;
                }
                else {
                    print "WARNING: Unknown unicode detected $1 for 'cc' $cc\n";
                }
            }

            if ( $subject =~ m/\=\?([0-9A-Za-z\-_]+)\?.\?.*\?\=/ ) {
                my $enc_check = find_encoding($1);
                if ($enc_check) {
                    print
                      "Unicode $1 detected. Decoding MIME-Header 'subject' from $subject to "
                      if $debug;
                    $subject = decode( "MIME-Header", $subject );
                    print "$subject.\n" if $debug;
                }
                else {
                    print
                      "WARNING: Unknown unicode detected $1 for 'subject' $subject\n";
                }
            }

            #	decode("MIME-Header", $from) if ($from =~ m/=\?/);
            $email_addresses{$from}++;
            my $name = $from;
            $name =~ s/\<.*\>//g;
            $name = $from if !$name;
            $name =~ s/\<|>//g;
            $name =~ s/\s$//g;
            $email_names{$name}++;

            my $body;
            if ($size) {
                $body = $client->bodypart_string( $msgid, 1, $size );
            }
            else {
                $body = $client->body_string($msgid);
                $body = $client->body_string($msgid)
                  unless ( defined $body );    #try again for large messages
            }
            unless ( defined $body ) {
                print "Cannot download body for message $msgid!\n";
                $body = "Unable to download message";
            }
            push( @{ $msgdata{date} }, $msgdate );

            #push(@{$msgdata{received}},  $date_received);
            push( @{ $msgdata{to} }, $to );
            push( @{ $msgdata{cc} }, $cc );

            #push(@{$msgdata{replyto}},   $replyto);
            #push(@{$msgdata{sender}},    $sender);
            push( @{ $msgdata{from} },      $from );
            push( @{ $msgdata{from_name} }, $name );
            push( @{ $msgdata{subject} },   $subject );

            #push(@{$msgdata{header}},    $header);
            push( @{ $msgdata{body} }, $body );

            #push(@{$msgdata{number}},    $msgnum);
            print "from=$from, date=$date, to=$to\n" if $debug;
            print "subject = $subject\n"             if $debug;
            print "body = $body"                     if $debug;
            $uid = $msgid;

        }
        print "Last UID is $uid\n" if ( defined $uid and ( !defined $quiet ) );

        $unread_count = $client->unseen_count;
        $client->logout();

    }
    else {
        print "Could not Authenticate!\n";
        $client->logout();
        return;
    }

    return ( $message_count, $mailbox_size, $unread_count, \%msgdata );
}

sub main::get_imap_folders {

    my %parms     = @_;
    my $account   = $parms{gmail_account};
    my $debug     = $parms{debug};
    my $password  = $parms{password};
    my $server    = $parms{server};
    my $port      = $parms{port};
    my $quiet     = $parms{quiet};
    my $mhaccount = $parms{account};

    #$server  = $main::config_parms{"net_mail_${mhaccount}_server"}  unless $server;
    $server = 'imap.gmail.com';    #  unless $server;

    #$port    = $main::config_parms{"net_mail_${mhaccount}_server_send_port"};
    $port = 993 unless $port;

    if ($mhaccount) {
        $account  = $main::config_parms{"net_mail_${mhaccount}_user"};
        $password = $main::config_parms{"net_mail_${mhaccount}_password"};
    }

    my @folders;

    print "Connecting to gmail account $account..." unless ( defined $quiet );

    #-------- code from perlmonks
    # Connect to the IMAP server via SSL
    my $socket;
    unless (
        $socket = IO::Socket::SSL->new(
            PeerAddr => $server,
            PeerPort => $port,
        )
      )
    {
        print "Unable to set up socket $@\n";
        return;
    }

    # Build up a client attached to the SSL socket.
    # Login is automatic as usual when we provide User and Password
    my $client;
    unless (
        $client = Mail::IMAPClient->new(
            Socket   => $socket,
            User     => $account,
            Password => $password,
        )
      )
    {
        print "Unable to connect to IMAP Server $@\n";
        return;
    }

    # Do something just to see that it's all ok
    if ( $client->IsAuthenticated() ) {
        print "Authenticated\n" unless ( defined $quiet );

        @folders = $client->folders();
        $client->logout();

    }
    else {
        print "Could not Authenticate!\n";
        $client->logout();
        return;
    }

    return @folders;
}

sub _check_age {

    my ( $internaldate, $offset, $dst, $age ) = @_;

    my %month;
    my $epochtime;
    my $time        = time();
    my $dst_disable = 0;
    $dst_disable = $main::config_parms{"imap_dst_fix"}
      if ( defined $main::config_parms{"imap_dst_fix"} );

    $month{jan} = 1;
    $month{feb} = 2;
    $month{mar} = 3;
    $month{apr} = 4;
    $month{may} = 5;
    $month{jun} = 6;
    $month{jul} = 7;
    $month{aug} = 8;
    $month{sep} = 9;
    $month{oct} = 10;
    $month{nov} = 11;
    $month{dec} = 12;

    #rfc format
    #my ($day, $mon, $year, $hour, $min, $sec,$tz) = $rfc2060_date =~ /(\d+)\s+(\S+)\s+(\d\d\d\d)\s+(\d+):(\d+):(\d+)\s+(\S+)/;
    #int format
    my ( $day, $mon, $year, $hour, $min, $sec, $tz ) =
      $internaldate =~ /^(\d+)-(\S+)-(\d\d\d\d)\s+(\d+):(\d+):(\d+)\s+(\S+)/;

    my $monnum = $month{ lc $mon } - 1;
    $year = $year - 1900;
    $epochtime = mktime( $sec, $min, $hour, $day, $monnum, $year );

    #print "db: imap_utils.pl: time=$time, epochtime=$epochtime";

    $epochtime = $epochtime - 3600 if ( $dst and !$dst_disable );
    $epochtime = $epochtime + $offset;

    #my $diff = ($time - $epochtime);
    #print ",epochtime after offset=$epochtime, diff=$diff\n";

    my $return = ( ( $time - $epochtime ) <= ( $age * 60 ) );

    #print "db: imap_utils.pl: diff=$diff, return=$return\n";
    return $return;
}

1;
