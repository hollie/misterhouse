# Category=Phone

#@ This code lists the rejected caller list.
#@ It also creates subroutines used by the web interface to
#@ display rejected caller list.

# Show phone logs via a popup or web page
$v_Reject_call_list = new Voice_Cmd 'Display rejected caller list';
$v_Reject_call_list->set_info('Shows rejected caller list.');

if ( $state = said $v_Reject_call_list) {
    print_log "Showing reject caller list";
    &read_reject_call_list;
}

# This function will read in or out phone logs and return
# a list array of all the calls.
sub read_reject_call_list {

    #print "Reading Reject Caller File\n";
    my $phone_dir = "$config_parms{data_dir}/phone";
    my (@calls);
    my $log_file = "$phone_dir/phone.caller_id.list";
    print_log "$log_file";
    open( MYFILE, $log_file )
      or die "Error, could not open file $log_file: $!\n";
    while (<MYFILE>) {
        my ( $number, $name, $sound, $type );

        #file type example please note the tabs between fields
        #4141230002	Jason (cell)		jason.wav	family
        #*		*MARKET*		*		reject

        ( $number, $name ) = $_ =~ /(\d{10}|[*])\s+(.*)/;

        #ok, we have the number and name is filled with the rest, lets break up name a little
        $name =~ s/^\s*//;    #trim junk from beginning

        if ( $name =~ /,|\t/g )    #more parms
        {
            ( $name, $sound, $type ) = split( /\t+|,\s*/, $name );
        }
        $name =~ s/\s*$//;         #trim the fat off the end
        $name  = '*'       unless $name;
        $sound = '*'       unless $sound;
        $type  = 'general' unless $type;

        #	    print_log "Number;$number, Name;$name, Sound;$sound, Type;$type\n";
        push @calls,
          sprintf( "number=%-12s name=%s sound=%s type=%s",
            $number, $name, $sound, $type );

    }
    close MYFILE;
    return @calls;
}
