
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

use strict;

use RRDTool::Rawish;
use HTML::Entities;    # So we can encode characters like <>& etc
use JSON qw(decode_json);
use IO::Compress::Gzip qw(gzip);
use vars qw(%json_table);

sub json {
    my ( $request_type, $path_str, $arguments, $body ) = @_;

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

    if ( lc($request_type) eq "get" ) {
        return json_get( $request_type, \@path, \%args, $body );
    }
    elsif ( lc($request_type) eq "put" ) {
        json_put( $request_type, \@path, \%args, $body );
    }
}

# Handles Put (UPDATE) Requests
sub json_put {
    my ( $request_type, $path, $arguments, $body ) = @_;
    my (%json);
    my %args        = %{$arguments};
    my @path        = @{$path};
    my $output_time = ::get_tickcount();
    $body = decode_json($body);

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
    return &json_page($json_raw);
}

# Handles Get (READ) Requests
sub json_get {
    my ( $request_type, $path, $arguments, $body ) = @_;

    my %args = %{$arguments};
    my @path = @{$path};
    my ( %json, %json_data, $json_vars, $json_objects );
    my $output_time = ::get_tickcount();

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
            $json_data{'collections'} = decode_json($json_collections)
              ;    #HP, wrap this in eval to prevent MH crashes
        };
        if ($@) {
            print_log
              "Json_Server.pl: WARNING: decode_json failed for collection.json. Please check this file!";
            $json_data{'collections'} =
              decode_json('{ "0" : { "name" : "error" } }')
              ;    #write a blank collection

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
            $json_data{'ia7_config'} =
              decode_json($prefs);  #HP, wrap this in eval to prevent MH crashes
        };
        if ($@) {
            print_log
              "Json_Server.pl: WARNING: decode_json failed for ia7_config.json. Please check this file!";
            $json_data{'ia7_config'} =
              decode_json('{ "prefs" : { "status" : "error" } }')
              ;                     #write a blank collection

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
            $json_data{'rrd_config'} =
              decode_json($prefs);  #HP, wrap this in eval to prevent MH crashes
        };
        if ($@) {
            print_log
              "Json_Server.pl: WARNING: decode_json failed for ia7_rrd_config.json. Please check this file!";
        }
    }

    # RRD data routines
    if ( $path[0] eq 'rrd' || $path[0] eq '' ) {
        my $path = "$config_parms{data_dir}/rrd";
        $path = $json_data{'rrd_config'}->{'prefs'}->{'path'}
          if ( defined $json_data{'rrd_config'}->{'prefs'}->{'path'} );
        my $rrd_file = "weather.rrd";
        $rrd_file = $json_data{'rrd_config'}->{'prefs'}->{'default_rrd'}
          if ( defined $json_data{'rrd_config'}->{'prefs'}->{'default_rrd'} );
        my $default_cf = "AVERAGE";
        $default_cf = $json_data{'rrd_config'}->{'prefs'}->{'default_cf'}
          if ( defined $json_data{'rrd_config'}->{'prefs'}->{'default_cf'} );

        my @dss      = ();
        my @defs     = ();
        my @xports   = ();
        my @dataset  = ();
        my $index    = 0;
        my @round    = ();
        my @type     = ();
        my $celsius  = 0;
        my $arg_time = 0;
        $arg_time = int( $args{time}[0] ) if ( defined int( $args{time}[0] ) );
        $celsius = 1 if ( $config_parms{weather_uom_temp} eq 'C' );
        $celsius = 1
          if ( lc $json_data{'rrd_config'}->{'prefs'}->{'uom'} eq "celsius" );
        my %data;
        my $end = "now";

        if ( defined $args{start}[0] ) {

            my $start = $args{start}[0];
            $end = $args{end}[0] if ( defined $args{end}[0] );

            #go through all the defined DSs and if the group name and stash in $args{ds} the array of DSs

            if ( defined $args{group}[0] ) {
                @{ $args{ds} } = ();    #override any DSs specified in the URL
                for my $dsg ( keys %{ $json_data{'rrd_config'}->{'ds'} } ) {
                    if (
                        defined $json_data{'rrd_config'}->{'ds'}->{$dsg}
                        ->{'group'} )
                    {
                        foreach my $group ( split /,/,
                            $json_data{'rrd_config'}->{'ds'}->{$dsg}->{'group'}
                          )
                        {
                            push @{ $args{ds} }, $dsg
                              if ( lc $group ) eq ( lc $args{group}[0] );
                        }
                    }
                }
            }

            foreach my $ds ( @{ $args{ds} } ) {
                push @dss, $ds;

                #if it doesn't exist as a ds then skip
                my $cf = $default_cf;
                $cf = $json_data{'rrd_config'}->{'ds'}->{$ds}->{'cf'}
                  if (
                    defined $json_data{'rrd_config'}->{'ds'}->{$ds}->{'cf'} );
                push @defs,   "DEF:$ds=$path/$rrd_file:$ds:$cf";
                push @xports, "XPORT:$ds";
                $dataset[$index]->{'label'} =
                  $json_data{'rrd_config'}->{'ds'}->{$ds}->{'label'}
                  if (
                    defined $json_data{'rrd_config'}->{'ds'}->{$ds}->{'label'}
                  );
                $dataset[$index]->{'color'} =
                  $json_data{'rrd_config'}->{'ds'}->{$ds}->{'color'}
                  if (
                    defined $json_data{'rrd_config'}->{'ds'}->{$ds}->{'color'}
                  );
                if (
                    lc $json_data{'rrd_config'}->{'ds'}->{$ds}->{'type'} eq
                    "bar" )
                {
                    $dataset[$index]->{'bars'}->{'show'}      = "true";
                    $dataset[$index]->{'bars'}->{'fill'}      = "0";
                    $dataset[$index]->{'bars'}->{'lineWidth'} = 0;

                    #$dataset[$index]->{'bars'}->{'barWidth'} = 8 * 60 * 60 * 1000;  #calculate barwidth based on data range
                    #TODO - bar width on data range
                    $dataset[$index]->{'bars'}->{'fillColor'}->{'colors'}[0]
                      ->{'opacity'} = 0.3;
                    $dataset[$index]->{'bars'}->{'fillColor'}->{'colors'}[1]
                      ->{'opacity'} = 0.3;
                    $dataset[$index]->{'yaxis'} = 2;
                }
                else {
                    $dataset[$index]->{'lines'}->{'show'} = "true";
                }
                $round[$index] =
                  $json_data{'rrd_config'}->{'ds'}->{$ds}->{'round'}
                  if (
                    defined $json_data{'rrd_config'}->{'ds'}->{$ds}->{'round'}
                  );
                $type[$index] =
                  $json_data{'rrd_config'}->{'ds'}->{$ds}->{'type'}
                  if (
                    defined $json_data{'rrd_config'}->{'ds'}->{$ds}->{'type'} );
                $index++;
            }

            push @defs, @xports;

            #print "defs=" . join (',',@defs) . "\n";
            #print "start=$start end=$end\n";

            my $rrd = RRDTool::Rawish->new( rrdfile => "$path/$rrd_file" );
            my $xml =
              $rrd->xport( [@defs], { '--start' => $start, '--end' => $end, } );
            my @lines = split /\n/, $xml;

            foreach my $line (@lines) {

                #print "line=$line\n";
                my ($step) = $line =~ /\<step\>(\d+)\<\/step\>/
                  ;    #this is the width for any bar charts
                if ($step) {
                    for my $i ( 0 .. $#dataset ) {
                        $dataset[$i]->{'bars'}->{'barWidth'} =
                          int($step) * 1000
                          if ( defined $dataset[$i]->{'bars'} );
                    }
                }
                my ($time) = $line =~ /\<row\>\<t\>(\d*)\<\/t\>/;
                $time = $time * 1000;    #javascript is in milliseconds

                #print "time=$time, $arg_time\n";
                next if ( $arg_time > int($time) );    #only return new items
                my (@values) = $line =~ /\<v\>(-?[e.+-\d]*|NaN)\<\/v\>/g;
                if ($time) {

                    #print "line=$line\n";
                    #print "[$time";
                    my $index = 0;
                    foreach my $value (@values) {
                        my $value1 = sprintf( "%.10g", $value );

                        #print "index=$index,value=$value,value1=$value1,";
                        $value1 = ( $value1 - 32 ) * ( 5 / 9 )
                          if (  ($celsius)
                            and ( lc $type[$index] eq "temperature" ) );
                        $value1 =
                          sprintf( "%." . $round[$index] . "f", $value1 )
                          if ( defined $round[$index] );

                        #print "value1=$value1";
                        $value1 =~ s/\.0*$//
                          unless ( $value1 == 0 )
                          ;    #remove unneccessary trailing decimals
                        $value1 = "null" if ( lc $value1 eq "nan" );

                        #print "value1=$value1\n";
                        #my @array = ();
                        #$array[0] = $time;
                        #$array[1] = $value1;
                        ##push @{$dataset[$index]->{data}},"$time,$value1"; ###Need to get a 2d array here####***
                        push @{ $dataset[$index]->{data} }, [ $time, $value1 ];

                        #push @{$dataset[$index]->{data}},@array;
                        $index++;
                    }
                }
            }
        }
        $data{'data'}    = \@dataset;
        $data{'options'} = $json_data{'rrd_config'}->{'options'}
          if ( defined $json_data{'rrd_config'}->{'options'} );
        $data{'periods'} = $json_data{'rrd_config'}->{'periods'}
          if ( defined $json_data{'rrd_config'}->{'periods'} );

        #$json_data{'rrd'} = \@dataset;
        $json_data{'rrd'} = \%data;

        #print Dumper %data;
    }

    # List objects
    if ( $path[0] eq 'objects' || $path[0] eq '' ) {
        $json_data{objects} = {};
        my @objects;

        # Building the list of parent groups for each object
        # we could use &::list_groups_by_object() for each object, but that sub
        # is time consuming, particularly when called numerous times.  Instead,
        # we create a lookup table one time, saving a lot of processing time.
        my $parent_table = build_parent_table();

        if ( $args{items} && $args{items}[0] ne "" ) {
            foreach my $name ( @{ $args{items} } ) {

                #$name =~ s/\$|\%|\&|\@//g;
                my $o = &get_object_by_name($name);
                print_log "json: object name=$name ref=" . ref $o
                  if $Debug{json};
                if ( my $data =
                    &json_object_detail( $o, \%args, \%fields, $parent_table ) )
                {
                    $json_data{objects}{$name} = $data;
                }
            }
        }
        else {

            # Restrict object list by type here to make things faster
            if ( $args{type} ) {
                for ( @{ $args{type} } ) {
                    push @objects, &list_objects_by_type($_);
                }
            }
            else {
                foreach my $object_type ( list_object_types() ) {
                    push @objects, &list_objects_by_type($object_type);
                }
            }
            foreach my $o ( map { &get_object_by_name($_) } sort @objects ) {
                next unless $o;
                my $name = $o;
                $name = $o->{object_name};
                $name =~ s/\$|\%|\&|\@//g;
                print_log "json: object name=$name ref=" . ref $o
                  if $Debug{json};
                if ( my $data =
                    &json_object_detail( $o, \%args, \%fields, $parent_table ) )
                {
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
                if ( filter_object( $temp_object, \%args ) ) {
                    $json_data{objects}{$category} = $temp_object;
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
                if ( filter_object( $temp_object, \%args ) ) {
                    $json_data{objects}{$type} = $temp_object;
                }
            }
        }
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

    # List packages
    if ( $path[0] eq 'packages' || $path[0] eq '' ) {
        my $ref = \%::;
        foreach my $key ( sort { lc $a cmp lc $b } keys %$ref ) {
            next unless $key =~ /.+::$/;
            next if $key eq 'main::';
            my $iref = ${$ref}{$key};
            my ( $k, $r ) =
              &json_walk_var( $iref, $key, qw( SCALAR ARRAY HASH CODE ) );
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
            my $iref = ${$ref}{$key};

            # this is for constants
            $iref = $$iref if ref $iref eq 'SCALAR';
            %json_vars = ( %json_vars, &json_walk_var( $iref, $key ) );
        }
        $json_data{vars} = \%json_vars;
    }

    if ( $path[0] eq 'table_data' ) {
        if ( $args{var} ) {
            my $length = $#{ $json_table{ $args{var}[0] }->{data} } + 1;

            #print "json_db: length = $length start=" . $args{start}[0] . " records=" . $args{records}[0] . "\n";

            #need to check if vars and keys exist

            my $start = 0;
            $start = $args{start}[0] if ( $args{start}[0] );
            my $records = 0;
            my $page    = 0;
            my $page    = $json_table{ $args{var}[0] }{page}
              if ( defined $json_table{ $args{var}[0] }{page} );
            $records = $args{records}[0] if ( $args{records}[0] );

            #		if ($length < ($start + $records)) {
            #			print "db: will have to request data, $length, $start, $records\n";
            #			print "&" . $json_table{$args{var}[0]}{hook} . "($start,$records)\n";
            #			my $hook = 	$json_table{$args{var}[0]}{hook} . "($start,$records)";
            #
            #		#eval (&get_inbound_data($start,$records));
            #			eval ("&$hook");
            #			if ($@) {
            #	  			print_log "Json_Server.pl: WARNING: fetch data failed for " . $args{var}[0] . " " . $json_table{$args{var}[0]}{hook} . "!";
            #			} else {
            #	  			$page++ if (scalar @{$json_table{$args{var}[0]}->{data}} > $json_table{$args{var}[0]}{page_size});
            #			}
            #			#$json_table{$args{var}[0]}{page} = $page;
            #		}
            #if requesting data beyond what's available, fetch it.
            #test bad table
            #remove data from hash
            my $jt_time = int( $json_table{ $args{var}[0] }{time} );

            #print "arg time = " . int($args{time}[0]) . " table time = " .$jt_time . "\n";
            if (   ( $args{time} && int( $args{time}[0] ) < $jt_time )
                or ( !$args{time} ) )
            {
                #$json_data->{'table_data'} = $json_table{$args{var}[0]};
                #need to copy all the data since we can adjust starts and records

                $json_data{'table_data'}{exist} =
                  $json_table{ $args{var}[0] }{exist};
                $json_data{'table_data'}{head} =
                  $json_table{ $args{var}[0] }{head};
                $json_data{'table_data'}{page_size} =
                  $json_table{ $args{var}[0] }{page_size};
                $json_data{'table_data'}{hook} =
                  $json_table{ $args{var}[0] }{hook};
                $json_data{'table_data'}{page} = $page;
                @{ $json_data{'table_data'}->{data} } =
                  map { [@$_] } @{ $json_table{ $args{var}[0] }->{data} };

                splice @{ $json_data{'table_data'}->{data} }, 0, $args{start}[0]
                  if ( $args{start}[0] );
                splice @{ $json_data{'table_data'}->{data} }, $args{records}[0]
                  if ( $args{records}[0] );
                $json_data{'table_data'}{records} =
                  scalar @{ $json_data{'table_data'}->{data} };

                #print "db=$json_data{'table_data'}{records}\n";
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

    # List speak phrases
    if ( $path[0] eq 'print_speaklog' || $path[0] eq '' ) {
        my ( @log, @tmp );
        my $name;
        if ( $args{time}
            && int( $args{time}[0] ) < int( ::print_speaklog_current_time() ) )
        {
            #Only return messages since time
            @log = ::print_speaklog_since( $args{time}[0] );
            push @log, ''
              ; #TODO HP - Kludge, the javascript seems to want an extra line in the array for some reason
                #print "db/json: " . join(", ",@log) . "\n";
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

        #	   foreach my $key (sort (keys(%{$output_ref}))) {
        #	   print "db:key = $key\n";
        #  		 $json{data}{$key} = $output_ref->{$key};
        #		}
    }
    else {
        $json{error}{msg} = 'No data, or path does not exist.';
    }

    #Insert Meta Data fields
    $json{meta}{time} = $output_time;
    $json{meta}{path} = \@path;
    $json{meta}{args} = \%args;

    my $json_raw = JSON->new->allow_nonref;

    # Translate special characters
    $json_raw->canonical(1); #Order the data so that objects show alphabetically
    $json_raw = $json_raw->pretty->encode( \%json );
    return &json_page($json_raw);

}

sub json_get_sub_element {
    my ( $element_ref, $json_ref, $error_path ) = @_;
    my $out_ref = {};
    $error_path = "/" unless $error_path;
    my $path = shift( @{$element_ref} );
    $error_path .= $path . "/";
    if ( ref $json_ref eq 'HASH' && exists $json_ref->{$path} ) {
        if ( scalar( @{$element_ref} ) > 0 ) {
            return json_get_sub_element( $element_ref, $json_ref->{$path},
                $error_path );
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
                %json_vars = &json_walk_var( $iref, $name, @types );
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
                my @values = split( '\'}{\'', $cls );
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
            my ( $k, $r ) = &json_walk_var( $iref, $iname, @types );
            $json_vars{$name} = $r if $k ne "";
        }
    }
    elsif ( $type eq 'ARRAY' ) {
        foreach my $key ( 0 .. @$ref - 1 ) {
            $iname = "$name\[$key\]";
            $iref  = \${$ref}[$key];
            $iref  = ${$ref}[$key] if ref $iref eq 'REF';
            my ( $k, $r ) = &json_walk_var( $iref, $iname, @types );
            $json_vars{$name}{$k} = $r;
        }
    }
    elsif ( $type eq 'HASH' ) {
        foreach my $key ( sort keys %$ref ) {
            $iname = "$name\{'$key'\}";
            $iref  = \${$ref}{$key};
            $iref  = ${$ref}{$key} if ref $iref eq 'REF';
            my ( $k, $r ) = &json_walk_var( $iref, $iname, @types );
            $json_vars{$name}{$key} = $r;
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
            print_log
              "json: build_parent_table, group_name $group_name doesn't have an object?"
              if $Debug{json};
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
        my $request_time = int( $args{time}[0] / 1000 );    # Convert to seconds
        my $current_time = int( ::get_tickcount() / 1000 ); # Convert to seconds

        if ( !( $object->can('get_idle_time') ) ) {

            #Items that do not have an idle time do not get reported at all in updates
            return;
        }
        elsif ( $object->get_idle_time eq '' ) {

            #Items that have NEVER been set to a state have a null idle time
            return;
        }
        elsif ( $request_time >= ( $current_time - $object->get_idle_time ) ) {

            #Should get_tickcount be replaced with output_time??
            #Object has not changed since time, so return undefined
            return;
        }
    }

    my %json_objects;
    my %json_complete_object;
    my @f = qw( category filename measurement rf_id set_by members
      state states state_log type label sort_order groups hidden parents
      idle_time text html seconds_remaining fp_location fp_icons fp_icon_set img link level);

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
                $value = encode_entities( $value, "\200-\377&<>" );
            }
            print_log "json: object_dets f $f m $method v $value"
              if $Debug{json};
        }
        elsif ( $f eq 'members' ) {
            ## Currently only list members for group items, but at some point we
            ## can add linked items too.
            if ( ref($object) eq 'Group' ) {
                $value = [];
                my @tmp
                  ; ## pull all the members into a temp array that can be sorted
                for my $obj_name (
                    &list_objects_by_group( $object->get_object_name, 1 ) )
                {
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
            $value = encode_entities( $value, "\200-\377&<>" );
            print_log "json: object_dets f $f ev $value" if $Debug{json};
        }
        elsif ( $f eq 'html' and $object->can('get_type') ) {
            $value = "<!\[CDATA\["
              . &html_item_state( $object, $object->get_type ) . "\]\]>";
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
          if ( lc($f) eq 'items' ); #HP, we should already have parsed the items
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
    my ($json_raw) = @_;
    my $json;
    gzip \$json_raw => \$json;
    my $output = "HTTP/1.0 200 OK\r\n";
    $output .= "Server: MisterHouse\r\n";
    $output .= "Content-type: application/json\r\n";
    $output .= "Content-Encoding: gzip\r\n";
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
HTTP/1.0 200 OK
Server: MisterHouse
Content-type: text/html

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
            if ( $args{$opt}{applyto} eq 'all' or grep /^$r$/,
                split /\|/, $args{$opt}{applyto} )
            {
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

    return $html;
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
        print_log "Json_Server.pl: WARNING: fetch data failed for "
          . $key . " "
          . $json_table{$key}{hook} . "!";
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

