#---------------------------------------------------------------------------
#  File:
#      handy_net_utilities.pl
#  Description:
#      Handy network utilities of all shapes and sizes
#  Author:
#      Bruce Winter    bruce@misterhouse.net
#  Latest version:
#      http://misterhouse.net/mh/lib/handy_net_utilities.pl
#  Change log:
#    11/27/98  Created.
#
#---------------------------------------------------------------------------

package handy_net_utilities;
use strict;

                                # Make sure we override any local Formatter with our modified one
                                #   - the default one does not look into tables
                                #   - This is a mess.  Really need to have mh libs first, not last.
                                #   - The latest code DOES tables, but have no spaces between elements
                                #     which is needed by stuff like internet_iridium.pl  :(
#BEGIN { 
#    require './../lib/site/HTML/FormatText.pm';
#    local $SIG{__WARN__} = sub { return if $_[0] =~ /redefined at/ };
#    require './../lib/site/HTML/Parse.pm';    # Without these we get HTML::Parser errors ... not sure why
#}
                                # These are useful for calling from user code directly
use HTML::FormatText;
use HTML::Parse;
use LWP::Simple;


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

    return 1 if lc( $main::config_parms{net_connect} ) eq 'persistent';

                         # We don't need to check this more than once a second
    return $prev_state if ( $prev_time == time );
    $prev_time = time;

                         # Linux
    if ( $^O eq "linux" ) {
        my $if = lc($main::config_parms{net_connect_if});
        if ( $if eq "" ) { 
            print "mh.ini parm net_connect and net_connect_if is not defined.  net connection assumed.\n";
            return $prev_state = 1;
        }
        open (PROC,"/proc/net/dev");
        while (<PROC>) {
            if ( $_ =~ /$if/ ) {
                return $prev_state = 1;
            }
        }  
        return $prev_state = 0;
    }

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

my ($DNS_resolver_request, $DNS_resolver_address, $DNS_resolver_requester, $DNS_resolver_time, %DNS_cache);

                                # This is the good, background way
sub main::net_domain_name_start {
    ($DNS_resolver_requester, $DNS_resolver_address) = @_;

                                # Allow for port name to be used.
    $DNS_resolver_address = $main::Socket_Ports{$DNS_resolver_address}{client_ip_address}
                         if $main::Socket_Ports{$DNS_resolver_address} and
                            $main::Socket_Ports{$DNS_resolver_address}{client_ip_address};

    $DNS_cache{$DNS_resolver_address} = 'local' if &main::is_local_address($DNS_resolver_address);

                                # Cache the data.  If cached, return results immediately,
                                # in addition to triggering net_domain_name_done
    if ($DNS_cache{$DNS_resolver_address}) {
        $DNS_resolver_request++;
        $DNS_resolver_time = time - 100; # Pretend we time out, so we also respond on next _done check
                                # If cached, return data
        return &net_domain_name_parse2($DNS_cache{$DNS_resolver_address});
    }
    elsif ($main::DNS_resolver) {
        $DNS_resolver_request = $main::DNS_resolver->bgsend($DNS_resolver_address);
        $DNS_resolver_time = time;
#       print "db $main::Time_Date DNS starting search $main::Time, t=$DNS_resolver_time, a=$DNS_resolver_address\n";
    }
    else {
        $DNS_resolver_request++;
        $DNS_resolver_time = time - 100; # Pretend we time out, so we respond on the next pass
    }
    return;
}

sub main::net_domain_name_done {
    my ($requester) = @_;
    return unless $DNS_resolver_request and $requester eq $DNS_resolver_requester;
#   print "db $DNS_resolver_time, t=$Time r=$requester, r2=$DNS_resolver_requester\n";
    my $result;
    if ($DNS_cache{$DNS_resolver_address}) {
        undef $DNS_resolver_request;
        return &net_domain_name_parse2($DNS_cache{$DNS_resolver_address});
    }
    elsif ((time - $DNS_resolver_time) > 5) {
#       print "db $main::Time_Date DNS ending   search $main::Time, t=$DNS_resolver_time, a=$DNS_resolver_address\n";
        print "DNS search timed out for $DNS_resolver_address\n" if $main::DNS_resolver;
        undef $DNS_resolver_request;
        return;
    }

    return unless $main::DNS_resolver->bgisready($DNS_resolver_request);
    $result = $main::DNS_resolver->bgread($DNS_resolver_request);
    undef $DNS_resolver_request;
    return &net_domain_name_parse($result, $DNS_resolver_address);
}
                                # This is the old, inline way
sub main::net_domain_name {
    my ($address) = @_;
                                # Allow for port name to be used.
    $address = $main::Socket_Ports{$address}{client_ip_address}
            if $main::Socket_Ports{$address} and
               $main::Socket_Ports{$address}{client_ip_address};

    return ('local', 'local') if &main::is_local_address($address);

    if ($DNS_cache{$address}) {
        return &net_domain_name_parse2($DNS_cache{$address});
    }

    my $result;
    if ($main::DNS_resolver) {
        print "Searching for Domain Name of $address ...";
        my $time = time;
        $result = $main::DNS_resolver->search($address);
        print " took ", time - $time, " seconds\n";
    }
    return &net_domain_name_parse($result, $address);
}

sub net_domain_name_parse {
    my ($result, $address) = @_;
                                # If no domain name is found, use the IP address
    my $domain_name = $address;

    if ($result) {
                                # Use PTR, not CNAME records
#232.65.86.63.in-addr.arpa.     13240   IN      CNAME   232.224.65.86.63.in-addr.arpa.
#232.224.65.86.63.in-addr.arpa. 13240   IN      PTR     host232.netwhistle.com.
#           my $answer = ($result->answer)[0];
#           my $string = $answer->string if $answer;
        my $string = '';
        for my $answer ($result->answer) {
            my $temp = $answer->string;
            print "DNS: $address -> $temp\n" if $main::config_parms{debug} eq 'net';
            $string = $temp if $temp =~ /\sPTR\s/;
        }
#   print "db s=$string ip=$DNS_resolver_address\n";
                                # answer string looks like this:
                                #  33.18.146.204.in-addr.arpa. 36279 IN PTR www.ibm.com.
                                #  9.37.208.64.in-addr.arpa.   86400 IN PTR crawler1.googlebot.com.
        $domain_name = (split(' ', $string))[4] if $string;
    }
    $DNS_cache{$address} = $domain_name;
    return &net_domain_name_parse2($domain_name);
}

sub net_domain_name_parse2 {
    my ($domain_name) = @_;
    my @domain_name  = split('\.', $domain_name);
    my $domain_name2 = $domain_name[-2];
    $domain_name2 .= ('.' . $domain_name[-1]) if $domain_name[-1] !~ /(net)|(com)|(org)/;
    print "db dn=$domain_name dn2=$domain_name2\n" if $main::config_parms{debug} eq 'net';
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
    my $passive     = $parms{passive};
    my $timeout     = $parms{timeout};
    $timeout = 20 unless $timeout;

    $server   = $main::config_parms{net_www_server} unless $server;
    $user     = $main::config_parms{net_www_user} unless $user;
    $password = $main::config_parms{net_www_password} unless $password;
    $dir      = $main::config_parms{net_www_dir} unless $dir;
    $passive  = 0 unless $passive;

    print "net_ftp error: 'server'   parm missing (check net_www_server   in mh.ini)\n" unless $server;
    print "net_ftp error: 'user'     parm missing (check net_www_user     in mh.ini)\n" unless $user;
    print "net_ftp error: 'password' parm missing (check net_www_password in mh.ini)\n" unless $password;

    return unless $server and $user and $password;

    print "Logging into web server $server as $user...\n";

    my $ftp;
    unless ($ftp = Net::FTP->new($server, timeout => $timeout, Passive => $passive)) {
        print "Unable to connect to ftp server $server timeout=$timeout passive=$passive: $@\n";
        return "failed on connect";
    }
    unless ($ftp->login($user, $password)) {
        print "Unable to login to $server as $user: $@\n";
        return "failed on login";
    }

    print " - doing a $type $command local=$file remote=$file_remote\n";

    if ($dir) {
        unless ($ftp->cwd($dir)) {
            print "Unable to chdir to $dir on ftp server $server: $@\n";
            return "failed on change dir";
        }
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
    elsif ($command eq 'mkdir') {
        unless ($ftp->mkdir($file_remote)) {
            print " \x07Unable to make dir $file_remote from $server: $@\n";
            return "failed on mkdir";
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

my ($aim_connection, $jabber_connection, $msn_connection, %msn_connections, %msn_queue);


sub main::net_jabber_signon {
    return if $jabber_connection;  # Already signed on

    my ($name, $password, $server, $resource, $port) = @_;

    $name     = $main::config_parms{net_jabber_name}      unless $name;
    $password = $main::config_parms{net_jabber_password}  unless $password;
    $server   = $main::config_parms{net_jabber_server}    unless $server;
    $resource = $main::config_parms{net_jabber_resource}  unless $resource;

    $server   = 'jabber.com' unless $server;
    $port     = 5222         unless $port;
    $resource = 'none'       unless $resource;

    print "Logging onto $server $port with name=$name resource=$resource\n";

    eval 'use Net::Jabber qw (Client)';
    print "Error in Net::Jabber: $@\n" if $@;
    $jabber_connection = new Net::Jabber::Client;
#   $jabber_connection = Net::Jabber::Client->new(debuglevel => 2, debugtime  => 1 , debugfile  =>  "/tmp/jabber.log");

    unless ($jabber_connection->Connect(hostname => $server, port => $port)) {
        print "  - Error:  Jabber server is down or connection was not allowed. jc=$jabber_connection\n";
        undef $jabber_connection;
        return;
    }

    $jabber_connection->SetCallBacks(message  => \&jabber::InMessage,
                                     presence => \&jabber::InPresence,
                                     iq       => \&jabber::InIQ);

    print "  - Sending username\n";
#   $jabber_connection->Connect();
    my @result = $jabber_connection->AuthSend(username => $name,
                                              password => $password,
                                              resource => $resource);
    if ($result[0] ne "ok") {
        print "  - Error: Jabber Authorization failed: $result[0] - $result[1]\n";
        undef $jabber_connection;
        return;
    }

# Not sure we need this ... perl2exe mh.exe failed on GetItems Query
#    print "  - Getting Roster to tell server to send presence info\n";
#    $jabber_connection->RosterGet();

    print "  - Sending presence to tell world that we are logged in\n";
    $jabber_connection->PresenceSend();
    
    &main::MainLoop_post_add_hook( \&jabber::process, 1 );

}

sub main::net_jabber_signoff {
    print "disconnecting from jabber\n";
    undef $jabber_connection;
    &main::MainLoop_post_drop_hook( \&jabber::process, 1 );
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
    my $sid = shift;
    my $message = shift;

#   my $type     = $message->GetType();
    my $from     = $message->GetFrom();
#   my $to       = $message->GetTo();
#   my $resource = $message->GetResource();
#   my $subject  = $message->GetSubject();
    my $body     = $message->GetBody();
#   &main::display("$main::Time_Date $from\nMessage:  " . $body, 0, "Jabber Message from $from", 'fixed');
#   &main::Jabber_Message_hooks($sid, $message, 'jabber');
    &main::Jabber_Message_hooks($from, $body, 'jabber');
}


sub jabber::InIQ {
    my $sid = shift;
    my $iq = shift;
    
    my $from  = $iq->GetFrom();
    my $type  = $iq->GetType();
    my $query = $iq->GetQuery();
    my $xmlns = $query->GetXMLNS();
    &main::display("$main::Time_Date $from\nIQ $query:  " . $xmlns, 0, "Jabber IQ from $from", 'fixed');
    &main::Jabber_IQ_hooks($sid, $iq);
}

sub jabber::InPresence {
    my $sid = shift;
    my $presence = shift;

    my $from     = $presence->GetFrom();
    my $type     = $presence->GetType();
    my $status   = $presence->GetStatus();
#   &main::display("$main::Time_Date $from\nPresence:  " . $status, 0, "Jabber Presence from $from.", 'fixed');
    &main::Jabber_Presence_hooks($from, $status, undef, 'jabber');
#   print $presence->GetXML(),"\n";
}

sub main::net_jabber_send {
    my %parms = @_;

    my ($from, $password, $to, $text, $file, $subject, $server, $resource);

    $from     = $parms{from};
    $password = $parms{password};
    $to       = $parms{to};
    $subject  = $parms{subject};

    $from     = $main::config_parms{net_jabber_name}      unless $from;
    $password = $main::config_parms{net_jabber_password}  unless $password;
    $to       = $main::config_parms{net_jabber_name_send} unless $to;
    $server   = $main::config_parms{net_jabber_server}    unless $server;
    $resource = $main::config_parms{net_jabber_resource}  unless $resource;
    $subject  = "Misterhouse" unless $subject;

    unless ($from and $password and $to) {
        print "\nError, net_jabber_send called with a missing argument:  from=$from to=$to password=$password\n";
        return;
    }
                                # This will take a few seconds to connect the first time
    &main::net_jabber_signon($from, $password, $server, $resource);
    return unless $jabber_connection;

    $text  = $parms{text};
    $text .= "\n" . &main::file_read($parms{file}) if $parms{file};

    print "Sending jabber message to $to: $text\n";

    $jabber_connection -> MessageSend(to   => $to, body => $text, subject => $subject);
    $jabber_connection -> Process(0);

}

sub main::net_msn_signon {
    my ($name, $password) = @_;

    return if $msn_connection;  # Already signed on

    $name     = $main::config_parms{net_msn_name}      unless $name;
    $password = $main::config_parms{net_msn_password}  unless $password;

    print "Logging onto MSN with name=$name ... \n";

    eval 'use MSN';
    if ($@) {
        print "MSN eval error: $@\n";
        return;
    }
    $msn_connection = MSN->new();

                             # Currently does not have a way to verify login??
    $msn_connection->connect($name, $password, '', 
                                     {
                                      Status  => \&MSN::status, 
                                      Answer  => \&MSN::answer, 
                                      Message => \&MSN::message, 
                                      Join    => \&MSN::join }, 0);
#    print "MSN logon error: $main::IM_ERR -> $Net::MSNIM::ERROR_MSGS{$main::IM_ERR} ($main::IM_ERR_ARGS)\n";
#    undef $msn_connection;
#    return;

    &main::MainLoop_post_add_hook( \&MSN::process, 1, $msn_connection, 0);
}

sub main::net_msn_signoff {
    print "disconnecting from msn\n";
    undef $msn_connection;
    &main::MainLoop_post_drop_hook( \&MSN::process, 1 );
}



sub MSN::status {
   my ($self, $username, $newstatus) = @_;
   print "MSN ${username}'s status changed from " . $self->buddystatus($username) . " to $newstatus.\n";
   &main::MSNim_Status_hooks($username, $newstatus, $self->buddystatus($username), 'MSN');
}

sub MSN::message {
   my ($self, $name, $name2, $text) = @_;
   print "MSN Message received: $name, $name2, $text\n";
   &main::MSNim_Message_hooks($name, $text, 'MSN');
   $msn_connections{$name} = $self;
   &MSN::send_queue($name);
}

sub MSN::join {
   my ($self, $username) = @_;
   print "MSN Join: $username\n";
   $msn_connections{$username} = $self;
   &MSN::send_queue($username);
}

sub MSN::answer {
   my ($self, $username) = @_;
   print "MSN Answer:  $username\n";
   $$self->sendmsg("Hello from MisterHouse to $username");
   $msn_connections{$username} = $self;
   &MSN::send_queue($username);
}

sub MSN::send_queue {
    my ($username) = @_;
    return unless  $msn_queue{$username};
    my $connection = $msn_connections{$username};
    my $msg;
    while (defined($msg = shift @{$msn_queue{$username}})) {
        print "MSN sending: $username, $msg\n";
        $$connection->sendmsg($msg);
    }
}

sub main::net_msn_send {
    my %parms = @_;

    my ($from, $password, $to, $text, $file);

    $from     = $parms{from};
    $password = $parms{password};
    $to       = $parms{to};

    $from     = $main::config_parms{net_msn_name}      unless $from;
    $password = $main::config_parms{net_msn_password}  unless $password;
    $to       = $main::config_parms{net_msn_name_send} unless $to;

    unless ($from and $password and $to) {
        print "\nError, net_msn_send called with a missing argument:  from=$from to=$to password=$password\n";
        return;
    }
    print "Sending MSN message to $to\n";
    $text  = $parms{text};
    $text .= "\n" . &main::file_read($parms{file}) if $parms{file};

    unless ($msn_connection) {
        &main::net_msn_signon($from, $password);
                                # Gotta wait until we are logged on until we send the msg
        for (1..40) {
            print ".";
            select undef, undef, undef, .1;
#           &MSN::process($msn_connection, 0);
            $msn_connection->process(0);
        }
    }


                              # Use an existing connection, or create a new one?
    if (my $to_connection = $msn_connections{$to}) {
        $$to_connection -> sendmsg($text);
    }
    else {
        print "Calling MSN user $to\n";
        $msn_connection -> call($to);
        push(@{$msn_queue{$to}}, $text)
    }


}


sub main::net_im_signon {
    my ($name, $password, $pgm) = @_;

    if (lc $pgm eq 'msn') {
        return &main::net_msn_signon($name, $password);
    }
    elsif (lc $pgm eq 'jabber') {
        return &main::net_jabber_signon($name, $password);
    }

    return if $aim_connection;  # Already signed on

    $name     = $main::config_parms{net_aim_name}      unless $name;
    $password = $main::config_parms{net_aim_password}  unless $password;
    my $buddies  = $main::config_parms{net_aim_buddies};

    print "Logging onto AIM with name=$name ... \n";

    eval 'use Net::AOLIM';
    if ($@) {
        print "Net::AOLIM eval error: $@\n";
        return;
    }
    $aim_connection = Net::AOLIM->new("username" => $name, 
                                      "password" => $password,
                                      'login_timeout' => 10,
                                      "callback" => \&aolim::callback,
                                      "allow_srv_settings" => 0 );
    $aim_connection -> add_buddies("friends", $name);

    for (split /,/, $buddies) {
        print "Adding AOL AIM buddy $_\n";
        $aim_connection -> add_buddies("friends", $_);
    }

    unless (defined($aim_connection->signon)) {
        print "AIM logon error: $main::IM_ERR -> $Net::AOLIM::ERROR_MSGS{$main::IM_ERR} ($main::IM_ERR_ARGS)\n";
        undef $aim_connection;
        return;
    }

    &main::MainLoop_post_add_hook( \&aolim::process, 1 );

                                # This is the old way
#    eval 'use Net::AIM';
#    unless ($aim_connection = $aim->newconn(Screenname => $name, Password   => $password)) {
#        print "Error, can not create AIM connection object\n";
#    }
                                # Logon occurs here
                                # Not sure how to test for successful logon
#   $aim->do_one_loop();

}

sub main::net_im_signoff {
    my ($pgm) = @_;
    if (lc $pgm eq 'msn') {
        &main::net_msn_signoff;
    }
    elsif (lc $pgm eq 'jabber') {
        &main::net_jabber_signoff;
    }
    else {
        print "disconnecting from aol im\n";
        undef $aim_connection;
        &main::MainLoop_post_drop_hook( \&aolim::process, 1 );
    }
}

# IM_IN MisterHouse F <HTML><BODY BGCOLOR="#ffffff"><FONT>hi ho</FONT></BODY></HTML>
sub aolim::callback {
    my ($type, $name, $arg, $text) = @_;
#   print "db t=$type, n=$name, a=$arg, t=$text\n";
    if ($type eq 'ERROR') {
        my $error = "$Net::AOLIM::ERROR_MSGS{$name}";
        $error =~ s/\$ERR_ARG/$arg/g;
        print "AOL AIM error: $error\n";
    }
    elsif ($type eq 'IM_IN') {
#       my $time = &main::time_date_stamp(5);
        my $text2 = HTML::FormatText->new(lm => 0, rm => 150)->format(HTML::TreeBuilder->new()->parse($text));
        chomp $text2;
#       &main::display(text => "$name ($time:$main::Second): " . $text2, time => 0, window_name => 'AIM', append => 'top');
        &main::AOLim_Message_hooks($name, $text2, 'AOL');
    }
    elsif ($type eq 'UPDATE_BUDDY') {
        my $status;
        if ($arg eq 'T') {
            $status = 'on';
        }
        elsif ($arg eq 'F') {
            $status = 'off';
        } 
        print "AOL AIM Buddy $name logged $status.\n";
        &main::AOLim_Status_hooks($name, $status, 'AOL');
    }

                                  # Sometimes name, arg, and text are empty,
                                  # but type=2 once a minute, so don't print that
    elsif ($name or $arg or $text) {
        print "AOL AIM data: t=$type name=$name a=$arg text=$text\n";
    }
}


sub aolim::process {
    return unless $main::New_Second;
    if (!defined $aim_connection or !defined $aim_connection->ui_dataget(0)) {
        print "\nAOL AIM connection died\n";
        print "AIM logon error: $main::IM_ERR -> $Net::AOLIM::ERROR_MSGS{$main::IM_ERR} ($main::IM_ERR_ARGS)\n";
        undef $aim_connection;
        &main::MainLoop_post_drop_hook( \&aolim::process, 1 );
    }
}


sub main::net_im_send {
    my %parms = @_;

    undef $parms{to} if lc($parms{to}) eq 'default';

                                # Default is aol aim (only because it was first)
    my $pgm = lc $parms{pgm};
    if ($pgm eq 'jabber') {
        &main::net_jabber_send(%parms);
        return;
    }
    elsif ($pgm eq 'msn') {
        &main::net_msn_send(%parms);
        return;
    }

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

    print "Sending aim message to $to\n";

    $text  = $parms{text};
    $text .= "\n" . &main::file_read($parms{file}) if $parms{file};

    $aim_connection -> toc_send_im($to, $text);
#   $aim_connection -> send_im($to, $text);

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
    my ($from, $to, $subject, $text, $server, $port, $smtp, $account, $mime, $baseref, $file, $filename);

    $server  = $parms{server};
    $port    = $parms{port};
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
    $server  = $main::config_parms{"net_mail_${account}_server_send"}       unless $server;
    $server  = $main::config_parms{"net_mail_${account}_server"}  unless $server;
    $server = 'localhost'                                         unless $server;
    $port    = $main::config_parms{"net_mail_${account}_server_send_port"}  unless $port;
    $port    = 25 unless $port;
    $from    = $main::config_parms{"net_mail_${account}_address"} unless $from;
    $to      = $main::config_parms{"net_mail_${account}_address"} unless $to;
    $subject = "Email from Mister House"                          unless $subject;
    $baseref = 'localhost'                                        unless $baseref;

                                # Allow for multiple recepients
    if ($to =~ /[,;]/) {
        for my $to2 (split /[,;]/, $to) {
            print "sending mail to $to2\n";
            &main::net_mail_send(%parms, to => $to2);
        }
        return;
    }

    $text .= &main::file_read($file) if $file;

    print "Sending mail with account $account from $from to $to on $server $port\n";

    print "net_mail_send error: 'server' parm missing (check net_mail_server in mh.ini)\n" unless $server;
    print "net_mail_send error: 'to' parm missing\n" unless $to;

    return unless $server and $to;

                                # Auto-detect mime type
                                #  - do not mime txt files ... best to just display them directly
#   ($mime) = $file =~ /(pl|zip|exe|jpg|gif|png|html|txt)$/ unless $mime;
    ($mime) = $file =~ /(pl|zip|exe|jpg|gif|png|html)$/ unless $mime;
    $mime = 'text' if $mime eq 'txt' or $mime eq 'pl';

    if ($mime) {
        eval "use MIME::Lite";
        if ($@) {
            print "Error in use MIME::Lite: $@\n";
            print "To use email, you need to install MIME::Lite\n";
            print " - linux: perl -MCPAN -eshell    install MIME::Lite\n";
            print " - windows: ppm -install MIME-Lite\n";
            return;
        }
        my $message;
        ($filename) = $file =~ /([^\\\/]+)$/ unless $filename;
        if ($mime eq 'text') {
            $message = MIME::Lite->new(From => $from,
                                       Subject => $subject,
                                       Type  => 'text,plain',
                                       Encoding => '8bit',
                                       Data => $text,
                                       Filename => $filename,
                                       To => $to);
        }
        elsif ($mime eq 'zip') {
            $message = MIME::Lite->new(From => $from,
                                       Subject => $subject,
                                       Type  => 'application,zip',
                                       Encoding => 'base64',
                                       Data => $text,
                                       Filename => $filename,
                                       To => $to);
        }
        elsif ($mime eq 'bin' or $mime eq 'exe') {
            $message = MIME::Lite->new(From => $from,
                                       Subject => $subject,
                                       Type  => 'application,octet-stream',
                                       Encoding => 'base64',
                                       Data => $text,
                                       Filename => $filename,
                                       To => $to);
        }
        elsif ($mime eq 'jpg' or $mime eq 'gif' or $mime eq 'png') {
            $message = MIME::Lite->new(From => $from,
                                       Subject => $subject,
                                       Type  => 'image,$mime',
                                       Encoding => 'base64',
                                       Data => $text,
                                       Filename => $filename,
                                       To => $to);
        }
                                # Default to html
        else {
                                # Modify the html so it has a BASE HREF and the links work in a mail reader
            $text =~ s|<HEAD>|<HEAD>\n<BASE HREF="http://$parms{baseref}">|i;
            $message = MIME::Lite->new(From => $from,
                                       Subject => $subject,
                                       Type  => 'text/html',
                                       Encoding => '8bit',
                                       Data => $text,
#                                      Path => $file,
                                       Filename => $filename,
                                       To => $to);
        }
        
        
        my $method = $main::config_parms{net_mail_send_method};
        $method = 'smtp' if !$method and $^O eq 'MSWin32';
        print "  - MIME email sent with net_mail_send_method $method\n";
        if ($method eq 'smtp') {
          MIME::Lite->send($method, $server, Timeout => 20, Port => $port);
        }
        elsif ($method) {
          MIME::Lite->send('sendmail', $method);
        }
        $message->send($server, Timeout => 20);
    }
    else {
        use Net::SMTP;
        unless ($smtp = Net::SMTP->new($server, Timeout => 10, Port => $port, Debug => $parms{debug})) {
            print "Unable to log into mail server $server $port: $@\n";
            return;
        }
        $smtp->mail($from) if $from;
        $smtp->to($to);
        $smtp->data("Subject: $subject\n", "To: $to\n", "From: $from\n\n", $text);
        $smtp->quit;
    }
}


sub main::net_mail_login {
    my %parms = @_;
    my ($user, $password, $server, $port, $pop, $account);

    $user     = $parms{user};
    $password = $parms{password};
    $server   = $parms{server};
    $port     = $parms{port};
    $account  = ($parms{account}) ? "net_mail_" . $parms{account} : "net_mail";
    $user     = $main::config_parms{$account . "_user"} unless $user;
    $password = $main::config_parms{$account . "_password"} unless $password;
    $server   = $main::config_parms{$account . "_server"} unless $server;
    $port     = $main::config_parms{$account . "_server_port"} unless $port;
    $port     = 110 unless $port;

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
    unless ($pop = Net::POP3->new($server, Timeout => 10, Port => $port, Debug => $parms{debug})) {
        print "Can not open connection to $server $port: $@\n";
        return;
    }
#   unless ($pop->apop($user, $password)) {   ... avoids plain text password across network by using MD5 ... not installed yet
    my $msgcnt;
    unless (defined ($msgcnt = $pop->login($user, $password))) {
        print "Can not login to $server $port as $user: $@\n";
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

use Date::Parse;                # For str2time

sub main::net_mail_summary {

    my %parms = @_;
    return unless my $pop = &main::net_mail_login(%parms);
#   print "Getting list of message sizes\n";
#   unless ($messages = $pop->list) {
#   print "Can not get list of messages: $!\n";
#   return;
#   }

    $parms{first}  = 1             unless $parms{first};
    $parms{age}    = 24*60         unless $parms{age};
    ($parms{last}) = $pop->popstat unless $parms{last};

    $main::config_parms{net_mail_scan_size} = 2000 unless $main::config_parms{net_mail_scan_size};
    
    my %msgdata;
                                # Rather than 
#   foreach my $msgnum ($parms{first} .. $parms{last}) {
    my $msgnum = $parms{last};
    while ($msgnum) {
        print "getting msg $msgnum\n" if $main::config_parms{debug} eq 'net';
        my $msg_ptr = $pop->top($msgnum, $main::config_parms{net_mail_scan_size});
        my ($date, $date_received, $from, $from_name, $to, $replyto, $subject, $header, $header_flag, $body);
        $header_flag = 1;
        for (@$msg_ptr) {
            if ($header_flag) {
#               chomp;
                $date    = $1 if !$date    and /^Date:(.+)/;
                $from    = $1 if !$from    and /^From:(.+)/;
                $to      = $1 if !$to      and /^To:(.+)/;
                $replyto = $1 if !$replyto      and /^Reply-To:(.+)/;
                $subject = $1 if !$subject and /^Subject:(.+)/;
                $header .= $_;
                $header_flag = 0 if /^ *$/;
                                # Assume first data is the received date
                                #    ... ; Tue, 4 Dec 2001 10:21:48 -0600
                $date_received = $1 if !$date_received and /(\S\S\S, \d+ \S\S\S \d+ \d\d:\d\d:\d\d) /
            }
            else {
                $body .= $_;
            }
        }
        $date_received = $date unless $date_received;

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
                                         # Spammers blank this out, so no point in warning about it
#       print "Warning, net_mail_summary: No From name found: from=$from, header=$header\n" unless $from_name;

        my $age_msg = int((time -  str2time($date_received)) / 60);
        print "Warning, net_mail_summary: age is negative: age=$age_msg, date=$date_received\n" if $age_msg < 0;

        print "msgnum=$msgnum  age=$age_msg date=$date_received from=$from to=$to subject=$subject\n" if $parms{debug} or $main::config_parms{debug} eq 'net';

#       print "db m=$msgnum mf=$parms{first} a=$age_msg a=$parms{age} d=$date_received from=$from \n";
        last if $age_msg > $parms{age};

        push(@{$msgdata{date}},      $date);
        push(@{$msgdata{received}},  $date_received);
        push(@{$msgdata{to}},        $to);
        push(@{$msgdata{replyto}},   $replyto);
        push(@{$msgdata{from}},      $from);
        push(@{$msgdata{from_name}}, $from_name);
        push(@{$msgdata{subject}},   $subject);
        push(@{$msgdata{header}},    $header);
        push(@{$msgdata{body}},      $body);
        push(@{$msgdata{number}},    $msgnum);
        last if --$msgnum < $parms{first};
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

                                # Dangerous method here!
sub main::net_mail_delete {

    my %parms = @_;
    return unless my $pop = &main::net_mail_login(%parms);

    $parms{first}  = 1             unless $parms{first};
    ($parms{last}) = $pop->popstat unless $parms{last};

    my @msgdata;
    foreach my $msgnum ($parms{first} .. $parms{last}) {
        print "Deleting msg $msgnum\n";
        $pop->delete($msgnum);
    }
    $pop->quit;                 # Need to logoff to delete
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
# Revision 1.45  2002/12/02 04:55:20  winter
# - 2.74 release
#
# Revision 1.44  2002/11/10 01:59:57  winter
# - 2.73 release
#
# Revision 1.43  2002/10/13 02:07:59  winter
#  - 2.72 release
#
# Revision 1.42  2002/07/01 22:25:28  winter
# - 2.69 release
#
# Revision 1.41  2002/05/28 13:07:52  winter
# - 2.68 release
#
# Revision 1.40  2002/03/31 18:50:40  winter
# - 2.66 release
#
# Revision 1.39  2002/03/02 02:36:51  winter
# - 2.65 release
#
# Revision 1.38  2002/01/23 01:50:33  winter
# - 2.64 release
#
# Revision 1.37  2002/01/19 21:11:12  winter
# - 2.63 release
#
# Revision 1.36  2001/12/16 21:48:41  winter
# - 2.62 release
#
# Revision 1.35  2001/11/18 22:51:43  winter
# - 2.61 release
#
# Revision 1.34  2001/10/21 01:22:32  winter
# - 2.60 release
#
# Revision 1.33  2001/09/23 19:28:11  winter
# - 2.59 release
#
# Revision 1.32  2001/06/27 03:45:14  winter
# - 2.54 release
#
# Revision 1.31  2001/05/28 21:14:38  winter
# - 2.52 release
#
# Revision 1.30  2001/05/06 21:07:26  winter
# - 2.51 release
#
# Revision 1.29  2001/04/15 16:17:21  winter
# - 2.49 release
#
# Revision 1.28  2001/03/24 18:08:38  winter
# - 2.47 release
#
# Revision 1.27  2001/02/04 20:31:31  winter
# - 2.43 release
#
# Revision 1.25  2000/12/21 18:54:15  winter
# - 2.38 release
#
# Revision 1.24  2000/12/03 19:38:55  winter
# - 2.36 release
#
# Revision 1.23  2000/11/12 21:02:38  winter
# - 2.34 release
#
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
