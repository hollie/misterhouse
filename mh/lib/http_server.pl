#---------------------------------------------------------------------------
#  This lib provides the mister house web server routines
#  Change log is at the bottom
#---------------------------------------------------------------------------

use strict;

my ($leave_socket_open_passes, $leave_socket_open_action);

my($Authorized, $Authorized_html, $set_password_flag, $Browser, $Referer);
my($html_pointer_cnt, %html_pointers);

sub process_http_request {
    my ($socket, $header) = @_;

    $leave_socket_open_passes = 0;

    my ($text, $h_response, $h_index, $h_list, $item, $state, $file);
    undef $h_response;

                                # Check for authentication
    if (&password_check(undef, 'http')) {
        my ($user, $password);
        while (<$socket>) {
            last unless /\S/;
            $Referer = $1 if /^Referer: (\S+)/;
            if (/^Authorization: Basic (\S+)/) {
                ($user, $password) = split(':', &uudecode($1));
            }
                #User-Agent: Mozilla/4.0 (compatible; MSIE 5.0; Windows 98)
                #User-Agent: Mozilla/4.6 [en] (Win98; I)
            if (/^User-Agent:/) {
                $Browser = (/MSIE/) ? "IE" : "Netscape";
                print "db Browser=$Browser  $_\n" if $main::config_parms{debug} eq 'http';
            }
        }

        if ($password) {
            if (&password_check($password, 'http')) {
                $Authorized = 0;
            }
            else {
                $Authorized = 1;
            }
            print "db Password flag set to $Authorized\n" if $main::config_parms{debug} eq 'http';
        }
        else {
                                # Lets default to not authorized and use SET_PASSWORD to set authorization
            $Authorized = 0;
        }
    }
    else {
        $Authorized = 1;
    }

    $Authorized_html  = "Status: <B><a href=/SET_PASSWORD>" . (($Authorized) ? "Authorized" : "Not Authorized") . "</B></a><br>";

    my ($get_req, $get_arg) = $header =~ m|^GET (\/[^ \?]+)\??(\S+)? HTTP|;

                                # translate from %## back to real characters
#   $get_arg =~ tr/+/ /;        #  - not sure why we needed this??
    $get_arg =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;

    $get_req = $main::config_parms{html_file} unless $get_req;
    $file = "$main::config_parms{html_dir}/$get_req";

    print "db web data requested:  get=$get_req arg=$get_arg file=$file.\n  header=$header\n" if $main::config_parms{debug} eq 'http';

    if ($get_req =~ /\/SET_PASSWORD$/) {
        if ($set_password_flag) {
            $set_password_flag = 0;
            my $msg = $Authorized_html . <br>;
            $msg .= ($Authorized) ? "Authorization flag was set" : "Authorization flag was unset";
            
            if ($get_arg eq 'redir' and $Referer) {
                $msg .= qq[<META http-equiv="refresh" content="1; url=$Referer">\n];
                $msg .= "<br>Go back to <a href=$Referer>$Referer</a>\n";
            }
            print $socket &html_page("", "$msg\n");
        }
        else {
            $set_password_flag = 1;
            print $socket <<eof;
HTTP/1.0 401 Unauthorized
Server: MisterHouse
Content-type: text/html
WWW-Authenticate: Basic realm="mh_control"
eof
        }
        return;
    }

    if (!$Authorized and lc $main::config_parms{password_protect} eq 'all') {
        $h_response  = "<center><h3>MisterHouse password_protect set to all.  Password required for all functions</h3>\n";
        $h_response .= "<h3><a href=/SET_PASSWORD?redir>Login</a></h3></center>";

        print $socket &html_page("", $h_response);
        return;
    }


    if (-d $file) {
        my $file2;
                                # Don't allow bad guys to go up the directory chain
        if ($get_req =~ /^\/\.\./) {
            print $socket &html_page("Error", "Access denied: $file");
        }            
        for my $default (split(',', $main::config_parms{html_default})) {
            $file2 = "$file/$default";
            last if -e $file2;
        }
        if (-e $file2) {
            &html_file($socket, $file2, $get_arg);
        }
        else {
            print $socket &html_page("Error", "No index found for directory: $file");
        }
    }
    elsif (-e $file) {
        &html_file($socket, $file, $get_arg);
    }
    elsif (my ($html, $style) = &html_mh_generated($get_req, $get_arg)) {
        print $socket &html_page("", $html, $style);
    }        
    elsif  ($get_req =~ /\/RUN$/ or
            $get_req =~ /\/RUN\:(\S*)$/) {
        $h_response = $1;

        $get_arg =~ s/^cmd=//;  # Drop the cmd= prefix from form lists.
        $get_arg =~ tr/\_/ /;   # Put blanks back
        $get_arg =~ tr/\~/_/;   # Put _ back
        $get_arg =~ s/\&x=\d+\&y=\d+$//;    # Drop the &x=n&y=n that is tacked on the end when doing image form submits

        print "db a=$Authorized RUN get_arg=$get_arg response=$h_response\n" if $main::config_parms{debug} eq 'http';

        if ($Authorized or $Password_Allow{$get_arg}) {
            if (&run_voice_cmd($get_arg)) {
                &html_response($socket, $h_response);
            }
            else {
                my $msg = "The Web RUN command not found: $get_arg.\n";
#               print $socket &html_page("", $msg, undef, undef, "control");
                print $socket &html_page("", $msg);
                print_log $msg;
            }
        }
        else {
            my $msg = "<a href=speech>Refresh Recently Spoken Text</a><br>\n";
            $msg .= "<br><B>Unauthorized Mode.</B> Authorization flag was not set, to the following was NOT performed<p>";
            $msg .= "<li>" . $get_arg . "</li>";
            print $socket &html_page("", $msg);
        }
    }
    elsif ($get_req =~ /\/SET$/ or 
           $get_req =~ /\/SET\:(\S*)$/) {
        $h_response = $1;
        ($item, $state) = $get_arg =~ /^(\S+)\?(\S+)$/;

        print "db SET item=$item state=$state response=$h_response\n" if $main::config_parms{debug} eq 'http';
        my $item_speakable = substr($item, 1); # Drop the $ off the object name
        $item_speakable =~ s/\_/ /g;
        $item_speakable =~ s/\~/_/g;
        $state =~ s/\_/ /g;      # No blanks were allowed in a url 
        $state =~ s/\~/_/g;      # Put _ back

        my $object = &get_object_by_name($item);
        my $state_now = $object->{state};
        my $text = $item_speakable;
        if ($state_now) {
            $text .= ($state eq $state_now) ? " set to $state again" : " changed from $state_now to $state";
        }
        else {
            $text .= " set to $state";
        }

        if ($Authorized or $Password_Allow{$item}) {
            eval "set $item '$state'" if $item and $state; # May only have a responce with no item
            &html_response($socket, $h_response,undef,undef);
            # &html_response($socket, $h_response,undef,undef,"speech");
        }
        else {
            my $msg = "<a href=speech>Refresh Recently Spoken Text</a><br>\n";
            $msg .= "<br><B>Unauthorized Mode.</B> Authorization flag was not set, to the following was NOT performed<p>";
            $msg .= "<li>set $item '$state'</li>";
            print $socket &html_page("", $msg);
        }
    }
    elsif  ($get_req =~ /\/SET_VAR$/ or
            $get_req =~ /\/SET_VAR\:(\S*)$/) {
        $h_response = $1;

        print "db SET_VAR a=$Authorized hr=$h_response\n get_req=$get_req  get_arg=$get_arg\n  \n" if $main::config_parms{debug} eq 'http';

                                # translate from %## back to real characters
#        $get_arg =~ tr/+/ /;
#        $get_arg =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;

        if ($Authorized) {
            my %states;
            my $use_pointers;
            for my $temp (split('&', $get_arg)) {
                ($item, $state) = $temp =~ /(\S+)=(.*)/;
                                # If item name is only digits, this implies tk_widgets, where we used html_pointer_cnt as an index
                if ($item =~ /^\d+$/) {
                    $states{$item} = $state;
                    $use_pointers++;
                    my $pvar = $html_pointers{$item};
                    $$pvar = $states{$item};
                    $Tk_results{$html_pointers{$item . "_label"}} = $states{$item};
                }
                                # Otherwise, we are trying to pass var name in directly. 
                else {
                    print qq[SET_VAR eval $item = "$state"\n] if $main::config_parms{debug} eq 'http';
                    eval qq[$item = "$state"];
                }
            }            
            &html_response($socket, $h_response);
        }
        else {
                                # IE does not support the Window-frame flag :(
                                # So we can not give the 'unauthorized' message without messing up the widget frame.
            if (0 and $Browser eq 'IE') {
#               print $socket &html_page("", &widgets ); # Refresh frame
            }
            else {
                my $msg = "<a href=speech>Refresh Recently Spoken Text</a><br>\n";
                $msg .= "<br><B>Unauthorized Mode.</B> Authorization flag was not set, to the following was NOT performed<p>";
                $msg .= "<li>set $get_req $get_arg</li>";
                print $socket &html_page("", $msg, undef, undef, 'control');
            }
        }

    }
    else {
        my $msg = "Unrecognized html request: get_req=$get_req   get_arg=$get_arg<p>  header=$header\n";
        print $socket &html_page("Error", $msg);
        print $msg;
    }

    return ($leave_socket_open_passes, $leave_socket_open_action);
}

sub html_mh_generated {
    my ($get_req, $get_arg) = @_;
        my $html;
                                # .html suffix is grandfathered in
    if ($get_req =~ /\/widgets(.html)?$/) {
        $html .= &widgets_checkbutton, $main::config_parms{html_style_tk};
        $html .= &widgets_radiobutton, $main::config_parms{html_style_tk};
        $html .= &widgets_entry, $main::config_parms{html_style_tk};
        return ($html, $main::config_parms{html_style_tk});
    }
    elsif ($get_req =~ /\/widgets_label$/) {
        $html = qq[<META HTTP-EQUIV="REFRESH" CONTENT="$main::config_parms{html_refresh_rate}">\n] if $main::config_parms{html_refresh_rate};
        return ($html . &widgets_label, $main::config_parms{html_style_tk});
    }
    elsif ($get_req =~ /\/widgets_entry$/) {
        return (&widgets_entry, $main::config_parms{html_style_tk});
    }
    elsif ($get_req =~ /\/widgets_radiobutton$/) {
        return (&widgets_radiobutton, $main::config_parms{html_style_tk});
    }
    elsif ($get_req =~ /\/widgets_checkbox$/) {
        return (&widgets_checkbutton, $main::config_parms{html_style_tk});
    }
    elsif ($get_req =~ /\/speech(.html)?$/) {
        return (&html_last_spoken, $main::config_parms{html_style_speak});
    }
    elsif ($get_req =~ /\/print_log(.html)?$/) {
        return (&html_print_log, $main::config_parms{html_style_print});
    }
    elsif ($get_req =~ /\/category$/) {
        return (&html_category, $main::config_parms{html_style_category});
    }
    elsif ($get_req =~ /\/groups$/) {
        return (&html_groups, $main::config_parms{html_style_category});
    }
    elsif ($get_req =~ /\/items$/) {
        return (&html_items, $main::config_parms{html_style_category});
    }
    elsif ($get_req  =~ /\/?list$/) {
        $html = &html_list($get_arg);
        return ($html, $main::config_parms{html_style_list});
    }
    elsif ($get_req =~ /\/results$/) {
        return ("<h2>Click on any item\n");
    }
    else {
        return;
    }
}

sub html_response {
    my ($socket, $h_response) = @_;
    my $file;

                                # This should have been done already?
#    $h_response =~ tr/+/ /;
#    $h_response =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;

    print "db html responce: $h_response\n" if $main::config_parms{debug} eq 'http';
    if ($h_response) {
        my ($sub_name, $sub_arg, $sub_ref);
                                # Allow for &sub1 and &sub1(args)
        if ((($sub_name, $sub_arg) = $h_response =~ /^\&(\S+)\((\S+)\)$/) or
            (($sub_name)           = $h_response =~ /^\&(\S+)$/)) {
            print "db hr=$h_response sn=$sub_name sa=$sub_arg\n" if $main::config_parms{debug} eq 'http';
            $sub_ref = \&{$sub_name};
            if (defined &$sub_ref) {
                $leave_socket_open_action = "&$sub_name('$sub_arg')";
                $leave_socket_open_passes = 2; # Assume a display or a speak will reset this??
#               my $html = &$sub_ref($sub_arg);
#               print $socket &html_page("", $html);
            }
            else {
                print $socket &html_page("", "Web html function not found: $sub_name");
            }
        }
        elsif ($h_response eq 'last_response') {
            undef $Last_Response;
            $leave_socket_open_passes = 2; # This will get set to 2 when display is run
            $leave_socket_open_action = "&html_last_response";
        }
        elsif ($h_response eq 'last_displayed') {
            $leave_socket_open_passes = 2; # This will get set to 2 when display is run
            $leave_socket_open_action = "&html_last_displayed";
        }
        elsif ($h_response eq 'last_spoken') {
            $leave_socket_open_passes = 2;
            $leave_socket_open_action = "&Voice_Text::last_spoken(1)"; # Only show the last spoken text
        }
        elsif (-e ($file = "$main::config_parms{html_dir}/$h_response")) {
            &html_file($socket, $file);
        }
        else {
            $h_response =~ tr/\_/ /; # Put blanks back
            $h_response =~ tr/\~/_/; # Put _ back
            print $socket &html_page("", $h_response);
        }
    }
                                # The default ... show last fews spoken phrases
    else {
        $leave_socket_open_passes = 2;
        $leave_socket_open_action = "&html_last_spoken";

    }
}

sub html_control {

    return <<eof;
 $Authorized_html
 <p>Click on a Category for a list of items</p>
eof
}

sub html_last_response {
   my $last_response;
   if ($Last_Response eq 'display') {
       ($last_response) = &display_log_last(1);
                                # Add breaks on newlines
       $last_response =~ s/\n/\n<br>/g;
#      $last_response = "<h4>Last Displayed Text</h3>$last_response";
   }
   elsif ($Last_Response eq 'speak') {
       $last_response = &Voice_Text::last_spoken(1);
   }
   else {
       $last_response = "<h4>No response resulted from the last command</hr>";
   }

   return $last_response;
}

sub html_last_displayed {
    my ($last_displayed) = &display_log_last(1);

                                # Add breaks on newlines
    $last_displayed =~ s/\n/\n<br>/g;

    return "<h3>Last Displayed Text</h3>$last_displayed";
}

sub html_last_spoken {
    my $h_response;

    if ($Authorized or $main::config_parms{password_protect} !~ /logs/i) {
        $h_response .= qq[<META HTTP-EQUIV="REFRESH" CONTENT="$main::config_parms{html_refresh_rate}">\n] if $main::config_parms{html_refresh_rate};
        $h_response .= "<a href=speech>Refresh Recently Spoken Text</a>\n";
        my @last_spoken = &Voice_Text::last_spoken($main::config_parms{max_log_entries});
        for my $text (@last_spoken) {
            $h_response .= "<li>$text\n";
        }
    }
    else {
        $h_response = "<h3>Recently Spoken Text:  Not Authorized</h3>";
    }
    return $h_response .= "\n";
}

sub html_print_log {

    my $h_response;
    if ($Authorized or $main::config_parms{password_protect} !~ /logs/i) {
        $h_response .= qq[<META HTTP-EQUIV="REFRESH" CONTENT="$main::config_parms{html_refresh_rate}">\n] if $main::config_parms{html_refresh_rate};
        $h_response .= "<a href=print_log>Refresh Print Log</a>\n";
        my @last_printed = &main::print_log_last($main::config_parms{max_log_entries});
        for my $text (@last_printed) {
            $h_response .= "<li>$text\n";
        }
    }
    else {
        $h_response = "<h3>Print Log:  Not Authorized</h3>";
    }
    return $h_response .= "\n";
}

sub html_file {
    my ($socket, $file, $arg) = @_;
    print "printing html file $file to $socket\n" if $main::config_parms{debug} eq 'http';

    local *HTML;                # Localize, for recursive call to &html_file

    unless (open (HTML, $file)) {
        print "Error, can not open html file: $file: $!\n";
        close HTML;
        return;
    }

                                # Allow for 'server side include' directives
                                #  <!--#include file="whatever"-->
    if ($file =~ /\.shtml$/) {
        print "db processing server side include file: $file\n" if $main::config_parms{debug} eq 'http';
        while (<HTML>) {
                                # Example:  <li>Version: <!--#include var="$Version"--> ...
            if (my ($prefix, $directive, $data, $suffix) = $_ =~ /(.*)\<\!--+ *\#include +(\S+)=\"([^\"]+)\" *--\>(.*)/) {
                 print "db http include: $directive=$data\n" if $main::config_parms{debug} eq 'http';
                print $socket $prefix;
                if ($directive eq 'file') {
                    if (-e ($file = "$main::config_parms{html_dir}/$data")) {
                        &html_file($socket, $file);
                    }
                    elsif (my ($html) = &html_mh_generated("/$data")) {
                        print $socket $html;
                    }
                    else {
                        print "Error, shtml file directive not recognized: $data\n";
                    }
                }
                elsif ($directive eq 'var' or $directive eq 'code') {
                    print "db processing server side include: var=$data\n" if $main::config_parms{debug} eq 'http';
                    print $socket eval "return $data";
                    print "Error in eval: $@" if $@;
                }
                else {
                    print "http include directive not recognized:  $directive = $data\n";
                }
                print $socket $suffix;
            }
            else {
                print $socket $_;
            }
        }
    }
                                # Allow for .pl cgi programs
                                # Note: These differ from classic .cgi in that they return 
                                #       the results, rather than print them to stdout.
    elsif ($file =~ /\.pl$/) {
        @ARGV = split('&', $arg);
        my $code = join(' ', <HTML>);

                                # I couldn't figure out how to open STDOUT to $socket
#       open(OLDOUT_H, ">&STDOUT"); # Copy old handle
#       fdopen 'STDOUT' $socket   or print "Could not redirect http_server STDOUT to $socket: $!\n";
#       open(STDOUT, ">&$socket") or print "Could not redirect http_server STDOUT to $socket: $!\n";
#       my $results = eval $code;
#       open(STDOUT, ">&OLDOUT_H");
#       close OLDOUT_H;

        my $results = eval $code;
        print "Error in http eval: $@" if $@;
        print "db http_server  .pl file results:$results.\n" if $main::config_parms{debug} eq 'http';
        print $socket $results;
    }
                                # Regular files.  read is faster than <>
    else {
        my $buff;
        binmode HTML;
        while (read(HTML, $buff, 8*2**10)) {
            print $socket $buff;
        }
    }

    close HTML;
}


sub html_page {
    my ($title, $body, $style, $script, $frame) = @_;
#   print "db html_page=$title\n$body\n";
                                # This meta tag does not work :(
                                # MS IE does not honor Window-target :(
#   my $frame2 = qq[<META HTTP-EQUIV="Window-target" CONTENT="$frame">] if $frame;
    $frame = "Window-target: $frame" if $frame;
    $style = $main::config_parms{html_style} if $main::config_parms{html_style} and !$style;
    return <<eof;
HTTP/1.0 200 OK
Content-Type: text/html
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

sub html_category {
    my $h_index;
    for my $category (&list_code_webnames) {
                                # Only list a category if it has commands
        next unless &html_list($category) =~ /RUN/;
        $h_index    .= "<li>" . &html_active_href("list?$category", $category) . "\n";
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
    for my $object_type ('X10_Item', 'X10_Appliance', 'Group', 'Serial_Item') {
        $h_index    .= "<li>" . &html_active_href("list?$object_type", $object_type) . "\n";
    }
    return $h_index;
}

my %html_icons;
sub html_reset_icons {
    print "db icons undefed\n";
    undef %html_icons;
}
sub html_find_icon_image {
    my ($object, $type) = @_;

    $type = lc $type;
    my $name  = lc $object->{object_name};
    my $state = lc $object->{state};

    $name =~ s/^\$//;           # remove $ at front of objects
    $name =~ s/^v_//;           # remove v_ in voice commands

    $state = 'dim' if $state =~ /^[+-]?\d+$/;
    print "db find_icon: object_name=$name, type=$type, state=$state\n" if $main::config_parms{debug} eq 'http';

    my ($icon, $member);
    unless (%html_icons) {
        print "Reading html icons directory\n";
        opendir (ICONS, "$main::config_parms{html_dir}/graphics/");
        for $member (readdir ICONS) {
            ($icon) = $member =~ /(\S+)\.\S+/;
            next unless $icon;
            $icon = lc $icon;
            $html_icons{$icon} = $member;
        }
    }

                                # Allow for set_icon to set the icon directly
    $name = $object->{icon} if $object->{icon};

                                # Look for exact matches
    if ($icon = $html_icons{"$name-$state"}) {
    }
                                # For voice items, look for approximate name matches
                                #  - Order of preference: object, text, filename
                                #    and pick the longest named match
    elsif ($type eq 'voice') {
        my ($i1, $i2, $i3, $l1, $l2, $l3);
        for my $member (sort keys %html_icons) {
            next if $member eq 'on' or $member eq 'off';
            my $l = length $member;
            if($name               =~ /$member/i and $l > $l1) { $i1 = $html_icons{$member}; $l1 = $l};
            if($object->{text}     =~ /$member/i and $l > $l2) { $i2 = $html_icons{$member}; $l2 = $l};
            if($object->{filename} =~ /$member/i and $l > $l3) { $i3 = $html_icons{$member}; $l3 = $l};
#           print "db n=$name t=$object->{text} $i1,$i2,$i3 l=$l m=$member\n" if $name =~ /set_clock/ or $object->{text} =~ /house in /;
        }
        if    ($i1) {$icon = $i1}
        elsif ($i2) {$icon = $i2} 
        elsif ($i3) {$icon = $i3}
        else {
            return;         # No match
        }
    }
                                # For non-voice items, try State and Item type matches
    else {

        unless ($icon = $html_icons{"$type-$state"} or
                $icon = $html_icons{$type}          or
                $icon = $html_icons{$state}) {
            return;         # No match
        }
    }
    return "/graphics/$icon";

#    my $h_icon;
#    if (($h_icon = $icon_dir . $name  . "-" . $state . ".gif") and -r ($html_dir . $h_icon) or # light-off.gif
#        ($h_icon = $icon_dir . $name  .                ".gif") and -r ($html_dir . $h_icon) or # light.gif
#        ($h_icon = $icon_dir . $type  . "-" . $state . ".gif") and -r ($html_dir . $h_icon) or # x10_item-off.gif
#        ($h_icon = $icon_dir . $type  .                ".gif") and -r ($html_dir . $h_icon) or # x10_item.gif
#        ($h_icon = $icon_dir . $state .                ".gif") and -r ($html_dir . $h_icon)) { # off.gif         
#        return $h_icon;
#    }
}

sub html_list {

    my($webname_or_object_type) = @_;
    my ($object, @object_list, $num, $h_list);
    
    $h_list .= "<center><b>$webname_or_object_type</b> &nbsp &nbsp &nbsp &nbsp $Authorized_html</center>\n";
    $h_list =~ s/group=\$//;     # Drop the group=$ prefix on group lists

#   $h_list .= qq[<!-- html_list -->\n<BASE TARGET='speech'>];
    $h_list .= qq[<!-- html_list -->\n];

    if ($webname_or_object_type =~ /^search=(\S+)/) {
        $h_list .= "<!-- html_list search -->\n";
        my @cmd_list = grep /$1/, &list_voice_cmds_match($1);
        for my $cmd (@cmd_list) {
            my ($file, $cmd2) = $cmd =~ /(.+)\:(.+)/;
            my $cmd3 = $cmd2;
            $cmd3 =~ tr/\_/\~/; # Swizzle _ to ~, so we can use _ for blanks
            $cmd3 =~ tr/ /\_/; # Blanks are not allowed in urls
#           $h_list .= "<li><i>$file</i>: <a href='RUN?$cmd3'>$cmd2</a>\n";
            $h_list .= "<li><a href='RUN?$cmd3'>$cmd2</a>\n";
        }
        $h_list  .= "\n";
        $h_list .= "<!-- html_list return -->\n";
        return $h_list;
    }

                                # Treat groups and item lists the same way
    if ($webname_or_object_type =~ /^group=(\S+)/) {
        $h_list .= "<!-- html_list group = $webname_or_object_type -->\n";
        my $object = &get_object_by_name($1);
        my @table_items = map{&html_item_state($_, $webname_or_object_type)} list $object;
        $h_list .= &table_it($config_parms{html_table_size}, 0, 0, @table_items);
        return $h_list;
    }

    if (@object_list = sort &list_objects_by_type($webname_or_object_type)) {
        $h_list .= "<!-- html_list list_objects_by_type = $webname_or_object_type -->\n";
        my @objects = map{&get_object_by_name($_)} @object_list;
        my @table_items = map{&html_item_state($_, $webname_or_object_type)} @objects;
        $h_list .= &table_it($main::config_parms{html_table_size}, 0, 0, @table_items);
        return $h_list;
    }

    if (@object_list = &list_objects_by_webname($webname_or_object_type)) {
        $h_list .= "<!-- html_list list_objects_by_webname -->\n";
        $h_list .= &html_command_table(sort @object_list);
    }
    $h_list .= "<!-- html_list return -->\n";
    return $h_list;

}

sub table_it {
    my ($cols, $border, $space, @items) = @_;

    my $h_list .= qq[<table border='$border' width="100%" cellspacing="$space" cellpadding="0">\n<tr align=center>\n];
    my $num = 0;
    for my $item (@items) {
        if ($num ge $cols) {
            $h_list .= "</tr>\n\n<tr align=center>\n";
            $num = 0;
        }
        $h_list .= $item . "\n";
        $num++;
    }
                                # do this so we don't throw off the table cell sizes if the number of items is not divisable
    while ($num lt $cols) {
        $h_list .= qq[<td align="right"></td>];
        $h_list .= qq[<td> </td>];
        $num++;
    }
    $h_list .= "</tr>\n</table>\n</table>";
    return $h_list;
}

sub html_command_table {
    my (@object_list) = @_;
    my ($h_ret, @htmls);
    my $list_count = 0;

    my @objects = map{&get_object_by_name($_)} @object_list;

                                # Sort by filename first, then object name
    for my $object (sort {$a->{filename} cmp $b->{filename} or $a->{text} cmp $b->{text}} @objects) {
        my $object_name = $object->{object_name};
        my $state_now   = $object->{state};
        my $filename    = $object->{filename};
        my $text        = $object->{text};
        next unless $text;      # Only do voice items
        $list_count++;

                                # Find the states and create the test label
                                #  - pick the first {a,b,c} phrase enumeration 
        $text =~ s/\{(.+?),.+?\}/$1/g;

        my ($prefix, $states, $suffix, $h_text, $text_cmd);
        ($prefix, $states, $suffix) = $text =~ /^(.*)\[(.+?)\](.*)$/;

                                # Do the filename entry
        push @htmls, qq[<td align='left' valign='center'>$filename</td>\n] if $main::config_parms{html_category_filename};


                                # Start the form before the icon
                                #  - outside of td so the table is shorter
                                #  - allows the icon to be a submit
        my $form = qq[<FORM action="/RUN:last_response" method="get" target='speech'>\n];

                                # Do the icon entry
        if ($main::config_parms{html_category_icons} and
            my $h_icon = &html_find_icon_image($object, 'voice')) {
            $h_ret = qq[<input type='image' src="$h_icon" alt="$h_icon" border="0">\n];
#           $h_ret = qq[<img src="$h_icon" alt="$h_icon" border="0">];
        }
        else {
            $h_ret = qq[<input type='submit' border='1' value='Run'>\n];
        }
        push @htmls, qq[$form<td align='left' valign='center'>$h_ret</td>\n];

        $h_ret  = qq[<td align='left'>];
        $h_ret .= qq[<b>$prefix</b>] if $prefix;
        if ($states) {
            $h_ret .= qq[<SELECT name="cmd" onChange="form.submit()">\n<option value="  "> \n];
            for my $state (split(',', $states)) {
                my $text_cmd = "$prefix$state$suffix";
                $text_cmd =~ tr/\_/\~/; # Blanks are not allowed in urls
                $text_cmd =~ tr/ /\_/;  
                $h_ret .= qq[<option value="$text_cmd">$state\n];
            }
            $h_ret .= qq[</SELECT>\n];
        }
        else {
            $text =~ tr/\_/\~/; # Blanks are not allowed in urls
            $text =~ tr/ /\_/; 
            $h_ret .= qq[<b>$text</b>];
            $h_ret .= qq[<input type="hidden" name="cmd" value='$text'>\n];
        }

        $h_ret .= qq[<b>$suffix</b>] if $suffix;

                                # Do the text entry
        push @htmls, qq[$h_ret</td></FORM>\n];

                                # Do the state log entry
        if (my ($date, $time, $state) = (state_log $object)[0] =~ /(\S+) (\S+) (.+)/) {
#           $state = '' if $state eq $label; # This command has not states
            $h_ret = "<NOBR><a href='/SET:&html_state_log($object_name)' target='speech'>$date $time</a></NOBR> <b>$state</b>";
        }
        else {
            $h_ret = "unknown";
        }
        
        push @htmls, qq[<td align='left' valign='center'>$h_ret</td>\n\n];
    }
    my $i = ($main::config_parms{html_category_filename}) ? 4 : 3; 
    return &table_it($i, $main::config_parms{html_category_border}, 0,  @htmls);
}

                                # List current object state
sub html_item_state {
    my ($object, $object_type) = @_;
    my $object_name  = $object->{object_name};
    my $filename     = $object->{filename};
    my $state_now    = $object->{state};
    my $object_name2 = &pretty_object_name($object_name);
    my $h_ret;

                                # find icon to show state, if not found show state_now in text.
    $h_ret = qq[<td align="right"><a href='/SET:&html_state_log($object_name)' target='speech'>];
    if (my $h_icon = &html_find_icon_image($object, $object_type)) {
        $h_ret .= qq[<img src="$h_icon" alt="$h_icon" border="0">];
    } else {
        $h_ret .= $state_now;
    }
    $h_ret .= qq[</a> </td>\n];

    my $state_toggle;
    if ($state_now eq ON) {
        $state_toggle = OFF;
#       $state_toggle = '-50%';
    }
    elsif ($state_now =~ /^[+-]?\d/) {
        $state_toggle = OFF;
    }
    else {
        $state_toggle = ON;
    }
#    $h_ret .= qq[<td align="left"><b><a onClick='history.go(0)' href='/SET:hi_there?$object_name?$state_toggle'>$object_name2</a></b></td>\n];
    $h_ret .= qq[<td align="left"><b>];
    if ($object_type eq 'X10_Item' or $object_type =~ /^group/i) {
#       $h_ret .= qq[<a href='/SET:&html_list($object_type)?$object_name?+15'>+</a> ];
        $h_ret .= qq[<a href='/SET:&html_list($object_type)?$object_name?+15'><img src='/graphics/a1+.gif' alt='+' border='0'></a> ];
        $h_ret .= qq[<a href='/SET:&html_list($object_type)?$object_name?-15'><img src='/graphics/a1-.gif' alt='-' border='0'></a> ];
    }
    $h_ret .= qq[<a href='/SET:&html_list($object_type)?$object_name?$state_toggle'>$object_name2</a>];
    $h_ret .= qq[</b></td>\n];
    return $h_ret;
}

sub html_state_log {
    my ($object_name) = @_;
    my $object = &get_object_by_name($object_name);
    my $object_name2 = &pretty_object_name($object_name);
    my $h_ret = "<b>$object_name2 states</b><br>\n";
    for my $state (state_log $object) {
        $h_ret .= "<li>$state</li>\n";
    }
    return $h_ret . "\n";
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


sub widgets_label {
    my @table_items;
    for my $ptr (@Tk_widgets) {
        my @data = @$ptr;
        my $type = shift @data;
        if ($type eq 'label') {
            for my $pvar (@data) {
                my $label = $$pvar;
                $label =~ s/(.+?\:)/<b>$1<\/b>/; # Bold the lable part
                next unless $label =~ /\S{3}/; # Drop really short labesl, like tk_eye
                push @table_items, qq[<td align='left'>$label</td>];
            }
        }
    }
    return &table_it(1, 0, 0, @table_items);
}

sub widgets_entry {
    my @table_items;
    for my $ptr (@Tk_widgets) {
        my @data = @$ptr;
        my $type = shift @data;
        if ($type eq 'entry') {
            my $i;
            for (@data) {
                $i++;
                                # Put form outside of td, or else td gets too high
                my $html = qq[<FORM name="widgets_entry" ACTION="SET_VAR"  target='speech'> <td align='right'>];
                my $label= shift @data;
                my $pvar = shift @data;
                $html .= "<b>$label:</b> ";
                $html_pointers{++$html_pointer_cnt} = $pvar;
                $html_pointers{$html_pointer_cnt . "_label"} = $label;
                $html .= qq[<INPUT SIZE=10 NAME="$html_pointer_cnt" value="$$pvar">];
                $html .= qq[</td></FORM>\n];
                push @table_items, $html;
            }
#            push @table_items, qq[<td></td>] if $i == 1; # Even up the row
        }
    }
    return &table_it($main::config_parms{html_table_size}, 0, 0, @table_items);
}

sub widgets_radiobutton {
    my @table_items;
    my ($i, $html);
    for my $ptr (@Tk_widgets) {
        my @data = @$ptr;
        my $type = shift @data;
        if ($type eq 'radiobutton') {
            my ($label, $pvar, $pvalue, $ptext) = @data;
            $html = qq[<FORM name="widgets_radiobutton" ACTION="SET_VAR"  target='speech'>\n <td align='left'><b>$label</b></td>];
            push @table_items, $html;
            $html_pointers{++$html_pointer_cnt} = $pvar;
            my @text = @$ptext if $ptext;         # Copy, so do not destroy original with shift
            $i = 0;
            for my $value (@$pvalue) {
                $i++;
                my $text = shift @text;
                $text = $value unless defined $text;
                my $checked = 'CHECKED' if $$pvar eq $value;
                $html  = qq[<td align='left'><INPUT type="radio" NAME="$html_pointer_cnt" value="$value" $checked ];
                $html .= qq[$checked onClick="form.submit()">$text</td>];
                push @table_items, $html;
            }
            while ($i++ < 5) {
                push @table_items, qq[<td></td>];
            }
        }
    }
    return &table_it(6, 0, 0, @table_items) . qq[</FORM>\n];
}

sub widgets_checkbutton {
    my @table_items;
    my ($i, $html);
    for my $ptr (@Tk_widgets) {
        my @data = @$ptr;
        my $type = shift @data;
        if ($type eq 'checkbutton') {
            $i = 0;
            while (@data) {
                $i++;
                my $text = shift @data;
                my $pvar = shift @data;
                $html_pointers{++$html_pointer_cnt} = $pvar;
                my $checked = 'CHECKED' if $$pvar;
                $html  = qq[<FORM name="widgets_radiobutton" ACTION="SET_VAR"  target='speech'>\n];
                $html .= qq[<INPUT type="hidden" name="$html_pointer_cnt" value='0'>\n]; # So we can uncheck buttons
                $html .= qq[<td><INPUT type="checkbox" NAME="$html_pointer_cnt" value="1" $checked onClick="form.submit()">$text</td></FORM>\n];
                push @table_items, $html;
            }
            while ($i++ < 4) {
                push @table_items, qq[<td></td>];
            }
        }
    }
    return &table_it(6, 0, 0, @table_items) . qq[</FORM>\n];
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
GET http://mantis.rchland.ibm.com:8081/ HTTP/1.0
Connection: Keep-Alive
Accept: image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png, */*
Accept-Charset: iso-8859-1,*,utf-8
Accept-Language: en
Authorization: Basic YnJ1Y2Vfd2ludGVyOmFiY2Rl
Host: mantis.rchland.ibm.com:8081
User-Agent: Mozilla/4.04 [en] (X11; I; AIX 4.3)
Cookie: w3ibmID=19990118162505401224000000
=end comment


#
# $Log$
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
