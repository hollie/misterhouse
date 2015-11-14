# Category = MisterHouse

#@ Reads incoming data from a socket port and do stuff with it.
#@ An example client that talks with this is mh/bin/mhsend

$mhsend_server = new Socket_Item( undef, undef, 'server_mhsend' );

# Create mh/data/mhsend directory at startup, if missing
mkdir( "$config_parms{data_dir}/mhsend", 0777 )
  if $Startup and !-d "$config_parms{data_dir}/mhsend";

if ( my $header = said $mhsend_server) {

    my ( $msg, $user, $password, $authorized, $response );

    # Format of incoming data:
    #  Request
    #  Authorization: Basic  xxxx
    #
    #  data

    my ( $action, $action_arg ) = $header =~ /^(\S+) *(\S*)/;
    $action = lc $action;
    my ( $name, $name_short );

    #   my ($name, $name_short) = net_domain_name('server_data');
    print_log
      "Received server_data data: name=$name: action=$action arg=$action_arg"
      unless $config_parms{no_log} =~ /mhsend_server/;

    # Read header and optional password (until blank record)
    my $handle = handle $mhsend_server;
    while (<$handle>) {
        last unless /\S/;
        if (/Authorization: Basic (\S+)/) {
            ( $user, $password ) = split( ':', unpack( "u", $1 ) );

            #           ($user, $password) = split(':', decode_base64 $1);
        }
        if ( $user = password_check $password, 'server_mhsend' ) {
            $authorized = $user;
        }
        else {
            $response = "mhsend password bad\n";
        }
    }

    # Now read the data
    while (<$handle>) {
        $msg .= $_;
    }

    if ( $Password_Allow{$action} eq 'anyone'
        or ( $action eq 'run' and $Password_Allow{$msg} eq 'anyone' ) )
    {
        $authorized = 'anyone';
    }

    if ( !$authorized ) {
        $response = "Action is not authorized: $action $msg";
    }
    elsif ( $action eq 'display' ) {
        $action_arg = 120 unless defined $action_arg;
        display( $msg, $action_arg, "Internet Message from $name" );
        display
          text        => $msg,
          time        => $action_arg,
          title       => 'Mhsend message',
          window_name => 'mssend',
          append      => 'bottom';

        #       print_msg "mhsend: $msg";
        $response = "Data was displayed for $action_arg seconds";
        logit( "$config_parms{data_dir}/mhsend/display.log", $msg )
          ;    # Also logit
    }
    elsif ( $action eq 'state' ) {
        my $state = eval "state $msg";
        $response = $state;
    }
    elsif ( $action eq 'speak' ) {
        if ( length $msg < 400 ) {
            speak $msg;
            $response = "Data was spoken";
        }
        else {
            display( $msg, 120, "Internet Message from $name" );
            $response =
              "Data was too long ... it was displayed instead of being spoken";
        }
    }
    elsif ( $action eq 'run' ) {
        $msg =~ s/\n|\r//g;

        #       if (&run_voice_cmd($msg)) {
        #       my $respond = "object_set name=mhsend_server";
        my $respond = "mhsend name=mhsend_server ";
        $respond .=
          "proxyip=" . $Socket_Ports{'server_mhsend'}{client_ip_address};
        if ( &process_external_command( $msg, 0, 'mhsend', $respond ) ) {
            $response = "Command was run: $msg";
        }
        else {
            $response = "Command not found: $msg";
        }
    }
    elsif ( $action eq 'file' ) {
        file_write( "$config_parms{data_dir}/mhsend/$action_arg", $msg );
        $response = "Data was filed to $action_arg";
    }
    elsif ( $action eq 'log' ) {
        $action_arg = 'default' unless $action_arg;

        #       logit("$config_parms{data_dir}/mhsend/$action_arg.log", $msg, 0);
        logit( "$config_parms{data_dir}/mhsend/$action_arg.log", $msg );
        $response = "Data was logged $action_arg.log";
    }

    print_log $response unless $config_parms{no_log} =~ /mhsend_server/;
    print "mhsend_server: $response\n"
      unless $config_parms{no_log} =~ /mhsend_server/;
    print $handle $response;

}

sub respond_mhsend {

    #   my $handle = handle $mhsend_server;
    #   print $handle $response;
    #   print_log "mhsend response: @_";
    &respond_default(@_);
}

