# Category=Internet
#
# This code will read incoming data from a socket port and do stuff with it.
# An example client that talks with this is mh/bin/mhsend
#

$mhsend_server = new Socket_Item( undef, undef, 'server_mhsend' );

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
      "Received server_data data: name=$name: action=$action arg=$action_arg";

    # Read header and optional password (until blank record)
    my $handle = handle $mhsend_server;
    while (<$handle>) {
        last unless /\S/;
        if (/Authorization: Basic (\S+)/) {
            ( $user, $password ) = split( ':', unpack( "u", $1 ) );

            #           ($user, $password) = split(':', decode_base64 $1);
        }
        if ( my $results = password_check $password, 'server_mhsend' ) {
            $response = "mhsend password bad: $results\n";
        }
        else {
            $authorized = 1;
        }
    }

    # Now read the data
    while (<$handle>) {
        $msg .= $_;
    }

    if ( $Password_Allow{$action}
        or ( $action eq 'run' and $Password_Allow{$msg} ) )
    {
        $authorized = 1;
    }
    print_log "  Authorized=$authorized\n";

    if ( !$authorized ) {
        $response = "Action is not authorized: $action $msg";
    }
    elsif ( $action eq 'display' ) {
        $action_arg = 120 unless defined $action_arg;
        display( $msg, $action_arg, "Internet Message from $name" );
        $response = "Data was displayed for $action_arg seconds";
    }
    elsif ( $action eq 'speak' ) {
        if ( $msg < 400 ) {
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
        if ( &run_voice_cmd($msg) ) {
            $response = "Command was run: $msg";
        }
        else {
            $response = "Command not found: $msg";
        }
    }
    elsif ( $action eq 'file' ) {
        file_write( "$config_parms{data_dir}/$action_arg", $msg );
        $response = "Data was filed to $action_arg";
    }
    elsif ( $action eq 'log' ) {
        $action_arg = 'default' unless $action_arg;
        logit( "$config_parms{data_dir}/$action_arg.log", $msg, 1 );
        $response = "Data was logged $action_arg.log";
    }

    print_log $response;
    print $response;
    print $handle $response;

    close $handle;
}

