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
use Encode qw(encode decode);

#require "$main::Pgm_Root/lib/site/HTML/Formatter.pm";

# Translate URL encoded data
sub main::html_unescape {
    my $todecode = shift;
    $todecode =~ tr/+/ /;
    $todecode =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
    return $todecode;
}

sub main::html_decode($) {
    my $ret = $_[0];
    $ret =~ s/&amp;/&/;
    $ret =~ s/&lt;/</;
    $ret =~ s/&gt;/>/;
    return $ret;
}

# Example usage:
#   my $ebay_cookies = '';
#   $f_ebay_login_headers = new File_Item "$config_parms{data_dir}/web/ebay_login.headers";
#   $p_ebay_login = new Process_Item("get_url 'http://signin.ebay.com/ws2/eBayISAPI.dll?SignIn&ssPageName=h:h:sin:US' '/dev/null' '" . $f_ebay_login_headers->name . "'");
#   start $p_ebay_login;
#   if (done_now $p_ebay_login) {
#      $ebay_cookies = &cookies_parse($f_ebay_login_headers, $ebay_cookies);
#   }
sub main::cookies_parse ($$) {
    my ( $file_item, $cookies ) = @_;

    # NOTE: Currently does not handle domains or expiration or anything... just
    # adds all cookies to the list.  Could be improved, but I don't have a need
    # to put in the effort at this time.
    my ( $name, $val );
    foreach ( $file_item->read_all() ) {
        if ( ( $name, $val ) = (/^Set-Cookie: ([^=]+)=([^;]+);.*/) ) {
            $cookies->{$name} = $val;
        }
    }
    return $cookies;
}

# Example usage (continued from example for cookies_parse())
# $p_ebay_watching->set("get_url -cookies '" . &cookies_generate($ebay_cookies) . "' '$url_ebay_watching' '" . $f_ebay_watching->name . "'");
# $p_ebay_watching->start();
sub main::cookies_generate ($$) {
    my ($cookies) = @_;
    my $ret = '';
    foreach ( keys %{$cookies} ) {
        $ret .= "$_=$cookies->{$_}; ";
    }
    $ret =~ s/;\s*$//;
    return $ret;
}

# Checking registry keys is fast!  1 ms per call (1000 calls -> 1 second)
#   print "Time used: ", timestr(timethis(1000, '&net_connect_check')), "\n";
#   Call to dun::checkconnect took 100 ms (100 calls -> 10 seconds)
# Could use dun if we checked only once per second?
# Don't know how to check on non-windows OS
my ( $prev_time, $prev_state );

sub main::net_connect_check {

    return 1 if lc( $main::config_parms{net_connect} ) eq 'persistent';

    # We don't need to check this more than once a second
    return $prev_state if ( $prev_time == time );
    $prev_time = time;

    # Linux
    if ( $^O eq "linux" ) {
        my $if = lc( $main::config_parms{net_connect_if} );
        if ( $if eq "" ) {
            print
              "mh.ini parm net_connect and net_connect_if is not defined.  net connection assumed.\n";
            return $prev_state = 1;
        }
        $prev_state = 0;
        open( PROC, "/proc/net/dev" );
        while (<PROC>) {
            if ( $_ =~ /$if/ ) {
                $prev_state = 1;
                last;
            }
        }
        close PROC;
        if ( $prev_state == 0 ) {
            &main::print_log("net_connect_check: interface $if not active.");
        }
        return $prev_state;
    }

    # Windows 95/98
    my $status = &main::registry_get(
        'HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\RemoteAccess',
        'Remote Connection' );

    #   print "db s=", unpack('H8', $status), ".\n";
    if ( unpack( 'H8', $status ) eq '01000000' ) {

        #       print "Internet connection found\n";
        return $prev_state = 1;
    }
    else {
        #       print "No internet connection found\n";
        return $prev_state = 0;
    }
}

my (
    $DNS_resolver_request, $DNS_resolver_address, $DNS_resolver_requester,
    $DNS_resolver_time,    %DNS_cache
);

# This is the good, background way
sub main::net_domain_name_start {
    ( $DNS_resolver_requester, $DNS_resolver_address ) = @_;

    # Allow for port name to be used.
    $DNS_resolver_address =
      $main::Socket_Ports{$DNS_resolver_address}{client_ip_address}
      if $main::Socket_Ports{$DNS_resolver_address}
      and $main::Socket_Ports{$DNS_resolver_address}{client_ip_address};

    $DNS_cache{$DNS_resolver_address} = 'local'
      if &main::is_local_address($DNS_resolver_address);

    # Cache the data.  If cached, return results immediately,
    # in addition to triggering net_domain_name_done
    if ( $DNS_cache{$DNS_resolver_address} ) {
        $DNS_resolver_request++;
        $DNS_resolver_time = time -
          100;    # Pretend we time out, so we also respond on next _done check
                  # If cached, return data
        return &net_domain_name_parse2( $DNS_cache{$DNS_resolver_address} );
    }
    elsif ($main::DNS_resolver) {
        $DNS_resolver_request =
          $main::DNS_resolver->bgsend($DNS_resolver_address);
        $DNS_resolver_time = time;

        #       print "db $main::Time_Date DNS starting search $main::Time, t=$DNS_resolver_time, a=$DNS_resolver_address\n";
    }
    else {
        $DNS_resolver_request++;
        $DNS_resolver_time =
          time - 100;    # Pretend we time out, so we respond on the next pass
    }
    return;
}

sub main::net_domain_name_done {
    my ($requester) = @_;
    return
      unless $DNS_resolver_request and $requester eq $DNS_resolver_requester;

    #   print "db $DNS_resolver_time, t=$Time r=$requester, r2=$DNS_resolver_requester\n";
    my $result;
    if ( $DNS_cache{$DNS_resolver_address} ) {
        undef $DNS_resolver_request;
        return &net_domain_name_parse2( $DNS_cache{$DNS_resolver_address} );
    }
    elsif ( ( time - $DNS_resolver_time ) > 5 ) {

        #       print "db $main::Time_Date DNS ending   search $main::Time, t=$DNS_resolver_time, a=$DNS_resolver_address\n";
        print "DNS search timed out for $DNS_resolver_address\n"
          if $main::DNS_resolver;
        undef $DNS_resolver_request;
        return;
    }

    return unless $main::DNS_resolver->bgisready($DNS_resolver_request);
    $result = $main::DNS_resolver->bgread($DNS_resolver_request);
    undef $DNS_resolver_request;
    return &net_domain_name_parse( $result, $DNS_resolver_address );
}

# This is the old, inline way
sub main::net_domain_name {
    my ($address) = @_;

    # Allow for port name to be used.
    $address = $main::Socket_Ports{$address}{client_ip_address}
      if $main::Socket_Ports{$address}
      and $main::Socket_Ports{$address}{client_ip_address};

    return ( 'local', 'local' ) if &main::is_local_address($address);

    if ( $DNS_cache{$address} ) {
        return &net_domain_name_parse2( $DNS_cache{$address} );
    }

    my $result;
    if ($main::DNS_resolver) {
        print "Searching for Domain Name of $address ...";
        my $time = time;
        $result = $main::DNS_resolver->search($address);
        print " took ", time - $time, " seconds\n";
    }
    return &net_domain_name_parse( $result, $address );
}

sub net_domain_name_parse {
    my ( $result, $address ) = @_;

    # If no domain name is found, use the IP address
    my $domain_name = $address;

    if ($result) {

        # Use PTR, not CNAME records
        #232.65.86.63.in-addr.arpa.     13240   IN      CNAME   232.224.65.86.63.in-addr.arpa.
        #232.224.65.86.63.in-addr.arpa. 13240   IN      PTR     host232.netwhistle.com.
        #           my $answer = ($result->answer)[0];
        #           my $string = $answer->string if $answer;
        my $string = '';
        for my $answer ( $result->answer ) {
            my $temp = $answer->string;
            print "DNS: $address -> $temp\n" if $main::Debug{net};
            $string = $temp if $temp =~ /\sPTR\s/;
        }

        #   print "db s=$string ip=$DNS_resolver_address\n";
        # answer string looks like this:
        #  33.18.146.204.in-addr.arpa. 36279 IN PTR www.ibm.com.
        #  9.37.208.64.in-addr.arpa.   86400 IN PTR crawler1.googlebot.com.
        $domain_name = ( split( ' ', $string ) )[4] if $string;
    }
    $DNS_cache{$address} = $domain_name;
    return &net_domain_name_parse2($domain_name);
}

sub net_domain_name_parse2 {
    my ($domain_name) = @_;
    my @domain_name = split( '\.', $domain_name );
    my $domain_name2 = $domain_name[-2];
    $domain_name2 .= ( '.' . $domain_name[-1] )
      if $domain_name[-1] !~ /(net)|(com)|(org)/;
    print "db dn=$domain_name dn2=$domain_name2\n" if $main::Debug{net};
    return wantarray ? ( $domain_name, $domain_name2 ) : $domain_name;
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
    my $command = $parms{command};
    my $type    = $parms{type};
    my $passive = $parms{passive};
    my $timeout = $parms{timeout};

    $timeout = $main::config_parms{net_ftp_timeout} unless $timeout;

    $timeout = 20 unless $timeout;

    $server   = $main::config_parms{net_www_server}   unless $server;
    $user     = $main::config_parms{net_www_user}     unless $user;
    $password = $main::config_parms{net_www_password} unless $password;
    $dir      = $main::config_parms{net_www_dir}      unless $dir;
    $passive  = 0                                     unless $passive;

    print
      "net_ftp error: 'server'   parm missing (check net_www_server   in mh.ini)\n"
      unless $server;
    print
      "net_ftp error: 'user'     parm missing (check net_www_user     in mh.ini)\n"
      unless $user;
    print
      "net_ftp error: 'password' parm missing (check net_www_password in mh.ini)\n"
      unless $password;

    return unless $server and $user and $password;

    print "Logging into web server $server as $user...\n";

    my $ftp;
    unless ( $ftp =
        Net::FTP->new( $server, timeout => $timeout, Passive => $passive ) )
    {
        print
          "Unable to connect to ftp server $server timeout=$timeout passive=$passive: $@\n";
        return "failed on connect";
    }
    unless ( $ftp->login( $user, $password ) ) {
        print "Unable to login to $server as $user: $@\n";
        return "failed on login";
    }

    print " - doing a $type $command local=$file remote=$file_remote\n";

    if ($dir) {
        unless ( $ftp->cwd($dir) ) {
            print "Unable to chdir to $dir on ftp server $server: $@\n";
            return "failed on change dir";
        }
    }
    if ( $type eq 'binary' ) {
        unless ( $ftp->binary() ) {
            print " \x07Unable to set bin mode on $server: $@\n";
            return "failed on binary";
        }
    }
    if ( $command eq 'put' ) {
        unless ( $ftp->put( $file, $file_remote ) ) {
            print
              " \x07Unable to put file $file into $server as $file_remote: $@\n";
            return "failed on put";
        }
    }
    elsif ( $command eq 'get' ) {
        unless ( $ftp->get( $file_remote, $file ) ) {
            print " \x07Unable to get file $file_remote from $server: $@\n";
            return "failed on put";
        }
    }
    elsif ( $command eq 'delete' ) {
        unless ( $ftp->delete($file_remote) ) {
            print " \x07Unable to delete file $file_remote from $server: $@\n";
            return "failed on delete";
        }
    }
    elsif ( $command eq 'mkdir' ) {
        unless ( $ftp->mkdir($file_remote) ) {
            print " \x07Unable to make dir $file_remote from $server: $@\n";
            return "failed on mkdir";
        }
    }
    else {
        print "Bad ftp command: $command\n";
        return "bad ftp command: $command";
    }

    print join( "\n", $ftp->dir($file_remote) ) if $command eq 'put';
    $ftp->quit;
    return "was successful";
}

use vars
  qw($aim_connection $icq_connection $jabber_connection $msn_connection %msn_connections %msn_queue %im_queue);

eval 'use Net::Jabber';

# print "Error loading Net::Jabber library\n$@\n" if $@;

sub main::net_jabber_signon {
    return if $jabber_connection;    # Already signed on

    my ( $name, $password, $server, $resource, $port ) = @_;

    $name     = $main::config_parms{net_jabber_name}     unless $name;
    $password = $main::config_parms{net_jabber_password} unless $password;
    $server   = $main::config_parms{net_jabber_server}   unless $server;
    $port     = $main::config_parms{net_jabber_port}     unless $port;
    $resource = $main::config_parms{net_jabber_resource} unless $resource;
    my $tls   = $main::config_parms{net_jabber_tls};
    my $certs = $main::config_parms{net_jabber_certs_path};
    $certs = '/etc/ssl/certs/' unless $certs;
    my $component = $main::config_parms{net_jabber_component_name};

    $server   = 'jabber.com'  unless $server;
    $port     = 5222          unless $port;
    $resource = 'misterhouse' unless $resource;
    $tls      = 1             unless defined($tls);

    print "Logging onto $server $port with name=$name resource=$resource\n";

    print "Error in Net::Jabber: $@\n" if $@;
    $jabber_connection = new Net::Jabber::Client();

    #   $jabber_connection = Net::Jabber::Client->new(debuglevel => 2, debugtime  => 1 , debugfile  =>  "/tmp/jabber.log");

    my %options = (
        hostname    => $server,
        port        => $port,
        tls         => $tls,
        ssl_ca_path => $certs
    );
    $options{componentname} = $component if ($component);
    my $success = $jabber_connection->Connect(%options);
    unless ($success) {
        print
          "  - Error:  Jabber server is down or connection was not allowed. jc=$jabber_connection: '$@'\n";
        undef $jabber_connection;
        return;
    }

    if ($component) {
        $jabber_connection->{STREAM}->{SIDS}
          ->{ $jabber_connection->{SESSION}->{id} }->{hostname} = $component;
    }

    $jabber_connection->SetCallBacks(
        message  => \&jabber::InMessage,
        presence => \&jabber::InPresence,
        iq       => \&jabber::InIQ
    );

    print "  - Sending username/resource ${name}/${resource}\n";

    #   $jabber_connection->Connect();
    my @result = $jabber_connection->AuthSend(
        username => $name,
        password => $password,
        resource => $resource
    );
    if ( $result[0] ne "ok" ) {
        print
          "  - Error: Jabber Authorization failed: $result[0] - $result[1]\n";
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
    if (   !defined $jabber_connection
        or !defined $jabber_connection->Process(0) )
    {
        print "\nJabber connection died\n";
        undef $jabber_connection;
        &main::MainLoop_post_drop_hook( \&jabber::process, 1 );
    }
}

sub jabber::InMessage {
    my $sid     = shift;
    my $message = shift;

    #   my $type     = $message->GetType();
    my $from = $message->GetFrom();

    #   my $to       = $message->GetTo();
    #   my $resource = $message->GetResource();
    #   my $subject  = $message->GetSubject();
    my $body = $message->GetBody();

    #   &main::display("$main::Time_Date $from\nMessage:  " . $body, 0, "Jabber Message from $from", 'fixed');
    #   &main::Jabber_Message_hooks($sid, $message, 'jabber');
    &main::Jabber_Message_hooks( $from, $body, 'jabber' );
}

sub jabber::InIQ {
    my $sid = shift;
    my $iq  = shift;

    my $from  = $iq->GetFrom();
    my $type  = $iq->GetType();
    my $query = $iq->GetQuery();
    my $xmlns = $query->GetXMLNS();
    &main::display( "$main::Time_Date $from\nIQ $query:  " . $xmlns,
        0, "Jabber IQ from $from", 'fixed' );
    &main::Jabber_IQ_hooks( $sid, $iq );
}

sub jabber::InPresence {
    my $sid      = shift;
    my $presence = shift;

    my $from   = $presence->GetFrom();
    my $type   = $presence->GetType();
    my $status = $presence->GetStatus();

    #   &main::display("$main::Time_Date $from\nPresence:  " . $status, 0, "Jabber Presence from $from.", 'fixed');
    &main::Jabber_Presence_hooks( $from, $status, undef, 'jabber' );

    #   print $presence->GetXML(),"\n";
}

sub main::net_jabber_send {
    my %parms = @_;

    my ( $from, $password, $to, $text, $file, $subject, $server, $resource );

    $from     = $parms{from};
    $password = $parms{password};
    $to       = $parms{to};
    $subject  = $parms{subject};

    $from     = $main::config_parms{net_jabber_name}      unless $from;
    $password = $main::config_parms{net_jabber_password}  unless $password;
    $to       = $main::config_parms{net_jabber_name_send} unless $to;
    $server   = $main::config_parms{net_jabber_server}    unless $server;
    $resource = $main::config_parms{net_jabber_resource}  unless $resource;
    $subject  = "Misterhouse"                             unless $subject;

    unless ( $from and $password and $to ) {
        print
          "\nError, net_jabber_send called with a missing argument:  from=$from to=$to password=$password\n";
        return;
    }

    # This will take a few seconds to connect the first time
    &main::net_jabber_signon( $from, $password, $server, $resource );
    return unless $jabber_connection;

    $text = $parms{text};
    $text .= "\n" . &main::file_read( $parms{file} ) if $parms{file};

    print "Sending jabber message to $to: $text\n";

    $jabber_connection->MessageSend(
        to      => $to,
        body    => $text,
        subject => $subject
    );
    $jabber_connection->Process(0);

}

sub main::net_msn_signon {
    my ( $name, $password ) = @_;

    return if $msn_connection;    # Already signed on

    $name     = $main::config_parms{net_msn_name}     unless $name;
    $password = $main::config_parms{net_msn_password} unless $password;

    print "Logging onto MSN with name=$name ... \n";

    eval 'use MSN';
    if ($@) {
        print "MSN eval error: $@\n";
        return;
    }
    $msn_connection = MSN->new();

    # Currently does not have a way to verify login??
    $msn_connection->connect(
        $name,
        $password,
        '',
        {
            Status  => \&MSN::status,
            Answer  => \&MSN::answer,
            Message => \&MSN::message,
            Join    => \&MSN::join
        },
        0
    );

    #    print "MSN logon error: $main::IM_ERR -> $Net::MSNIM::ERROR_MSGS{$main::IM_ERR} ($main::IM_ERR_ARGS)\n";
    #    undef $msn_connection;
    #    return;

    &main::MainLoop_post_add_hook( \&MSN::process, 1, $msn_connection, 0 );
}

sub main::net_msn_signoff {
    print "disconnecting from msn\n";
    undef $msn_connection;
    &main::MainLoop_post_drop_hook( \&MSN::process, 1 );
}

sub MSN::status {
    my ( $self, $username, $newstatus ) = @_;
    print "MSN ${username}'s status changed from "
      . $self->buddystatus($username)
      . " to $newstatus.\n";
    &main::MSNim_Status_hooks( $username, $newstatus,
        $self->buddystatus($username), 'MSN' );
}

sub MSN::message {
    my ( $self, $name, $name2, $text ) = @_;
    print "MSN Message received: $name, $name2, $text\n";
    &main::MSNim_Message_hooks( $name, $text, 'MSN' );
    $msn_connections{$name} = $self;
    &MSN::send_queue($name);
}

sub MSN::join {
    my ( $self, $username ) = @_;
    print "MSN Join: $username\n";
    $msn_connections{$username} = $self;
    &MSN::send_queue($username);
}

sub MSN::answer {
    my ( $self, $username ) = @_;
    print "MSN Answer:  $username\n";
    $$self->sendmsg("Hello from MisterHouse to $username");
    $msn_connections{$username} = $self;
    &MSN::send_queue($username);
}

sub MSN::send_queue {
    my ($username) = @_;
    return unless $msn_queue{$username};
    my $connection = $msn_connections{$username};
    my $msg;
    while ( defined( $msg = shift @{ $msn_queue{$username} } ) ) {
        print "MSN sending: $username, $msg\n";
        $$connection->sendmsg($msg);
    }
}

sub main::net_msn_send {
    my %parms = @_;

    my ( $from, $password, $to, $text, $file );

    $from     = $parms{from};
    $password = $parms{password};
    $to       = $parms{to};

    $from     = $main::config_parms{net_msn_name}      unless $from;
    $password = $main::config_parms{net_msn_password}  unless $password;
    $to       = $main::config_parms{net_msn_name_send} unless $to;

    unless ( $from and $password and $to ) {
        print
          "\nError, net_msn_send called with a missing argument:  from=$from to=$to password=$password\n";
        return;
    }
    print "Sending MSN message to $to\n";
    $text = $parms{text};
    $text .= "\n" . &main::file_read( $parms{file} ) if $parms{file};

    unless ($msn_connection) {
        &main::net_msn_signon( $from, $password );

        # Gotta wait until we are logged on until we send the msg
        for ( 1 .. 40 ) {
            print ".";
            select undef, undef, undef, .1;

            #           &MSN::process($msn_connection, 0);
            $msn_connection->process(0);
        }
    }

    # Use an existing connection, or create a new one?
    if ( my $to_connection = $msn_connections{$to} ) {
        $$to_connection->sendmsg($text);
    }
    else {
        print "Calling MSN user $to\n";
        $msn_connection->call($to);
        push( @{ $msn_queue{$to} }, $text );
    }

}

sub main::net_im_signon {
    my ( $name, $password, $pgm, $port ) = @_;

    if ( lc $pgm eq 'msn' ) {
        return &main::net_msn_signon( $name, $password );
    }
    elsif ( lc $pgm eq 'jabber' ) {
        return &main::net_jabber_signon( $name, $password );
    }
    elsif ( lc $pgm eq 'icq' ) {
        return &main::net_icq_signon( $name, $password, $port );
    }
    return &main::net_aol_signon( $name, $password, $port );
}

sub main::net_aol_signon {
    my ( $name, $password, $pgm, $port ) = @_;

    # Already signed on?
    unless ( $aim_connection and $oscar::aim_connected ) {
        $aim_connection = main::get_oscar_connection( "AIM", $name, $password );
    }
    return $aim_connection;
}

sub main::net_icq_signon {
    my ( $name, $password, $pgm, $port ) = @_;

    # Already signed on?
    unless ( $icq_connection and $oscar::icq_connected ) {
        $icq_connection = main::get_oscar_connection( "ICQ", $name, $password );
    }
    return $icq_connection;
}

sub main::get_oscar_connection {
    my ( $network, $name, $password ) = @_;
    my $im_connection;
    my $lnet = lc($network);

    $name = $main::config_parms{ 'net_' . $lnet . '_name' } unless $name;
    $password = $main::config_parms{ 'net_' . $lnet . '_password' }
      unless $password;

    if ( !$name ) {
        warn "$network user name (net_" . $lnet . "_name) is not configured";
    }

    if ( !$password ) {
        warn "$network password (net_" . $lnet . "_password) is not configured";
    }

    return unless $name and $password;

    print "Logging onto $network with name=$name ... \n";

    eval 'use Net::OSCAR qw(:standard :loglevels)';
    if ($@) {
        print "Net::OSCAR use error: $@\n";
        return;
    }

    # I got not buddies?   'invalid capability' on buddy_list_transfer
    #   $im_connection = Net::OSCAR->new(capabilities => [qw(typing_status extended_status buddy_icons file_transfer buddy_list_transfer)]);
    $im_connection = Net::OSCAR->new(
        capabilities => [
            qw(typing_status extended_status buddy_icons file_transfer                    )
        ]
    );
    $im_connection->set_callback_im_in( \&oscar::cb_imin );
    $im_connection->set_callback_buddy_in( \&oscar::cb_buddyin );
    $im_connection->set_callback_buddy_out( \&oscar::cb_buddyout );
    $im_connection->set_callback_error( \&oscar::cb_error );
    $im_connection->set_callback_signon_done( \&oscar::cb_signondone );
    $im_connection->set_callback_connection_changed(
        \&oscar::cb_connectionchanged );
    $im_connection->set_callback_buddy_icon_uploaded(
        \&oscar::cb_buddyiconuploaded );
    $im_connection->set_callback_buddy_icon_downloaded(
        \&oscar::cb_buddyicondownloaded );
    $im_connection->set_callback_buddylist_ok( \&oscar::cb_buddylistok );

    #   $im_connection -> set_callback_buddylist_changed(\&oscar::cb_buddylistchanged);
    $im_connection->set_callback_buddylist_error( \&oscar::cb_buddylisterror );
    $im_connection->set_callback_typing_status( \&oscar::cb_typing_status );
    $im_connection->set_callback_extended_status( \&oscar::cb_extended_status );
    $im_connection->set_callback_log( \&oscar::cb_log );

    #my %level_map=(0=>'NONE', 1=>'WARN', 2=>'INFO', 3=>'SIGNON', 4=>'NOTICE', 6=>'DEBUG', 10=>'PACKETS',30=>'XML', 35=>'XML2');
    # for some reason the package constants do not get correctly imported.
    # uncomment the following line to get DEBUG level messages
    # $im_connection->loglevel(6,1);

    unless (
        defined(
            $im_connection->signon(
                screenname => $name,
                password   => $password
            )
        )
      )
    {
        return undef;
    }
    if ( $lnet eq 'aim' ) {
        $oscar::aim_connected = 0;
        &main::MainLoop_post_add_hook( \&oscar::process_aim, 1 );
    }
    else {
        $oscar::icq_connected = 0;
        &main::MainLoop_post_add_hook( \&oscar::process_icq, 1 );
    }

    return $im_connection;
}

sub main::net_im_signoff {
    my ($pgm) = @_;
    if ( lc $pgm eq 'msn' ) {
        &main::net_msn_signoff;
    }
    elsif ( lc $pgm eq 'jabber' ) {
        &main::net_jabber_signoff;
    }
    elsif ( lc $pgm eq 'icq' ) {
        print "Disconnecting from ICQ\n";
        $icq_connection->signoff();
        undef $icq_connection;
        &main::MainLoop_post_drop_hook( \&icq::process, 1 );
    }
    else {
        print "Disconnecting from AOL\n";
        $aim_connection->signoff();
        undef $aim_connection;
        &main::MainLoop_post_drop_hook( \&oscar::process_aim, 1 );
    }
}

# Since ICQ buddy names are numbers only we can share buddies_status
# without worrying about conflicts
my %buddies_status;

# IM_IN MisterHouse F <HTML><BODY BGCOLOR="#ffffff"><FONT>hiho</FONT></BODY></HTML>

sub oscar::cb_typing_status {
    my ( $oscar, $who, $status ) = @_;

    # print "We received typing status $status from $who.\n";
}

sub oscar::cb_extended_status {
    my ( $oscar, $status ) = @_;
    print "Our extended status is $status.\n" if $status;
}

sub oscar::buddylist_changed {
    my ( $oscar, @changes ) = @_;

    print "Buddylist was changed:\n";
    foreach (@changes) {
        printf( "\t%s: %s %s\n",
            $_->{action}, $_->{type},
            ( $_->{type} == 1 )
            ? ( $_->{group} . "/" . $_->{buddy} )
            : $_->{group} );
    }
}

sub oscar::cb_error {
    my ( $oscar, $connection, $error, $description, $fatal ) = @_;
    my $name = $oscar->screenname();
    print "OSCAR error ($name): $description\n";
}

sub oscar::cb_buddyin {
    my ( $oscar, $screenname, $group, $buddydata ) = @_;

    oscar::buddychange( $oscar, $screenname, 'on' );
}

sub oscar::cb_buddyout {
    my ( $oscar, $screenname, $group ) = @_;

    oscar::buddychange( $oscar, $screenname, 'off' );
}

sub oscar::cb_buddyiconuploaded {
    my ($oscar) = @_;

    my $net = oscar::get_net($oscar);

    print( uc($net) . " buddy icon set\n" );
}

sub oscar::cb_buddyicondownloaded {
    my ($oscar) = @_;

    my $net = oscar::get_net($oscar);

    print( uc($net) . " buddy icon read\n" );
}

sub oscar::cb_buddylistok {
    my ($oscar) = @_;

    my $net = oscar::get_net($oscar);

    print( uc($net) . " buddy list set\n" );
}

sub oscar::cb_buddylisterror {
    my ( $oscar, $error, $what ) = @_;

    my $net = oscar::get_net($oscar);

    print( uc($net) . " buddy list error: $what\n" );
}

sub oscar::cb_log {
    my ( $oscar, $level, $message ) = @_;

    my $net = oscar::get_net($oscar);

    my %level_map = (
        0  => 'NONE',
        1  => 'WARN',
        2  => 'INFO',
        3  => 'SIGNON',
        4  => 'NOTICE',
        6  => 'DEBUG',
        10 => 'PACKETS',
        30 => 'XML',
        35 => 'XML2'
    );

    my $level_string = $level_map{$level};

    print( uc($net) . " log $level_string :" . $message . "\n" );
}

sub oscar::cb_signondone {
    my ($oscar) = @_;

    my $net     = oscar::get_net($oscar);
    my $buddies = $main::config_parms{ 'net_' . $net . '_buddies' };

    &::print_log( "Signed on to " . uc($net) );
    if ( $net eq 'aim' ) {
        $oscar::aim_connected = 1;
    }
    else {
        $oscar::icq_connected = 1;
    }

    for ( split /,/, $buddies ) {
        print( "Adding " . uc($net) . " buddy $_\n" );
        $oscar->add_buddy( "friends", $_ );
    }
    my $iconfile = $main::config_parms{"net_${net}_buddy_icon"};
    if ( -r $iconfile ) {
        my $icon = &main::file_read($iconfile);
        print( "Setting " . uc($net) . " buddy icon: $iconfile...\n" );
        $oscar->set_icon($icon)
          if $icon and $main::config_parms{"net_${net}_class"} ne 'free';
    }

    #   $oscar -> set_visibility(1);

    print( "Sending " . uc($net) . " buddy list...\n" );
    $oscar->commit_buddylist();
}

sub oscar::cb_connectionchanged {
    my ( $oscar, $connection, $status ) = @_;

    my $net = oscar::get_net($oscar);
    print( uc($net) . " connection: $status\n" );

    # For some reason, we get a status=deleted when first logging onto
    # OSCAR.  We only react to 'deleted' if we have previously been connected
    if ( $status eq 'deleted' ) {
        if ( $net eq 'aim' ) {
            if ( $oscar::aim_connected == 1 ) {
                $oscar::aim_connected = 0;
                &main::AOLim_Disconnected_hooks();
            }
        }
        else {
            if ( $oscar::icq_connected == 1 ) {
                $oscar::icq_connected = 0;
                &main::ICQim_Disconnected_hooks();
            }
        }
    }
}

sub oscar::get_net {
    my ($oscar) = @_;

    if ( lc $oscar->screenname() eq lc $main::config_parms{'net_aim_name'} ) {
        return 'aim';
    }
    else {
        return 'icq';
    }
}

sub oscar::buddychange {
    my ( $oscar, $screenname, $status ) = @_;

    my $status_old = $buddies_status{$screenname};
    if ( $buddies_status{$screenname} ne $status ) {
        print "AOL AIM Buddy $screenname logged $status.\n";
        $buddies_status{$screenname} = $status;
    }
    if ( oscar::get_net($oscar) eq 'aim' ) {
        &main::AOLim_Status_hooks( $screenname, $status, $status_old, 'AOL' );
    }
    else {
        &main::ICQim_Status_hooks( $screenname, $status, $status_old, 'ICQ' );
    }
}

sub oscar::cb_imin {
    my ( $oscar, $from, $message, $away ) = @_;

    my $plaintext = HTML::FormatText->new( lm => 0, rm => 150 )
      ->format( HTML::TreeBuilder->new()->parse($message) );
    chomp $plaintext;

    my $net = oscar::get_net($oscar);
    if ( $net eq 'aim' ) {
        &main::AOLim_Message_hooks( $from, $plaintext, 'AOL' );
    }
    else {
        &main::ICQim_Message_hooks( $from, $plaintext, 'ICQ' );
    }
}

sub oscar::process_icq {
    oscar::process('icq');
}

sub oscar::process_aim {
    oscar::process('aim');
}

sub oscar::process {
    my ($net) = @_;

    return unless $main::New_Second;

    my $connection;

    if ( $net eq 'icq' ) {
        $connection = $icq_connection;
    }
    else {
        $connection = $aim_connection;
    }

    # not sure how to check if connection is still up
    $connection->do_one_loop() if defined $connection;
}

sub main::net_im_process_queue {
    my $pgm       = shift;
    my $recipient = shift;

    $pgm = lc $pgm;
    $recipient ||= 'default';

    return unless $im_queue{$pgm};

    #   return unless &main::new_second(10); # Throttle outgoing data, so they don't cancel the account! ... not needed?

    my $parms;
    my $num_items = scalar @{ $im_queue{$pgm} };
    while ( defined( $parms = shift @{ $im_queue{$pgm} } ) && $num_items ) {
        &main::print_log(
            "Trying again to send $pgm message to " . $$parms{to} );
        if ( $$parms{to} eq $recipient ) {
            &main::net_im_send(%$parms);
        }
        else {
            push( @{ $im_queue{$pgm} }, $parms );
        }
        $num_items--;
    }

}    #  main::net_im_process_queue()

sub main::net_im_send {
    my %parms = @_;

    if ( $main::Debug{im} ) {
        my $parm;
        foreach $parm ( keys(%parms) ) {
            print "net_im_send parm $parm is $parms{$parm}\n";
        }
    }

    # Default is aol aim (only because it was first)
    my $pgm = lc $parms{pgm};
    my $to  = $parms{to};
    print "net_im_send pgm=$pgm to=$to\n" if $main::Debug{im};
    &::logit(
        "$main::config_parms{data_dir}/logs/net_im.$::Year_Month_Now.log",
        "to=$to from=$parms{from} pgm=$pgm text=$parms{text}"
    );

    return if &main::net_im_do_send(%parms) != 0;

    return unless $main::config_parms{net_queue_im};

    # Queue the msg!
    $to ||= 'default';
    $parms{to} = $to;
    push( @{ $im_queue{$pgm} }, \%parms );
    &main::print_log("Unable to send $pgm message to $to, queued for later..");
}

sub main::net_im_do_send {

    my %parms = @_;

    undef $parms{to} if lc( $parms{to} ) eq 'default';

    my $pgm = lc $parms{pgm};
    if ( $pgm eq 'jabber' ) {
        &main::net_jabber_send(%parms);
        return 1;
    }
    elsif ( $pgm eq 'msn' ) {
        &main::net_msn_send(%parms);
        return 1;
    }

    my ( $from, $password, $to, $text, $file, $im_connection );

    $from     = $parms{from};
    $password = $parms{password};
    $to       = $parms{to};

    # *** Better decision here on missing pgm!
    #  Which is configured?  If both, is name numeric?
    # *** Store pgm in set_by too!  And send with to param when responding in kind to IM users

    if ( $pgm eq 'icq' ) {
        $from     = $main::config_parms{net_icq_name}      unless $from;
        $password = $main::config_parms{net_icq_password}  unless $password;
        $to       = $main::config_parms{net_icq_name_send} unless $to;
    }
    else {
        $from     = $main::config_parms{net_aim_name}      unless $from;
        $password = $main::config_parms{net_aim_password}  unless $password;
        $to       = $main::config_parms{net_aim_name_send} unless $to;
    }

    unless ( $from and $password and $to ) {
        print
          "\nError, net_im_send called with a missing argument:  from=$from to=$to password=$password\n";
        return 0;
    }

    # This will take a few seconds to connect the first time
    $im_connection = &main::net_im_signon( $from, $password, $parms{pgm} );

    print "net_im_send im=$im_connection to=$to status=$buddies_status{$to}\n"
      if $::Debug{im};

    return 0 unless defined $im_connection;

    return 0 if $buddies_status{$to} and $buddies_status{$to} ne 'on';

    $text = $parms{text};
    $text .= "\n" . &main::file_read( $parms{file} ) if $parms{file};

    return if $text eq '';

    print "Sending $parms{pgm} message to $to\n";

    # Chop message up if needed since AIM has a limit of 1024

    # Need this for html based clients??
    #   $text =~ s/\n/<br>/g;

    my $message_sent = 1;
    if ( length $text > 900 ) {

        # Break message into lines for readability
        my @lines = split /\n/, $text;

        my $line = "";
        while ( scalar(@lines) ) {
            if ( ( ( length $line ) + ( length $lines[0] ) ) > 900 ) {
                $im_connection->send_im( $to, $line ) if $line;
                $line = "";
            }
            $line = $line . ( shift @lines ) . "\n";
        }
        if ($line) {
            my $ret = $im_connection->send_im( $to, $line );
            $message_sent = 0 unless defined $ret;
        }
    }
    else {
        my $ret = $im_connection->send_im( $to, $text );
        $message_sent = 0 unless defined $ret;
    }
    return $message_sent;
}

sub main::net_mail_send_old {
    my %parms = @_;
    my ( $from, $to, $subject, $text, $server, $smtp, $account );

    $server  = $parms{server};
    $from    = $parms{from};
    $to      = $parms{to};
    $subject = $parms{subject};
    $account = $parms{account};

    $account = $main::config_parms{net_mail_send_account}        unless $server;
    $server  = $main::config_parms{"net_mail_${account}_server"} unless $server;
    $from = $main::config_parms{"net_mail_${account}_address"} unless $from;
    $to = $main::config_parms{"net_mail_${account}_address"} unless $to;
    $subject = "Email from Mister House" unless $subject;
    $text = $parms{text};

    print
      "net_mail_send error: 'server' parm missing (check net_mail_server in mh.ini)\n"
      unless $server;
    print "net_mail_send error: 'to' parm missing\n" unless $to;

    return unless $server and $to;

    use Net::SMTP;
    print "Logging into mail server $server to send msg to $to\n";

    unless ( $smtp =
        Net::SMTP->new( $server, Timeout => 10, Debug => $parms{debug} ) )
    {
        print "Unable to log into mail server $server: $@\n";
        return;
    }
    $smtp->mail($from) if $from;
    $smtp->to($to);
    $smtp->data( "Subject: $subject\n", "To: $to\n", "From: $from\n\n", $text );
    $smtp->quit;
    print "Message sent\n";
}

sub main::net_mail_send {
    my %parms = @_;
    my (
        $from, $to,       $subject, $text, $server,
        $port, $smtp,     $account, $mime, $baseref,
        $file, $filename, $service
    );
    my ( $smtpusername, $smtppassword, $smtpencrypt );

    $server       = $parms{server};
    $port         = $parms{port};
    $account      = $parms{account};
    $from         = $parms{from};
    $to           = $parms{to};
    $subject      = $parms{subject};
    $mime         = $parms{mime};
    $baseref      = $parms{baseref};
    $text         = $parms{text};
    $file         = $parms{file};
    $filename     = $parms{filename};
    $smtpusername = $parms{smtpusername};
    $smtppassword = $parms{smtppassword};
    $smtpencrypt  = $parms{smtpencrypt};

    my $priority = $parms{priority};
    $priority = 3 unless $priority;

    $account = $main::config_parms{net_mail_send_account} unless $account;
    $server = $main::config_parms{"net_mail_${account}_server_send"}
      unless $server;
    $server = $main::config_parms{"net_mail_${account}_server"} unless $server;
    $server = 'localhost' unless $server;
    $port = $main::config_parms{"net_mail_${account}_server_send_port"}
      unless $port;
    $port = 25                                                 unless $port;
    $from = $main::config_parms{"net_mail_${account}_address"} unless $from;
    $to   = $main::config_parms{"net_mail_${account}_address"} unless $to;
    $subject = "Email from Misterhouse" unless $subject;

    #    $baseref = 'localhost'                                        unless $baseref;
    $service = $main::config_parms{"net_mail_${account}_service"};
    $service = "smtp" unless $service;

    my $timeout =
      $main::config_parms{"net_mail_${account}_server_send_timeout"};
    $timeout = 20 unless $timeout;

    $smtpusername = $main::config_parms{"net_mail_${account}_user"}
      unless $smtpusername;
    $smtppassword = $main::config_parms{"net_mail_${account}_password"}
      unless $smtppassword;
    $smtpencrypt = $main::config_parms{"net_mail_${account}_password_encrypt"}
      unless $smtpencrypt;
    $smtpencrypt = "PLAIN" unless $smtpencrypt;

    # Allow for multiple recepients
    if ( $to =~ /[,;]/ ) {
        for my $to2 ( split /[,;]/, $to ) {
            print "sending mail to $to2\n";
            &main::net_mail_send( %parms, to => $to2 );
        }
        return;
    }

    print
      "Sending $service mail with account $account from $from to $to on $server $port\n";

    print
      "net_mail_send error: 'server' parm missing (check net_mail_server in mh.ini)\n"
      unless $server;
    print "net_mail_send error: 'to' parm missing\n" unless $to;

    return unless $server and $to;

    # Auto-detect mime type
    #  - do not mime txt files ... best to just display them directly
    #   ($mime) = $file =~ /(pl|zip|exe|jpg|gif|png|html|txt)$/ unless $mime;
    ($mime) = $file =~ /\.([a-z0-9]+)$/i unless $mime;
    $mime = lc $mime;
    $mime = 'unknown' if $file and not $mime;
    my $mime_message;

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
        $message = MIME::Lite->new(
            From    => $from,
            To      => $to,
            Subject => $subject,
            Type    => 'multipart/mixed',
        );
        if ($text) {
            $message->attach(
                Type => 'TEXT',
                Data => $text,
            );
        }
        if ( $mime eq 'text' or $mime eq 'txt' or $mime eq 'pl' ) {
            $message->attach(
                Type     => 'text/plain',
                Encoding => '7bit',
                Path     => $file,
                Filename => $filename,
            );
        }
        elsif ( $mime eq 'zip' ) {
            $message->attach(
                Type     => 'application/zip',
                Encoding => 'base64',
                Path     => $file,
                Filename => $filename,
            );
        }
        elsif ( $mime eq 'jpg' or $mime eq 'gif' or $mime eq 'png' ) {
            $message->attach(
                Type     => "image/$mime",
                Encoding => 'base64',
                Path     => $file,
                Filename => $filename,
            );
        }
        elsif ( $mime =~ /html/ ) {
            $text = &main::file_read($file) if $file;

            # Modify the html so it has a BASE HREF and the links work in a mail reader
            #  - Seems to work anywhere?  Not all html has <HEAD> like it should
            $text =~ s|(<HTML.*?>)|$1\n<BASE HREF="http://$baseref">|i
              if $baseref;
            if ( $mime eq 'html_inline' ) {
                $message = MIME::Lite->new(
                    From     => $from,
                    Subject  => $subject,
                    Type     => 'text/html',
                    Encoding => '8bit',
                    Data     => $text,
                    Filename => $filename,
                    To       => $to
                );
            }
            else {
                $message->attach(
                    Type     => 'text/html',
                    Encoding => '8bit',
                    Data     => $text,
                    Filename => $filename,
                );
            }
        }
        else {
            $message->attach(
                Type     => 'application/octet-stream',
                Encoding => 'base64',
                Path     => $file,
                Filename => $filename,
            );
        }

        $message->add( 'X-Priority' => $priority ) if ( $priority != 3 );
        $mime_message = $message->as_string;
    }

    if ( lc $service eq "gmail" ) {
        print "Sending message via Gmail...\n";
        print "Only text messages supported at this time.\n" if ($mime_message);
        eval "require 'net_gmail_utils.pl'";
        if ($@) {
            print "Error in require net_gmail_utils: $@\n";
            print "To use gmail send, you need to install dependancies\n";
            return;
        }

        &net_gmail_utils::send_gmail(
            account       => $account,
            gmail_account => $smtpusername,
            password      => $smtppassword,
            to            => $to,
            text          => $text,
            subject       => $subject
        );

    }
    else {

        eval
          "use Net::SMTP_auth";   # Not on all installs, so eval to avoid errors
        print "NET::SMTP_auth eval error: $@\n" if $@;

        use Net::SMTP;
        use Authen::SASL;

        unless (
            $smtp = Net::SMTP_auth->new(
                $server,
                Timeout => $timeout,
                Port    => $port,
                Debug   => $parms{debug}
            )
          )
        {
            print "Unable to Authenticate on mail server $server $port: $@\n";
            return;
        }
        print 'Authenticating SMTP using encryption ', $smtpencrypt,
          " for username ", $smtpusername, "\n"
          if $parms{debug};

        # set SMTP username and password if we have them
        $smtp->auth( $smtpencrypt, $smtpusername, $smtppassword )
          if ( $smtpusername and $smtppassword );

        use Email::Date::Format qw(email_date);
        my $emaildate = email_date;    #use current local time

        $smtp->mail($from) if $from;
        $smtp->to($to);
        if ($mime_message) {
            $smtp->data();
            $smtp->datasend($mime_message);
            $smtp->dataend();
        }
        else {
            $smtp->data(
                "X-Priority: $priority\n",
                "Subject: $subject\n",
                "To: $to\n",
                "From: $from\n",
                "Date: $emaildate\n\n", $text
            );
        }
        $smtp->quit;
    }
}

sub main::net_mail_login {
    my %parms = @_;
    my ( $user, $password, $server, $port, $pop, $account, $ping );

    $user     = $parms{user};
    $password = $parms{password};
    $server   = $parms{server};
    $port     = $parms{port};
    $ping     = $parms{ping};
    $account = ( $parms{account} ) ? "net_mail_" . $parms{account} : "net_mail";
    $user = $main::config_parms{ $account . "_user" } unless $user;
    $password = $main::config_parms{ $account . "_password" } unless $password;
    $server   = $main::config_parms{ $account . "_server" } unless $server;
    $port     = $main::config_parms{ $account . "_server_port" } unless $port;
    $port     = 110 unless $port;
    $ping     = $main::config_parms{ $account . "_server_ping" } unless $ping;
    $ping     = 'on' unless $ping;

    print "net_mail_login error: mh.ini ${account}_user parm is missing\n"
      unless $user;
    print "net_mail_login error: mh.ini ${account}_password parm is missing\n"
      unless $password;
    print "net_mail_login error: mh.ini ${account}_server parm is missing\n"
      unless $server;

    return unless $server and $user and $password;

    # This will time out in 1-2 seconds, -vs- 30 seconds for pop login
    #   print "Server ping test set to ", $ping , "\n" ;
    if ( lc $ping eq 'on' ) {
        unless ( &main::net_ping($server) ) {
            print "Can not ping mail server: $server\n";
            print " email check aborted\n";
            return;
        }
    }

    my $timeout = $main::config_parms{ $account . "_timeout" };
    $timeout = 20 unless $timeout;

    use Net::POP3;
    print "net_mail_login to $server\n" if $parms{debug};
    unless (
        $pop = Net::POP3->new(
            $server,
            Timeout => $timeout,
            Port    => $port,
            Debug   => $parms{debug}
        )
      )
    {
        print "Can not open connection to $server $port: $@\n";
        return;
    }

    #   unless ($pop->apop($user, $password)) {   ... avoids plain text password across network by using MD5 ... not installed yet
    my $msgcnt;
    unless ( defined( $msgcnt = $pop->login( $user, $password ) ) ) {
        print "Can not login to $server $port as $user: $@\n";
        return;
    }

    return $pop;

}

sub main::net_mail_stats {
    my %parms = @_;
    return unless my $pop = &main::net_mail_login(%parms);

    my ( $msgcnt, $msgsize ) = $pop->popstat;

    #   print "There are $msgcnt messages in $msgsize bytes on $server\n";

    #   my $msglast= $pop->last;
    #   print "The last READ message is number $msglast\n";

    return ( $msgcnt, $msgsize );
}

sub main::net_mail_count {
    my %parms = @_;
    return unless my $pop = &main::net_mail_login(%parms);
    my ($msgcnt) = $pop->popstat;
    print "$msgcnt messages in mailbox $parms{account}\n"
      unless defined $parms{debug} and $parms{debug} == 0;

    return $msgcnt;
}

use Date::Parse;    # For str2time

sub main::net_mail_summary {

    my %parms = @_;
    return unless my $pop = &main::net_mail_login(%parms);

    #   print "Getting list of message sizes\n";
    #   unless ($messages = $pop->list) {
    #   print "Can not get list of messages: $!\n";
    #   return;
    #   }

    $parms{first} = 1       unless $parms{first};
    $parms{age}   = 24 * 60 unless $parms{age};
    ( $parms{last} ) = $pop->popstat unless $parms{last};

    $main::config_parms{net_mail_scan_size} = 2000
      unless $main::config_parms{net_mail_scan_size};

    my %msgdata;

    # Rather than
    #   foreach my $msgnum ($parms{first} .. $parms{last}) {
    my $msgnum = $parms{last};
    while ($msgnum) {
        print "getting msg $msgnum\n" if $main::Debug{net};
        my $msg_ptr =
          $pop->top( $msgnum, $main::config_parms{net_mail_scan_size} );
        my (
            $date,    $date_received, $from,        $from_name,
            $sender,  $to,            $cc,          $replyto,
            $subject, $header,        $header_flag, $body
        );
        $header_flag = 1;
        my $i = 0;
        for (@$msg_ptr) {
            last if $i++ > 200;    # The scan_size parm above doesn't work?

            #           print "dbx net_mail_summary hf=$header_flag r=$_\n" if $_ =~ /winter/i or $to =~ /winter/;
            if ($header_flag) {

                #               chomp;
                $date    = $1 if !$date    and /^Date:(.+)/;
                $from    = $1 if !$from    and /^From:(.+)/;
                $sender  = $1 if !$sender  and /^Sender:(.+)/;
                $to      = $1 if !$to      and /^To:(.+)/;
                $cc      = $1 if !$cc      and /^Cc:(.+)/;
                $replyto = $1 if !$replyto and /^Reply-To:(.+)/;
                $subject = $1 if !$subject and /^Subject:(.+)/;
                $header .= $_;
                $header_flag = 0 if /^ *$/;

                # Assume first data is the received date
                #    ... ; Tue, 4 Dec 2001 10:21:48 -0600
                $date_received = $1
                  if !$date_received
                  and /(\S\S\S, \d+ \S\S\S \d+ \d\d:\d\d:\d\d) /;
            }
            else {
                $body .= $_;
            }
        }
        $date_received = $date unless $date_received;

        # Parse any unicode from headers...
        if ( $sender =~ m/=\?/ ) {
            print "Unicode detected. Decoding MIME-Header sender $sender to "
              if $parms{debug} or $main::Debug{net};
            $sender = decode( "MIME-Header", $sender );
            print "$sender.\n" if $parms{debug} or $main::Debug{net};
        }
        if ( $to =~ m/=\?/ ) {
            print "Unicode detected. Decoding MIME-Header to $to to "
              if $parms{debug} or $main::Debug{net};
            $to = decode( "MIME-Header", $to );
            print "$to.\n" if $parms{debug} or $main::Debug{net};
        }
        if ( $cc =~ m/=\?/ ) {
            print "Unicode detected. Decoding MIME-Header cc $cc to "
              if $parms{debug} or $main::Debug{net};
            $cc = decode( "MIME-Header", $cc );
            print "$cc.\n" if $parms{debug} or $main::Debug{net};
        }
        if ( $subject =~ m/=\?/ ) {
            print "Unicode detected. Decoding MIME-Header subject $subject to "
              if $parms{debug} or $main::Debug{net};
            $subject = decode( "MIME-Header", $subject );
            print "$subject.\n" if $parms{debug} or $main::Debug{net};
        }

        #special parse from so we can speak it out
        $from =~ s/\"//g;
        $from =~ s/^\s+//;    #remove spaces

        #parse two special cases:
        # '"last, first: org (sub-org)" <email@email.com>'
        #$' <email@email.com>'

        if ( $from =~ m/^\</ )
        { #just an email address with no friendly name, so just return the email address
            ($from_name) =
              $from =~ /^\<(.*)\>$/;    #remove < and > from email address
        }
        else {

            if ( $from =~ m/=\?/ ) {
                print "Unicode detected. Decoding MIME-Header from $from to "
                  if $parms{debug} or $main::Debug{net};
                $from = decode( "MIME-Header", $from );
                print "$from.\n" if $parms{debug} or $main::Debug{net};
            }

            # Process 'from' into speakable name
            #       ($from_name) = $from =~ /\((.+)\)/;  #remove this. I don't know why you'd want to just select text in ()?
            ($from_name) = $from =~ / *(.+?) *</;
            ($from_name) = $from =~ / *(\S+) *@/ unless $from_name;
            $from_name = $from
              unless $from_name;    # Sometimes @ is carried onto next record
            $from_name =~ tr/_/ /;

            #       $from_name =~ tr/"//;
            $from_name =~ s/\"//g;    # "first last"
            $from_name = "$2 $1" if $from_name =~ /(\S+), +(\S+)/; # last, first
            $from_name =~ s/://g;    #:'s have no place in an email address

            #       $from_name =~ s/ (\S)\. / $1 /;  # Drop the "." after middle initial abreviation.
            # Spammers blank this out, so no point in warning about it
        }
        print
          "Warning, net_mail_summary: No From name found: from=$from, header=$header\n"
          unless $from_name;

        my $age_msg = int( ( time - str2time($date_received) ) / 60 );
        print
          "Warning, net_mail_summary: age is negative: age=$age_msg, date=$date_received\n"
          if $age_msg < 0;

        print
          "msgnum=$msgnum  age=$age_msg date=$date_received from=$from sender=$sender to=$to subject=$subject\n"
          if $parms{debug} or $main::Debug{net};

        #       print "db m=$msgnum mf=$parms{first} a=$age_msg a=$parms{age} d=$date_received from=$from \n";
        if ( $age_msg <= $parms{age} ) {

            push( @{ $msgdata{date} },      $date );
            push( @{ $msgdata{received} },  $date_received );
            push( @{ $msgdata{to} },        $to );
            push( @{ $msgdata{cc} },        $cc );
            push( @{ $msgdata{replyto} },   $replyto );
            push( @{ $msgdata{sender} },    $sender );
            push( @{ $msgdata{from} },      $from );
            push( @{ $msgdata{from_name} }, $from_name );
            push( @{ $msgdata{subject} },   $subject );
            push( @{ $msgdata{header} },    $header );
            push( @{ $msgdata{body} },      $body );
            push( @{ $msgdata{number} },    $msgnum );

        }
        last if --$msgnum < $parms{first};
    }

    return \%msgdata;
}

sub main::net_mail_read {

    my %parms = @_;
    return unless my $pop = &main::net_mail_login(%parms);

    $parms{first} = 1 unless $parms{first};
    ( $parms{last} ) = $pop->popstat unless $parms{last};

    my @msgs = $parms{first} .. $parms{last};
    @msgs = split /[, ]/, $parms{msgnum} if $parms{msgnum};

    my @msgdata;
    for my $msgnum (@msgs) {
        print "net_mail_read reading msg $msgnum\n";
        my $msg_ptr = $pop->get($msgnum);
        push @msgdata, "@{$msg_ptr}";
    }
    return @msgdata;
}

# Dangerous method here!
sub main::net_mail_delete {

    my %parms = @_;
    return unless my $pop = &main::net_mail_login(%parms);

    $parms{first} = 1 unless $parms{first};
    ( $parms{last} ) = $pop->popstat unless $parms{last};

    my @msgdata;
    foreach my $msgnum ( $parms{first} .. $parms{last} ) {
        print "Deleting msg $msgnum\n";
        $pop->delete($msgnum);
    }
    $pop->quit;    # Need to logoff to delete
}

sub main::net_ping {
    my ( $host, $protocol ) = @_;
    use Net::Ping;

    # icmp requires root
    $protocol = $main::config_parms{ping_protocol}
      || $main::config_parms{net_ping_protocol};
    return 1 if $protocol eq 'none';
    $protocol = ( $> ? 'tcp' : 'icmp' ) unless $protocol;

    my $p;
    my $timeout = $main::config_parms{ping_timeout}
      || $main::config_parms{net_ping_timeout};
    if ( defined $timeout ) {

        # use the user-defined timeout
        print "Using a timeout of $timeout seconds for Net::Ping\n"
          if $main::Debug{ping};
        $p = Net::Ping->new( $protocol, $timeout );
    }
    else {
        # use the default timeout of Net::Ping (which is 5 seconds)
        print "Using Net::Ping's default timeout\n" if $main::Debug{ping};
        $p = Net::Ping->new($protocol);
    }

    return $p->ping($host);
}

# This method does not seem any faster, and requires another module, use Socket, so lets stick with IO::Socket
#
#sub main::net_socket_check {
#   use Socket;
#    my ($host_port, $protocol) = @_;
#    $protocol = 'tcp' unless $protocol;
#    my ($host, $port) = $host_port =~ /(\S+)\:(\S+)/;
#    print "net_socket_check: checking $protocol host=$host port=$port\n" if $main::Debug{socket};
#    my $proto = getprotobyname($protocol);
#    my $iaddr = inet_aton $host or print "net_socket_check error, could not find host=$host: $!\n";
#    my $paddr = sockaddr_in($port, $iaddr);
#    socket(SOCK, PF_INET, SOCK_STREAM, $proto) or print "net_socket_error, Could not open socket: $!";
#    my $connect = connect(SOCK, $paddr);
#    close SOCK;
#    print "net_socket_check: $protocol host=$host port=$port connect=$connect\n" if $main::Debug{socket};
#    return $connect;
#}

sub main::net_socket_check {
    my ( $host_port, $protocol ) = @_;
    $protocol = 'tcp' unless $protocol;
    my ( $host, $port ) = $host_port =~ /(\S+)\:(\S+)/;
    if ($port) {
        print "socket_check testing to $protocol on host=$host port=$port\n"
          if $main::Debug{socket};
        if (
            my $sock = new IO::Socket::INET->new(
                PeerAddr => $host,
                PeerPort => $port,
                Proto    => $protocol,
                Timeout  => 0
            )
          )
        {
            return 1;
        }
        else {
            print
              "socket_check:  $protocol port is down on host=$host port=$port: $@\n"
              if $main::Debug{socket};
            return 0;
        }
    }
    else {
        print
          "socket_check error:  address is not in the host:port form.  address=$host_port\n";
        return 0;
    }
}

sub main::url_last_modified {
    my $url = shift;
    my $ua  = LWP::UserAgent->new();
    my $rq  = HTTP::Request->new( HEAD => $url );
    my $rp  = $ua->request($rq);
    if ($rp) {
        print $rp->last_modified if $main::Debug{http};
        return &time2str( $rp->last_modified );
    }
    else {
        return 'Not known';
    }
}

sub main::url_changed {
    my ( $url, $name ) = @_;
    $name = substr( $url, 7 ) unless $name;
    my $previous_modified = $main::Save{"url_date:$name"};
    my $last_modified     = &main::get_last_modified($url);
    if ( $previous_modified ne $last_modified ) {
        $main::Save{"url_date:$name"} = $last_modified;
        return 1;
    }
    else {
        return;
    }
}

1;

#
# $Log: handy_net_utilities.pl,v $
# Revision 1.66  2006/01/29 20:30:17  winter
# *** empty log message ***
#
# Revision 1.65  2005/12/21 15:19:23  mattrwilliams
# Added AIM/ICQ buddy icon capability.
# Added hooks for AOL/ICQ connection being lost.
#
# Revision 1.64  2005/10/02 19:27:53  mattrwilliams
# - added more callbacks for OSCAR object
# - added ICQ compatibility (I think - untested)
#
# Revision 1.63  2005/10/02 17:24:47  winter
# *** empty log message ***
#
# Revision 1.61  2005/01/23 23:21:45  winter
# *** empty log message ***
#
# Revision 1.60  2004/11/22 22:57:26  winter
# *** empty log message ***
#
# Revision 1.59  2004/09/25 20:01:19  winter
# *** empty log message ***
#
# Revision 1.58  2004/07/30 23:26:38  winter
# *** empty log message ***
#
# Revision 1.57  2004/05/02 22:22:17  winter
# *** empty log message ***
#
# Revision 1.56  2004/04/25 18:20:00  winter
# *** empty log message ***
#
# Revision 1.55  2004/03/23 01:58:08  winter
# *** empty log message ***
#
# Revision 1.54  2004/02/01 19:24:35  winter
#  - 2.87 release
#
# Revision 1.53  2003/12/22 00:25:06  winter
#  - 2.86 release
#
# Revision 1.52  2003/11/23 20:26:01  winter
#  - 2.84 release
#
#
#  Mod by Pete Flaherty for Autenticated SMTP 09/12/03
#  with lots of great help from Ross Towbin
#  Requires Net:SMTP_auth , Authen::SASL
#
# Revision 1.51  2003/09/02 02:48:46  winter
#  - 2.83 release
#
# Revision 1.50  2003/07/06 17:55:11  winter
#  - 2.82 release
#
# Revision 1.49  2003/04/20 21:44:08  winter
#  - 2.80 release
#
# Revision 1.48  2003/02/08 05:29:24  winter
#  - 2.78 release
#
# Revision 1.47  2003/01/12 20:39:21  winter
#  - 2.76 release
#
# Revision 1.46  2002/12/24 03:05:08  winter
# - 2.75 release
#
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
