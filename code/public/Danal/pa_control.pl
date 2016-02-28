# Category=Sound

#@ Controls (new) weeder board for "speech by room" via relays
#@ See code for required changes for your speakers.

##################################################################
# Sets relays to control speech by room.
#
# Coded for www.weedtech.com digital IO module part # WTDIO-M.
#   WTDIO-M used to control two banks of ELK-924-4 "Sensitive Relay" www.elkproducts.com
#   Many alarm system companies sell these relays.
#
# Can be used as model for any DIO board/relay combination.
#
# Code is in three parts:
# 1. Code executed as a result of pre hook to speak & play.
#    This is automatically called by mh 'kernel' before each speak or play event.
#    Generally used to set relays ON.
# 2. Code executed every user script pass.
#    Generally used to set relays OFF.
# 3. Various commands to allow interaction with (1) and (2)
#
#
#  By: Danal Estes, N5SVV
#  E-Mail: danal@earthling.net
##################################################################

# Also see mh/code/public/Danal/Master_Bedroom.pl for integration examples.

##################################################################
# Define objects used by both parts of code
##################################################################

my @speakers;
my $DIO_address = 'A'
  ;  # Weeder DIO boards have an DIP switch settable prefix.  Set this to match.
my $port_name =
  'weeder';    # edit to match weeder serial port name from mh.private.ini
$pa_speaker_timer = new Timer;

# PA relay items.
# Portion of name after "$pa_" matches to "rooms=" strings in speak commands.
#
# In addition to being standard generic objects, these objects have additional attributes:
#   $pa_xyz->{notall}     manually set to true to exclude speaker from "room=all"
#   $pa_xyz->{bitmask}    the bitmask for an individual bit in the byte command to the DIO card.
# These are used by code; do not set manually:
#   $pa_xyz->{sleeping}   set to true to override relay control to OFF
#   $pa_xyz->{speaking}   set to true by decision code; read by the code that writes byte masks to the DIO board
#
$pa_master             = new Generic_Item;
$pa_master->{bitmask}  = 0x01;
$pa_office             = new Generic_Item;
$pa_office->{bitmask}  = 0x02;
$pa_kitchen            = new Generic_Item;
$pa_kitchen->{bitmask} = 0x04;
$pa_garage             = new Generic_Item;
$pa_garage->{bitmask}  = 0x08;
$pa_5                  = new Generic_Item;
$pa_5->{bitmask}       = 0x10;
$pa_6                  = new Generic_Item;
$pa_6->{bitmask}       = 0x20;
$pa_7                  = new Generic_Item;
$pa_7->{bitmask}       = 0x40;
$pa_outdoor            = new Generic_Item;
$pa_outdoor->{bitmask} = 0x80;
$pa_outdoor->{notall}  = 1;

@speakers = (
    $pa_master, $pa_office, $pa_kitchen, $pa_garage, $pa_5, $pa_6, $pa_7,
    $pa_outdoor
);

##################################################################
# Code run by speak & play pre-hooks
##################################################################

&Speak_pre_add_hook( \&pa_stub ) if $Reload;
&Play_pre_add_hook( \&pa_stub )  if $Reload;

sub pa_stub {
    my (%parms) = @_;
    my $rooms = $parms{rooms};
    $rooms = 'all' unless $rooms;

    my $room;
    for $room ( split( ',', $rooms ) ) {
        $room = lc $room;
        if ( $room =~ /all/i ) {
            for $ref (@speakers) {
                $ref->{speaking} = !( $ref->{notall} or $ref->{sleeping} );
                print_log "Room $ref->{object_name} set $ref->{speaking}"
                  if ( $config_parms{debug} eq 'pa' );
            }
        }
        else {
            no strict 'refs';
            $ref = ${"pa_$room"};
            if ( !( $ref->{notall} or $ref->{sleeping} ) ) {
                $ref->{speaking} = !$ref->{sleeping};
                print_log "Room $ref->{object_name} set $ref->{speaking}"
                  if ( $config_parms{debug} eq 'pa' );
            }
        }
    }
    &set_DIO;
    select undef, undef, undef, .05; # adjust to delay sound until relays settle
}

##################################################################
# Code run every pass
##################################################################

# Add a fail-safe turn speakers off timer

set $pa_speaker_timer 10 if state $mh_speakers eq ON;
run_voice_cmd 'speakers off' if expired $pa_speaker_timer;

# mh_sound.pl monitors for end-of-speech and will set $mh_speakers OFF on that pass

if ( state_now $mh_speakers eq OFF ) {
    for $ref (@speakers) {
        if ( $ref->{speaking} ) {
            $ref->{speaking} = 0;
            print_log "Room $ref->{object_name} set OFF from speakers off"
              if ( $config_parms{debug} eq 'pa' );
        }
    }
    &set_DIO;
    unset $pa_speaker_timer;
}

##################################################################
# Various support commands
##################################################################

# Voice command to turn all speakers on or off

$v_pa_speakers = new Voice_Cmd('Speakers [on,off]');
$v_pa_speakers->set_info('Turn all the PA speakers on/off');

my $ref;
if ( $state = said $v_pa_speakers) {
    for $ref (@speakers) {
        $ref->{speaking} = $state eq 'on' ? 1 : 0;
        print_log "Room $ref->{object_name} set $state from voice command "
          if ( $config_parms{debug} eq 'pa' );
    }
    &set_DIO;
}

$v_master_nap = new Voice_Cmd('Master Bedroom Nap [on,off]');
$v_master_nap->set_info('Override PA speaker in Master');

if ( $state = said $v_master_nap) {
    $pa_master->{sleeping} = $state;
}

##################################################################
# Write to DIO board; called from both hook code and loop code
##################################################################

sub set_DIO {
    my $byte = 0x00;
    for $ref (@speakers) {
        if ( $ref->{speaking} ) {
            $byte = $byte | $ref->{bitmask};
            print_log "DIO write - room "
              . $ref->{object_name}
              . " mask "
              . ( sprintf "%0.2X", $ref->{bitmask} )
              . " ORed into byte giving "
              . ( sprintf "%0.2X", $byte )
              if ( $config_parms{debug} eq 'pa' );
        }
    }
    my $command = $DIO_address . "W" . sprintf "%0.2X", $byte;
    print_log "DIO write - command = $command"
      if ( $config_parms{debug} eq 'pa' );
    $main::Serial_Ports{$port_name}{object}->write( $command . "\r" )
      if $main::Serial_Ports{$port_name}{object};
    set $pa_speaker_timer 10 if $byte;    #Set saftey time if any speakers on.
}

##################################################################
# Create as serial object to avoid "unmatched incoming serial" when DIO board echos commands
##################################################################

if ($Reload) {
    $DIO_board = new Serial_Item( $DIO_address . "!", "power on", $port_name );

    # $DIO_board ->add($DIO_address . "!","badcomm");  # Leave commented, so bad comm reply from board will get logged
    for my $i ( 0 .. 255 ) {
        my $hex = sprintf "%0.2X", $i;
        $DIO_board->add( ( $DIO_address . "W" . $hex ), "s$hex" );
    }
}

# and read it, to avoid ever growing buffers
my $dummy = said $DIO_board;
print_log "Heard from DIO board - data = $dummy"
  if ( $dummy ne '' )
  and ( $config_parms{debug} eq 'padata' );

