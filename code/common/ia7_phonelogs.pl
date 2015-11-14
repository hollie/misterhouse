# Category=IA7

#@ Code that loads the phone logs into the dynamic IA7 json data tables. User code needs to be
#@ added that hooks new_*_call into inbound and outbound calls.

#read in 3 files
# if record

use Data::Dumper;

#config parm, page size
my $page_size  = 30;    # unless config page size
my $field_line = 1;
my $field_type = 1;
my $logfiles   = 3;

if ( $Startup or $Reload ) {
    &json_table_create("phone_in");
    my @phone_in_headers = ( "Time", "Phone Number", "Name" );
    push( @phone_in_headers, "Line" ) if ($field_line);
    push( @phone_in_headers, "Type" ) if ($field_type);
    for my $i ( 0 .. $#phone_in_headers ) {
        &json_table_put_header( "phone_in", $i, $phone_in_headers[$i] );
    }
    &get_phone_inbound_data( 0, $page_size );
    &json_table_set_page_size( "phone_in", $page_size );
    &json_table_set_fetch_routine( "phone_in", "get_phone_inbound_data" )

      & json_table_create("phone_out");
    my @phone_out_headers = ( "Time", "Phone Number", "Name" );
    push( @phone_out_headers, "Line" ) if ($field_line);
    push( @phone_out_headers, "Type" ) if ($field_type);
    for my $i ( 0 .. $#phone_out_headers ) {
        &json_table_put_header( "phone_out", $i, $phone_out_headers[$i] );
    }
    &get_phone_outbound_data( 0, $page_size );
    &json_table_set_page_size( "phone_out", $page_size );
    &json_table_set_fetch_routine( "phone_out", "get_phone_outbound_data" )

}

sub _get_data {
    my ( $type, $start, $recs ) = @_;

    #print "db: get_data type=$type start=$start recs=$recs\n";

    my $log   = $type;
    my $table = "phone_" . $type;
    $log = 'callerid' if $log eq 'in';
    $log = 'phone'    if $log eq 'out';

    # read from call db
    my $records = $start + $recs;
    my @logs    = &read_phone_logs1($log);
    my @calls   = &read_phone_logs2( $records, @logs );

    #print "db: logs=" . scalar @logs . " calls= " . scalar @calls;
    my $count = -1;
    $start = 0 unless ($start);

    #need to filter to start...
    for my $r (@calls) {
        $count++;
        next if ( $count < $start );
        my ( $time, $num, $name, $line, $type ) =
          $r =~ /date=(.+) number=(.+) name=(.+) line=(.*) type=(.*)/;
        ( $time, $num, $name ) = $r =~ /(.+\d+:\d+:\d+) (\S+) (.+)/
          unless $name;
        my $display_name = $name;
        $display_name =~ s/_/ /g;   # remove underscores to make it print pretty
            #print "db: [$table] $count, $time, $num,$display_name\n";
        next unless $num;

        my $type_no = 3;
        &json_table_put_data( $table, $count, 0, $time );
        &json_table_put_data( $table, $count, 1, $num );
        &json_table_put_data( $table, $count, 2, $display_name );
        if ($field_line) {
            &json_table_put_data( $table, $count, 3, $line );
            $type_no = 4;
        }
        &json_table_put_data( $table, $count, $type_no, $type )
          if ($field_type);
    }
    &json_table_push($table);

}

sub _new_call {
    my ( $table, $time, $number, $name, $line, $type ) = @_;
    my @data = ( $time, $number, $name );
    push( @data, $line ) if ($field_line);
    push( @data, $type ) if ($field_type);
    my $json_table = "phone_$table";

    #print "db: time=$time number=$number name=$name line=$line type=$type\n";
    #print "db:table=$json_table, data=[" . join(";", @data) . "]\n";
    &json_table_insert_data_row( $json_table, 0, [@data] ) &
      json_table_push($json_table);
}

sub get_phone_inbound_data {
    my ( $start, $recs ) = @_;

    &_get_data( "in", $start, $recs );
}

sub get_phone_outbound_data {
    my ( $start, $recs ) = @_;

    &_get_data( "out", $start, $recs );

}

sub new_inbound_call {
    my ( $time, $number, $name, $line, $type ) = @_;

    &_new_call( "in", $time, $number, $name, $line, $type );
}

sub new_outbound_call {
    my ( $time, $number, $name, $line, $type ) = @_;

    &_new_call( "out", $time, $number, $name, $line, $type );

}

