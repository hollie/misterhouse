# Category = MisterHouse

# $Date$
# $Revision$

#@ This module allows you to access MisterHouse via telnet. You'll
#@ need to set the server_telnet_port in your mh.private.ini file.
#@ If you set server_telnet_port to 23 (the standard telnet port),
#@ you can run:   telnet localhost
#@ If you have a real telnet server run (like on linux), you will
#@ want to use a different port (e.g. 1234):   telnet localhost 1234
#@ This code is a good example of how to use mh as a socket_server.

# set the banners
# noloop=start
$config_parms{telnet_welcome_banner} =
  "Welcome to Mister House Socket Port 1!  Type exit/quit/bye/ctrl-D to exit."
  unless $config_parms{telnet_welcome_banner};
$config_parms{telnet_exit_banner} =
  "Bye for now.  Y'all come back now, ya hear!"
  unless $config_parms{telnet_exit_banner};

# noloop=stop

# Examples on how to read and write data to a tcp socket port
$telnet_server = new Socket_Item( $config_parms{telnet_welcome_banner} . "\n\r",
    'Welcome1', 'server_telnet' );
$telnet_server->add( "Hi, thanks for dropping by!\n\r",          'hi' );
$telnet_server->add( $config_parms{telnet_exit_banner} . "\n\r", 'bye' );
$telnet_server->add( "\n\r",                                     'cr' );
$telnet_server->add( "\rmh> ",                                   'prompt' );
$telnet_server->add( "\rmh# ", 'prompt_admin' );

#$telnet_server ->add             ("\rmh $Time_Now> ", 'prompt');

# To avoid CR on set, so we can have a prompt
#$Socket_Ports{'server_telnet'}{datatype} = 'rawout' if $Startup;
#$Socket_Ports{'server_telnet'}{datatype} = 'raw' if $Startup;

# Authorize user with password
use vars '%telnet_flags';
my $response_loop_telnet;
if ( active_now $telnet_server) {
    set $telnet_server 'Welcome1';
    set_echo $telnet_server 0;
    my $client_ip = $Socket_Ports{server_telnet}{client_ip_address};
    my $client    = $Socket_Ports{server_telnet}{socka};
    $telnet_flags{$client}{auth}      = 0;
    $telnet_flags{$client}{auth_orig} = 0;

    # This will return false if the telnet ip is not in the password_allow_clients list
    if ( my $user = password_check undef, 'server_telnet' ) {
        if ( -e $config_parms{password_file} ) {
            set $telnet_server 'Authorized by IP address match.';
        }
        else {
            set $telnet_server
              'Run set_password to create a password.  Global authorization enabled until then';
        }
        set $telnet_server 'cr';
        $telnet_flags{$client}{auth}      = $user;
        $telnet_flags{$client}{auth_orig} = $user;
        print_log "Telnet: connection from $user\@$client_ip ($client)";
    }
    else {
        print_log "Telnet: connection from $client_ip ($client)";
        set $telnet_server
          'Type "login" to authenticate. Type "help" for a quick list of options.';
        set $telnet_server 'cr';
    }
    set $telnet_server 'cr';
    set $telnet_server ( $telnet_flags{$client}{auth} eq "admin" )
      ? 'prompt_admin'
      : 'prompt';
}

if ( inactive_now $telnet_server) {
    my $client_ip = $Socket_Ports{server_telnet}{client_ip_address};
    my $client    = $Socket_Ports{server_telnet}{socka};
    $telnet_flags{$client}{auth}      = 0;
    $telnet_flags{$client}{auth_orig} = 0;
    $telnet_flags{$client}{data}      = '';
    delete $log_to_telnet_list{"$client"};
    print_log "Telnet: session closed from $client_ip";
}

# Code all the various code hooks
use vars '%log_to_telnet_list';

sub telnet_log {
    my ( $log_source, $text, %parms ) = @_;
    return if $parms{no_im} or !$text;
    $text = "$log_source: $text";
    while ( my ( $to, $filter ) = each %log_to_telnet_list ) {

        #       print "db telnet_log to=$to filter=$filter s=$log_source text=$text\n";
        next unless $filter eq 'all' or $text =~ /$filter/;
        set $telnet_server $text, $to;
        set $telnet_server 'cr';
    }
}
if ($Reload) {
    &Log_add_hook( \&telnet_log );
}

# You can also write text directly out, not using a pre-defined item state
#set $telnet_server "The time is $Time_Now" if $New_Minute and active $telnet_server;

$v_telnet_client_set = new Voice_Cmd 'Run telnet set test [1,2,3,4,5]';

if ( said $v_telnet_client_set) {
    my $state = $v_telnet_client_set->{state};
    $v_telnet_client_set->respond("Running telnet test $state...");

    set $telnet_server "Test telnet set $state" if $state == 1;
    set $telnet_server "Test telnet set $state", 'all'       if $state == 2;
    set $telnet_server "Test telnet set $state", 0           if $state == 3;
    set $telnet_server "Test telnet set $state", 1           if $state == 4;
    set $telnet_server "Test telnet set $state", '127.0.0.1' if $state == 5;
}

# Read from the port, then write to it based on what was sent, if authorized
my $reponse_loop_telnet = 0;

#if (my $data = $Socket_Ports{server_telnet}{data_record}) {

#my $data='';

my $datapart;
if ( defined( $datapart = said $telnet_server) ) {

    my $client_ip = $Socket_Ports{server_telnet}{client_ip_address};
    my $client    = $Socket_Ports{server_telnet}{socka};

    $telnet_flags{$client}{data} .= $datapart;

    if ( $datapart =~ /\r\n?$/i ) {
        my $msg = '';

        # print ("command was ".join(' ',unpack('C*',$telnet_flags{$client}{data}))."\n");
        $telnet_flags{$client}{data} =~ s/ *\r\n?$//;

        # remove telnet command strings
        # These are used by a telnet client to negotiate certain parameters
        # It would be best to interpret them and respond in kind
        # but it is simpler to just ignore them :-)

        $telnet_flags{$client}{data} =~ s/\xff\xfa.+?\xff\xf0//g;
        $telnet_flags{$client}{data} =~ s/\xff(\xfb|\xfc|\xfd|\xfe).//g;

        # print ("command is now ".join(' ',unpack('C*',$telnet_flags{$client}{data}))."\n");

        if ( $telnet_flags{$client}{auth} eq 'set_password' ) {
            print_log "Telnet: password data: $telnet_flags{$client}{data}";
            if ( my $user = password_check $telnet_flags{$client}{data},
                'server_telnet' )
            {
                print_log
                  "Telnet: session authorized for $user from $client_ip";
                $msg = "$user password accepted\r\n";
                $telnet_flags{$client}{auth} = $user;
            }
            else {
                print_log
                  "Telnet: password bad: password=$telnet_flags{$client}{data}";
                $msg = "password bad\r\n";
                $telnet_flags{$client}{auth} = 0;
            }
            set_echo $telnet_server 0;
        }
        elsif ( $telnet_flags{$client}{data} ne '' ) {

            print_log
              "Telnet: port data ($client): $telnet_flags{$client}{data}";

            if ( $telnet_flags{$client}{data} =~ /^log[io]n/i ) {
                $msg = "Enter Password: ";
                $telnet_flags{$client}{auth} = 'set_password';
                set_echo $telnet_server '*';
            }
            elsif ( $telnet_flags{$client}{data} =~ /^(help|\?)/ ) {
                $msg = "Type any of the following:\n\r";
                $msg .= "  logon       => logon with password\n\r"
                  if !$telnet_flags{$client}{auth}
                  && !&password_check( undef, 'server_telnet' );
                $msg .=
                  "  find:  xyz  => find and report commands that match xyz\n\r";
                $msg .=
                  "  log:   xyz  => xyz is a filter of what to log.  Can print, speak, play, speak|play, all, and stop\n\r";
                $msg .= "  whoami:     => display currently logged in user\n\r";
                $msg .=
                  "  exit|bye:   => exit from admin or family mode, or close telnet connection\n\r";
                $msg .= "  help|?:     => this help text\n\r";
                $msg .=
                  "  any valid MisterHouse voice command (e.g. What time is it)\n\r";
            }
            elsif ( $telnet_flags{$client}{data} =~ /^find:(.+)/ ) {
                my $search = $1;
                $search =~ s/^\s*(.*?)\s*$/$1/
                  ;    # remove any whitespace before and after the search term
                my @cmds = list_voice_cmds_match $search;
                my @cmds2;
                for my $cmd (@cmds) {
                    if ( $telnet_flags{$client}{auth} )
                    { #if access is given in mh.ini parms, then don't check authority
                        push @cmds2, $cmd;
                    }
                    else {
                        $cmd =~ s/^[^:]+: //
                          ; #Trim the category ("Other: ", etc) from the front of the command
                        $cmd =~ s/\s*$//;
                        my ($ref) = &Voice_Cmd::voice_item_by_text( lc($cmd) );
                        my $authority = $ref->get_authority if $ref;
                        push @cmds2, $cmd
                          if lc $authority eq 'telnet'
                          or lc $authority eq 'anyone';
                    }
                }
                $msg =
                    "Found "
                  . scalar(@cmds2)
                  . " commands that matched \"$search\":\n\r  ";
                $msg .= join( "\n\r  ", @cmds2 );
                $msg .= "\n\r";
            }

            elsif ( $telnet_flags{$client}{data} =~ /^log: (.+)$/i ) {
                if ( lc $1 eq 'stop' ) {
                    delete $log_to_telnet_list{"$client"};
                }
                else {
                    $log_to_telnet_list{"$client"} = lc $1;
                }
                print_log "Telnet: logging $1 to $client_ip";
            }

            elsif ( lc( $telnet_flags{$client}{data} ) eq 'whoami' ) {
                my $whoami = $telnet_flags{$client}{auth};
                $whoami = "guest" if $whoami eq 0;
                set $telnet_server $whoami . "\n\r";
            }
            elsif ( lc( $telnet_flags{$client}{data} ) eq 'hi' ) {
                set $telnet_server 'hi';
            }
            elsif (lc( $telnet_flags{$client}{data} ) eq 'exit'
                || lc( $telnet_flags{$client}{data} ) eq 'bye'
                || lc( $telnet_flags{$client}{data} ) eq 'quit'
                || $telnet_flags{$client}{data} eq "\x04" )
            {
                if ( $telnet_flags{$client}{auth} eq
                    $telnet_flags{$client}{auth_orig} )
                {
                    set $telnet_server 'bye';
                    sleep 1;
                    stop $telnet_server;
                }
                elsif ( $telnet_flags{$client}{auth} eq "admin" ) {
                    $telnet_flags{$client}{auth} =
                      $telnet_flags{$client}{auth_orig};
                    print_log
                      "Telnet: user from $client_ip has exited from admin back to $telnet_flags{$client}{auth}";
                }
                elsif ( $telnet_flags{$client}{auth} eq "family" ) {
                    $telnet_flags{$client}{auth} =
                      $telnet_flags{$client}{auth_orig};
                    print_log
                      "Telnet: user from $client_ip has exited from family back to $telnet_flags{$client}{auth}";
                }
            }
            else {
                # This will allow us to type in any command
                my ($ref) = &Voice_Cmd::voice_item_by_text(
                    lc( $telnet_flags{$client}{data} ) );
                my $authority = $ref->get_authority if $ref;

                #set $telnet_server "You said: '$telnet_flags{$client}{data}'\n\r";
                #               my $respond = "object_set name=telnet_server arg1='$client'";
                my $respond = "telnet client='$client'";
                if ( $telnet_flags{$client}{auth} || $authority eq 'anyone' ) {
                    if (    $authority eq 'admin'
                        and $telnet_flags{$client}{auth} ne 'admin' )
                    {
                        $msg =
                          "Admin logon required for '$telnet_flags{$client}{data}'";
                    }
                    elsif (
                        &process_external_command(
                            $telnet_flags{$client}{data}, 0,
                            "telnet [$client_ip]"
                        )
                      )
                    {
                        #                   elsif (&process_external_command($telnet_flags{$client}{data}, 0, 'telnet', $respond)) {
                        $msg =
                          "Command executed: \"$telnet_flags{$client}{data}\"\n\r";
                        $response_loop_telnet = $Loop_Count +
                          4; # Give us 4 passes to wait for any resulting speech
                    }
                    else {
                        $msg =
                          "Searching for cmd: $telnet_flags{$client}{data}.\n\r";
                        set $search_command_string $telnet_flags{$client}{data},
                          "telnet [$client_ip]";

                        #                        set $search_command_string $telnet_flags{$client}{data}, 'telnet', $respond;
                    }

                    #                    else {
                    #                        $msg = "Command not recognized: \"$telnet_flags{$client}{data}\"\n\r";
                    #                    }
                }
                else {
                    $msg =
                      "Not authorized to run command: \"$telnet_flags{$client}{data}\"\n\r";
                }
            }
            logit(
                "$config_parms{data_dir}/logs/server_telnet.$Year_Month_Now.log",
                "$client: $telnet_flags{$client}{data}"
            );
        }
        set $telnet_server $msg if defined $msg;
        unless ( $telnet_flags{$client}{auth} eq 'set_password' ) {
            set $telnet_server 'cr';
            set $telnet_server ( $telnet_flags{$client}{auth} eq "admin" )
              ? 'prompt_admin'
              : 'prompt';
        }
        $telnet_flags{$client}{data} = '';
    }
}

# Show the reponse the the previous command
#if (active $telnet_server and $response_loop_telnet == $Loop_Count) {
#    set $telnet_server 'cr';
#    my $client = $Socket_Ports{server_telnet}{socka};
#    set $telnet_server ($telnet_flags{$client}{auth} eq "admin") ? 'prompt_admin' : 'prompt';
#}

# Example of how enable inputing random data from a telnet session
# In your telnet, type:  set $wakeup_time_test '10 am'
$wakeup_time_test = new Generic_Item;
$wakeup_time_test->set_states(
    qw(6:00am 6:20am 6:40am 7:00am 7:20am 7:40am 8:00am none));

speak "Your wake up time is set for $state"
  if $state = state_now $wakeup_time_test;
speak "Time to wake up" if time_now state $wakeup_time_test;

