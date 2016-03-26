
=head1 B<Clipsal CBus>

=head2 SYNOPSIS

Clipsal_CBus.pm - support for Clipsal CBus

=head2 DESCRIPTION

This module adds support for ...

=cut

package Clipsal_CBus;

# Used solely to provide a consistent logging feature, copied from Nest.pm

use strict;

# Set up the groups hash of hashes, a key-value hash, CBus group address is the key.

%Clipsal_CBus::Groups = ();
%Clipsal_CBus::Units = ();
$Clipsal_CBus::Command_Counter = 0;
$Clipsal_CBus::Command_Counter_Max = 100;

$Clipsal_CBus::Talker = new Socket_Item( undef, undef, $::config_parms{cgate_talk_address} );
$Clipsal_CBus::Talker_v = new Voice_Cmd("cbus talker [Start,Stop,Status,Scan]");

$Clipsal_CBus::Monitor = new Socket_Item( undef, undef, $::config_parms{cgate_mon_address} );
$Clipsal_CBus::Monitor_v = new Voice_Cmd("cbus monitor [Start,Stop,Status]");

#log levels
my $warn    = 1;
my $notice  = 2;
my $info    = 3;
my $debug   = 4;
my $trace   = 5;

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

sub generate_voice_commands {
    
    &::print_log("Generating Voice commands for all CBus objects");
    
    my $object_string;
    for my $object (&main::list_all_objects) {
        next unless ref $object;
        next
        unless $object->isa('Clipsal_CBus::Group');
        
        #get object name to use as part of variable in voice command
        my $object_name   = $object->get_object_name;
        my $object_name_v = $object_name . '_v';
        $object_string .= "use vars '${object_name}_v';\n";
        
        #Convert object name into readable voice command words
        my $command = $object->{label};
        #$command =~ s/^\$//;
        #$command =~ tr/_/ /;
        
        #my $group = ( $object->isa('Insteon_PLM') ) ? '' : $object->group;
        
        #Get list of all voice commands from the object
        my $voice_cmds = $object->get_voice_cmds();
        
        #Initialize the voice command with all of the possible device commands
        $object_string .= "$object_name_v  = new Voice_Cmd '$command ["
        . join( ",", sort keys %$voice_cmds ) . "]';\n";
        
        #Tie the proper routine to each voice command
        foreach ( keys %$voice_cmds ) {
            $object_string .=
            "$object_name_v -> tie_event('"
            . $voice_cmds->{$_}
            . "', '$_');\n\n";
        }
        
        #Add this object to the list of CBus Voice Commands on the Web Interface
        $object_string .=
        ::store_object_data( $object_name_v, 'Voice_Cmd', 'Clipsal CBus',
        'Clipsal_CBus_commands' );
    }
    
    #Evaluate the resulting object generating string
    package main;
    eval $object_string;
    print_log ("Error in cbus_item_commands: $@\n") if $@;
    package Clipsal_CBus;
}

1;

