
=head1 B<Clipsal CBus>

=head2 SYNOPSIS

Clipsal_CBus.pm - support for Clipsal CBus.

=head2 DESCRIPTION

This module adds support for Clipsal CBus automation systems, and is a refactor of the original cbus.pl code by Richard Morgan and Andrew McCallum.
 
******* IMPORTANT *******
***
*** You must change the C-Gate configuration files found under the 'config' directory.
***
*** In C-GateConfig.txt: Change global-event-level from 5 to 7, the new line will be:
***	    "global-event-level=7"
***
*** In access.txt: Add a new line with your subnet,
*** eg. if your IP address is 192.168.72.42, then add the following line:
***	    "interface 192.168.72.255 Program"
***
******* IMPORTANT *******

=head3 How CGate integrates with MH

All CBus objects (i.e. the CGate interface, groups and units) are defined in a standard mht
file. Misterhouse creates objects from the mht file at $Reload, and subsequently creates corresponding voice command
objects on the next $Reload. As the MH obects are created, their details (e.g. address, name) are added
to a hash oh hashes (one each for Groups and Units) which is used to map a received CBus message back to an MH object.
 
On $Relaod, this module checks to see if there is a hash of group objects. If not, presumablt we haven't defined any group objects in
mht file, so we walk the tree of objects in CBus, and output to results to a generated mht file. So, all that's needed to get going is
to:
 
1) Create an mht file with just a CGate object defined. There is an example in the code directory.
2) Define the CBus settings in the ini file (see below)
3) Run MH to generate an mht file (typically called cbus.mht.generated)
4) Rename the generated mht file to make it valid (e.g. cbus.mht)
5) Edit the mht file as required, e.g. to add group objects to MH groups
6) reload
7) Enjoy (and report bugs)

The $object_vs are all voice commands, and in this version they are NOT used to control
a Cbus device from the web.  Each CBus group object has it's own set() method which
ensures that any actions are reflected both in MH and on the CBus. Therefore, any changes to CBus are reflected
in the web interface in real time.
 
Each $v_object is tied to its respective $object. In program control (testing the state of an $object, or setting a $object) are all
performed against the $object, although you can set the $v_object, its state will not
reflect any updates from the actual CBus.

Remember, the CBus is interactive, it can receive as well as issue commands.

So, you should always use the $object in your code, as it has it's own set() method. Notice how the last 'set_by'
directive was also passed, this is to ensure that we do not create endless message loops.
When the set() sub is called the actual CBus device is set to that state
assuming it was not the CBus that actually initiated this set in the first place. For example, in user code,
you might use something like this:-
 
 if (time_now "$Time_Sunset") {
    speak "I just turned the entry light on at $Time_Now";
    $Front_Entrance_Light->set('on','user code');
 }

CGate itself repeats all commands received back to MH via the CBus monitor. Therefore MH listens for these 
commands and then sets the appropriate $object, but this is ignored if MH was in fact the source of the set.

When MH starts up, the cbus code will automatically attempt to sync MH to the current
state of CGate. CGate of course, will reflect the physical state of the CBus network.
When the sync is complete, the $CBus_Sync will be set ON.

mh.private.ini Settings
===============
Category = CBus
cbus_project_name       = CARLYLE
cgate_mon_address       = 192.168.1.180:20024
cgate_talk_address      = 192.168.1.180:20023
cbus_dat_file           = cbus.xml              #deprecated from original cbus.pl code
cbus_mht_file           = cbus.mht.generated
cbus_category_prefix    = cbus_                 #deprecated from original cbus.pl code
cbus_ramp_speed         = 0

=cut

package Clipsal_CBus;

use strict;

%Clipsal_CBus::Groups              = ();
%Clipsal_CBus::Units               = ();
$Clipsal_CBus::Command_Counter     = 0;
$Clipsal_CBus::Command_Counter_Max = 100;

$Clipsal_CBus::Talker  = new Socket_Item( undef, undef, $::config_parms{cgate_talk_address} );
$Clipsal_CBus::Monitor = new Socket_Item( undef, undef, $::config_parms{cgate_mon_address} );

$Clipsal_CBus::Talker_last_sent = "N/A";

=head2 FUNCTIONS
 
=over
 
=item C<debug ( $message, $level )>
 
Provides a standard logging function for the CBus packages.
 
=cut

#log levels
my $warn   = 1;
my $notice = 2;
my $info   = 3;
my $debug  = 4;
my $trace  = 5;

&::print_log("[Clipsal CBus] CBus logging at level $::Debug{cbus}");

sub debug {
    my ( $self, $message, $level ) = @_;
    $level = $info if $level eq '';
    my $line   = '';
    my @caller = caller(0);
    if ( $::Debug{cbus} >= $level || $level == 0 ) {
        $line = " at line " . $caller[2]
          if $::Debug{cbus} >= $trace;
        &::print_log( "[" . $caller[0] . "] " . $message . $line );
    }
}

=item C<generate_voice_commands ()>
 
Generates voice commands correspnding to the CBus group objects. When a new CGate object is instantiated, it
adds a post reload hook into &main to run this function.
 
=cut

sub generate_voice_commands {

    &::print_log("[Clipsal CBus] Generating Voice commands for all CBus group objects");

    my $object_string;
    for my $object (&main::list_all_objects) {
        next unless ref $object;
        next unless $object->isa('Clipsal_CBus::Group');

        #get object name to use as part of variable in voice command
        my $object_name   = $object->get_object_name;
        my $object_name_v = $object_name . '_v';
        $object_string .= "use vars '${object_name}_v';\n";
        my $command = $object->{label};

        #Get list of all voice commands from the object
        my $voice_cmds = $object->get_voice_cmds();

        #Initialize the voice command with all of the possible device commands
        $object_string .= "$object_name_v  = new Voice_Cmd '$command [" . join( ",", sort keys %$voice_cmds ) . "]';\n";

        #Tie the proper routine to each voice command
        foreach ( keys %$voice_cmds ) {
            $object_string .= "$object_name_v -> tie_event('" . $voice_cmds->{$_} . "', '$_');\n\n";
        }

        #Add this object to the list of CBus Voice Commands on the Web Interface
        $object_string .= ::store_object_data( $object_name_v, 'Voice_Cmd', 'Clipsal CBus', 'Clipsal_CBus_commands' );
    }

    #Evaluate the resulting object generating string
    package main;

    eval $object_string;
    print_log("Error in cbus_item_commands: $@\n") if $@;

    use vars '$CBus_Talker_v';
    $CBus_Talker_v = new Voice_Cmd("cbus talker [Status,Scan]");
    &main::register_object_by_name( '$CBus_Talker_v', $CBus_Talker_v );
    $CBus_Talker_v->{category}    = "Clipsal CBus";
    $CBus_Talker_v->{filename}    = "Clipsal_CBus_commands";
    $CBus_Talker_v->{object_name} = '$CBus_Talker_v';

    use vars '$CBus_Monitor_v';
    $CBus_Monitor_v = new Voice_Cmd("cbus monitor [Status]");
    &main::register_object_by_name( '$CBus_Monitor_v', $CBus_Monitor_v );
    $CBus_Monitor_v->{category}    = "Clipsal CBus";
    $CBus_Monitor_v->{filename}    = "Clipsal_CBus_commands";
    $CBus_Monitor_v->{object_name} = '$CBus_Monitor_v';

    package Clipsal_CBus;
}

=head1 AUTHOR
 
Richard Morgan, omegaATbigpondDOTnetDOTau
Andrew McCallum, Mandoon Technologies, andyATmandoonDOTcomDOTau
Jon Whitear, jonATwhitearDOTorg
 
=head1 VERSION HOSTORY
 
03-12-2001
     Modified to support c-gate 1.5
23-06-2002
     Monitor: Source name now works, and shows 'MH' is source 0
05-07-2002
     Modified for cbus_dat.csv input file support
     Added groups and set_info support
06-07-2002
     Minor changes to support new cbus_builder
     Modified to support global %cbus_data hash
     removed make_cbus_file(), replaced with cbus_builder.pl
11-07-2002
     Added announce flag to cbus_dat.csv, and conditional speak flag $announce
19-09-2002
     Fixed bug in cbus_set() that prevented dimming numeric % set values
     being accepted.  Dimming now works.
21-09-2002
     Modified cbus_groups and cbus_catagories to read from input file
     rather than hard coded
     Put in config item cbus_category_prefix
     Comments in input file now allowed
     Fixed some other minor things
22-09-2002 V2.0
     Collapsed cbus_talker.pl, cbus_builder.pl and cbus_monitor.pl
     into one new file, cbus.pl.  Now issued as V2.0.
 
V2.1    Fixed up some menu uglies.
        Improved coding in monitor loop
        Fixed up code labels, docs etc
 
V2.2    Changed all speak() calls to say 'C-Bus' rather than 'CBus', so the diction is correct

V2.2.1  Fixed minor bug in cbus monitor start voice command

V2.2.2  Implemented;
        oneshot device type
        cbus_oneshot_log config param
 
V2.2.3  Made the dump_cbus_data format pretty HTML tables

V3.0    2008-02-04
        Fixed to work with C-Gate Version: v2.6.1 (build 2236)
        Latest version as of June 2008
        Now reports the name of the source unit that modified a group level.
        Added ability to scan CGate for groups and output to config file.
        *** Configuration only requires running Builder to scan cgate and
        *** build XML file, then commanding MH to "reload code". Job Done.
        *** Customisation if wanted can be done through the config file.
        Changed config file to XML format.
        Builder command auto scans CGate if no config file exists.
        Fixed interpretation of dimming commands.
        PROD is the default state. In PROD, no option to stop comms.
        Changed DEV to DEBUG for commonality.
        Monitor and Talker attempt to always run unless in DEBUG state.
 
V3.0.1	2013-11-22
        Fixed to work with C-Gate Version: v2.9.7 (build 2569), which returns
        cbus addresses in the form NETWORK/APPLICATION/GROUP rather than
        //PROJECT/NETWORK/APPLICATION/GROUP.
        Add logging to aid debugging cbus_builder
        Contributed by Jon Whitear <jonATwhitearDOTorg>
 
V3.0.2  2013-11-25
        Add support for both formats of return code, i.e. NETWORK/APPLICATION/GROUP
  	    and //PROJECT/NETWORK/APPLICATION/GROUP.
 
V3.0.3	2013-11-28
        Test debug flag for logging statements.
 
V4.0    2016-03-25
        Refactor cbus.pl into Clipsal_CBus.pm, CGate.pm, Group.pm, and Unit.pm, and
        make CBus support more MisterHouse "native".
 
=head1 LICENSE
 
This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as 
published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
 
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty 
of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 
You should have received a copy of the GNU General Public License along with this program; if not, write to the 
Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 
=cut

1;
