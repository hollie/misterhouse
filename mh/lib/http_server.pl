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
        print "db gr=$get_req,\n";
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
            $get_req =~ /\/RUN_ARGS$/ or
            $get_req =~ /\/RUN\:(\S*)$/) {
        $h_response = $1;

        my $cmd;
        if ($get_req =~ /\/RUN_ARGS$/) {
            ($cmd) = $get_arg =~ /cmd=(\S+)$/;
            $get_arg=$cmd;
        }
        $get_arg =~ tr/\_/ /;      # Put blanks back
        $get_arg =~ tr/\~/_/;      # Put _ back

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
           $get_req =~ /\/SET_ARGS$/ or 
           $get_req =~ /\/SET\:(\S*)$/) {
        $h_response = $1;
        if ($get_req =~ /\/SET_ARGS$/) {
            $get_arg =~ tr/+/ /;
            $get_arg =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
            ($item) = $get_arg =~ /item=(\S\w+)\&/;  # damn dollar sign
            ($state) = $get_arg =~ /state=(\S+)\&/;
            my ($dim) = $get_arg =~ /dim=(\S+)$/;
            $state = $dim unless $state;
            print "item=$item\n";
            print "state=$state\n";
            print "dim=$dim\n";
        } else {
            ($item, $state) = $get_arg =~ /^(\S+)\?(\S+)$/;
        }

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
            eval "set $item '$state'";
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
        $get_arg =~ tr/+/ /;
        $get_arg =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;

        if ($Authorized) {
                                # Note: We need to visit all variables, including those not in the list, as checkbox
                                #       items are not echoed when they are unchecked.
                                #       Format:  1=abc&2=&5=hij
            my %states;
            my $use_pointers;
            for my $temp (split('&', $get_arg)) {
                ($item, $state) = $temp =~ /(\S+)=(.*)/;
                                # If item name is only digits, this implies tk_widgets, where we used html_pointer_cnt as an index
                if ($item =~ /^\d+$/) {
                    $states{$item} = $state;
                    $use_pointers++;
                }
                                # Otherwise, we are trying to pass var name in directly. 
                else {
                    print qq[SET_VAR eval $item = "$state"\n] if $main::config_parms{debug} eq 'http';
                    eval qq[$item = "$state"];
                }
            }            
            if ($use_pointers) {
                for $item (1..$html_pointer_cnt) {
                    my $pvar = $html_pointers{$item};
                    $$pvar = $states{$item};
                                # Echo the result inso Tk_results
                    $Tk_results{$html_pointers{$item . "_label"}} = $states{$item};
                }
                print $socket &html_page("", &tk_widgets ); # Refresh frame
            }
            else {
                &html_response($socket, $h_response);
            }
        }
        else {
                                # IE does not support the Window-frame flag :(
                                # So we can not give the 'unauthorized' message without messing up the widget frame.
            if ($Browser eq 'IE') {
                print $socket &html_page("", &tk_widgets ); # Refresh frame
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
                                # .html suffix is grandfathered in
    if ($get_req =~ /\/control(.html)?$/) {
        return (&html_control, $main::config_parms{html_style_control});
    }
    elsif ($get_req =~ /\/widgets(.html)?$/) {
        return (&tk_widgets, $main::config_parms{html_style_tk});
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
    elsif ($get_req  =~ /\/?list$/) {
        $get_arg =~ /^([^\? ]+)\??(\S*)$/;
        my $category     = $1;
        my $category_arg = $2;
        my $category_name = $1;
        $category_name =~ s/group=//;
        $category_name = &pretty_object_name($category_name);

        my $html = $Authorized_html . "\n";
        $html .= "<h1>Category: $category_name</h1>";
        $html .= &html_list($category, $category_arg);
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

    $h_response =~ tr/+/ /;
    $h_response =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;

    if ($h_response) {
        my ($sub_name, $sub_arg, $sub_ref);
                                # Allow for &sub1 and &sub1(args)
        if ((($sub_name, $sub_arg) = $h_response =~ /^\&(\S+)\((\S+)\)$/) or
            (($sub_name)           = $h_response =~ /^\&(\S+)$/)) {
            print "db hr=$h_response sn=$sub_name sa=$sub_arg\n" if $main::config_parms{debug} eq 'http';
            $sub_ref = \&{$sub_name};
            if (defined &$sub_ref) {
                print "h_response function: &$sub_name('$sub_arg')\n";
                $leave_socket_open_action = "&$sub_name('$sub_arg')";
                $leave_socket_open_passes = 2; # Assume a display or a speak will reset this??
#               my $html = &$sub_ref($sub_arg);
#               print $socket &html_page("", $html);
            }
            else {
                print $socket &html_page("", "Web html function not found: $sub_name");
            }
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

sub tk_widgets {
    
    my $html;
#   my $html = "<BASE TARGET='speech'>";
    $html .= qq[<FORM name="tk_widgets" ACTION="SET_VAR">];


                                # Note: Use a fixed font, so label size does not change with changing letters.
    $html .= qq[<font face="Courier New Bold" ><pre>\n];

    $html_pointer_cnt = 0;

    for my $ptr (@Tk_widgets) {
        my @data = @$ptr;
        my $type = shift @data;
#       print "db tk_widget=$type data=@data\n";
        if ($type eq 'label') {
            $html .= &html_label(@data);
        }
        elsif ($type eq 'entry') {
            $html .= &html_entry(@data);
        }
        elsif ($type eq 'radiobutton') {
            $html .= &html_radiobutton(@data);
        }
        elsif ($type eq 'checkbutton') {
            $html .= &html_checkbutton(@data);
        }
        else {
            print "\n\nUnimplemented html widget: $type\n\n";
        }
    }

                                # Need a submit button, or text form does not respond on Enter :(
    $html .= qq[<center><input type="submit" value="Submit"></center>\n];

    $html .= "</font></pre></form>\n";

    return $html;

}

sub html_last_displayed {
    my ($last_displayed) = &display_log_last(1);

                                # Add breaks on newlines
    $last_displayed =~ s/\n/\n<p>/g;

    return "<h3>Last Displayed Text</h3>$last_displayed";
}

sub html_last_spoken {
    my $h_response;

    if ($Authorized or $main::config_parms{password_protect} !~ /logs/i) {
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
            if (my ($directive) = $_ =~ /--\#\s*include file="(\S+)"/) {
                print "db processing server side directive: $directive\n" if $main::config_parms{debug} eq 'http';
                if (-e ($file = "$main::config_parms{html_dir}/$directive")) {
                    &html_file($socket, $file);
                }
                elsif (my ($html) = &html_mh_generated("/$directive")) {
                    print $socket $html;
                }
                else {
                    print "Error, shtml directive not recognized: $directive\n";
                }
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

sub html_frame_old {
    return <<eof;
HTTP/1.0 200 OK
Content-Type: text/html

<HTML>
<HEAD>
<TITLE>Mister House Control Page</TITLE>
</HEAD>

<FRAMESET Cols="40%,*">
  <FRAME SRC=index NAME="index">
  <FRAMESET Rows="*,150">
    <FRAME SRC=list NAME="list">
    <FRAME SRC=results NAME="results">
  </FRAMESET>
</FRAMESET>

</HTML>
eof
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
<META HTTP-EQUIV=Expires CONTENT="Tue, 01 Jan 1990 00:00:01 GMT">


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

sub html_javascript_reload {
    my ($html_source) = @_;
    return <<eof;
<script language="JavaScript">
<!--
var time = null
function move() {
window.location = '$html_source'
}
//-->
</script>
eof
}
#<body onload="timer=setTimeout('move()',3000)"></body>

sub html_entry {
    my @data = @_;
    my $html;
    for (@data) {
        my $label= shift @data;
        my $pvar = shift @data;
        $html_pointers{++$html_pointer_cnt} = $pvar;
        $html_pointers{$html_pointer_cnt . "_label"} = $label;
        $html .= qq[$label: <INPUT SIZE=10 NAME="$html_pointer_cnt" value="$$pvar">];
                                # This will cause a line break :(
    }
    $html .= "\n";
    return $html;
}

sub html_label {
    my (@data) = @_;
    my $html;
    for my $pvar (@data) {
        $html .= "$$pvar  ";
    }
    $html .= "\n";
    return $html;
}

sub html_checkbutton {
    my (@data) = @_;
    my $html;
    while (@data) {
        my $text= shift @data;
        my $pvar = shift @data;
        $html_pointers{++$html_pointer_cnt} = $pvar;
        my $checked = 'CHECKED' if $$pvar;
#       undef $checked;
        $html .= qq[<INPUT type="checkbox" NAME="$html_pointer_cnt" value="1" $checked onClick="document.tk_widgets.submit()">$text  ];
    }
    $html .= "\n";
    return $html;
}

sub html_radiobutton {
    my ($label, $pvar, $pvalue, $ptext) = @_;
    my $html = "$label:";
    $html_pointers{++$html_pointer_cnt} = $pvar;
    my @text = @$ptext if $ptext;         # Copy, so do not destroy original with shift
    for my $value (@$pvalue) {
        my $text = shift @text;
        $text = $value unless defined $text;
        my $checked = 'CHECKED' if $$pvar eq $value;
        $html .= qq[  <INPUT type="radio" NAME="$html_pointer_cnt" value="$value" $checked onClick="document.tk_widgets.submit()">$text];
    }
    $html .= "\n";
    return $html;
}

sub html_category {
    my $h_index = "<BASE TARGET='control'>";

    $h_index .= "<p>\n";

#   $h_index .= qq[<FORM ACTION="list">\nSearch string: <INPUT SIZE=10 NAME="search">\n</FORM>\n];
    
#   $h_index .= &html_label(\$Tk_objects{label_time});
#   $h_index .= &html_label(\$Tk_objects{label_uptime_cpu});


                # Do other objects by type and alphabetically
#   for my $object_type (&list_object_types) {
    $h_index .= "<h4>By Group</h4>\n";
    for my $group (&list_objects_by_type('Group')) {
        $h_index    .= "<li>" . &html_active_href("list?group=$group", &pretty_object_name($group)) . "</li>";
    }
                # Do objects by file
    $h_index .= "<h1>By Category</h1>\n";
#   for my $file (&list_code_files) {
    for my $category (&list_code_webnames) {
                                # Only list a category if it has commands
        next unless &html_list($category) =~ /RUN/;
        $h_index    .= "<li>" . &html_active_href("list?$category", $category) . "</li>";
    }
    $h_index .= "<h4>By Object Type</h4>\n";
    for my $object_type ('Serial_Item', 'X10_Item', 'X10_Appliance', 'Group') {
        $h_index    .= "<li>" . &html_active_href("list?$object_type", $object_type);
        $h_index    .=          &html_active_href("list?$object_type?state", "(state)") . "</li>";
    }
    $h_index .= "\n";

    return $h_index;
}

#------------------------------------------------------------------------------
# look through web folder for icons to use for status by name, type and status
# returning icon filename.
#------------------------------------------------------------------------------
sub html_find_icon_image {
    my ($object, $object_type) = @_;
    my $object_name  = $object->{object_name};
    my $filename     = $object->{filename};
    my $state_now    = $object->{state};
    my $h_icon = "";

    my $type = lc($object_type);
    $object_name =~ s/\$//g;        # remove $ at front of objects
    $object_name =~ s/^v_//g;       # remove v_ in voice commands

    if ($state_now =~ /^[+-]\d+$/ or $state_now =~ /^\d+$/) {
        $state_now = "dim";
    }

    my $html_dir = "$main::config_parms{html_dir}";
    my $html_icon_dir = "images/";      # hard coded for now

    print "****** html_find_icon_image: object_name = $object_name, type = $type , state_now = $state_now *****\n";
    print "****** html_find_icon_image: html_dir = $html_dir, html_icon_dir = $html_icon_dir *****\n";

    my $t_icon1 = lc($html_icon_dir . $object_name . "-" . $state_now . ".gif");            # images/light-off.gif
    print "****** $t_icon1\n";
    my $t_icon2 = lc($html_icon_dir . $object_name . ".gif");                           # images/light.gif
    print "****** $t_icon2\n";
    my $t_icon3 = lc($html_icon_dir . $type . "-" . $state_now . ".gif");               # images/x10_item-off.gif
    print "****** $t_icon3\n";
    my $t_icon4 = lc($html_icon_dir . $type . ".gif");                                  # images/x10_item.gif
    print "****** $t_icon4\n";
    my $t_icon5 = lc($html_icon_dir . $state_now . ".gif");                             # images/off.gif
    print "****** $t_icon5\n";

    $t_icon1 =~ s/\$//g;
    $t_icon2 =~ s/\$//g;
    $t_icon3 =~ s/\$//g;
    $t_icon4 =~ s/\$//g;
    $t_icon5 =~ s/\$//g;
    
    if (-r ($html_dir . "/" . $t_icon1)) {
        $h_icon = $t_icon1;
    } elsif (-r ($html_dir . "/" . $t_icon2)) {
        $h_icon = $t_icon2;
    } elsif (-r ($html_dir . "/" . $t_icon3)) {
        $h_icon = $t_icon3;
    } elsif (-r ($html_dir . "/" . $t_icon4)) {
        $h_icon = $t_icon4;
    } elsif (-r ($html_dir . "/" . $t_icon5)) {
        $h_icon = $t_icon5;
    } 
    print "****** html_find_icon_image: icon found = $h_icon *****\n" if "$h_icon";
    return "$h_icon";
}

sub html_list {

    my ($object, $object_name, @object_list);
    my($webname_or_object_type, $option) = @_;
    my ($h_temp, $num, $h_ret);

    my $h_list = qq[
        <!-- html_list -->
        <BASE TARGET='speech'>
    ];

    # Do other objects by type and alphabetically
    if ($webname_or_object_type =~ /^group=(\S+)/) {
        $h_list .= "<!-- html_list group -->\n";
        my $object = &get_object_by_name($1);

                                # select box for group itself
#       $h_temp = qq[<table cols=3 width="100%" cellpadding="10" cellspacing="0" border="1" align="center"><tr>\n];
#       $h_list .= $h_temp;
#       $h_list .= &html_object_table($object, $webname_or_object_type);
#       $num=1;
#   leaving group itself out for now

        $num=0;

                                # Sort by filename first, then object name
        for my $group_member (sort {$a->{filename} cmp $b->{filename} or $a->{object_name} cmp $b->{object_name}} list $object) {

            # force new table row
            if ($num ge 3) {
                $h_temp = qq[
                    </tr>
                    </table>
                ];
                $h_list .= $h_temp;
            }

            if ($num ge 3 or $num eq 0) {
                    $h_temp = qq[
                    <center><table cols=1 width="100%" cellpadding="0" cellspacing="0" border="1" align="center">
                        <tr NOSAVE>
                        <td NOSAVE>
                    ];
                    $h_list .= $h_temp;
                    $num=0;
            }
            $num++;

            $h_list .= "\n<td>\n" unless $num eq 1;

            $h_list .= &html_object_table($group_member, $webname_or_object_type);
            $num++;
        }
        $h_temp = qq[
               </tr>
               </table>
               </center>
               </body>
        ];
        $h_list .= $h_temp;
        return $h_list;
    }

    if ($webname_or_object_type =~ /^search=(\S+)/) {
        $h_list .= "<!-- html_list search -->\n";
        my @cmd_list = grep /$1/, &list_voice_cmds_match($1);
        for my $cmd (@cmd_list) {
            my ($file, $cmd2) = $cmd =~ /(.+)\:(.+)/;
            my $cmd3 = $cmd2;
            $cmd3 =~ tr/\_/\~/; # Swizzle _ to ~, so we can use _ for blanks
            $cmd3 =~ tr/ /\_/; # Blanks are not allowed in urls
            $h_list .= "<li><a href='RUN?$cmd3'>$cmd2</a>\n";
        }
        $h_list  .= "\n";
        $h_list .= "<!-- html_list return -->\n";
        return $h_list;
    }

    if (@object_list = &list_objects_by_type($webname_or_object_type)) {
        $h_list .= "<!-- html_list list_objects_by_type = $webname_or_object_type -->\n";
        
                                # Sort by filename first, then object name
        my @objects = map{&get_object_by_name($_)} @object_list;

        $h_list .= &html_type_table(@objects);
        $h_temp = qq[<table border=0 width="100%" cellspacing="2" cellpadding="0">\n<tr align=center>\n];
        $h_list .= $h_temp;
        $num=0;
        for my $object (sort {$a->{filename} cmp $b->{filename} or $a->{object_name} cmp $b->{object_name}} @objects) {
            if ($num ge 4) {
                $h_list .= "</tr>\n\n<tr align=center>\n";
                $num = 0;
            }
            $h_list .= &html_item_state($object,$webname_or_object_type);
            $num++;
        }
        # do this so we don't throw off the table cell sizes if the number of items is not divisable by 4
        while ($num lt 4) {
                $h_temp = qq[<td align="right"></td>];
                $h_list .= $h_temp;
                $h_temp = qq[<td> </td>];
                $h_list .= $h_temp;
                $num++;
        }
        $h_list .= "</tr>\n</table>\n</table>";
        return $h_list;
    }

    if (@object_list = &list_objects_by_webname($webname_or_object_type)) {
        $h_list .= "<!-- html_list list_objects_by_webname -->\n";
        $h_list .= &html_webname_table(@object_list);
    }
    $h_list .= "<!-- html_list return -->\n";
    return $h_list;

}

sub html_webname_table {
    my (@object_list) = @_;
    my $object_name;
    my $list_count = 0;
    my $h_ret;
    my $h_temp;


    my $num=0;
    for $object_name (@object_list) {
        my $object = &get_object_by_name($object_name);
        my $state_now    = $object->{state};
        my $text = $object->{text};
    print "****** text = $text *****\n";
        next unless $text;              # Only do voice items
        my $filename = $object->{filename};
        $list_count++;

                # Pick the first {a,b,c} phrase enumeration
        $text =~ s/\{(.+?),.+?\}/$1/g;

        # force new table row 
        if ($num ge 3) {
            $h_temp = qq[
                </tr>
                </table>
            ];
            $h_ret .= $h_temp;
        }

        if ($num ge 3 or $num eq 0) {
            $h_temp = qq[
                <!-- html_webname_table main level table -->
                <center><table cols=1 width="100%" cellpadding="0" cellspacing="0" border="1" align="center">
                <tr NOSAVE>
                <td NOSAVE>
            ];
            $h_ret .= $h_temp;
            $num=0;
        }
        $num++;

        my ($prefix, $states, $suffix);
        my $multi;
        my $h_text;
        my $text_cmd;
        if (($prefix, $states, $suffix) = $text =~ /^(.*)\[(.+?)\](.*)$/) {
                $h_text = $prefix . "..." . $suffix;
                $text_cmd = "$prefix$state_now$suffix";
                $multi=ON;
        } else {
                $h_text = $text;
                $text_cmd = $text;
                $multi=OFF;
        }
        $text_cmd =~ tr/\~/\_/;    # Blanks are not allowed in urls
        $text_cmd =~ tr/ /\_/;    # Blanks are not allowed in urls
        
        $h_temp = qq[
            <!-- html_webname_table object level table -->
        ];
        $h_ret .= $h_temp;

        $h_ret .= "\n<td>\n" unless $num eq 1;

        $h_temp = qq[
            <table cols=1 width="100%" cellpadding="0" cellspacing="0" border="0" align="center">
            <tr>
              <td>
        ];
        $h_ret .= $h_temp;

        #------------------------------------------------------------
        # icon and object name table
        #------------------------------------------------------------
        my $h_icon_field = "";
        if (my $h_icon = &html_find_icon_image($object,"voice")) {
            $h_temp = qq[<center><font size="+1"><img src="$h_icon" hspace=5 align=center ><b>$h_text</b></font>\n];
        } else {
            $h_temp = qq[<center><font size="+2"><b>$h_text</b></font></center>\n];
        }
        $h_ret .= $h_temp;

        $h_temp = qq[
              </td>
            </tr>
            <tr>
              <td>
        ];
        $h_ret .= $h_temp;

        if ($multi eq ON) {
            #-------------------------------------
            # voice cmds with more than one state
            #-------------------------------------

            # Label of button should have $state_now

            $h_temp = qq[
                <!-- html_webname_table state level table -->
                <FORM action="RUN_ARGS" method="get" target='speech'>
                <table cols=2 width="100%" cellpadding="0" cellspacing="0" border="0" align="center">
                    <tr>
                    <td>
                    <center>
                    <div align=right>
                        <SELECT name="cmd"><option value="$text_cmd">$state_now
            ];
            $h_ret .= $h_temp;

            for my $state (split(',', $states)) {
                my $text_cmd = "$prefix$state$suffix";
                $text_cmd =~ tr/\~/\_/;    # Blanks are not allowed in urls
                $text_cmd =~ tr/ /\_/;    # Blanks are not allowed in urls
                if ($state ne $state_now) {
                    $h_temp = qq[<option value="$text_cmd">$state];
                    $h_ret .= $h_temp;
                }
            }
            $h_temp = qq[
                        </SELECT>
                    </div>
                    </center>
                    </td>
                    <td><input type='submit' border='0' value='Go'></td>
                </tr>
                </table>
            ];
            $h_ret .= $h_temp;


        } else {        
            #-------------------------------------
            # voice cmds with only one state
            #-------------------------------------
            # start form here but close it later
            $h_temp = qq[
                    <FORM action="RUN_ARGS" method="get" target='speech'>
                    <center>
                    <input type=hidden name=cmd value=$text_cmd>
                    <input type='submit' border='0' value='Go'>
                    </center>
            ];
            $h_ret .= $h_temp;
        }

        $h_temp = qq[
              </FORM>
              </td>
            </tr>
        ];
        $h_ret .= $h_temp;

        my $h_last = (state_log $object)[0];
#       my $h_last = "";
#       print "db o=$object $h_last\n";
        

        $h_temp = qq[
            <tr>
              <td>
                <center>Last change: $h_last</center>
              </td>
            </tr>
        ];
        $h_ret .= $h_temp;

        $h_temp = qq[
            <!-- html_webname_table CLOSE object level table -->
            </table>
            </td>
        ];
        $h_ret .= $h_temp;

    }
    $h_temp = qq[
        </tr>
        </table>
        </center>
        </body>
    ];
    $h_ret .= $h_temp;
    return "$h_ret";
}

sub html_type_table {
   my (@objects) = @_;
   my $h_temp = qq[
        <!-- html_type_table -->
        <td valign="top">
        <FORM action="SET_ARGS" method="get" target='speech'>
        <div align="center"><center><p>
        <input type='button' value=' Update Status ' onClick='history.go(0)'>
        <SELECT name="item">
        <option value="">Select item];
   my $h_ret = $h_temp;
   for my $object (sort {$a->{filename} cmp $b->{filename} or $a->{object_name} cmp $b->{object_name}} @objects) {
        my $object_name  = $object->{object_name};
        my $object_name2 = &pretty_object_name($object_name);
        my $h_temp = qq[
            <option value="$object_name">$object_name2];
        $h_ret .= $h_temp;
   }
   $h_temp = qq[ 
        </SELECT>
        <input type="submit" value="on" name="state">
        <input type="submit" value="off" name="state">
    ];
    $h_ret .= $h_temp;
#   $h_ret .= &html_dim_option if $object_type =~ /x10_item/i;
   $h_ret .= &html_dim_option;
   $h_temp = qq[
        </center></div>
        </form>
        <!-- html_type_table return -->
    ];
   $h_ret .= $h_temp;
   return "$h_ret";
}

sub html_dim_option {
    my $h_temp = qq[
        <SELECT name="dim" border=1>
            <option value="">No Dim
            <option value="-25">-25%
            <option value="-50">-50%
            <option value="-75">-75%
            <option value="+25">+25%
            <option value="+50">+50%
            <option value="+75">+75%
            <option value="brighten">Brighten
            <option value="darken">Darken
        </SELECT>
        <input type="submit" border="0" value="Dim">
    ];
    return $h_temp;
}


sub html_select_object {
    my ($object) = @_; 
    my $object_name  = $object->{object_name};
    my $object_name2 = &pretty_object_name($object_name);
    my $ret;
 
    $ret= qq[<option value="$object_name">$object_name2];
    return $ret;
}

                                # List current object state
sub html_item_state {
    my ($object, $object_type) = @_;
    my $object_name  = $object->{object_name};
    my $filename     = $object->{filename};
    my $state_now    = $object->{state};
    my $object_name2 = &pretty_object_name($object_name);
    my $h_icon_field = "";
    my $h_ret;

    #
    # find icon to show state, if not found show state_now in text.
    #
    if (my $h_icon = &html_find_icon_image($object,$object_type)) {
        $h_ret = qq[<td align="right"><img src="/$h_icon" alt="$h_icon" > </td>\n];
    } else {
        $h_ret = qq[<td align="right">$state_now</td>\n];
    }

    my $h_temp .= qq[<td align="left"><b>$object_name2:   </b></td>\n];
    $h_ret .= $h_temp;

    return "$h_ret";
}

                                # List all possible object states
sub html_object_table {
    my ($object, $object_type) = @_;
    my $object_name  = $object->{object_name};
    my $filename     = $object->{filename};
    my $state_now    = $object->{state};
    my $object_name2 = &pretty_object_name($object_name);
    my $h_icon_field = "";
    my $h_object;
    my $count_states;
    my ($h_temp, $h_ret);


    $h_temp = qq[
        <table cols=1 width="100%" cellpadding="0" cellspacing="0" border="0" align="center">
        <tr>
        <td>
    ];
    $h_ret .= $h_temp;
    #------------------------------------------------------------
    # icon and object name table
    #------------------------------------------------------------
    my $h_icon_field = "";
    if (my $h_icon = &html_find_icon_image($object,"voice")) {
        $h_temp = qq[<center><font size="+1"><img src="$h_icon" hspace=5 align=center ><b>$object_name2</b></font>\n];
    } else {
        $h_temp = qq[<center><font size="+2"><b>$object_name2</b></font></center>\n];
    }
    $h_ret .= $h_temp;

    $h_temp = qq[
        </td>
        </tr>
        <tr>
        <td>
    ];
    $h_ret .= $h_temp;

    $h_temp = qq[
        <!-- html_webname_table state level table -->
        <FORM action="SET_ARGS" method="get" target='speech'>
        <table cols=2 width="100%" cellpadding="0" cellspacing="0" border="0" align="center">
            <tr>
            <td>
                <center>
                <div align=right>
                <SELECT name="state">
                <input type=hidden name=item value='$object_name'>
                <option value="$state_now">$state_now
    ];
    $h_ret .= $h_temp;


#   if ($object->{states}) {
        for my $state (@{$object->{states}}) {
            next unless $state;                 # Skip items with non-named states
            next if $state =~ /^[+-]\d+$/ and $state % 20; # Skip most X10 dim levels
            next if $state eq $state_now;
            $count_states++;
            $h_temp = qq[<option value="$state">$state];
            $h_ret .= $h_temp;
        }
        $h_temp = qq[
            </SELECT>
            </div>
            </center>
            </td>
            <td><input type='submit' border='0' value='Go'></td>
            </tr>
            </table>
        ];
        $h_ret .= $h_temp;

        $h_temp = qq[
            </FORM>
            </td>
            </tr>
        ];
        $h_ret .= $h_temp;

        my $h_last = (state_log $object)[0];

        $h_temp = qq[
                        <tr>
                          <td>
                        <center>Last change: $h_last</center>
                          </td>
                        </tr>
        ];
        $h_ret .= $h_temp;

        $h_temp = qq[
                <!-- html_webname_table CLOSE object level table -->
                </table>
                </td>
        ];
        $h_ret .= $h_temp;

#   }
    return "$h_ret";

}

sub html_active_href {
    my($url, $text) = @_;
    return <<eof;
    <a href=$url>
    <SPAN onMouseOver="this.className='over';"
    onMouseOut="this.className='out';" 
    style="cursor: hand"
        class="blue">$text</SPAN></a>
eof
}

sub pretty_object_name {
    my ($name) = @_;
    $name = substr($name, 1) if substr($name, 0, 1) eq '$';
    $name =~ tr/_/ /;
    $name = ucfirst $name;
    return $name;
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
