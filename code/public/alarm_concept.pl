# Category=Alarm System
#####################################################################
# Script for handling alarm functions from the Concept alarm system #
# refer to instructions in the Concept.pm file                      #
#####################################################################
# 20020601 - Nick Maddock - Creation day                            #
#####################################################################

# Create the Alarm objects
my $ComputerRoom = new ConceptZone( 'Computer Room', 120 )
  ;    # Zone object to handle the motion sensor in the computer room
my $LoungeRoom =
  new ConceptZone( 'Lounge Room', 120 );   # Motion sensor in the computer room.
my $BedRoom =
  new ConceptZone( 'Bed Room', 120 );      # Motion Sensor in the bed room
my $BAbyRoom = new ConceptZone( 'Baby Room', 120 );
my $BackDoor = new ConceptZone('Back Door');    # Read switch on back door
my $FrontDoor = new ConceptZone('Front Door');   # Reed switch on the front door

my $state;
my $CompLastState;
my $LoungeLastState;
my $CompLastOccupied;
my $FrontDoorState;

# Just a simple piece of test code, it will print out anything it recieved
#if (my $log = said $ComputerRoom) {
#   print_log "ComputerRoom $Loop_Count said = $log";
#}

if ( $CompLastState ne $ComputerRoom->state ) {
    $CompLastState = $ComputerRoom->state;
    print_log "Alarm.pl:Computer Room change state to $CompLastState";

}

#if( $LoungeLastState ne $LoungeRoom->state)
#{
#	$LoungeLastState = $LoungeRoom->state;
#	print_log "Alarm.pl:Lounge Room change state to $LoungeLastState";
#
#}

if ( $CompLastOccupied != $ComputerRoom->occupied ) {
    $CompLastOccupied = $ComputerRoom->occupied;
    print_log "Alarm.pl: Computer Room Occupied changed to $CompLastOccupied";
}

if ( $FrontDoorState != $FrontDoor->state ) {
    $FrontDoorState = $FrontDoor->state;
    if ( $FrontDoorState == 1 ) {
        print_log "Alarm.pl: The front door is open";
    }
    else {
        print_log "Alarm.pl: The front door is closed";
    }
}
