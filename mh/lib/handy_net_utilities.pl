#---------------------------------------------------------------------------
#  File:
#      handy_net_utilities.pl
#  Description:
#      Handy network utilities of all shapes and sizes
#  Author:
#      Bruce Winter    winter@isl.net  http://www.isl.net/~winter
#  Latest version:
#      http://www.isl.net/~winter/house/programs
#  Change log:
#    11/27/98  Created.
#
#---------------------------------------------------------------------------

package handy_net_utilities;
use strict;

                                # These are useful for calling from user code directly
use LWP::Simple; 
use my_Formatter;               # This one allows for tables
use HTML::FormatText;
use HTML::Parse;

                                # Translate URL encoded data
sub main::html_unescape {
    my $todecode = shift;
    $todecode =~ tr/+/ /;
    $todecode =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
    return $todecode;
}
                                # Checking registry keys is fast!  1 ms per call (1000 calls -> 1 second)
                                #   print "Time used: ", timestr(timethis(1000, '&net_connect_check')), "\n";
                                #   Call to dun::checkconnect took 100 ms (100 calls -> 10 seconds)
                                # Could use dun if we checked only once per second?
my ($prev_time, $prev_state);
sub main::net_connect_check {
    
    return 1 if lc($main::config_parms{net_connect}) eq 'persistent';

                                # We don't need to check this more than once a second
    return $prev_state if ($prev_time == time);
    $prev_time = time;
#   return &Win32::DUN::CheckConnect;

                                # Windows NT does not appeart to store this (at least a reg diff didn't show much)
                                # Windows 95/98
    my $status = &main::registry_get('HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\RemoteAccess', 'Remote Connection');
#   print "db s=", unpack('H8', $status), ".\n";
    if (unpack('H8', $status) eq '01000000') {
#       print "Internet connection found\n";
        return $prev_state = 1;
    }
    else {
#       print "No internet connection found\n";
        return $prev_state = 0;
    }
}

sub main::net_domain_name {
    my ($address) = @_;
    my $domain_name;

                                # Allow for port name to be used.
    $address = $main::Socket_Ports{$address}{client_ip_address} if $main::Socket_Ports{$address}{client_ip_address};
    
                                # Use a DNS server to find the domain name
    if ($main::DNS_resolver) {
        print "Searching for Domain Name of $address\n";
        my $result = $main::DNS_resolver->search($address);
        if ($result) {
            my $answer = ($result->answer)[0]->string;
                                # answer string looks like this:  
                                #  33.18.146.204.in-addr.arpa. 36279 IN PTR www.ibm.com. 
            print "  DNS Results: $answer\n";
            $domain_name = (split(' ', $answer))[4];
        }
    }
                                # If no domain name is found, use the IP address
    $domain_name = $address unless $domain_name;

    my @domain_name  = split('\.', $domain_name); 
    my $domain_name2 = $domain_name[-2]; 
    print "ip=$address dn=$domain_name dn2=$domain_name2\n" if $main::config_parms{debug} eq 'net';
    return wantarray ? ($domain_name, $domain_name2) : $domain_name;
}


sub main::net_ftp {
    my %parms = @_;

    my $server      = $parms{server};
    my $user        = $parms{user};
    my $password    = $parms{password};
    my $dir         = $parms{dir};
    my $file        = $parms{file};
    my $file_remote = $parms{file_remote};
    $file_remote = $file unless $file_remote;
    my $command     = $parms{command};

    $server   = $main::config_parms{net_www_server} unless $server;
    $user     = $main::config_parms{net_www_user} unless $user;
    $password = $main::config_parms{net_www_password} unless $password;
    $dir      = $main::config_parms{net_www_dir} unless $dir;

    print "net_ftp error: 'server'   parm missing (check net_www_server   in mh.ini)\n" unless $server;
    print "net_ftp error: 'user'     parm missing (check net_www_user     in mh.ini)\n" unless $user;
    print "net_ftp error: 'password' parm missing (check net_www_password in mh.ini)\n" unless $password;

    return unless $server and $user and $password;

    print "Logging into web server $server...\n";
        
    my $ftp;
    unless ($ftp = Net::FTP->new($server)) {
        print "Unable to connect to ftp server $server: $@\n";
        return "failed on connect";
    }
    unless ($ftp->login($user, $password)) {
        print "Unable to login to $server as $user: $@\n";
        return "failed on login";
    }        
    unless ($ftp->cwd($dir)) {
        print "Unable to chdir to $dir on ftp server $server: $@\n";
        return "failed on change dir";
    }
    if ($command eq 'put') {
        unless ($ftp->put($file, $file_remote)) {
            print " \x07Unable to put file $file into $server: $@\n";
            return "failed on put";
        }
    }
    elsif ($command eq 'get') {
        unless ($ftp->get($file_remote, $file)) {
            print " \x07Unable to get file $file_remote from $server: $@\n";
            return "failed on put";
        }
    }
    elsif ($command eq 'delete') {
        unless ($ftp->delete($file_remote)) {
            print " \x07Unable to delete file $file_remote from $server: $@\n";
            return "failed on delete";
        }
    }
    else {
        return "bad ftp command: $command";
    }

    print join("\n", $ftp->dir($file));
    $ftp->quit;
    print "File $file has been uploaded\n";
    return "was successful";
}

sub main::net_mail_send {
    my %parms = @_;
    my ($from, $to, $subject, $text, $server, $smtp, $account);

    $server  = $parms{server};
    $from    = $parms{from};
    $to      = $parms{to};
    $subject = $parms{subject};
    $account = $parms{account};

    $account = $main::config_parms{net_mail_send_account} unless $server;
    $server  = $main::config_parms{"net_mail_${account}_server"}  unless $server;
    $from    = $main::config_parms{"net_mail_${account}_address"} unless $from;
    $to      = $main::config_parms{"net_mail_${account}_address"} unless $to;
    $subject = "Email from Mister House" unless $subject;
    $text    = $parms{text};

    print "net_mail_send error: 'server' parm missing (check net_mail_server in mh.ini)\n" unless $server;
    print "net_mail_send error: 'to' parm missing\n" unless $to;

    return unless $server and $to;

    use Net::SMTP;
    print "Logging into mail server $server to send msg to $to\n";
    unless ($smtp = Net::SMTP->new($server, Timeout => 10, Debug => $parms{debug})) {
        print "Unable to log into mail server $server: $@\n";
        return;
    }
    $smtp->mail($from) if $from;
    $smtp->to($to);
    $smtp->data("Subject: $subject\n", "To: $to\n", "From: $from\n\n", $text);
    $smtp->quit;
    print "Message sent\n";
}

sub main::net_mail_login {
    my %parms = @_;
    my ($user, $password, $server, $pop, $account);

    $user     = $parms{user};
    $password = $parms{password};
    $server   = $parms{server};
    $account  = ($parms{account}) ? "net_mail_" . $parms{account} : "net_mail";
    $user     = $main::config_parms{$account . "_user"} unless $user;
    $password = $main::config_parms{$account . "_password"} unless $password;
    $server   = $main::config_parms{$account . "_server"} unless $server;

    print "net_mail_read error: mh.ini ${account}_user parm is missing\n" unless $user;
    print "net_mail_read error: mh.ini ${account}_password parm is missing\n" unless $password;
    print "net_mail_read error: mh.ini ${account}_server parm is missing\n" unless $server;

    return unless $server and $user and $password;

                                # This will time out in 1-2 seconds, -vs- 30 seconds for pop login
    unless (&main::net_ping($server)) {
        print "Can not ping mail server: $server\n";
        return;
    }

    use Net::POP3;
#   print "Logging into $server\n";
    unless ($pop = Net::POP3->new($server, Timeout => 10, Debug => $parms{debug})) {
        print "Can not open connection to $server: $@\n";
        return;
    }
#   unless ($pop->apop($user, $password)) {   ... avoids plain text password across network by using MD5 ... not installed yet
    my $msgcnt;
    unless (defined ($msgcnt = $pop->login($user, $password))) {
        print "Can not login to $server as $user: $@\n";
        return;
    }

    return $pop;

}

sub main::net_mail_stats {
    my %parms = @_;
    return unless my $pop = &main::net_mail_login(%parms);
    
    my ($msgcnt, $msgsize) = $pop->popstat;
#   print "There are $msgcnt messages in $msgsize bytes on $server\n";

#   my $msglast= $pop->last;
#   print "The last READ message is number $msglast\n";

    return ($msgcnt, $msgsize);
}

sub main::net_mail_count {
    my %parms = @_;
    return unless my $pop = &main::net_mail_login(%parms);
    my ($msgcnt) = $pop->popstat;
    print "$msgcnt messages in mailbox $parms{account}\n";

    return $msgcnt;
}

sub main::net_mail_summary {

    my %parms = @_;
    return unless my $pop = &main::net_mail_login(%parms);
#   print "Getting list of message sizes\n";
#   unless ($messages = $pop->list) {
#   print "Can not get list of messages: $!\n";
#   return;
#   }

    $parms{first}  = 1             unless $parms{first};
    ($parms{last}) = $pop->popstat unless $parms{last};

    my %msgdata;
    foreach my $msgnum ($parms{first} .. $parms{last}) {
        print "getting msg $msgnum\n" if $main::config_parms{debug} eq 'net';
        my $msg_ptr = $pop->top($msgnum, 15); # The first 15 records should include some of the body text
        my ($date, $from, $from_name, $to, $subject, $header, $header_flag, $body);
        $header_flag = 1;
        for (@$msg_ptr) {
            if ($header_flag) {
                $date    = $1 if !$date    and /Date:(.+)/;
                $from    = $1 if !$from    and /From:(.+)/;
                $to      = $1 if !$to      and /To:(.+)/;
                $subject = $1 if !$subject and /Subject:(.+)/;
                $header .= $_;
                $header_flag = 0 if /^ *$/;
            }
            else {
                $body .= $_;
            }
        }
                                # Process 'from' into speakable name
        ($from_name) = $from =~ /\((.+)\)/;
        ($from_name) = $from =~ / *(.+?) *</ unless $from_name;
        ($from_name) = $from =~ / *(\S+) *@/ unless $from_name; 
        $from_name = $from unless $from_name; # Sometimes @ is carried onto next record
        $from_name =~ tr/_/ /;
#       $from_name =~ tr/"//;
        $from_name =~ s/\"//g;  # "first last"
        $from_name = "$2 $1" if $from_name =~ /(\S+), +(\S+)/; # last, first
#       $from_name =~ s/ (\S)\. / $1 /;  # Drop the "." after middle initial abreviation.
        print "Warning, no From name found: from=$from, header=$header\n" unless $from_name;

#       print "db from_name=$from_name from=$from\n";
        print "msgnum=$msgnum  date=$date from=$from to=$to subject=$subject\n" if $main::config_parms{debug} eq 'net';
        push(@{$msgdata{date}}, $date);
        push(@{$msgdata{to}},   $to);
        push(@{$msgdata{from}}, $from);
        push(@{$msgdata{from_name}}, $from_name);
        push(@{$msgdata{subject}},   $subject);
        push(@{$msgdata{header}},    $header);
        push(@{$msgdata{body}},      $body);
        push(@{$msgdata{number}},    $msgnum);
    }

    return \%msgdata;
}

sub main::net_mail_read {

    my %parms = @_;
    return unless my $pop = &main::net_mail_login(%parms);

    $parms{first}  = 1             unless $parms{first};
    ($parms{last}) = $pop->popstat unless $parms{last};

    my @msgdata;
    foreach my $msgnum ($parms{first} .. $parms{last}) {
        print "getting msg $msgnum\n";
        my $msg_ptr = $pop->get($msgnum);
        $msgdata[$msgnum] = $msg_ptr;
#       print "msg=@{$msgdata[$msgnum]}\n";
    }

    return \@msgdata;
}

sub main::net_ping {
    my ($host, $protocol) = @_;
    use Net::Ping;
                                # icmp requires root
    $protocol = $main::config_parms{ping_protocol};
    return 1 if $protocol eq 'none';
    $protocol = ($> ? 'tcp' : 'icmp') unless $protocol;
    my $p = Net::Ping->new($protocol);
    return $p->ping($host);
}

1;

#
# $Log$
# Revision 1.1  2000/01/19 14:01:01  winter
# Initial revision
#
# Revision 1.13  1999/12/13 00:03:41  winter
# - store body text in email read
#
# Revision 1.12  1999/07/21 21:15:02  winter
# *** empty log message ***
#
# Revision 1.11  1999/07/05 22:35:19  winter
# - make net_domain_name smarter
#
# Revision 1.10  1999/06/27 20:15:01  winter
# - add html_unescape
#
# Revision 1.9  1999/06/20 22:33:16  winter
# - add net_domain_name function
#
# Revision 1.8  1999/05/30 21:09:59  winter
# - minor changes
#
# Revision 1.7  1999/03/28 00:33:56  winter
# - add Ping
#
# Revision 1.6  1999/03/21 17:34:55  winter
# - take out some debug
#
# Revision 1.5  1999/03/12 04:31:11  winter
# - allow for account parm in mail function
#
# Revision 1.4  1999/02/01 00:07:48  winter
# - untabify.  use net_connect, not net_connections
#
# Revision 1.3  1999/01/30 19:54:45  winter
# - add net_ftp
#
# Revision 1.2  1999/01/23 16:33:57  winter
# - untabbify
#
# Revision 1.1  1998/12/08 02:24:26  winter
# - created
#
#
