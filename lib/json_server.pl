
=head1 B<json_server>

=head2 SYNOPSIS

Called via the web server.  If no request, usage is returned.  Examples:

  http://localhost:8080/sub?json
  http://localhost:8080/sub?json(vars)

You can also specify which objects, groups, categories, variables, etc to return (by default, all) Example:

  http://me:8080/sub?json(weather=TempIndoor|TempOutdoor)

You can also specify which fields of objects are returned (by default, all) Example:

  http://localhost:8080/sub?json(groups=$All_Lights,fields=html)

=head2 DESCRIPTION

Generate json for mh objects, groups, categories, and variables

TODO

  add request types for speak, print, and error logs
  add the truncate option to packages, vars, and other requests
  add more info to subs request

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item B<UnDoc>

=cut

#NOTE: Removed sort from line 454 for optimization.

use strict;

use RRDTool::Rawish;
use HTML::Entities;    # So we can encode characters like <>& etc
use JSON qw(decode_json);
use IO::Compress::Gzip qw(gzip);
use vars qw(%json_table);
use File::Copy;
use Digest::MD5 qw(md5 md5_hex);
my %json_cache;
my @json_notifications = ();    #noloop
my $web_counter; #noloop;

sub json {
    my ( $request_type, $path_str, $arguments, $body, $client_number, $requestnum ) = @_;
 
    my %HttpHeader = &::http_get_headers($client_number, $requestnum);
    print_log ("json: Compression header: ". $HttpHeader{'Accept-Encoding'} ." - Connection header: ". $HttpHeader{'Connection'} ."Client: $client_number Req: $requestnum" ) if $Debug{json};
    # Passed arguments can be used to override the global parameters
    # This is necessary for using the LONG_POLL interface
    if ( $request_type eq '' ) {
        $request_type = $HTTP_REQ_TYPE;
    }
    my %arg_hash = %HTTP_ARGV;

    if ( $arguments ne '' ) {
        %arg_hash = ();

        # Split the pairs apart first
        # $pairs[0]="var1=val1", $pairs[1]="var2=val2", etc
        my @pairs = split( /&/, $arguments );

        # Now split each individual pair and store in the hash
        foreach my $pair (@pairs) {
            my ( $name, $value ) = $pair =~ /(.*?)=(.*)/;
            if ($value) {
                $value =~ tr/\+/ /;    # translate + back to spaces
                $value =~ s/%([0-9a-fA-F]{2})/pack("C",hex($1))/ge;

                # Store in hash
                $arg_hash{$name} = $value;
            }
        }
    }
    if ( $body eq '' ) {
        $body = $HTTP_BODY;
    }
    if ( $path_str eq '' ) {
        $path_str = $HTTP_REQUEST;
    }

    # Split arguments into arrays
    my %args;
    foreach my $k ( keys %arg_hash ) {
        $args{$k} = [ split /,/, $arg_hash{$k} ];
    }

    # Split Path into Array
    $path_str =~ s/^\/json//i;    # Remove leading 'json' path
    $path_str =~ s/^\/|\/$//g;    # Remove leadin trailing slash.

    my @path = split( '/', $path_str );

    if ($path_str eq '') {
            print_log "Json_Server.pl: WARNING: null json request received. Ignoring...";
    } else {

        if ( lc($request_type) eq "get" ) {
            return json_get( $request_type, \@path, \%args, $body, %HttpHeader );
        }
        elsif ( lc($request_type) eq "put" ) {
            json_put( $request_type, \@path, \%args, $body, %HttpHeader );
        }
        elsif ( lc($request_type) eq "post" ) {
            json_post( $request_type, \@path, \%args, $body, %HttpHeader );
        }
    }
}

# Handles Put (UPDATE) Requests
sub json_put {
    my ( $request_type, $path, $arguments, $body, %HttpHeader ) = @_;
    my (%json);
    my %args        = %{$arguments};
    my @path        = @{$path};
    my $output_time = ::get_tickcount();
    $body = decode_json($body);
    %HttpHeader = %Http unless %HttpHeader;

    # Currently we only know how to do things with objects
    if ( $path[0] eq 'objects' ) {
        my $object = ::get_object_by_name( $path[1] );
        if ( ref $object ) {
            if ( $path[2] ne '' && $object->can( $path[2] ) ) {
                my $method   = $path[2];
                my $response = $object->$method($body);
                $json{data} = $response;
            }
            else {
                $json{error}{msg} = 'Method not available on object';
            }
        }
        else {
            $json{error}{msg} = 'Unable to locate object by that name';
        }
    }
    else {
        $json{error}{msg} = 'PUT can only be used on the path objects';
    }

    #Insert Meta Data fields
    $json{meta}{time} = $output_time;
    $json{meta}{path} = \@path;
    $json{meta}{args} = \%args;

    my $json_raw = JSON->new->allow_nonref;

    # Translate special characters
    $json_raw = $json_raw->pretty->encode( \%json );
    return &json_page($json_raw,%HttpHeader);
}

 sub json_post {
    my ( $request_type, $path, $arguments, $body, %HttpHeader ) = @_;
    my (%json);
    my %args        = %{$arguments};
    my @path        = @{$path};
    my $response_code = "HTTP/1.1 200 OK\r\n";
    my $response_text = ();
    %HttpHeader = %Http unless %HttpHeader;
    my $empty_json = 0;
    $empty_json = 1 if ($body =~ m/^\{(\s*)\}$/);
    
    eval {
        $body = decode_json($body);    #HP, wrap this in eval to prevent MH crashes
    };
    
    if ($@ and !$empty_json) {
        &main::print_log( "Json_Server.pl: WARNING: decode_json failed for json POST!" );
        &main::print_log( "Json_Server.pl: WARNING: Data is $body" );

        $response_code = "HTTP/1.1 500 Internal Server Error\r\n";
        $response_text->{status} = "error";
        $response_text->{text} = "Failed to decode JSON file";
        
    } elsif ( $path[0] eq 'collections' ) {
    
        if ($empty_json) {
                $response_code = "HTTP/1.1 500 Internal Server Error\r\n";
                $response_text->{status} = "error";
                $response_text->{text} = "Empty JSON string posted";
                &main::print_log( "Json_Server.pl: ERROR." . $response_text->{text});

        } else {
             my @collection_files = (
              "$config_parms{ia7_data_dir}/collections.json",
              "$config_parms{data_dir}/web/collections.json",
              "$Pgm_Root/data/web/collections.json"
             );

             &main::print_log( "Json_Server.pl: Updating Collections.json");

             if (lc $Authorized ne "admin") {
                 $response_code = "HTTP/1.1 401 Unauthorized\r\n";
                 $response_text->{status} = "error";
                 $response_text->{text} = "Administative Access required";
                 &main::print_log( "Json_Server.pl: ERROR." . $response_text->{text});

             } else {
        
                 ($response_code, $response_text) = &json_write_file('collections',$body,@collection_files);
 
             }
        }

    } elsif ( $path[0] eq 'ia7_config' ) {

        if ($empty_json) {
                $response_code = "HTTP/1.1 500 Internal Server Error\r\n";
                $response_text->{status} = "error";
                $response_text->{text} = "Empty JSON string posted";
                &main::print_log( "Json_Server.pl: ERROR." . $response_text->{text});

        } else {

             my @config_files = (
              "$config_parms{ia7_data_dir}/ia7_config.json",
              "$config_parms{data_dir}/web/ia7_config.json",
              "$Pgm_Root/data/web/ia7_config.json"
             );

             &main::print_log( "Json_Server.pl: Updating ia7_config.json");

             if (lc $Authorized ne "admin") {
                 $response_code = "HTTP/1.1 401 Unauthorized\r\n";
                 $response_text->{status} = "error";
                 $response_text->{text} = "Administative Access required";
                 &main::print_log( "Json_Server.pl: ERROR." . $response_text->{text});

             } else {
        
                 ($response_code, $response_text) = &json_write_file('ia7_config',$body,@config_files);
             }
        }

    } elsif ( $path[0] eq 'web_counter' ) {

        $web_counter = 0 if (not defined $web_counter);
        $web_counter++;
        $main::Save{"ia7_count_total"}++;
        $response_code = "HTTP/1.1 200 OK\r\n";
        $response_text->{status} = "success";
        $response_text->{text} = "";  

    } elsif ( $path[0] eq 'security' ) {

    &main::print_log( "Json_Server.pl: security post");
   
       print Dumper $body;
       
       if ($body->{pk} eq 'add_group') {
            my $members = join(',',@{$body->{members}});
            print("add_group &Groups('add',$body->{name},$members)\n");
            
            &Groups('add',$body->{name},$members);
       }
       if ($body->{pk} eq 'add_user') {
            my $passwd = "";
            $passwd = $body->{password};
            $passwd = md5_hex($passwd) unless ($body->{md5} eq "true");
            &Groups('add','',$body->{name},$passwd); 
            print("add_user &Groups('add','',$body->{name},$passwd), [$body->{md5}]\n"); 
            
            foreach my $group (@{$body->{groups}}) {
                &Groups('add',$group,$body->{name}); 
                print("add_user &Groups('add',$group,$body->{name})\n"); 
            }        
       }
       if ($body->{pk} eq 'type') {
            if ($body->{value} eq 'delete') {
                my ($type,$name) = $body->{name} =~ /^(user_|group_)(.*)/i;
                if ($type eq "user_") {
                    print("can't delete users yet");
                } elsif ($type eq "group_") {                    
                    &Groups('delete',$name); 
                    print("delete group &Groups('delete',$name);\n");
                }
            }
        } 
       
        $response_code = "HTTP/1.1 200 OK\r\n";
        $response_text->{status} = "success";
        $response_text->{text} = "";  

    } elsif ( $path[0] eq 'triggers' ) {

        if (($empty_json or (!defined $body->{name}) or (!defined $body->{value}) or (!defined $body->{pk})) and (defined $body->{pk} and lc $body->{pk} ne 'add')) {
                $response_code = "HTTP/1.1 500 Internal Server Error\r\n";
                $response_text->{status} = "error";
                if ($empty_json) {
                    $response_text->{text} = "Empty JSON string posted";
                } else {
                    $response_text->{text} = "Bad submitted data";                
                }
                &main::print_log( "Json_Server.pl: ERROR: Trigger Post:" . $response_text->{text});

        } elsif (lc $Authorized ne "admin") {
                 $response_code = "HTTP/1.1 401 Unauthorized\r\n";
                 $response_text->{status} = "error";
                 $response_text->{text} = "Administative Access required";
                 &main::print_log( "Json_Server.pl: ERROR: Unauthorized Trigger update" . $response_text->{text});
        } else {
        print Dumper $body;
        
        my $err = 0;
        my $status;
        if ($body->{pk} eq 'code') {
            $err = trigger_code_flag($body->{value});
            if ($err) {
                $status = "Error: Blacklist command found:$err";
                &main::print_log( "Json_Server.pl: Trigger. Blacklist command ($err) found in $body->{name}");
            } else {
                $status = &trigger_set_code($body->{name}, $body->{value});
            }
           
        } elsif ($body->{pk} eq 'name') {
           $status = &trigger_rename($body->{name}, $body->{value});
        
        } elsif ($body->{pk} eq 'type') {
           $status = &trigger_set_type($body->{name}, $body->{value});

        } elsif ($body->{pk} eq 'trigger') {
           $status = &trigger_set_trigger($body->{name}, $body->{value});

        } elsif ($body->{pk} eq 'add') {
            &main::print_log( "Json_Server.pl: adding new trigger $body->{name} ");
            my $trigger = ( $body->{trigger1} ) ? "$body->{trigger1} $body->{trigger2}" : $body->{trigger2};
            my $code;
            if ( $body->{code1} ) {
                 unless ( $body->{code1} eq 'set' ) {
                     $body->{code2} =~ s/\'/\\'/g;
                     $body->{code2} = "'$body->{code2}'";
                 }
                 $code = "$body->{code1} $body->{code2}";
             }
             else {
                 $code = $body->{code2};
             }
             &main::print_log("trigger_set( $trigger, $code, $body->{type}, $body->{name} )");

             $status = &trigger_set( $trigger, $code, $body->{type}, $body->{name} );
        }
                     
            if ($status =~ m/OK/) {
                $response_code = "HTTP/1.1 200 OK\r\n";
                $response_text->{status} = "success";
                my ($txt) = $status =~ /INFO: (.*)/i; 
                $response_text->{text} = "";
                $response_text->{text} = $txt if ($txt);             
                &_triggers_save

            } else {
                $response_code = "HTTP/1.1 500 Internal Server Error\r\n";
                $response_text->{status} = "error";
                my ($txt) = $status =~ /ERROR: (.*)/i; 
                $response_text->{text} = $txt;
            }
        
        }

    } elsif ( $path[0] eq 'objects' ) {

        if ($empty_json) {
                $response_code = "HTTP/1.1 500 Internal Server Error\r\n";
                $response_text->{status} = "error";
                $response_text->{text} = "Empty JSON string posted";
                &main::print_log( "Json_Server.pl: ERROR." . $response_text->{text});

        } else {
        
             my $obj_found = 0;
             my $error = 0;
             foreach my $object (keys %{$body}) {
                 foreach my $field (keys %{$body->{$object}}) {
                     if ($field == "schedule") {
                         if (!$Authorized) {
                             $response_code = "HTTP/1.1 401 Unauthorized\r\n";
                             $response_text->{status} = "error";
                             $response_text->{text} = "Authenticated Access required";
                             &main::print_log( "Json_Server.pl: Error modifying schedule for $object:" . $response_text->{text});
                             $error = 1;
                         } else {
                             $obj_found = 1;
                             my $obj = &main::get_object_by_name($object);
                             $obj->reset_schedule();
                             foreach my $schedule (@{$body->{$object}->{$field}}) {
                             $obj->set_schedule( $schedule->{id}, $schedule->{cron}, $schedule->{label} );
                             }
                         }
                     }
                 }
             } 
             unless ($error) {
                 if ($obj_found) {
                     $response_code = "HTTP/1.1 200 OK\r\n";
                     $response_text->{status} = "success";
                     $response_text->{text} = "";  
                 } else {
                     $response_code = "HTTP/1.1 500 Internal Server Error\r\n";
                     $response_text->{status} = "error";
                     $response_text->{text} = "Object not found";
                 }
             }
        }
         
    } else {
        $response_code = "HTTP/1.1 500 Internal Server Error\r\n";
        $response_text->{status} = "error";
        $response_text->{text} = "Unknown path " . $path[0];
        &main::print_log( "Json_Server.pl: ERROR." . $response_text->{text});
        
    }  
    
    my $html_body;  
    eval {
        $html_body = to_json( $response_text, { utf8 => 1} );
    };
    if ($@) {
        &main::print_log( "Json_Server.pl: WARNING: to_json failed for json POST!" );
        $response_code = "HTTP/1.1 500 Internal Server Error\r\n";
        $response_text->{status} = "error";
        $response_text->{text} = "Failed to encode JSON data";
        
    }

    my $html_head = $response_code;
    $html_head .= "Server: MisterHouse\r\n";
    $html_head .= "Content-Length: " . length($html_body) . "\r\n";
    $html_head .= "Date: " . time2str(time) . "\r\n";
    $html_head .= "\r\n";  
 
    return $html_head . $html_body;
      
}


# Handles Get (READ) Requests
sub json_get {
    my ( $request_type, $path, $arguments, $body, %HttpHeader ) = @_;

    my %args = %{$arguments};
    my @path = @{$path};
    my ( %json, %json_data, $json_vars, $json_objects );
    my $output_time = ::get_tickcount();
    %HttpHeader = %Http unless %HttpHeader;

    # Build hash of fields requested for easy reference
    my %fields;
    if ( $args{fields} ) {
        foreach ( @{ $args{fields} } ) {
            $fields{$_} = 1;
        }
    }
    $fields{all} = 1 unless %fields;
    
    # List defined collections
    if ( $path[0] eq 'collections' || $path[0] eq '' ) {
        my $collection_file = "$Pgm_Root/data/web/collections.json";
        $collection_file = "$config_parms{data_dir}/web/collections.json"
          if -e "$config_parms{data_dir}/web/collections.json";
        $collection_file = "$config_parms{ia7_data_dir}/collections.json"
          if -e "$config_parms{ia7_data_dir}/collections.json";

        eval {
            my $json_collections = file_read($collection_file);
            $json_collections =~ s/\$config_parms\{(.+?)\}/$config_parms{$1}/gs;
            $json_collections =~ s/\$Authorized/$Authorized/gs;    # needed for including current "Authorize" status
            $json_data{'collections'} = decode_json($json_collections);    #HP, wrap this in eval to prevent MH crashes
        };
        if ($@) {
            print_log "Json_Server.pl: WARNING: decode_json failed for collection.json. Please check this file!";
            $json_data{'collections'} = decode_json('{ "0" : { "name" : "error" } }');    #write a blank collection
            config_checker($collection_file);
        }
    }

    # List ia7 preferences
    if ( $path[0] eq 'ia7_config' || $path[0] eq '' ) {
        my $prefs_file = "$Pgm_Root/data/web/ia7_config.json";
        $prefs_file = "$config_parms{data_dir}/web/ia7_config.json"
          if -e "$config_parms{data_dir}/web/ia7_config.json";
        $prefs_file = "$config_parms{ia7_data_dir}/ia7_config.json"
          if -e "$config_parms{ia7_data_dir}/ia7_config.json";

        eval {
            my $prefs = file_read($prefs_file);
            $json_data{'ia7_config'} = decode_json($prefs);    #HP, wrap this in eval to prevent MH crashes
        };

        if ($@) {
            print_log "Json_Server.pl: WARNING: decode_json failed for ia7_config.json. Please check this file!";
            $json_data{'ia7_config'} = decode_json('{ "prefs" : { "status" : "error" } }');    #write a blank collection
            config_checker($prefs_file);
        }

        # Look at the client ip overrides, and replace any pref key with the client_ip specific item
        # have to first check for {clients} since checking for $HttpHeader seems to create a null $clients key
        if (defined $json_data{'ia7_config'}->{clients}) {       
             if ( defined $json_data{'ia7_config'}->{clients}->{ $HttpHeader{Client_address} } ) {
                 print_log "Json_Server.pl: Client override section for $HttpHeader{Client_address} found";
                 for my $key ( keys %{ $json_data{'ia7_config'}->{clients}->{ $HttpHeader{Client_address} } } ) {
                     print_log "Json_Server.pl: Client key=$key, value = $json_data{'ia7_config'}->{clients}->{$HttpHeader{Client_address}}->{$key}";
                     print_log "Json_Server.pl: Master value = $json_data{'ia7_config'}->{prefs}->{$key}";
                     $json_data{'ia7_config'}->{prefs}->{$key} = $json_data{'ia7_config'}->{clients}->{ $HttpHeader{Client_address} }->{$key};
                 }
                 delete $json_data{'ia7_config'}->{clients};
             }
        }        
    }

    # List rrd config settings
    if ( $path[0] eq 'rrd_config' || $path[0] eq 'rrd' || $path[0] eq '' ) {
        my $prefs_file = "$Pgm_Root/data/web/ia7_rrd_config.json";
        $prefs_file = "$config_parms{data_dir}/web/ia7_rrd_config.json"
          if -e "$config_parms{data_dir}/web/ia7_rrd_config.json";
        $prefs_file = "$config_parms{ia7_data_dir}/ia7_rrd_config.json"
          if -e "$config_parms{ia7_data_dir}/ia7_rrd_config.json";

        eval {
            my $prefs = file_read($prefs_file);
            $json_data{'rrd_config'} = decode_json($prefs);    #HP, wrap this in eval to prevent MH crashes
        };
        if ($@) {
            &main::print_log("Json_Server.pl: WARNING: decode_json failed for ia7_rrd_config.json. Please check this file!");
        }
    }

    # RRD data routines
    if ( $path[0] eq 'rrd' || $path[0] eq '' ) {
        my $path = "$config_parms{data_dir}/rrd";
        $path = "$config_parms{rrd_dir}"
          if (  ( defined $config_parms{rrd_dir} )
            and ( $config_parms{rrd_dir} ) );
        $path = $json_data{'rrd_config'}->{'prefs'}->{'path'}
          if ( defined $json_data{'rrd_config'}->{'prefs'}->{'path'} );
        my $rrd_file = "weather_data.rrd";
        $rrd_file = $config_parms{weather_data_rrd}
          if ( ( defined $config_parms{weather_data_rrd} ) and ($config_parms{weather_data_rrd}));
        my $rrd_source = "";
        $rrd_file = $args{file}[0] if (defined $args{file}[0]);
        $rrd_source = $args{source}[0] if (defined $args{source}[0]);
        $rrd_file = $config_parms{"rrd_source_" . $rrd_source} if (defined $config_parms{"rrd_source_" . $rrd_source} and $config_parms{"rrd_source_" . $rrd_source});
        $path = $config_parms{"rrd_source_" .$rrd_source . "_path"} if (defined $config_parms{"rrd_source_" . $rrd_source . "_path"} and $config_parms{"rrd_source_" . $rrd_source . "_path"});
#print "JSON: source=$rrd_source path=$path file=$rrd_file\n";
        if ( $rrd_file =~ m/.*\/(.*\.rrd)/ ) {
            $rrd_file = $1;
        }
        $rrd_file = $json_data{'rrd_config'}->{'prefs'}->{'default_rrd'}
          if ( defined $json_data{'rrd_config'}->{'prefs'}->{'default_rrd'} );
        my $default_cf = "AVERAGE";
        $default_cf = $json_data{'rrd_config'}->{'prefs'}->{'default_cf'}
          if ( defined $json_data{'rrd_config'}->{'prefs'}->{'default_cf'} );
        my $default_timestamp = "true";
        $default_timestamp = $json_data{'rrd_config'}->{'prefs'}->{'get_last_update'}
          if ( defined $json_data{'rrd_config'}->{'prefs'}->{'get_last_update'} );

        &main::print_log("json_server.pl: WARNING. could not find ds.$rrd_source section in ia7_rrd_config.json!") if (($rrd_source) and !(defined $json_data{'rrd_config'}->{'ds.' . $rrd_source}));

        my @dss      = ();
        my @defs     = ();
        my @xports   = ();
        my @dataset  = ();
        my $index    = 0;
        my @round    = ();
        my @type     = ();
        my @colors   = ('#330099','#00ff00','#3300FF','#330099','#2B65EC','#FF0000','#009933','#FBB117','#CC33CC','#00FF00','#FF99CC','#990000');
        my $celsius  = 0;
        my $kph      = 0;
        my $arg_time = 0;
        my $xml_info;
        $arg_time = int( $args{time}[0] ) if ( defined int( $args{time}[0] ) );
        $celsius  = 1                     if ( $config_parms{weather_uom_temp} eq 'C' );
        $celsius  = 1
          if ( lc $json_data{'rrd_config'}->{'prefs'}->{'uom'} eq "celsius" );

        $kph = 1 if ( $config_parms{weather_uom_wind} eq 'kph' );

        my %data;
        my $end = "now";

        if ( defined $args{start}[0] ) {

            my $start = $args{start}[0];
            $end = $args{end}[0] if ( defined $args{end}[0] );

            #go through all the defined DSs and if the group name and stash in $args{ds} the array of DSs

            if ( defined $args{group}[0] ) {
                @{ $args{ds} } = ();    #override any DSs specified in the URL
                my $ds_config = $json_data{'rrd_config'}->{'ds'};
                $ds_config = $json_data{'rrd_config'}->{'ds.' . $rrd_source} if ($rrd_source); #use ds.<name> if an external source is specified
                for my $dsg ( keys %{ $ds_config } ) {
                    if ( defined $ds_config->{$dsg}->{'group'} ) {
                        foreach my $group ( split /,/, $ds_config->{$dsg}->{'group'} ) {
                            push @{ $args{ds} }, $dsg if ( lc $group ) eq ( lc $args{group}[0] );
                        }
                    }
                }
            }
            my $color_index = 0;
            foreach my $ds ( @{ $args{ds} } ) {
                push @dss, $ds;

                my $ds_config = $json_data{'rrd_config'}->{'ds'};
                $ds_config = $json_data{'rrd_config'}->{'ds.' . $rrd_source} if ($rrd_source); #use ds.<name> if an external source is specified

                #if it doesn't exist as a ds then skip
                my $cf = $default_cf;
                $cf = $ds_config->{$ds}->{'cf'} if ( defined $ds_config->{$ds}->{'cf'} );
                push @defs,   "DEF:$ds=$path/$rrd_file:$ds:$cf";
                push @xports, "XPORT:$ds";
                $dataset[$index]->{'label'} = $ds;
                $dataset[$index]->{'label'} = $ds_config->{$ds}->{'label'} if ( defined $ds_config->{$ds}->{'label'} );
                $color_index = 0 if ($color_index > scalar(@colors));
                $dataset[$index]->{'color'} = $colors[$color_index++];
                $dataset[$index]->{'color'} = $ds_config->{$ds}->{'color'} if ( defined $ds_config->{$ds}->{'color'} );
                if ( lc $ds_config->{$ds}->{'type'} eq "bar" ) {
                    $dataset[$index]->{'bars'}->{'show'}      = "true";
                    $dataset[$index]->{'bars'}->{'fill'}      = "0";
                    $dataset[$index]->{'bars'}->{'lineWidth'} = 0;

                    #$dataset[$index]->{'bars'}->{'barWidth'} = 8 * 60 * 60 * 1000;  #calculate barwidth based on data range
                    #TODO - bar width on data range
                    $dataset[$index]->{'bars'}->{'fillColor'}->{'colors'}[0]->{'opacity'} = 0.3;
                    $dataset[$index]->{'bars'}->{'fillColor'}->{'colors'}[1]->{'opacity'} = 0.3;
                    $dataset[$index]->{'yaxis'}                                           = 2;
                }
                else {
                    $dataset[$index]->{'lines'}->{'show'} = "true";
                }
                $round[$index] = $ds_config->{$ds}->{'round'} if ( defined $ds_config->{$ds}->{'round'} );
                $type[$index] = $ds_config->{$ds}->{'type'} if ( defined $ds_config->{$ds}->{'type'} );
                $index++;
            }

            push @defs, @xports;
            my $rrd = RRDTool::Rawish->new( rrdfile => "$path/$rrd_file" );
            my $xml =
              $rrd->xport( [@defs], { '--start' => $start, '--end' => $end, } );
            $xml_info = $rrd->info if ( $default_timestamp eq "true" );
            my @lines = split /\n/, $xml;

            my ($step) = $xml =~ /\<step\>(\d+)\<\/step\>/;    #this is the width for any bar charts

            if ($step) {
                for my $i ( 0 .. $#dataset ) {
                    $dataset[$i]->{'bars'}->{'barWidth'} = int($step) * 1000
                      if ( defined $dataset[$i]->{'bars'} );
                }
            }

            my $time_index = 0;
            my ($db_start) = $xml =~ /\<start\>(\d+)\<\/start\>/;

            foreach my $line (@lines) {
                my (@values) = $line =~ /\<v\>(-?[e.+-\d]*|NaN)\<\/v\>/g;

                next if ( !@values );    #skip header lines

                my $index = 0;
                foreach my $value (@values) {
                    my $value1 = sprintf( "%.10g", $value );
                    $value1 = ( $value1 - 32 ) * ( 5 / 9 )
                      if (  ($celsius)
                        and ( lc $type[$index] eq "temperature" ) );
                    $value1 = sprintf( "%.2f", $value1 * 1.60934 )
                      if ( ($kph) and ( lc $type[$index] eq "speed" ) );
                    $value1 = sprintf( "%." . $round[$index] . "f", $value1 )
                      if ( defined $round[$index] );
                    $value1 =~ s/\.0*$//
                      unless ( $value1 == 0 );    #remove unneccessary trailing decimals
                    $value1 = "null" if ( lc $value1 eq "nan" );
                    if ($arg_time) {
                        push @{ $dataset[$index]->{data} }, [ ( $db_start + ( $time_index * $step ) ) * 1000, $value1 ]
                            if (($db_start + ( $time_index * $step ) ) * 1000 >= $arg_time ); #filter out all values less than time= if present
                    } else {
                        push @{ $dataset[$index]->{data} }, [ ( $db_start + ( $time_index * $step ) ) * 1000, $value1 ];
                    }
                    $index++;
                }
                $time_index++;
            }
        }
        $data{'data'}    = \@dataset;
        $data{'options'} = $json_data{'rrd_config'}->{'options'}
          if ( defined $json_data{'rrd_config'}->{'options'} );
        $data{'periods'} = $json_data{'rrd_config'}->{'periods'}
          if ( defined $json_data{'rrd_config'}->{'periods'} );
        $data{'last_update'} = $xml_info->{'last_update'} * 1000
          if ( ref($xml_info) eq 'HASH' && defined $xml_info->{'last_update'} );
        $json_data{'rrd'} = \%data;
    }

    # List object history
    if ( $path[0] eq 'history' ) {

        if ( $args{items} && $args{items}[0] ne "" ) {
            my %statemaps = (
                'on'       => 100,
                'open'     => 100,
                'opened'   => 100,
                'motion'   => 100,
                'enable'   => 100,
                'enabled'  => 100,
                'online'   => 100,
                'ready'    => 100,
                'off'      => -100,
                'close'    => -100,
                'closed'   => -100,
                'still'    => -100,
                'disable'  => -100,
                'disabled' => -100,
                'offline'  => -100,
                'fault'    => -100,
                'dim'      => 50,
            );
            my $unknown_value = 40;
            my @dataset       = ();
            my %states;
            my %data;
            my $index = 0;
            my $start = time;
            $start = $args{start}[0] if ( defined $args{start}[0] );
            my $graph = 0;
            $graph = $args{graph}[0] if ( defined $args{graph}[0] );
            my $days = 0;
            $days = $args{days}[0] if ( defined $args{days}[0] );

            foreach my $name ( @{ $args{items} } ) {
                my $o = &get_object_by_name($name);
                next unless ( defined $o );
                next unless $o->get_logger_status();
                my $label = $o->set_label();
                $label = $name unless ( defined $label );
                my $logger_data = $o->get_logger_data( $start, $days );

                #alert if any anomalous states are detected
                my @lines = split /\n/, $logger_data;
                foreach my $line (@lines) {
                    my $value;
                    my ( $time1, $time2, $obj, $state, $setby, $target ) =
                      split ",", $line;
                    if ($graph) {
                        if ( defined $statemaps{$state} ) {
                            $value = $statemaps{$state};
                        }
                        else {
                            if ( $state =~ /(\d+)\%/ ) {
                                $value = $_;
                            }
                            else {
                                &main::print_log("json_server.pl: WARNING. object history state $state not found in mapping");
                                $value = $unknown_value++;
                            }
                        }
                        $states{$value} = $state;
                        push @{ $dataset[$index]->{data} }, [ int($time2), int($value) ];
                    }
                    else {
                        push @dataset, [ int($time2), $state, $setby ];
                    }
                }
                push @{ $dataset[$index]->{label} }, $label if ($graph);
                $index++;
            }
            if ($graph) {

                #flot expects to see an array
                my @yaxticks = ();
                for my $j ( sort keys %states ) {
                    push @yaxticks, [ $j, $states{$j} ];
                }
                $data{'options'}->{'yaxis'}->{'ticks'}    = \@yaxticks;    #\%states;
                $data{'options'}->{'legend'}->{'show'}    = "true";
                $data{'options'}->{'xaxis'}->{'mode'}     = "time";
                $data{'options'}->{'points'}->{'show'}    = "true";
                $data{'options'}->{'xaxis'}->{'timezone'} = "browser";
                $data{'options'}->{'grid'}->{'hoverable'} = "true";
            }
            $data{'data'}         = \@dataset;
            $json_data{'history'} = \%data;
        }
    }

    # List objects
    if ( $path[0] eq 'objects' || $path[0] eq '' ) {
        $json_data{objects} = {};
        my @objects;

        # Building the list of parent groups for each object
        # we could use &::list_groups_by_object() for each object, but that sub
        # is time consuming, particularly when called numerous times.  Instead,
        # we create a lookup table one time, saving a lot of processing time.
	$json_cache{parent_table} = build_parent_table() if ( !($json_cache{parent_table}) || $Reload );
        if ( $args{items} && $args{items}[0] ne "" ) {
            foreach my $name ( @{ $args{items} } ) {

                #$name =~ s/\$|\%|\&|\@//g;
                my $o = &get_object_by_name($name);
                print_log "json: object name=$name ref=" . ref $o if $Debug{json};
                if ( my $data = &json_object_detail( $o, \%args, \%fields, $json_cache{parent_table} ) ) {
                    $json_data{objects}{$name} = $data;
                }
            }
        }
        else {


            if ( $args{parents} ) { # Restrict object list by group here to make things faster
                for ( @{ $args{parents} } ) {
                    push @objects, &list_objects_by_group( $_, 1 )
                }
            }
            elsif ( $args{category} ) {
                for ( @{ $args{category} } ) {
                    push @objects, &list_objects_by_webname( $_ )
                }
            }
            elsif ( $args{type} ) { # Restrict object list by type here to make things faster
                for ( @{ $args{type} } ) {
                    push @objects, &list_objects_by_type($_);
                }
            }
            else {
                foreach my $object_type ( list_object_types() ) {
                    push @objects, &list_objects_by_type($object_type);
                }
            }

            #            foreach my $o ( map { &get_object_by_name($_) } sort @objects ) {
            foreach my $o ( map { &get_object_by_name($_) } @objects ) {
                next unless $o;
                my $name = $o;
                $name = $o->{object_name};
                $name =~ s/\$|\%|\&|\@//g;
                print_log "json: (map) object name=$name ref=" . ref $o if $Debug{json};
                if ( my $data = &json_object_detail( $o, \%args, \%fields, $json_cache{parent_table} ) ) {
                    $json_data{objects}{$name} = $data;
                }
            }

            # Insert categories as an object
            my @categories = &list_code_webnames('Voice_Cmd');
            for my $category ( sort @categories ) {
                print_log "json: cat $category" if $Debug{json};
                my $temp_object = {
                    'type'    => 'Category',
                    'members' => ''
                };
                # if a time has been supplied, then the client data has been initialized, and we don't need to send it again
                # if a category gets added, it won't refresh, but that's rare and this prevents the clients from continually sending data
                unless ( $args{time} && $args{time}[0] > 0 ) {
                    if ( filter_object( $temp_object, \%args ) ) {
                        $json_data{objects}{$category} = $temp_object;
                    }
                }
            }

            # List known types as objects
            my @types = @Object_Types;
            foreach my $type ( sort @types ) {
                print_log "json: type $type" if $Debug{json};
                my $temp_object = {
                    'type'    => 'Type',
                    'members' => ''
                };
                # if a time has been supplied, then the client data has been initialized, and we don't need to send it again
                # if a category gets added, it won't refresh, but that's rare and this prevents the clients from continually sending data
                unless ( $args{time} && $args{time}[0] > 0 ) {                
                    if ( filter_object( $temp_object, \%args ) ) {
                        $json_data{objects}{$type} = $temp_object;
                    }
                }
            }
        }
    }

    if ( $path[0] eq 'security' ) {
    if (defined $path[1] and $path[1] eq 'authorize') {
        # Passwords are stored as MD5 hashes in the user data file
        # Take that MD5, then take the current date (in YYYYDDMM format) and then calculate
        # an authorization MD5 value. Adding in the current date means that the lifespan of a compromised
        # password token is at most 1 day.
        my $status = "";
        if ($args{user} && $args{user}[0] eq "") {
            $status = "fail";
            &main::print_log("json_server.pl: ERROR, authorize attempt with no username");
        } elsif ($args{password} && $args{password}[0] eq "") {
            $status = "fail";
            &main::print_log("json_server.pl: ERROR, authorize attempt with no password");
            
        } else {
            my $password = &Groups('getpw','',$args{user}[0]);
            my $time_seed = &main::time_date_stamp('18',$Time);
            #to account for clock drift, check today and tomorrow values around midnight
            #if time is between 11:55 and midnight then also check tomorrow
            #if time is between midnight and 00:05 then also check yesterday
            if (time_greater_than("11:55 PM")) {
                my $time_seedT = &main::time_date_stamp('18',$Time + 86400);
                my $pwdcheck1 = md5_hex($password . $time_seedT);
                $status = "success" if (lc $args{password}[0] eq lc $pwdcheck1);
            }
            if (time_less_than("00:05 AM")) {
                my $time_seedY = &main::time_date_stamp('18',$Time - 86400);
                my $pwdcheck2 = md5_hex($password . $time_seedY);
                $status = "success" if (lc $args{password}[0] eq lc $pwdcheck2);
            }
            #print "PW=$password, time_seed=$time_seed";
            my $pwdcheck = md5_hex($password . $time_seed);
            #print "PWC=$pwdcheck\n";
       
            if ($status eq "" and (lc $args{password}[0] eq lc $pwdcheck)) {
                $status = "success";
                &main::print_log("json_server.pl: INFO, user $args{user}[0] successfully authenticated");
                
            } else {
                $status = "fail";
                &main::print_log("json_server.pl: WARNING, user $args{user}[0] authentication attempt failed");
                
            }
        }    
        $json_data{security}->{authorize} = $status;
    } else {
        #check if $Authorized
        my $ref;
        my $users;
        my $found = 0;
        if ($args{user} && $args{user}[0] ne "") {
            $ref->{user} = &Groups('get','',$args{user}[0]);
            #$json_data{security}{users} = 
            $found = 1;
        }
        if ($args{group} && $args{group}[0] ne "") {
            $ref->{group} = &Groups('get',$args{group}[0]);
            #$json_data{security}{groups} = 
            $found = 1;
        }
        if (!$found) {
            $ref = ${&Groups('getall')};   
        }
        #ref->{acl} = ${&Groups('fullacl')};
        print Dumper $ref;
        $json_data{security} = $ref if (defined $ref);
        #$json_data{security} = ${$ref} if (defined ${$ref});
        #print Dumper $json_data{security};
        }
    }

    if ( $path[0] eq 'authorize' ) {
    # /json/security/authorize?$user=admin&password=MD5HASH
    }

    # List subroutines
    if ( $path[0] eq 'subs' || $path[0] eq '' ) {
        my $name;
        my $ref = \%::;
        foreach my $key ( sort { lc $a cmp lc $b } keys %$ref ) {
            my $iref = ${$ref}{$key};
            $json_data{subs}{$key} = &json_walk_var( $iref, $key, ('CODE') );
        }
    }

    # List triggers
    if ( $path[0] eq 'triggers' || $path[0] eq '' ) {
        &_triggers_save; #clean up triggers before sending
        #group by type
        my @dataset       = ();
        
        for my $name (
        sort {
            my $t1 = $triggers{$a}{type};
            my $t2 = $triggers{$b}{type};
            $t1 = 0 if $t1 eq 'OneShot';
            $t2 = 0 if $t2 eq 'OneShot';
            $t1 = 1 if $t1 eq 'NoExpire';
            $t2 = 1 if $t2 eq 'NoExpire';
            $t1 = 2 if $t1 eq 'Expired';
            $t2 = 2 if $t2 eq 'Expired';   
            $t1 = 3 if $t1 eq 'Disabled';
            $t2 = 3 if $t2 eq 'Disabled';                     
            $t1 cmp $t2 or lc $a cmp lc $b
        } keys %triggers
      )
    {
        my ( $trigger, $code, $type, $triggered, $trigger_error, $code_error ) = trigger_get($name);
        my %data;
        $data{name} = $name;
        $data{trigger} = $trigger;
        $data{type} = $type;
        $data{code} = $code;
        if ($triggered) {
            $data{triggered_ms} = $triggered;
            $data{triggered} = &time_date_stamp( 12, $triggered );            
            $data{triggered_rel} = &time_date_stamp( 23, $triggered );
           }
        push @dataset, \%data;
        }
        my %data2;
        $data2{data}  = \@dataset;
        $data2{options}{code} = ["speak","play","display","print_log","set","run","run_voice_cmd","net_im_send","net_mail_send"];
        $data2{options}{trigger} = ["time_now","time_cron","time_random","new_second","new_minute","new_hour",'$New_Hour','$New_Day','$New_Week','$New_Month','$New_Year'];
        $json_data{'triggers'} = \%data2;
    }

    # List packages
    if ( $path[0] eq 'packages' || $path[0] eq '' ) {
        my $ref = \%::;
        foreach my $key ( sort { lc $a cmp lc $b } keys %$ref ) {
            next unless $key =~ /.+::$/;
            next if $key eq 'main::';
            my $iref = ${$ref}{$key};
            my ( $k, $r ) = &json_walk_var( $iref, $key, qw( SCALAR ARRAY HASH CODE ) );
            $json_data{packages}{$k} = $r if $k ne "";
        }

    }

    # List Global vars
    if ( $path[0] eq 'vars' || $path[0] eq '' ) {
        my $ref = \%::;
        my %json_vars;
        foreach my $key ( sort { lc $a cmp lc $b } keys %$ref ) {
            next unless $key =~ /^[[:print:]]+$/;
            next if $key =~ /::$/;
            next if $key =~ /^.$/;
            next if $key =~ /^__/;
            next if $key =~ /^_</;
            next if $key eq 'ARGV';
            next if $key eq 'CARP_NOT';
            next if $key eq 'ENV';
            next if $key eq 'INC';
            next if $key eq 'ISA';
            next if $key eq 'SIG';
            next if $key eq 'User_Code';
            my $iref = ${$ref}{$key};

            # this is for constants
            $iref = $$iref if ref $iref eq 'SCALAR';
            
            
            eval {
                %json_vars = ( %json_vars, &json_walk_var( $iref, $key ) ); #wrap this in eval in case there is weird data
            };
            if ($@) {
                print_log "Json_Server.pl: WARNING: JSON variable parsing: $key failed to process";
            }
        }
        $json_data{vars} = \%json_vars;
    }
    
   if ( $path[0] eq 'vars_global' || $path[0] eq '' ) {
        my %json_vars_global;
        for my $key ( sort keys %main:: ) {

            # Assume all the global vars we care about are $Ab...
            next if $key !~ /^[A-Z][a-z]/ or $key =~ /\:/;
            next if $key eq 'Save'        or $key eq 'Tk_objects';    # Covered elsewhere
            next if $key eq 'Socket_Ports';
            next if $key eq 'User_Code';

            my $glob = $main::{$key};
	    next if (ref($glob) eq "CODE"); 			# Fix for MH crash 
            if ( ${$glob} ) {
                my $value = ${$glob};
                next if $value =~ /HASH/;                             # Skip object pointers
                next if $key eq 'Password';
                $value =~ s/[\r\n]+$//;
                #print "db: [$key -> $value]\n";
                $json_vars_global{$key} = $value;
            }
            elsif ( %{$glob} ) {
                for my $key2 ( sort keys %{$glob} ) {
                    my $value = ${$glob}{$key2};# . "\n";
                    $value = '' unless $value;                        # Avoid -w uninitialized value msg
                    $value =~ s/[\r\n]+$//;
                    next if $value =~ /HASH\(/;                         # Skip object pointers
                    next if $value =~ /ARRAY\(/;
                    #print "db: [$key\{$key2\} -> $value]\n";
                    $json_vars_global{"$key\{$key2\}"} = $value;
                }
            }
        }
        $json_data{vars_global} = \%json_vars_global;
    }
    
   if ($path[0] eq 'tagline' || $path[0] eq 'misc' || $path[0] eq '') {
        my $source = "tagline";
        $source = "misc" if ($path[0] eq 'misc');
        my $file;
        if ( -e "$config_parms{data_dir}/remarks/1100tags.txt" ) {
            $file = "$config_parms{data_dir}/remarks/1100tags.txt";
        } else {
            $file = "$Pgm_Root/data/remarks/1100tags.txt";
        }
        srand;
        my $tagline = "could not retrieve tagline";
        
        eval {
            open FILE, "<$file" or warn "Could not open filename: $!\n";
            rand($.)<1 and ($tagline=$_) while <FILE>;
            close FILE;
        };
        if ($@) {
            print_log "Json_Server.pl: WARNING: Could not open tagline file!";
        }        
        
        $json_data{$source}{tagline} = $tagline
   }

   if ( $path[0] eq 'web_counter' || $path[0] eq 'misc' || $path[0] eq '' ) {
        my $source = "web_counter";
        $source = "misc" if ($path[0] eq 'misc');

        $web_counter = 0 if (not defined $web_counter);
        $json_data{$source}{web_counter_session} = $web_counter;
        $json_data{$source}{web_counter_total} = $main::Save{"ia7_count_total"};

   }

   if ( $path[0] eq 'stats' || $path[0] eq 'misc' || $path[0] eq '' ) {
        my $source = "stats";
        $source = "misc" if ($path[0] eq 'misc');
        my $uptime;
        if ( $OS_win or $^O eq 'cygwin' ) {
            $uptime = "$Tk_objects{label_uptime_mh} &nbsp;&nbsp; $Tk_objects{label_uptime_cpu}";
        } else {
            $uptime = `uptime`;
        }
        my ($time,$upt,$users,$load) = $uptime =~ /(\S+)\s+up\s(.*),\s+(\d+)\susers?,\s+load\saverages?:\s(.*)/g;
        $json_data{$source}{time} = $time;
        $json_data{$source}{uptime} = $upt;
        $json_data{$source}{users} = $users;
        $json_data{$source}{load} = $load;
        $json_data{$source}{cores} = $System_cores;
        $json_data{$source}{time_of_day} = $Time_Of_Day;
        $json_data{$source}{sunrise} = $Time_Sunrise;
        $json_data{$source}{sunset} = $Time_Sunset;
   }

   if ( $path[0] eq 'weather' || $path[0] eq 'misc' || $path[0] eq '' ) {
        my $source = "weather";
        $source = "misc" if ($path[0] eq 'misc');
        my $enabled = 0;
        $enabled = 1 if (defined $Weather_Common::weather_module_enabled and $Weather_Common::weather_module_enabled=1);
        $json_data{$source}{barom} = $Weather{"Barom"};
        $json_data{$source}{summary} = $Weather{"Summary"};
        $json_data{$source}{summary_long} = $Weather{"Summary_Long"};
        $json_data{$source}{tempindoor} = $Weather{"TempIndoor"};
        $json_data{$source}{tempoutdoor} = $Weather{"TempOutdoor"};
        $json_data{$source}{wind} = $Weather{"Wind"};
        $json_data{$source}{clouds} = (lc $Weather{"Clouds"});
        $json_data{$source}{clouds} =~ s/^\s+|\s+$//g; #remove leading/trailing spaces
        $json_data{$source}{raining} = int($Weather{"IsRaining"});
        $json_data{$source}{snowing} = int($Weather{"IsSnowing"});
        $json_data{$source}{night} = $Dark;
        $json_data{$source}{weather_lastupdated} = $Weather{"LastUpdated"};
        $json_data{$source}{weather_enabled} = $enabled;
        $json_data{$source}{ForecastHigh} = $Weather{"ForecastHigh"};
        $json_data{$source}{ForecastLow} = $Weather{"ForecastLow"};        
        $json_data{$source}{ForecastConditions} = $Weather{"ForecastConditions"};       
             
   }

   if ( $path[0] eq 'vars_save' || $path[0] eq '' ) {
        my %json_vars_save;
        
        for my $key ( sort keys %Save ) {
            my $value = ( $Save{$key} ) ? $Save{$key} : '';
            $value =~ s/[\r\n]+$//;
            $json_vars_save{$key} = $value;
        }
 
        $json_data{vars_save} = \%json_vars_save;
    }    

    if ( $path[0] eq 'notifications' ) {
        for my $i ( 0 .. $#json_notifications ) {
            my $n_time = int( $json_notifications[$i]{time} );
            my $x      = $args{time}[0];                         #Weird, does nothing, but notifications doesn't work if removed...
            if (    ($n_time)
                and ( ( defined $args{time} && int( $args{time}[0] ) < $n_time ) ) )
            {
                push( @{ $json_data{'notifications'} }, $json_notifications[$i] );
            }
            else {
                #if older than X minutes, then remove the array values to keep things tidy
            }
        }
    }

    if ( $path[0] eq 'table_data' ) {
        if ( $args{var} ) {
            my $length = $#{ $json_table{ $args{var}[0] }->{data} } + 1;

            #need to check if vars and keys exist


            my $start = 0;
            $start = $args{start}[0] if ( $args{start}[0] );
            my $records = 0;
            my $page    = 0;
            my $page    = $json_table{ $args{var}[0] }{page} if ( defined $json_table{ $args{var}[0] }{page} );
            $records = $args{records}[0] if ( $args{records}[0] );

            # TODO: At some point have a hook that pulls in more data into the table if it's missing
            #  ie read a file

            my $jt_time = int( $json_table{ $args{var}[0] }{time} );
            if (   ( $args{time} && int( $args{time}[0] ) < $jt_time ) or ( !$args{time} ) ) {
                #need to copy all the data since we can adjust starts and records

                $json_data{'table_data'}{exist}       = $json_table{ $args{var}[0] }{exist};
                $json_data{'table_data'}{head}        = $json_table{ $args{var}[0] }{head};
                $json_data{'table_data'}{page_size}   = $json_table{ $args{var}[0] }{page_size};
                $json_data{'table_data'}{hook}        = $json_table{ $args{var}[0] }{hook};
                $json_data{'table_data'}{page}        = $page;
                #wrap this in an eval in case the data is bad to prevent crashes"
                eval {
                    @{ $json_data{'table_data'}->{data} } = map { [@$_] } @{ $json_table{ $args{var}[0] }->{data} };
                };
                if ($@) {
                    &::print_log("Json_Server.pl: ERROR: problems parsing table data for " . $args{var}[0]);
                } else {
                    splice @{ $json_data{'table_data'}->{data} }, 0, $args{start}[0] if ( $args{start}[0] );
                    splice @{ $json_data{'table_data'}->{data} }, $args{records}[0] if ( $args{records}[0] );
                    $json_data{'table_data'}{records} = scalar @{ $json_data{'table_data'}->{data} };
                }
            }
        }
    }

    # List print_log phrases
    if ( $path[0] eq 'print_log' || $path[0] eq '' ) {
        my @log;
        my $name;
        if ( $args{time}
            && int( $args{time}[0] ) < int( ::print_log_current_time() ) )
        {
            #Only return messages since time
            @log = ::print_log_since( $args{time}[0] );
        }
        elsif ( !$args{time} ) {
            @log = ::print_log_since();
        }
        if ( scalar(@log) > 0 ) {
            $json_data{'print_log'} = [];
            push( @{ $json_data{'print_log'} }, @log );
        }
    }

    if ( $path[0] eq 'fp_icon_sets' ) {
        my $p     = "../web/ia7/graphics/*default_" . $args{px}[0] . ".png";
        my @icons = glob($p);
        s/^..\/web// for @icons;
        $json_data{'icon_sets'} = [];
        push( @{ $json_data{'fp_icon_sets'} }, @icons );
    }

    # List speak phrases
    if ( $path[0] eq 'print_speaklog' || $path[0] eq '' ) {
        my ( @log, @tmp );
        my $name;
        if ( $args{time}
            && int( $args{time}[0] ) < int( ::print_speaklog_current_time() ) )
        {
            #Only return messages since time
            @log = ::print_speaklog_since( $args{time}[0] );
            push @log, '';    #TODO HP - Kludge, the javascript seems to want an extra line in the array for some reason
        }
        elsif ( !$args{time} ) {
            @log = ::print_speaklog_since();
        }
        if ( scalar(@log) > 0 ) {
            $json_data{'print_speaklog'} = [];
            push( @{ $json_data{'print_speaklog'} }, @log );
        }
    }

    print_log Dumper(%json_data) if $Debug{json};

    # Select appropriate data based on path request
    my $output_ref;
    if ( scalar(@path) > 0 ) {
        my @element_list = @path;    #Prevent Altering the Master Reference
        $output_ref = json_get_sub_element( \@element_list, \%json_data );
    }

    # If this is a long_poll and there is no data, simply return
    if ( $args{long_poll} && ( !$output_ref ) ) {
        return;
    }

    # Insert Data or Error Message
    if ($output_ref) {
        $json{data} = $output_ref;
    }
    else {
        $json{error}{msg} = 'No data, or path does not exist.';
    }

    #Insert Meta Data fields
    $json{meta}{time}      = $output_time;
    $json{meta}{path}      = \@path;
    $json{meta}{args}      = \%args;
    $json{meta}{client_ip} = $HttpHeader{Client_address};

    my $json_raw = JSON->new->allow_nonref;

    # Translate special characters
    $json_raw->canonical(1);    #Order the data so that objects show alphabetically
    $json_raw = $json_raw->pretty->encode( \%json );
    return &json_page($json_raw,%HttpHeader);

}

sub json_get_sub_element {
    my ( $element_ref, $json_ref, $error_path ) = @_;
    my $out_ref = {};
    $error_path = "/" unless $error_path;
    my $path = shift( @{$element_ref} );
    $error_path .= $path . "/";
    if ( ref $json_ref eq 'HASH' && exists $json_ref->{$path} ) {
        if ( scalar( @{$element_ref} ) > 0 ) {
            return json_get_sub_element( $element_ref, $json_ref->{$path}, $error_path );
        }
        else {
            #This is the end of the line
            $out_ref = $json_ref->{$path};

            #Check if this ref is empty
            if ( ref $out_ref eq 'ARRAY' && scalar( @{$out_ref} ) == 0 ) {
                return;
            }
            elsif ( ref $out_ref eq 'HASH' && ( !%{$out_ref} ) ) {
                return;
            }
            return $out_ref;
        }
    }
    else {
        return;
    }
}

sub json_walk_var {
    my ( $ref, $name, @types ) = @_;
    my ( %json_vars, $iname, $iref );
    @types = qw( ARRAY HASH SCALAR ) unless @types;
    my $type  = ref $ref;
    my $rtype = ref \$ref;
    my $json_vars;
    $ref = "$type", $ref = \$ref, $type = 'SCALAR' if $type =~ /\:\:/;
    print_log "json: r $ref n $name t $type rt $rtype" if $Debug{json};
    return if $type eq 'REF';

    if ( $type eq 'GLOB' or $rtype eq 'GLOB' ) {
        foreach my $slot (@types) {
            my $iref = *{$ref}{$slot};
            next unless $iref;
            unless ($slot eq 'SCALAR'
                and not defined $$iref
                and ( *{$ref}{ARRAY} or *{$ref}{CODE} or *{$ref}{HASH} ) )
            {
                eval {
                    %json_vars = &json_walk_var( $iref, $name, @types ); #wrap this in eval in case there is weird data
                };
                if ($@) {
                    print_log "Json_Server.pl: WARNING: JSON variable parsing: $name failed to process";
                }
            }
        }
        return %json_vars;
    }

    my ( $iref, $iname );
    $name = encode_entities($name);

    if ( $type eq '' ) {
        my $value = $ref;
        $value = undef unless defined $value;
        return ( "$name", $value );
    }
    elsif ( $type eq 'SCALAR' ) {
        my $value = $$ref;
        $value = undef unless defined $value;
        if ( $name =~ m/::(.*?)$/ ) {
            $name = $1;
        }
        if ( $name =~ m/\[(\d+?)\]$/ ) {
            my $index = $1;
            return $index, $value;
        }
        elsif ( $name =~ m/.*?\{'(.*?)'\}$/ ) {
            my $cls = $1;
            if ( $cls =~ m/\}\{/ ) {
                my @values = split( '\'}\{\'', $cls );
                foreach my $val (@values) {
                    $value = "Unusable Object" if ref $value;
                    return $val, $value;
                }
            }
            else {
                return "$cls", $value;
            }
        }
        else {
            return ( "$name", $value );
        }
    }
    elsif ( $name =~ /.::$/ ) {
        foreach my $key ( sort keys %$ref ) {
            $iname = "$name$key";
            $iref  = ${$ref}{$key};
            $iref  = \${$ref}{$key} unless ref $iref;
            my ( $k, $r );
            eval {
                ($k, $r)  = &json_walk_var( $iref, $iname, @types );; #wrap this in eval in case there is weird data
            };
            if ($@) {
                print_log "Json_Server.pl: WARNING: JSON variable parsing: $iname failed to process";
            }
            $json_vars{$name} = $r if $k ne "";
        }
    }
    elsif ( $type eq 'ARRAY' ) {
        foreach my $key ( 0 .. @$ref - 1 ) {
            $iname = "$name\[$key\]";
            $iref  = \${$ref}[$key];
            $iref  = ${$ref}[$key] if ref $iref eq 'REF';
            my ( $k, $r );
            eval {
                ($k, $r)  = &json_walk_var( $iref, $iname, @types );; #wrap this in eval in case there is weird data
            };
            if ($@) {
                print_log "Json_Server.pl: WARNING: JSON variable parsing: $iname failed to process";
            }
            $json_vars{$name}{$k} = $r;
        }
    }
    elsif ( $type eq 'HASH' ) {
        foreach my $key ( sort keys %$ref ) {
            $iname = "$name\{'$key'\}";
            $iref  = \${$ref}{$key};
            $iref  = ${$ref}{$key} if ref $iref eq 'REF';
            my ( $k, $r );
            eval {
                ($k, $r)  = &json_walk_var( $iref, $iname, @types );; #wrap this in eval in case there is weird data
            };
            if ($@) {
                print_log "Json_Server.pl: WARNING: JSON variable parsing: $iname failed to process";
            }            $json_vars{$name}{$key} = $r;
        }
    }
    elsif ( $type eq 'CODE' ) {
    }
    print_log Dumper(%json_vars) if $Debug{json};
    return %json_vars;
}

sub build_parent_table {
    my @groups;
    my %parent_table;
    for my $group_name ( &list_objects_by_type('Group') ) {
        my $group = &get_object_by_name($group_name);
        $group_name =~ s/\$|\%|\&|\@//g;
        unless ( defined $group ) {
            print_log "json: build_parent_table, group_name $group_name doesn't have an object?" if $Debug{json};
            next;
        }
        else {
            for my $object ( $group->list( undef, undef, 1 ) ) {
                my $obj_name = $object->get_object_name;
                push( @{ $parent_table{$obj_name} }, $group_name );
            }
        }
    }
    return \%parent_table;
}

sub json_object_detail {
    my ( $object, $args_ref, $fields_ref, $parent_table ) = @_;

    # Use our own arguments hash so we can modify it
    my %args   = %{$args_ref};
    my %fields = %{$fields_ref};

    # Skip this process if all fields are specifically excluded
    return if exists $fields{none};

    my $ref = ref \$object;
    return unless $ref eq 'REF';

    #return if $object->can('hidden') and $object->hidden; #Not sure about this, HP - should just return a hidden property
    my $object_name = $object->{object_name};

    # Skip object if time arg supplied and not changed
    if ( $args{time} && $args{time}[0] > 0 ) {

        # Idle times are only reported in seconds
        my $request_time = int( $args{time}[0] / 1000 );       # Convert to seconds
        my $current_time = int( ::get_tickcount() / 1000 );    # Convert to seconds

        if ( !( $object->can('get_idle_time') ) ) {

            #Items that do not have an idle time do not get reported at all in updates
            return;
        }
        elsif ( $object->get_idle_time eq '' ) {

            #Items that have NEVER been set to a state have a null idle time
            return;
        }
        elsif ( ( $request_time - 1 ) > ( $current_time - $object->get_idle_time ) ) {

            #To avoid missed changes, since they can happen at the millisecond level, give a second's cushion
            #Object has not changed since time, so return undefined
            return;
        }        
    }

    my %json_objects;
    my %json_complete_object;
    my @f = qw( category filename measurement rf_id set_by members
      state states state_log type label sort_order groups hidden parents schedule logger_status
      idle_time text html seconds_remaining fp_location fp_icons fp_icon_set img link level rgb rrd state_override);

    # Build list of fields based on those requested.
    foreach my $f ( sort @f ) {

        # Lets skip fields that are neither called for nor filtered on
        next unless ( $fields{all} or $fields{$f} or $args{$f} );

        my $value;
        my $method = $f;
        if (
            $object->can($method)
            or ( ( $method = 'get_' . $method )
                and $object->can($method) )
          )
        {
        
            if ( $f eq 'type' ) {

                # We need to hard code type, b/c x10 has a subroutine called
                # type that screws with us.
                $method = 'get_type';
            }
            if ( $f eq 'states' or $f eq 'state_log' or $f eq 'fp_location' ) {
                my @a = $object->$method;
                $value = \@a;
            }
            elsif ( $f eq 'fp_icons' ) {
                my %a = $object->$method;

                #my @b;
                #foreach my $key (sort(keys %a)) {
                #	push (@b, "$key : $a{$key}") if ($key);
                #}
                $value = \%a
                  unless ( exists $a{""} );    #don't return a null value
            }

            elsif ( $f eq 'link' ) {
                my $a = $object->$method;

                $value = $a if ( defined $a and $a ne "" );    #don't return a null value
            }
            
            elsif ( $f eq 'rrd' ) {
                my $a = $object->$method;
                $a =  (split( /\/|\\/, $a))[-1];    #just take the filename
                my $b = $object->get_rrd_ds();
                $value = $a . ":" . $b if ( defined $a and $a ne "" );    #don't return a null value
            }

            elsif ( $f eq 'rgb' ) {
                my ($a,$b,$c) = $object->$method;

                $value = "$a,$b,$c" if (( defined $a and $a ne "" )    #don't return a null value
                                        and ( defined $b and $b ne "" )
                                        and ( defined $c and $c ne "" ));
            }

            #if ( $f eq 'hidden' ) {
            #	my $a = $object->$method;
            #	if ($a == 1 or $a eq "1") {
            #		print_log "json true";
            #	 } else {
            #		print_log "json false";
            #	 }
            #}
            else {
                $value = $object->$method;
                #RF this makes a horlicks of utf8 characters
                $value = encode_entities( $value, "\200-\377&<>" );
                $value = encode_entities( $value, '<>&"');

            }
            print_log "json: object_dets f $f m $method v $value" if $Debug{json};
        }
        elsif ( $f eq 'members' ) {
            ## Currently only list members for group items, but at some point we
            ## can add linked items too.
            if ( ref($object) eq 'Group' ) {
                $value = [];
                my @tmp;    ## pull all the members into a temp array that can be sorted
                for my $obj_name ( &list_objects_by_group( $object->get_object_name, 1 ) ) {
                    $obj_name =~ s/\$|\%|\&|\@//g;

                    #push (@{$value}, $obj_name);
                    push( @tmp, $obj_name );
                }
                push( @{$value}, sort @tmp );
            }
        }
        elsif ( $f eq 'parents' ) {
            $value = [];
            for my $group_name ( $$parent_table{$object_name} ) {
                $value = $group_name;
            }
        }
        elsif ( exists $object->{$f} ) {
            $value = $object->{$f};
            #RF this makes a horlicks of utf8 characters
            $value = encode_entities( $value, "\200-\377&<>" );
            $value = encode_entities( $value, '<>&"');

            print_log "json: object_dets f $f ev $value" if $Debug{json};
        }
        elsif ( $f eq 'html' and $object->can('get_type') ) {
            $value = "<!\[CDATA\[" . &html_item_state( $object, $object->get_type ) . "\]\]>";
            print_log "json: object_dets f $f" if $Debug{json};
        }
        else {
            print_log "json: object_dets didn't find $f" if $Debug{json};
        }

        if ( ( $fields{all} or $fields{$f} ) && defined $value ) {
            $json_objects{$f} = $value;
        }
        $json_complete_object{$f} = $value;
    }

    if ( filter_object( \%json_complete_object, $args_ref ) ) {
        return \%json_objects;
    }
    else {
        return;
    }
}

sub filter_object {
    my ( $object, $args_ref ) = @_;
    my %args = %{$args_ref};

    # Check if object has required parameters
    for my $f ( keys %args ) {

        # Skip special fields
        next if ( lc($f) eq 'time' );
        next if ( lc($f) eq 'fields' );
        next if ( lc($f) eq 'long_poll' );
        next
          if ( lc($f) eq 'items' );    #HP, we should already have parsed the items
        next if ( $f eq '' );
        if ( $$object{$f} ) {
            for my $test_val ( @{ $args{$f} } ) {
                if ( ref $$object{$f} eq 'ARRAY' ) {
                    my $notfound = 1;
                    for ( @{ $$object{$f} } ) {
                        if ( $test_val eq $_ ) {
                            $notfound = 0;
                            last;
                        }
                    }
                    return if ($notfound);
                }
                elsif ( $test_val ne $$object{$f} ) {

                    # Required value was not a match
                    # not sure how the same value could equal an array of values
                    # but leave here for possible future expansion
                    return;
                }
            }
        }
        else {
            #Object lacks the required field
            return 0;
        }
    }
    return 1;
}

sub json_page {
    my ($json_raw,%HttpHeader) = @_;
    my $json = $json_raw;
    gzip \$json_raw => \$json if &::http_gzip(%HttpHeader);


##    utf8::encode( $json_raw ); #may need to wrap gzip in an eval and encode it if errors develop. It crashes if a < is in the text
    my $output = "HTTP/1.1 200 OK\r\n";
    $output .= "Server: MisterHouse\r\n";
    $output .= "Connection: close\r\n";    
    $output .= "Content-type: application/json\r\n";
    $output .= "Connection: close\r\n" if &http_close_socket(%HttpHeader);
    $output .= "Content-Encoding: gzip\r\n" if &::http_gzip(%HttpHeader);
    $output .= "Content-Length: " . ( length $json ) . "\r\n";
    $output .= "Date: " . time2str(time) . "\r\n";
    $output .= "\r\n";
    $output .= $json;

    return $output;
}

sub json_entities_encode {
    my $s = shift;
    $s =~ s/\&/&amp;/g;
    $s =~ s/\</&lt;/g;
    $s =~ s/\>/&gt;/g;
    $s =~ s/\'/&apos;/g;
    $s =~ s/\"/&quot;/g;
    return $s;
}

sub json_usage {
    my $html = <<eof;
<html>
<head>
</head>

<body>
<h2>JSON Server</h2>
eof
    my @requests = qw( types groups categories config_parms socket_ports
      user_code weather save objects photos subs menus triggers packages vars print_log print_speaklog);

    my %args = (
        fields => { applyto => 'types|groups|categories|objects', },
        time   => { applyto => 'print_log|print_speaklog', }
    );
    foreach my $r (@requests) {
        my $url = "/sub?json($r)";
        $html .= "<h2>$r</h2>\n<p><a href='$url'>$url</a></p>\n<ul>\n";
        foreach my $opt ( sort keys %args ) {
            if ( $args{$opt}{applyto} eq 'all' or grep /^$r$/, split /\|/, $args{$opt}{applyto} ) {
                $url = "/sub?json($r,$opt";
                if ( defined $args{$opt}{example} ) {
                    foreach ( split /\|/, $args{$opt}{example} ) {
                        print_log "json: r $r opt $opt ex $_" if $Debug{json};
                        $html .= "<li><a href='$url=$_)'>$url=$_)</a></li>\n";
                    }
                }
                else {
                    $html .= "<li><a href='$url)'>$url)</a></li>\n";
                }
            }
        }
        $html .= "</ul>\n";
    }
    $html .= <<eof;
</body>
</html>
eof
 my $html_head = "HTTP/1.1 200 OK\r\n";
 $html_head .= "Server: MisterHouse\r\n";
 $html_head .= "Content-type: application/json\r\n";
 $html_head .= "Connection: close\r\n" if &http_close_socket;
 $html_head .= "Content-Length: " . ( length $html ) . "\r\n";
 $html_head .= "Date: " . time2str(time) . "\r\n";
 $html_head .= "\r\n";


    return $html_head.$html;
}

sub json_write_file {
    my ($name,$body, @files) = @_; 
        my $response_code;
        my $response_text;  
        my $file_found = 0;
        my $file_error = 0;
        foreach my $file (@files) {
            &main::print_log( "Checking $file...");
            if (-e $file) {
                my $file_data = to_json( $body, { utf8 => 1, pretty => 1 } );
                my $backup_file = $file . ".J" . int( ::get_tickcount() / 1000 ) . ".backup";
                copy ($file, $backup_file) or $file_error = 1;
                unless ($file_error) {
                    &main::print_log( "Writing to $file...");
                    &main::file_write( $file, $file_data );
#TODO get error code from file_write
                }
                $file_found = 1;
                last;
            }
        }
        if ($file_error) {
            $response_code = "HTTP/1.1 500 Internal Server Error OK\r\n";
            $response_text->{status} = "error";
            $response_text->{text} = "Error saving file or backup"; 
            &main::print_log( "Json_Server.pl: ERROR." . $response_text->{text});
        
        } else {
             if ($file_found) {
                 $response_code = "HTTP/1.1 200 OK\r\n";
                 $response_text->{status} = "success";
                 $response_text->{text} = "";             
             } else {
                 $response_code = "HTTP/1.1 500 Internal Server Error\r\n";
                 $response_text->{status} = "error";
                 $response_text->{text} = "Could not find " . $name . " file";    
                 &main::print_log( "Json_Server.pl: ERROR." . $response_text->{text});                           
             }  
        }
    return ($response_code, $response_text);
}      

sub json_table_create {
    my ($key) = @_;

    return 0 if ( defined $json_table{$key}{exist} );

    $json_table{$key}{exist} = 1;
    return 1;
}

sub json_table_delete {
    my ($key) = @_;

    return 0 if ( !defined $json_table{$key}{exist} );

    $json_table{$key} = {};
    return 1;
}

sub json_table_put_header {
    my ( $key, $pos, $value ) = @_;

    return 0 if ( !defined $json_table{$key}{exist} );

    $json_table{$key}{head}[$pos] = $value;
    return 1;
}

sub json_table_get_header {
    my ( $key, $pos ) = @_;

    return 0 if ( !defined $json_table{$key}{exist} );

    return $json_table{$key}{head}[$pos];
}

sub json_table_put_data {
    my ( $key, $posx, $posy, $value ) = @_;

    return 0 if ( !defined $json_table{$key}{exist} );

    $json_table{$key}{data}[$posx][$posy] = $value;
    return 1;
}

sub json_table_get_data {
    my ( $key, $posx, $posy ) = @_;

    return 0 if ( !defined $json_table{$key}{data}[$posx][$posy] );

    return $json_table{$key}{data}[$posx][$posy];
}

sub json_table_push {
    my ($key) = @_;

    return 0 if ( !defined $json_table{$key} );
    	
    $json_table{$key}{time} = &get_tickcount;
    return 1;
}

sub json_table_insert_data_row {

    # insert a row at a given location
    my ( $key, $posx, @posy ) = @_;

    return 0 if ( !defined $json_table{$key}{exist} );

    splice @{ $json_table{$key}{data} }, $posx, 0, @posy;

    return 1;
}

sub json_table_delete_data_row {

    # will shrink array
    my ( $key, $posx ) = @_;

    return 0 if ( !defined $json_table{$key}{exist} );

    splice @{ $json_table{$key}{data} }, $posx;

    return 1;
}

sub json_table_get_table_length {

    # number of rows contained
    my ($key) = @_;

    return 0 if ( !defined $json_table{$key}{exist} );

    my $length = $#{ $json_table{$key}->{data} } + 1;

    return $length;
}

sub json_table_set_page_size {
    my ( $key, $length ) = @_;

    return 0 if ( !defined $json_table{$key}{exist} );

    $json_table{$key}{page_size} = $length;

    return 1;
}

sub json_table_get_page_size {
    my ($key) = @_;
    return 0 if ( !defined $json_table{$key}{exist} );

    if ( defined $json_table{$key}{page_size} ) {
        return $json_table{$key}{page_size};
    }
    else {
        return 0;
    }
}

sub json_table_set_fetch_routine {

    # what code to pull new data in.
    my ( $key, $code ) = @_;

    return 0 if ( !defined $json_table{$key}{exist} );

    $json_table{$key}{hook} = $code;

    return 0;
}

sub json_table_fetch_data {
    my ( $key, $posx, $records ) = @_;

    return 0 if ( !defined $json_table{$key}{hook} );

    my @data;
    eval( @data = &{ $json_table{$key}{hook} }( $posx, $records ) );
    if ($@) {
        print_log "Json_Server.pl: WARNING: fetch data failed for " . $key . " " . $json_table{$key}{hook} . "!";
        return 0;
    }
    my $l = &json_get_table_length($key) + 1;
    my $r = 0;
    foreach my $row (@data) {
        my $e = 0;
        foreach my $element (@$row) {
            &json_table_put_data( $r + $l, $e, $data[$r][$e] );
            $e++;
        }
        $r++;
    }
    &json_table_push($key);
    return 0;
}

sub json_table_purge_data {
    my ( $key, $posx, $records ) = @_;
}

sub json_notification {
    my ( $type, $data ) = @_;
    $data->{type} = $type;
    $data->{time} = &::get_tickcount;
    for my $i ( 0 .. $#json_notifications ) {

        #clean up any old notifications, or empty entries (ie less than 5 seconds old)
        my $n_time = int( $json_notifications[$i]{time} );    
        if (   ( &get_tickcount > $n_time + 5000 )
            or ( !defined $json_notifications[$i]{time} ) )
        {
            splice @json_notifications, $i, 1;
        }
    }
    push (@json_notifications, $data);
}

sub config_checker {
    my ($file) = @_;

    my ( %collections, $key, $output, $temp );
    my @data = file_read($file);

    foreach my $row (@data) {
        $key = $1 if $row =~ /\"(\d+?)\" \:/;
        $row =~ /\"(.+?)\" \: \"(.+?)\"/;
        $collections{$key}{$1} = $2 if $1;
    }

    foreach my $row (@data) {
        $key = $1 if $row =~ /\"(\d+?)\" \:/;
        if ( $row =~ /(\d+?)(\,|\n)/ ) {
            my $sub_key = $1;
            my $comma   = $2;
            $collections{$key}{children} .= "\t$1: ";
            $collections{$key}{children} .= "$collections{$sub_key}{name}";
            $collections{$key}{children} .= "\n";
        }
    }

    #foreach $key (sort check_numerically keys %collections) {
    #	$output .= "$key: $collections{$key}{name}:$collections{$key}{link}$collections{$key}{external}$collections{$key}{iframe}:$collections{$key}{comment}:$collections{$key}{mode}:$collections{$key}{children}";
    #}

    my ( $row, $show_row, $bracket_errors, $comma_errors1, $comma_errors2, %brackets, $curly, $square );
    $curly  = 'closed';
    $square = 'closed';

    while ( $row < @data ) {
        $show_row = $row + 1;
        $data[$row] =~ s/\s+$//;    # remove trailing spaces
        if ( $data[$row] =~ /\{/ and $data[$row] !~ /iframe|external/ ) {
            $brackets{open_curly}++;
            $bracket_errors .= "Repeated open curly bracket in line $show_row: '$data[$row]'\n"
              if $curly and $curly eq 'open';
            $curly = 'open';
        }
        if ( $data[$row] =~ /\}/ and $data[$row] !~ /iframe|external/ ) {
            $brackets{close_curly}++;
            $bracket_errors .= "Repeated close curly bracket in line $show_row: '$data[$row]'\n"
              if $curly eq 'closed';
            $curly = 'closed';
        }
        if ( $data[$row] =~ /\[/ ) {
            $brackets{open_square}++;
            $bracket_errors .= "Repeated open square bracket in line $show_row: '$data[$row]'\n"
              if $square eq 'open';
            $square = 'open';
        }
        if ( $data[$row] =~ /\]/ ) {
            $brackets{close_square}++;
            $bracket_errors .= "Repeated close square bracket in line $show_row: '$data[$row]'\n"
              if $square eq 'closed';
            $square = 'closed';
        }

        $comma_errors1 .= $row + 1 . ": '$data[$row]'\n"
          if $data[$row] !~ /\, *$/
          and $data[ $row + 1 ] !~ /(\}|\])/
          and $data[$row] !~ /\: (\{|\[)/
          and $data[$row] !~ /^\{/
          and $data[$row] !~ /\}$/;

        $comma_errors2 .= $row + 1 . ": '$data[$row]'\n"
          if $data[$row] =~ /\,/ and $data[ $row + 1 ] =~ /(\}|\])\,/;

        $row++;
    }

    $output .= "Possible bracket errors:\n$bracket_errors\n" if $bracket_errors;
    $output .= "The following lines should possibly have a comma at the end:\n$comma_errors1\n"
      if $comma_errors1;
    $output .= "The following lines should possibly not have a comma at the end:\n$comma_errors2\n"
      if $comma_errors2;

    $output .= "There are $brackets{open_square} '[' and $brackets{close_square} ']'.\n";
    $output .= "There are $brackets{open_curly} '{' and $brackets{close_curly} '}'.\n";

    print_log $output;
}

sub check_numerically { $a <=> $b }

return 1;    # Make require happy

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut
