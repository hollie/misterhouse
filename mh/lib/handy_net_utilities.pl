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

                                # Make sure we override any local Formatter with our modified one
                                #   - the default one does not look into tables
#se my_Formatter;               #   - Must be in lib/site/HTML dir to work :(
use HTML::FormatText;
                                # These are useful for calling from user code directly
use LWP::Simple;
use HTML::Parse;


#require "$main::Pgm_Root/lib/site/HTML/Formatter.pm";

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
                                # Don't know how to check on non-windows OS
my ($prev_time, $prev_state);
sub main::net_connect_check {

    return 1 if  !$main::OS_win or lc($main::config_parms{net_connect}) eq 'persistent';

                                # We don't need to check this more than once a second
    return $prev_state if ($prev_time == time);
    $prev_time = time;
#   return &Win32::DUN::CheckConnect;

                                # Windows NT does not seem to store this in a handy spot, like win98
                                #  - Jim Maloney found this key, but we think it is unique to his machine :(
#   my $status = &main::registry_get('HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{C69045CE-7095-4A59-8837-FC8AA04F49BB}', 'NTEContextList');
#   if (unpack('H8', $status) > 0) {
#       print "Internet connection found\n";
#       return $prev_state = 1;
#   }

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
        print "Searching for Domain Name of $address ...";
        my $time = time;
        my $result = $main::DNS_resolver->search($address);
        print " took ", time - $time, " seconds\n";
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
    $file_remote    = $file unless $file_remote;
    my $command     = $parms{command};
    my $type        = $parms{type};

    $server   = $main::config_parms{net_www_server} unless $server;
    $user     = $main::config_parms{net_www_user} unless $user;
    $password = $main::config_parms{net_www_password} unless $password;
    $dir      = $main::config_parms{net_www_dir} unless $dir;

    print "net_ftp error: 'server'   parm missing (check net_www_server   in mh.ini)\n" unless $server;
    print "net_ftp error: 'user'     parm missing (check net_www_user     in mh.ini)\n" unless $user;
    print "net_ftp error: 'password' parm missing (check net_www_password in mh.ini)\n" unless $password;

    return unless $server and $user and $password;

    print "Logging into web server $server as $user...\n";

    my $ftp;
    unless ($ftp = Net::FTP->new($server)) {
        print "Unable to connect to ftp server $server: $@\n";
        return "failed on connect";
    }
    unless ($ftp->login($user, $password)) {
        print "Unable to login to $server as $user: $@\n";
        return "failed on login";
    }

    print " - doing a $type $command local=$file remote=$file_remote\n";

    unless ($ftp->cwd($dir)) {
        print "Unable to chdir to $dir on ftp server $server: $@\n";
        return "failed on change dir";
    }
    if ($type eq 'binary') {
        unless ($ftp->binary()) {
            print " \x07Unable to set bin mode on $server: $@\n";
            return "failed on binary";
        }
    }
    if ($command eq 'put') {
        unless ($ftp->put($file, $file_remote)) {
            print " \x07Unable to put file $file into $server as $file_remote: $@\n";
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
        print "Bad ftp command: $command\n";
        return "bad ftp command: $command";
    }

    print join("\n", $ftp->dir($file_remote)) if $command eq 'put';
    $ftp->quit;
    return "was successful";
}

my ($aim_connection, $jabber_connection);


sub main::net_jabber_signon {
    return if $jabber_connection;  # Already signed on

    my ($name, $password, $server, $resource, $port) = @_;

    $server   = 'jabber.com' unless $server;
    $port     = 5222         unless $port;
    $resource = 'none'       unless $resource;

    print "Logging onto $server:$port with name=$name resource=$resource\n";

    eval 'use Net::Jabber';
    $jabber_connection = new Net::Jabber::Client;
    unless ($jabber_connection->Connect(hostname => $server, port => $port)) {
        print "  - Error:  Jabber server is down or connection was not allowed. jc=$jabber_connection\n";
        return;
    }

    $jabber_connection->SetCallBacks(message  => \&jabber::InMessage,
                                     presence => \&jabber::InPresence,
                                     iq       => \&jabber::InIQ);

    print "  - Sending username\n";
    $jabber_connection->Connect();
    my @result = $jabber_connection->AuthSend(username => $name,
                                              password => $password,
                                              resource => $resource);
    if ($result[0] ne "ok") {
        print "  - Error: Jabber Authorization failed: $result[0] - $result[1]\n";
        return;
    }

# Not sure we need this ... perl2exe mh.exe failed on GetItems Query
#    print "  - Getting Roster to tell server to send presence info\n";
#    $jabber_connection->RosterGet();

    print "  - Sending presence to tell world that we are logged in\n";
    $jabber_connection->PresenceSend();
    
    &main::MainLoop_post_add_hook( \&jabber::process, 1 );

}

sub jabber::process {
    return unless $main::New_Second;
    if (!defined $jabber_connection or !defined $jabber_connection->Process(0)) {
        print "\nJabber connection died\n";
        undef $jabber_connection;
        &main::MainLoop_post_drop_hook( \&jabber::process, 1 );
    }
}

sub jabber::InMessage {
    my $message  = new Net::Jabber::Message(@_);
#   my $type     = $message->GetType();
    my $from     = $message->GetFrom();
#   my $to       = $message->GetTo();
    my $resource = $message->GetResource();
#   my $subject  = $message->GetSubject();
    my $body     = $message->GetBody();
    &main::display("$main::Time_Date $from ($resource)\nMessage:  " . $body, 0, "Jabber Message from $from", 'fixed');
}


sub jabber::InIQ {
    my $iq    = new Net::Jabber::IQ(@_);
    my $from  = $iq->GetFrom();
    my $type  = $iq->GetType();
    my $query = $iq->GetQuery();
    my $xmlns = $query->GetXMLNS();
    &main::display("$main::Time_Date $from\nIQ $query:  " . $xmlns, 0, "Jabber IQ from $from", 'fixed');
}

sub jabber::InPresence {
    my $presence = new Net::Jabber::Presence(@_);
    my $from     = $presence->GetFrom();
    my $type     = $presence->GetType();
    my $status   = $presence->GetStatus();
    &main::display("$main::Time_Date $from\nPresence:  " . $status, 0, "Jabber Presence from $from", 'fixed');
#   print $presence->GetXML(),"\n";
}

sub main::net_jabber_send {
    my %parms = @_;

    my ($from, $password, $to, $text, $file);

    $from     = $parms{from};
    $password = $parms{password};
    $to       = $parms{to};

    $from     = $main::config_parms{net_jabber_name}      unless $from;
    $password = $main::config_parms{net_jabber_password}  unless $password;
    $to       = $main::config_parms{net_jabber_name_send} unless $to;

    unless ($from and $password and $to) {
        print "\nError, net_jabber_send called with a missing argument:  from=$from to=$to password=$password\n";
        return;
    }
                                # This will take a few seconds to connect the first time
    &main::net_jabber_signon($from, $password);
    return unless $jabber_connection;

    print "Sending jabber message to $to\n";

    $text  = $parms{text};
    $text .= "\n" . &main::file_read($parms{file}) if $parms{file};

    $jabber_connection -> MessageSend(to   => $to, body => $text);
    $jabber_connection -> Process(0);

}


sub main::net_im_signon {
    my ($name, $password) = @_;
    return if $aim_connection;  # Already signed on

    print "Logging onto AIM with name=$name ... ";

    eval 'use Net::AIM';
    my $aim = new Net::AIM;

    unless ($aim_connection = $aim->newconn(Screenname => $name, Password   => $password)) {
        print "Error, can not create AIM connection object\n";
    }
                                # Logon occurs here
                                # Not sure how to test for successful logon
    $aim->do_one_loop();
}


sub main::net_im_send {
    my %parms = @_;

    my ($from, $password, $to, $text, $file);

    $from     = $parms{from};
    $password = $parms{password};
    $to       = $parms{to};

    $from     = $main::config_parms{net_aim_name}      unless $from;
    $password = $main::config_parms{net_aim_password}  unless $password;
    $to       = $main::config_parms{net_aim_name_send} unless $to;

    unless ($from and $password and $to) {
        print "\nError, net_im_send called with a missing argument:  from=$from to=$to password=$password\n";
        return;
    }
                                # This will take a few seconds to connect the first time
    &main::net_im_signon($from, $password);
    return unless $aim_connection;

    print "Sending aim message to $to ";

    $text  = $parms{text};
    $text .= "\n" . &main::file_read($parms{file}) if $parms{file};

    $aim_connection -> send_im($to, $text);

}


sub main::net_mail_send_old {
    my %parms = @_;
    my ($from, $to, $subject, $text, $server, $smtp, $account);

    $server  = $parms{server};
    $from    = $parms{from};
    $to      = $parms{to};
    $subject = $parms{subject};
    $account = $parms{account};

    $account = $main::config_parms{net_mail_send_account}         unless $server;
    $server  = $main::config_parms{"net_mail_${account}_server"}  unless $server;
    $from    = $main::config_parms{"net_mail_${account}_address"} unless $from;
    $to      = $main::config_parms{"net_mail_${account}_address"} unless $to;
    $subject = "Email from Mister House"                          unless $subject;
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

sub main::net_mail_send {
    my %parms = @_;
    my ($from, $to, $subject, $text, $server, $smtp, $account, $mime, $baseref, $file, $filename);

    $server  = $parms{server};
    $account = $parms{account};
    $from    = $parms{from};
    $to      = $parms{to};
    $subject = $parms{subject};
    $mime    = $parms{mime};
    $baseref = $parms{baseref};
    $text    = $parms{text};
    $file    = $parms{file};
    $filename= $parms{filename};

    $account = $main::config_parms{net_mail_send_account}         unless $server;
    $server  = $main::config_parms{"net_mail_${account}_server_send"}  unless $server;
    $server  = $main::config_parms{"net_mail_${account}_server"}  unless $server;
    $server = 'localhost'                                         unless $server;
    $from    = $main::config_parms{"net_mail_${account}_address"} unless $from;
    $to      = $main::config_parms{"net_mail_${account}_address"} unless $to;
    $subject = "Email from Mister House"                          unless $subject;
    $baseref = 'localhost'                                        unless $baseref;

    $text .= &main::file_read($file) if $file;

    print "Sending mail with $account, from $from to $to\n";

    print "net_mail_send error: 'server' parm missing (check net_mail_server in mh.ini)\n" unless $server;
    print "net_mail_send error: 'to' parm missing\n" unless $to;

    return unless $server and $to;

    if ($mime) {
        eval "use MIME::Lite";
        if ($@) {
            print "Error in use MIME::Lite: $@\n";
            print "To use email, you need to install MIME::Lite\n";
            print " - linux: perl -MCPAN -eshell    install MIME::Lite\n";
            print " - windows: ppm -install MIME-Lite\n";
            return;
        }

                                # Modify the html so it has a BASE HREF and the links work in a mail reader
        $text =~ s|<HEAD>|<HEAD>\n<BASE HREF="http://$parms{baseref}">|i;

        ($filename) = $file =~ /([^\\\/]+)$/ unless $filename;

        my $message = MIME::Lite->new(From => $from,
                                      Subject => $subject,
                                      Type  => 'text/html',
                                      Encoding => '8bit',
                                      Data => $text,
#                                     Path => $file,
                                      Filename => $filename,
                                      To => $to);
        if ($^O eq "MSWin32") {
            print "Using built in smtp code with server $server\n";
            MIME::Lite->send('smtp', $server, Timeout => 20);
        }
        print "Sending report to $to\n";
        $message->send;
    }
    else {
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
    print "$msgcnt messages in mailbox $parms{account}\n" unless defined $parms{debug} and $parms{debug} == 0;

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
#               chomp;
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
# Revision 1.22  2000/10/01 23:29:40  winter
# - 2.29 release
#
# Revision 1.21  2000/09/09 21:19:11  winter
# - 2.28 release
#
# Revision 1.20  2000/08/19 01:25:08  winter
# - 2.27 release
#
# Revision 1.19  2000/06/24 22:10:55  winter
# - 2.22 release.  Changes to read_table, tk_*, tie_* functions, and hook_ code
#
# Revision 1.18  2000/05/27 16:40:10  winter
# - 2.20 release
#
# Revision 1.17  2000/04/09 18:03:19  winter
# - 2.13 release
#
# Revision 1.16  2000/03/10 04:09:01  winter
# - Add Ibutton support and more web changes
#
# Revision 1.15  2000/02/12 06:11:37  winter
# - commit lots of changes, in preperation for mh release 2.0
#
# Revision 1.14  2000/01/27 13:45:36  winter
# - update version number
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
