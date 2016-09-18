# Category	= CONCEPT

# This is the main module for producing the code to interface to the Concept alarm
# pannel handler. It was orignally adapted from the CBUS interface that Richard
# Morgan developed (and changed as little as possible)

##############################################################################
##############################################################################
##############################################################################
##############################################################################
###########							##############
###########	Globals, Startup, Menus, Voice COmmands		##############
###########							##############
##############################################################################
##############################################################################
##############################################################################
##############################################################################

# Define Globals
my %concept_data;
my @concept_groups;
my @concept_categories;
my ( $concept_monitor, $concept_talker );
my $last_concept_event_state = "un-initialised";
my $last_concept_control_state;

# Voice Commands
$v_concept_builder = new Voice_Cmd("Concept Builder [RUN_BUILDER,DUMP_DATA]");
$v_concept_speak   = new Voice_Cmd('Concept Pannel Monitor Speak [on,off]');
$v_concept_monitor =
  new Voice_Cmd("Concept Pannel Monitor [START,STOP,STATUS]");
$v_concept_talker = new Voice_Cmd("Concept Pannel Talker [START,STOP,STATUS]");
$v_concept_speak->tie_event('speak "Concept Panel Speak is now $state"');

if ($Reread) {
    load_concept_data();
}

if ($Startup) {

    # Open the IP port to the C-Gate Server Status Port
    $concept_monitor =
      new Socket_Item( undef, undef, $config_parms{concept_mon_address} );

    if ( $config_parms{system_state} eq "PROD" ) {
        print_log "concept_monitor: STARTING";
        concept_monitor_start();
    }
    else {
        print_log "concept_monitor: DISABLED, as we are in DEV mode";
    }

    $concept_talker =
      new Socket_Item( undef, undef, $config_parms{concept_talk_address} );

    if ( $config_parms{system_state} eq "PROD" ) {
        print_log "concept_talker: STARTING";
        concept_talker_start();
    }
    else {
        print_log "concept_talker: DISABLED, as we are in DEV mode";
    }
}

# Monitor Voice Command / Menu processing
if ( my $data = said $v_concept_monitor) {
    if ( $data eq 'START' ) {
        concept_monitor_start();

    }
    elsif ( $data eq 'STOP' ) {
        concept_monitor_stop();

    }
    elsif ( $data eq 'STATUS' ) {
        concept_monitor_status();

    }
    else {
        print_log "Concept_Monitor: command $data is not implemented";
    }
}

# Builder Voice Command / Menu processing
if ( my $data = said $v_concept_builder) {
    if ( $data eq 'RUN_BUILDER' ) {
        load_concept_data();
        build_concept_file();

    }
    elsif ( $data eq 'DUMP_DATA' ) {
        dump_concept_data();

    }
    else {
        print_log "concept_Builder: command $data is not implemented";
    }
}

# Talker Voice Command / Menu processing
if ( $state = said $v_concept_talker) {

    if ( $state eq 'START' ) {
        concept_talker_start();

    }
    elsif ( $state eq 'STOP' ) {
        concept_talker_stop();

    }
    elsif ( $state eq 'STATUS' ) {
        concept_talker_status();

    }
    else {
        print_log "Concept_Talker: command $state is not implemented";
    }
}

##############################################################################
##############################################################################
##############################################################################
##############################################################################
###########							##############
###########		CONCEPT BUILDER				##############
###########							##############
##############################################################################
##############################################################################
##############################################################################
##############################################################################

sub num_sort {

    # numeric sort routine, called as "sort sum_sort nnnnnnn"

    $a <=> $b;
}

sub load_concept_data {

    # Reads in the Concept definitions file, and creates the master
    # object Hash of Hash.  Also creates Arrays for Groups and Categories

    # clear out the hashes, MH is good at polluting its hases with reloads
    %concept_data       = ();
    @concept_groups     = ();
    @concept_categories = ();

    # Load in the Concept definitiions file
    my $filename =
      $config_parms{code_dir} . "/" . $config_parms{concept_dat_file};
    print_log "concept_Builder: Loading Concept Data from file $filename";
    open( CF, "<$filename" )
      or print_log "concept_Builder: Could not open $filename: $!";
    my @temp2 = <CF>;

    close(CF)
      or print_log "concept_Builder: Could not close $filename: $!";

    # remove all the comment lines in input file
    my @temp1 = grep !/^\s*#/, @temp2;

    # Grab the first row (headings) then create an array of their names
    my $first_row = @temp1[0];
    chomp $first_row;
    my @headings = split /,/, $first_row;
    my $max_headings = scalar @headings;
    $headings[ $max_headings - 1 ] =~ tr/\r//d;
    print_log "concept_Builder: $max_headings headings loaded from dat file";

    # Get rid of the first line, and process the entire file
    shift @temp1;

    # Step through the array of Concept devices and stuff them into a Hash
    foreach my $row (@temp1) {

        $row =~ s/\cM//g;    #remove all ^M
        chomp $row;
        my @details = split /,/, $row;
        my $loop = 0;

        for ( $loop = 0; $loop < $max_headings; $loop++ ) {

            $concept_data{ $details[0] }{ $headings[$loop] } = $details[$loop];
        }
    }
    my $count = scalar @temp1;
    undef @temp1;
    print_log "concept_Builder: Loaded $count Concept nodes";

    # Dredge for a list of Concept Group Names
    foreach my $address ( sort num_sort keys %concept_data ) {

        my $item_group_string = $concept_data{$address}{'group'};
        my @item_group_list = split /:/, $item_group_string;

        #check if the group name is in the hash, push itif no, skip if yes
        foreach my $item_group (@item_group_list) {
            if ( grep m/$item_group/, @concept_groups ) {
                next;
            }
            else {
                push @concept_groups, $item_group;
            }
        }
    }

    my $count = scalar @concept_groups;
    print_log "concept_Builder: Loaded $count Concept groups";

    # Dredge for a list of Concept Category Names
    foreach my $address ( sort num_sort keys %concept_data ) {

        my $item_category = $concept_data{$address}{'category'};

        #check if the group name is in the hash, push itif no, skip if yes
        if ( grep m/$item_category/, @concept_categories ) {
            next;
        }
        else {
            push @concept_categories, $item_category;
        }
    }

    my $count = scalar @concept_categories;
    print_log "concept_Builder: Loaded $count Concept categories";
}

sub dump_concept_data {

    # Basic diagnostic routine for dumping the concept objects hash

    for my $record ( sort num_sort keys %concept_data ) {
        my $msg = sprintf "CONCEPT ID: %s\n", $record;

        for my $data ( keys %{ $concept_data{$record} } ) {
            $msg .= "$concept_data{$record}{$data},";
        }
        print_log $msg;
    }
}

sub build_concept_file {

    # This sub parses through the %concept_group array
    # and creates the file concept_data.pl, which contains all the
    # item, event and group definitions for all Concept units

    my $concept_file = $config_parms{code_dir} . "/concept_data.pl";
    my ( $item, $name, $opts, $rows, $info, $delay );
    rename( $concept_file, $concept_file . '.old' )
      or print_log "Could not create backup of $concept_file: $!";

    # _opts2 is for dimmable units, _opts1 is for relay appliances
    my @cmd_opts = ( '', '', '[on,off]', '[on,off]' );

    print_log "Saving Concept configs to $concept_file";
    open( CF, ">$concept_file" )
      or print_log "Could not open $concept_file: $!";

    print CF "# Category=Concept_Items\n#\n#\n";
    print CF
      "# Created: $Time_Now, from concept_dat file: \"$config_parms{concept_dat_file}\"\n";
    print CF
      "# This file is automatically created with the Concept command RUN_BUILDER  -- DO NOT EDIT\n";
    print CF "#\n# -- DO NOT EDIT --\n";
    print CF "#\n#\n#\n";

    print CF "#\n# Concept Device Summary List\n#\n";
    foreach my $address ( sort num_sort keys %concept_data ) {
        $item = $concept_data{$address}{'label'};
        $name = $item;
        $item =~ s/ /_/g;
        $item = '$' . $item;

        printf CF ( "# %-30s  Address: %-7s\tObject is: %s\n", $name, $address,
            $item );
        $rows++;
    }

    print CF "#\n# Create Concept_Items\n#\n";
    foreach my $address ( sort num_sort keys %concept_data ) {
        $item = $concept_data{$address}{'label'};
        $item =~ s/ /_/g;
        $item = '$' . $item;
        printf CF ( "%-40s= new Concept_Item;\n", $item );
        $rows++;
    }

    # This loop is more complex as we sort them via category

    foreach my $category (@concept_categories) {
        my @cat_list;
        foreach my $address ( sort num_sort keys %concept_data ) {
            my $item = $concept_data{$address}{'category'};

            if ( $item eq $category ) {
                push @cat_list, $address;
            }
        }

        print CF "#\n# Create Concept Voice_Cmds for Category: $category\n#\n";
        print CF "# Category="
          . $config_parms{concept_category_prefix}
          . "$category\n#\n";

        foreach my $address (@cat_list) {

            # Don't generate voice commands for zone inputs
            if ( $concept_data{$address}{'type'} != 1 ) {
                $item = $concept_data{$address}{'label'};
                $name = $item;
                $item =~ s/ /_/g;
                $item = '$v_' . $item;

                $opts = $cmd_opts[ $concept_data{$address}{'type'} ];

                printf CF ( "%-40s= new Voice_Cmd \'%s %s\';\n", $item, $name,
                    $opts );
                $rows++;
            }
        }
        undef @cat_list;
    }

    print CF "#\n# Category=Concept_Items\n#\n";
    print CF "#\n# Add set_info directives to Concept Voice_Cmds\n#\n";
    foreach my $address ( sort num_sort keys %concept_data ) {

        # Don't set info it's a zone input and has no voice command
        if ( $concept_data{$address}{'type'} != 1 ) {
            $item = $concept_data{$address}{'label'};
            $name = $item;
            $item =~ s/ /_/g;
            $item = '$v_' . $item;

            $info = $concept_data{$address}{'info'};

            # Now this is interesting
            # Something in the MH code parser breaks when it sees set_info in a line
            my $str1 = sprintf( "%-40s-> set",       $item );
            my $str2 = sprintf( "_info (\'%s\');\n", $info );
            $str1 = $str1 . $str2;

            print CF ("$str1");
            $rows++;
        }
    }

    #
    #
    #	set_states for Concept_Items
    #
    #
    print CF "#\n# Set the Concept_Items Command States\n#\n";
    foreach my $address ( sort num_sort keys %concept_data ) {
        $item = $concept_data{$address}{'label'};
        $item =~ s/ /_/g;
        $item = '$' . $item;

        #$opts = $cmd_opts[$concept_data{$address}{'type'}]

        # Zone inputs get the extra TAMPER state
        if ( $concept_data{$address}{'type'} == 1 ) {
            printf CF ( "%-40s -> set_states(ON,OFF,\"TAMPER\");\n", $item );
        }
        else {
            printf CF ( "%-40s -> set_states(ON,OFF);\n", $item );
        }
        $rows++;

    }

    print CF "#\n# Create Event Ties\n#\n";
    foreach my $address ( sort num_sort keys %concept_data ) {
        if ( $concept_data{$address}{'type'} !=
            1 )    # Don't set a tie for Zone inputs, they are input only
        {
            $item = $concept_data{$address}{'label'};
            $item =~ s/ /_/g;

            #		$item = '$v_' . $item;
            $item = '$' . $item;
            my $rstring = $item . '->{set_by}';
            printf CF (
                "tie_event %-29s \'concept_set( \"%s\", \$state, $rstring)\';\n",
                $item, $address
            );
            $rows++;
        }
    }

    #
    #
    #	tie_item the $object to voice command object
    #
    #
    print CF "#\n# Create Item Ties\n#\n";
    foreach my $address ( sort num_sort keys %concept_data ) {

        # Don't do this is it is a zone input and has no voice command
        if ( $concept_data{$address}{'type'} != 1 ) {
            $item = $concept_data{$address}{'label'};
            $item =~ s/ /_/g;

            #$item = '$v' . $item;

            printf CF ( 'tie_items $v_' . "%-29s  \$%s;\n", $item, $item );
            $rows++;
        }
    }

    print CF "#\n# Create Groups\n#\n";
    foreach my $group_name (@concept_groups) {
        $group_name = '$' . $group_name;
        printf CF ( "%-40s= new Group();\n", $group_name );
        $rows++;
    }

    print CF "#\n# Assign Concept Objects to Groups\n#\n";
    foreach my $address ( sort num_sort keys %concept_data ) {
        $item = $concept_data{$address}{'label'};
        $item =~ s/ /_/g;
        $item = '$' . $item;

        my $item_group_string = $concept_data{$address}{'group'};
        my @item_group_list = split /:/, $item_group_string;

        foreach my $item_group (@item_group_list) {
            $item_group = '$' . $item_group;
            printf CF ( "%-20s-> add(%s);\n", $item_group, $item );
            $rows++;
        }
    }

    # What follows creates a sub called concept_update()
    #	It is called by concept_monitor.pl, whenever there is a message
    #	received from the Concept handler.  This is perl code to write perl code
    #	Eval statements seem to be unstable under MH.

    print CF "#\n# Create Master Concept Status Subroutine\n#\n";
    print CF "sub concept_update {\n\n";
    print CF
      "\t# *****************************************************************************************\n";
    print CF
      "\t# This subroutine is automatically generated by concept_builder.pl, do not edit !\n";
    print CF
      "\t# *****************************************************************************************\n\n";
    print CF "\tmy \$addr = \$_[0];\n";
    print CF "\tmy \$newstate = \$_[1];\n";
    print CF "\tmy \$requestor = \$_[2];\n\n";

    foreach my $address ( sort num_sort keys %concept_data ) {
        $item = $concept_data{$address}{'label'};
        $item =~ s/ /_/g;
        $item = '$' . $item;
        print CF "\tif (\$addr eq \"$address\") {\n";
        print CF "\t\tset $item \$newstate;\n";
        print CF "\t\t$item" . '->{set_by}' . " = \$requestor;\n";
        print CF "\t}\n\n";
        $rows++;
    }

    print CF "}\n";

    print CF "#\n#\n# EOF\n#\n#\n";

    close(CF)
      or print_log "Could not close $concept_file: $!";

    print_log "Completed Concept configs to $concept_file, saved $rows records";

}

##############################################################################
##############################################################################
##############################################################################
##############################################################################
###########							##############
###########		Concept MONITOR				##############
###########							##############
##############################################################################
##############################################################################
##############################################################################
##############################################################################

sub concept_monitor_start {

    # Start the concept listener (monitor)

    if ( active $concept_monitor) {
        print_log "Concept_Monitor already running, skipping start";
        speak("Concept Monitor: is already running");

    }
    else {
        if ( start $concept_monitor) {
            speak("Concept monitor started");
            print_log "Concept_Monitor: started";
        }
        else {
            speak("Concept Monitor failed to start");
            print_log "Concept_Monitor: failed to start";
        }
    }
}

sub concept_monitor_stop {

    # Stop the concept listener (monitor)

    print_log "Concept_Monitor: Stopping";
    stop $concept_monitor;
    speak("Concept Monitor stopped");
}

sub concept_monitor_status {

    # Return the status of the concept listener (monitor)

    if ( active $concept_monitor) {
        print_log
          "Concept_Monitor: is active. Last event received was: $last_concept_event_state";
        speak(
            "Concept Monitor is active. Last event received was $last_concept_event_state"
        );
    }
    else {
        print_log "Concept Monitor: is not running";
        speak("Concept Monitor is not running");
    }
}

# Monitor and process data comming from Concept server
# Executed every pass of MH

if ( my $concept_msg = said $concept_monitor)    # See if any data has arrived
{
    my @cg = split / /, $concept_msg;   # Seperate the data so that,
                                        # $cg[0] - Time stamp
                                        # $cg[1] - activity code. 201,202 or 203
          # $cg[2] - What is effected, ie: Zone=C01:01 or Area=01 etc
          # $cg[3] - The nodes state. ie: state=0 etc
          # $cg[4] - The setby if an AUX. ie: by=C1 etc
    my $cg_time = $cg[0];
    my $cg_code = $cg[1];

    my @cd;
    my $cg_unit  = "Unknown";
    my $cg_state = 0;
    my $cg_type  = 0;
    my $co_setby = "Panel";
    if ( $cg_code == 201 )    # Zone update
    {
        $cg_type  = 1;
        $cg_state = $cg[3];
        @cd       = split /=/, $cg[2];
        $cg_unit  = 'Z' . $cd[1];
    }
    if ( $cg_code == 203 )    # Auxilary update
    {
        $cg_type  = 2;
        $cg_state = $cg[3];
        @cd       = split /=/, $cg[2];
        $cg_unit  = 'X' . $cd[1];

        @cd = split /=/, $cg[4];    # Seperate the setby out
        $co_setby = $cd[1];
        if (
            $co_setby eq $config_parms{concept_interface} ) # Comms task 1 is MH
        {
            $co_setby = "MH";
        }
    }
    if ( $cg_code == 202 )                                  # Area change
    {
        $cg_type  = 3;
        $cg_state = $cg[3];
        $cg_unit  = $cg[2];
    }

    my $state_speak;
    if ( !defined $concept_data{$cg_unit}{'label'} ) {

        # We haven't been told about this node so ignore it
        $cg_type = 0;
    }

    if ( $cg_type != 0 ) {    # We have something of interest

        my $concept_state = 0;
        my @sub_state = split /=/, $cg_state;

        if ( $sub_state[1] == 1 ) {
            $concept_state = ON;
            $state_speak   = ON;
        }
        elsif ( $sub_state[1] == 0 ) {
            $concept_state = OFF;
            $state_speak   = OFF;

        }
        elsif ( $sub_state[1] == 2 ) {
            $concept_state = 'TAMPER';
            $state_speak   = 'TAMPER';

        }
        else {    # Don't know what state it is
            $concept_state = OFF;
            $state_speak   = OFF;
        }

        my $concept_label      = $concept_data{$cg_unit}{'label'};
        my $concept_speak_name = $concept_data{$cg_unit}{'speak_name'};
        my $announce           = $concept_data{$cg_unit}{'announce'};

        $last_concept_event_state = "$concept_speak_name $state_speak";

        if ( ( state $v_concept_speak eq ON ) && ($announce) ) {
            speak($last_concept_event_state);
        }

        if ( $co_setby eq 'MH' ) {

            # This is a response to MH sending a event so just ignore it
            # otherwise we would just keep setting and setting and setting
            print_log
              "Concept_Monitor: Recieved recursive instruction $concept_label $state_speak, ignored ";
        }
        else {
            concept_update( $cg_unit, $concept_state, 'concept' )
              ;    # The 'concept' is picked up
                   # by the talker to stop the
                   # signal going straight back out
            print_log "Concept_Monitor: $concept_label $state_speak";
        }
    }

}

##############################################################################
##############################################################################
##############################################################################
##############################################################################
###########							##############
###########		Concept TALKER				##############
###########							##############
##############################################################################
##############################################################################
##############################################################################
##############################################################################

sub concept_set {

    # main command handler for concept directives directives

    my ( $device, $level, $changed_by ) = @_;
    my $orig_level = $level;

    if ( $changed_by eq 'concept' ) {

        # This was a Recursive set, we are inoring
        print_log "Concept Talker: Got a recursive send so ignoring it";
        return;
    }
    else {
        # This was NOT a recursive set, do it
    }

    # Get rid of any % signs in the $Level value
    $level =~ s/%//g;

    if ( ( $level eq ON ) || ( $level eq 'ON' ) ) {
        $level = ON;

    }
    elsif ( ( $level eq OFF ) || ( $level eq 'OFF' ) ) {
        $level = OFF;

    }
    else {
        print_log
          "Concept Talker: Unkown level \'$level\' passed to concept_set()";
        return;
    }

    my $dev_type = substr( $device, 0, 1 );
    my $command  = "unknown";
    my $unit     = "unknown";
    if ( $dev_type eq 'Z' )    # can't set a zone
    {
        print_log
          "Concept Talker: Tryed to change state on a zone $device in concept_set()";
        return;
    }
    elsif ( $dev_type eq 'X' )    # An auxilary
    {
        $command = "AUX";
        $unit = substr( $device, 1 );
    }
    else                          # Must be an alarm
    {
        $command = "AREA";
        $unit    = $device;
    }

    if ( active $concept_talker) {
        my $concept_label = $concept_data{$device}{'label'};
        print_log "Concept_Talker: SET $command $unit=$level";

        my $ramp_command = sprintf( "SET %s %s=%s\n", $command, $unit, $level );
        set $concept_talker $ramp_command;
        $last_concept_control_state = "Setting $command unit $unit to $level";
    }
    else {
        print_log "Concept_Talker: is not running, cannot send command";
    }

    while ( my $data = said $concept_talker) {
        print_log "Concept_Talker: Concept advised: $data";
    }

    #	if (my $data = said $concept_talker) {
    #		print_log "Concept_Talker: Concept advised: $data";
    #	}

}

sub concept_talker_start {

    # Starts the concept command driver (Talker)

    if ( active $concept_talker) {
        print_log "Concept_Talker: already running, skipping start";
        speak("Concept talker is already running");

    }
    else {
        if ( start $concept_talker) {
            speak("Concept talker started");
            print_log "Concept_Talker: started";

            if ( my $data = said $concept_talker) {
                print_log "Concept_Talker: Concept advised: $data";
            }

        }
        else {
            speak("Concept Talker failed to start");
            print_log "Concept_Talker: failed to start";
        }
    }
}

sub concept_talker_stop {

    # Stops the concept command driver (Talker)

    print_log "Concept_Talker: Stopping";
    stop $concept_talker;
    speak("Concept talker stopped");
}

sub concept_talker_status {

    # Returns the status of the concept command driver (Talker)

    if ( active $concept_talker) {
        print_log
          "Concept_Talker: is active. Last command sent was: $last_concept_control_state";
        speak(
            "Concept Talker is active. Last command sent was $last_concept_control_state"
        );
    }
    else {
        print_log "Concept_Talker: is not running";
        speak("Concept Talker is not running");
    }
}

