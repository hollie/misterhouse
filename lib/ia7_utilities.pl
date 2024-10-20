package ia7_utilities;
use strict;
use JSON qw(decode_json to_json);

$main::Save{"ia7_count_total"} = 0 if (not defined $main::Save{"ia7_count_total"}); #noloop

&::Reload_post_add_hook( \&ia7_utilities::speech_startup, 1 ); #noloop

sub speech_startup {
    if ( !defined $main::Info{IPAddress_local} ) {
        &::print_log("WARNING \$Info{IPAddress_local} not defined. Json speech disabled");
    }
    else {
        &::print_log("IA7 Speech Notifications enabled");
        &::Speak_parms_add_hook( \&main::json_speech_enable );
    }
}

sub main::json_speech_enable {
    my ($parms) = @_;
    push( @{ $parms->{web_hook} }, \&main::file_ready_for_ia7);
}

sub main::file_ready_for_ia7 {
    my (%parms) = @_;
    my %data;
    $data{mode}   = $parms{mode};
    $data{url}    = "http://" . $main::Info{IPAddress_local} . ":" . $main::config_parms{http_port} . "/" . $parms{web_file} if (defined $parms{web_file}) ;
    $data{text}   = $parms{raw_text};
    $data{client} = $parms{requestor};
    if (defined $main::Info{IPAddress_local}) {
        if ((defined $parms{forked}) and $parms{forked} ) {
        #if it's a child process we can't access the global @json_notifications array, so send a webservice call to the master process
            my $MHParent = $main::Info{IPAddress_local} . ":" . $main::config_parms{http_port};      
            my $cmd = "get_url -quiet \"http://$MHParent/SUB?ia7_notify(\'speech',$data{mode},'$data{text}',$data{url})\" /dev/null";
            &main::run("$cmd") unless (defined $main::config_parms{disable_json_speech} and $main::config_parms{disable_json_speech}); 
        } else {
            &main::json_notification( "speech", {%data} );
        }
    }
}

sub main::ia7_notify {
    my ( $type, $mode, $text, $url, $color, $client ) = @_;

    my %data;
    $data{mode}   = $mode if ($mode);
    $data{url}    = $url if ($url);
    $data{text}   = $text if ($text);
    $data{client} = $client if ($client);
    $data{color}  = $color if ($color);
    #&main::print_log("WS text = $data{text}, type=$type, url=$data{url}");    
    return unless ((lc $type eq "speech") or (lc $type eq "sound") or (lc $type eq "banner"));
    &main::json_notification( $type, {%data} );
    return "";
}

sub ia7_update_collection {
    &main::print_log("[IA7_Collection_Updater] : Starting");
    my $ia7_coll_current_ver = 1.6;

    my @collection_files = (
        "$main::Pgm_Root/data/web/collections.json",
        "$main::config_parms{data_dir}/web/collections.json",
        "$main::config_parms{ia7_data_dir}/collections.json"
    );
    for my $file (@collection_files) {
        if ( -e $file ) {
            &main::print_log("[IA7_Collection_Updater] : Reviewing $file to current version $ia7_coll_current_ver");
            my $json_data;
            my $file_data;
            my $updated;
            eval {
                $file_data = &main::file_read($file);
                $json_data = decode_json($file_data);    #HP, wrap this in eval to prevent MH crashes
            };

            if ($@) {
                &main::print_log("[IA7_Collection_Updater] : WARNING: decode_json failed for $file. Please check this file!");
            }
            else {
                $updated = 0;

                if (   ( !defined $json_data->{meta}->{version} )
                    or ( $json_data->{meta}->{version} < 1.2 ) )
                {                                #IA7 v1.2 required change
                    $json_data->{700}->{user} = '$Authorized'
                      unless ( defined $json_data->{700}->{user} );
                    my $found = 0;
                    foreach my $i ( @{ $json_data->{500}->{children} } ) {
                        $found = 1 if ( $i == 700 );
                    }
                    push( @{ $json_data->{500}->{children} }, 700 )
                      unless ($found);
                    $json_data->{meta}->{version} = "1.2";
                    &main::print_log("[IA7_Collection_Updater] : Updating $file to version 1.2 (MH 4.2 IA7 v1.2.100 support)");
                    $updated = 1;
                }
                if ( $json_data->{meta}->{version} < 1.3 )  {
                    #IA7 v1.4 required change
                    #convert back to a file so we can globally change links
                    my $file_data2 = to_json( $json_data, { utf8 => 1, pretty => 1 } );    
                    $file_data2 =~ s/\"link\"[\s+]:[\s+]\"\/ia7\/\#path=\/vars\"/\"link\" : \"\/ia7\/\#path\=\/vars_global\"/g;
                    $file_data2 =~ s/\"link\"[\s+]:[\s+]\"\/ia7\/\#path=\/vars\/Save\"/\"link\" : \"\/ia7\/\#path\=\/vars_save\"/g;
                    eval {
                        $json_data = decode_json($file_data2);    #HP, wrap this in eval to prevent MH crashes
                    };
                    if ($@) {
                        &main::print_log("[IA7_Collection_Updater] : WARNING: decode_json failed for v1.3 update.");
                    } else {           
                        $json_data->{meta}->{version} = "1.3";
                        &main::print_log("[IA7_Collection_Updater] : Updating $file to version 1.3 (MH 5.0 IA7 v1.4.400 support)");
                        $updated = 1; 
                    } 
                }  
                if ( $json_data->{meta}->{version} < 1.4 )  {
                    #IA7 v1.4 required change
                    #weather icons v2 changed wi-sprinkles to wi-humidity
                    my $file_data2 = to_json( $json_data, { utf8 => 1, pretty => 1 } );    
                    $file_data2 =~ s/wi-sprinkles/wi-humidity/g;
                    eval {
                        $json_data = decode_json($file_data2);    #HP, wrap this in eval to prevent MH crashes
                    };
                    if ($@) {
                        &main::print_log("[IA7_Collection_Updater] : WARNING: decode_json failed for v1.4 update.");
                    } else {           
                        $json_data->{meta}->{version} = "1.4";
                        &main::print_log("[IA7_Collection_Updater] : Updating $file to version 1.4 (MH 5.0 IA7 v1.5.800 weathericon change)");
                        $updated = 1; 
                    }
                }
                if ( $json_data->{meta}->{version} < 1.5 )  {
                    #IA7 v2.0 required change
                    #Native trigger support /bin/triggers.pl
                    my $file_data2 = to_json( $json_data, { utf8 => 1, pretty => 1 } );    
                    $file_data2 =~ s/\"link\"[\s+]:[\s+]\"\/bin\/triggers\.pl\"/\"link\" : \"\/ia7\/\#path\=triggers\"/g;
                    eval {
                        $json_data = decode_json($file_data2);    #HP, wrap this in eval to prevent MH crashes
                    };
                    if ($@) {
                        &main::print_log("[IA7_Collection_Updater] : WARNING: decode_json failed for v1.5 update.");
                    } else {           
                        $json_data->{meta}->{version} = "1.5";
                        &main::print_log("[IA7_Collection_Updater] : Updating $file to version 1.5 (MH 5.1 IA7 v2.0.300 native triggers change)");
                        $updated = 1; 
                    }
                } 
                if ( $json_data->{meta}->{version} < 1.6 )  {
                    
                    my $setup_key = 0;
                    my $next_key = 0;
                    foreach my $key (keys %{$json_data}) {
                        $setup_key = $key if ($json_data->{$key}->{name} eq 'Setup MrHouse');
                        $next_key = $key if (($key > $next_key) and ($key < 500));
                    }
                    if ($setup_key and $next_key) {
                        $next_key++;
                        &main::print_log("[IA7_Collection_Updater] : Adding new security button (" . $next_key . ") to Setup MrHouse (" . $setup_key . ")");
                        $json_data->{meta}->{version} = "1.6";
                        $json_data->{$next_key}->{icon} = "fa-users";
                        $json_data->{$next_key}->{name} = "Users and Groups";
                        $json_data->{$next_key}->{link} = "/ia7/#path=/security";
                        push (@{$json_data->{$setup_key}->{children}},$next_key);
                        &main::print_log("[IA7_Collection_Updater] : Updating $file to version 1.6 (MH 5.1 IA7 v2.0.600 user management)");
                        $updated = 1;
                    } else {
                        &main::print_log("[IA7_Collection_Updater] : Could not add security key to Setup MrHouse (" . $next_key . ":" . $setup_key . ")");
                    } 

                }                        
                if ($updated) {
                    my $json_newdata = to_json( $json_data, { utf8 => 1, pretty => 1 } );
                    my $backup_file = $file . ".t" . int( ::get_tickcount() / 1000 ) . ".backup";
                    &main::file_write( $backup_file, $file_data );
                    &main::print_log( "[IA7_Collection_Updater] : Saved backup " . $file . ".t" . int( ::get_tickcount() / 1000 ) . ".backup" );
                    &main::file_write( $file, $json_newdata );
                }
            }
        }
    }
    &main::print_log("[IA7_Collection_Updater] : Finished");
}

1;
