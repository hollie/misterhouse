# Category=Internet

# $Date$
# $Revision
#
#@ This module allows MisterHouse to connect to AOL Instant Messenger,
#@ MSN Messenger (currently broken due to a MS change in protocols), and/or Jabber.
#@ Once connected, you can type any normal mh commands.  You can also type
#@  find: xyz to search for command xyz, or
#@  log: xyz to start sending log data with filter xyz.
#@  Example filters are print, speak, play, speak|play, all, and stop (to stop).
#@ To Authorize commands, either use the logon command from your aim client
#@ or set the mh.ini password_allow_im to a list of your aim ids
#@ (e.g. password_allow_im = joe@jabber.com/Jabber Instant Messenger, joe@hotmail.com, joe )

=begin comment

Set these mh.ini parms:

   net_aim_name=
   net_aim=password=
   net_aim_name_send=

   net_icq_name=
   net_icq_password=
   net_icq_name_send=

   net_msn_name=
   net_msn_password=
   net_msn_name_send=

   net_jabber_name=
   net_jabber_password=
   net_jabber_server=     (e.g. jabber.com)
   net_jabber_resource=   (optional)
   net_jabber_name_send=

The code libs for AOL and MSN are included in mh.

Jabber is an open, XML based protocol for instant messaging.
You can get free IDs and client for various platforms at
  http://jabbercentral.com or http://www.jabber.com .

Jabber requires perl 5.6+ (for Unicode support) and these modules from CPAN:
  Net::Jabber
  XML::Stream

If on Windows, you can get these from ActiveState with these commands:

 cd /perl/bin
 perl ppm.bat install Net-Jabber
 perl ppm.bat install XML-Stream

If on Linux (or the above does not work on Windows) try:

 perl -MCPAN -eshell     then     install Net::Jabber

=cut

$v_im_test = new Voice_Cmd 'Send [AOL,ICQ,MSN,jabber] test message';
$v_im_test->set_info(
    'Send a test message to the default AOL, ICQ, MSN, or jabber address');

if ( $state = said $v_im_test) {
    my $msg = "MisterHouse has been up for $Tk_objects{label_uptime_cpu}";

    #   respond "app=aol Sending test message to AOL...";
    net_im_send( text => $msg, pgm => $state );
}

$v_im_signon = new Voice_Cmd 'Connect to [AOL,ICQ,MSN,jabber]';
$v_im_signon->set_info(
    'Disconnect, then re-Connect to the specified im servers');
if ( $state = said $v_im_signon) {
    if ( $state eq 'AOL' and $oscar::aim_connected ) {
        &net_im_signoff($state);
        print "****TEST****Disconnecting...\n";
    }
    elsif ( $state eq 'ICQ' and $oscar::icq_connected ) {
        &net_im_signoff($state);
    }

    &net_im_signon( undef, undef, $state );

}

$v_im_signoff = new Voice_Cmd 'Disconnect from [AOL,ICQ,MSN,jabber]';
$v_im_signoff->set_info('Disconnect from the specified im servers');
if ( $state = said $v_im_signoff) {
    &net_im_signoff($state);
}

$v_im_logdata1 = new Voice_Cmd 'Start sending log data to [AOL,ICQ,MSN,jabber]';
$v_im_logdata1->set_info(
    'Start sending print log entries and speech to the default IM user');
$v_im_logdata2 = new Voice_Cmd 'Stop sending log data to [AOL,ICQ,MSN,jabber]';
$v_im_logdata2->set_info(
    'Stop sending print log entries and speech to the default IM user');

$log_to_im_list{"$state default"} = 'all' if $state = said $v_im_logdata1;
delete $log_to_im_list{"$state default"} if $state = said $v_im_logdata2;

# Reload hooks and INI parameters on reload
my %im_data;
if ($Reload) {
    &AOLim_Message_add_hook( \&im_message );
    &MSNim_Message_add_hook( \&im_message );
    &Jabber_Message_add_hook( \&im_message );
    &ICQim_Message_add_hook( \&im_message );

    &AOLim_Status_add_hook( \&im_status );
    &MSNim_Status_add_hook( \&im_status );
    &Jabber_Presence_add_hook( \&im_status );
    &ICQim_Status_add_hook( \&im_status );

    # Allow for auto-connect on startup (otherwise connects only when sending)
    if ($Startup) {
        &net_im_signon( undef, undef, 'aim' )
          if $config_parms{net_aim_autoconnect};
        &net_im_signon( undef, undef, 'msn' )
          if $config_parms{net_msn_autoconnect};
        &net_im_signon( undef, undef, 'icq' )
          if $config_parms{net_icq_autoconnect};
        &net_im_signon( undef, undef, 'jabber' )
          if $config_parms{net_jabber_autoconnect};
    }

    &Log_add_hook( \&im_log );

    # Configured users are allowed to have authority without logging in

    for my $user ( split /[,]+/, $config_parms{password_allow_im} ) {
        $user =~ s/^ +//;
        $user =~ s/ +$//;    # Drop leading/trailing blanks
        $im_data{password_allow}{$user}++;
        print "Setting im password_allow user: $user.\n" if $main::Debug{im};
    }
}

# Code all the various code hooks
use vars '%log_to_im_list';

sub im_log {
    my ( $log_source, $text, %parms ) = @_;
    return if $parms{no_im} or !$text;
    $text = "$log_source: $text";
    while ( my ( $to, $filter ) = each %log_to_im_list ) {

        #       print "db im_log to=$to filter=$filter s=$log_source text=$text\n";
        next unless $filter eq 'all' or $text =~ /$filter/;
        my ( $pgm, $user ) = $to =~ /(\S+) ?(.*)/;
        net_im_send( text => $text, pgm => $pgm, to => $user );
    }
}

sub im_status {
    my ( $user, $status, $status_old, $pgm ) = @_;
    my $msg = '';
    $msg = "changed from $status_old to $status" if $status ne $status_old;
    $msg = "is now $status" unless $status_old;
    print_log "$pgm IM: $user $msg" if $msg ne "";
    &net_im_process_queue( $pgm, $user )
      if $status eq "on" and $config_parms{net_queue_im};
}

sub im_message {
    my ( $from, $text, $pgm ) = @_;

    my ($ref) = &Voice_Cmd::voice_item_by_text( lc($text) );
    my $authority = $ref->get_authority if $ref;

    $authority = $Password_Allow{$text} unless $authority;

    if ( $text eq "" ) {
        print "IM: received empty text, discarding\n" if $main::Debug{im};
        return;
    }

    print
      "IM: RUN a=$authority,$im_data{password_allow}{$from} from=$from text=$text\n"
      if $main::Debug{im};
    return if $text =~ /^i\'m away/i;
    return if $text =~ /^Sorry, I ran out for a bit/i;
    return if $text =~ /^I am currently away from the computer/i;
    return
      if $from =~ /AOL System Msg/i
      ;    # Fix for AOL: bot to bot infinite loop - stops replies to AOL's bot.

    my ($im_sessionless_from) = $from =~ m/^(.*@.*\/.*)\w{8}$/;

    my $msg;
    if ( $text =~ /^(login|logon): *(\S*)$/i ) {
        if ( $im_data{password_allow}{$from} ) {

            # *** What about the three different levels?
            $msg =
              "You have $im_data{password_allow}{$from} access, so there is no need to login!";
        }
        else {
            if ( my $user = password_check $2) {
                run_after_delay 120, "&im_logoff('$pgm', '$from')";
                $im_data{password_allow_temp}{$from} = $user;
                $msg =
                  "$user login accepted. You will be logged out in 2 minutes.";
                $msg .=
                  "\nRun set_password to create a password.  Global authorization enabled until then"
                  unless -e $config_parms{password_file};
            }
            else {
                $msg = 'Invalid Password';
            }
        }
    }
    elsif ( $text =~ /^(logout|logoff)$/ ) {
        if ( $im_data{password_allow}{$from} ) {
            $msg = 'You are not logged in.';
        }
        if ( $im_data{password_allow_temp}{$from} ) {
            $im_data{password_allow_temp}{$from} = 0;
            $msg = 'You have been logged out';
        }
        else {
            $msg = 'You are not logged in.';
        }
    }
    elsif ( $text =~ /^find:(.+)/ ) {
        my $search = $1;
        $search =~ s/^ +//;
        $search =~ s/ +$//;
        my @cmds = list_voice_cmds_match $search;
        my @cmds2;
        for my $cmd (@cmds) {
            if (   $im_data{password_allow}{$from}
                or $im_data{password_allow_temp}{$from} )
            {    #if access is given in mh.ini parms, then don't check authority
                push @cmds2, $cmd;
            }
            else {
                $cmd =~ s/^[^:]+: //
                  ; #Trim the category ("Other: ", etc) from the front of the command
                $cmd =~ s/\s*$//;
                my ($ref) = &Voice_Cmd::voice_item_by_text( lc($cmd) );
                $authority = $ref->get_authority if $ref;
                push @cmds2, $cmd
                  if lc $authority eq 'im'
                  or lc $authority eq 'anyone';
            }
        }
        $msg =
          "Found " . scalar(@cmds2) . " commands that matched \"$search\":\n  ";
        $msg .= join( "\n  ", @cmds2 );
    }
    elsif ( $text =~ /^help/ ) {
        $msg = "Type any of the following:\n";
        $msg .= "  find item:  xyz  => finds objects that match xyz\n";
        $msg .= "  find:  xyz  => finds commands that match xyz\n";
        $msg .= "  speak:  xyz  => speaks text xyz\n";
        $msg .= "  display:  xyz  => speaks text xyz\n";
        $msg .= "  set: xyz state => set object xyz to state\n";
        $msg .=
          "  log: xyz  => xyz is a filter of what to log. (print, speak, play, speak|play, all, and stop)\n"
          if ( $im_data{password_allow}{$from}
            or $im_data{password_allow_temp}{$from} );
        $msg .=
          "  var: abc xyz => abc is a variable, hash or reference, xyz element in hash or hash reference to show\n";
        $msg .= "  logon: xyz  => logon with password xyz\n";
        $msg .=
          "  send sname:  xyz  => sname is a Screenname to send a message to, and xyz is the text to send. Can only send using current IM program\n"
          if ( $im_data{password_allow}{$from}
            or $im_data{password_allow_temp}{$from} );
        $msg .= "  any valid MisterHouse command(e.g. What time is it)\n";
    }
    elsif ($authority eq 'anyone'
        or $im_data{password_allow}{$from}
        or $im_data{password_allow_temp}{$from}
        or $im_data{password_allow}{$im_sessionless_from} )
    {
        if (    $authority eq 'admin'
            and $im_data{password_allow_temp}{$from} ne 'admin' )
        {
            $msg = "Admin logon required";
        }
        elsif ( $text =~ /^var:\s+(.+)$/i ) {
            no strict 'refs';
            my ( $var, $key ) = split( /\s+/, $1 );
            my $refType = ref( ${$var} );
            if ( $key eq '' ) {
                if ( $refType eq '' ) {
                    $msg = "\$$var = $$var";
                }
                else {
                    if ( $refType eq 'SCALAR' ) {
                        $msg = "\\$$$var = ${${$var}}";
                    }
                    else {
                        $msg =
                          "Error, \$$var is not a scalar reference, it is a $refType reference.  I need a second parameter";
                    }
                }
            }
            else {
                if ( $refType eq '' ) {    # this is a simple hash
                    $msg = '$' . $var . '{' . $key . '} = ' . ${$var}{$key};
                }
                else
                {    # this is a reference, assuming a hash or object reference
                    $msg = '$' . $var . '->{' . $key . '} = ' . ${$var}->{$key};
                }
            }
        }
        elsif ( $text =~ /^log: (.+)$/i ) {
            if ( lc $1 eq 'stop' ) {
                delete $log_to_im_list{"$pgm $from"};
            }
            else {
                $log_to_im_list{"$pgm $from"} = lc $1;
            }
            print_log "$pgm IM: logging $1 for $from";
        }
        elsif ( $text =~ /^send (.+):(.+)$/i ) {
            if ( $2 eq '' ) {
                $msg = "Cannot send a blank message.";
            }
            else {
                &net_im_send( pgm => $pgm, to => $1, text => $2 );
                $msg = "Message sent to $1";
            }
        }

        elsif ( $text =~ /^set:(.+)/ ) {
            my $cmdstring = $1;
            my $flag      = 0;

            # Strip leading/trailing whitespace
            $cmdstring =~ s/^\s+//;
            $cmdstring =~ s/\s+$//;
            my @command = split( / /, $cmdstring );

            # check each of the following object classes for matching object name
            for my $objectclass ( 'X10_Item', 'X10_Appliance', 'Serial_Item',
                'Group' )
            {
                for my $name ( &list_objects_by_type($objectclass) ) {

                    # compare lowercase to make case-insensitive
                    if ( lc($name) eq lc( '$' . $command[0] ) ) {

                        # found a valid object name! get a ref to the object
                        my $object = &get_object_by_name($name);

                        # Check if the requested state is valid...
                        foreach my $validstate ( $object->get_states() ) {
                            if ( $command[1] eq $validstate ) {

                                # valid object name, valid state request
                                # so do it!
                                $flag = 1;
                                set $object $command[1];
                                $msg =
                                  $command[0] . " set to " . $command[1] . "\n";

                                # break out since we're done
                                last;
                            }
                        }
                        if ( !$flag ) {

                            # oops...invalid state requested, let them know
                            $msg =
                                $command[1]
                              . " is not a valid state for "
                              . $command[0] . "\n";

                            # set the flag so we'll stop searching because
                            # we already matched the object name
                            $flag = 1;
                        }

                        # break out of the loop since we matched an object name
                        last;
                    }
                }
                last if $flag;
            }
            if ( !$flag ) {
                $msg = "object " . $command[0] . " not found!\n";
            }
        }
        elsif ( $text =~ /^find\x20item:(.+)/ ) {
            $msg = "Matching commands: \n";
            my $cmdstring = $1;

            # Strip leading/trailing whitespace
            $cmdstring =~ s/^\s+//;
            $cmdstring =~ s/\s+$//;

            # check each of the following object classes for matching object name
            for my $objectclass ( 'X10_Item', 'X10_Appliance', 'Serial_Item',
                'Group' )
            {
                for my $name ( &list_objects_by_type($objectclass) ) {

                    # compare lowercase to make case-insensitive
                    if ( $name =~ m/$cmdstring/i ) {

                        # strip off the leading '$' character
                        $msg .= substr( $name, 1 ) . "\n";
                    }
                }
            }
            if ( !$msg ) {
                $msg = "No matches found.\n";
            }
        }
        elsif ( $text =~ /^speak:(.+)/ ) {
            my $speechtext = $1;
            speak "app=im $speechtext";
            $msg = "I said: $speechtext";
        }
        elsif ( $text =~ /^alphadisplay:(.+)/ ) {
            my $displaytext = $1;
            display "app=im device=alpha $displaytext";
            $msg = "I displayed: $displaytext";
        }
        elsif ( $text =~ /^display:(.+)/ ) {
            my $displaytext = $1;
            display "app=im $displaytext";
            $msg = "I displayed: $displaytext";
        }

        # *** Need to convert unmatched command to a find...
        # RespondTarget is deprecated, use set_by to respond to the correct program/user
        elsif (
            &process_external_command(
                $text, 1,
                "im [$pgm,$from]",
                "im pgm=$pgm to=$from"
            )
          )
        {
        }
        else {

            use vars '$eliza_rule'
              ;    # in case eliza_server common code module is not loaded

            my $rule;

            $rule = $config_parms{im_chatbot};

            if ( !$rule and ref $eliza_rule ) {
                $rule = $eliza_rule->{state};
            }

            if ( $rule and $rule ne 'none' )
            {      # allow short-circuit of chatbot via config parm or widget
                my $eliza = new Chatbot::Eliza "Eliza",
                  "../data/eliza/$rule.txt";
                $msg = $eliza->transform($text);
            }
            else {
                $msg = "I don't understand.  Type 'help' to get started...";
            }
        }
    }
    else {
        $msg = "$from: You are not authorized to run this command!";
    }

    print_log "$pgm IM: $from: $text" . ( ($msg) ? " ($msg)" : '' );

    # respond if there is an immediate response (commands respond on their own)

    &net_im_send( pgm => $pgm, to => $from, text => $msg ) if $msg;

}

sub im_logoff {
    my ( $pgm, $screenname ) = @_;
    if ( $im_data{password_allow_temp}{$screenname} ) {
        $im_data{password_allow_temp}{$screenname} = 0;
        &net_im_send(
            pgm  => $pgm,
            to   => $screenname,
            text => 'Your session has expired and you have been logged out.'
        );
    }
}

sub im_message_window_closing {

}

sub im_message_window_saving {
    my $p_win = shift;

    my $msg = $$p_win{t1}->get( '0.0', 'end' );
    chomp $msg;    # stupid tk entry widget appends a CR

    if ($msg) {
        &net_im_send( text => $msg, to => undef );
        return 0;
    }
    else {
        display('app=im time=0 Enter a message to send.');
        return 1;
    }
}

# *** Change OK to Send and add "pgm" and "to" fields

sub open_im_message_window {
    my %parms = @_;
    $parms{title}       = "Send IM";
    $parms{app}         = "im";
    $parms{text}        = "Hi!";
    $parms{window_name} = "message";
    $parms{buttons}     = 2;
    $parms{help}        = 'Enter a message to send to the default IM account.';
    my $w_window = &load_child_window(%parms);

    if ( defined $w_window ) {
        unless ( $w_window->{activated} ) {
            $w_window->activate();
            $w_window->{t1}->focus();
        }
        return $w_window;
    }
}

&register_custom_window( 'im', 'message', 1 ) if $Reload;

