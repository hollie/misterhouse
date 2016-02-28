##################################################################
#  Caller ID equivalent for 3Com ISDN Lan Modem                  #
#                                                                #
#  By: Danal Estes , N5SVV                                       #
#  E-Mail: danal@earthling.net                                   #
#                                                                #
##################################################################

# Category=Phone

# The ISDN Lan Modem at Software level 5.3.1 and above broadcast an Ethernet packet
# periodically and at certain event triggers.
#
# The packet contains Option Key/Length/Value tokens
# Option Key is a number; see the switch statement trees below
# Length is in bytes, non inclusive (i.e. Length is data only, add 2 for Option Key & Length)
# Data format depends on Option Key

$ISDN = new Socket_Item( undef, undef, 'server_ISDN' );    #Normally socket 2071

if ( my $packet = said $ISDN) {
    print_log "3Com data received\n" if $config_parms{debug};
    print_log "Length " . length($packet) . "\n" if $config_parms{debug};
    print_log "\n" . unpack( "h*", $packet ) . "\n" if $config_parms{debug};

    my ( $NumChannels, %current, %service );

    my $i = 4;    # Start at first option flag
    while ( $i < length($packet) ) {
        my $option = unpack( 'C', substr( $packet, $i,     1 ) );
        my $length = unpack( 'C', substr( $packet, $i + 1, 1 ) );
        $i += 2;
        print_log "Option = $option Length = $length " if $config_parms{debug};

        if ( $option == 1 ) {    # Number of channels running
            $NumChannels = unpack( 'C', substr( $packet, $i, 1 ) );
            print_log "NumChannels = $NumChannels\n" if $config_parms{debug};
        }

        if ( $option == 2 ) {    # Call Type/Direction Channel 1
            $current{1}{callflag} = unpack( 'C', substr( $packet, $i, 1 ) );
            if ( 1 == $current{1}{callflag} ) {
                $current{1}{calltype} = 'VOICE';
                $current{1}{calldir}  = 'INCOMING';
            }
            elsif ( 2 == $current{1}{callflag} ) {
                $current{1}{calltype} = 'VOICE';
                $current{1}{calldir}  = 'OUTGOING';
            }
            elsif ( 3 == $current{1}{callflag} ) {
                $current{1}{calltype} = 'DATA';
                $current{1}{calldir}  = 'INCOMING';
            }
            elsif ( 4 == $current{1}{callflag} ) {
                $current{1}{calltype} = 'DATA';
                $current{1}{calldir}  = 'OUTGOING';
            }
            else {
                $current{1}{calltype} = '';
                $current{1}{calldir}  = '';
            }
            print_log
              "Current call channel 1 = $current{1}{callflag} $current{1}{calltype} $current{1}{calldir}\n"
              if $config_parms{debug};
        }

        if ( $option == 3 ) {    # Destination Name Channel 1
            $current{1}{destname} =
              unpack( 'A*', substr( $packet, $i, $length ) );
            print_log "Channel 1 destination $current{1}{destname}\n"
              if $config_parms{debug};
        }

        if ( $option == 4 ) {    # Called Number Channel 1
            $current{1}{callednum} =
              unpack( 'A*', substr( $packet, $i, $length ) );
            print_log "Channel 1 called $current{1}{callednum}\n"
              if $config_parms{debug};
        }

        if ( $option == 5 ) {    # Calling Number Channel 1
            $current{1}{callingnum} =
              unpack( 'A*', substr( $packet, $i, $length ) );
            print_log "Channel 1 calling number $current{1}{callingnum}\n"
              if $config_parms{debug};
        }

        if ( $option == 6 ) {    # B-Channel Count for Channel 1
            $current{1}{bcount} = unpack( 'C', substr( $packet, $i, 1 ) );
            print_log "Channel 1 B-Chan count $current{1}{bcount}\n"
              if $config_parms{debug};
        }

        if ( $option == 7 ) {    # Call duration Channel 1
            $current{1}{calldur} =
              unpack( 'H*', substr( $packet, $i, $length ) );
            print_log "Channel 1 duration $current{1}{calldur}\n"
              if $config_parms{debug};
        }

        if ( $option == 8 ) {    # Remote ID for Channel 1
            $current{1}{rmtid} = unpack( 'H*', substr( $packet, $i, 1 ) );
            print_log "Channel 1 Remote ID $current{1}{rmtid}\n"
              if $config_parms{debug};
        }

        if ( $option == 9 ) {    # B-Channel in use for Channel 1
            $current{1}{bchan} = unpack( 'C', substr( $packet, $i, 1 ) );
            print_log "Channel 1 B-Chan used $current{1}{bchan}\n"
              if $config_parms{debug};
        }

        if ( $option == 10 ) {    # SBRT entry for Channel 1
            $current{1}{SBRT} = unpack( 'H*', substr( $packet, $i, 1 ) );
            print_log "Channel 1 SBRT entry $current{1}{SBRT}\n"
              if $config_parms{debug};
        }

        if ( $option == 22 ) {    # Call Type/Direction Channel 2
            $current{2}{callflag} = unpack( 'C', substr( $packet, $i, 1 ) );
            if ( 1 == $current{2}{callflag} ) {
                $current{2}{calltype} = 'VOICE';
                $current{2}{calldir}  = 'INCOMING';
            }
            elsif ( 2 == $current{2}{callflag} ) {
                $current{2}{calltype} = 'VOICE';
                $current{2}{calldir}  = 'OUTGOING';
            }
            elsif ( 3 == $current{2}{callflag} ) {
                $current{2}{calltype} = 'DATA';
                $current{2}{calldir}  = 'INCOMING';
            }
            elsif ( 4 == $current{2}{callflag} ) {
                $current{2}{calltype} = 'DATA';
                $current{2}{calldir}  = 'OUTGOING';
            }
            else {
                $current{2}{calltype} = '';
                $current{2}{calldir}  = '';
            }
            print_log
              "Current call Channel 2 = $current{2}{callflag} $current{2}{calltype} $current{2}{calldir}\n"
              if $config_parms{debug};
        }

        if ( $option == 23 ) {    # Destination Name Channel 2
            $current{2}{destname} =
              unpack( 'A*', substr( $packet, $i, $length ) );
            print_log "Channel 2 destination $current{2}{destname}\n"
              if $config_parms{debug};
        }

        if ( $option == 24 ) {    # Called Number Channel 2
            $current{2}{callednum} =
              unpack( 'A*', substr( $packet, $i, $length ) );
            print_log "Channel 2 called $current{2}{callednum}\n"
              if $config_parms{debug};
        }

        if ( $option == 25 ) {    # Calling Number Channel 2
            $current{2}{callingnum} =
              unpack( 'A*', substr( $packet, $i, $length ) );
            print_log "Channel 2 calling number $current{2}{callingnum}\n"
              if $config_parms{debug};
        }

        if ( $option == 26 ) {    # B-Channel Count for Channel 2
            $current{2}{bcount} = unpack( 'C', substr( $packet, $i, 1 ) );
            print_log "Channel 2 B-Chan count $current{2}{bcount}\n"
              if $config_parms{debug};
        }

        if ( $option == 27 ) {    # Call duration Channel 2
            $current{2}{calldur} =
              unpack( 'H*', substr( $packet, $i, $length ) );
            print_log "Channel 2 duration $current{2}{calldur}\n"
              if $config_parms{debug};
        }

        if ( $option == 28 ) {    # Remote ID for Channel 2
            $current{2}{rmtid} = unpack( 'H*', substr( $packet, $i, 1 ) );
            print_log "Channel 2 Remote ID $current{2}{rmtid}\n"
              if $config_parms{debug};
        }

        if ( $option == 29 ) {    # B-Channel in use for Channel 2
            $current{2}{bchan} = unpack( 'C', substr( $packet, $i, 1 ) );
            print_log "Channel 2 B-Chan used $current{2}{bchan}\n"
              if $config_parms{debug};
        }

        if ( $option == 30 ) {    # SBRT entry for Channel 2
            $current{2}{SBRT} = unpack( 'H*', substr( $packet, $i, 1 ) );
            print_log "Channel 2 SBRT entry $current{2}{SBRT}\n"
              if $config_parms{debug};
        }

        if ( $option == 40 ) {    # Service Provider 1 name
            $service{1} = unpack( 'A*', substr( $packet, $i, $length ) );
            print_log "Service Provider 1 name $service{1}\n"
              if $config_parms{debug};
        }

        if ( $option == 41 ) {    # Service Provider 2 name
            $service{2} = unpack( 'A*', substr( $packet, $i, $length ) );
            print_log "Service Provider 2 name $service{2}\n"
              if $config_parms{debug};
        }

        if ( $option == 42 ) {    # Service Provider 3 name
            $service{3} = unpack( 'A*', substr( $packet, $i, $length ) );
            print_log "Service Provider 3 name $service{3}\n"
              if $config_parms{debug};
        }

        if ( $option == 43 ) {    # Service Provider 4 name
            $service{4} = unpack( 'A*', substr( $packet, $i, $length ) );
            print_log "Service Provider 4 name $service{4}\n"
              if $config_parms{debug};
        }

        $i += $length;
    }    # While loop to decode packet

    # All above code is basic 3com IDSN Lan Modem packet decode
    # and debugging.

    # Code below needs more work and better integration into
    # other MH modules that support callerid.

    use vars '$old1_call', '$old2_call';
    $old1_call = '' if $current{1}{callflag} != 1;
    if (    ( $current{1}{callflag} == 1 )
        and ( $current{1}{callingnum} ne $old1_call ) )
    {    # New incoming voice call?
        $old1_call = $current{1}{callingnum};
        &callerid( $current{1}{callingnum} );
    }

    $old2_call = '' if $current{2}{callflag} != 1;
    if (    ( $current{2}{callflag} == 1 )
        and ( $current{2}{callingnum} ne $old2_call ) )
    {    # New incoming voice call?
        $old2_call = $current{2}{callingnum};
        &callerid( $current{2}{callingnum} );
    }

}

sub callerid {
    my ($cid_nmbr) = @_;
    my $cid_speak_nmbr =
        substr( $cid_nmbr, 0, 3 ) . "."
      . substr( $cid_nmbr, 3, 3 ) . "."
      . substr( $cid_nmbr, 6, 4 );        # Pauses for speak
    my $areacode = substr( $cid_nmbr, 0, 3 );
    $cid_speak_nmbr = substr( $cid_speak_nmbr, 3, 8 )
      if ( $areacode eq $config_parms{local_area_code} )
      ;                                   # Drop area code if same
#### $Caller_ID::state_by_areacode{$areacode};
    # Put Spaces in the Phone Number to 'speak' correctly
    my @chars = split //, $cid_speak_nmbr;
    $cid_speak_nmbr = '';
    foreach my $char (@chars) {
        $cid_speak_nmbr .= $char . " ";
    }

    my $cid_speak_name = '';              # for now...
                                          # Long term logs
    logit( "$config_parms{data_dir}/phone/logs/callerid.$Year_Month_Now.log",
        "$cid_nmbr $cid_name" );
    logit_dbm( "$config_parms{data_dir}/phone/callerid.dbm",
        $cid_nmbr, "$Time_Now $Date_Now $Year name=$cid_name" );

    # Short term log; speak or clear via X10 keypresses.
    open( CALLLOG, ">>$config_parms{data_dir}\\phone\\callerid.log" );  # Log it
    print CALLLOG "$Date_Now`$Time_Now`$cid_speak_name`$cid_speak_nmbr\n";
    close CALLLOG;

    speak "Call from $cid_speak_nmbr";

}
