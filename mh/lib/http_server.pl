#---------------------------------------------------------------------------
#  This lib provides the mister house web server routines
#  Change log is at the bottom
#---------------------------------------------------------------------------

use strict;

use vars qw(%Http %Cookies $Authorized);
$Authorized = 0;

my($leave_socket_open_passes, $leave_socket_open_action);
my($Cookie, $H_Response, $html_pointer_cnt, %html_pointers, $browser_format);

my %mime_types = (
                  'htm'   => 'text/html',
                  'html'  => 'text/html',
                  'shtml' => 'text/html',
                  'vxml'  => 'text/html',
                  'pl'    => 'text/html',
                  'txt'   => 'text/plain',
                  'png'   => 'image/png',
                  'gif'   => 'image/gif',
                  'jpg'   => 'image/jpeg',
                  'wml'   => 'text/vnd.wap.wml',
                  'wmls'  => 'text/vnd.wap.wmlscript',
                  'wbmp'  => 'image/vnd.wap.wbmp',  
                  'bmp'   => 'image/bmp',
                  'wmls'  => 'text/vnd.wap.wmlscript',
                  'wmlc'  => 'application/vnd.wap.wmlc',
                  'wmlsc' => 'application/vnd.wap.wmlscriptc',
);


my (%http_dirs, %html_icons, $html_info_overlib, %password_protect_dirs, %http_agent_formats);
sub main::http_read_parms {
    
                                # html_alias1=/aprs=>e:/misterhouse/web/aprs
    for my $parm (keys %main::config_parms) {
        next unless $parm =~ /^html_alias/;
        next unless $main::config_parms{$parm} =~ /(\S+)\s+(\S+)/;
                                # This doesn't work ??
        print " - html alias: $1 => $2\n" if $main::config_parms{debug} eq 'http';
        if (-d $2) {
            $http_dirs{$1} = $2;
        }
        else {
            print "   html_alias alias $1 is not a directory: $2\n";
        }
    }
            
    $html_info_overlib = 1 if $main::config_parms{html_info} and $main::config_parms{html_info} =~ 'overlib';

#html_user_agents    = Windows CE=>1,whatever=>2
    for my $temp (split ',', $config_parms{html_browser_formats}) {
        my ($agent, $format) = $temp =~ / *(.+) *=> *(\d)/;
        $http_agent_formats{$agent} = $format;
    }
    
    undef %html_icons;          # Refresh lib/http_server.pl icons

    %password_protect_dirs = map {$_, 1} split ',', $main::config_parms{password_protect_dirs};

                                # Set defaults for all html_ parms for alternate browser user-agent web_formats
    for my $parm (grep /^html_.*[^\d]$/, keys %main::config_parms) {
        $main::config_parms{$parm . '1'} = $main::config_parms{$parm} unless defined $main::config_parms{$parm . '1'};
        $main::config_parms{$parm . '2'} = $main::config_parms{$parm} unless defined $main::config_parms{$parm . '2'};
        $main::config_parms{$parm . '3'} = $main::config_parms{$parm} unless defined $main::config_parms{$parm . '3'};
    }

}


sub process_http_request {
    my ($socket, $header) = @_;

    my $time_check = time;

    print "Http request: $header\n" if $main::config_parms{debug} eq 'http_get';

    $leave_socket_open_passes = 0;

    my ($text, $h_response, $h_index, $h_list, $item, $state);
    undef $h_response;

    $Authorized = &password_check(undef, 'http') ? 0 : 1; # If no $Password or local address, defaults to authorized

                                # Read http header data
    $Cookie = '';  undef %Cookies; undef %Http;
    $H_Response = 'last_response';
    my $temp;
    while (<$socket>) {
        last unless /\S/;
        $temp .= $_;
        my ($key, $value) = /(\S+?)\: ?(.+?)[\n\r]+/;

        $Http{$key} = $value;
#       print "db http header key=$key value=$value.\n" if $main::config_parms{debug} eq 'http';

        if ($key eq 'Cookie') {
            for my $key_value (split ';', $value) {
                my ($key2, $value2) = $key_value =~ /(\S+)=(\S+)/;
                $Cookies{$key2} = $value2;
            }
        }
        elsif ($key eq 'Authorization') {
            if ($value =~ /Basic (\S+)/) {
                my ($user, $password) = split(':', &uudecode($1));
                $Authorized = (&password_check($password, 'http')) ? 0 : 1;
            }
        }
        $Http{loop}    = $Loop_Count; # Track which pass we last processes a web request
        $Http{request} = $header;
    }
    logit "$config_parms{data_dir}/logs/server_header.$Year_Month_Now.log",  "$header data:$temp";;

                                # Look at type of browser, via User-Agent key
# Some examples
#Agent: Mozilla/4.0 (compatible; MSIE 4.01; Windows NT Windows CE)
#Agent: Mozilla/4.0 (compatible; MSIE 5.5; Windows NT 5.0)
#Agent: Mozilla/4.0 (compatible; MSIE 5.5; Windows NT 4.0; BCD2000)
#Agent: Mozilla/4.0 (compatible; MSIE 6.0b; Windows NT 5.1)
#Agent: Mozilla/4.61 [en] (Win98; I)
#Agent: Mozilla/4.76 [en] (Windows NT 5.0; U)
#Agent: Mozilla/4.7 [en] (X11; I; Linux 2.2.14-15mdk i686)
#Agent: Mozilla/4.76 [en] (X11; U; Linux 2.2.16-22jjg i686)
   
    if ($Http{'User-Agent'} =~ /Windows CE/) {
        $Http{'User-Agent'}    =  'MSCE';
    }
    elsif ($Http{'User-Agent'} =~ /MSIE/) {
        $Http{'User-Agent'}    =  'MSIE';
    }
    elsif ($Http{'User-Agent'} =~ /Mozilla/) {
        $Http{'User-Agent'}    =  'Mozilla';
    }
    $Http{format} = '';
    if ($config_parms{web_format} and $config_parms{web_format} =~ /^\d$/) {
        $Http{format} = $config_parms{web_format};
    }
    else {
        $Http{format} = $http_agent_formats{$Http{'User-Agent'}} if $http_agent_formats{$Http{'User-Agent'}};
    }

    if ($config_parms{password_menu} eq 'html' and $Password and $Cookies{password}) {
        $Authorized = ($Cookies{password} eq $Password) ? 1 : 0
    }

    print "http a=$Authorized format=$Http{format} ua=$Http{'User-Agent'} web_format=$config_parms{web_format}\n" if $main::config_parms{debug} eq 'http';

    my ($get_req, $get_arg) = $header =~ m|^GET (\/[^ \?]+)\??(\S+)? HTTP|;

#query-replace-regexp "said \\([$a-z_]+\\)" "\\1->{said}" nil)
    $get_req = $main::config_parms{'html_file' . $Http{format}} unless $get_req;
    $get_arg = '' unless $get_arg;
    logit "$config_parms{data_dir}/logs/server_http.$Year_Month_Now.log",  "$Socket_Ports{http}{client_ip_address} $get_req $get_arg";

    $get_arg =~ tr/\+/ /;       # translate + back to spaces (e.g. code search tk widget)
                                # Real + will be in %## form (e.g. /SET;&html_list(X10_Item)?$test_house2?%2B15)

    $get_arg =~ s/\&/&&/g;      # translate & to &&, so %## & will not trigger && splits

                                # translate from %## back to real characters
                                # Ascii table: http://www.bbsinc.com/symbol.html 
                                #  - get_req may have h_response with %## chars in it
    $get_req =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
    $get_arg =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;

    print "Web data requested:  get=$get_req arg=$get_arg\n  header=$header\n" if $main::config_parms{debug} eq 'http';

                                # Prompt for password
    if ($get_req =~ /SET_PASSWORD$/) {
        if ($config_parms{password_menu} eq 'html') {
            if ($get_req =~ /^\/UNSET_PASSWORD$/) {
                $Authorized = 0;
                $Cookie .= "Set-Cookie: password=xyz ; ; path=/;\n";
            }
            my $html = &html_authorized;
            $html .= &html_password('')  . '<br>' if $config_parms{password_menu} eq 'html';
            print $socket &html_page(undef, $html, undef, undef, undef);
        }
        else {
            my $html = &html_authorized;
            if ($Authorized) {
                                # No good way to un-Authorized here :(
                if ($get_req =~ /\/UNSET_PASSWORD$/) {
                    $Authorized = 0;
                    print $socket &html_password('');
                    return;
                }
                                # Refresh the main page
                $html = $Http{Referer}; # &html_page will use referer if only a url is given
                $html =~ s/SET_PASSWORD.*//;
                print $socket &html_page(undef, $html);
            }
            else {
                if ($get_req =~ /\/UNSET_PASSWORD$/) {
                    print $socket &html_page(undef, $html);
                }
                else {
                    print $socket &html_password('');
                }
            }
        }
        return;
    }
                                # Process the html password form
    elsif ($get_req =~ /\/SET_PASSWORD_FORM$/) {
        my ($password) = $get_arg =~ /password=(\S+)/;
        my ($html);
        my ($name, $name_short) = &net_domain_name('http');
        if (&password_check($password, 'http')) {
            $Authorized = 0;
            $html =  &html_authorized . &html_password('') . qq[<b>Password was incorrect</b>\n];
            $Cookie .= "Set-Cookie: password=xyz ; ; path=/;\n";
            $Cookies{password_was_not_valid}++; # So we can monitor from user code
            &print_log("Password was just NOT set; $name");
            &speak("Password NOT set by $name_short");
        }
        else {
            $Authorized = 1;
            $Cookie .= "Set-Cookie: password=$Password; ; path=/\n" if $Password;
#           $html  = &html_authorized . "<h3>Password accepted</h3>";
#           $html = "$url";   # &html_page will use referer if only a url is given
#           $html .= "<a href=$url>Refresh Main Page</a>\n";
                                # Refresh the main page
            $html = $Http{Referer}; # &html_page will use referer if only a url is given
            $html =~ s/\/SET_PASSWORD.*//;
            &print_log("Password was just set; $name");
            &speak("Password set by $name_short");
        }
        print $socket &html_page(undef, $html);
        return;
    }

    elsif (!$Authorized and lc $main::config_parms{password_protect} eq 'all') {
        if ($get_req =~ /wml/) {
            print $socket &html_password('browser'); # wml requires browser login ... no form/cookies for now
        }
        else {
            $h_response  = "<center><h3>MisterHouse password_protect set to all.  Password required for all functions</h3>\n";
            $h_response .= "<h3><a href=/SET_PASSWORD>Login</a></h3></center>";
            print $socket &html_page("", $h_response);
        }
        return;
    }

                                # See if the request was for a file
    elsif (&test_for_file($socket, $get_req, $get_arg)) {
    }

                                # See if request was for an auto-generated page
    elsif (my ($html, $style) = &html_mh_generated($get_req, $get_arg, 1)) {
        my $time_check2 = time;
        &print_socket_fork($socket, &html_page("", $html, $style));
#        print $socket &html_page("", $html, $style);
        $time_check2 = time - $time_check2;
        if ($time_check2 > 2) {
            my $msg = "http_server write time exceeded: time=$time_check2, req=$get_req,$get_arg";
            print "\n$Time_Date: $msg";
            &print_log($msg);
        }
    }        
                                # Test for RUN commands
    elsif  ($get_req =~ /\/RUN$/i or
            $get_req =~ /\/RUN[\:\;](\S*)$/i) {
        $h_response = $1;

        if ($get_arg) {
            $get_arg =~ s/select_cmd=//;  # Drop the cmd=  prefix from form lists.
            $get_arg =~ tr/\_/ /;   # Put blanks back
            $get_arg =~ tr/\~/_/;   # Put _ back
                                # Drop the &&x=n&&y=n that is tacked on (before or after) when doing image form submits
            $get_arg =~ s/&&x=\d+&&y=\d+//;
            $get_arg =~ s/x=\d+&&y=\d+&&//;
        }

        my ($ref) = &Voice_Cmd::voice_item_by_text(lc($get_arg));
        my $authority = $ref->get_authority if $ref;
        $authority = $Password_Allow{$get_arg} unless $authority;

        print "RUN a=$Authorized,$authority get_arg=$get_arg response=$h_response\n" if $main::config_parms{debug} eq 'http';

        if ($Authorized or $authority) {
                                # Allow for RUN;&func  (response function like &dir_sort, with no action)
            if (!$get_arg) {
                &html_response($socket, $h_response);
            }
            elsif (&run_voice_cmd($get_arg)) {
                &html_response($socket, $h_response);
            }
            else {
                my $msg = "The Web RUN command not found: $get_arg.\n";
                $msg = "Pick a command state from the pull down on the right" if $get_arg eq 'pick a state msg';
#               print $socket &html_page("", $msg, undef, undef, "control");
                print $socket &html_page("", "<br><b>$msg</b>");
                print_log $msg;
            }
        }
        else {
            print $socket &html_page("", &html_unauthorized($get_arg, $h_response));
        }
    }
                                # Test for subroutine call.  Note we can have both a SUB action and a SUB response
    elsif  ($get_req =~ /\/SUB$/i or
            $get_req =~ /\/SUB[\:\;](\S*)$/i) {
        $h_response = $1;
                                # Run the subroutine (if authorized)
        my($msg, $action) = &html_sub($get_arg, 1);
        if ($msg) {
            print $socket &html_page("", $msg);
        }
        elsif ($action) {
            my $response = eval $action;
            print "\nError in html SUB: $@\n" if $@;
                                # Check for a response sub
            if (my($msg, $action) = &html_sub($response)) {
                if ($msg) {
                    print $socket &html_page("", $msg);
                }
                else {
                    $leave_socket_open_action = $action;
                    $leave_socket_open_passes = 3; # Wait a few passes, so multi-pass events can settle (e.g. barcode_web.pl)
                }
            }
            elsif ($response) {
                &print_socket_fork($socket, $response);
#               print $socket $response;
            }
            elsif (!$h_response) {
                $h_response = 'last_response';
            }
        }
                                # Generate a response IF requested (i.e. no default)
        &html_response($socket, $h_response) if $h_response;
    }
                                # Allow for either SET or SET_VAR 
    elsif  ($get_req =~ /\/SET(_VAR)?$/i or
            $get_req =~ /\/SET(_VAR)?[\:\;](\S*)$/i) {
        $h_response = $2;
#       print "Error, no SET argument: $header\n" unless $get_arg;

                                # Change select_item=$item&select_state=abc to $item=abc
        $get_arg =~ s/select_item=(\S+)\&&select_state=/$1=/; 

                                # See if any variables require authorization
        my $authority = 1;
        unless ($Authorized) {
            for my $temp (split('&&', $get_arg)) {
                next unless ($item, $state) = $temp =~ /(\S+)[\?\=](.*)/;

                if ($item =~ /^\d+$/) { # Can't do html_pointer yet ... need to switch to Tk objects
                    $authority = 0;
                    next;
                }
                                # WAP pages don't allow for $ in url, so make it optional
                $item = "\$". $item unless substr($item, 0, 1) eq "\$";
                my $set_authority = eval qq[$item->get_authority if $item and ref($item) and $item->isa('Generic_Item');];
                print "SET authority eval error: $@\n" if $@;
                unless ($set_authority or $Password_Allow{$item}) {
                    $authority = 0;
                    last;
                }
            }
        }

        print "SET a=$Authorized,$authority hr=$h_response get_req=$get_req  get_arg=$get_arg\n" if $main::config_parms{debug} eq 'http';

        if ($Authorized or $authority) {
            for my $temp (split('&&', $get_arg)) {
                ($item, $state) = $temp =~ /(\S+)[\?\=](.*)/;
#               print "db i=$item s=$state a=$get_arg t=$temp\n";

                $state =~ s/\_/ /g;      # No blanks were allowed in a url 
                $state =~ s/\~/_/g;      # Put _ back

                                # If item name is only digits, this implies tk_widgets, where we used html_pointer_cnt as an index
                if ($item =~ /^\d+$/) {
                    my $pvar = $html_pointers{$item};
                                # Allow for state objects
                    if ($pvar and ref $pvar ne 'SCALAR' and $pvar->can('set')) {
                        $pvar->set($state);
                    }
                    else {
                        $$pvar = $state;
                    }
                                # This gives uninitilzed errors ... not needed anymore?
                                #  - yep, needed till we switch widgets to objects
                    $Tk_results{$html_pointers{$item . "_label"}} = $state if $html_pointers{$item . "_label"};
                }
                                # Otherwise, we are trying to pass var name in directly. 
                else {
                                # WAP pages don't allow for $ in url, so make it optional
                    $item = "\$". $item unless substr($item, 0, 1) eq "\$";

                                # Can be a scalar or a object
                    $state =~ tr/\"/\'/; # So we can use "" to quote it
                    my $eval_cmd = qq[($item and ref($item) and $item->isa('Generic_Item')) ? ($item->set("$state")) : ($item = "$state")];
                    print "SET eval: $eval_cmd\n" if $main::config_parms{debug} eq 'http';
                    eval $eval_cmd;
                    print "SET eval error: $@\n" if $@;
                }
            }            
            &html_response($socket, $h_response);
        }
        else {
            if ($h_response =~ /^last_/) {
                print $socket &html_page("", &html_unauthorized($get_arg, $h_response));
            }
            else {
                                # Just refresh the screen, don't give a bad boy msg
                                #  - this way we don't mess up the Items display frame
                &html_response($socket, $h_response,undef,undef);
            }
        }

    }
    else {
        my $msg = "Unrecognized html request: get_req=$get_req   get_arg=$get_arg  header=$header\n";
        print $socket &html_page("Error", $msg);
        print $msg;
    }

    $time_check = time - $time_check;
    if ($time_check > 1) {
        my $msg = "http_server time exceeded: time=$time_check, ip=$Socket_Ports{http}{client_ip_address}, header=$header";
        logit "$config_parms{data_dir}/logs/mh_pause.$Year_Month_Now.log",  $msg;
        print "\n$Time_Date: $msg\n";
        &print_log($msg);
#       &speak("web sleep of $time_check seconds");
    }

    return ($leave_socket_open_passes, $leave_socket_open_action);
}

sub html_password {
    my ($menu) = @_;
    $menu = $config_parms{password_menu} unless $menu;
    my $html;
    if ($menu eq 'html') {
        $html  = qq[<BODY onLoad="self.focus();document.pw.password.focus()">\n];
        $html .= qq[<BASE TARGET='_top'>\n];
        $html .= qq[<FORM name=pw action="SET_PASSWORD_FORM" method="get">\n];
        $html .= qq[<h3>Password:<INPUT size=10 name='password' type='password'></h3>\n</FORM>\n];
    }
    else {
        $html  = qq[HTTP/1.0 401 Unauthorized\n];
        $html .= qq[Server: MisterHouse\n];
        $html .= qq[Content-type: text/html\n];
        $html .= qq[WWW-Authenticate: Basic realm="mh_control"\n];
    }
    return $html;
}

sub html_authorized {
    if ($Authorized) {
        return "Status: <b><a href=UNSET_PASSWORD>Logged In</a></b><br>";
    }
    else {
        return "Status: <b><a href=SET_PASSWORD yet>Not Logged In</a></b><br>";
    }
}

sub html_unauthorized {
    my ($action, $h_response) = @_;
    if ($h_response =~ /vxml/) {
        return &vxml_page(audio => 'Sorry, you are not authorized for that command');
    }
    else {
        my $msg = "<a href=speech>Refresh Recently Spoken Text</a><br>\n";
        $msg .= "<br><B>Unauthorized Mode.</B> Authorization flag was not set, to the following was NOT performed<p>";
        $msg .= "<li>" . $action . "</li>";
        return $msg;
    }
}

sub get_local_file {
    my ($get_req) = @_;
    my ($http_dir, $http_member) = $get_req =~ /^(\/[^\/]+)(.*)/;
    my $file;
    if ($http_dir and $http_dirs{$http_dir}) {
        $file  = $http_dirs{$http_dir};
        $file .= "/$http_member" if $http_member;
    }
    else {
        $file = "$main::config_parms{'html_dir' . $Http{format}}/$get_req";
    }
    return ($file, $http_dir);
}

sub test_for_file {
    my ($socket, $get_req, $get_arg, $no_header, $no_print) = @_;

    my ($file, $http_dir) = &get_local_file($get_req);

                                # Check for index files in directory
    if (-d $file) {
        my $file2;
        for my $default (split ',', $main::config_parms{'html_default' . $Http{format}}) {
            $file2 = "$file/$default";
            last if -e $file2;
        }
        if (-e $file2) {
            $file = $file2;
        }
        else {
            print $socket &html_page("Error", "No index found for directory $get_req");
            return 1;
        }
    }

    if (-e $file) {
        my $html = &html_file($socket, $file, $get_arg, $no_header) if &test_file_req($socket, $get_req, $http_dir);
        if ($no_print) {
            return $html;
        }
        else {
            &print_socket_fork($socket, $html);
            return 1;
        }
    }
    else {
        return 0;               # No file found ... check for other types of http requests
    }
}

                                # Check for illicit or password protected dirs
sub test_file_req {
    my ($socket, $get_req, $http_dir) = @_;

                                # Don't allow bad guys to go up the directory chain
    $get_req =~ s#/\./#/#g;                                     # /./ -> /
    $get_req =~ s#//+#/#g;                                      # // -> /
    1 while( $get_req =~ s#/(?!\.\.)[^/]+/\.\.(/|$)#$1# );      # /foo/../ -> /
    # if there is a .. at this point, it's a bad thing. Also stop if path contains exploitable characters
    if ($get_req =~ m#/\.\.|[\|\`;><\000]# ) {
        print $socket &html_page("Error", "Access denied: $_[1]");
        return 0;
    }
                                # Verify the directory is not password protected
    if ($http_dir and $password_protect_dirs{$http_dir} and !$Authorized) {
        my $html = "<h4>Directory $http_dir requires Login password access</h4>\n";
        $html   .= "<h4><a href=SET_PASSWORD>Login</a></h4>";
        print $socket &html_page($html);
        return 0;
    }

    return 1;
}

sub html_mh_generated {
    my ($get_req, $get_arg, $auto_refresh) = @_;
    my $html = '';
                                # Allow for any of these $get_req forms:
                                #    /dir/request
                                #    /request
                                #    request
    $get_req =~ s/^.*?([^\/]+)$/$1/;

    if ($get_req =~ /^widgets$/) {
        return (&widgets('all'), $main::config_parms{'html_style_tk' . $Http{format}});
    }
    elsif ($get_req =~ /^widgets_type?$/) {
        $html .= &widgets('checkbutton');
        $html .= &widgets('radiobutton');
        $html .= &widgets('entry');
        return ($html, $main::config_parms{'html_style_tk' . $Http{format}});
    }
    elsif ($get_req =~ /^widgets_label$/) {
        $html = qq[<META HTTP-EQUIV="REFRESH" CONTENT="$main::config_parms{'html_refresh_rate' . $Http{format}}; url=widgets_label">\n] 
            if $auto_refresh and $main::config_parms{'html_refresh_rate' . $Http{format}};
        return ($html . &widgets('label'), $main::config_parms{'html_style_tk' . $Http{format}});
    }
    elsif ($get_req =~ /^widgets_entry$/) {
        return (&widgets('entry'), $main::config_parms{'html_style_tk' . $Http{format}});
    }
    elsif ($get_req =~ /^widgets_radiobutton$/) {
        return (&widgets('radiobutton'), $main::config_parms{'html_style_tk' . $Http{format}});
    }
    elsif ($get_req =~ /^widgets_checkbox$/) {
        return (&widgets('checkbutton'), $main::config_parms{'html_style_tk' . $Http{format}});
    }
    elsif ($get_req =~ /^vars_save$/) {
        return (&vars_save, $main::config_parms{'html_style_tk' . $Http{format}});
    }
    elsif ($get_req =~ /^vars_global$/) {
        return (&vars_global, $main::config_parms{'html_style_tk' . $Http{format}});
    }
                                # .html suffix is grandfathered in
    elsif ($get_req =~ /^speech(.html)?$/) {
        return (&html_last_spoken);
    }
    elsif ($get_req =~ /^print_log(.html)?$/) {
        return (&html_print_log);
    }
    elsif ($get_req =~ /^category$/) {
        return (&html_category, $main::config_parms{'html_style_category' . $Http{format}});
    }
    elsif ($get_req =~ /^groups$/) {
        return (&html_groups, $main::config_parms{'html_style_category' . $Http{format}});
    }
    elsif ($get_req =~ /^items$/) {
        return (&html_items, $main::config_parms{'html_style_category' . $Http{format}});
    }
    elsif ($get_req  =~ /^list[\:\;]?(\S*)$/) {
        $H_Response = $1 if $1;
        $html = &html_list($get_arg, $auto_refresh);
        return ($html, $main::config_parms{'html_style_list' . $Http{format}});
    }
    elsif ($get_req =~ /^results$/) {
        return ("<h2>Click on any item\n");
    }
    else {
        return;
    }
}

sub html_sub {
    my ($data, $sub_required) = @_;
    return unless $data;
    my ($sub_name, $sub_arg, $sub_ref);

    $data = '&' . $data if $data and $data !~/^&/; # Avoid & character in the url ... messes up Tellme

                                # Allow for &sub1 and &sub1(args)
    if ((($sub_name, $sub_arg) = $data =~ /^\&(\S+)\((\S+)\)$/) or
        (($sub_name)           = $data =~ /^\&(\S+)$/)) {
        $sub_arg = '' unless $sub_arg; # Avoid uninit warninng
#       $sub_ref = \&{$sub_name};  # This does not work ... code refs are always auto-created :(
#       if (defined $sub_ref) {
                                # The %main:: array will have a glob for all subs (and vars)
        if ($main::{$sub_name}) {
            print "html_sub: a=$Authorized pa=$Password_Allow{'&$sub_name'} data=$data sn=$sub_name sa=$sub_arg sr=$sub_ref\n" if $main::config_parms{debug} eq 'http';
                                # Check for authorization
            if ($Authorized or $Password_Allow{"&$sub_name"}) {
                $sub_arg = "'$sub_arg'" if $sub_arg and $sub_arg !~ /^[\'\"]/; # Add quotes if needed
                return(undef, "&$sub_name($sub_arg)");
            }
            else {
                return("Web response function not authorized: &$sub_name $sub_arg");
            }
        }
        else {
            return("Web html function not found: &$sub_name $sub_ref") if $sub_required;
        }
    }
    return;
}

sub html_response {
    my ($socket, $h_response) = @_;
    my $file;

    print "html response: $h_response\n" if $main::config_parms{debug} eq 'http';
    if ($h_response) {
        if ($h_response =~ /^last_response_?(\S*)/) {
            $Last_Response = '';
                                # Wait for some sort of response ... need a way to 
                                # specify longer wait times on longer commands.
                                # By default, we shouldn't put a long time here or
                                # we way too many passes for the 'no response message'
                                # from many commands that do not respond
            $leave_socket_open_passes = 3; 
            $leave_socket_open_action = qq|&html_last_response('$Http{"User-Agent"}', $1)|;
        }
        elsif ($h_response eq 'last_displayed') {
            $leave_socket_open_passes = 3;
            $leave_socket_open_action = "&html_last_displayed";
        }
        elsif ($h_response eq 'last_spoken') {
            $leave_socket_open_passes = 3;
            $leave_socket_open_action = "&html_last_spoken"; # Only show the last spoken text
#           $leave_socket_open_action = "&speak_log_last(1)"; # Only show the last spoken text
#           $leave_socket_open_action = "&Voice_Text::last_spoken(1)"; # Only show the last spoken text
        }
        elsif ($h_response =~ /^http:\S+$/i or $h_response =~ /^referer$/i) {
                                # Wait a few passes before refreshing page, in case mh states changed
            $h_response = $Http{Referer} if $h_response =~ /^referer$/i;
#           $leave_socket_open_action = "&http_redirect('$h_response')"; # mh uses &html_page, so this does not work
            $leave_socket_open_action = "'$h_response'"; # &html_page will use referer if only a url is given
            $leave_socket_open_passes = 3;
        }
        elsif (my($msg, $action) = &html_sub($h_response)) {
            if ($msg) {
                print $socket &html_page("", $msg);
            }
            else {
                $leave_socket_open_action = $action;
                $leave_socket_open_passes = 3; # Wait a few passes, so multi-pass events can settle (e.g. barcode_web.pl)
            }
        }
        elsif (&test_for_file($socket, $h_response)) {
                                # Allow for files to be modified on the fly, so wait a pass
                                #  ... naw, use &file_read if you need to wait (e.g. barcode_scan.shtml)
#       elsif (-e ($file = "$main::config_parms{'html_dir' . $Http{format}}/$h_response")) {
#           $leave_socket_open_passes = 3;
#           &html_file($socket, $file, '', 1);
#           $leave_socket_open_action = "&html_file(\$Socket_Ports{http}{socka}, '$file', '', 1)";
#           $leave_socket_open_action = "file_read '$file')";
        }
        else {
            $h_response =~ tr/\_/ /; # Put blanks back
            $h_response =~ tr/\~/_/; # Put _ back
            print $socket &html_page("", $h_response);
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
    my ($browser, $length) = @_;
    my ($last_response, $script, $style);
    $last_response = &last_response;
    $Last_Response = '' unless $Last_Response;
    if ($Last_Response eq 'speak') {
                                # Allow for MSagent
        if ($browser =~ /^MS/ and $Cookies{msagent} and $main::config_parms{'html_msagent_script' . $Http{format}}) {
            $script = file_read "$config_parms{'html_dir' . $Http{format}}/$config_parms{'html_msagent_script' . $Http{format}}";
            $script =~ s/<!-- *speak_text *-->/$last_response/;
        }
    }
    elsif ($Last_Response eq 'display') {
        $last_response =~ s/\n/\n<br>/g; # Add breaks on newlines
    }
    elsif ($Last_Response eq 'print_log') {
        ($last_response, $style) = &html_print_log;
    }
    elsif (!$last_response) {
        $last_response = "<br><b>No response resulted from the last command</b>";
    }

    $last_response = substr $last_response, 0, $length if $length;
    $style = "$main::config_parms{'html_style_speak' . $Http{format}}" unless $style;

    return $last_response, $style, $script;
}


sub html_last_displayed {
    my ($last_displayed) = &display_log_last(1);

                                # Add breaks on newlines
    $last_displayed =~ s/\n/\n<br>/g;

#   return "<h3>Last Displayed Text</h3>$last_displayed";
    return "<h3>Last Displayed Text</h3>$last_displayed", $main::config_parms{'html_style_speak' . $Http{format}};

}


sub html_last_spoken {
    my $h_response;

    if ($Authorized or $main::config_parms{password_protect} !~ /logs/i) {
        $h_response .= qq[<META HTTP-EQUIV="REFRESH" CONTENT="$main::config_parms{'html_refresh_rate' . $Http{format}}; url=speech">\n] if $main::config_parms{'html_refresh_rate' . $Http{format}};
        $h_response .= "<a href=speech>Refresh Recently Spoken Text</a>\n";
        my @last_spoken = &speak_log_last($main::config_parms{max_log_entries});
        for my $text (@last_spoken) {
            $h_response .= "<li>$text\n";
        }
    }
    else {
        $h_response = "<h4>Not Logged In</h4>";
    }
    return "$h_response\n", $main::config_parms{'html_style_speak' . $Http{format}};
}

sub html_print_log {

    my $h_response;
    if ($Authorized or $main::config_parms{password_protect} !~ /logs/i) {
        $h_response .= qq[<META HTTP-EQUIV="REFRESH" CONTENT="$main::config_parms{'html_refresh_rate' . $Http{format}}; url=print_log">\n] if $main::config_parms{'html_refresh_rate' . $Http{format}};
        $h_response .= "<a href=print_log>Refresh Print Log</a>\n";
        my @last_printed = &main::print_log_last($main::config_parms{max_log_entries});
        for my $text (@last_printed) {
            $text =~ s/\n/\n<br>/g;
            $h_response .= "<li>$text\n";
        }
    }
    else {
        $h_response = "<h4>Not Logged In</h4>";
    }
    return "$h_response\n", $main::config_parms{'html_style_print' . $Http{format}};
}

sub html_file {
    my ($socket, $file, $arg, $no_header) = @_;
    print "printing html file $file to $socket\n" if $main::config_parms{debug} eq 'http';

    my $html;
    local *HTML;                # Localize, for recursive call to &html_file

    unless (open (HTML, $file)) {
        print "Error, can not open html file: $file: $!\n";
        close HTML;
        return;
    }

                                # Allow for 'server side include' directives
                                #  <!--#include file="whatever"-->
    if ($file =~ /\.shtml$/ or $file =~ /\.vxml$/) {
        print "Processing server side include file: $file\n" if $main::config_parms{debug} eq 'http';
        $html = &mime_header($file) unless $no_header;
        while (my $r = <HTML>) {
                                # Example:  <li>Version: <!--#include var="$Version"--> ...
#           if (my ($prefix, $directive, $data, $suffix) = $r =~ /(.*)\<\!--+ *\#include +(\S+)=[\"\']([^\"\']+)[\"\'] *--\>(.*)/) {
            if (my ($prefix, $directive, $data, $suffix) = $r =~ /(.*)\<\!--+ *\#include +(\S+)=\"([^\"]+)\" *--\>(.*)/) {
                 print "Http include: $directive=$data\n" if $main::config_parms{debug} eq 'http';
                 $html .= $prefix;
                                # tellme vxml does not like comments in the middle of things :(
                                # - also had problems with comments inside td elements, so lets skip this
                                #   e.g.: " <td <!--#include file="motion.pl?timer_motion_main"--> > 
#                $html .= "\n<\!-- The following is from include $directive = $data -->\n" unless $file =~ /\.vxml$/;
                 my ($get_req, $get_arg) = $data =~ m|(\/?[^ \?]+)\??(\S+)?|;
                 $get_arg = '' unless $get_arg; # Avoid uninitalized var msg
                 if ($directive eq 'file') {

                    if (my $html_file = &test_for_file($socket, $get_req, $get_arg, 1, 1)) {
                        $html .= $html_file;
                    }
                    elsif (my ($html2, $style) = &html_mh_generated($get_req, $get_arg, 0)) {
                        $style = '' unless $style; # Avoid uninitalized var msg
                        $html .= $style . $html2;
                    }
                    else {
                        print "Error, shtml file directive not recognized: req=$get_req arg=$get_arg\n";
                    }
                }
                elsif ($directive eq 'var' or $directive eq 'code') {
                    print "Processing server side include: var=$data\n" if $main::config_parms{debug} eq 'http';
                    $html .= eval "return $data";
                    print "Error in eval: $@" if $@;
                }
                else {
                    print "http include directive not recognized:  $directive = $data\n";
                }
                $html .= $suffix;
            }
            else {
                $html .= $r;
            }
        }
    }
                                # Allow for .pl cgi programs
                                # Note: These differ from classic .cgi in that they return 
                                #       the results, rather than print them to stdout.
    elsif ($file =~ /\.pl$/) {
        @ARGV = split('&&', $arg) if $arg;
        my $code = join(' ', <HTML>);

                                # I couldn't figure out how to open STDOUT to $socket
#       open(OLDOUT_H, ">&STDOUT"); # Copy old handle
#       fdopen 'STDOUT' $socket   or print "Could not redirect http_server STDOUT to $socket: $!\n";
#       open(STDOUT, ">&$socket") or print "Could not redirect http_server STDOUT to $socket: $!\n";
#       my $results = eval $code;
#       open(STDOUT, ">&OLDOUT_H");
#       close OLDOUT_H;

        $html = eval $code;
        print "Error in http eval: $@" if $@;
        print "Http_server  .pl file results:$html.\n" if $main::config_parms{debug} eq 'http';
    }
    else {
        $html = &mime_header($file) unless $no_header;
        binmode HTML;
        $html .= join '', <HTML>;
    }
    close HTML;
    return $html;
}

sub mime_header {
    my ($extention) = $_[0] =~ /.+\.(\S+)$/;
    my $mime = $mime_types{lc $extention} || 'text/html';
    return qq[HTTP/1.0 200 OK\nServer: MisterHouse\nContent-type: $mime\n\n];
}

sub html_page {
    my ($title, $body, $style, $script, $frame) = @_;

    $body = 'No data' unless $body;

                                # Allow for redirect and pre-formated responses (e.g. vxml response)
    return http_redirect($body)    if $body =~ /^http:\S+$/i;
    return $body                   if $body =~ /^HTTP\//; # HTTP/1.0 200 OK


                                # This meta tag does not work :(
                                # MS IE does not honor Window-target :(
#   my $frame2 = qq[<META HTTP-EQUIV="Window-target" CONTENT="$frame">] if $frame;
    $style = $main::config_parms{'html_style' . $Http{format}} if $main::config_parms{'html_style' . $Http{format}} and !$style;
    $frame = "Window-target: $frame" if $frame;
    $frame  = '' unless $frame;  # Avoid -w uninitialized value msg
    $script = '' unless $script; # Avoid -w uninitialized value msg
    $title  = '' unless $title;  # Avoid -w uninitialized value msg
    return <<eof;
HTTP/1.0 200 OK
Server: MisterHouse
Content-Type: text/html
Cache-control: no-cache
$Cookie
$frame

$script
<HTML>
<HEAD>

$style
<TITLE>$title</TITLE>
</HEAD>
<BODY>
<H3>$title</H3>

$body

</BODY>
</HTML>
eof
}

sub http_redirect {
    my ($url) = @_;
    return <<eof;
HTTP/1.0 301 Moved Temporarily
Location:$url
$Cookie
eof
}

sub html_category {
    my $h_index;

    $h_index = qq[<DIV ID="overDiv" STYLE="position:absolute; visibility:hide; z-index:1;"></DIV>\n] . 
        qq[<SCRIPT LANGUAGE="JavaScript" SRC="/overlib.js"></SCRIPT>\n] if $html_info_overlib;

    for my $category (&list_code_webnames('Voice_Cmd')) {
        next if $category =~ /^none$/;

        my $info = "$category:";
        if ($html_info_overlib) {
            if (my @files = &list_files_by_webname($category)) {
                $info .= '<li>' . join ('<li>', @files);
            }
            $info = qq[onMouseOver="overlib('$info', FIXX, 5, OFFSETY, 50 )" onMouseOut="nd();"];
        }
        $h_index .= "<li>" . qq[<a href=list?$category $info>$category</a>\n];
#       $h_index .= "<li>" . &html_active_href("list?$category", $category) . "\n";
    }
    return $h_index;
}

sub html_groups {
    my $h_index;
    for my $group (&list_objects_by_type('Group')) {
        $h_index    .= "<li>" . &html_active_href("list?group=$group", &pretty_object_name($group)) . "\n";
    }
    return $h_index;
}

sub html_items {
    my $h_index;
#   for my $object_type ('X10_Item', 'X10_Appliance', 'Group', 'iButton', 'Serial_Item') {
    for my $object_type (@Object_Types) {
        next if $object_type eq 'Voice_Cmd'; # Already covered under Category
        $h_index    .= "<li>" . &html_active_href("list?$object_type", $object_type) . "\n";
    }
    return $h_index;
}

sub html_find_icon_image {
    my ($object, $type) = @_;

    $type = lc $type;
    my $name  = lc $object->{object_name};
    my $state = lc $object->{state};

    $name =~ s/^\$//;           # remove $ at front of objects
    $name =~ s/^v_//;           # remove v_ in voice commands

                                # Hard to track exact time state, so just use 1 icon for any dim
    $state = 'dim' if $type eq 'x10_item' and ($state =~ /^[+-]?\d+$/ or $state =~ /\d+\%/);

                                # Use on/off icons for conditional Weather_Items
    $state = ($state) ? 'on' : 'off' if $type eq 'weather_item' and ($object->{comparison});

    print "Find_icon: object_name=$name, type=$type, state=$state\n" if $main::config_parms{debug} eq 'http';

    my ($icon, $member);
    unless (%html_icons) {

        my $dir = "$main::config_parms{'html_dir' . $Http{format}}/graphics/";
        $dir = $http_dirs{'/graphics'} if $http_dirs{'/graphics'};
        print "Reading html icons from $dir\n";
        opendir (ICONS, $dir);
        for $member (readdir ICONS) {
            ($icon) = $member =~ /(\S+)\.\S+/;
            next unless $icon;
            $icon = lc $icon;
            $html_icons{$icon} = $member;
        }
    }

                                # Allow for set_icon to set the icon directly
    $name = $object->{icon} if $object->{icon};
    return '' if $name eq 'none';

                                # Look for exact matches
    if ($icon = $html_icons{"$name-$state"}) {
    }
                                # For voice items, look for approximate name matches
                                #  - Order of preference: object, text, filename
                                #    and pick the longest named match
    elsif ($type eq 'voice') {
        my ($i1, $i2, $i3, $l1, $l2, $l3);
        $l1 = $l2 = $l3 = 0;
        for my $member (sort keys %html_icons) {
            next if $member eq 'on' or $member eq 'off';
            my $l = length $member;
            if ($html_icons{$member}) {
                if($name               =~ /$member/i and $l > $l1) { $i1 = $html_icons{$member}; $l1 = $l};
                if($object->{text}     =~ /$member/i and $l > $l2) { $i2 = $html_icons{$member}; $l2 = $l};
                if($object->{filename} =~ /$member/i and $l > $l3) { $i3 = $html_icons{$member}; $l3 = $l};
            }
#           print "db n=$name t=$object->{text} $i1,$i2,$i3 l=$l m=$member\n" if $object->{text} =~ /playlist/;
        }
        if    ($i1) {$icon = $i1}
        elsif ($i2) {$icon = $i2} 
        elsif ($i3) {$icon = $i3}
        else {
            return '';         # No match
        }
    }
                                # For non-voice items, try State and Item type matches
    else {

        unless ($icon = $html_icons{"$type-$state"} or
                $icon = $html_icons{$type}          or
                $icon = $html_icons{$state}) {
            return '';         # No match
        }
    }

    return "/graphics/$icon";
}

sub html_list {

    my($webname_or_object_type, $auto_refresh) = @_;
    my ($object, @object_list, $num, $h_list);
    
    $h_list .= "<b>$webname_or_object_type</b> &nbsp &nbsp &nbsp &nbsp " . &html_authorized . "\n";
    $h_list =~ s/group=\$//;     # Drop the group=$ prefix on group lists

    $h_list .= qq[<!-- html_list -->\n];

                                # This means the form was submited ... check for search keyword
    if (my ($search) = $webname_or_object_type =~ /search=(.*)/) {

                                # Check for msagent checkbox
        if ($webname_or_object_type =~ /msagent=1/) {
            unless ($Cookies{msagent}) {
                $Cookies{msagent} = 1;
                $Cookie .= "Set-Cookie: msagent=1 ; ; path=/;\n";
                return "<h3>MS agent has been turned On</h3>";
            }
        }
        else {
            if ($Cookies{msagent}) {
                $Cookies{msagent} = 0;
                $Cookie .= "Set-Cookie: msagent=0 ; ; path=/;\n";
                return "<h3>MS agent has been turned Off</h3>";
            }
        }
                                # Search for matching Voice_Cmd and Tk Widgets
        $h_list .= "<!-- html_list list_objects_by_search=$search -->\n";
        my %seen;
        for my $cmd (&list_voice_cmds_match($search)) {
                                # Now find object name
            my ($file, $cmd2) = $cmd =~ /(.+)\:(.+)/;
            my ($object, $said, $vocab_cmd) = &Voice_Cmd::voice_item_by_text(lc $cmd2);
            my $object_name = $object->{object_name};
            next if $seen{$object_name}++;
            push @object_list, $object_name;
        }
        $h_list .= &widgets('search', $search);
        $h_list .= &html_command_table(sort @object_list);
        return $h_list;
    }

                                # Check for authority based searches
    if ($webname_or_object_type =~ /authority=(\S*)/) {
        my $search = $1;
        for my $category (&list_code_webnames('Voice_Cmd')) {
            for my $object_name (sort &list_objects_by_webname($category)) {
                my $object = &get_object_by_name($object_name);
                next unless $object and $object->isa('Voice_Cmd');
                                # for now, only list set_authority('anyone') commands
                my $authority = $object->get_authority;
                push @object_list, $object_name if $authority and $authority =! /$search/i;
            }
        }

        $h_list .= "<!-- html_list list_objects_by_authority=$search -->\n";
#       $h_list .= &widgets('search', $1);
        $h_list .= &html_command_table(sort @object_list);
        return $h_list;
    }

                                # List Groups (treat them the same as Items)
    if ($webname_or_object_type =~ /^group=(\S+)/) {
        $h_list .= "<!-- html_list group = $webname_or_object_type -->\n";
        my $object = &get_object_by_name($1);
        my @objects = list $object;
                                # Ignore objects marked as hidden
        @objects = grep !$$_{hidden}, list $object;

        my @table_items = map{&html_item_state($_, $webname_or_object_type)} @objects;
        $h_list .= &table_it($config_parms{'html_table_size' . $Http{format}}, 0, 0, @table_items);
        return $h_list;
    }

                                # List Items by type
    if (@object_list = sort &list_objects_by_type($webname_or_object_type)) {
        $h_list .= qq[<META HTTP-EQUIV="REFRESH" CONTENT="$main::config_parms{'html_refresh_rate' . $Http{format}}; url=list?$webname_or_object_type">\n]
            if $auto_refresh and $main::config_parms{'html_refresh_rate' . $Http{format}};
        $h_list .= "<!-- html_list list_objects_by_type = $webname_or_object_type -->\n";
        my @objects = map{&get_object_by_name($_)} @object_list;

                                # Ignore objects marked as hidden
        @objects = grep !$$_{hidden}, @objects;

        my @table_items = map{&html_item_state($_, $webname_or_object_type)} @objects;
        $h_list .= &table_it($main::config_parms{'html_table_size' . $Http{format}}, 0, 0, @table_items);
        return $h_list;
    }

                                # List Voice_Cmds, by Category
    if (@object_list = &list_objects_by_webname($webname_or_object_type)) {
        $h_list .= "<!-- html_list list_objects_by_webname -->\n";
        $h_list .= &widgets('all', $webname_or_object_type);
        $h_list .= &html_command_table(sort @object_list) if @object_list;
        return $h_list;
    }

}

sub table_it {
    my ($cols, $border, $space, @items) = @_;

    my $h_list .= qq[<table border='$border' width="100%" cellspacing="$space" cellpadding="0">\n];

    my $num = 0;
    for my $item (@items) {
        if ($num == 0) {
                                # Check to see if it already specs a row
            if ($item =~ /^\<tr/) {
                $h_list .= $item . "\n";
                next;
            }
            $h_list .= qq[<tr align=center>\n];
        }
        $h_list .= $item . "\n";
        if (++$num == $cols) {
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
    my ($html, @htmls);
    my $list_count = 0;
    my ($msagent_cmd1, $msagent_script1, $msagent_script2 );

    my @objects = map{&get_object_by_name($_)} @object_list;

                                # Sort by sort field, then filename, then object name
    for my $object (sort {($a->{order} and $b->{order} and $a->{order} cmp $b->{order}) or
                          ($a->{filename} cmp $b->{filename}) or
                          (defined $a->{text} and defined $b->{text} and $a->{text} cmp $b->{text})} @objects) {
        my $object_name = $object->{object_name};
        my $state_now   = $object->{state};
        my $filename    = $object->{filename};
        my $text        = $object->{text};
        next unless $text;      # Only do voice items
        next if $$object{hidden};

        $list_count++;

                                # Find the states and create the test label
                                #  - pick the first {a,b,c} phrase enumeration 
        $text =~ s/\{(.+?),.+?\}/$1/g;

        my ($prefix, $states, $suffix, $h_text, $text_cmd, $ol_info, $state_log, $ol_state_log);
        ($prefix, $states, $suffix) = $text =~ /^(.*)\[(.+?)\](.*)$/;
        $states = '' unless $states; # Avoid -w uninitialized values error
        $suffix = '' unless $states;
        my @states = split ',', $states;
#       my $states_with_select = @states > $config_parms{'html_category_select' . $Http{format}};
        my $states_with_select = length("@states") > $config_parms{'html_select_length' . $Http{format}};

                                # Do the filename entry
        push @htmls, qq[<td align='left' valign='center'>$filename</td>\n] if $main::config_parms{'html_category_filename' . $Http{format}};

                                # Build the info and statelog overlib strings
                                #  - Netscape only supports onmouse over on hrefs :(
                                #  - Building a dummy href for Netscap only kind of works, so lets skip it.
#       $ol_info .= qq[<a href="javascript:void(0);" ];
        if ($html_info_overlib) {
            $ol_info = $object->{info};
            $ol_info = "$prefix ... $suffix" if !$ol_info and ($prefix or $suffix);
            $ol_info = $text   unless $ol_info;
            $ol_info = "$filename: $ol_info";
            $ol_info =~ s/\'/\\\'/g;
            $ol_info =~ s/\"/\\\'/g;
            my $height = 20;
            if ($states_with_select and $html_info_overlib) {
                $ol_info .= '<li>' . join ('<li>', @states);
                $height += 20 * @states;
            }
            my $row = $list_count;
            $row /= 2 if $main::config_parms{'html_category_cols' . $Http{format}} == 2;
            $height = $row * 25 if $row * 25 < $height;
#           my $ol_pos = ($list_count > 5) ? 'ABOVE, HEIGHT, $height' : 'RIGHT';
#           my $ol_pos = "ABOVE, HEIGHT, $height";
            my $ol_pos = "BELOW, HEIGHT, $height";
            $ol_info = qq[onMouseOver="overlib('$ol_info', $ol_pos)" onMouseOut="nd();"];

                                # Summarize state log entries
            unless ($main::config_parms{'html_category_states' . $Http{format}}) {
                my @states_log = state_log $object;
                while (my $state = shift @states_log) {
                    if (my ($date, $time, $state) = $state =~ /(\S+) (\S+ *[APM]{0,2}) *(.*)/) {
                        $ol_state_log .= "<li>$date $time <b>$state</b> ";
                    }
                }
                $ol_state_log = "unknown" unless $ol_state_log;
                $ol_state_log = qq[onMouseOver="overlib('$ol_state_log', RIGHT, WIDTH, 250 )" onMouseOut="nd();"];
            }
        }

                                # Put in a dummy link, so we can get netscape state_log info
        if ($config_parms{'html_info' . $Http{format}} eq 'overlib_link') {
#           $html  = qq[<a href="javascript:void(0);" $ol_info>info</a><br> ];
            $html  = qq[<a href='SET;&html_info($object_name)'$ol_info>info</a><br> ];
            $html .= qq[<a href='SET;&html_state_log($object_name)'$ol_state_log>log</a> ];
            push @htmls, qq[<td align='left' valign='center'>$html</td>\n];
        }


                                # Do the icon entry
        if ($main::config_parms{'html_category_icons' . $Http{format}} and
            my $h_icon = &html_find_icon_image($object, 'voice')) {
#           my $alt = $object->{info} . " ($h_icon)";
            my $alt = $h_icon;
            $html = qq[<input type='image' src="$h_icon" alt="$alt" border="0">\n];
#           $html = qq[<img src="$h_icon" alt="$h_icon" border="0">];
        }
        else {
            $html = qq[<input type='submit' border='1' value='Run'>\n];
        }

                                # Start the form before the icon
                                #  - outside of td so the table is shorter
                                #  - allows the icon to be a submit
        my $form = qq[<FORM action="RUN;$H_Response" method="get">\n];

                                # Icon button
        push @htmls, qq[$form  <td align='left' valign='center' width='0%' $ol_state_log>$html</td>\n];

                                # Now do the main text entry
        my $width = ($main::config_parms{'html_category_cols' . $Http{format}} == 1) ? "width='100%'" : '';
        $html  = qq[<td align='left' $width $ol_info> ];

        $html .= qq[<b>$prefix</b>] if $prefix;

                                # Use a SELECT dropdown with 4 or more states
        if ($states_with_select) {
            $html .= qq[<SELECT name="select_cmd" onChange="form.submit()">\n];
#           $html .= qq[<option value="pick_a_state_msg" SELECTED> \n]; # Default is blank
            $msagent_cmd1 = "$prefix (";
            my $selected = 'SELECTED';
            for my $state (@states) {
                my $text_cmd = "$prefix$state$suffix";
                $text_cmd =~ tr/\_/\~/; # Blanks are not allowed in urls
                $text_cmd =~ tr/ /\_/;  
                $html .= qq[<option value="$text_cmd"$selected>$state\n];
                $state =~ s/\+(\d+)/$1/; # Msagent doesn't like +20, +30, etc
                $msagent_cmd1 .= "$state|" if $state;
                $selected = '';
            }
            substr($msagent_cmd1, -1, 1) =  ") $suffix";
            $html .= qq[</SELECT>\n];
        }
                                # Use hrefs with 2 or 3 states
        elsif ($states) {
            my $hrefs;
            $msagent_cmd1 = "$prefix (";
            for my $state (@states) {
                my $text_cmd = "$prefix$state$suffix";
                $text_cmd =~ s/\+/\%2B/g; # Use hex 2B = +, as + will be translated to blanks
                $text_cmd =~ tr/\_/\~/; # Blanks are not allowed in urls
                $text_cmd =~ tr/ /\_/;  
                                # Use the first entry as the default one, used when clicking on the icon
                if ($hrefs) {
                    $hrefs .= qq[, ] if $hrefs;
                }
                else {
                    $html .= qq[<input type="hidden" name="select_cmd" value='$text_cmd'>\n];
                }

                                # We could add ol_info here, so netscape kind of works, but this 
                                # would be redundant and ineffecient.
                $hrefs .= qq[<a href='RUN;$H_Response?$text_cmd'>$state</a> ];
                $state =~ s/\+(\d+)/$1/; # Msagent doesn't like +20, +30, etc
                $msagent_cmd1 .= "$state|" if $state;
#               $hrefs .= qq[<a href='/RUN;$H_Response?$text_cmd' $ol_info>$state</a> ];
            }
            substr($msagent_cmd1, -1, 1) =  ") $suffix";
            $html .= $hrefs;
        }
                                # Just display the text, when no states
        else {
            my $text_cmd = $text;
            $text_cmd =~ tr/\_/\~/; # Blanks are not allowed in urls
            $text_cmd =~ tr/ /\_/; 
            $html .= qq[<b>$text</b>];
            $html .= qq[<input type="hidden" name="select_cmd" value='$text_cmd'>\n];
            $msagent_cmd1 = $text;
        }

        $html .= qq[<b>$suffix</b>] if $suffix;
        push @htmls, qq[$html</td></FORM>\n]; 

                                # Do the states_log entry
        if ($main::config_parms{'html_category_states' . $Http{format}}) {
            if (my ($date, $time, $state) = (state_log $object)[0] =~ /(\S+) (\S+) *(.*)/) {
                $state_log = "<NOBR><a href='SET;&html_state_log($object_name)'>$date $time</a></NOBR> <b>$state</b>";
            }
            else {
                $state_log = "unknown";
            }
            push @htmls, qq[<td align='left' valign='center'>$state_log</td>\n\n];
        }

                                # Include MsAgent VR commands
#       minijeff.Commands.Add "ltOfficeLight", "Control Office Light","Turn ( on | off ) office light", True, True
        my $msagent_id = substr $object_name, 1;
#       $msagent_script1 .= qq[minijeff.Commands.Add "Run_Command", "$text", "$msagent_cmd1", True, True\n];
#       $msagent_script2 .= qq[Case "$msagent_id"\n   $msagent_id\n];
#       $msagent_script1 .= qq[minijeff.Commands.Add "$msagent_id", "$text", "$msagent_cmd1", True, True\n];
        $msagent_cmd1 =~ s/\[\]//; # Drop [] on stateless commands
        my $msagent_cmd2 = $msagent_cmd1;
        $msagent_cmd2 =~ s/\|/,/g;
        $msagent_script1 .= qq[minijeff.Commands.Add "$msagent_id", "$msagent_cmd2", "$msagent_cmd1", True, True\n];
        $msagent_script2 .= qq[Case "$msagent_id"\n   Run_Command(UserInput.voice)\n];
    }

                                # Create final html
    $html = "<BASE TARGET='speech'>\n";
    $html = qq[<DIV ID="overDiv" STYLE="position:absolute; visibility:hide; z-index:1;"></DIV>\n] . 
            qq[<SCRIPT LANGUAGE="JavaScript" SRC="/overlib.js"></SCRIPT>\n] . 
                $html if $html_info_overlib;

    if ($Http{'User-Agent'} =~ /^MS/ and $Cookies{msagent} and $main::config_parms{'html_msagent_script_vr' . $Http{format}}) {
        my $msagent_file = file_read "$config_parms{'html_dir' . $Http{format}}/$config_parms{'html_msagent_script_vr' . $Http{format}}";
        $msagent_file =~ s/<!-- *vr_cmds *-->/$msagent_script1/;
        $msagent_file =~ s/<!-- *vr_select *-->/$msagent_script2/;
        $html = $msagent_file . $html;
    }

    my $cols = 2;
    $cols += 1 if $main::config_parms{'html_category_filename' . $Http{format}};
    $cols += 1 if $main::config_parms{'html_category_states' . $Http{format}};
    $cols += 1 if $main::config_parms{'html_info' . $Http{format}} eq 'overlib_link';
    $cols *= 2 if $main::config_parms{'html_category_cols' . $Http{format}} == 2;

    return  $html . &table_it($cols, $main::config_parms{'html_category_border' . $Http{format}}, $main::config_parms{'html_category_cellsp' . $Http{format}},  @htmls);
}

                                # List current object state
sub html_item_state {
    my ($object, $object_type) = @_;
    my $object_name  = $object->{object_name};
    my $object_name2 = &pretty_object_name($object_name);
    my $isa_X10 = $object->isa('X10_Item');

                                # If not a state item, just list it
    unless ($isa_X10 or $object->isa('Group') or defined $object->{state} or $object->{states}) {
        return qq[<td></td><td align="left"><b>$object_name2</b></td>\n];
    }

    my $filename     = $object->{filename};
    my $state_now    = $object->{state};
    my $html;
    $state_now = '' unless $state_now; # Avoid -w uninitialized value msg

                                # If >2 possible states, add a Select pull down form
    my @states;
    @states = @{$object->{states}} if $object->{states};
#   print "db on=$object_name ix10=$isa_X10 s=@states\n";
    @states = split ',', $config_parms{x10_menu_states} if $isa_X10;
    @states = qw(on off) if $object->isa('X10_Appliance');
    my $use_select = 1 if @states > 2 and length("@states") > $config_parms{'html_select_length' . $Http{format}};

    if ($use_select) {
#       $html .= qq[<FORM action="/SET;&html_list($object_type)?" method="get">\n];
        $html .= qq[<FORM action="SET;referer?" method="get">\n];
        $html .= qq[<INPUT type="hidden" name="select_item" value="$object_name">\n]; # So we can uncheck buttons
    }

                                # Find icon to show state, if not found show state_now in text.
                                #  - icon is also used to show state log
    $html .= qq[<td align="right"><a href='SET;&html_state_log($object_name)' target='speech'>];

    if (my $h_icon = &html_find_icon_image($object, $object_type)) {
        $html .= qq[<img src="$h_icon" alt="$h_icon" border="0"></a>];
    } 
    elsif ($state_now and 8 > length $state_now) {
        $html .= $state_now . '</a>&nbsp';
    }
    else {
        $html .= qq[<img src="/graphics/nostat.gif" alt="no_state" border="0"></a>];
    }
    $html .= qq[</td>\n];

                                # Add brighten/dim arrows on X10 Items
    $html .= qq[<td align="left"><b>];
    if ($isa_X10) {
                                # Note:  Use hex 2B = +, as + means spaces in most urls
#       $html .= qq[<a href='SET;&html_list($object_type)?$object_name?%2B15'><img src='/graphics/a1+.gif' alt='+' border='0'></a> ];
        $html .= qq[<a href='SET;referer?$object_name?%2B15'><img src='/graphics/a1+.gif' alt='+' border='0'></a> ];
        $html .= qq[<a href='SET;referer?$object_name?-15'>  <img src='/graphics/a1-.gif' alt='-' border='0'></a> ];
    }

                                # Add Select states
    if ($use_select) {
        $html .= qq[<SELECT name="select_state" onChange="form.submit()">\n];
        $html .= qq[<option value="pick_a_state_msg" SELECTED> \n]; # Default is blank
        for my $state (@states) {
            my $state_short = substr $state, 0, 5;
            $html .= qq[<option value="$state">$state_short\n];
#           $html .= qq[<a href='SET;&html_list($object_type)?$object_name?$state'>$state</a> ];
        }
        $html .= qq[</SELECT>\n];
    }
     
    if (@states) {
                                # Find toggle state
        my $state_toggle;
        if ($object_type eq 'Weather_Item') {
        }
        elsif ($state_now eq ON or $state_now =~ /^[\+\-]?\d/) {
            $state_toggle = OFF;
        }
        elsif ($state_now eq OFF or grep $_ eq ON, @states) {
            $state_toggle = ON;
        }
    
        if ($state_toggle) {
            $html .= qq[<a href='SET;referer?$object_name=$state_toggle'>$object_name2</a>];
#           $html .= qq[<a href='SET;&html_list($object_type)?$object_name?$state_toggle'>$object_name2</a>];
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
            my $state_short = substr $state, 0, 5;
            $html .= qq[ <a href='SET;referer?$object_name=$state'>$state_short</a>];
        }
    }

    $html .= qq[</b></td>];
    $html .= qq[</FORM>] if $use_select;
    return $html . "\n";
}

$Password_Allow{'&html_state_log'} = 'anyone';
sub html_state_log {
    my ($object_name) = @_;
    my $object = &get_object_by_name($object_name);
    my $object_name2 = &pretty_object_name($object_name);
    my $html = "<b>$object_name2 states</b><br>\n";
    for my $state (state_log $object) {
        $html .= "<li>$state</li>\n" if $state;
    }
    return $html . "\n";
}

sub html_info {
    my ($object_name) = @_;
    my $object = &get_object_by_name($object_name);
    my $object_name2 = &pretty_object_name($object_name);
    my $html = "<b>$object_name2 info</b><br>\n";
    $html .= $object->{info};
    return $html;
}

sub html_active_href {
    my($url, $text) = @_;
    return qq[<a href=$url>$text</a>];
                                # Netscape has problems with this when 
                                # used with the hide-show javascript in main.shtml / top.html
    return qq[
      <a href=$url>
      <SPAN onMouseOver="this.className='over';"
      onMouseOut="this.className='out';" 
      style="cursor: hand"
      class="blue">$text</SPAN></a>
    ]
}

sub pretty_object_name {
    my ($name) = @_;
    $name = substr($name, 1) if substr($name, 0, 1) eq "\$";
    $name =~ tr/_/ /;
    $name = ucfirst $name;
    return $name;
}


                                # Avoid mh pauses by printing to slow remote clients with a 'forked' program
my $socket_fork_count = 0;
sub print_socket_fork {
    my ($socket, $html) = @_;
    my $length = length $html;
                                # These sizes are picked a bit randomly.  Don't need to fork on small files
    if (($main::config_parms{http_fork} or !$OS_win) and
        ($length > 2000 and !&is_local_address() or $length > 10000)) {
        print "http_server: printing with forked socket: l=$length s=$socket\n" if $main::config_parms{debug} eq 'http';
        if ($OS_win) {
            &socket_fork_win($socket, $html);
        }
        else {
            &socket_fork_unix($socket, $html);
        }
    }
    else {
        print $socket $html;
    }
}

# Magic simulated fork using copied file handles from
#  Example: 7.22 of "Win32 Perl Scripting: Administrators Handbook" by Dave Roth
#  Published by New Riders Publishing  ISBN # 1-57870-215-1

sub socket_fork_win {
    my($socket, $html) = @_;
    my ($process, $perl, $cmd);
    $cmd = 'perl'    if            $perl = &main::which('perl.exe');
    $cmd = 'mh -run' if !$perl and $perl = &main::which('mh.exe');
    if ($cmd) {
        my $file = "$Pgm_Path/../data/http_fork_" . $socket_fork_count++;
        &file_write($file, $html);
        $cmd .= " $Pgm_Path/print_socket_fork.pl $file";
        open OLD_STDOUT, ">&STDOUT"  or print "\nsocket_fork error: can not backup STDOUT: $!\n";
        open STDOUT,     ">&" . $socket->fileno() or die "Can not redirect STDOUT: $!\n";
        my $pid = Win32::Process::Create($process, $perl, $cmd, 1, 0, '.') or
            print "Warning, run error: pgm_path=$perl $cmd\n error=", Win32::FormatMessage( Win32::GetLastError() ), "\n";
        open  STDOUT, ">&OLD_STDOUT"  or print "\nsocket_fork error: can not redir STDIN to orig value: $!\n";
        close OLD_STDOUT;
                                # Need to close the socket only after the process is done :(
        $socket_fork_processes{$pid} = [$process, $socket]; # Used in mh to close the socket
        $leave_socket_open_passes = -1; # This will not close the socket
#       shutdown($socket, 0);   # "how":  0=no more receives, 1=sends, 2=both
#       $socket->close();
    }
    else {
        print "\nsocket_fork_win error: no perl.exe or mh.exe found\n" unless $cmd;
        print $socket $html;
    }

}

                                # Forks are MUCH easier in unix :)
sub socket_fork_unix {
    my($socket, $html) = @_;

    my $pid = fork;
    if (defined $pid && $pid == 0) {
        print $socket $html;
        $socket->close;
                                # This avoids 'Unexpected async reply' if mh -tk 1
        &POSIX::_exit(0) 
#       exit;
    }
    else {
                                # Not sure why, but I get a broken pipe if I shutdown send or both.
        shutdown($socket, 0);   # "how":  0=no more receives, 1=sends, 2=both
#       $socket->close;
    }
}

                                # Netscape 4.? hangs if we print > 28k bytes all at once to the socket :(
                                #  - this does not fix the problem :((
                                #  - but printing with a fork as above does solve the problem :)
sub print_socket2 {
    my ($socket, $html) = @_;
#   binmode $socket;
#    my $old_fh = select($socket);
#    $| = 1;
#    select($old_fh);
    my $length = length $html;
    print "db l=$length\n";
    my $pos = 0;
    while ($pos <= $length) {
        print $socket substr $html, $pos, 1000;
        $pos += 1000;
    }
}


sub vars_save {
    my @table_items;
    unless ($Authorized or $main::config_parms{password_protect} !~ /vars/i) {
        return "<h4>Not Authorized to view Variables</h4>";
    }
    for my $key (sort keys %Save) {
        my $value = ($Save{$key}) ? $Save{$key} : '';
        push @table_items, "<td align='left'><b>$key:</b> $value</td>";
    }
    return &table_it(2, 1, 1, @table_items);
}

sub vars_global {
    my @table_items;
    unless ($Authorized or $main::config_parms{password_protect} !~ /vars/i) {
        return "<h4>Not Authorized to view Variables</h4>";
    }

    for my $key (sort keys %main::) {
                                # Assume all the global vars we care about are $Ab... 
        next if $key !~ /^[A-Z][a-z]/ or $key =~ /\:/;
        next if $key eq 'Save' or $key eq 'Tk_objects'; # Covered elsewhere
        next if $key eq 'Socket_Ports';

        no strict 'refs';
        if (defined ${$key}) {
           my $value = ${$key};
#          next unless defined $value;
           next if $value =~ /HASH/; # Skip object pointers
           push @table_items, "<td align='left'><b>\$$key:</b> $value</td>";
        } 
        elsif (defined %{$key}) {
            for my $key2 (sort eval "keys \%$key") {
                my $value = eval "\$$key\{'$key2'\}\n";
#               next unless defined $value;
                $value = '' unless $value; # Avoid -w uninitialized value msg
                next if $value =~ /HASH/; # Skip object pointers
                push @table_items, "<td align='left'><b>\$$key\{$key2\}:</b> $value</td>";
            }
        }
    }
    return &table_it(2, 1, 1, @table_items);
}



sub vxml_page {
    my ($vxml) = @_;

    my $header = "Content-type: text/xml";
#   $header    = $Cookie . $header if $Cookie;

    return <<eof;
HTTP/1.0 200 OK
Server: MisterHouse
$header
<!DOCTYPE vxml PUBLIC "-//Tellme Networks//Voice Markup Language 1.0//EN"
 'http://resources.tellme.com/toolbox/vxml-tellme.dtd'>

<vxml application="http://resources.tellme.com/lib/universals.vxml">

$vxml

</vxml>
eof

}
                                # vxml for audio text/wav followed by a goto
sub vxml_audio {
    my ($name, $text, $wav, $goto) = @_;
    my $vxml;
    $vxml  = "<form id='$name' anchor='true'>\n <block>\n  <audio ";
    $vxml .= "src='$wav'" if $wav;
    $vxml .= ">$text</audio>\n";
    $vxml .= "  <goto next='$goto'/>\n </block></form>";
    return $vxml;
}

                                # vxml for a basic form with grammar.  Called from &menu_vxml
sub vxml_form {
    my %parms = @_;
    my ($prompt, $grammar, $filled);
    my @grammar = @{$parms{grammar}};
    my @action  = @{$parms{action}};
    my @goto    = @{$parms{goto}};
    my $noinput = 'Sorry, I did not hear anything.';
    my $nomatch = 'What was that again?';
    $prompt  = qq|<prompt><audio>$parms{prompt}</audio></prompt>| if $parms{prompt};

                                # Add previous menu option
    unshift @grammar, 'previous';
    unshift @goto,    ($parms{prev}) ? "#$parms{prev}" : '_lastanchor';
    unshift @action,  '';
    unless ($parms{help}) {
        $parms{help} = 'Speak or key one of ' . scalar @grammar . 'commands: ';
        my $i = 1;
        for my $cmd (@grammar) {
            $parms{help} .= $i++ . ": $cmd, ";
        }
    }
#   $parms{help}    = "Speak or key one of " . scalar @grammar . " commands: " . join(', ', @grammar) unless $parms{help};

    my $i = 0;
    for my $text ('help', @grammar) {
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
        if ($i == 0) {
            $grammar .= qq|[$cmd] {<option "help">}\n|;
        }
        else {
            $grammar .= qq|[$cmd] {<option "$i">}\n|;
            $filled  .= qq|  <result name='$i'>\n|;
            $filled  .= qq|   <audio>$text</audio>\n| unless $text eq 'previous';
            $filled  .= qq|   $action[$i-1]\n| if $action[$i-1];
            $filled  .= qq|   <goto next='$goto[$i-1]'/>\n  </result>\n|;
        }
        $i++;
    }
    return <<eof;
 <form id='$parms{name}' anchor='true'>
  <field name="$parms{name}" timeout="60">
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
   <default>
    <reprompt/> 
   </default>
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
    my ($request_type, $request_category) = @_;

    $request_category = '' unless $request_category;

    unless ($Authorized or $main::config_parms{password_protect} !~ /widgets/i) {
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

        next unless $request_type eq 'search' or
            (($request_type eq 'all' or $type eq $request_type) and 
             (!$request_category or $request_category eq $category));

        my $search = $request_category if $request_type eq 'search';

        if ($type eq 'label') {
#            $cols = 2;
            push @table_items, &widget_label($search, @data);
        }
        elsif ($type eq 'entry') {
            push @table_items, &widget_entry($search, @data);
        }
        elsif ($type eq 'radiobutton') {
            push @table_items, &widget_radiobutton($search, @data);
        }
        elsif ($type eq 'checkbutton') {
            push @table_items, &widget_checkbutton($search, @data);
        }
    }
    return &table_it($cols, 0, 0, @table_items);
}

sub widget_label {
    my @table_items;
    my $search = shift @_;
    for my $pvar (@_) {
        my $label = $$pvar;
        next unless $label and $label =~ /\S{3}/;   # Drop really short labels, like tk_eye
        next if $search and $label !~ /$search/i;
        my ($key, $value) = $label =~ /(.+?\:)(.*)/;
        $value = '' unless $value;
        push @table_items, qq[<tr><td align='left' colspan=1><b>$key</b></td>] .
                           qq[<td align='left' colspan=5>$value</td></tr>];
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
        my $label= shift @_;
        my $pvar = shift @_;

        next if $search and $label !~ /$search/i;
        push @table_items, qq[<td align=left><b>$label:</b></td>];
                                # Put form outside of td, or else td gets too high
        my $html = qq[<FORM name="widgets_entry" ACTION="SET;$H_Response"  target='speech'> <td align='left'>];
        $html_pointers{++$html_pointer_cnt} = $pvar;
        $html_pointers{$html_pointer_cnt . "_label"} = $label;

                                # Allow for state objects
        my $value;
        if (ref $pvar ne 'SCALAR' and $pvar->can('set')) {
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
    while (@table_items < 6) {
        push @table_items, qq[<td></td>];
    }
    return @table_items;
}

sub widget_radiobutton {
    my @table_items;
    my $search = shift @_;
    my ($label, $pvar, $pvalue, $ptext) = @_;
    return if $search and $label and $label !~ /$search/i;
    my $html = qq[<FORM name="widgets_radiobutton" ACTION="SET;$H_Response"  target='speech'>\n];
    $html .= qq[<td align='left'><b>$label</b></td>];
    push @table_items, $html;
    $html_pointers{++$html_pointer_cnt} = $pvar;
    my @text = @$ptext if $ptext;         # Copy, so do not destroy original with shift
    for my $value (@$pvalue) {
        my $text = shift @text;
        $text = $value unless defined $text;
                                # Allow for state objects
        my $checked = '';
        if (ref $pvar ne 'SCALAR' and $pvar->can('set')) {
            $checked = 'CHECKED' if $pvar->state eq $value;
        }
        else {
            $checked = 'CHECKED' if $$pvar and $$pvar eq $value;
        }
        $html  = qq[<td align='left'><INPUT type="radio" NAME="$html_pointer_cnt" value="$value" $checked ];
        $html .= qq[$checked onClick="form.submit()">$text</td>];
        push @table_items, $html;
    }
    $table_items[$#table_items] .= qq[</form>\n];
    while (@table_items < 6) {
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
        next if $search and $text !~ /$search/i;
        $html_pointers{++$html_pointer_cnt} = $pvar;
        my $checked = ($$pvar) ? 'CHECKED' : '';
        my $html = qq[<FORM name="widgets_radiobutton" ACTION="SET;$H_Response"  target='speech'>\n];
        $html .= qq[<INPUT type="hidden" name="$html_pointer_cnt" value='0'>\n]; # So we can uncheck buttons
        $html .= qq[<td align='left'><INPUT type="checkbox" NAME="$html_pointer_cnt" value="1" $checked onClick="form.submit()">$text</td></FORM>\n];
        push @table_items, $html;
    }
    while (@table_items < 6) {
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
    my ($dir_html, $sortby, $reverse, $filter) = @_;

    $filter = '' unless $filter; # Avoid uninit warnings
    $sortby = '' unless $sortby; # Avoid uinit warnings
    my $reverse2 = ($reverse) ? 0 : 1;
    my $sort_order = ($reverse) ? '+' : '-' ;
    my ($dir) = &get_local_file($dir_html);
    my $dir_tr = $dir_html;
    $dir_tr =~ s/\//\%2F/g;

    opendir DIR, $dir or print "http_server: Could not open dir_index dir=$dir: $!\n";
    my @files = sort readdir DIR;
    close DIR;
    
    @files = grep /$filter/, @files if $filter; # Drop out files if requested

    $filter =~ s/\\/\%5C/g;
    my $html = qq[<table width=80% border=0 cellspacing=0 cellpadding=0>\n<tr height=50>];
    $html .= qq[<td><a href="SET;&dir_index('$dir_tr','name',$reverse2,'$filter')">$sort_order Sort by Name</a></td>\n];
    $html .= qq[<td><a href="SET;&dir_index('$dir_tr','type',$reverse2,'$filter')">$sort_order Sort by Type</a></td>\n];
    $html .= qq[<td><a href="SET;&dir_index('$dir_tr','size',$reverse2,'$filter')">$sort_order Sort by Size</a></td>\n];
    $html .= qq[<td><a href="SET;&dir_index('$dir_tr','date',$reverse2,'$filter')">$sort_order Sort by Date</a></td></tr>\n];

    my %file_data;
    for my $file (@files) {
        ($file_data{$file}{size}, $file_data{$file}{date}) = (stat("$dir/$file"))[7,9];
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
    if ($sortby eq 'date' or $sortby eq 'size') {
        @files = sort {$file_data{$a}{$sortby} <=> $file_data{$b}{$sortby} or $a cmp $b} @files;
    }
    elsif ($sortby eq 'type') {
        @files = sort {$file_data{$a}{$sortby} cmp $file_data{$b}{$sortby} or $a cmp $b} @files;
    }
    @files = reverse @files if $reverse;
    for my $file (@files) {
        my $file_date = localtime $file_data{$file}{date};
        $html .= "<tr><td><a href=$dir_html/$file>$file</a></td>\n";
        $html .= "<td>$file_data{$file}{type}</td>\n";
        $html .= "<td>$file_data{$file}{size}</td>\n";
        $html .= "<td>$file_date</td></tr>\n";
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


return 1;           # Make require happy

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
# $Log$
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
