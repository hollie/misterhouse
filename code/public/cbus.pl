# Category    = CBus
#
# Subversion $Date$
# Subversion $Revision$
# vim:ts=4:expandtab:
#
# Copyright 2002: Richard Morgan  omegaATbigpondDOTnetDOT.au
# Copyright 2008: Andrew McCallum, Mandoon Technologies andyATmandoonDOTcomDOTau
#
# $Id$
#
#   Ensure XML::Simple is installed:
#
#        On Linux:        perl -MCPAN -e "install XML::Simple"
#        On Windows:        run 'ppm',  then type 'install XML::Simple'
#                                FIXME is the windows command correct??
#
#   ******* IMPORTANT *******
#   ***
#   *** You must change the C-Gate configuration files found under the 'config' directory.
#   ***
#   *** In C-GateConfig.txt: Change global-event-level from 5 to 7, the new line will be:
#   ***	    "global-event-level=7"
#   ***
#   *** In access.txt: Add a new line with your subnet,
#   *** eg. if your IP address is 192.168.72.42, then add the following line:
#   ***	    "interface 192.168.72.255 Program"
#   ***
#   ******* IMPORTANT *******
#
# Revision History:
#    03-12-2001
#        Modified to support c-gate 1.5
#    23-06-2002
#        Monitor: Source name now works, and shows 'MH' is source 0
#    05-07-2002
#        Modified for cbus_dat.csv input file support
#        Added groups and set_info support
#    06-07-2002
#        Minor changes to support new cbus_builder
#        Modified to support global %cbus_data hash
#        removed make_cbus_file(), replaced with cbus_builder.pl
#    11-07-2002
#        Added announce flag to cbus_dat.csv, and conditional speak flag $announce
#    19-09-2002
#        Fixed bug in cbus_set() that prevented dimming numeric % set values
#        being accepted.  Dimming now works.
#    21-09-2002
#        Modified cbus_groups and cbus_catagories to read from input file
#        rather than hard coded
#        Put in config item cbus_category_prefix
#        Comments in input file now allowed
#        Fixed some other minor things
#    22-09-2002 V2.0
#        Collapsed cbus_talker.pl, cbus_builder.pl and cbus_monitor.pl
#        into one new file, cbus.pl.  Now issued as V2.0.
#
#    V2.1    Fixed up some menu uglies.
#        Improved coding in monitor loop
#        Fixed up code labels, docs etc
#
#    V2.2    Changed all speak() calls to say 'C-Bus' rather than 'CBus', so the diction is correct
#
#    V2.2.1    Fixed minor bug in cbus monitor start voice command
#
#    V2.2.2    Implemented;
#            oneshot device type
#            cbus_oneshot_log config param
#
#    V2.2.3    Made the dump_cbus_data format pretty HTML tables
#
#    V3.0    2008-02-04
#            Fixed to work with C-Gate Version: v2.6.1 (build 2236)
#              Latest version as of June 2008
#            Now reports the name of the source unit that modified a group level.
#            Added ability to scan CGate for groups and output to config file.
#            *** Configuration only requires running Builder to scan cgate and
#            *** build XML file, then commanding MH to "reload code". Job Done.
#            *** Customisation if wanted can be done through the config file.
#            Changed config file to XML format.
#            Builder command auto scans CGate if no config file exists.
#            Fixed interpretation of dimming commands.
#            PROD is the default state. In PROD, no option to stop comms.
#            Changed DEV to DEBUG for commonality.
#            Monitor and Talker attempt to always run unless in DEBUG state.
#
#	V3.0.1	 2013-11-22
#	         Fixed to work with C-Gate Version: v2.9.7 (build 2569), which returns
#	         cbus addresses in the form NETWORK/APPLICATION/GROUP rather than
#	         //PROJECT/NETWORK/APPLICATION/GROUP.
#	         Add logging to aid debugging cbus_builder
#	         Contributed by Jon Whitear <jonATwhitearDOTorg>
#
#	V3.0.2   2013-11-25
#			 Add support for both formats of return code, i.e. NETWORK/APPLICATION/GROUP
#	         and //PROJECT/NETWORK/APPLICATION/GROUP.
#
#	V3.0.3	 2013-11-28
#			 Test debug flag for logging statements.
#
# How Cgate integrates with MH
#
#    All Cbus objects are defined in a standard XML file (cbus.xml), this file is
#    read in at $Reload, and a large Hash-of-Hash is created to store the CBus objects for
#    MH.  To ensure that MH can use the CBus objects propoerly, they are mapped
#    into a MH object.
#
#    To do this mapping, that is create the cbus $objects and matching tied Voice_cmds
#    a sub in this file make_cbus_file() reads through the CBus hash and creates the perl directive
#    We are in effect using MH to write its own code, this was inspired from the X!0 methods.
#    The ouput file of the builder, cbus.pl is a valid MH code module and is then read
#    in at the next reload.
#
#    So..  Remember to RUN_BUILDER, then RELOAD code, to make a CBus object change.
#
#    The $v_objects are all voice commands and they are used to control
#    a Cbus device from the web.  Each $v_object is tied to its respective $object.
#    In program control (testing the state of an $object, or setting a $object) are all
#    performed against the $object, although you can set the $v_object, its state will not
#    reflect any updates from the actual CBus.
#
#    Remember, the CBus is interactive, it can receive as well as issue commands.
#
#    So, its best to always use the $object in your code. Each $object is tied
#    to an event trigger that calls the cbus_set() subroutines,, notice how the last 'set_by'
#    directive was also passed, this is to ensure that we do not create endless message loops.
#    When the cbus_set() sub is called the actual CBus device is set to that state
#    assuming it was not the CBus that actually initiated this set in the first place.
#
#    CGate itself repeats all commands received, back to MH via
#    the CBus monitor. Therefore MH listens for these commands and then sets the appropriate
#    $object, but this is ignored if MH was in fact the source of the set.
#
#    When MH starts up, the cbus code will automatically attempt to sync MH to the current
#    state of CGate. CGate of course, will reflect the physical state of the CBus network.
#    When the sync is complete, the $CBus_Sync will be set ON.
#
#    mh.private.ini Settings
#    ===============
#    Category = CBus
#    # cbus_system_state     = DEBUG
#    cbus_project_name       = CARLYLE
#    cgate_mon_address       = 192.168.1.180:20024
#    cgate_talk_address      = 192.168.1.180:20023
#    cbus_dat_file           = cbus.xml
#    cbus_category_prefix    = cbus_
#    cbus_ramp_speed         = 0
#
#
#    QUICK START
#    ===========
#    * Install the cbus.pl file in your code directory
#    * Activate the cbus.pl file in the "Setup MrHouse" web page
#    * Add the above settings to mh.private.ini configuration.
#      IMPORTANTLY, set the project name of your cbus network
#      or delete the configuration item if you have set the
#      default project in cgate itself.
#    * Command MH to "cbus builder run". This will scan cgate, write a CBus
#      config file (cbus.xml) and build cbus_procedures.pl
#    * Command mh to "reload code".
#    * Enjoy (and report bugs)
#
#
##############################################################################
##############################################################################
##############################################################################
##############################################################################
###########                                                     ##############
###########    Globals, Startup, Menus, Voice Commands          ##############
###########                                                     ##############
##############################################################################
##############################################################################
##############################################################################
##############################################################################

use XML::Simple qw(:strict);

#
# Define Defaults
#
my $WATCHDOG_TIMER_DEFAULT = 900;    # 15 minutes
my $DELAY_CHECK_SYNC       = 10;
my $MAX_CMD_COUNT          = 100;

#
# Define Globals
#
my $CBUS_RETRY_SECS    = 5;
my $cbus_talker_retry  = $CBUS_RETRY_SECS + 1;
my $cbus_monitor_retry = $CBUS_RETRY_SECS + 1;

my ( $cbus_monitor, cbus_talker );

my $cbus_system_debug = 0;
my $cbus_def;
my @cbus_net_list;
my $cbus_scan_last_addr_seen;
my $last_mon_state = "un-initialised";
my $last_talk_state;
my $cmd_counter = 0;
my @cmd_list    = ();

my $CBus_Sync        = new Generic_Item;
my $sync_in_progress = 0;
my %addr_not_sync    = ();
my $cbus_def_filename;
my $cbus_project_name;
my $cbus_scanning_cgate = 0;
my $request_cgate_scan  = 0;
my $cbus_units_config;
my $cbus_got_tree_list;
my $cbus_scanning_tree;
my @cbus_group_list;
my @cbus_unit_list;
my $cbus_session_id = "";
my $cbus_group_idx;
my $cbus_unit_idx;

# Voice Commands
$v_cbus_builder =
  new Voice_Cmd( "CBus Builder " . "[Test,Run,Scan CGate,List Devices]" );
$v_cbus_speak   = new Voice_Cmd('CBus Monitor Speak [on,off]');
$v_cbus_monitor = new Voice_Cmd("CBus Monitor [Start,Stop,Status]");
$v_cbus_talker  = new Voice_Cmd("CBus Talker [Start,Stop,Status]");
$v_cbus_speak->tie_event('speak "C-Bus Speak is now $state"');

if ( $Reload || $Reread ) {

    # Stop both comms ports in case of changes in config
    cbus_talker_stop();
    cbus_monitor_stop();

    # Re configure to pickup any changes in ini
    cbus_configure();
    load_def_file();
}

#
# Configure startup values
#
sub cbus_configure {
    $cbus_project_name = $config_parms{cbus_project_name};

    # Open the IP port to the C-Gate Server Status Port
    $cbus_monitor =
      new Socket_Item( undef, undef, $config_parms{cgate_mon_address} );

    # Open the IP port to the C-Gate Server Control Port
    $cbus_talker =
      new Socket_Item( undef, undef, $config_parms{cgate_talk_address} );

    if ( $config_parms{cbus_system_state} eq "DEBUG" ) {
        $cbus_system_debug = 1;
        print_log "CBus: DEBUG mode - No CGate communications started";
    }

    print_log "CBus: MisterHouse CBus debug mode - additional logging enabled"
      if $Debug{cbus};

}

# Monitor Voice Command / Menu processing
if ( my $data = said $v_cbus_monitor) {
    if ( $data eq 'Start' ) {
        cbus_monitor_start();

    }
    elsif ( $data eq 'Stop' ) {
        cbus_monitor_stop();

    }
    elsif ( $data eq 'Status' ) {
        cbus_monitor_status();

    }
    else {
        print_log "cbus_Monitor: command $data is not implemented";
    }
}

# Builder Voice Command / Menu processing
if ( my $data = said $v_cbus_builder) {
    if ( $data eq 'Run' ) {
        load_def_file();
        if ( not defined $cbus_def ) {

            # There was no cbus def file to load.
            # Help out a new user, by auto-building the def file.
            # Otherwise, there will be nothing to build.
            print_log "CBus: Builder is initiating scan of CGate";
            scan_cgate();
        }
        build_cbus_file(0);

    }
    elsif ( $data eq 'Test' ) {
        load_def_file();
        if ( not defined $cbus_def ) {
            print_log "CBus: Builer is initiating scan of CGate";
            scan_cgate();
        }
        build_cbus_file(1);

    }
    elsif ( $data eq 'Scan CGate' ) {
        load_def_file();
        scan_cgate();

    }
    elsif ( $data eq 'List Devices' ) {
        dump_cbus_data();

    }
    else {
        print_log "CBus: Builder command $data is not implemented";
    }
}

# Talker Voice Command / Menu processing
if ( $state = said $v_cbus_talker) {
    if ( $state eq 'Start' ) {
        cbus_talker_start();

    }
    elsif ( $state eq 'Stop' ) {
        cbus_talker_stop();

    }
    elsif ( $state eq 'Status' ) {
        cbus_talker_status();

    }
    else {
        print_log "CBus: Talker command $state is not implemented";
    }
}

#
# Reads in an existing CBus XML definitions file.
#
sub load_def_file {
    undef $cbus_def;

    # Load in the CBus definitiions file
    $cbus_def_filename =
      $config_parms{code_dir} . "/" . $config_parms{cbus_dat_file};
    if ( not -e $cbus_def_filename ) {
        print_log
          "CBus: load_def_file() XML definition file $cbus_def_filename does not exist";
        return;
    }

    print_log "CBus: load_def_file () Loading CBus config from XML file "
      . $cbus_def_filename;
    $cbus_def = XMLin(
        $cbus_def_filename,
        ForceArray => [ 'mh_group', 'note' ],
        KeyAttr    => ['address']
    );

    delete $cbus_def->{group}{'//AAAProjectName/Network/Application/Group'};
    delete $cbus_def->{'Creation_Time'};
    delete $cbus_def->{'Creation_Date'};
    delete $cbus_def->{'Version'};

    #print_log Dumper($cbus_def);
}

##############################################################################
##############################################################################
##############################################################################
##############################################################################
###########                                                     ##############
###########    CBus BUILDER                                     ##############
###########         Scan CGate,                                 ##############
###########      Write config file,                             ##############
###########      Write cbus_procedures.pl                       ##############
###########                                                     ##############
##############################################################################
##############################################################################
##############################################################################
##############################################################################

#
# Scan CGate server to update the configuration.
#
sub scan_cgate {

    # Initiate scan of CGate data
    # The scan is controlled by code in the Talker mh main loop code
    print_log "CBus: scan_cgate() Scanning CGate...";

    # Cleanup from any previous scan and initialise flags/counters
    @cbus_net_list = [];

    # Setup definition hash if needed
    if ( not defined $cbus_def ) {
        $cbus_def = {
            group => {},
            unit  => {}
        };
    }

    if ( defined $cbus_project_name ) {
        set $cbus_talker "project load " . $cbus_project_name;
        set $cbus_talker "project use " . $cbus_project_name;
        print_log "CBus: scan_cgate() Command - project start "
          . $cbus_project_name;
        set $cbus_talker "project start " . $cbus_project_name;
    }

    $request_cgate_scan = 1;
    set $cbus_talker "get cbus networks";

    # The mh main loop code will write the def file at the end of the scan.
}

#
# Write CBus definition file (XML) to a file
#
sub write_def_file {

    # NOTE: The data below will be deleted from the data structure on load.
    #       The builder always does a load or a scan first and therefore never
    #       sees the hash entries below.

    # Add a version and timestamp to the file to be saved
    $cbus_def->{Version}       = "3.0";
    $cbus_def->{Creation_Date} = $Date_Now;
    $cbus_def->{Creation_Time} = $Time_Now;

    # Add an example to the config file
    $cbus_def->{group}{'//AAAProjectName/Network/Application/Group'} = {
        name           => "SomeExample",
        type           => "output/input",
        category       => "CBus Lights",
        type           => "relay",
        speak_name     => "AAA is example",
        label          => "Label Name (->set_label) used by iPhone interface",
        log_label      => "AAA Example",
        announce       => "1",
        web_icon       => "Some icon specification",
        web_mouse_over => "Info when mouseover on web",
        mh_group       => [ "Outside", "Security" ],
        note           => [
            "Added by MisterHouse",
            "These notes are not used by MisterHouse.",
            "Delete/add notes for human readability.",
            "This is an example and not loaded.",
            "type can be relay or dimmer."
        ]
    };

    my $xml_file = XML::Simple->new(
        ForceArray => [qw(mh_group, note)],
        KeyAttr    => ['address'],
        RootName   => 'CBus'
    );

    # Write the file to disk
    print_log
      "CBus: write_def_file() Writing XML definition to $cbus_def_filename,";
    $xml_file->XMLout( $cbus_def, OutputFile => $cbus_def_filename, );
}

sub dump_cbus_data {

    print_log "CBus: Device list function disabled";

    #    # Basic diagnostic routine for dumping the cbus objects hash
    #    my $count = 0;
    #    my $msg = "<H2>CBUS Device Listing</H2><HR>";
    #
    #    for my $record (sort keys %cbus_data) {
    #
    #        $msg .= sprintf "<h3>CBus ID: %d  <FONT color=\"red\">%s</FONT></H3>", $record, $cbus_data{$record}{log_label};
    #        $msg .= '<TABLE border="1">';
    #
    #        for my $data (sort keys %{ $cbus_data{$record} } ) {
    #            $msg .= sprintf("<TR><TD><B>%10s</B></TD><TD>%s</TD></TR>", $data, $cbus_data{$record}{$data});
    #        }
    #
    #        $msg .= '</TABLE>';
    #        $count++;
    #    }
    #
    #    $msg .= "<HR><p>List CBus Devices: Listed $count CBus devices<p>";
    #    display $msg;
}

#
# Build cbus_procedues.pl code using data from configuration file
#
sub build_cbus_file {

    # Parses through the %cbus_def hash
    # and creates the file cbus_procedures.pl, which contains all the
    # item, event and group definitions for all Cbus units

    my ( $cbus_file, $item, $name, %group_list );
    my %cmd_opts = (
        'relay'    => 'on,off',
        'watchdog' => 'on,off',
        'dimmer'   => 'on,off,5%,10%,20%,30%,40%,50%,60%,70%,80%,90%',
        'oneshot' => 'on'    # FIXME check with RichardM
    );

    # If $cbus_build_debug is true, run in debug mode, otherwise run as normal
    my $cbus_build_debug = $_[0];

    # Setup output filename
    if ($cbus_build_debug) {
        print_log "CBus: build_cbus_file() Start CBus build in TEST mode";
        $cbus_file = $config_parms{code_dir} . "/cbus_procedures.pl.test";

    }
    else {
        print_log "CBus: build_cbus_file() Starting build";
        $cbus_file = $config_parms{code_dir} . "/cbus_procedures.pl";
    }

    rename( $cbus_file, $cbus_file . '.old' )
      or print_log "CBus: build_cbus_file() Could not backup $cbus_file: $!";

    print_log "CBus: build_cbus_file() Saving CBus configs to $cbus_file";
    open( CF, ">$cbus_file" )
      or print_log "CBus: build_cbus_file() Could not open $cbus_file: $!";

    print CF "# Category=CBus_Items\n#\n#\n";
    print CF
      "# Created: $Time_Now, from cbus.xml file: \"$config_parms{cbus_dat_file}\"\n";
    print CF "#\n";
    print CF
      "# This file is automatically created with the CBus command RUN_BUILDER\n";
    print CF "#\n";
    print CF "#\n";
    print CF "# -------------- DO NOT EDIT --------------\n";
    print CF "# ---- CHANGES WILL BE LOST ON REBUILD ----\n";
    print CF "#\n";
    print CF "\n";
    print CF "\n";
    print CF "# Cbus Device Summary List\n#\n";
    my $cbus_prefix = $config_parms{cbus_category_prefix};
    my %item_name   = ();

    foreach my $address ( sort keys %{ $cbus_def->{group} } ) {
        $name = $cbus_def->{group}{$address}{name};
        next if not defined $name;
        $item = $cbus_prefix . $name;
        $item =~ s/ /_/g;
        $item =~ s/-/_/g;
        $item_name{$address} = $item;

        printf CF ( "# Addr:%-25s Object:\$%s\n", $address, $item );
    }

    print CF "\n#\n# Create CBus Items\n#\n";
    foreach my $address ( sort keys %{ $cbus_def->{group} } ) {
        $item = $item_name{$address};
        next if not defined $item;
        $name = $cbus_def->{group}{$address}{name};
        my $pretty_name = $cbus_def->{group}{$address}{label};
        if ( not defined $pretty_name ) {
            $pretty_name = $name;
            $pretty_name =~ s/(\w)([A-Z])/$1 $2/g;
        }
        my $v_item = '$v_' . $item;

        # Create CBus_Item
        print CF "\$$item = new Generic_Item;\n";

        # Set label for CBus group
        print CF "\$$item -> set_label('$pretty_name');\n";

        # Determine type of CBus group
        my $type = $cbus_def->{group}{$address}{type};
        $type = 'dimmer' if not defined $type;
        my $opts = $cmd_opts{$type};

        # set_states for Cbus Items
        print CF "\$$item -> set_states(split ',',\'$opts\');\n";

        #set_states  $TV split ',', $tv_states

        # Create voice command
        my $voice_cmd = $cbus_def->{group}{$address}{voice_cmd};
        if ( not defined $voice_cmd ) {
            $voice_cmd = $name;
        }
        print CF "$v_item = new Voice_Cmd \'$voice_cmd [$opts]\';\n";

        # Add extra info for web interface
        my $info = $cbus_def->{group}{$address}{web_mouse_over};
        if ( not defined $info ) {
            $info = "Item " . $name;
        }

        # Something in the MH code parser breaks when it
        # sees set_info in a line
        my $str1 = "$v_item -> set";
        print CF $str1 . "_info (\'$info\');\n";

        # tie_item the $object to voice command object
        print CF "tie_items $v_item  \$" . $item . ";\n";

        # Add icon for web interface if it is defined
        my $icon = $cbus_def->{group}{$address}{web_icon};
        if ( defined $icon ) {
            print CF "set_icon $v_item '$icon';\n";
        }

        # Create Event Ties
        my $rstring = '$' . $item . '->{set_by}';
        if ( $type eq 'watchdog' ) {

            # In user code use the set timer 15mins, set on, 2hours/15mins

            my $ramptime = $cbus_def->{group}{$address}{watchdog_time};
            $ramptime = $config_parms{cbus_watchdog_timer}
              unless defined $ramptime;
            $ramptime = $WATCHDOG_TIMER_DEFAULT unless defined $ramptime;

            print CF "\$$item " . "-> {watchdog_time} = $ramptime;\n";
            print CF "\$$item " . "-> {watchdog_timer} = new Timer;\n";
            print CF "\$$item " . "-> {watchdog_off_timer} = new Timer;\n";
            print CF "tie_event \$$item \n   "
              . "\'if (\$state eq ON) {    "
              . "cbus_set(\"$address\", ON, $rstring); "
              . "cbus_set(\"$address\", \"1%\", $rstring, "
              . "\$$item"
              . "->{watchdog_time});"
              . "} else {"
              . "cbus_set(\"$address\", \$state, $rstring);}\';\n";
        }
        else {
            # Relay, Dimmer, or OneShot
            print CF "tie_event \$$item \n   \'cbus_set(\"$address\", "
              . "\$state, $rstring)\';\n";
        }

        # Extract groups and store for group creation phase
        foreach my $group ( @{ $cbus_def->{group}{$address}{mh_group} } ) {
            if ( exists $group_list{$group} ) {
                push @{ $group_list{$group} }, '$' . $item;
            }
            else {
                $group_list{$group} = [ '$' . $item ];
            }
        }

        print CF "\n";
    }

    # Create groups using list generated in previous loop
    print CF "\n#\n# Create Groups\n#\n";
    foreach my $group_name ( keys %group_list ) {
        print CF "\$$group_name = new Group();\n";

        foreach my $group_item ( @{ $group_list{$group_name} } ) {
            print CF "\$$group_name -> add($group_item);\n";
        }
        print CF "\n";
    }
    print CF "\n";

    # What follows creates a sub called cbus_update()
    #    It is called by cbus_monitor.pl, whenever there is a message
    #    received from the Cbus.  This is perl code to write perl code
    #    Eval statements seem to be unstable under MH.

    print CF "#\n# Create Master CBus Status Subroutine\n#\n";
    print CF "sub cbus_update {\n\n";
    print CF "\t# *****************************************"
      . "****************************\n";
    print CF "\t# This subroutine is automatically generated by cbus.pl, "
      . "do not edit !\n";
    print CF "\t# *****************************************"
      . "****************************\n";
    print CF "\tmy \$addr = \$_[0];\n";
    print CF "\tmy \$newstate = \$_[1];\n";
    print CF "\tmy \$requestor = \$_[2];\n";
    print CF "\n";
    print CF "\n";

    foreach my $address ( sort keys %{ $cbus_def->{group} } ) {
        $item = $item_name{$address};
        next if not defined $item;
        $item = '$' . $item;

        print CF "\tif (\$addr eq \"$address\") {\n";

        if ( $cbus_def->{group}{$address}{type} eq 'oneshot' ) {
            print CF "\t\t\# This is a ONESHOT device\n";
            print CF "\t\t\$state = state $item;\n";
            print CF "\t\tif ((\$newstate == ON) && (\$state ne \'ON\')) {\n";
            print CF "\t\t\tset $item ON;\n";
            print CF "\t\t\t$item" . '->{set_by}' . " = \$requestor;\n";
            print CF "\t\t} else {\n";
            print CF "\t\t\t\# Ignore\n";
            print CF "\t\t}\n";
            print CF "\t}\n\n";
        }
        else {

            print CF "\t\tset $item \$newstate;\n";
            print CF "\t\t$item" . '->{set_by}' . " = \$requestor;\n";
            print CF "\t}\n\n";
        }
    }

    print CF "}\n";
    print CF "#\n#\n# EOF\n#\n#\n";

    close(CF)
      or print_log "CBbus: build_cbus_file() Could not close $cbus_file: $!";

    print_log "CBUs: build_cbus_file() Completed CBus build to $cbus_file";

}

##############################################################################
##############################################################################
##############################################################################
##############################################################################
###########                                                     ##############
###########        CBus MONITOR                                 ##############
###########                                                     ##############
##############################################################################
##############################################################################
##############################################################################
##############################################################################

#
# Ensure that the Monitor telnet session to CGate remains active
#
if ( not active $cbus_monitor and not $cbus_system_debug ) {

    # Try once a minute or if a recent failure try every second
    # Currently set to 5 seconds
    if ( $New_Minute
        or ( $New_Second and $cbus_monitor_retry++ > $CBUS_RETRY_SECS ) )
    {
        $cbus_monitor_retry = 0;
        print_log "CBus: Restarting CBus Monitor" if $Debug{cbus};
        cbus_monitor_start();
    }
}

#
# Monitor functions
#
sub cbus_monitor_start {

    # Start the CBus listener (monitor)

    if ( active $cbus_monitor) {
        print_log "CBus: Monitor already running, skipping start";

    }
    else {
        $cbus_monitor_retry = 0;
        if ( start $cbus_monitor) {
            print_log "CBus: Monitor started";
        }
        else {
            speak("C-Bus Monitor failed to start");
            print_log "CBus: Monitor failed to start";
        }
    }
}

sub cbus_monitor_stop {

    # Stop the CBus listener (monitor)

    return if not active $cbus_monitor;
    print_log "CBus: Monitor stopping" if $cbus_system_debug;
    stop $cbus_monitor;
}

sub cbus_monitor_status {

    # Return the status of the CBus listener (monitor)

    if ( active $cbus_monitor) {
        print_log "CBus: Monitor is active. Last event: $last_mon_state";
        speak("C-Bus Monitor is active. Last event was $last_mon_state");
    }
    else {
        print_log "CBus: Monitor is NOT running";
        speak("C-Bus Monitor is not running");
    }
}

#
# Main MH Loop Code for Monitor
#
# Monitor and process data comming from CBus server
# Executed every pass of MH

if ( my $cbus_msg = said $cbus_monitor) {
    my @cg = split / /, $cbus_msg;
    my $cg_code = $cg[1];
    my $state_speak;

    if ( $cg_code == 730 ) {    # only code 730 are of interest
                                #print_log "CBus: Monitor=$cbus_msg";

        my $cg_time      = $cg[0];
        my $cg_addr      = $cg[2];
        my $cg_action    = $cg[4];
        my $cg_level     = $cg[5];
        my $cg_source    = $cg[6];
        my $cg_ramptime  = $cg[7];
        my $cg_sessionId = $cg[8];
        my $cg_commandId = $cg[9];

        my $level = abs( substr( $cg_level, 6, 3 ) );
        my $source = substr( $cg_source, 11 );
        my $cbus_state = 0;

        # Determine SOURCE of the command
        my $could_be_ramp_starting = 1;
        if ( $cg_sessionId =~ /$cbus_session_id/ ) {
            $source = "MH";    # Found MisterHouses session ID

        }
        elsif ( $cg_commandId =~ /commandId=(.+)/ ) {

            # If commandId is present then CGate sent the command
            my $command_id = $1;

            # CGate doesn't send a "ramp starting" message
            $could_be_ramp_starting = 0;

            if ( $command_id =~ /^\d+/ ) {

                # Assume that Toolkit is the only software that uses a count
                # for it's command IDs. Would have been helpful if Clipsal
                # had put a label specifying Toolkit as well....
                $source = "Clipsal_ToolKit";

            }
            elsif ( $command_id =~ /MisterHouse/ ) {
                $source = "MisterHouse";

            }
            else {
                # If other software issues CGATE commands using the [] label,
                #  ie.      [DudHomeControl] on //HOME/254/56/1
                # then the source in MH will be shown as "DudHomeControl".
                $source = $command_id;

                # Otherwise, MH will just show that CGate was used.
                $source = "Clipsal_CGate" if $source eq '{none}';
            }

        }
        else {
            $source = "Switch:" . $cbus_def->{unit}{$source}{name};
        }

        # Determine what level is being reported
        my $ramping;
        $cg_ramptime =~ s/ramptime=//i;

        ### if ($could_be_ramp_starting and $cg_ramptime > 0) {
        if ( $cg_ramptime > 0 ) {

            # The group has started ramping
            if ( $level == 255 ) {
                $ramping     = 'UP';
                $state_speak = 'ramping UP';
            }
            else {
                $ramping     = 'DOWN';
                $state_speak = 'ramping DOWN';
            }

        }
        else {
            if ( $level == 255 ) {
                $cbus_state  = ON;
                $state_speak = 'set to ON';

            }
            elsif ( $level == 0 ) {
                $cbus_state  = OFF;
                $state_speak = 'set to OFF';

            }
            else {
                my $plevel = $level / 255 * 100;
                $cbus_state  = sprintf( "%.0f%%",        $plevel );
                $state_speak = sprintf( "dim to %.0f%%", $plevel );
            }
        }

        my $cbus_label = $cbus_def->{group}{$cg_addr}{log_label};
        my $speak_name = $cbus_def->{group}{$cg_addr}{speak_name};
        my $announce   = $cbus_def->{group}{$cg_addr}{announce};

        $cbus_label = $cbus_def->{group}{$cg_addr}{name}
          if not defined $cbus_label;
        $speak_name = $cbus_def->{group}{$cg_addr}{name}
          if not defined $speak_name;
        $announce = 0 if not defined $announce;

        $last_mon_state = "$speak_name $state_speak";

        if ( ( state $v_cbus_speak eq ON ) && ($announce) ) {
            speak($last_mon_state);
        }

        if ( $source eq 'MH' ) {

            # This is a Reflected mesg, we will ignore

        }
        elsif ( not defined $cbus_label ) {
            print_log "CBus: UNKNOWN Address $cg_addr $state_speak "
              . "by \"$source\"";

        }
        elsif ($ramping) {
            print_log "CBus: $cbus_label ramping $ramping by \"$source\"";

            # FIXME set some state in MH. Look at X10 stuff??

        }
        else {
            # Trigger an update to the procedures
            cbus_update( $cg_addr, $cbus_state, 'cbus' );

            if ( $cbus_def->{group}{$cg_addr}{type} eq 'oneshot' ) {
                if ( $config_parms{cbus_log_oneshot} ) {
                    ### FIXME RichardM to test
                    # Device is a one-shot and logging is on
                    print_log "CBus: ONESHOT device $cbus_label "
                      . "set $state_speak by $source";
                }

            }
            else {
                print_log "CBus: $cbus_label $state_speak by \"$source\"";
            }
        }
    }
}

##############################################################################
##############################################################################
##############################################################################
##############################################################################
###########                                                     ##############
###########        CBus TALKER                                  ##############
###########                                                     ##############
##############################################################################
##############################################################################
##############################################################################
##############################################################################

#
# Ensure that the Talker telnet session to CGate remains active
#
if ( not active $cbus_talker and not $cbus_system_debug ) {

    # Try once a minute or if a recent failure try every second
    # Currently set to 5 seconds
    if ( $New_Minute
        or ( $New_Second and $cbus_talker_retry++ > $CBUS_RETRY_SECS ) )
    {
        $cbus_talker_retry = 0;
        print_log "CBus: Restarting CBus Talker" if $Debug{cbus};
        cbus_talker_start();
    }
}

#
# Talker functions
#
sub cbus_talker_start {

    # Starts the CBus command driver (Talker)

    if ( active $cbus_talker) {
        print_log "CBus: Talker already running, skipping start";
        speak("C-Bus talker is already running");

    }
    else {
        set $CBus_Sync OFF;
        $cbus_talker_retry = 0;
        if ( start $cbus_talker) {
            print_log "CBus: Talker started";
        }
        else {
            speak("C-Bus Talker failed to start");
            print_log "CBus: Talker failed to start";
        }
    }
}

sub cbus_talker_stop {

    # Stops the CBus command driver (Talker)

    set $CBus_Sync OFF;
    return if not active $cbus_talker;
    print_log "CBus: Talker stopping";
    stop $cbus_talker;
}

sub cbus_talker_status {

    # Returns the status of the CBus command driver (Talker)

    if ( active $cbus_talker) {
        print_log "CBus: Talker is active. "
          . "Last command sent was: $last_talk_state";
        speak(  "C-Bus Talker is active. "
              . "Last command sent was $last_talk_state" );
    }
    else {
        print_log "CBus: Talker is not running";
        speak("C-Bus Talker is not running");
    }
}

#
# Send level change commands to CGate
#
sub cbus_set {

    # main command handler for CBus bus directives
    # print_log "cbus_set @_";

    my ( $addr, $level, $changed_by, $speed ) = @_;
    my $orig_level = $level;

    if ( $changed_by =~ /\[cbus\.pl\]/ ) {

        # This was a Recursive set, we are ignoring
        # print_log "cbus: ignoring since recursive";
        return;
    }
    else {
        # This was NOT a recursive set, do it
    }

    # Get rid of any % signs in the $Level value
    $level =~ s/%//g;

    if ( ( $level eq ON ) || ( $level eq 'ON' ) ) {
        $level = 255;

    }
    elsif ( ( $level eq OFF ) || ( $level eq 'OFF' ) ) {
        $level = 0;

    }
    elsif ( ( $level <= 100 ) && ( $level >= 0 ) ) {
        $level = int( $level / 100.0 * 255.0 );

    }
    else {
        print_log "CBus: Unknown level \'$level\' passed to cbus_set()";
        return;
    }

    unless ( defined $speed ) {
        $speed = $config_parms{cbus_ramp_speed};
        $speed = 0 if not defined $speed;
    }

    my $cbus_label = $cbus_def->{group}{$addr}{log_label};
    $cbus_label = $cbus_def->{group}{$addr}{name} if not defined $cbus_label;

    my $cmd_log_string = "RAMP $cbus_label set $orig_level, speed=$speed";

    if ( active $cbus_talker) {
        print_log "CBus: $cmd_log_string";
        my $ramp_command =
          "[MisterHouse$cmd_counter] RAMP $addr $level $speed\n";
        set $cbus_talker $ramp_command;
        $last_talk_state = "Ramp unit $addr to level $level, speed $speed";
        $cmd_list[$cmd_counter] = $ramp_command;
        $cmd_counter = 0 if ( ++$cmd_counter > $MAX_CMD_COUNT );
    }
    else {
        print_log "CBus: Talker not active, unable to '$cmd_log_string'";
    }
}

#
# Setup to sync levels of all known addresses
#
sub start_level_sync {
    return if not defined $cbus_def;

    print_log "CBus: Syncing MisterHouse to CBus (Off groups not displayed)";

    set $CBus_Sync OFF;
    $sync_in_progress = 1;
    %addr_not_sync    = %{ $cbus_def->{group} };

    attempt_level_sync();
}

#
# Send commands to synchronise the Misterhouse level to CBus
#
sub attempt_level_sync {
    my @count = keys %addr_not_sync;
    print_log "CBus: attempt_level_sync() count=" . @count if $Debug{cbus};

    if ( not %addr_not_sync ) {
        print_log "CBus: Sync to CGate complete";
        set $CBus_Sync ON;
        $sync_in_progress = 0;

    }
    else {
        print_log "CBus: attempt_level_sync() list:@count" if $Debug{cbus};

        foreach my $addr ( keys %addr_not_sync ) {

            # Skip if CBus scene group address
            if (   $addr =~ /\/\/.+\/\d+\/202\/\d+/
                or $addr =~ /\/\/.+\/\d+\/203\/\d+/ )
            {
                delete $addr_not_sync{$addr};
                next;
            }
            set $cbus_talker "[MisterHouse $addr] get $addr level";
        }

        eval_with_timer 'attempt_level_sync()', $DELAY_CHECK_SYNC;
    }
}

#
# Add an address or group to the hash
#

sub add_address_to_hash {
    my ( $addr, $name ) = @_;
    my $addr_type;

    if ( $addr =~ /\/p\/(\d+)/ ) {

        # Data is for a CBus device eg. switch, relay, dimmer
        $addr_type = 'unit';
        $addr      = $1;
    }
    else {
        # Data is for a CBus "group"
        $addr_type = 'group';
    }

    print_log
      "CBus: add_address_to_hash() Addr $addr is $name of type $addr_type";

    # Store the CBus name and address in the cbus_def hash
    if ( $addr_type eq 'group' ) {
        if ( not exists $cbus_def->{group}{$addr} ) {
            print_log "CBus: add_address_to_hash() group not defined yet, "
              . "adding $addr, $name";
            $cbus_def->{group}{$addr} = {
                name     => $name,
                note     => ["Added by MisterHouse $Date_Now $Time_Now"],
                type     => 'dimmer',
                mh_group => ['CBus']
            };

            # print_log Dumper($cbus_def);
        }
    }
    elsif ( $addr_type eq 'unit' ) {
        if ( not exists $cbus_def->{unit}{$addr} ) {
            print_log "CBus: add_address_to_hash() unit not defined yet, "
              . "adding $addr, $name";
            $cbus_def->{unit}{$addr} = {
                name => $name,
                note => ["Added by MisterHouse $Date_Now $Time_Now"]
            };
        }
    }

}

#
# Main MH Loop Code for  ***** TALKER *****
#
# Process data returned from CBus server after a command is sent
#
if ( my $cbus_data = said $cbus_talker) {
    my $msg_code = -1;
    my $msg_id;

    if ( $cbus_data =~ /(\[.+\]\s+)?(\d\d\d)/ ) {
        $msg_id   = $1;
        $msg_code = $2;
    }

###### Message code 320: Tree information. Returned from the tree command.

    if ( $msg_code == 320 ) {
        if ( not $cbus_got_tree_list ) {
            if ( not $cbus_units_config ) {
                if ( $cbus_data =~ /Applications/ ) {
                    $cbus_units_config = 1;
                }
                elsif ( $cbus_data =~ /(\/\/.+\/\d+\/p\/\d+).+type=(.+) app/ ) {

                    # CGate is listing CBus "devices" (input and output)
                    print_log "CBus: scanned addr=$1 is type $2";

                    # Store unit on a list for later scanning of details
                    push @cbus_unit_list, $1;
                }

            }
            else {
                # CGate is listing CBus "groups"
                if ( $cbus_data =~ /end/ ) {
                    print_log "CBus: end of CBus scan data, got tree list"
                      if $Debug{cbus};
                    $cbus_got_tree_list = 1;
                }
                elsif ( $cbus_data =~ /(\/\/.+\/\d+\/\d+\/\d+).+level=(\d+)/ ) {
                    print_log "CBus: scanned group=$1 at level $2";

                    # Store group on a list for later scanning of details
                    push @cbus_group_list, $1;
                }
            }
        }

###### Message code 342: DBGet response (not documented in CGate Server Guide 1.0.)

    }
    elsif ( $msg_code == 342 ) {
        if ($cbus_scanning_cgate) {

            print_log "CBus: Message 342 response data: $cbus_data"
              if $Debug{cbus};

            if ( $cbus_data =~ /\d+\s+(\d+\/[a-z\d]+\/\d+)\/TagName=(.+)/ ) {

                #response matched against "new" format, i.e. network/app/group
                my ( $addr, $name ) = ( $1, $2 );
                $addr = "//$cbus_project_name/$addr";

                $cbus_scan_last_addr_seen = $addr;

                # $name =~ s/ /_/g;  Change spaces, depends on user usage...
                add_address_to_hash( $addr, $name );

            }
            elsif ( $cbus_data =~ /(\/\/.+\/\d+\/[a-z\d]+\/\d+)\/TagName=(.+)/ )
            {
                #response matched against "old" format, i.e. //project/network/app/group
                my ( $addr, $name ) = ( $1, $2 );

                $cbus_scan_last_addr_seen = $addr;

                # $name =~ s/ /_/g;  Change spaces, depends on user usage...
                add_address_to_hash( $addr, $name );

            }
            print_log "Cbus: end message" if $Debug{cbus};
        }

###### Message code 300: Object information, for example: 300 1/56/1: level=200

    }
    elsif ( $msg_code == 300 ) {

        if ( $cbus_data =~ /(sessionID=.+)/ ) {
            $cbus_session_id = $1;    # Set global session ID
            print_log "CBus: Session ID is \"$cbus_session_id\"";

        }
        elsif ( $cbus_data =~ /networks=(.+)/ ) {
            my $netlist = $1;
            print_log "CBus: Network list - $netlist";
            @cbus_net_list = split /,/, $netlist;

            # Request state of network
            set $cbus_talker "get " . $cbus_net_list[0] . " state";

        }
        elsif ( $cbus_data =~ /state=(.+)/ ) {
            my $network_state = $1;
            print_log "CBus: CGate Status - $cbus_data";
            if ( $network_state ne "ok" ) {
                eval_with_timer 'set $cbus_talker "get '
                  . $cbus_net_list[0]
                  . ' state"', 2;
            }
            else {
                if ($request_cgate_scan) {

                    # This state request was part of scanning startup
                    $cbus_scanning_cgate = 1;    # Set scanning flag
                    $request_cgate_scan  = 0;
                }
                else {
                    # If not a scan, then is a startup sync being kicked off
                    start_level_sync();
                }
            }

        }
        elsif ( $cbus_data =~ /(\/\/[\w|\d]+\/\d+\/\d+\/\d+):\s+level=(.+)/ ) {
            my ( $addr, $level ) = ( $1, $2 );

            my $cbus_state;
            if ( $level == 255 ) {
                $cbus_state = ON;
            }
            elsif ( $level == 0 ) {
                $cbus_state = OFF;
            }
            else {
                my $plevel = $level / 255 * 100;
                $cbus_state = sprintf( "%.0f%%", $plevel );
            }

            # Store new level from sync response
            cbus_update( $addr, $cbus_state, "MisterHouseSync", 0 );
            delete $addr_not_sync{$addr};    # Remove from not sync'ed list
            my $name = $cbus_def->{group}{$addr}{name};
            print_log "CBus: $name is $cbus_state" if $cbus_state ne OFF;
            print_log "CBus: $name ($addr) is $cbus_state" if $Debug{cbus};

        }
        else {
            print_log "CBus: UNEXPECTED 300 msg \"$cbus_data\"";
        }

###### Message code 200: Completed successfully

    }
    elsif ( $msg_code == 200 ) {
        print_log "CBus: Cmd OK - $cbus_data" if $Debug{cbus};

###### Message code 201: Service ready

    }
    elsif ( $msg_code == 201 ) {
        print_log "CBus: Comms established - $cbus_data";

        # Newly started comms, therefore find the networks available
        # then we will wait until CGate has sync'ed with the network
        $request_cgate_scan = 0;
        set $cbus_talker "session_id";
        if ( not defined $cbus_project_name ) {
            print_log "CBus: ***ERROR*** Set \$cbus_project_name in mh.ini";
        }
        else {
            my $cmd =
                "print_log  'CBus: project load $cbus_project_name'; "
              . "set \$cbus_talker 'project load $cbus_project_name'; "
              . "print_log  'CBus: project use $cbus_project_name'; "
              . "set \$cbus_talker 'project use $cbus_project_name'; "
              . "print_log  'CBus: project start $cbus_project_name'; "
              . "set \$cbus_talker 'project start $cbus_project_name'; "
              . "set \$cbus_talker 'get cbus networks'";
            eval_with_timer $cmd, 2;
        }

###### Message code 401: Bad object or device ID

    }
    elsif ( $msg_code == 401 ) {
        print_log "CBus: $cbus_data";

###### Message code 408: Indicates that a SET, GET or other method
###### failed for a given object

    }
    elsif ( $msg_code == 408 ) {
        print_log "CBus: **** Failed Cmd - $cbus_data";
        if ( $msg_id =~ /\[MisterHouse(\d+)\]/ ) {
            my $cmd_num = $1;
            my $cmd     = $cmd_list[$cmd_num];
            if ( $cmd ne "" ) {
                print_log "CBus: Trying command again - $cmd";
                set $cbus_talker $cmd;
                $cmd_list[$cmd_num] = "";
            }
            else {
                print_log "CBus: 2nd failure - abandoning command";
            }
        }

###### Message code unhandled

    }
    else {
        print_log "CBus: Cmd port - UNHANDLED: $cbus_data";
    }
}

#
# Control scanning of the CGate configuration
#
if ( active $cbus_talker and $cbus_scanning_cgate ) {
    if ( not $cbus_scanning_tree ) {
        if ( my $network = pop @cbus_net_list ) {

            # Cleanup from any previous scan and initialise flags/counters
            $cbus_units_config  = 0;
            $cbus_got_tree_list = 0;
            undef @cbus_group_list;
            undef @cbus_unit_list;
            undef $cbus_scan_last_addr_seen;
            $cbus_group_idx = 0;
            $cbus_unit_idx  = 0;

            # Request from CGate a list of addresses on network
            $network = "//$cbus_project_name/$network";
            print_log "CBus: Scanning network $network";
            set $cbus_talker "tree $network";

            $cbus_scanning_tree = 1;

        }
        else {
            # All networks scanned - set completion flag
            ### FIXME - RichardM test with two networks??
            print_log "Cbus: leaving scanning mode" if $Debug{cbus};
            $cbus_scanning_cgate = 0;
            print_log "CBus: CBus server scan complete";
            write_def_file();
        }

    }
    elsif ($cbus_got_tree_list) {
        if ( $cbus_group_idx < @cbus_group_list ) {
            my $group = $cbus_group_list[ $cbus_group_idx++ ];
            print_log "Cbus: dbget group $group" if $Debug{cbus};
            set $cbus_talker "dbget $group/TagName";

        }
        elsif ( $cbus_unit_idx < @cbus_unit_list ) {
            my $unit = $cbus_unit_list[ $cbus_unit_idx++ ];
            print_log "Cbus: dbget unit $unit" if $Debug{cbus};
            set $cbus_talker "dbget $unit/TagName";

        }
        else {
            if (
                $cbus_scan_last_addr_seen eq $cbus_unit_list[$#cbus_unit_list] )
            {
                # Tree Scan complete - set tree completion flag
                print_log "Cbus: leaving scanning mode" if $Debug{cbus};
                $cbus_scanning_tree = 0;
            }
        }

    }
    else {
        # We are in scanning_tree mode, and waiting for response to the
        # TREE command. The TREE command lists each address on the particular
        # network. Then we will "dbget" each address. (That will start when
        # cbus_got_tree_list becomes true.
    }
}

