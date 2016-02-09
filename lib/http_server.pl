#---------------------------------------------------------------------------
#  This lib provides the mister house web server routines
#  Change log is at the bottom
#---------------------------------------------------------------------------
# $Date$
# $Revision$

use strict;
use Text::ParseWords;
require 'http_utils.pl';

#no warnings 'uninitialized';   # These seem to always show up.  Dang, will not work with 5.0

use vars
  qw(%Http %Cookies %Included_HTML %HTTP_ARGV $HTTP_REQUEST $HTTP_BODY $HTTP_REQ_TYPE);
$Authorized = 0;

my ( $leave_socket_open_passes, $leave_socket_open_action );
my ( $Cookie, $H_Response, $html_pointer_cnt, %html_pointers );

my %mime_types = (
    'htm'   => 'text/html',
    'html'  => 'text/html',
    'shtml' => 'text/html',
    'sht'   => 'text/html',
    'pl'    => 'text/html',
    'vxml'  => 'text/html',
    'xml'   => 'text/xml',
    'xsl'   => 'text/xml',
    'xslt'  => 'text/xml',
    'sxml'  => 'text/xml',
    'txt'   => 'text/plain',

    #                 'htc'   => 'text/plain',
    'css'   => 'text/css',
    'png'   => 'image/png',
    'gif'   => 'image/gif',
    'ico'   => 'image/gif',
    'jpg'   => 'image/jpeg',
    'jpeg'  => 'image/jpeg',
    'js'    => 'application/x-javascript',
    'sjs'   => 'application/x-javascript',
    'wbmp'  => 'image/vnd.wap.wbmp',
    'bmp'   => 'image/bmp',
    'au'    => 'audio/basic',
    'pls'   => 'audio/x-scpls',
    'm3u'   => 'audio/x-scpls',
    'snd'   => 'audio/basic',
    'wav'   => 'audio/x-wav',
    'mp3'   => 'audio/x-mp3',
    'ogm'   => 'application/ogg',
    'mjpg'  => 'video/x-motion-jpeg',
    'wml'   => 'text/vnd.wap.wml',
    'wmls'  => 'text/vnd.wap.wmlscript',
    'wmlc'  => 'application/vnd.wap.wmlc',
    'wmlsc' => 'application/vnd.wap.wmlscriptc',
    'wrl'   => 'x-world/x-vrml',
    'json'  => 'application/json',
);

my ( %http_dirs, %html_icons, $html_info_overlib, %password_protect_dirs,
    %http_agent_formats, %http_agent_sizes );

my ( $http_fork_mem, $http_fork_page, $http_fork_count );

if ( $config_parms{http_fork} eq 'memmap' ) {
    $http_fork_mem  = new Win32::MemMap;
    $http_fork_page = $http_fork_mem->GetGranularitySize();
}

sub http_read_parms {

    # Old style:  html_alias_tv = /tv   $config_parms{data_dir}/tv
    # New style:  html_alias_tv =       $config_parms{data_dir}/tv
    for my $parm ( keys %main::config_parms ) {
        next if $parm =~ /_MHINTERNAL_/;
        next unless $parm =~ /^html_alias(\d*)_(\S+)/;
        my $alias = '/' . $2;
        my $dir   = $main::config_parms{$parm};

        # Allow for old style alias (with blanks in dir name)
        if ( $dir =~ /(\S+)\s+(\S+)/ ) {
            $alias = $1;
            $dir   = $2;
        }
        print " - html alias: $parm $alias => $dir\n" if $main::Debug{http};

        # If we have multiple alias, the last one wins
        if ( -d $dir ) {
            unshift @{ $http_dirs{$alias} }, $dir;
        }
        else {
            print "   html_alias alias $alias dir does not exist, dir=$dir\n";
        }
    }

    $html_info_overlib = 1
      if $main::config_parms{html_info}
      and $main::config_parms{html_info} =~ 'overlib';

    #   $config_parms{http_fork} = 1 if ($config_parms{http_fork} ne '0') and (!$OS_win or $OS_win and Win32::IsWinNT);
    $config_parms{http_fork} = 1
      if ( $config_parms{http_fork} eq '' )
      and ( !$OS_win or $OS_win and Win32::IsWinNT );

    $main::config_parms{http_client_timeout} = 0.5
      unless $main::config_parms{http_client_timeout};

    #html_user_agents    = Windows CE=>1,whatever=>2
    &read_parm_hash( \%http_agent_formats,
        $main::config_parms{html_browser_formats}, 1 );
    &read_parm_hash( \%http_agent_sizes,
        $main::config_parms{html_browser_sizes}, 1 );

    undef %html_icons;       # Refresh lib/http_server.pl icons
    undef %Included_HTML;    # These should get re-created on $Reload

    %password_protect_dirs = map { $_, 1 } split ',',
      $main::config_parms{password_protect_dirs};

    # Set defaults for all html_ parms for alternate browser user-agent web_formats

    for my $parm ( grep /^html_.*[^\d]$/, keys %main::config_parms ) {
        next if $parm =~ /_MHINTERNAL_/;
        next if $parm =~ /^html_alias/;
        $main::config_parms{ $parm . '1' } = $main::config_parms{$parm}
          unless exists $main::config_parms{ $parm . '1' };
        $main::config_parms{ $parm . '2' } = $main::config_parms{$parm}
          unless exists $main::config_parms{ $parm . '2' };
        $main::config_parms{ $parm . '3' } = $main::config_parms{$parm}
          unless exists $main::config_parms{ $parm . '3' };
    }

}

sub http_process_request {
    my ($socket) = @_;

    my $time_check = time;

    $leave_socket_open_passes = 0;
    $leave_socket_open_action = '';
    $socket_fork_data{length} = 0;

    my ( $header, $text, $h_response, $h_index, $h_list, $item, $state );
    $H_Response = 'last_response';

    # Find ip address (used to bypass password check)
    my $peer = $socket->peername;
    my ( $port, $iaddr ) = unpack_sockaddr_in($peer) if $peer;
    my $client_ip_address = inet_ntoa($iaddr) if $iaddr;
    $Socket_Ports{http}{client_ip_address} = $client_ip_address;

    $Authorized = &password_check( undef, 'http' );  # Returns authorized userid
    print
      "----------\nhttp: client_ip=$Socket_Ports{http}{client_ip_address} a=$Authorized.\n"
      if $main::Debug{http};

    # Read http header data
    $Cookie = '';
    undef %Cookies;
    undef %Http;
    my $temp;

    # Must wait for the new socket to become active
    my $nfound =
      &socket_has_data( $socket, $main::config_parms{http_client_timeout} );
    return unless $nfound > 0;    # nfound == -1 means an error
    while (1) {
        $_ = <$socket>;
        last unless $_ and /\S/;
        $temp .= $_;
        if (/^ *(GET|POST|PUT) /) {
            $header = $_;
        }
        elsif ( my ( $key, $value ) = /(\S+?)\: ?(.+?)[\n\r]+/ ) {
            $Http{$key} = $value;
            print "http:   header key=$key value=$value.\n"
              if $main::Debug{http2};
        }
    }
    unless ($header) {

        # Ignore empty requests, like from 'check the http server' command
        print "http: Error, not header request.  header=$temp\n"
          if $main::Debug{http} and $temp;
        return;
    }

    $Socket_Ports{http}{data_record} = $header;

    $Http{loop} =
      $Loop_Count;    # Track which pass we last processes a web request
    $Http{request} = $header;
    $Http{Referer} = '' unless $Http{Referer};    # Avoid uninitilized var errors
    ( $Http{Host_address} ) = $Http{Host} =~ /([^\:]+)/
      if $Http{Host};    # Drop the port, if present
    $Http{Client_address} = $Socket_Ports{http}{client_ip_address};

    if ( $Http{Cookie} ) {
        for my $key_value ( split ';', $Http{Cookie} ) {
            my ( $key2, $value2 ) = $key_value =~ /(\S+)=(\S+)/;
            $Cookies{$key2} = $value2 if defined $value2;
        }
    }
    if ( $Http{Authorization} ) {
        if ( $Http{Authorization} =~ /Basic (\S+)/ ) {
            my ( $user, $password ) = split( ':', &uudecode($1) );
            $Authorized = &password_check( $password, 'http' );
        }
    }

    # Look at type of browser, via User-Agent key
    # Some examples
    #Agent: Mozilla/4.0 (compatible; MSIE 4.01; Windows NT Windows CE)
    #Agent: Mozilla/4.0 (compatible; MSIE 5.5; Windows NT 5.0)
    #Agent: Mozilla/4.0 (compatible; MSIE 5.5; Windows NT 4.0; BCD2000)
    #Agent: Mozilla/4.0 (compatible; MSIE 6.0b; Windows NT 5.1)
    #Agent: Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; Q312461; .NET CLR 1.0.3705)
    #Agent: Mozilla/4.61 [en] (Win98; I)
    #Agent: Mozilla/4.76 [en] (Windows NT 5.0; U)
    #Agent: Mozilla/4.7 [en] (X11; I; Linux 2.2.14-15mdk i686)
    #Agent: Mozilla/4.76 [en] (X11; U; Linux 2.2.16-22jjg i686)
    #Agent: Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:0.9.4) Gecko/20011128 Netscape6/6.2.1
    #Audrey:     Mozilla/4.7 (Win98; Audrey)
    #Compaq IA1: Mozilla/4.0 (compatible; MSIE 4.01; Windows CE; MSN Companion 2.0; 800x600; Compaq).
    #Aquapad:    Mozilla/4.0 (compatible; MSIE 4.01; Windows NT Windows CE)
    #Opera: Mozilla/4.0 (compatible; MSIE 5.0; Linux 2.4.6-rmk1-np2-embedix armv4l; 240x320) Opera 5.0  [en]
    #iPhone: Mozilla/5.0 (iPhone; CPU iPhone OS 8_1_3 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B466 Safari/600.1.4

    my $ia7_enable = 'none';
    $ia7_enable = $main::config_parms{'ia7_enable'}
      if defined $main::config_parms{'ia7_enable'};
    my $mobile_html    = 0;
    my $modern_browser = 0;
    if (   ( $Http{'User-Agent'} =~ /iPhone/i )
        or ( $Http{'User-Agent'} =~ /Android/i ) )
    {
        $mobile_html = 1;
    }
    if (   ( $Http{'User-Agent'} =~ /AppleWebKit/i )
        or ( $Http{'User-Agent'} =~ /Chrome/i )
        or ( $Http{'User-Agent'} =~ /Gecko/i )
        or ( $Http{'User-Agent'} =~ /iPad/i ) )
    {
        $modern_browser = 1;
    }

    #   print "db ua=$Http{'User-Agent'}\n";
    if ( $Http{'User-Agent'} ) {
        $Http{'User-Agent-Size'} = $1
          if $Http{'User-Agent'} =~ /\d{2,}x(\d){2,}/;
        if ( $Http{'User-Agent'} =~ /Windows CE/i ) {
            $Http{'User-Agent'} = 'MSCE';
            $modern_browser = 0;
        }
        elsif ( $Http{'User-Agent'} =~ /Audrey/i ) {
            $Http{'User-Agent'} = 'Audrey';
            $modern_browser = 0;
        }
        elsif ( $Http{'User-Agent'} =~ /Photon/i ) {
            $Http{'User-Agent'} = 'Photon';
            $modern_browser = 0;
        }
        elsif ( $Http{'User-Agent'} =~ /MSIE/i ) {
            $Http{'User-Agent'} = 'MSIE';
        }
        elsif ( $Http{'User-Agent'} =~ /Netscape6/i ) {
            $Http{'User-Agent'} = 'Netscape6';
            $modern_browser = 0;
        }
        elsif ( $Http{'User-Agent'} =~ /Mozilla/i ) {
            $Http{'User-Agent'} = 'Mozilla';
        }
        elsif ( $Http{'User-Agent'} =~ /embedix/i ) {
            $Http{'User-Agent'} = 'Zaurus';
            $modern_browser = 0;
        }
        elsif ( $Http{'User-Agent'} =~ /Opera/i ) {
            $Http{'User-Agent'} = 'Opera';
        }
    }
    else {
        $Http{'User-Agent'} = '';
        $modern_browser = 0;
    }

    $Http{format} = '';
    if ( $config_parms{web_format} and $config_parms{web_format} =~ /^\d$/ ) {
        $Http{format} = $config_parms{web_format};
    }
    else {
        $Http{format} = $http_agent_formats{ $Http{'User-Agent'} }
          if $http_agent_formats{ $Http{'User-Agent'} };
    }

    #   if ($config_parms{password_menu} eq 'html' and $Password and $Cookies{password}) {
    #       $Authorized = ($Cookies{password} eq $Password) ? 1 : 0
    if ( $config_parms{password_menu} eq 'html' ) {
        $Authorized = &password_check( $Cookies{password}, 'http', 'crypted' );
    }

    my ( $req_typ, $get_req, $get_arg ) =
      $header =~ m|^(GET\|POST\|PUT) (\/[^ \?]*)\??(\S+)? HTTP|;
    $get_arg = '' unless defined $get_arg;
    $HTTP_REQ_TYPE = $req_typ;

    $get_arg =~ s/(.*)\&__async.*/$1/; # RaK: Fast hack to ensure async requests

    logit "$config_parms{data_dir}/logs/server_header.$Year_Month_Now.log",
      "$header data:$temp"
      if $main::Debug{http};
    print "http: gr=$get_req ga=$get_arg "
      . "A=$Authorized format=$Http{format} ua=$Http{'User-Agent'} h=$header"
      if $main::Debug{http};
    if ( $req_typ eq "POST" || $req_typ eq "PUT" ) {
        my $cl = $Http{'Content-Length'}
          || $Http{'Content-length'};    # Netscape uses lower case l
        print "http POST query has $cl bytes of args\n" if $main::Debug{http};
        my $buf;
        read $socket, $buf, $cl;

        # Save the body into the global var
        $HTTP_BODY = $buf;

        # This is a bad practice to merge the body and arguments together as the
        # body may not always contain an argument string.  It may contain JSON
        # data, binary data, or anything.
        # Since I can't figure out if any bad code relies on merging the body
        # into the arguments, the following regex tests if the body is a valid
        # argument string.  If it is, the body is merged.
        if ( $buf =~ /^([-\+=&;%@.\w_]*)\s*$/ ) {
            $get_arg .= "&" if ( $get_arg ne '' );
            $get_arg .= $buf;
        }

        #       shutdown($socket->fileno(), 0);   # "how":  0=no more receives, 1=sends, 2=both
    }

    if ( !$get_req or $get_req eq '/' ) {
        $get_req = $main::config_parms{ 'html_file' . $Http{format} };
        $get_req = '/ia7/'
          if ( ( ( lc $ia7_enable eq "mobile" ) or ( lc $ia7_enable eq "all" ) )
            and $mobile_html );
        $get_req = '/ia7/'
          if ( ( lc $ia7_enable eq "all" ) and $modern_browser );

        $get_req = '/' . $get_req
          unless $get_req =~ /^\//;    # Leading / is optional
        my $referer = "http://$Http{Host}";

        # Some browsers (e.g. Audrey) do not echo port in Host data
        #       $referer .= ":$config_parms{http_port}" if $config_parms{http_port} and $referer !~ /$config_parms{http_port}$/;
        $referer .= ":$config_parms{http_port}"
          if $config_parms{http_port} and $referer !~ /\:\d+$/;
        $referer .= $get_req;
        print $socket &http_redirect($referer);
        return;
    }

    logit "$config_parms{data_dir}/logs/server_http.$Year_Month_Now.log",
      "$Socket_Ports{http}{client_ip_address} $get_req $get_arg"
      unless $config_parms{no_log} =~ /http_local/ and &is_local_address();

    #
    # Split out the arguments into a hash and make them available so they're
    # available to our shtml and pl files directly from the %HTTP_ARGV hash
    #
    # URL is something like
    # http://your.misterhouse.server/dir/page?var1=val1&var2=val2
    # so $get_arg should contain:  var1=val1&var2=val2
    #

    # Clear any previous arguments
    %HTTP_ARGV = ();
    if ($get_arg) {

        # Split the pairs apart first
        # $pairs[0]="var1=val1", $pairs[1]="var2=val2", etc
        my @pairs = split( /&/, $get_arg );

        # Now split each individual pair and store in the hash
        foreach my $pair (@pairs) {
            my ( $name, $value ) = $pair =~ /(.*?)=(.*)/;
            if ($value) {
                $value =~ tr/\+/ /;    # translate + back to spaces
                $value =~ s/%([0-9a-fA-F]{2})/pack("C",hex($1))/ge;

                # Store in hash
                $HTTP_ARGV{$name} = $value;
            }
        }
    }

    $get_arg =~
      tr/\+/ /;    # translate + back to spaces (e.g. code search tk widget)
     # Real + will be in %## form (e.g. /SET;&html_list(X10_Item)?$test_house2?%2B15)

    $get_arg =~ s/\&/&&/g
      ;    # translate & to &&, since we translate %##  to & before splitting

    # translate from %## back to real characters
    # Ascii table: http://www.bbsinc.com/symbol.html
    #  - get_req may have h_response with %## chars in it
    $get_req =~ s/%([0-9a-fA-F]{2})/pack("C",hex($1))/ge;
    $get_req =~ s!//!/!g;    # remove double slashes in request

    $HTTP_REQUEST =
      $get_req; # copy get_req to globally (i.e. in scripts) accessible variable

    $get_arg =~ s/%([0-9a-fA-F]{2})/pack("C",hex($1))/ge;

    #   print "http: gr=$get_req ga=$get_arg\n" if $main::Debug{http};

    # Store so that include files have access to parent args
    $ENV{HTTP_QUERY_STRING} = $get_arg;

    # Prompt for password (SET_PASSWORD) and allow for UNSET_PASSWORD
    if ( $get_req =~ /SET_PASSWORD$/ ) {
        if ( $config_parms{password_menu} eq 'html' ) {
            if ( $get_req =~ /^\/UNSET_PASSWORD$/ ) {
                $Authorized = 0;
                $Cookie .= "Set-Cookie: password=xyz ; ; path=/;\n";
            }
            my $html = &html_authorized;
            $html .= "<br>Refresh: <a target='_top' href='/'> Main Page</a>\n";
            $html .= &html_password('') . '<br>';
            print $socket &html_page( undef, $html, undef, undef, undef,
                undef );
        }
        else {
            my $html = &html_authorized;
            $html .= "<br>Refresh: <a target='_top' href='/'> Main Page</a>\n";

            #           $html .= &html_reload_link('/', 'Refresh Main Page');   # Does not force reload?
            my ( $name, $name_short ) = &net_domain_name('http');
            if ( $Authorized and $get_req =~ /\/SET_PASSWORD$/ ) {
                &print_log(
                    "Password was just accepted for User [$Authorized] browser $name"
                );

                # Speak calls cause problems with speak hooks, like in the audrey code
                #               &speak("app=admin $Authorized password accepted for $name_short");
                $html .= "<br><b>$Authorized password accepted</b>";
                print $socket &html_page( undef, $html );
            }
            else {
                # No good way to un-Authorized here, so just re-do the pop-up window till it gives up?
                #               print "dbx requestor=$name, get_req=$get_req, Authorized=$Authorized\n";
                print $socket &html_password('');
                print $socket &html_page( undef,
                    "requestor=$name, get_req=$get_req, Authorized=$Authorized"
                );
            }
        }
        return;
    }

    # Process the html password form
    elsif ( $get_req =~ /\/SET_PASSWORD_FORM$/ ) {
        my ($password) = $get_arg =~ /password=(\S+)/;
        my ($html);
        my ( $name, $name_short )       = &net_domain_name('http');
        my ( $user, $password_crypted ) = &password_check2($password);
        $Authorized = $user if $password_crypted;
        $html .= &html_authorized;
        $html .= "<br>Refresh: <a target='_top' href='/'> Main Page</a>\n";

        #       $html .= &html_reload_link('/', 'Refresh Main Page');
        $html .= &html_password('');
        if ($password_crypted) {
            $Cookie .= "Set-Cookie: password=$password_crypted; ; path=/\n"
              if $password_crypted;

            # Refresh the main page
            $html .= "<b>$user password accepted</b>";

            #           $html = $Http{Referer}; # &html_page will use referer if only a url is given
            $html =~ s/\/SET_PASSWORD.*//;
            &print_log(
                "Password was just accepted for User [$user] browser $name");

            #           &speak("app=admin $user password accepted for $name_short");
        }
        else {
            $Authorized = 0;
            $html   .= "<b>Password was incorrect</b>\n";
            $Cookie .= "Set-Cookie: password=xyz ; ; path=/;\n";
            $Cookies{password_was_not_valid}++
              ;    # So we can monitor from user code
            &print_log("Password was just NOT set; $name");
            &play( file => 'unauthorized' );    # Defined in event_sounds.pl

            #           &speak("app=admin Password NOT set by $name_short");
        }
        print $socket &html_page( undef, $html );
        return;
    }

    elsif ( !$Authorized and lc $main::config_parms{password_protect} eq 'all' )
    {
        if ( $get_req =~ /wml/ ) {
            print $socket &html_password('browser')
              ;    # wml requires browser login ... no form/cookies for now
        }
        else {
            $h_response =
              "<center><h3>MisterHouse password_protect set to all.  Password required for all functions</h3>\n";
            $h_response .= "<h3><a href=/SET_PASSWORD>Login</a></h3></center>";
            print $socket &html_page( "", $h_response );
        }
        return;
    }

    # See if the request was for a file
    if ( &test_for_file( $socket, $get_req, $get_arg ) ) {
    }
    elsif ( $get_req =~ /^\/JSON/i ) {
        &print_socket_fork( $socket, json() );
    }

    # Test for RUN commands
    elsif ($get_req =~ /\/RUN$/i
        or $get_req =~ /\/RUN[\:\;](\S*)$/i )
    {
        $h_response = $1;

        if ($get_arg) {
            $get_arg =~
              s/select_cmd=//;    # Drop the cmd=  prefix from form lists.
            $get_arg =~ tr/\_/ /; # Put blanks back
            $get_arg =~ tr/\~/_/; # Put _ back
             # Drop the &&x=n&&y=n that is tacked on (before or after) when doing image form submits
             # Do the same in SET below
            $get_arg =~ s/&&x=\d+&&y=\d+//;
            $get_arg =~ s/x=\d+&&y=\d+&&//;

            # From DN: /SET;referer %24pvr_text=Glick&%24pvr_up.x=6&%24pvr_up.y=6
            $get_arg =~ s/\.x=/_x=/;
            $get_arg =~ s/\.y=/_y=/;
        }

        my ($ref) = &Voice_Cmd::voice_item_by_text( lc($get_arg) );
        my $authority = $ref->get_authority if $ref;
        $authority = $Password_Allow{$get_arg} unless $authority;

        print
          "http: RUN a=$Authorized,$authority get_arg=$get_arg response=$h_response\n"
          if $main::Debug{http};

        if ( $Authorized or ( $authority and $authority eq 'anyone' ) ) {

            # Allow for RUN;&func  (response function like &dir_sort, with no action)
            if ( !$get_arg ) {
                &html_response( $socket, $h_response );
            }
            elsif (
                &run_voice_cmd( $get_arg, undef, "web [$client_ip_address]" ) )
            {
                &html_response( $socket, $h_response );
            }
            else {
                my $msg = "The Web RUN command not found: $get_arg.\n";
                $msg = "Pick a command state from the pull down on the right"
                  if $get_arg eq 'pick a state msg';

                #               print $socket &html_page("", $msg, undef, undef, "control");
                print $socket &html_page( "", "<br><b>$msg</b>" );
                print_log $msg;
            }
        }
        else {
            print $socket &html_page( "",
                &html_unauthorized( $get_arg, $h_response ) );
        }
    }

    # Test for subroutine call.  Note we can have both a SUB action and a SUB response
    elsif ($get_req =~ /\/SUB$/i
        or $get_req =~ /\/SUB[\:\;](.*)$/i )
    {
        $h_response = $1;

        # Run the subroutine (if authorized)
        my ( $msg, $action ) = &html_sub( $get_arg, 1 );
        if ($msg) {
            print $socket &html_page( "", $msg );
            return;    # No need anything else ?
        }
        elsif ($action) {
            my $response = eval $action;
            print "\nError in html SUB: $@\n" if $@;

            # Check for a response sub
            if ( my ( $msg, $action ) = &html_sub($response) ) {
                if ($msg) {
                    print $socket &html_page( "", $msg );
                }
                else {
                    $leave_socket_open_action = $action;
                    $leave_socket_open_passes = 3
                      ; # Wait a few passes, so multi-pass events can settle (e.g. barcode_web.pl)
                }
            }
            elsif ($response) {
                &print_socket_fork( $socket, $response );

                #               print $socket $response;
            }
            elsif ( !$h_response ) {
                $h_response = 'last_response';
            }
        }

        # Generate a response IF requested (i.e. no default)
        &html_response( $socket, $h_response ) if $h_response;
    }

    # Allow for either SET or SET_VAR
    elsif ($get_req =~ /\/SET(_VAR)?$/i
        or $get_req =~ /\/SET(_VAR)?[\:\;](\S*)$/i )
    {
        $h_response = $2;

        #       print "Error, no SET argument: $header\n" unless $get_arg;

        # Change select_item=$item&select_state=abc to $item=abc
        $get_arg =~ s/select_item=(\S+)\&&select_state=/$1=/;

        # Drop the &&x=n&&y=n that is tacked on (before or after) when doing image form submits
        # Do the same in RUN above
        # From DN: /SET;referer %24pvr_text=Glick&%24pvr_up.x=6&%24pvr_up.y=6
        $get_arg =~ s/&&x=\d+&&y=\d+//;
        $get_arg =~ s/x=\d+&&y=\d+&&//;
        $get_arg =~ s/\.x=/_x=/;
        $get_arg =~ s/\.y=/_y=/;

        # See if any variables require authorization
        my $authority = 1;
        unless ($Authorized) {
            for my $temp ( split( '&&', $get_arg ) ) {
                next unless ( $item, $state ) = $temp =~ /(\S+)[\?\=](.*)/;

                if ( $item =~ /^\d+$/ )
                {   # Can't do html_pointer yet ... need to switch to Tk objects
                    $authority = 0;
                    next;
                }

                # WAP pages don't allow for $ in url, so make it optional
                $item = "\$" . $item unless substr( $item, 0, 1 ) eq "\$";
                my $set_authority = eval
                  qq[$item->get_authority if $item and ref($item) and UNIVERSAL::isa($item, 'Generic_Item');];
                print "SET authority eval error: $@\n" if $@;
                unless ( $set_authority eq 'anyone'
                    or $Password_Allow{$item} eq 'anyone' )
                {
                    $authority = 0;
                    last;
                }
            }
        }

        print
          "SET a=$Authorized,$authority hr=$h_response get_req=$get_req  get_arg=$get_arg\n"
          if $main::Debug{http};

        if ( $Authorized or $authority ) {
            for my $temp ( split( '&&', $get_arg ) ) {

                # /s allows for multi-line arguments, like you get from textarea form elements
                ( $item, $state ) = $temp =~ /(\S+?)[\?\=](.*)/s;

                #               print "db i=$item s=$state a=$get_arg t=$temp\n";

                $state =~ s/\_/ /g;    # No blanks were allowed in a url
                $state =~ s/\~/_/g;    # Put _ back

                # If item name is only digits, this implies tk_widgets, where we used html_pointer_cnt as an index
                if ( $item =~ /^\d+$/ ) {
                    my $pvar = $html_pointers{$item};

                    # Allow for state objects
                    if ( $pvar and ref $pvar ne 'SCALAR' and $pvar->can('set') )
                    {
                        $pvar->set( $state, "web [$client_ip_address]" );
                    }
                    else {
                        $$pvar = $state;
                    }

                    # This gives uninitilzed errors ... not needed anymore?
                    #  - yep, needed till we switch widgets to objects
                    $Tk_results{ $html_pointers{ $item . "_label" } } = $state
                      if $html_pointers{ $item . "_label" };
                }

                # Otherwise, we are trying to pass var name in directly.
                else {
                    # WAP pages don't allow for $ in url, so make it optional
                    $item = "\$" . $item unless substr( $item, 0, 1 ) eq "\$";

                    # Can be a scalar or a object
                    $state =~ tr/\"/\'/;    # So we can use "" to quote it

                    #                   my $eval_cmd = qq[($item and ref($item) and UNIVERSAL::isa($item, 'Generic_Item')) ?
                    my $eval_cmd =
                      qq[($item and ref($item) ne '' and ref($item) ne 'SCALAR' and $item->can('set')) ?
                                      ($item->set("$state", "web [$client_ip_address]")) : ($item = "$state")];
                    print "SET eval: $eval_cmd\n" if $main::Debug{http};
                    eval $eval_cmd;
                    print "SET eval error.  cmd=$eval_cmd  error=$@\n" if $@;
                }
            }
            &html_response( $socket, $h_response );
        }
        else {
            if ( $h_response =~ /^last_/ ) {
                print $socket &html_page( "",
                    &html_unauthorized( $get_arg, $h_response ) );
            }
            else {
                # Just refresh the screen, don't give a bad boy msg
                #  - this way we don't mess up the Items display frame
                &html_response( $socket, $h_response, undef, undef );
            }
        }

    }

    # Test for ajax "long poll" subroutine call.  Note, the response option is not supported
    elsif ( $get_req =~ /\/LONG_POLL$/i ) {
        &html_ajax_long_poll( $socket, $get_req, $get_arg );
        $leave_socket_open_passes = -1;    # don't close the socket
        return:
    }

    # See if request was for an auto-generated page
    elsif ( my ( $html, $style ) = &html_mh_generated( $get_req, $get_arg, 1 ) )
    {
        my $time_check2 = time;
        &print_socket_fork( $socket, &html_page( "", $html, $style ) );

        #        print $socket &html_page("", $html, $style);
        $time_check2 = time - $time_check2;
        if ( $time_check2 > 2 ) {
            my $msg =
              "http_server write time exceeded: time=$time_check2, req=$get_req,$get_arg";

            #           print "\n$Time_Date: $msg";
            &print_log($msg);
        }
    }
    else {
        print
          "Unrecognized html request: get_req=$get_req get_arg=$get_arg  header=$header\n";

        $get_req .= "?$get_arg" if $get_arg;
        $Misc{missing_url} = $get_req;

        print $socket &http_redirect("/misc/failed_request.shtml");
    }

    $time_check = time - $time_check;
    if ( $time_check > $config_parms{http_pause_time} ) {
        my $msg =
          "http_server time exceeded $config_parms{http_pause_time} seconds: time=$time_check, lso=$leave_socket_open_passes, "
          . "l=$socket_fork_data{length}, ip=$Socket_Ports{http}{client_ip_address}, header=$header";
        logit "$config_parms{data_dir}/logs/mh_pause.$Year_Month_Now.log", $msg;
        print "\n$Time_Date: $msg\n";
        &print_log($msg);

        #       &speak("app=admin web sleep of $time_check seconds");
    }

    return ( $leave_socket_open_passes, $leave_socket_open_action );
}

sub html_password {
    my ($menu) = @_;
    $menu = $config_parms{password_menu} unless $menu;

    #   return $html_unauthorized unless $Authorized;

    my $html;
    if ( $menu eq 'html' ) {
        $html =
          qq[<BODY onLoad="self.focus();document.pw.password.focus(); top.frames[0].location.reload()">\n];

        #       $html .= qq[<BASE TARGET='_top'>\n];
        $html .= qq[<FORM name=pw action="SET_PASSWORD_FORM" method="post">\n];

        #       $html .= qq[<FORM name=pw action="SET_PASSWORD_FORM" method="get">\n]; ... get not secure from browser history list!!
        #       $html .= qq[<h3>Password:<INPUT size=10 name='password' type='password'></h3>\n</FORM>\n];
        $html .=
          qq[<b>Password:</b><INPUT size=10 name='password' type='password'>\n];
        $html .= qq[<INPUT type=submit value='Submit Password'>\n</FORM>\n];
        $html .=
          qq[<P> This form is used for logging into MisterHouse.<br> For administration please see the documentation of <a href="http://misterhouse.net/mh.html"> set_password </a></P>\n];
    }
    else {
        $html = qq[HTTP/1.0 401 Unauthorized\n];
        $html .= qq[Server: MisterHouse\n];
        $html .= qq[Content-type: text/html\n];
        $html .= qq[WWW-Authenticate: Basic realm="mh_control"\n];
    }
    return $html;
}

sub html_authorized {
    if ($Authorized) {
        return
          "Status: <b><a href=UNSET_PASSWORD>Logged In as $Authorized</a></b><br>";
    }
    else {
        return "Status: <b><a href=SET_PASSWORD>Not Logged In</a></b><br>";
    }
}

sub html_unauthorized {
    my ( $action, $h_response ) = @_;
    if ( $h_response =~ /vxml/ ) {
        return &vxml_page(
            audio => 'Sorry, you are not authorized for that command' );
    }
    else {
        #       my $msg = "<a href=speech>Refresh Recently Spoken Text</a><br>\n";
        my $msg .= &html_header(
            "<b>Unauthorized Mode</b>&nbsp;&nbsp;&nbsp;&nbsp;"
              . &html_authorized,
            $action
        );
        $msg .= "<li>" . $action . "</li>";
        $msg .=
          "<br>Status: <b><a href=SET_PASSWORD yet>Not Logged In</a></b></body></html>";
        return $msg;
    }
}

sub http_get_local_file {
    my ( $get_req, $get_alias_index ) = @_;
    my ( $file, $http_dir, $http_member );

    # Check for alias dirs for member name
    ( $http_dir, $http_member ) = $get_req =~ /^(\/[^\/]+)(.*)/;

    # Goofy audrey can add a / suffix to a file request
    $http_member =~ s|/$||;

    if ( $http_dir and $http_dirs{$http_dir} ) {

        # First one wins (last one in the mh.ini file)
        ALIAS_CHECK:
        for my $dir ( @{ $http_dirs{$http_dir} } ) {
            $file = "$dir/$http_member";

            # Check for dir index files
            if ( -d $file ) {
                last ALIAS_CHECK
                  unless $get_req =~ m|/$|;    # Force redirect in test_for_file
                if ($get_alias_index) {
                    my $dir = $file;
                    for my $default ( split ',',
                        $main::config_parms{ 'html_default' . $Http{format} } )
                    {
                        $file = "$dir/$default";
                        last ALIAS_CHECK if -e $file;
                    }
                }
                else {
                    last ALIAS_CHECK;          # Return dir
                }
            }
            else {
                last ALIAS_CHECK if -e $file;
            }
            undef $file;
        }
    }
    $file = "$main::config_parms{'html_dir' . $Http{format}}/$get_req"
      unless $file;

    # Goofy audrey can add a / suffix to a file request
    $file =~ s|/$|| unless -d $file;
    return ( $file, $http_dir ) if -e $file;
}

sub test_for_file {
    my ( $socket, $get_req, $get_arg, $no_header, $no_print ) = @_;

    $get_req =~ s!//!/!g;    # remove double slashes in request

    my ( $file, $http_dir ) = &http_get_local_file( $get_req, 1 );
    return 0 unless $file;

    # Check for index files in directory
    if ( -d $file ) {

        # If the url does not have a trailing /, redirect it, so
        # we can get browsers to work with relative links
        unless ( $get_req =~ m|/$| ) {
            my $referer = "http://$Http{Host}";

            # Some browsers (e.g. Audrey) do not echo port in Host data
            #           $referer .= ":$config_parms{http_port}" if $config_parms{http_port} and $referer !~ /$config_parms{http_port}$/;
            $referer .= ":$config_parms{http_port}"
              if $config_parms{http_port} and $referer !~ /\:/;
            $referer .= "$get_req/";
            print $socket &http_redirect($referer);
            print "test_for_file redirected to $referer\n"
              if $main::Debug{http};
            return 1;
        }

        my $dir = $file;
        for my $default ( split ',',
            $main::config_parms{ 'html_default' . $Http{format} } )
        {
            $file = "$dir/$default";
            last if -e $file;
        }
        unless ( -e $file ) {
            print $socket &html_page( "Error",
                "No index found for directory $get_req" );
            return 1;
        }
    }

    if ( -e $file ) {
        my $html = &html_file( $socket, $file, $get_arg, $no_header )
          if &test_file_req( $socket, $get_req, $http_dir );
        if ($no_print) {
            return $html;
        }
        else {
            &print_socket_fork( $socket, $html );
            return 1;
        }
    }
    else {
        return 0;    # No file found ... check for other types of http requests
    }
}

# Check for illicit or password protected dirs
sub test_file_req {
    my ( $socket, $get_req, $http_dir ) = @_;

    # Don't allow bad guys to go up the directory chain
    $get_req =~ s#/\./#/#g;    # /./ -> /
    $get_req =~ s#//+#/#g;     # // -> /
    1 while ( $get_req =~ s#/(?!\.\.)[^/]+/\.\.(/|$)#$1# );    # /foo/../ -> /
      # if there is a .. at this point, it's a bad thing. Also stop if path contains exploitable characters

    #   if ($get_req =~ m#/\.\.|[\|\`;><\000]# ) {
    if ( $get_req =~ m#\.\.|[\|\`;><\000]# ) {
        print $socket &html_page( "Error", "Access denied: $_[1]" );
        return 0;
    }

    # Verify the directory is not password protected
    if ( $http_dir and $password_protect_dirs{$http_dir} and !$Authorized ) {
        my $html =
          "<h4>Directory $http_dir requires Login password access</h4>\n";
        $html .= "<h4><a href=SET_PASSWORD>Login</a></h4>";

        #       print $socket &html_page('error', $html);
        print $socket $html;
        return 0;
    }

    #   print "test_file_req Clean request=$get_req\n" if $main::Debug{http};
    return 1;
}

sub html_mh_generated {
    my ( $get_req, $get_arg, $auto_refresh ) = @_;
    my $html = '';
    $html =
      qq[<META HTTP-EQUIV="REFRESH" CONTENT="$main::config_parms{'html_refresh_rate' . $Http{format}}; url=$get_req">\n]
      if $auto_refresh
      and $main::config_parms{ 'html_refresh_rate' . $Http{format} };

    # Allow for any of these $get_req forms:
    #    /dir/request
    #    /request
    #    request
    $get_req =~ s/^.*?([^\/]+)$/$1/;

    if ( $get_req =~ /^widgets$/ ) {
        return ( $html . &widgets('all'),
            $main::config_parms{ 'html_style_tk' . $Http{format} } );
    }
    elsif ( $get_req =~ /^widgets_type?$/ ) {
        $html .= &widgets('checkbutton');
        $html .= &widgets('radiobutton');
        $html .= &widgets('entry');
        return ( $html . $html,
            $main::config_parms{ 'html_style_tk' . $Http{format} } );
    }
    elsif ( $get_req =~ /^widgets_label$/ ) {
        return ( $html . &widgets('label'),
            $main::config_parms{ 'html_style_tk' . $Http{format} } );
    }
    elsif ( $get_req =~ /^widgets_entry$/ ) {
        return ( $html . &widgets('entry'),
            $main::config_parms{ 'html_style_tk' . $Http{format} } );
    }
    elsif ( $get_req =~ /^widgets_radiobutton$/ ) {
        return ( $html . &widgets('radiobutton'),
            $main::config_parms{ 'html_style_tk' . $Http{format} } );
    }
    elsif ( $get_req =~ /^widgets_checkbox$/ ) {
        return ( $html . &widgets('checkbutton'),
            $main::config_parms{ 'html_style_tk' . $Http{format} } );
    }
    elsif ( $get_req =~ /^vars_save$/ ) {
        return ( $html . &vars_save,
            $main::config_parms{ 'html_style_tk' . $Http{format} } );
    }
    elsif ( $get_req =~ /^vars_global$/ ) {
        return ( $html . &vars_global,
            $main::config_parms{ 'html_style_tk' . $Http{format} } );
    }

    # .html suffix is grandfathered in
    elsif ( $get_req =~ /^speech(.html)?$/ ) {
        return (&html_last_spoken);
    }
    elsif ( $get_req =~ /^print_log(.html)?$/ ) {
        return (&html_print_log);
    }
    elsif ( $get_req =~ /^error_log(.html)?$/ ) {
        return (&html_error_log);
    }
    elsif ( $get_req =~ /^category$/ ) {
        return ( &html_category,
            $main::config_parms{ 'html_style_category' . $Http{format} } );
    }
    elsif ( $get_req =~ /^groups$/ ) {
        return ( &html_groups,
            $main::config_parms{ 'html_style_category' . $Http{format} } );
    }
    elsif ( $get_req =~ /^items$/ ) {
        return ( &html_items,
            $main::config_parms{ 'html_style_category' . $Http{format} } );
    }
    elsif ( $get_req =~ /^list[\:\;]?(\S*)$/ ) {
        $H_Response = $1 if $1;
        $html = &html_list( $get_arg, $auto_refresh );

        #       $html .= "\n$Included_HTML{$get_arg}\n" if $Included_HTML{$get_arg} ;
        if ( $Included_HTML{$get_arg} ) {
            foreach ( split "\n", $Included_HTML{$get_arg} ) {
                $html .= shtml_include($_) . "\n";
            }
        }
        return ( $html,
            $main::config_parms{ 'html_style_list' . $Http{format} } );
    }
    elsif ( $get_req =~ /^results$/ ) {
        return ("<h2>Click on any item\n");
    }
    else {
        return;
    }
}

sub html_sub {
    my ( $data, $sub_required ) = @_;
    return unless $data;
    my ( $sub_name, $sub_arg, $sub_ref );

    $data = '&' . $data
      if $data
      and $data !~ /^&/;    # Avoid & character in the url ... messes up Tellme
    $data =~ s/\=\&+$//; # Goofy wapalizer (http://www.gelon.net) appends this??

    # Save ISMAP data: xyz(a,b)?1,2 -> xyz(a,b,1,2)
    if ( $data =~ /^(.+)\)\?(\d+),(\d+)$/ ) {
        $data = "$1,xy=$2|$3)";
    }

    # Allow for &sub1 and &sub1(args)
    if (   ( ( $sub_name, $sub_arg ) = $data =~ /\&([^\&]+?)\((.*)\)$/ )
        or ( ($sub_name) = $data =~ /^\&(\S+)$/ ) )
    {
        $sub_arg = '' unless defined $sub_arg;    # Avoid uninit warninng

        #       $sub_ref = \&{$sub_name};  # This does not work ... code refs are always auto-created :(
        #       if (defined $sub_ref) {

        # The %main:: array will have a glob for all subs (and vars)
        if ( $main::{$sub_name} ) {
            print
              "html_sub: a=$Authorized pa=$Password_Allow{'&$sub_name'} data=$data sn=$sub_name sa=$sub_arg sr=$sub_ref\n"
              if $main::Debug{http};

            # Check for authorization
            if (
                (
                       $Authorized
                    or $Password_Allow{"&$sub_name"}
                    and $Password_Allow{"&$sub_name"} eq 'anyone'
                )
              )
            {
                # If not quoted, split to multiple argument according to ,
                my @args = parse_line( ',', 0, $sub_arg );
                $sub_arg = join ',', map { "'$_'" } @args;
                return ( undef, "&$sub_name($sub_arg)" );
            }
            else {
                return (
                    "Web response function not authorized: &$sub_name $sub_arg"
                );
            }
        }
        else {
            return ("Web html function not found: &$sub_name $sub_ref")
              if $sub_required;
        }
    }
    return ("Web html function not parsed: $data") if $sub_required;
    return;    # Tell if test we failed
}

sub html_response {
    my ( $socket, $h_response ) = @_;
    my $file;

    print "http: html response: $h_response\n" if $main::Debug{http};
    if ($h_response) {
        if ( $h_response =~ /^last_response_?(\S*)/ ) {
            $Last_Response = '';

            # Wait for some sort of response ... need a way to
            # specify longer wait times on longer commands.
            # By default, we shouldn't put a long time here or
            # we way too many passes for the 'no response message'
            # from many commands that do not respond
            $leave_socket_open_passes = 3;
            $leave_socket_open_action =
              qq|&html_last_response('$Http{"User-Agent"}', $1)|;
        }
        elsif ( $h_response eq 'last_displayed' ) {
            $leave_socket_open_passes = 200;
            $leave_socket_open_action = "&html_last_displayed";
        }
        elsif ( $h_response eq 'last_spoken' ) {
            $leave_socket_open_passes = 3;
            $leave_socket_open_action =
              "&html_last_spoken";    # Only show the last spoken text

            #           $leave_socket_open_action = "&speak_log_last(1)"; # Only show the last spoken text
            #           $leave_socket_open_action = "&Voice_Text::last_spoken(1)"; # Only show the last spoken text
        }
        elsif ( $h_response =~ /^https?:\S+$/i or $h_response =~ /^reff?erer/i )
        {
            # Allow to use just the base part of the referer
            #  - some browsers (audrey) do not return full referer url :(
            #    so allow for referer(url)...
            if ( my ($rurl) = $h_response =~ /^reff?erer(\S+)/ ) {
                $Http{Referer} =~ m|(https?://\S+?)/|;
                $h_response = $1 . $rurl;
            }
            elsif ( $h_response =~ /^reff?erer/ ) {
                $h_response = $Http{Referer};
            }

            # Wait a few passes before refreshing page, in case mh states changed
            #           $leave_socket_open_action = "&http_redirect('$h_response')"; # mh uses &html_page, so this does not work
            $leave_socket_open_action = "'$h_response'"
              ;    # &html_page will use referer if only a url is given
            $leave_socket_open_passes = 3;
        }
        elsif ( my ( $msg, $action ) = &html_sub($h_response) ) {
            if ($msg) {
                print $socket &html_page( "", $msg );
            }
            else {
                $leave_socket_open_action = $action;
                $leave_socket_open_passes = 3
                  ; # Wait a few passes, so multi-pass events can settle (e.g. barcode_web.pl)
            }
        }
        elsif ( &test_for_file( $socket, $h_response ) ) {

            # Allow for files to be modified on the fly, so wait a pass
            #  ... naw, use &file_read if you need to wait (e.g. barcode_scan.shtml)
            #       elsif (-e ($file = "$main::config_parms{'html_dir' . $Http{format}}/$h_response")) {
            #           $leave_socket_open_passes = 200;
            #           &html_file($socket, $file, '', 1);
            #           $leave_socket_open_action = "&html_file(\$Socket_Ports{http}{socka}, '$file', '', 1)";
            #           $leave_socket_open_action = "file_read '$file')";
        }
        elsif ( $h_response eq 'no_response' ) {
            print $socket &html_no_response;
        }
        else {
            $h_response =~ tr/\_/ /;    # Put blanks back
            $h_response =~ tr/\~/_/;    # Put _ back
            print $socket &html_page( "", $h_response );
        }
    }

    # The default ... show last fews spoken phrases
    #  - don't set this big.  Many things will have no response
    #    so we don't want to wait for them.
    else {
        $leave_socket_open_passes = 3;
        $leave_socket_open_action = "&html_last_spoken";

    }
}

sub html_last_response {
    my ( $browser, $length ) = @_;
    my ( $last_response, $script, $style );
    $last_response = &last_response;
    $Last_Response = '' unless $Last_Response;

    if ( $Last_Response eq 'speak' ) {

        # Allow for MSagent
        if (    $browser =~ /^MS/
            and $Cookies{msagent}
            and $main::config_parms{ 'html_msagent_script' . $Http{format} } )
        {
            $script = file_read
              "$config_parms{'html_dir' . $Http{format}}/$config_parms{'html_msagent_script' . $Http{format}}";
            $script =~ s/<!-- *speak_text *-->/$last_response/;
        }
    }
    elsif ( $Last_Response eq 'print_log' ) {
        ( $last_response, $style ) = &html_print_log;
    }
    elsif ( !$last_response ) {
        $last_response =
          "<br><b>No response resulted from the last command</b>";
    }

    #   elsif ($Last_Response eq 'display') {
    else {
        $last_response =~ s/\n/\n<br>/g;    # Add breaks on newlines
    }

    $last_response = substr $last_response, 0, $length if $length;
    $style = "$main::config_parms{'html_style_speak' . $Http{format}}"
      unless $style;

    return ( $last_response, $style, $script );
}

sub http_speak_to_wav_start {
    my ( $tts_text, $voice, $compression ) = @_;

    # Try to To minimized the problem of multiple web browsers
    # talking at the same time by using a semi-random .wav file name
    my $wav_file = "http_server." . int( ( $Second * rand ) * 10000 ) . ".wav";

    # Skip if on the local box or empty text (why is empty text passed at all?)

    # webmute = undef => refers to the ini parameter.
    # webmute = 0     => makes it speak in the browser.
    # webmute = 1     => makes responses speak remotely
    # webmute = 2     => stops all generation of WAV files and remote speech and returns the last response as text (same as webmute=1, except no speech.)

    my $webmute;

    # This defaults to local speech
    $webmute = 1
      if ( $Socket_Ports{http}{client_ip_address} eq '127.0.0.1' )
      or !$tts_text;
    if ( exists $Cookies{webmute} ) {
        $webmute = $Cookies{webmute};
    }
    else {
        $webmute = 1 if $config_parms{webmute};
    }

    # 'always' overrides cookie unless it is display mode (2), which is inherently muted
    $webmute = 1 if $config_parms{webmute} eq 'always' && $webmute != 2;
    return 0 if $webmute == 1;

    $tts_text = substr( $tts_text, 0, 500 ) . '.  Stopped. Speech Truncated.'
      if length $tts_text > 500;
    ( $compression = ( &is_local_address() ) ? 'low' : 'high' )
      unless $compression;
    &Voice_Text::speak_text(
        voice       => $voice,
        to_file     => &html_alias('/cache') . "/$wav_file",
        text        => $tts_text,
        compression => $compression,
        async       => 1
    ) unless $webmute;

    # Some browsers (e.g. Audrey) do not echo port in Host data
    my $ref = "http://$Http{Host}";

    #   $ref .= ":$config_parms{http_port}" if $config_parms{http_port} and $ref !~/$config_parms{http_port}$/;
    $ref .= ":$config_parms{http_port}"
      if $config_parms{http_port} and $ref !~ /\:/;
    $ref .= "/cache/$wav_file";

    return $ref;
}

sub http_speak_to_wav_finish {
    my ( $tts_text, $wav_file ) = @_;

    my $html = $tts_text;

    # Create autoplay wav file
    # CLIENT            works with everything in theory
    # EMBED and BGSOUND works with IE (EMBED did not work with older IE)
    # EMBED and BGSOUND works with WINCE on Compaq IA1
    # EMBED             works with Audrey
    # EMBED             works with Netscape  (with plugin)
    # EMBED             works with Konqueror (with plugin)
    # Embed gives controls, BGSOUND is invisible
    # Volume, with and without %, does not work (at least not in IE or Audrey)

    if ($wav_file) {

        # Allow for different formats for different browsers
        my $format = $config_parms{ 'html_wav_format' . $Http{format} };

        # This seems clever, but seems not to work :(
        if ( $format =~ /frame/i ) {
            print "db h=$html wf=$wav_file\n";
            $html .= qq|
   <FRAMESET ROWS="99%,*">
   <NOFRAMES>
     This document must be viewed using a frame-enabled browser.
   </NOFRAMES>
     <FRAME SRC="$html">
     <FRAME SRC="$wav_file">
   </FRAMESET>
|;
        }    # This works!  :)
        elsif ( $format =~ /client/ ) {

            # Original audio code tested on all Windows and Mac versions of IE, Netscape, Mozilla, Firefox, Opera and AOL (including the IE3 version for the
            # Mac that supported VBScript)  In theory it should work on everything, everywhere (at least where WAV files are supported in some fashion.)
            # WAV portion added here to allow mh to talk to all sound-enabled clients
            # Tested snippet in IE6 with and without JavaScript and at restricted security levels

            $html .= qq@

<script language="JavaScript">

<!--

function tryObject(sMIMEType) {
	return (navigator.mimeTypes && navigator.mimeTypes[sMIMEType] && navigator.mimeTypes[sMIMEType].enabledPlugin)
}

function pluginSupported(sMIMEType, sClass) {
	if (VBScriptEnabled) return (ObjectVersion(sClass) > 0); else return tryObject(sMIMEType)
}

function backgroundSound(sURI, sID, sDescription, iLoop) {
	return ("<bgsound id=\\"" + sID + "\\" volume=\\"20\\" alt=\\"" + sDescription + "\\" src=\\"" + sURI + "\\"" + (defined(iLoop)?" loop=\\"" + iLoop +  "\\"":"") + "><" + "/bgsound>")
}

function defined(o) {
	return(typeof(o) != 'undefined')
}

function activeXBrowser() {
	return (VBScriptEnabled || !navigator.mimeTypes || !defined(navigator.mimeTypes.length) || (navigator.mimeTypes.length == 0))
}

function writeAudio(sURI, sDescription, sID, iLoop) {

	if (activeXBrowser()) {
		document.write(backgroundSound(sURI, sID, sDescription, iLoop));

	}
	else {
		if (pluginSupported('audio/x-wav')) {
			document.write("<embed autostart='true' id=\\"" + sID + "\\" alt=\\"" + sDescription + "\\" src=\\"" + sURI + "\\"><" + "/embed><noembed>" + backgroundSound(sURI, sID, sDescription, iLoop) + "</noembed>");
		}

		else {
			document.write(backgroundSound(sURI, sID, sDescription, iLoop));
		}
	}
}

//-->

</script>

<script language="VBScript">

<!--

Function TryActiveXObject(strClass)

	On Error Resume Next

	Dim bTryObject

	bTryObject = False

	If ScriptEngineMajorVersion > 1 Then bTryObject = IsObject(CreateObject(strClass))

	TryActiveXObject = bTryObject

End Function

'-->

</script>

<script language="JavaScript">

<!--

var VBScriptEnabled = (typeof(TryActiveXObject) != 'undefined');

writeAudio('$wav_file');

//-->

</script>

<noscript>

<embed src="$wav_file" autostart="true"></embed><noembed><bgsound volume="20" src="$wav_file" /></noembed>

</noscript>

@;
        }
        elsif ( $format =~ /link/ ) {
            $html .= "&nbsp;&nbsp;<a href='$wav_file'>Listen to wav</a>\n";
        }
        elsif ( $format =~ /bgsound/ ) {
            $html .= "\n<br><BGSOUND SRC='$wav_file' VOLUME=20>\n";
        }
        else {
            $html .=
              "\n<br><EMBED SRC='$wav_file' VOLUME=20 WIDTH=144 HEIGHT=60 AUTOSTART='true'>\n";

            #           $html .= "\n<br><EMBED SRC='$wav_file'  VOLUME=20 WIDTH=144 HEIGHT=60 AUTOSTART='true'>\n" .
            #             "<NOEMBED><BGSOUND SRC='$wav_file'></NOEMBED>\n";
        }
    }

    # Without this, IE loads the file too quick??
    #    select undef, undef, undef, 0.10; # Not sure why we need this
    # We don't!
    return ($html);
}

sub html_last_displayed {
    my ($last_displayed) = &display_log_last(1);

    # Add breaks on newlines
    $last_displayed =~ s/\n/\n<br>/g;

    #   return "<h3>Last Displayed Text</h3>$last_displayed";
    return "<h3>Last Displayed Text</h3>$last_displayed",
      $main::config_parms{ 'html_style_speak' . $Http{format} };

}

sub html_last_spoken {
    my $h_response;

    if ( $Authorized or $main::config_parms{password_protect} !~ /logs/i ) {
        $h_response .=
          qq[<META HTTP-EQUIV="REFRESH" CONTENT="$main::config_parms{'html_refresh_rate' . $Http{format}}; url=speech">\n]
          if $main::config_parms{ 'html_refresh_rate' . $Http{format} };
        $h_response .= "<a href=speech>Refresh Recently Spoken Text</a>\n";

        #       $h_response .= &html_file($socket, '../web/bin/set_cookie.pl', 'webmute&&<b>Webmute</b>', 1);
        my @last_spoken =
          &speak_log_last( $main::config_parms{max_log_entries} );
        for my $text (@last_spoken) {
            $h_response .= "<li>$text\n";
        }
    }
    else {
        $h_response = "<h4>Not Logged In</h4>";
    }

    return "$h_response\n",
      $main::config_parms{ 'html_style_speak' . $Http{format} };
}

sub html_print_log {

    my $h_response;
    if ( $Authorized or $main::config_parms{password_protect} !~ /logs/i ) {
        $h_response .=
          qq[<META HTTP-EQUIV="REFRESH" CONTENT="$main::config_parms{'html_refresh_rate' . $Http{format}}; url=print_log">\n]
          if $main::config_parms{ 'html_refresh_rate' . $Http{format} };
        $h_response .= "<a href=print_log>Refresh Print Log</a>\n";
        my @last_printed =
          &main::print_log_last( $main::config_parms{max_log_entries} );
        for my $text (@last_printed) {

            #This formatting is a little bizarre, but sub html_page blindly
            #converts all \n to \n\r apparently to be standards compliant. It
            #would be easier to set the white space of list-item to pre, however
            #the additional newline characters added by html_page look ugly.
            $text =~ s/\n/<\/pre><\/br>\n<pre>/g;
            $h_response .= "<li><pre>$text</pre></li>\n";
        }
    }
    else {
        $h_response = "<h4>Not Logged In</h4>";
    }
    return "$h_response\n",
      $main::config_parms{ 'html_style_print' . $Http{format} };
}

sub html_encode {
    ($_) = @_;
    s/\&/\&amp;/g;
    s/\x22/\&quot;/g;
    s/>/\&gt;/g;
    s/</\&lt;/g;
    $_;
}

sub html_error_log {

    my $h_response;
    if ( $Authorized or $main::config_parms{password_protect} !~ /errorlog/i ) {
        $h_response .=
          qq[<META HTTP-EQUIV="REFRESH" CONTENT="$main::config_parms{'html_refresh_rate' . $Http{format}}; url=error_log">\n]
          if $main::config_parms{ 'html_refresh_rate' . $Http{format} };
        $h_response .= "<a href=error_log>Refresh Error Log</a>\n";
        my @last_printed =
          &main::error_log_last( $main::config_parms{max_log_entries} );
        for my $text (@last_printed) {
            $text =~ s/\n/\n<br>/g;
            $h_response .= "<li>$text\n";
        }
    }
    else {
        $h_response = "<h4>Not Logged In</h4>";
    }
    return "$h_response\n",
      $main::config_parms{ 'html_style_error' . $Http{format} };
}

# These html_form functions are used by mh/web/bin/*.pl scrips
sub html_form_input_set_func {
    my ( $func, $resp, $var1, $var2 ) = @_;
    my $html .= qq|<form action='/bin/set_func.pl' method=post><td>\n|;
    $html    .= qq|<input name='func' value="$func"  type='hidden'>\n|;
    $html    .= qq|<input name='resp' value="$resp"  type='hidden'>\n|;
    $html    .= qq|<input name='var1' value="$var1"  type='hidden'>\n|;
    my $size = 4 + length $var2;
    $size = 10 if $size < 10;
    $size = 30 if $size > 30;
    $html .= qq|<input name='var2' value="$var2" size=$size>\n|;
    $html .= qq|</td></form>\n|;
    return $html;
}

sub html_form_input_set_var {
    my ( $var, $resp, $default ) = @_;
    $default = HTML::Entities::encode($default);
    my $html .= qq|<form action='/bin/set_var.pl' method=post><td>\n|;
    $html    .= qq|<input name='var'   value="$var"   type='hidden'>\n|;
    $html    .= qq|<input name='resp'  value="$resp"  type='hidden'>\n|;
    $html    .= qq|<input name='value' value="$default" size=30>\n|;
    $html    .= qq|</td></form>\n|;
    return $html;
}

#       $html .= "<td><a href=/bin/set_var.pl?\$triggers{'$name2'}{trigger}&/bin/triggers.pl>$trigger</a></td>\n";

sub html_form_select {
    my ( $var, $onchange, $default, @values ) = @_;
    $onchange = ($onchange) ? "onChange='form.submit()'" : '';
    my $form .= qq|<select name='$var' $onchange>\n|;
    for my $value (@values) {
        my $selected = ( $value eq $default ) ? 'selected' : '';
        my $option = $value;
        $option =~ s/&/&#38;/g;
        $option =~ s/'/&#39;/g;
        $form .= qq|<option value='$option' $selected>$value</option>\n|;
    }
    $form .= "</select>\n";
    return $form;
}

sub html_form_select_set_func {
    my ( $func, $resp, $var1, $default, @values ) = @_;
    my $form .= qq|<form action='/bin/set_func.pl' method=post><td>\n|;
    $form    .= qq|<input name='func' value="$func"  type='hidden'>\n|;
    $form    .= qq|<input name='resp' value="$resp"  type='hidden'>\n|;
    $form    .= qq|<input name='var1' value="$var1"  type='hidden'>\n|;
    $form    .= qq|<select name='var2' onChange='form.submit()'>\n|;
    for my $value (@values) {
        my $selected = ( $value eq $default ) ? 'selected' : '';
        my $option = $value;
        $option =~ s/&/&#38;/g;
        $option =~ s/'/&#39;/g;
        $form .= qq|<option value='$option' $selected>$value</option>\n|;
    }
    $form .= "</select></td></form>\n";
    return $form;
}

sub html_form_select_set_var {
    my ( $var, $default, @values ) = @_;
    my $html = "<form action=/bin/set_var.pl method=post><td>\n";
    $html .= qq|<input type='hidden' name='var'  value="$var">\n|;
    $html .= qq|<input type='hidden' name='resp' value='/bin/triggers.pl'>\n|;
    $html .=
      &html_form_select( 'value', 1, $default, @values ) . "</td></form>\n";
    return $html;
}

sub html_file {
    my ( $socket, $file, $arg, $no_header ) = @_;
    print "http: print html file=$file arg=$arg\n" if $main::Debug{http};

    # Do not cach shtml files
    my ($cache) = ( $file =~ /\.shtm?l?$/ or $file =~ /\.vxml?$/ ) ? 0 : 1;

    # Return right away if the file has not changed
    #http:   header key=If-Modified-Since value=Sat, 27 Mar 2004 02:49:29 GMT; length=1685.
    if (    $cache
        and $Http{'If-Modified-Since'}
        and $Http{'If-Modified-Since'} =~ /(.+? GMT)/ )
    {
        my $time2 = &str2time($1);
        my $time3 = ( stat($file) )[9];
        print "db web file cache check: f=$file t=$time2/$time3\n"
          if $main::Debug{http3};
        if ( $time3 <= $time2 ) {
            return "HTTP/1.0 304 Not Modified\nServer: MisterHouse\n";
        }
    }

    my $html;
    local *HTML;    # Localize, for recursive call to &html_file

    unless ( open( HTML, $file ) ) {
        print "Error, can not open html file: $file: $!\n";
        close HTML;
        return;
    }

    # Allow for 'server side include' directives
    #  <!--#include file="whatever"-->
    if (   $file =~ /\.shtm?l?$/
        or $file =~ /\.vxml?$/
        or $file =~ /\.sxml?$/
        or $file =~ /\.sjs?$/ )
    {
        print "Processing server side include file: $file\n"
          if $main::Debug{http};
        $html = &mime_header( $file, 0 ) unless $no_header;
        while ( my $r = <HTML> ) {
            $html .= shtml_include( $r, $socket );
        }
    }

    # Allow for .pl cgi programs
    # Note: These differ from classic .cgi in that they return
    #       the results, rather than print them to stdout.
    elsif ( $file =~ /\.(pl|cgi)$/ ) {
        my $code = join( '', <HTML> );

        # Check if authorized
        my $user_required = lc $1 if $code =~ /^# *authority: *(\S+) *$/smi;
        $file =~ s/.*\///;    # Drop path to file

        $user_required = $Password_Allow{$file} if $Password_Allow{$file};

        unless ( &authority_check($user_required) ) {
            my $whoisit = &net_domain_name('http');
            &print_log("$whoisit made an unauthorized request for $file");

            #           return &html_page("", &html_unauthorized("Not authorized to run perl .pl file: $file"));
            return &html_unauthorized(
                "Not authorized to run perl .pl file: $file");
        }

        @ARGV = '';    # Have to clear previous args
        @ARGV = split( /&&/, $arg ) if defined $arg;

        # Allow for regular STDOUT cgi scripts
        if ( $code =~ /^\S+perl/ ) {
            print "http: running cgi script: $file\n" if $main::Debug{http};
            &html_cgi( $socket, $code, $arg );
            return;
        }
        else {
            $html = eval $code;
            if ($@) {
                my $msg = "http error in http eval of $file: $@";
                $html = &html_page( '', $msg );
                print $msg;
            }

            #            print "Error in http eval: $@" if $@;
        }

        # Drop the http header if no_header
        $html =~ s/^HTTP.+?^$//smi if $no_header;

        #       print "Http_server  .pl file results:$html.\n" if $main::Debug{http};
    }
    else {
        binmode HTML;

        #       my $data = join '', <HTML>;
        # Read entire file at once instead of line by line ... faster
        my $data;
        {
            local $/ = undef;
            $data = join( '', <HTML> );
        }
        $html = &mime_header( $file, 1, length $data ) unless $no_header;
        $html .= $data;
    }
    close HTML;
    return $html;
}

sub shtml_include {
    my ( $r, $socket ) = @_;
    my $html;

    # Example:  <li>Version: <!--#include var="$Version"--> ...
    #   if (my ($prefix, $directive, $data, $suffix) = $r =~ /(.*)\<\!--+ *\#include +(\S+)=[\"\']([^\"\']+)[\"\'] *--\>(.*)/) {
    while ( my ( $prefix, $directive, $data, $suffix ) =
        $r =~ /(.*?)\<\!--+ *\#include +(\S+)=\"([^\"]+)\" *--\>(.*)/ )
    {
        print "Http include: $directive=$data\n" if $main::Debug{http};
        $html .= $prefix;

        # tellme vxml does not like comments in the middle of things :(
        # - also had problems with comments inside td elements, so lets skip this
        #   e.g.: " <td <!--#include file="motion.pl?timer_motion_main"--> >
        #       $html .= "\n<\!-- The following is from include $directive = $data -->\n" unless $file =~ /\.vxml$/;
        if ( $directive eq 'file' ) {
            eval "\$data = qq[$data]"
              ;    # Resolve $vars in file specs (e.g. config_parm{web_href...}
            my ( $get_req, $get_arg ) = $data =~ m|(\/?[^ \?]+)\??(\S+)?|;
            $get_arg = '' unless defined $get_arg;  # Avoid uninitalized var msg
            $get_arg =~ s/\&/&&/g
              ; # translate & to &&, since we translate %##  to & before splitting
            if ( !$get_req ) {
            }
            elsif ( my $html_file =
                &test_for_file( $socket, $get_req, $get_arg, 1, 1 ) )
            {
                $html .= $html_file;
            }
            elsif ( my ( $html2, $style ) =
                &html_mh_generated( $get_req, $get_arg, 0 ) )
            {
                $style = '' unless $style;    # Avoid uninitalized var msg
                $html .= $style . $html2;
            }
            else {
                print
                  "Error, shtml file directive not recognized: data=$data req=$get_req arg=$get_arg\n";
            }
        }
        elsif ( $directive eq 'ajax' ) {
            my $url = $data;
            unless ( $data =~ m/^\// ) {
                print "Correcting AJAX URL\n" if $main::Debug{http};
                $url = "/" . $url;
            }
            my $ajax_start =
              qq[<span class="ajax_update"><input type="hidden" value="$url"><span class="content">];
            my $ajax_end = qq[</span></span>];
            eval "\$data = qq[$data]"
              ;    # Resolve $vars in file specs (e.g. config_parm{web_href...}
            my ( $get_req, $get_arg ) = $data =~ m|(\/?[^ \?]+)\??(\S+)?|;
            $get_arg = '' unless defined $get_arg;  # Avoid uninitalized var msg
            $get_arg =~ s/\&/&&/g
              ; # translate & to &&, since we translate %##  to & before splitting
            if ( !$get_req ) {
            }
            elsif ( my $html_file =
                &test_for_file( $socket, $get_req, $get_arg, 1, 1 ) )
            {
                $html .= $ajax_start . $html_file . $ajax_end;
            }
            elsif ( my ( $html2, $style ) =
                &html_mh_generated( $get_req, $get_arg, 0 ) )
            {
                $style = '' unless $style;    # Avoid uninitalized var msg
                $html .= $ajax_start . $style . $html2 . $ajax_end;
            }
            else {
                print
                  "Error, shtml ajax directive not recognized: data=$data req=$get_req arg=$get_arg\n";
            }
        }
        elsif ( $directive =~ /^s?var$/ or $directive eq 'code' ) {
            print "Processing server side include: var=$data\n"
              if $main::Debug{http};
            if ( $directive eq 'svar' and !$Authorized ) {
                $html .= $data;
            }
            else {
                $html .= eval "return $data";    # Why the return??

                #               $html .= eval "$data";
            }
            print "Error in eval: $@" if $@;
        }
        else {
            print
              "http include directive not recognized:  $directive = $data\n";
        }
        $r = $suffix;
    }
    $html .= $r;
    return $html;
}

sub html_cgi {
    my ( $socket, $code, $arg ) = @_;
    my $html;

    # Need to redirect print/printf from STDOUT to $socket

    # Method 1.  Works except on Win95/98
    $config_parms{http_cgi_method} = 1 unless $config_parms{http_cgi_method};
    if ( $config_parms{http_cgi_method} == 1 ) {
        open OLD_HANDLE, ">&STDOUT"
          or print "\nhttp .pl error: can not backup STDOUT: $!\n";
        if ( my $fileno = $socket->fileno() ) {
            print "http: cgi redirecting socket fn=$fileno s=$socket\n"
              if $main::Debug{http};

            # This is the step that fails on win98 :(
            open STDOUT, ">&$fileno"
              or warn
              "http .pl error: Can not redirect STDOUT to $fileno: $!\n";
        }
    }

    # Method 2.  If CGI is used (e.g. organizer scripts), this
    #    gives this error on eval: Undefined subroutine CGI::delete
    else {

        package Override_print;
        sub TIEHANDLE { bless $_[1], $_[0]; }
        sub PRINT  { my $coderef = shift; $coderef->(@_); }
        sub PRINTF { my $coderef = shift; $coderef->(@_); }

        #       sub DELETE { }
        sub define_print (&) { tie( *STDOUT, "Override_print", @_ ); }
        sub undefine_print (&) { untie(*STDOUT); }

        package Main;
        Override_print::define_print { $html .= shift };
    }

    print "HTTP/1.0 200 OK\nServer: MisterHouse\nCache-Control: no-cache\n";

    # Setup up vars so pgms like CGI.pm work ok
    $arg =~ s/&&/&/g;
    $ENV{QUERY_STRING}   = $arg;
    $ENV{REQUEST_METHOD} = 'GET';

    #   $ENV{REMOTE_ADDR}       = $Http{Client_address};
    eval '&CGI::initialize_globals'
      ;    # Need this or else CGI.pm global vars are not reset
    local $^W = 0;    # Avoid redefined sub msgs
    eval $code;
    print "Error in http cgi eval: $@" if $@;

    if ( $config_parms{http_cgi_method} == 1 ) {
        $socket->close();
        open STDOUT, ">&OLD_HANDLE"
          or print "\nhttp .pl error: can not redir STDIN to orig value: $!\n";
        close OLD_HANDLE;
    }
    else {
        Override_print::undefine_print { };
        print $socket $html;
        $socket->close();
    }
}

sub mime_header {
    my ( $file_or_type, $cache, $length ) = @_;

    # Allow for passing filename or filetype
    my ( $mime, $date );
    if ( $mime = $mime_types{$file_or_type} ) {
        $date = &time2str();
    }
    else {
        my ($extention) = $file_or_type =~ /.+\.(\S+)$/;
        $mime = $mime_types{ lc $extention } || 'text/html';
        my $time = ( stat($file_or_type) )[9];
        $date = &time2str($time);

        #       $date = &time_date_stamp(19, $time);
    }

    #   print "dbx2 m=$mime f=$file_or_type\n";

    my $header = "HTTP/1.0 200 OK\nServer: MisterHouse\nContent-type: $mime\n";

    #   $header .= ($cache) ? "Cache-Control: max-age=1000000\n" : "Cache-Control: no-cache\n";
    if ($cache) {
        $header .= "Last-Modified: $date\n";
    }
    else {
        $header .= "Cache-Control: no-cache\n";
    }

    # Allow for a length header, as this allows for faster 'persistant' connections
    $header .= "Content-Length: $length\n" if $length;

    return $header . "\n";

    #Expires: Mon, 01 Jul 2002 08:00:00 GMT
}

# this returns real dirs, given html alias
# If we have multiple aliases, return the first one?
sub html_alias {
    my ($dir) = @_;
    return ( $http_dirs{$dir}[0] or $http_dirs{"/$dir"}[0] );
}

# Responses documented here: http://www.w3.org/Protocols/HTTP/HTRESP.html
sub html_no_response {

    return <<eof;
HTTP/1.0 204 No Response
Server: MisterHouse
Content-Type: text/html


eof
}

sub html_page {
    my ( $title, $body, $style, $script, $frame ) = @_;

    my $date = time2str(time);

    # Allow for fully formated html
    if ( $body =~ /^\s*<(!doctype\s*)?(html|\?xml)/i ) {
        $body =~ s/\n/\n\r/g
          ;    # Bill S. says this is required to be standards compiliant

        my $contenttype =
          "text/html";    # Default value if no other information is found

        if ( $body =~ /^\s*<(\?xml)/i ) {
            $contenttype = "text/xml";
        }

        # Content-Length is only for binary data!
        #        my $length = length $body;
        # Content-Length: $length

        #Cache-Control: max-age=1000000
        return <<eof;
HTTP/1.0 200 OK
Server: MisterHouse
Date: $date
Content-Type: $contenttype
Cache-Control: no-cache

$body
eof
    }

    $body = 'No data' unless $body;

    # Allow for redirect and pre-formated responses (e.g. vxml response)
    return http_redirect($body) if $body =~ /^https?:\S+$/i;
    return $body if $body =~ /^HTTP\//;    # HTTP/1.0 200 OK

    # This meta tag does not work :(
    # MS IE does not honor Window-target :(
    #   my $frame2 = qq[<META HTTP-EQUIV="Window-target" CONTENT="$frame">] if $frame;
    $style = $main::config_parms{ 'html_style' . $Http{format} }
      if $main::config_parms{ 'html_style' . $Http{format} }
      and !defined $style;
    $frame = "Window-target: $frame" if $frame;
    $frame  = '' unless $frame;     # Avoid -w uninitialized value msg
    $script = '' unless $script;    # Avoid -w uninitialized value msg
    $title  = '' unless $title;     # Avoid -w uninitialized value msg

    #Cache-Control: max-age=1000000

    my $html;
    if ($script) {

        #      print "dbx1 s=$script\n\n";
        $script = qq[<SCRIPT LANGUAGE="JavaScript">$script></SCRIPT>\n]
          unless $script =~ / script /i;
        $html = $script . "\n";
    }
    $html .= "<HTML>
<HEAD>
$style
<TITLE>$title</TITLE>
</HEAD>
<BODY>

$body
</BODY>
</HTML>
";

    my $extraheaders = '';
    $extraheaders .= $Cookie . "\n\r" if $Cookie;
    $extraheaders .= $frame . "\n\r"  if $frame;
    $extraheaders .= "\n\r"           if $extraheaders;

    # Not sure how important length is, but pretty cheap and easy to do
    $html =~
      s/\n/\n\r/g;    # Bill S. says this is required to be standards compiliant
    return <<eof;
HTTP/1.0 200 OK
Server: MisterHouse
Content-Type: text/html
Cache-Control: no-cache
$extraheaders

$html
eof
}

sub http_redirect {
    my ($url) = @_;
    print "http_redirect Location: $url\n" if $main::Debug{http};
    return <<eof;
HTTP/1.0 302 Moved Temporarily
Location: $url
$Cookie
eof
}

sub http_agent_size {
    my $size = $Http{'User-Agent-Size'};
    unless ($size) {
        my $agent = $Http{'User-Agent'};
        $size =
          ( $http_agent_sizes{$agent} ) ? $http_agent_sizes{$agent} : 1000;
    }
    return $size;
}

sub html_category {
    my $h_index;

    $h_index =
      qq[<DIV ID="overDiv" STYLE="position:absolute; visibility:hide; z-index:1;"></DIV>\n]
      . qq[<SCRIPT LANGUAGE="JavaScript" SRC="/lib/overlib.js"></SCRIPT>\n]
      if $html_info_overlib;

    for my $category ( &list_code_webnames('Voice_Cmd') ) {
        next if $category =~ /^none$/;

        my $info = "$category:";
        my $accesskey = substr( $category, 0, 1 );
        if ($html_info_overlib) {
            if ( my @files = &list_files_by_webname($category) ) {
                $info .= '<li>' . join( '<li>', @files );
            }

            #           $info = qq[onMouseOver="overlib('$info', FIXX, 5, OFFSETY, 50 )" onMouseOut="nd();"];
            $info =
              qq[onMouseOver="overlib('$info', RIGHT, OFFSETY, 50 )" onMouseOut="nd();"];
        }

        # Create buttons with GD module if available
        if ( $Info{module_GD} ) {
            $h_index .=
              qq[<a href=list?$category $info accesskey=$accesskey><img src="/bin/button.pl?$category" alt='$category' border="0"></a>\n];
        }
        else {
            $h_index .= "<li>"
              . qq[<a href=list?$category $info accesskey=$accesskey>$category</a>\n];
        }
    }
    return $h_index;
}

sub html_groups {
    my $h_index;
    for my $group ( &list_objects_by_type('Group') ) {

        # No need to list empty groups
        my $object = &get_object_by_name($1);
        if ( $object and $object->can('list') ) {
            next unless grep !$$_{hidden}, list $object;
        }

        # Create buttons with GD module if available
        if ( $Info{module_GD} ) {
            my $name = &pretty_object_name($group);
            $h_index .=
              qq[<a href=list?group=$group><img src="/bin/button.pl?$name" alt='$name' border="0"></a>\n];
        }
        else {
            $h_index .= "<li>"
              . &html_active_href( "list?group=$group",
                &pretty_object_name($group) )
              . "\n";
        }
    }
    return $h_index;
}

sub html_items {
    my $h_index;

    #   for my $object_type ('X10_Item', 'X10_Appliance', 'Group', 'iButton', 'Serial_Item') {
    for my $object_type (@Object_Types) {
        next if $object_type eq 'Voice_Cmd';    # Already covered under Category
             # Create buttons with GD module if available
        if ( $Info{module_GD} ) {
            $h_index .=
              qq[<a href=list?$object_type><img src="/bin/button.pl?$object_type" alt='$object_type' border="0"></a>\n];
        }
        else {
            $h_index .= "<li>"
              . &html_active_href( "list?$object_type", $object_type ) . "\n";
        }
    }
    return $h_index;
}

sub html_find_icon_image {
    my ( $object, $type ) = @_;
    my ( $name, $state, $icon, $ext, $member );

    $type = lc $type;
    if ( $type eq 'text' ) {
        $name = $object;
    }
    else {
        $name = lc $object->{object_name};

        #       $state = lc $object->{state};
        $state = lc $object->state();
        $state = lc $object->state_level()
          if ( $type eq 'x10_item'
            or $type eq 'x10_switchlinc' );
        $state = 'on'  if $state eq '100%';
        $state = 'dim' if $state =~ /^\d\d?%$/;
        $name =~ s/^\$//;    # remove $ at front of objects
        $name =~ s/^v_//;    # remove v_ in voice commands
                             # Use on/off icons for conditional Weather_Items
        $state = ($state) ? 'on' : 'off'
          if $type eq 'weather_item' and ( $object->{comparison} );

        # Remove min/max from normal and alert states on RF_Items
        $state =~ s/(normal|alert)(min|max)$/$1/i;

        # Allow for set_icon to set the icon directly
        $name = $object->{icon} if $object->{icon};
        if ( $type eq 'eibrb_item' ) {
            $state = sprintf( "%.0f", $state / 10 ) * 10;
        }
        return '' if $name eq 'none';
    }

    print "Find_icon: object_name=$name, type=$type, state=$state\n"
      if $main::Debug{http};

    unless (%html_icons) {
        undef %html_icons;

        # If we have multiple dirs, the first one wins (last one in mh.ini file)
        for my $dir ( @{ $http_dirs{'/graphics'} } ) {
            print "Reading html icons from $dir\n" if $main::Debug{http};
            opendir( ICONS, $dir );

            for $member ( readdir ICONS ) {
                ( $icon, $ext ) = $member =~ /(\S+)\.(\S+)/;
                $ext = lc $ext;
                next
                  unless $ext
                  and ( $ext eq 'gif' or $ext eq 'jpg' or $ext eq 'png' );
                $icon = lc $icon;

                # Give .jpg files a preference as these are supported by GD from web/bin/button.pl
                $html_icons{$icon} = $member
                  unless $html_icons{$icon} and $html_icons{$icon} =~ /.jpg$/i;
            }
        }
    }

    # Look for exact matches
    if (   $icon = $html_icons{"$name-$state"}
        or $icon = $html_icons{$name} )
    {
    }

    # For voice items, look for approximate name matches
    #  - Order of preference: object, text, filename
    #    and pick the longest named match
    elsif ( $type eq 'voice' or $type eq 'text' ) {
        my ( $i1, $i2, $i3, $l1, $l2, $l3 );
        $l1 = $l2 = $l3 = 0;
        for my $member ( sort keys %html_icons ) {
            next if $member eq 'on' or $member eq 'off';
            my $l = length $member;
            if ( $html_icons{$member} ) {
                if ( $name =~ /$member/i and $l > $l1 ) {
                    $i1 = $html_icons{$member};
                    $l1 = $l;
                }
                unless ( $type eq 'text' ) {
                    if ( $object->{text} =~ /$member/i and $l > $l2 ) {
                        $i2 = $html_icons{$member};
                        $l2 = $l;
                    }
                    if ( $object->{filename} =~ /$member/i and $l > $l3 ) {
                        $i3 = $html_icons{$member};
                        $l3 = $l;
                    }
                }
            }

            #           print "db n=$name t=$object->{text} $i1,$i2,$i3 l=$l m=$member\n" if $object->{text} =~ /playlist/;
        }
        if    ($i1) { $icon = $i1 }
        elsif ($i2) { $icon = $i2 }
        elsif ($i3) { $icon = $i3 }
        else {
            return '';    # No match
        }
    }

    # For non-voice items, try State and Item type matches
    else {

        unless ( $icon = $html_icons{"$type-$state"}
            or $icon = $html_icons{$type}
            or $icon = $html_icons{$state} )
        {
            return '';    # No match
        }
    }

    return "/graphics/$icon";
}

#  button_action is used by mh/web/bin/menu.pl.  Similar to web/bin/button_action.pl
#  but the function form allows for a more complicated referer string.
sub button_action {
    my ($args) = @_;
    my ( $object_name, $state, $referer, $xy ) = split ',', $args;

    my ( $x, $y ) = $xy =~ /(\d+)\|(\d+)/;

    # Do not dim the dishwasher :)
    unless ( eval qq|UNIVERSAL::isa($object_name, 'X10_Appliance')|
        or eval
        qq|ref($object_name) && $object_name->can('is_dimmable') && !($object_name->is_dimmable)|
      )
    {
        $state = 'dim'      if $x < 30;    # Left  side of image
        $state = 'brighten' if $x > 70;    # Right side of image
    }

    eval qq|$object_name->set("$state")|;
    print "smart_button_action.pl eval error: $@\n" if $@;

    $referer =~ s/ /%20/g;
    $referer =~ s/&&/&/g;
    return &http_redirect($referer);
}

sub html_header {
    my ( $text, $title ) = @_;
    $text  = 'Generic Header' unless $text;
    $title = 'Misterhouse'    unless $title;

    my $color = $config_parms{html_color_header};
    $color = '#9999cc' unless $color;

    return qq[<html>
<head>
<title>$title</title>
</head>
<body>
$config_parms{html_style}
<table width=100% bgcolor='$color'>
<td><center>
<font size=3 color="black"><b>
$text
</b></font></center>
</td>
</table>
];
}

sub html_header_new {
    if ($Authorized) {

        my ($text) = @_;
        $text = 'Generic Header' unless $text;

        my $color = $config_parms{html_color_header};
        $color = '#9999cc' unless $color;

        return qq[
$config_parms{html_style}
<table width=100% bgcolor='$color'>
<td><center>
<font size=3 color="black"><b>
$text
</b></font></center>
</td>
</table><br>
];
    }
    else {
        my ($text) = @_;
        $text = 'Sorry Unauthorized to View This Function';

        my $color = $config_parms{html_color_header};
        $color = '#9999cc' unless $color;

        return qq[
$config_parms{html_style}
<table width=100% bgcolor='$color'>
<td><center><meta http-equiv="refresh" content="0;URL=/misc/unauthorized.html">
<font size=3 color="black"><b>
$text
</b></font></center>
</td>
</table><br>
];
    }
}

sub html_list {

    my ( $webname_or_object_type, $auto_refresh ) = @_;
    my ( $object, @object_list, $num, $h_list );

    $h_list .= &html_header(
        "<b>Browse $webname_or_object_type</b>&nbsp;&nbsp;&nbsp;&nbsp;"
          . &html_authorized );
    $h_list =~ s/group=\$//;    # Drop the group=$ prefix on group lists

    $h_list .= qq[<!-- html_list -->\n];

    # This means the form was submited ... check for search keyword
    # Now better done with /bin/command_search.pl?string
    if ( my ($search) = $webname_or_object_type =~ /search=(.*)/ ) {

        # Search for matching Voice_Cmd and Tk Widgets
        $h_list .= "<!-- html_list list_objects_by_search=$search -->\n";
        my %seen;
        for my $cmd ( &list_voice_cmds_match($search) ) {

            # Now find object name
            my ( $file, $cmd2 ) = $cmd =~ /(.+)\:(.+)/;
            my ( $object, $said, $vocab_cmd ) =
              &Voice_Cmd::voice_item_by_text( lc $cmd2 );
            my $object_name = $object->{object_name};
            next if $seen{$object_name}++;
            push @object_list, $object_name;
        }
        $h_list .= &widgets( 'search', $search );
        $h_list .= &html_command_table(@object_list);
        return $h_list;

    }

    # Check for authority based searches
    if ( $webname_or_object_type =~ /authority=(\S*)/ ) {
        my $search = $1;
        for my $category ( &list_code_webnames('Voice_Cmd') ) {
            for my $object_name ( sort &list_objects_by_webname($category) ) {
                my $object = &get_object_by_name($object_name);
                next unless $object and UNIVERSAL::isa( $object, 'Voice_Cmd' );

                # for now, only list set_authority('anyone') commands
                my $authority = $object->get_authority;
                push @object_list, $object_name
                  if $authority and $authority = !/$search/i;
            }
        }

        $h_list .= "<!-- html_list list_objects_by_authority=$search -->\n";

        #       $h_list .= &widgets('search', $1);
        $h_list .= &html_command_table(@object_list);
        return $h_list;
    }

    # List Groups (treat them the same as Items)
    if ( $webname_or_object_type =~ /^group=(\S+)/ ) {
        $h_list .= "<!-- html_list group = $webname_or_object_type -->\n";
        my $object = &get_object_by_name($1);

        # Ignore objects marked as hidden
        my @objects = grep !$$_{hidden}, list $object
          if $object and $object->can('list');

        my @table_items =
          map { &html_item_state( $_, $webname_or_object_type ) } @objects;
        $h_list .=
          &table_it( $config_parms{ 'html_table_size' . $Http{format} },
            0, 0, @table_items );
        return $h_list;
    }

    # List Items by type
    if ( @object_list = sort &list_objects_by_type($webname_or_object_type) ) {
        $h_list .=
          qq[<META HTTP-EQUIV="REFRESH" CONTENT="$main::config_parms{'html_refresh_rate' . $Http{format}}; url=list?$webname_or_object_type">\n]
          if $auto_refresh
          and $main::config_parms{ 'html_refresh_rate' . $Http{format} };
        $h_list .=
          "<!-- html_list list_objects_by_type = $webname_or_object_type -->\n";
        my @objects = map { &get_object_by_name($_) } @object_list;

        # Ignore objects marked as hidden
        @objects = grep !$$_{hidden}, @objects;

        my @table_items =
          map { &html_item_state( $_, $webname_or_object_type ) } @objects;
        $h_list .=
          &table_it( $main::config_parms{ 'html_table_size' . $Http{format} },
            0, 0, @table_items );
        return $h_list;
    }

    # List Voice_Cmds, by Category
    if ( @object_list = &list_objects_by_webname($webname_or_object_type) ) {
        $h_list .= "<!-- html_list list_objects_by_webname -->\n";
        $h_list .= &widgets( 'all', $webname_or_object_type );
        $h_list .= &html_command_table(@object_list) if @object_list;
        return $h_list;
    }

}

sub table_it {
    my ( $cols, $border, $space, @items ) = @_;

    my $h_list .=
      qq[<table border='$border' width="100%" cellspacing="$space" cellpadding="0">\n];

    my $num = 0;
    for my $item (@items) {
        if ( $num == 0 ) {

            # Check to see if it already specs a row
            if ( $item =~ /^\<tr/ ) {
                $h_list .= $item . "\n";
                next;
            }
            $h_list .= qq[<tr align=center>\n];
        }
        $h_list .= $item . "\n";
        if ( ++$num == $cols ) {
            $h_list .= "</tr>\n\n";
            $num = 0;
        }
    }

    # do this so we don't throw off the table cell sizes if the number of items is not divisable
    #    while ($num lt $cols) {
    #        $h_list .= qq[<td align="right"></td>];
    #        $h_list .= qq[<td> </td>];
    #        $num++;
    #    }
    #    $h_list .= "</tr>\n</table>\n";
    $h_list .= "</table>\n";
    return $h_list;
}

sub html_command_table {
    my (@object_list) = @_;
    my ( $html, @htmls );
    my $list_count = 0;
    my ( $msagent_cmd1, $msagent_script1, $msagent_script2 );

    my @objects = map { &get_object_by_name($_) } @object_list;

    # Sort by sort field, then filename, then object name
    for my $object (
        sort {
                 ( $a->{order} and $b->{order} and $a->{order} cmp $b->{order} )
              or ( $a->{filename} cmp $b->{filename} )
              or (  exists $a->{text}
                and exists $b->{text}
                and $a->{text} cmp $b->{text} )
        } @objects
      )
    {
        my $object_name = $object->{object_name};
        my $state_now   = $object->{state};
        my $filename    = $object->{filename};
        my $text        = $object->{text};
        next unless $text;    # Only do voice items
        next if $$object{hidden};

        $list_count++;

        # Find the states and create the test label
        #  - pick the first {a,b,c} phrase enumeration
        $text =~ s/\{(.+?),.+?\}/$1/g;

        my ( $prefix, $states, $suffix, $h_text, $text_cmd, $ol_info,
            $state_log, $ol_state_log );
        ( $prefix, $states, $suffix ) = $text =~ /^(.*)\[(.+?)\](.*)$/;
        $states = '' unless $states;    # Avoid -w uninitialized values error
        $suffix = '' unless $states;
        my @states = split ',', $states;

        #       my $states_with_select = @states > $config_parms{'html_category_select' . $Http{format}};
        my $states_with_select = length("@states") >
          $config_parms{ 'html_select_length' . $Http{format} };

        # Do the filename entry
        push @htmls, qq[<td align='left' valign='center'>$filename</td>\n]
          if $main::config_parms{ 'html_category_filename' . $Http{format} };

        # Build the info and statelog overlib strings
        #  - Netscape only supports onmouse over on hrefs :(
        #  - Building a dummy href for Netscap only kind of works, so lets skip it.
        #       $ol_info .= qq[<a href="javascript:void(0);" ];
        if ($html_info_overlib) {
            $ol_info = $object->{info};
            $ol_info = "$prefix ... $suffix"
              if !$ol_info and ( $prefix or $suffix );
            $ol_info = $text unless $ol_info;
            $ol_info = "$filename: $ol_info";
            $ol_info =~ s/\'/\\\'/g;
            $ol_info =~ s/\"/\\\'/g;
            my $height = 20;
            if ( $states_with_select and $html_info_overlib ) {
                $ol_info .= '<li>' . join( '<li>', @states );
                $height += 20 * @states;
            }
            my $row = $list_count;
            $row /= 2
              if $main::config_parms{ 'html_category_cols' . $Http{format} } ==
              2;
            $height = $row * 25 if $row * 25 < $height;

            #           my $ol_pos = ($list_count > 5) ? 'ABOVE, HEIGHT, $height' : 'RIGHT';
            #           my $ol_pos = "ABOVE, HEIGHT, $height";
            my $ol_pos = "BELOW, HEIGHT, $height";
            $ol_info =
              qq[onMouseOver="overlib('$ol_info', $ol_pos)" onMouseOut="nd();"];

            # Summarize state log entries
            unless (
                $main::config_parms{ 'html_category_states' . $Http{format} } )
            {
                my @states_log = state_log $object;
                while ( my $state = shift @states_log ) {
                    if ( my ( $date, $time, $state ) =
                        $state =~ /(\S+) (\S+ *[APM]{0,2}) *(.*)/ )
                    {
                        $ol_state_log .= "<li>$date $time <b>$state</b> ";
                    }
                }
                $ol_state_log = "unknown" unless $ol_state_log;
                $ol_state_log =
                  qq[onMouseOver="overlib('$ol_state_log', RIGHT, WIDTH, 250 )" onMouseOut="nd();"];
            }
        }

        # Put in a dummy link, so we can get netscape state_log info
        if ( $config_parms{ 'html_info' . $Http{format} } eq 'overlib_link' ) {

            #           $html  = qq[<a href="javascript:void(0);" $ol_info>info</a><br> ];
            $html =
              qq[<a href='SET;&html_info($object_name)'$ol_info>info</a><br> ];
            $html .=
              qq[<a href='SET;&html_state_log($object_name)'$ol_state_log>log</a> ];
            push @htmls, qq[<td align='left' valign='center'>$html</td>\n];
        }

        # Do the icon entry
        if ( $main::config_parms{ 'html_category_icons' . $Http{format} }
            and my $h_icon = &html_find_icon_image( $object, 'voice' ) )
        {
            #           my $alt = $object->{info} . " ($h_icon)";
            my $alt = $h_icon;
            $alt =~ s/.*?([^\/]+)\..*/$1/;    # Use just the base file name
            $html =
              qq[<input type='image' src="$h_icon" alt="$alt" border="0">\n];

            #           $html = qq[<img src="$h_icon" alt="$h_icon" border="0">];
        }
        else {
            $html = qq[<input type='submit' border='1' value='Run'>\n];
        }

        # Start the form before the icon
        #  - outside of td so the table is shorter
        #  - allows the icon to be a submit
        my $form =
            qq[<FORM action="RUN;$H_Response" method="get" target="]
          . $config_parms{ 'html_target_speech' . $Http{format} }
          . qq[">\n];

        # Icon button
        push @htmls,
          qq[$form  <td align='left' valign='center' width='0%' $ol_state_log>$html</td>\n];

        # Now do the main text entry
        my $width =
          ( $main::config_parms{ 'html_category_cols' . $Http{format} } == 1 )
          ? "width='100%'"
          : '';
        $html = qq[<td align='left' $width $ol_info> ];

        $html .= qq[<b>$prefix</b>] if $prefix;

        my $web_style = get_web_style $object;
        if ( !defined $web_style ) {
            if ($states_with_select) {
                $web_style = "dropdown";
            }
            elsif ($states) {
                $web_style = "url";
            }
        }

        # Use a SELECT dropdown with 4 or more states
        my $currState = state $object;
        if ( $web_style eq "dropdown" ) {
            $html .= qq[<SELECT name="select_cmd" onChange="form.submit()">\n];

            #           $html .= qq[<option value="pick_a_state_msg" SELECTED> \n]; # Default is blank
            $msagent_cmd1 = "$prefix (";
            for my $state (@states) {
                my $selected =
                  $currState && $state eq $currState ? "selected" : "";
                my $text_cmd = "$prefix$state$suffix";
                $text_cmd =~ tr/\_/\~/;    # Blanks are not allowed in urls
                $text_cmd =~ tr/ /\_/;
                $html .=
                  qq[<option $selected value="$text_cmd">$state</option>\n];
                $state =~ s/\+(\d+)/$1/;    # Msagent doesn't like +20, +30, etc
                $msagent_cmd1 .= "$state|" if $state;
            }
            substr( $msagent_cmd1, -1, 1 ) = ") $suffix";
            $html .= qq[</SELECT>\n];
        }
        elsif ( $web_style eq "radio" ) {

            #           $html .= qq[<option value="pick_a_state_msg" SELECTED> \n]; # Default is blank
            $msagent_cmd1 = "$prefix (";
            for my $state (@states) {
                my $selected =
                  $currState && $state eq $currState ? "checked" : "";
                my $text_cmd = "$prefix$state$suffix";
                $text_cmd =~ tr/\_/\~/;    # Blanks are not allowed in urls
                $text_cmd =~ tr/ /\_/;
                $html .=
                  qq[<INPUT type="radio" name="select_cmd" $selected onChange="form.submit()" value="$text_cmd"/>$state\n];
                $state =~ s/\+(\d+)/$1/;    # Msagent doesn't like +20, +30, etc
                $msagent_cmd1 .= "$state|" if $state;
            }
            substr( $msagent_cmd1, -1, 1 ) = ") $suffix";
            $html .= qq[</SELECT>\n];
        }

        # Use hrefs with 2 or 3 states
        elsif ( $web_style eq "url" ) {
            my $hrefs;
            $msagent_cmd1 = "$prefix (";
            for my $state (@states) {
                my $text_cmd = "$prefix$state$suffix";
                $text_cmd =~ s/\+/\%2B/g
                  ;    # Use hex 2B = +, as + will be translated to blanks
                $text_cmd =~ s/\'/\%27/g;    # Use hex 27 = '
                $text_cmd =~ tr/\_/\~/;      # Blanks are not allowed in urls
                $text_cmd =~ tr/ /\_/;

                # Use the first entry as the default one, used when clicking on the icon
                if ($hrefs) {
                    $hrefs .= qq[, ] if $hrefs;
                }
                else {
                    $html .=
                      qq[<input type="hidden" name="select_cmd" value='$text_cmd'>\n];
                }

                # We could add ol_info here, so netscape kind of works, but this
                # would be redundant and ineffecient.
                $hrefs .=
                    qq[<a href='RUN;$H_Response?$text_cmd' target="]
                  . $config_parms{ 'html_target_speech' . $Http{format} }
                  . qq[">$state</a> ];
                $state =~ s/\+(\d+)/$1/;    # Msagent doesn't like +20, +30, etc
                $msagent_cmd1 .= "$state|" if $state;

                #               $hrefs .= qq[<a href='/RUN;$H_Response?$text_cmd' $ol_info>$state</a> ];
            }
            substr( $msagent_cmd1, -1, 1 ) = ") $suffix";
            $html .= $hrefs;
        }

        # Just display the text, when no states
        else {
            my $text_cmd = $text;
            $text_cmd =~
              s/\+/\%2B/g;   # Use hex 2B = +, as + will be translated to blanks
            $text_cmd =~ s/\'/\%27/g;    # Use hex 27 = '
            $text_cmd =~ tr/\_/\~/;      # Blanks are not allowed in urls
            $text_cmd =~ tr/ /\_/;
            $html .= qq[<b>$text</b>];
            $html .=
              qq[<input type="hidden" name="select_cmd" value='$text_cmd'>\n];
            $msagent_cmd1 = $text;
        }

        $html .= qq[<b>$suffix</b>] if $suffix;
        push @htmls, qq[$html</td></FORM>\n];

        $html = '';

        # Do the states_log entry
        if ( $main::config_parms{ 'html_category_states' . $Http{format} } ) {
            if ( my ( $date, $time, $state ) =
                ( state_log $object)[0] =~ /(\S+) (\S+) *(.*)/ )
            {
                $state_log =
                  "<NOBR><a href='SET;&html_state_log($object_name)'>$date $time</a></NOBR> <b>$state</b>";
            }
            else {
                $state_log = "unknown";
            }
            push @htmls,
              qq[<td align='left' valign='center'>$state_log</td>\n\n];
        }

        # Include MsAgent VR commands
        #       minijeff.Commands.Add "ltOfficeLight", "Control Office Light","Turn ( on | off ) office light", True, True
        my $msagent_id = substr $object_name, 1;

        #       $msagent_script1 .= qq[minijeff.Commands.Add "Run_Command", "$text", "$msagent_cmd1", True, True\n];
        #       $msagent_script2 .= qq[Case "$msagent_id"\n   $msagent_id\n];
        #       $msagent_script1 .= qq[minijeff.Commands.Add "$msagent_id", "$text", "$msagent_cmd1", True, True\n];
        $msagent_cmd1 =~ s/\[\]//;    # Drop [] on stateless commands
        my $msagent_cmd2 = $msagent_cmd1;
        $msagent_cmd2 =~ s/\|/,/g;
        $msagent_script1 .=
          qq[minijeff.Commands.Add "$msagent_id", "$msagent_cmd2", "$msagent_cmd1", True, True\n];
        $msagent_script2 .=
          qq[Case "$msagent_id"\n   Run_Command(UserInput.voice)\n];
    }

    # Create final html
    # moved the target option down to form and a tags to be compatible with IE7, dn
    #   $html = "<BASE TARGET='" . $config_parms{'html_target_speech' . $Http{format}}. "'>\n";
    $html =
      qq[<DIV ID="overDiv" STYLE="position:absolute; visibility:hide; z-index:1;"></DIV>\n]
      . qq[<SCRIPT LANGUAGE="JavaScript" SRC="/lib/overlib.js"></SCRIPT>\n]
      . $html
      if $html_info_overlib;

    if (    $Http{'User-Agent'} =~ /^MS/
        and $Cookies{msagent}
        and $main::config_parms{ 'html_msagent_script_vr' . $Http{format} } )
    {
        my $msagent_file = file_read
          "$config_parms{'html_dir' . $Http{format}}/$config_parms{'html_msagent_script_vr' . $Http{format}}";
        $msagent_file =~ s/<!-- *vr_cmds *-->/$msagent_script1/;
        $msagent_file =~ s/<!-- *vr_select *-->/$msagent_script2/;
        $html = $msagent_file . $html;
    }

    my $cols = 2;
    $cols += 1
      if $main::config_parms{ 'html_category_filename' . $Http{format} };
    $cols += 1 if $main::config_parms{ 'html_category_states' . $Http{format} };
    $cols += 1
      if $main::config_parms{ 'html_info' . $Http{format} } eq 'overlib_link';
    $cols *= 2
      if $main::config_parms{ 'html_category_cols' . $Http{format} } == 2;

    return $html
      . &table_it(
        $cols,
        $main::config_parms{ 'html_category_border' . $Http{format} },
        $main::config_parms{ 'html_category_cellsp' . $Http{format} },
        @htmls
      );
}

# Return html for 1 item
sub html_item {
    my ($name) = @_;
    my $object = &get_object_by_name($name);
    if ( UNIVERSAL::isa( $object, 'Voice_Cmd' ) ) {
        return &html_command_table($name);
    }
    else {
        return &table_it( 1, 1, 0, &html_item_state( $object, $name ) );
    }
}

# List current object state
sub html_item_state {
    my ( $object, $object_type ) = @_;

    my $object_name  = $object->{object_name};
    my $object_name2 = &pretty_object_name($object_name);
    my $isa_X10      = UNIVERSAL::isa( $object, 'X10_Item' );
    my $isa_EIB2     = UNIVERSAL::isa( $object, 'EIB2_Item' );

    # If not a state item, just list it
    unless ( $isa_X10
        or UNIVERSAL::isa( $object, 'Group' )
        or exists $object->{state}
        or $object->{states} )
    {
        return qq[<td></td><td align="left"><b>$object_name2</b></td>\n];
    }

    my $filename  = $object->{filename};
    my $state_now = $object->{state};
    my $html;
    $state_now = ''
      unless defined($state_now);    # Avoid -w uninitialized value msg

    # If >2 possible states, add a Select pull down form
    my @states;
    @states = @{ $object->{states} } if $object->{states};
    @states = split ',', $config_parms{x10_menu_states} if $isa_X10;

    @states = qw(on off) if UNIVERSAL::isa( $object, 'X10_Appliance' );

    my $use_select = 1
      if @states > 2
      and length("@states") >
      $config_parms{ 'html_select_length' . $Http{format} };

    if ($use_select) {

        # Some browsers (e.g. Audrey) do not have full url in Referer :(
        my $referer =
          ( $Http{Referer} =~ /html$/ )
          ? 'referer'
          : "&html_list($object_type)";
        $html .= qq[<FORM action="/SET;$referer?" method="get">\n];
        $html .=
          qq[<INPUT type="hidden" name="select_item" value="$object_name">\n]
          ;    # So we can uncheck buttons
    }

    # Find icon to show state, if not found show state_now in text.
    #  - icon is also used to show state log
    $html .=
      qq[<td align="right"><a href='SET;&html_state_log($object_name)' target=\']
      . $config_parms{ 'html_target_speech' . $Http{format} } . "'>";

    if ( my $h_icon = &html_find_icon_image( $object, $object_type ) ) {
        $html .= qq[<img src="$h_icon" alt="$object_name" border="0"></a>];
    }
    elsif ( $state_now ne '' ) {
        my $temp = $state_now;
        $temp = substr( $temp, 0, 8 ) . '..' if length $temp > 8;
        $html .= $temp . '</a>&nbsp';
    }
    else {
        $html .=
          qq[<img src="/graphics/nostat.gif" alt="no_state" border="0"></a>];
    }
    $html .= qq[</td>\n];

    # Add brighten/dim arrows on X10 Items
    $html .= qq[<td align="left"><b>];
    if ( ( $isa_X10 and !UNIVERSAL::isa( $object, 'X10_Appliance' ) )
        || $isa_EIB2 )
    {

        # Some browsers (e.g. Audrey) do not have full url in Referer :(
        my $referer =
          ( $Http{Referer} =~ /html$/ )
          ? 'referer'
          : "&html_list($object_type)";

        # Note:  Use hex 2B = +, as + means spaces in most urls
        $html .=
          qq[<a href='SET;$referer?$object_name?%2B15'><img src='/graphics/a1+.gif' alt='+' border='0'></a> ];
        $html .=
          qq[<a href='SET;$referer?$object_name?-15'>  <img src='/graphics/a1-.gif' alt='-' border='0'></a> ];
    }

    # Add Select states
    if ($use_select) {
        $html .= qq[<SELECT name="select_state" onChange="form.submit()">\n];
        $html .=
          qq[<option value="pick_a_state_msg" SELECTED> \n];  # Default is blank
        for my $state (@states) {

            #           my $state_url = &escape($state);
            my $state_url = &quote_attribute($state);
            my $state_short = substr $state, 0, 15;
            $html .= qq[<option value=$state_url>$state_short\n];

            #           $html .= qq[<option value="$state_url">$state_short\n];
            #           $html .= qq[<a href='SET;&html_list($object_type)?$object_name?$state'>$state</a> ];
        }
        $html .= qq[</SELECT>\n];
    }

    if (@states) {

        # Find toggle state
        my $state_toggle;
        if ( $object_type eq 'Weather_Item' ) {
        }
        elsif ( $state_now eq ON or $state_now =~ /^[\+\-]?\d/ ) {
            $state_toggle = OFF;
        }
        elsif ( $state_now eq OFF or grep $_ eq ON, @states ) {
            $state_toggle = ON;
        }

        if ($state_toggle) {

            # Some browsers (e.g. Audrey) do not have full url in Referer :(
            my $referer =
              ( $Http{Referer} =~ /html$/ )
              ? 'referer'
              : "&html_list($object_type)";
            $html .=
              qq[<a href='SET;$referer?$object_name=$state_toggle'>$object_name2</a>];
        }
        else {
            $html .= $object_name2;
        }
    }
    else {
        $html .= $object_name2;
    }

    #   else {
    unless ($use_select) {
        for my $state (@states) {
            next unless $state;
            my $state_url = &escape($state);
            my $state_short = substr $state, 0, 15;

            # Some browsers (e.g. Audrey) do not have full url in Referer :(
            my $referer =
              ( $Http{Referer} =~ /html$/ )
              ? 'referer'
              : "&html_list($object_type)";
            $html .=
              qq[ <a href='SET;$referer?$object_name=$state_url'>$state_short</a>];
        }
    }

    $html .= qq[</b></td>];
    $html .= qq[</FORM>] if $use_select;
    return $html . "\n";
}

$Password_Allow{'&html_state_log'} = 'anyone';

sub html_state_log {
    my ($object_name) = @_;
    my $object        = &get_object_by_name($object_name);
    my $object_name2  = &pretty_object_name($object_name);
    my $html          = "<b>$object_name2 states</b><br>\n";
    for my $state ( state_log $object) {
        $html .= "<li>$state</li>\n" if $state;
    }
    return $html . "\n";
}

sub html_info {
    my ($object_name) = @_;
    my $object        = &get_object_by_name($object_name);
    my $object_name2  = &pretty_object_name($object_name);
    my $html          = "<b>$object_name2 info</b><br>\n";
    $html .= $object->{info};
    return $html;
}

sub html_active_href {
    my ( $url, $text ) = @_;
    return qq[<a href=$url>$text</a>];

    # Netscape has problems with this when
    # used with the hide-show javascript in main.shtml / top.html
    return qq[
      <a href=$url>
      <SPAN onMouseOver="this.className='over';"
      onMouseOut="this.className='out';"
      style="cursor: hand"
      class="blue">$text</SPAN></a>
    ];
}

# This will create a link that forces a code reload
sub html_reload_link {
    my ( $url, $link_desc ) = @_;
    return qq[
      <SCRIPT LANGUAGE="JavaScript"><!--
      function updateLink(filename) {
        now = new Date();
      return  filename + '?' + now.getTime();
      }
      //--></SCRIPT>
      <A HREF="$url" onClick="this.href=updateLink('$url')" TARGET="_top">$link_desc</A>
    ];
}

# html -> text, without memory leak!
sub html_to_text {
    my ( $tree, $format, $text );

    # This leaks memory!
    #   $text = HTML::FormatText->new(lm => 0, rm => 150)->format(HTML::TreeBuilder->new()->parse($_[0]));

    $tree = HTML::TreeBuilder->new();
    $format = HTML::FormatText->new( leftmargin => 0, rightmargin => 150 );
    $tree->parse( $_[0] );
    $text = $format->format($tree);
    $tree->delete;    # Avoid a memory leak!
    return $text;
}

sub pretty_object_name {
    my ($name) = @_;
    $name = substr( $name, 1 ) if substr( $name, 0, 1 ) eq "\$";
    $name =~ tr/_/ /;
    $name = ucfirst $name;
    return $name;
}

# Avoid mh pauses by printing to slow remote clients with a 'forked' program
sub print_socket_fork {
    my ( $socket, $html ) = @_;
    return unless $html;
    my $length = length $html;
    $socket_fork_data{length} = $length;

    # These sizes are picked a bit randomly.  Don't need to fork on small files
    #  - A few Win98 users had problems, but unix is ok
    if (    ( $main::config_parms{http_fork} )
        and ( $length > 3000 and !&is_local_address() or $length > 10000 ) )
    {
        print "http: printing with forked socket: l=$length s=$socket\n"
          if $main::Debug{http};
        if ($OS_win) {
            if ( $main::config_parms{http_fork} eq 'memmap' ) {
                $http_fork_count =
                  ( $http_fork_count % 65535 ) + 1;    # more than enough :^)
                my $mapname = "//MemMap/HttpFork" . "$http_fork_count";

                # seems we need to map this on a virtual memory page boundry
                my $mapsize =
                  $length + $http_fork_page - ( $length % $http_fork_page );
                my $mem = $http_fork_mem->OpenMem( $mapname, $mapsize );
                $mem->Write( \$html, 0 );

                # This ugly fork can only do one at a time :(
                if ( $socket_fork_data{process} ) {
                    print
                      "http: deferring socket_fork s=$socket mapname=$mapname\n"
                      if $main::Debug{http};
                    push @{ $socket_fork_data{next} },
                      [ $socket, $mem, $http_fork_count ];
                    $leave_socket_open_passes =
                      -1;    # This will not close the socket
                }
                else {
                    &print_socket_fork_win( $socket, $mem, $http_fork_count );
                }
            }
            else {
                # This ugly fork can only do one at a time :(
                if ( $socket_fork_data{process} ) {
                    print "http: defering socket_fork s=$socket\n"
                      if $main::Debug{http};
                    push @{ $socket_fork_data{next} }, [ $socket, \$html ];
                    $leave_socket_open_passes =
                      -1;    # This will not close the socket
                }
                else {
                    &print_socket_fork_win( $socket, \$html );
                }
            }
        }
        else {
            &print_socket_fork_unix( $socket, $html );
        }
    }
    else {
        print $socket $html;
    }
}

# Magic simulated fork using copied file handles from
#  Example: 7.22 of "Win32 Perl Scripting: Administrators Handbook" by Dave Roth
#  Published by New Riders Publishing  ISBN # 1-57870-215-1

sub print_socket_fork_win {
    my ( $socket, $ptr, $fork_count ) = @_;
    my ( $process, $perl, $cmd );

    $cmd = 'perl' if $perl = &main::which('perl.exe');
    $cmd = 'mhe -run' if !$perl and $perl = &main::which('mhe.exe');
    if ($cmd) {
        if ($fork_count) {
            my $mapname = "//MemMap/HttpFork" . "$fork_count";
            $cmd .= " $Pgm_Path/print_socket_fork_memmap.pl $mapname";
        }
        else {
            my $file = "$config_parms{data_dir}/http_fork.html";
            &file_write( $file, $$ptr );
            $cmd .= " $Pgm_Path/print_socket_fork.pl $file";
        }

        # Processes can only inherit Win32 filehandles :(
        # We only have 3 available handles (STDOUT,STDIN,STDERR)
        # If we use these with parallel processes, they mess up,
        # so make sure we only call this once at a time
        open OLD_HANDLE, ">&STDOUT"
          or print "\nsocket_fork error: can not backup STDOUT: $!\n";
        if ( my $fileno = $socket->fileno() ) {
            print
              "http: redirecting socket fn=$fileno s=$socket fork=$fork_count\n"
              if $main::Debug{http};
            unless ( open STDOUT, ">&$fileno" ) {
                print "http error: Can not redirect STDOUT: $!\n";
                print "Older windows (like $Info{OS_name}) can not do this.\n"
                  if Win32::IsWin95;
            }
            my $pid = Win32::Process::Create( $process, $perl, $cmd, 1, 0, '.' )
              or print "Warning, run error: pgm_path=$perl $cmd\n error=",
              Win32::FormatMessage( Win32::GetLastError() ), "\n";
            open STDOUT, ">&OLD_HANDLE"
              or print
              "\nsocket_fork error: can not redir STDIN to orig value: $!\n";
            close OLD_HANDLE;

            # Need to close the socket only after the process is done :(
            $socket_fork_data{forkmem} = $ptr if $fork_count;
            $socket_fork_data{process} = $process;
            $socket_fork_data{socket}  = $socket;
            $leave_socket_open_passes = -1;    # This will not close the socket

            #           shutdown($socket, 0);   # "how":  0=no more receives, 1=sends, 2=both
            #           $socket->close();
        }
    }
    else {
        print "\nsocket_fork_win error: no perl.exe or mhe.exe found\n"
          unless $cmd;
        if ($fork_count) {
            $ptr->Read( \my $html, 0, $ptr->GetDataSize );
            $ptr->Close;
            print $socket $html;
        }
        else {
            print $socket $$ptr;
        }
    }

}

# Forks are MUCH easier in unix :)
sub print_socket_fork_unix {
    my ( $socket, $html ) = @_;

    my $pid = fork;
    if ( defined $pid && $pid == 0 ) {
        print $socket $html;
        $socket->close;

        # This avoids 'Unexpected async reply' if mh -tk 1
        &POSIX::_exit(0)

          #       exit;
    }
    else {
        # Not sure why, but I get a broken pipe if I shutdown send or both.
        shutdown( $socket, 0 );    # "how":  0=no more receives, 1=sends, 2=both

        #       $socket->close;
    }
}

# Netscape 4.? hangs if we print > 28k bytes all at once to the socket :(
#  - this does not fix the problem :((
#  - but printing with a fork as above does solve the problem :)
sub print_socket2 {
    my ( $socket, $html ) = @_;

    #   binmode $socket;
    #    my $old_fh = select($socket);
    #    $| = 1;
    #    select($old_fh);
    my $length = length $html;
    print "db l=$length\n";
    my $pos = 0;
    while ( $pos <= $length ) {
        print $socket substr $html, $pos, 1000;
        $pos += 1000;
    }
}

# - These 3 subs from David Mark

sub quote_attribute {
    ($_) = @_;
    s/\x22/\&quot;/g;
    '"' . $_ . '"';
}

sub escape {
    ($_) = @_;
    s/ /\+/g;
    s/([^a-zA-Z0-9_\-.\+])/uc sprintf("%%%02x",ord($1))/eg;
    $_;
}

sub unescape {
    ($_) = @_;
    tr/+/ /;
    s/%(..)/pack("c",hex($1))/ge;
    $_;
}

# Use this
#  - /SET;&referer(/ia5/lights/list_items.pl|$object_type)
sub referer {
    my ($r) = @_;
    $r =~ tr/\|/?/;
    $Http{Referer} =~ m|(https?://\S+?)/|;
    $r = $1 . $r unless $r =~ /^http/;
    return $r;
}

sub recompose_uri {
    my $request;
    my $querystring;
    my $encoded_request     = '';
    my $encoded_querystring = '';
    ($_) = @_;

    $request = $_;

    if (/(.*?)\?(.*)/) {
        $request     = $1;
        $querystring = $2;
    }

    my @atoms = split '/', $request;

    foreach (@atoms) {
        $encoded_request .= '/' if $encoded_request;
        $encoded_request .= (/:/) ? $_ : escape($_);

    }

    if ($querystring) {
        my $name;
        my $value;
        my @params = split '&', $querystring;
        foreach (@params) {
            if ( ( $name, $value ) = /(.*?)\=(.*)/ ) {

                $encoded_querystring .= '&amp;' if $encoded_querystring;
                $encoded_querystring .= escape($name) . '=' . escape($value);
            }
            else {
                $encoded_querystring .= '&amp;' if $encoded_querystring;
                $encoded_querystring .= escape($_);

            }

        }
        return $encoded_request . '?' . $encoded_querystring;
    }
    else {
        $encoded_request;
    }
}

sub vars_save {
    my @table_items;
    unless ( $Authorized or $main::config_parms{password_protect} !~ /vars/i ) {
        return "<h4>Not Authorized to view Variables</h4>";
    }
    for my $key ( sort keys %Save ) {
        my $value = ( $Save{$key} ) ? $Save{$key} : '';
        push @table_items, "<td align='left'><b>$key:</b> $value</td>";
    }
    return &html_header("List Save Variables")
      . &table_it( 2, 1, 1, @table_items );
}

sub vars_global {
    my @table_items;
    unless ( $Authorized or $main::config_parms{password_protect} !~ /vars/i ) {
        return "<h4>Not Authorized to view Variables</h4>";
    }
    for my $key ( sort keys %main:: ) {

        # Assume all the global vars we care about are $Ab...
        next if $key !~ /^[A-Z][a-z]/ or $key =~ /\:/;
        next if $key eq 'Save' or $key eq 'Tk_objects';    # Covered elsewhere
        next if $key eq 'Socket_Ports';
        next if $key eq 'User_Code';

        my $glob = $main::{$key};
        if ( ${$glob} ) {
            my $value = ${$glob};
            next if $value =~ /HASH/;     # Skip object pointers
            next if $key eq 'Password';
            push @table_items, "<td align='left'><b>\$$key:</b> $value</td>";
        }
        elsif ( %{$glob} ) {
            for my $key2 ( sort keys %{$glob} ) {
                my $value = ${$glob}{$key2} . "\n";
                $value = '' unless $value;    # Avoid -w uninitialized value msg
                next if $value =~ /HASH/;     # Skip object pointers
                push @table_items,
                  "<td align='left'><b>\$$key\{$key2\}:</b> $value</td>";
            }
        }
    }
    return &html_header("List Global Variables")
      . &table_it( 2, 1, 1, @table_items );
}

sub vxml_page {
    my ($vxml) = @_;

    my $header = "Content-type: text/xml";

    #   $header    = $Cookie . $header if $Cookie;

    return <<eof;
HTTP/1.0 200 OK
Server: MisterHouse
$header
<?xml version="1.0" encoding="UTF-8"?>

<vxml version="2.0"
application="http://resources.tellme.com/lib/universals.vxml">

$vxml

</vxml>
eof

}

# vxml for audio text/wav followed by a goto
sub vxml_audio {
    my ( $name, $text, $wav, $goto ) = @_;
    my $vxml;
    $vxml = "<form id='$name'>\n <block>\n  <audio ";
    $vxml .= "src='$wav'" if $wav;
    $vxml .= ">$text</audio>\n";
    $vxml .= "  <goto next='$goto'/>\n </block></form>";
    return $vxml;
}

# vxml for a basic form with grammar. Called from &menu_vxml
sub vxml_form {
    my %parms = @_;
    my ( $prompt, $grammar, $filled );
    my @grammar = @{ $parms{grammar} };
    my @action  = @{ $parms{action} };
    my @goto    = @{ $parms{goto} };
    my $noinput = 'Sorry, I did not hear anything.';
    my $nomatch = 'What was that again?';
    $prompt = qq|<prompt><audio>$parms{prompt}</audio></prompt>|
      if $parms{prompt};

    # Add previous menu option
    unshift @grammar, 'previous';
    unshift @goto, ( $parms{prev} ) ? "#$parms{prev}" : '_lastanchor';
    unshift @action, '';
    unless ( $parms{help} ) {
        $parms{help} = 'Speak or key one of ' . scalar @grammar . ' commands: ';
        my $i = 1;
        for my $cmd (@grammar) {
            $parms{help} .= $i++ . ": $cmd, ";
        }
    }

    #   $parms{help}    = "Speak or key one of " . scalar @grammar . " commands: " . join(', ', @grammar) unless $parms{help};

    my $i = 0;
    for my $text ( 'help', @grammar ) {
        my $cmd = $text;

        # These are illegal characters for grammar
        $cmd =~ s/\+/ plus /g;
        $cmd =~ s/\-/ minus /g;
        $cmd =~ s/\%/ percent/g;
        $cmd =~ s/\&//g;
        $cmd =~ s/\^/ up /g;
        $cmd = 'down' if $cmd eq 'v';

        #       $cmd =~ s/\?/\??/g; # Avoid ? in voice_cmd ... don't know how to pass them via tellme

        $cmd = lc $cmd;
        $cmd = "dtmf-$i $cmd" if $i < 10;
        if ( $i == 0 ) {
            $grammar .= qq|[$cmd] {<option "help">}\n|;
        }
        else {
            $grammar .= qq|[$cmd] {<option "$i">}\n|;
            $filled  .= qq|  <if cond='$i'>\n|;
            $filled .= qq|   <audio>$text</audio>\n| unless $text eq 'previous';
            $filled .= qq|   $action[$i-1]\n| if $action[ $i - 1 ];
            $filled .= qq|   <goto expr="'$goto[$i-1]'"/>\n  </if>\n|;
        }
        $i++;
    }
    return <<eof;
 <form id='$parms{name}'>
  <field name="$parms{name}">
   $prompt
   <grammar>
    <![CDATA[[
$grammar
    ]]]>
   </grammar>
   <noinput>
    <audio>$noinput</audio><reprompt/>
   </noinput>
   <nomatch>
    <audio>$nomatch</audio>
    <reprompt/>
   </nomatch>
   <catch>
    <reprompt/>
   </catch>
   <help>
    <audio>$parms{help}</audio><reprompt/>
   </help>
   <filled>
    $filled
   </filled>
  </field>
 </form>
eof
}

sub widgets {
    my ( $request_type, $request_category ) = @_;

    $request_category = '' unless $request_category;

    unless ( $Authorized
        or $main::config_parms{password_protect} !~ /widgets/i )
    {
        return "<h4>Not Authorized to view Widgets</h4>";
    }

    my @table_items;
    my $cols = 6;

    # Note, can not hide tk widgets yet :(
    #  - need to make them into a Generic_Object
    for my $ptr (@Tk_widgets) {

        my @data = @$ptr;

        my $category = shift @data;
        my $type     = shift @data;
        $category =~ s/ /_/;

        next
          unless $request_type eq 'search'
          or (  ( $request_type eq 'all' or $type eq $request_type )
            and ( !$request_category or $request_category eq $category ) );

        my $search = $request_category if $request_type eq 'search';

        if ( $type eq 'label' ) {

            #            $cols = 2;
            push @table_items, &widget_label( $search, @data );
        }
        elsif ( $type eq 'entry' ) {
            push @table_items, &widget_entry( $search, @data );
        }
        elsif ( $type eq 'radiobutton' ) {
            push @table_items, &widget_radiobutton( $search, @data );
        }
        elsif ( $type eq 'checkbutton' ) {
            push @table_items, &widget_checkbutton( $search, @data );
        }
    }

    # List a header unless we are listing for a category, which already has a header
    my $header =
      ($request_category) ? ' ' : &html_header("List $request_type widgets");
    return $header . &table_it( $cols, 0, 0, @table_items );
}

sub widget_label {
    my @table_items;
    my $search = shift @_;
    for my $pvar (@_) {

        # Allow for state objects
        my $label;
        if ( ref $pvar ne 'SCALAR' and $pvar->can('set') ) {
            $label = $pvar->state;
        }
        else {
            $label = $$pvar;
        }
        next
          unless $label
          and $label =~ /\S{3}/;    # Drop really short labels, like tk_eye
        next if $search and $label !~ /$search/i;
        my ( $key, $value ) = $label =~ /(.+?\:)(.*)/;
        $value = '' unless $value;
        push @table_items, qq[<tr><td align='left' colspan=1><b>$key</b></td>]
          . qq[<td align='left' colspan=5>$value</td></tr>];

        #       push @table_items, qq[<td align='left' colspan=4>$value</td>];
        #       $label =~ s/(.+?\:)/<b>$1<\/b>/; # Bold the label part
        #       push @table_items, qq[<tr><td align='left' colspan=6>$label</td></tr>];
    }
    return @table_items;
}

sub widget_entry {
    my @table_items;
    my $search = shift @_;
    while (@_) {
        my $label = shift @_;
        my $pvar  = shift @_;
        next unless $pvar;

        next if $search and $label !~ /$search/i;
        push @table_items, qq[<td align=left><b>$label:</b></td>];

        # Put form outside of td, or else td gets too high
        my $html =
            qq[<FORM name="widgets_entry" ACTION="SET;$H_Response"  target=\']
          . $config_parms{ 'html_target_speech' . $Http{format} }
          . "'> <td align='left'>";
        $html_pointers{ ++$html_pointer_cnt } = $pvar;
        $html_pointers{ $html_pointer_cnt . "_label" } = $label;

        # Allow for state objects
        my $value;
        if ( ref $pvar ne 'SCALAR' and $pvar->can('set') ) {
            $value = $pvar->state;
        }
        else {
            $value = $$pvar;
        }
        $value = '' unless $value;
        $html .= qq[<INPUT SIZE=10 NAME="$html_pointer_cnt" value="$value">];
        $html .= qq[</td></FORM>\n];
        push @table_items, $html;
    }

    #   while (@table_items < 6) {
    while ( @table_items % 6 ) {
        push @table_items, qq[<td></td>];
    }
    return @table_items;
}

sub widget_radiobutton {
    my @table_items;
    my $search = shift @_;
    my ( $label, $pvar, $pvalue, $ptext ) = @_;
    return if $search and $label and $label !~ /$search/i;
    my $html =
      qq[<FORM name="widgets_radiobutton" ACTION="SET;$H_Response"  target=\']
      . $config_parms{ 'html_target_speech' . $Http{format} } . "'>\n";
    $html .= qq[<td align='left'><b>$label</b></td>];
    push @table_items, $html;
    $html_pointers{ ++$html_pointer_cnt } = $pvar;
    my @text = @$ptext if $ptext;  # Copy, so do not destroy original with shift

    for my $value (@$pvalue) {
        my $text = shift @text;
        $text = $value unless defined $text;

        # Allow for state objects
        my $checked = '';
        if ( ref $pvar ne 'SCALAR' and $pvar->can('set') ) {
            $checked = 'CHECKED' if $pvar->state eq $value;
        }
        else {
            $checked = 'CHECKED' if $$pvar and $$pvar eq $value;
        }
        $html =
          qq[<td align='left'><INPUT type="radio" NAME="$html_pointer_cnt" value="$value" $checked ];
        $html .= qq[$checked onClick="form.submit()">$text</td>];
        push @table_items, $html;
    }
    $table_items[$#table_items] .= qq[</form>\n];

    #   while (@table_items < 6) {
    while ( @table_items % 6 ) {
        push @table_items, qq[<td></td>];
    }
    return @table_items;
}

sub widget_checkbutton {
    my @table_items;

    # One form per button??
    my $search = shift @_;
    while (@_) {
        my $text = shift @_;
        my $pvar = shift @_;
        next unless $pvar;

        next if $search and $text !~ /$search/i;
        $html_pointers{ ++$html_pointer_cnt } = $pvar;
        my $checked = ($$pvar) ? 'CHECKED' : '';
        my $html =
          qq[<FORM name="widgets_radiobutton" ACTION="SET;$H_Response"  target=\']
          . $config_parms{ 'html_target_speech' . $Http{format} } . "'>\n";
        $html .= qq[<INPUT type="hidden" name="$html_pointer_cnt" value='0'>\n]
          ;    # So we can uncheck buttons
        $html .=
          qq[<td align='left'><INPUT type="checkbox" NAME="$html_pointer_cnt" value="1" $checked onClick="form.submit()">$text</td></FORM>\n];
        push @table_items, $html;
    }
    while ( @table_items % 6 ) {
        push @table_items, qq[<td></td>];
    }
    return @table_items;
}

# dir_index can be called with this fun url:
#    http://house:8080/RUN;&dir_index('/pictures','date',0)
# or with a record in a .shtml file like this:
#       <!--#include code="&dir_index('/pictures','date',0)"-->

$Password_Allow{'&dir_index'} = 'anyone';

sub dir_index {
    my ( $dir_html, $sortby, $reverse, $filter, $limit ) = @_;

    #   print "dbx in dir_index for $dir_html\n";

    $filter = '' unless $filter;    # Avoid uninit warnings
    $sortby = '' unless $sortby;    # Avoid uinit warnings
    my $reverse2   = ($reverse) ? 0   : 1;
    my $sort_order = ($reverse) ? '+' : '-';
    my ($dir)      = &http_get_local_file($dir_html);
    my $dir_tr     = $dir_html;
    $dir_tr =~ s/\//\%2F/g;

    opendir DIR, $dir
      or print
      "http_server: Could not open dir_index for $dir_html dir=$dir: $!\n";
    my @files = sort readdir DIR;
    close DIR;

    @files = grep /$filter/, @files if $filter;    # Drop out files if requested

    $filter =~ s/\\/\%5C/g;
    my $html =
      qq[<table width=80% border=0 cellspacing=0 cellpadding=0>\n<tr height=50>];
    $html .=
      qq[<td><a href="SET;&dir_index('$dir_tr','name',$reverse2,'$filter')">$sort_order Sort by Name</a></td>\n];
    $html .=
      qq[<td><a href="SET;&dir_index('$dir_tr','type',$reverse2,'$filter')">$sort_order Sort by Type</a></td>\n];
    $html .=
      qq[<td><a href="SET;&dir_index('$dir_tr','size',$reverse2,'$filter')">$sort_order Sort by Size</a></td>\n];
    $html .=
      qq[<td><a href="SET;&dir_index('$dir_tr','date',$reverse2,'$filter')">$sort_order Sort by Date</a></td></tr>\n];

    my %file_data;
    for my $file (@files) {
        ( $file_data{$file}{size}, $file_data{$file}{date} ) =
          ( stat("$dir/$file") )[ 7, 9 ];
        my ($type) = $file =~ /(\.[^\.]+)$/;
        $type = '' unless $type;
        $type = 'Directory' if -d "$dir/$file";
        $file_data{$file}{type} = $type;

        #       $file_data{$file}{type} = '' $1 if $file =~ /(\.[^\.]+)$/;
        #        if ($file =~ /(\.[^\.]+)$/) {
        #            $file_data{$file}{type} = $1;
        #        }
        #        else {
        #            $file_data{$file}{type} = '';
        #    }

    }
    if ( $sortby eq 'date' or $sortby eq 'size' ) {
        @files = sort {
                 $file_data{$a}{$sortby} <=> $file_data{$b}{$sortby}
              or $a cmp $b
        } @files;
    }
    elsif ( $sortby eq 'type' ) {
        @files = sort {
                 $file_data{$a}{$sortby} cmp $file_data{$b}{$sortby}
              or $a cmp $b
        } @files;
    }
    @files = reverse @files if $reverse;
    my $i = 0;
    for my $file (@files) {
        my $file_date = localtime $file_data{$file}{date};
        my $file_ref  = $file;
        $file_ref =~ s/ /%20/g;
        $html .= "<tr><td><a href=$dir_html/$file_ref>$file</a></td>\n";
        $html .= "<td>$file_data{$file}{type}</td>\n";
        $html .= "<td>$file_data{$file}{size}</td>\n";
        $html .= "<td>$file_date</td></tr>\n";
        last if $limit and $i++ > $limit;
    }

    return $html . "</table>\n";
}

# From: http://allnetdevices.com/faq/?pair=04.005
#Don't use this.  Use meta cache control in menu_run instead.
#Expires: Mon, 26 Jul 1997 05:00:00 GMT
#Last-Modified: DD. month YYYY HH:MM:SS GMT
#Cache-Control: no-cache, must-revalidate
#Pragma: no-cache

sub wml_page {
    my ($wml) = @_;
    $wml = <<"eof";
HTTP/1.0 200 OK
Server: MisterHouse
Content-Type: text/vnd.wap.wml

<?xml version="1.0"?>
<!DOCTYPE wml PUBLIC "-//PHONE.COM//DTD WML 1.1//EN"
			"http://www.phone.com/dtd/wml11.dtd" >
<wml>
  $wml
</wml>
eof
    return $wml;
}

return 1;    # Make require happy

# Example on updateing 2 frames at once
#<SCRIPT LANGUAGE=JAVASCRIPT><!--
#function fnUpdate(){
#   top.frame1.location="URL1";
#   top.frame2.location="URL2";
#}// --></SCRIPT>...
#<A HREF="URL1" TARGET=frame1 onClick="fnUpdate();">Update frames</A>
#

=begin comment
Examples of browser requests (by running test_http_server.pl)
GET http://house:8081/ HTTP/1.0
Connection: Keep-Alive
Accept: image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png, */*
Accept-Charset: iso-8859-1,*,utf-8
Accept-Language: en
Authorization: Basic YnJ1Y2Vfd2ludGVyOmFiY2Rl
Host: house:8081
User-Agent: Mozilla/4.04 [en] (X11; I; AIX 4.3)
Cookie: xyzID=19990118162505401224000000
=end comment


#
# $Log: http_server.pl,v $
# Revision 1.98  2006/01/28 02:28:12  mattrwilliams
# Added <!doctype ...  as a valid start of a complete html page in html_page.
#
# Revision 1.97  2005/10/02 17:24:47  winter
# *** empty log message ***
#
# Revision 1.96  2005/05/22 18:13:07  winter
# *** empty log message ***
#
# Revision 1.95  2005/03/20 19:02:02  winter
# *** empty log message ***
#
# Revision 1.94  2005/01/23 23:21:45  winter
# *** empty log message ***
#
# Revision 1.93  2004/11/22 22:57:26  winter
# *** empty log message ***
#
# Revision 1.92  2004/09/25 20:01:19  winter
# *** empty log message ***
#
# Revision 1.91  2004/07/05 23:36:37  winter
# *** empty log message ***
#
# Revision 1.90  2004/06/06 21:38:44  winter
# *** empty log message ***
#
# Revision 1.89  2004/05/02 22:22:17  winter
# *** empty log message ***
#
# Revision 1.88  2004/04/25 18:20:17  winter
# *** empty log message ***
#
# Revision 1.87  2004/03/23 01:58:08  winter
# *** empty log message ***
#
# Revision 1.86  2004/02/01 19:24:35  winter
#  - 2.87 release
#
# Revision 1.85  2003/12/22 00:25:06  winter
#  - 2.86 release
#
# Revision 1.84  2003/12/01 03:09:52  winter
#  - 2.85 release
#
# Revision 1.83  2003/11/23 20:26:02  winter
#  - 2.84 release
#
# Revision 1.82  2003/09/02 02:48:46  winter
#  - 2.83 release
#
# Revision 1.81  2003/07/06 17:55:12  winter
#  - 2.82 release
#
# Revision 1.80  2003/04/20 21:44:08  winter
#  - 2.80 release
#
# Revision 1.79  2003/03/09 19:34:42  winter
#  - 2.79 release
#
# Revision 1.78  2003/02/08 05:29:24  winter
#  - 2.78 release
#
# Revision 1.77  2003/01/18 03:32:42  winter
#  - 2.77 release
#
# Revision 1.76  2003/01/12 20:39:21  winter
#  - 2.76 release
#
# Revision 1.75  2002/12/24 03:05:08  winter
# - 2.75 release
#
# Revision 1.74  2002/12/02 04:55:20  winter
# - 2.74 release
#
# Revision 1.73  2002/11/10 01:59:57  winter
# - 2.73 release
#
# Revision 1.72  2002/09/22 01:33:24  winter
# - 2.71 release
#
# Revision 1.71  2002/08/22 04:33:20  winter
# - 2.70 release
#
# Revision 1.70  2002/07/01 22:25:28  winter
# - 2.69 release
#
# Revision 1.69  2002/05/28 13:07:52  winter
# - 2.68 release
#
# Revision 1.68  2002/03/31 18:50:41  winter
# - 2.66 release
#
# Revision 1.67  2002/03/02 02:36:51  winter
# - 2.65 release
#
# Revision 1.66  2002/01/23 01:50:33  winter
# - 2.64 release
#
# Revision 1.65  2002/01/19 21:11:12  winter
# - 2.63 release
#
# Revision 1.64  2001/12/16 21:48:41  winter
# - 2.62 release
#
# Revision 1.63  2001/11/18 22:51:43  winter
# - 2.61 release
#
# Revision 1.62  2001/10/21 01:22:32  winter
# - 2.60 release
#
# Revision 1.61  2001/09/23 19:28:11  winter
# - 2.59 release
#
# Revision 1.60  2001/08/12 04:02:58  winter
# - 2.57 update
#
# Revision 1.59  2001/06/27 13:17:39  winter
# - 2.55 release
#
# Revision 1.58  2001/06/27 03:45:14  winter
# - 2.54 release
#
# Revision 1.57  2001/05/28 21:14:38  winter
# - 2.52 release
#
# Revision 1.56  2001/05/06 21:07:26  winter
# - 2.51 release
#
# Revision 1.55  2001/04/15 16:17:21  winter
# - 2.49 release
#
# Revision 1.54  2001/03/24 18:08:38  winter
# - 2.47 release
#
# Revision 1.53  2001/02/04 20:31:31  winter
# - 2.43 release
#
# Revision 1.52  2001/01/20 17:47:50  winter
# - 2.41 release
#
# Revision 1.51  2000/12/21 18:54:15  winter
# - 2.38 release
#
# Revision 1.50  2000/12/03 19:38:55  winter
# - 2.36 release
#
# Revision 1.49  2000/11/12 21:53:14  winter
# - 2.34 release
#
# Revision 1.48  2000/11/12 21:02:38  winter
# - 2.34 release
#
# Revision 1.47  2000/10/22 16:48:29  winter
# - 2.32 release
#
# Revision 1.46  2000/10/09 02:31:13  winter
# - 2.30 update
#
# Revision 1.45  2000/10/01 23:29:40  winter
# - 2.29 release
#
# Revision 1.44  2000/09/09 21:19:11  winter
# - 2.28 release
#
# Revision 1.43  2000/08/19 01:25:08  winter
# - 2.27 release
#
# Revision 1.42  2000/06/24 22:10:55  winter
# - 2.22 release.  Changes to read_table, tk_*, tie_* functions, and hook_ code
#
# Revision 1.41  2000/05/06 16:34:32  winter
# - 2.15 release
#
# Revision 1.40  2000/04/09 18:03:19  winter
# - 2.13 release
#
# Revision 1.39  2000/03/10 04:09:01  winter
# - Add Ibutton support and more web changes
#
# Revision 1.38  2000/02/24 14:02:41  winter
# - fixed a Category and icon bug.  Add description option.
#
# Revision 1.37  2000/02/20 04:47:55  winter
# -2.01 release
#
# Revision 1.36  2000/02/15 04:38:59  winter
# - fix list?xyz shtml include.  Fix + -> ' ' on entry bug
#
# Revision 1.35  2000/02/13 03:57:27  winter
#  - 2.00 release.  New web server interface
#
# Revision 1.34  2000/02/12 06:11:37  winter
# - commit lots of changes, in preperation for mh release 2.0
#
# Revision 1.33  2000/02/02 14:10:43  winter
# - check in Dave Lounsberry's table/icon updates.
#
# Revision 1.30  1999/12/13 00:05:45  winter
# - take out hard coded fonts.  Add my html_style options
#
# Revision 1.29  1999/10/09 20:40:29  winter
# - add password_protect all
#
# Revision 1.28  1999/09/27 03:20:03  winter
# - swizle _ to ~_, add http to password_check, change leave_socket_open from 100 to 2.
#
# Revision 1.27  1999/09/12 16:57:50  winter
# - switch to html_dir
#
# Revision 1.26  1999/08/30 00:25:15  winter
# - allow for .pl files
#
# Revision 1.25  1999/08/01 01:30:59  winter
# - use <p> in last_displayed newlines.  Add Password_Allow
#
# Revision 1.24  1999/07/28 23:30:39  winter
# - add last_displayed support
#
# Revision 1.23  1999/07/21 21:16:09  winter
# - add shtml support.  Query password_protected.
#
# Revision 1.22  1999/07/05 22:37:22  winter
# - add url translation code.  Add _label to html_pointers for %Tk_entry
#
# Revision 1.21  1999/06/27 20:15:44  winter
# - add html_response function/subroutine option.
#
# Revision 1.20  1999/06/22 00:41:45  winter
# - change how $h_repsonse is specified
#
# Revision 1.19  1999/06/20 22:34:12  winter
# - allow for h_response on SET and RUN.
#
# Revision 1.18  1999/05/30 21:07:05  winter
# - add web_widget.
#
# Revision 1.17  1999/03/21 17:32:40  winter
# - add 'basic realm' to authentication code
#
# Revision 1.16  1999/02/26 14:31:25  winter
# - default to un-authorized
#
# Revision 1.15  1999/02/21 00:26:04  winter
# - add password authentication
#
# Revision 1.14  1999/02/16 02:04:49  winter
# - add group listing
#
# Revision 1.13  1999/02/08 00:30:27  winter
# - add $fileitem to lists.  Add search function
#
# Revision 1.12  1999/02/04 14:37:11  winter
# - fix path bug ... do prefix check for \/
#
# Revision 1.11  1999/02/01 00:06:16  winter
# - check requests with ^ in re string.  top_10_list was being parsed as 'list'
#
# Revision 1.10  1999/01/24 20:03:02  winter
# - allow for default index.html.  Fix misc so vcr programing works.
#
# Revision 1.9  1999/01/23 16:29:56  winter
# *** empty log message ***
#
# Revision 1.8  1999/01/23 16:24:25  winter
# - re-tabify
#
# Revision 1.7  1999/01/13 14:10:37  winter
# - use generic, object socket handles
#
# Revision 1.6  1999/01/10 02:28:32  winter
# - change from loop_code_was_run to leave_socket_open, for better 'last spoken' updates
#
# Revision 1.5  1999/01/07 01:57:46  winter
# - minor fixes
#
# Revision 1.4  1998/12/10 14:34:51  winter
# - add html_file option and support new template feature
#
# Revision 1.3  1998/12/08 13:54:18  winter
# - add webname categories
#
# Revision 1.2  1998/12/07 14:37:18  winter
# - some sort of update :)
#
# Revision 1.1  1998/09/12 22:12:02  winter
# - created.
#
#
