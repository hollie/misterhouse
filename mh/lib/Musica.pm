=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Musica.pm

Description:
   Allows control of the Musica whole-house audio system by Netstreams over the
   RS232 port.  This system has excellent controllability through Misterhouse
   and provides 6 zones and 4 sources with very nice keypads.

   http://www.netstreams.com

   Note that you must use a null-modem cable between the Musica system and your
   Misterhouse computer.

   This module uses Rev 2.0 of the Musica RS-232 protocol.

Author:
	Kirk Bauer
	kirk@kaybee.org

License:
	This free software is licensed under the terms of the GNU public license.

Initialization:
   You can define any number of Musica systems, but each one requires its own
   serial port.  To begin with, come up with a name for your object such as
   $Musica.  Then add an entry to your mh.private.ini file:

      Musica_serial_port=/dev/ttyS9

   If you wanted to define two Musica systems, you would just choose two unique
   names:

      Musica1_serial_port=/dev/ttyS9
      Musica2_serial_port=/dev/ttyS10

   Once you have specified which serial port to use, simply define the main
   object and your zone objects in your .mht file:

      MUSICA, Musica
      MUSICA_ZONE, music_kitchen,    Musica, 1
      MUSICA_ZONE, music_master_bed, Musica, 2

   This would define the object $Musica, with zone 1 named $music_kitchen, and
   zone 2 named $music_master_bed.  If you have more than one system to
   control, just use the same names as you used in your .ini file:

      MUSICA, Musica1
      MUSICA, Musica2
      MUSICA_ZONE, music_kitchen,     Musica1, 1
      MUSICA_ZONE, music_master_bed,  Musica1, 2
      MUSICA_ZONE, music_patio,       Musica2, 1
      MUSICA_ZONE, music_dining_room, Musica2, 2

   Finally, you can define an object representing each of the four Musica
   sources if you so desire.  This is only necessary if you need to do
   something like start or stop an MP3 player or turn something on via X10 when
   a source is accessed, if you want to watch for users changing the source
   labels from keypads, or if you want to change the source labels from
   Misterhouse.  Finally, if you want to watch for button presses or cause
   buttons to be pressed through Misterhouse, these are useful.  These are not
   required for casual use.

      MUSICA_SOURCE, mrhouse_speech, Musica, 1
      MUSICA_SOURCE, am_fm_tuner,    Musica, 2
      MUSICA_SOURCE, music_source3,  Musica, 3
      MUSICA_SOURCE, music_source4,  Musica, 4

Interface Overview:
   All objects (the main Musica object, the zone objects, and the source objects)
   will return various states (as documented below) when somebody performs any
   kind of action from a keypad.

   If somebody changes the volume in a specific zone, for example, the object
   for that zone will have a state of 'volume_changed'.  You can watch for
   those states as follows:

      if ($state = state_now $music_kitchen) {
         print_log "Kitchen keypad new state: $state";
      }

   Note that when changes are made FROM Misterhouse (using the various
   controlling functions such as set_volume()) no state will be returned.  In
   this case, you can see that your command took effect by calling get_volume()
   and seeing that it returns the volume you set.  Note that this function will
   return your new value only after your command has been sent to the Musica
   system and it has confirmed your command.  If there is a large queue of
   pending commands this can take several seconds.

   Also, many functions can be called on either the main Musica object or one
   only one zone object.  You can, for example, call $Musica->set_volume('100%')
   to set all zones to 100% volume or call $music_kitchen->set_volume('100%') to
   only change the volume of one zone.  But even if you change the volume of
   all zones using the main object, you must still call get_volume() on the zone
   objects since the system as a whole doesn't actually have a volume.

   Finally, if any object returns a state of 'error', it means that an error
   was encountered with the initialization of the system (i.e. a zone keypad
   was not found) or there was a problem executing one of your commands.
   The error will be displayed in the print log but you can also call
   get_last_error() on any object to see this error message.

Controlling either all zones or one zone:
   These functions can all be called on the main Musica object to influence
   all zones or can be called on one specific zone object:

   set_treble(level): Sets the treble level for the zone.  Valid values are -14
   through 14 with 0 being the default (note that the keypads only have a
   resolution of two, such as -4, -2, 0, 2, 4, and a value such as 1 will be
   the same as 0 or 2).

   set_bass(level): Sets the bass level for the zone.  Valid values are -14
   through 14 with 0 being the default (note that the keypads only have a
   resolution of two, such as -4, -2, 0, 2, 4, and a value such as 1 will be
   the same as 0 or 2).

   set_source(identifier): Changes zone or zones to specified source.  The
   parameter can be a number 1-4, the letter 'E' for the local expansion port,
   the label assigned to a specific source (such as 'MP3'), or a source object.
   Examples:
      $zone1_obj->set_source(1);
      $Musica->set_source('E');
      $zone1_obj->set_source('MP3');
      $Musica->set_source($source1_obj);

   set_volume(level): Sets the volume of one or all zones, where the level 
   specified must range from 0 to 35.  Can also be specified as a percentage
   where '0%' is off and '100%' is full volume.

   set_balance(level): Sets the balance where -7 is full-left, +7 is full-right,
   and 0 is centered.

   mute(): Mutes one or all zones.

   unmute(): Unmutes one or all zones.

   loudness_on(): Turns on loudness in one or all zones.

   loudness_off(): Turns off loudness in one or all zones.

   internal_amp(): Use only the internal amplifier.

   both_amps(): Use both internal and external amplifiers.

   external_amp(): Use only the external amplifier.

   green_backlight(): Set backlight to the color green.

   amber_backlight(): Set backlight to the color amber.

   set_backlight_brightness(level): Sets backlight level to a value between
      0 and 8 where 0 is off and 8 is full brightness.  Can also be specified
      with a percentage where '0%' is off and '100%' is full brightness.

   nudge_volume_down(): Reduces the volume one notch.

   nudge_volume_up(): Increases the volume one notch.

   nudge_bass_down(): Reduces the bass one notch.

   nudge_bass_up(): Increases the bass one notch.

   nudge_treble_down(): Reduces the treble one notch.

   nudge_treble_up(): Increases the treble one notch.

   nudge_balance_left(): Balance shifted one notch to the left.

   nudge_balance_right(): Balance shifted one notch to the right.

   lock_menu(): Locks the menu on the keypad to prevent the user from
      entering the setup menu.  Source selection and volume can still
      be changed.

   unlock_menu(): Unlocks the menu.

Controlling the Musica system object:
   The following functions allow you to make changes to the Musica system
   as a whole from Misterhouse.  
   
   all_off(): Turn off all zones.

Retrieving data from the Musica system object:
   get_object_version(): Returns the version of the Musica object.
   get_port_name(): Returns the name of the serial port used for this object.
   get_zones(): Returns list of zone objects associated with this system.
   get_sources(): Returns list of source objects associated with this system.
   get_adc_version(): Returns the version string as reported by the Audio
      Distribution Center.

Monitoring the Musica system object:
   Following is a list of states that may be returned by the Musica system:

   error: An error has occurred, call get_last_error() for details.

Controlling the Musica zone objects:
   The following functions allow you to make changes to a specific Musica
   zone from Misterhouse.
   
   set_source(source): Sets the zone to the specified source, where 'source'
   is a number between 1 and 4 or E for the local expansion source.  Turns 
   the zone ON if it is not already on.

   turn_off(): Turns off the zone.
   nudge_source_up(): Switches to the next source (must already be on).
   nudge_source_down(): Switches to the previous source (must already be on).

Retrieving data from the Musica zone object:
   get_musica_obj(): Returns the main musica object.
   get_zone_num(): Returns the zone number (from 1 to 6) for this object.
   get_keypad_version(): Returns the version number returned by the keypad.
   get_last_on_time(): Returns the last time the keypad was turned on
      (in Epoch format, as $::Time expresses it)
   get_source(): Returns the currently-selected source number.
   get_volume(): Returns the volume, from 0 to 35.
   get_bass_level(): Returns the bass level from -14 to 14.
   get_treble_level(): Returns the bass level from -14 to 14.
   get_balance(): Returns the balance where -7 is full-left, 7 is full-right,
      and 0 is centered.
   get_loudness(): Returns 1 if on, 0 if off.
   get_mute(): Returns 1 if on, 0 if off.
   get_blcolor(): Returns 'green' or 'amber' to indicate backlight color.
   get_brightness(): Returns backlight brightness from 0 to 8 where 0 means
      that the backlight is currently off.
   get_audioport: Returns 1 if the audioport is connected.
   get_amp: Returns 'room_amp', 'both', or 'external_amp'.
   get_locked(): Returns 1 if the keypad is locked.
   get_overheat(): Returns 1 if the keypad is overheated.

Monitoring the Musica zone objects:
   You can watch for state changes of the Musica zone object to see when a
   user changes the system in a way that affects a particular zone.

   error: An error has occurred, call get_last_error() for details.
   zone_on: The zone was turned on from an off state.
   zone_off: The zone was turned off from an on state.
   source_changed: The zone is already on and a user changed the source.
   changed_label_source_X: This zone keypad was used to change the label
      of source X (where X is a number from 1 to 4).
   volume_changed: Volume of the zone was changed. 
   bass_changed: Bass level of the zone was changed. 
   treble_changed: Treble level of the zone was changed.
   balance_changed: Balance level of the zone was changed.
   loudness_on: Loudness was enabled in the zone
   loudness_off: Loudness was disabled in the zone
   mute_on: This zone was muted.
   mute_off: This zone was unmuted.
   color_amber: The backlight color in this zone was changed to amber.
   color_green: The backlight color in this zone was changed to green.
   backlight_on: The backlight was turned on (not given when the backlight
      comes on when the zone is turned on).
   backlight_off: The backlight was turned off.
   brightness_changed: The backlight was turned off.
   internal_amp: The user has chosen to use the internal amp only.
   internal_external_amp: The user has chosen to use the internal amp as well
      as an amp connected through the Expansion Interface Module.
   external_amp: Only the external amp is being used.
   locked: The keypad has been locked
   unlocked: The keypad has been unlocked
   overheated: The zone keypad has become overheated
   heat_normal: The zone keypad is no longer overheated
   button_pressed_*: A button was pressed (button names can be found after
      this comment section or by calling get_button_labels() on a source
      object).
   button_held_*: A button was pressed and held (button names can be found 
      after this comment section or by calling get_button_labels() on a 
      source object).

Controlling the Musica source object:
   The following functions allow you to make changes to a particular source
   accessible from the Musica system.

   set_label(label): Sets the global label for this particular source.  The
      label can either be given as a number between 1 and 30 or as a string.
      Only certain strings are allowed, and these strings can be determined 
      by calling get_source_labels() on a source object.
   press_button(button): Sends the IR code associated with pressing the
      specified button for this source.  Button can be specified as either
      a number from 1 to 12 or as a label as returned by get_button_labels().
   hold_button(button): Sends the IR code associated with holding the
      specified button for this source.  Button can be specified as either
      a number from 1 to 12 or as a label as returned by get_button_labels().

Retrieving data from a Musica source object:
   get_musica_obj(): Returns the main musica object. 
   get_source_num(): Returns the numerical source number associated with 
      this source object.
   get_label(): Returns the label for the source as a string. 
   get_source_labels(): Returns a list of valid source labels.
   get_button_labels(): Returns a list of the names of the 12 programmable
      buttons on the Musica keypad and remote.
   get_zones(): Returns array of zones currently listening to this source.
   get_usage_count(): Returns the number of zones currently listening to 
      this source.

Monitoring the Musica source objects:
   You can watch for state changes of the Musica source object to see when a
   user changes the system in a way that affects a particular source.

   error: An error has occurred, call get_last_error() for details.
   label_changed: somebody changed the label for this source from a keypad
      (call get_set_by() to find the object name of the keypad used to make
      the change). 
   first_listener: the source now has a listener and it did not before.
   no_listeners: the only listener stopped listening and now nobody is using
      this particular source.
   listener_zone_X: zone X just selected this source.
   button_pressed_*: A button was pressed (button names can be found after
      this comment section or by calling get_button_labels()).
   button_held_*: A button was pressed and held (button names can be found 
      after this comment section or by calling get_button_labels()).

MUSICA SYSTEM BUGS:
   [ADC Version M30419]
   If I send the ChangeSrc command at least three seconds after the
   ChangeStore command then it works fine.  But if the gap is two seconds or
   less the zone never turns on like it should.

   [ADC Version M30419]
   ADC never responds to a NudgeSrc to a zone that is off.
      Workaround: only sends command if the zone is already on.

   [ADC Version M30419]
   ChangeSwOu command is always responded to with ChangeSwOu/1 whether you
   are trying to turn it on or off, and it seems to have no effect?

TODO:
   - Detect door/phone muting by watching for volume changes?
   - Implement IR_Dn/IR_Up?
   - ExeMenu* is not implemented as the ADC does not respond which makes it
     not like every other command plus I don't know why you would use it as it
     just allows you to navigate the menu system on a keypad but you can 
     change everything directly through other messages anyways.  But, for the
     record:
        ExeMenu/Zone/Command where Command is:
           1: Menu button
           2: Up Arrow
           3: Down Arrow
           4: Left Arrow
           5: Right Arrow

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package Musica;

# Object data:
#    musica_obj: pointer to itself to allow for cleaner code (since
#       all derived classes use this but use common functions)
#    port_name: the name of the port registered with Misterhouse
#    zones: An array of registered zone objects
#    sources: An array of registered source objects
#    queue: An array of commands still awaiting a response
#    adc_version: The version reported by the Audio Distribution Center
#    zone: set to 0 to allow the easy building of messages

@Musica::ISA = ('Serial_Item');

use vars qw( %source_name_to_number @source_number_to_name 
             %button_name_to_number @button_number_to_name
           );

%source_name_to_number = (
   'CD'       => 1,
   'AUX'      => 2,
   'TAPE'     => 3,
   'TUNER'    => 4,
   'TUNER2'   => 5,
   'AM'       => 6,
   'FM'       => 7,
   'MP3'      => 8,
   'BLUES'    => 9,
   'CHILDREN' => 10,
   'CLASSIC'  => 11,
   'COUNTRY'  => 12,
   'DAD'      => 13,
   'DANCE'    => 14,
   'DVD'      => 15,
   'LIGHTS'   => 16,
   'INTERNET' => 17,
   'JAZZ'     => 18,
   'REQUEST'  => 19,
   'MOM'      => 20,
   'XM RADIO' => 21,
   'POP'      => 22,
   'R&B'      => 23,
   'RAP'      => 24,
   'HD RADIO' => 25,
   'ROCK'     => 26,
   'SAT'      => 27,
   'SAT2'     => 28,
   'SOUL'     => 29,
   'WESTERN'  => 30
);

@source_number_to_name = (
   '',
   'CD',
   'AUX',
   'TAPE',
   'TUNER',
   'TUNER2',
   'AM',
   'FM',
   'MP3',
   'BLUES',
   'CHILDREN' ,
   'CLASSIC'  ,
   'COUNTRY'  ,
   'DAD'      ,
   'DANCE'    ,
   'DVD'      ,
   'LIGHTS'   ,
   'INTERNET' ,
   'JAZZ'     ,
   'REQUEST'  ,
   'MOM'      ,
   'XM RADIO' ,
   'POP'      ,
   'R&B'      ,
   'RAP'      ,
   'HD RADIO' ,
   'ROCK'     ,
   'SAT'      ,
   'SAT2'     ,
   'SOUL'     ,
   'WESTERN'  
);

%button_name_to_number = (
   'pause'     => 1,
   'stop'      => 2,
   'play'      => 3,
   'rewind'    => 4,
   'up'        => 5,
   'forward'   => 6,
   'left'      => 7,
   'down'      => 8,
   'right'     => 9,
   'previous'  => 10,
   'power'     => 11,
   'next'      => 12,
);

@button_number_to_name = (
   '',
   'pause',
   'stop',
   'play',
   'rewind',
   'up',
   'forward',
   'left',
   'down',
   'right',
   'previous',
   'power',
   'next'
);

# The version of this Misterhouse object
use constant OBJECT_VERSION => '1.0';
# Maximum number of zones and sources in the system
use constant MAX_ZONES => 6;
use constant MAX_SOURCES => 4;
# Maximum amount of time to wait for a response to a command (in seconds)
use constant MAX_RESPONSE_WAIT => 10;
# How long after a zone turns on should mute/volume changes not be reported?
use constant IGNORE_AFTER_ON => 10;

my %Musica_Systems;

sub serial_startup {
   # Nothing needs to be done here...
}

sub _check_for_data {
   for my $port_name (keys %Musica_Systems) {
      if (($Musica_Systems{$port_name}{'last_data_received'} + MAX_RESPONSE_WAIT) < $::Time) {
         # It has been a while since we received data for this object... so, call
         # the _send_next_cmd() function which will re-send the first item in the
         # queue (if there is one present) just to try the command again
         if ($Musica_Systems{$port_name}{'object'}->{'queue'}->[0]) {
            $Musica_Systems{$port_name}{'object'}->_send_next_cmd();
            $Musica_Systems{$port_name}{'object'}->_report_error("Had to re-send command [" . $Musica_Systems{$port_name}{'object'}->{'queue'}->[0] . ']');
            $Musica_Systems{$port_name}{'last_data_received'} = $::Time;
         }
      }
      &::check_for_generic_serial_data($port_name) if $::Serial_Ports{$port_name}{'object'};
      my $data = $::Serial_Ports{$port_name}{'data_record'};
      next if !$data;
      $Musica_Systems{$port_name}{'object'}->_parse_data($data);
      $main::Serial_Ports{$port_name}{'data_record'}='';
      $Musica_Systems{$port_name}{'last_data_received'} = $::Time;
   }
}

sub new {
   my ($class, $port_name) = @_;
   my $self = {};
   $$self{'port_name'} = $port_name;
   $$self{'zone'} = 0;
   &::print_log("$self->{'port_name'}: Netstreams Musica Misterhouse Module Version " . OBJECT_VERSION);
   for (my $i = 1; $i <= MAX_ZONES; $i++) {
      $$self{'zones'}[$i] = undef;
   }
   @{$$self{'queue'}} = ();
   bless $self, $class;
   $$self{'musica_obj'} = $self;
   $Musica_Systems{$port_name}{'object'} = $self;
   if (1==scalar(keys %Musica_Systems)) { # Add hooks on first call only
      &::MainLoop_pre_add_hook(\&Musica::_check_for_data, 1);
   }
   &::serial_port_create($port_name, $::config_parms{$port_name . "_serial_port"}, 9600);
   $self->_queue_cmd('EventData/0/1');
   $self->_queue_cmd('EventSrc/1');
   $self->_queue_cmd('EventStore/0/1');
   $self->_queue_cmd('StatVer/0');
   return $self;
}

sub _store_zone_source {
   my ($self, $zone, $source, $change_state) = @_;
   my $currsrc = $$self{'zones'}[$zone]->{'source'};
   if ($$self{'zones'}[$zone] and ($source ne 'X')) {
      unless ($currsrc eq $source) {
         if (defined $currsrc) {
            if ($currsrc eq '0') {
               # Currently off
               $$self{'zones'}[$zone]->set_receive('zone_on') if $change_state;
               $$self{'zones'}[$zone]->{'on_time'} = $::Time;
            } else {
               if ($source eq '0') {
                  $$self{'zones'}[$zone]->set_receive('zone_off') if $change_state;
               } else {
                  $$self{'zones'}[$zone]->set_receive('source_changed') if $change_state;
               }
            }
         }
         $$self{'zones'}[$zone]->{'source'} = $source;
         if ($$self{'sources'}[$currsrc]) {
            $$self{'sources'}[$currsrc]->_zone_not_using($zone);
         }
         if ($$self{'sources'}[$source]) {
            $$self{'sources'}[$source]->_zone_is_using($zone);
         }
      }
   }
}

sub _found_response {
   my ($self) = @_;
   #&::print_log("$self->{'port_name'}: found expected response for command '$$self{'queue'}->[0]'") if $main::Debug{musica};
   shift @{$$self{'queue'}};
   $self->_send_next_cmd();
}

sub _parse_data {
   my ($self, $data) = @_;
   &::print_log("$self->{'port_name'}: parsing serial data: [$data]") if $main::Debug{musica};
   # First, check to see if we got a Busy response which means we need to re-send
   # the first command in the queue
   if ($data eq 'Busy') {
      &::print_log("$self->{'port_name'}: re-sending first command in queue") if $main::Debug{musica};
      $self->_send_next_cmd();
      return;
   }
   my ($cmd, $value) = ($data =~ m=^([^/]+)/(.*)$=);
   my $compare = $$self{'queue'}->[0];
   $compare =~ s/\/.*$//;
   if ($compare) {
      # Now, see if we got a response to the first command in the queue
      if ($cmd eq $compare) {
         $self->_found_response();
      }
   }
   if ($cmd eq 'StatVer') {
      my ($zone, $version) = split /\//, $value;
      if ($zone == 0) {
         $$self{'adc_version'} = $version;
         &::print_log("$self->{'port_name'}: Netstreams Musica ADC Version: $version");
      } elsif ($$self{'zones'}[$zone]) {
         if ($version eq 'X') {
            $version = 'Not Present';
            $self->_report_error('Zone keypad not detected by ADC', $zone);
            $$self{'zones'}[$zone]->{'present'} = 0;
         }
         $$self{'zones'}[$zone]->{'keypad_version'} = $version;
         &::print_log("$self->{'port_name'}: Netstreams Musica Zone $zone Keypad Version: $version");
      }
   } elsif ($cmd eq 'EventPress') {
      if (($compare eq 'ExePress') or ($compare eq 'ExeHold')) {
         # Both ExePress and ExeHold commands respond with EventPress
         $self->_found_response();
      } else {
         my ($source, $button, $zone) = split /\//, $value;
         my $action = 'button_pressed_';
         if ($button > 12) {
            $button -= 12;
            my $action = 'button_held_';
         }
         if ($$self{'zones'}[$zone]) {
            $$self{'zones'}[$zone]->set_receive($action . $button_number_to_name[$button]);
         }
         if ($$self{'sources'}[$source]) {
            $$self{'sources'}[$source]->set_receive($action . $button_number_to_name[$button]);
         }
      }
   } elsif ($cmd eq 'ExeLock') {
      my ($zone, $lock) = split /\//, $value;
      $self->_store_zone_data($zone, 'locked', $lock);
   } elsif ($cmd eq 'ChangeVol') {
      my ($zone, $volume) = split /\//, $value;
      $self->_store_zone_data($zone, 'volume', $volume);
   } elsif ($cmd eq 'NudgeVol') {
      my ($zone, $volume) = split /\//, $value;
      $self->_store_zone_nudge($zone, 'volume', $volume, 0, 35);
   } elsif ($cmd eq 'ChangeMute') {
      my ($zone, $mute) = split /\//, $value;
      $self->_store_zone_data($zone, 'mute', $mute);
   } elsif ($cmd eq 'ChangeTreb') {
      my ($zone, $treble) = split /\//, $value;
      $self->_store_zone_data($zone, 'treble', $treble);
   } elsif ($cmd eq 'NudgeTreb') {
      my ($zone, $treble) = split /\//, $value;
      $self->_store_zone_nudge($zone, 'treble', $treble, 1, 15);
   } elsif ($cmd eq 'ChangeBass') {
      my ($zone, $bass) = split /\//, $value;
      $self->_store_zone_data($zone, 'bass', $bass);
   } elsif ($cmd eq 'NudgeBass') {
      my ($zone, $bass) = split /\//, $value;
      $self->_store_zone_nudge($zone, 'bass', $bass, 1, 15);
   } elsif ($cmd eq 'ChangeBal') {
      my ($zone, $balance) = split /\//, $value;
      $self->_store_zone_data($zone, 'balance', $balance);
   } elsif ($cmd eq 'NudgeBal') {
      my ($zone, $balance) = split /\//, $value;
      $self->_store_zone_nudge($zone, 'basance', $balance, 1, 15);
   } elsif ($cmd eq 'ChangeLoud') {
      my ($zone, $loudness) = split /\//, $value;
      $self->_store_zone_data($zone, 'loudness', $loudness);
   } elsif ($cmd eq 'ChangeAmp') {
      my ($zone, $amp) = split /\//, $value;
      $self->_store_zone_data($zone, 'amp', $amp);
   } elsif ($cmd eq 'ChangeBaCo') {
      my ($zone, $color) = split /\//, $value;
      $self->_store_zone_data($zone, 'blcolor', $color);
   } elsif ($cmd eq 'ChangeBaLi') {
      my ($zone, $level) = split /\//, $value;
      $self->_store_zone_data($zone, 'brightness', $level);
   } elsif ($cmd eq 'NudgeSrc') {
      my ($zone, $source) = split /\//, $value;
      $self->_store_zone_data($zone, 'source', $source);
   } elsif ($cmd eq 'ChangeSrc') {
      my ($zone, $source) = split /\//, $value;
      if ($zone == 0) {
         for (my $i = 1; $i <= MAX_ZONES; $i++) {
            $self->_store_zone_source($i, $source);
         }
      } else {
         $self->_store_zone_source($zone, $source);
      }
   } elsif ($cmd eq 'ChangeStore') {
      my ($source, $label) = split /\//, $value;
      if ($$self{'sources'}[$source]) {
         $$self{'sources'}[$source]->{'label'} = $label;
      }
   } elsif ($cmd eq 'EventStore') {
      my ($zone, @sources) = split /\//, $value;
      my $changed = 0;
      for (my $i = 1; $i <= MAX_SOURCES; $i++) {
         if ($$self{'sources'}[$i]) {
            unless ($$self{'sources'}[$i]->{'label'} eq $sources[$i-1]) {
               $changed = $i;
               $$self{'sources'}[$i]->{'label'} = $sources[$i-1];
               if ($$self{'zones'}[$zone]) {
                  $$self{'sources'}[$i]->set_receive('label_changed', $$self{'zones'}[$zone]);
               } else {
                  $$self{'sources'}[$i]->set_receive('label_changed', undef);
               }
            }
         }
      }
      if ($$self{'zones'}[$zone]) {
         $$self{'zones'}[$zone]->set_receive('changed_label_source_' . $changed) if $changed;
      }
   } elsif ($cmd eq 'EventSrc') {
      my (@sources) = split /\//, $value;
      for (my $i = 1; $i <= MAX_ZONES; $i++) {
         $self->_store_zone_source($i, $sources[$i-1], 1);
      }
   } elsif ($cmd eq 'EventData') {
      my ($zone, $volume, $bass, $treble, $balance, $loudness, $mute, $blcolor, 
          $brightness, $audioport, $amp, $locked, $overheat) = split /\//, $value;
      if ($$self{'zones'}[$zone]) {
         unless ($$self{'zones'}[$zone]->{'volume'} == $volume) {
            if (defined($$self{'zones'}[$zone]->{'volume'}) and (($$self{'zones'}[$zone]->{'on_time'} + IGNORE_AFTER_ON) < $::Time)) {
               $$self{'zones'}[$zone]->set_receive('volume_changed') 
            }
            $$self{'zones'}[$zone]->{'volume'} = $volume;
         }
         unless ($$self{'zones'}[$zone]->{'bass'} == $bass) {
            $$self{'zones'}[$zone]->set_receive('bass_changed') if defined $$self{'zones'}[$zone]->{'bass'};
            $$self{'zones'}[$zone]->{'bass'} = $bass;
         }
         unless ($$self{'zones'}[$zone]->{'treble'} == $treble) {
            $$self{'zones'}[$zone]->set_receive('treble_changed') if defined $$self{'zones'}[$zone]->{'treble'};
            $$self{'zones'}[$zone]->{'treble'} = $treble;
         }
         unless ($$self{'zones'}[$zone]->{'balance'} == $balance) {
            $$self{'zones'}[$zone]->set_receive('balance_changed') if defined $$self{'zones'}[$zone]->{'balance'};
            $$self{'zones'}[$zone]->{'balance'} = $balance;
         }
         unless ($$self{'zones'}[$zone]->{'loudness'} == $loudness) {
            if ($loudness) {
               $$self{'zones'}[$zone]->set_receive('loudness_on') if defined $$self{'zones'}[$zone]->{'loudness'};
            } else {
               $$self{'zones'}[$zone]->set_receive('loudness_off') if defined $$self{'zones'}[$zone]->{'loudness'};
            }
            $$self{'zones'}[$zone]->{'loudness'} = $loudness;
         }
         unless ($$self{'zones'}[$zone]->{'mute'} == $mute) {
            if (defined($$self{'zones'}[$zone]->{'mute'}) and (($$self{'zones'}[$zone]->{'on_time'} + IGNORE_AFTER_ON) < $::Time)) {
               if ($mute) {
                  $$self{'zones'}[$zone]->set_receive('mute_on');
               } else {
                  $$self{'zones'}[$zone]->set_receive('mute_off');
               }
            }
            $$self{'zones'}[$zone]->{'mute'} = $mute;
         }
         unless ($$self{'zones'}[$zone]->{'blcolor'} == $blcolor) {
            if ($blcolor) {
               $$self{'zones'}[$zone]->set_receive('color_amber') if defined $$self{'zones'}[$zone]->{'blcolor'};
            } else {
               $$self{'zones'}[$zone]->set_receive('color_green') if defined $$self{'zones'}[$zone]->{'blcolor'};
            }
            $$self{'zones'}[$zone]->{'blcolor'} = $blcolor;
         }
         unless ($$self{'zones'}[$zone]->{'brightness'} == $brightness) {
            if (defined $$self{'zones'}[$zone]->{'brightness'}) {
               if ($$self{'zones'}[$zone]->{'brightness'} == 0) {
                  $$self{'zones'}[$zone]->set_receive('backlight_on')
               } elsif ($brightness == 0) {
                  $$self{'zones'}[$zone]->set_receive('backlight_off')
               } else {
                  $$self{'zones'}[$zone]->set_receive('brightness_changed')
               }
            }
            $$self{'zones'}[$zone]->{'brightness'} = $brightness;
         }
         unless ($$self{'zones'}[$zone]->{'audioport'} == $audioport) {
            if ($audioport) {
               $$self{'zones'}[$zone]->set_receive('audio_port_connected') if defined $$self{'zones'}[$zone]->{'audioport'};
            } else {
               $$self{'zones'}[$zone]->set_receive('audio_port_disconnected') if defined $$self{'zones'}[$zone]->{'audioport'};
            }
            $$self{'zones'}[$zone]->{'audioport'} = $audioport;
         }
         unless ($$self{'zones'}[$zone]->{'amp'} == $amp) {
            if ($amp == 0) {
               $$self{'zones'}[$zone]->set_receive('internal_amp') if defined $$self{'zones'}[$zone]->{'amp'};
            } elsif ($amp == 1) {
               $$self{'zones'}[$zone]->set_receive('internal_external_amp') if defined $$self{'zones'}[$zone]->{'amp'};
            } else {
               $$self{'zones'}[$zone]->set_receive('external_amp') if defined $$self{'zones'}[$zone]->{'amp'};
            }
            $$self{'zones'}[$zone]->{'amp'} = $amp;
         }
         unless ($$self{'zones'}[$zone]->{'locked'} == $locked) {
            if ($locked) {
               $$self{'zones'}[$zone]->set_receive('locked') if defined $$self{'zones'}[$zone]->{'locked'};
            } else {
               $$self{'zones'}[$zone]->set_receive('unlocked') if defined $$self{'zones'}[$zone]->{'locked'};
            }
            $$self{'zones'}[$zone]->{'locked'} = $locked;
         }
         unless ($$self{'zones'}[$zone]->{'overheat'} == $overheat) {
            if ($overheat) {
               $$self{'zones'}[$zone]->set_receive('overheated') if defined $$self{'zones'}[$zone]->{'overheat'};
            } else {
               $$self{'zones'}[$zone]->set_receive('heat_normal') if defined $$self{'zones'}[$zone]->{'overheat'};
            }
            $$self{'zones'}[$zone]->{'overheat'} = $overheat;
         }
      }
   }
}

sub _register_zone {
   my ($self, $zone_obj, $zone_num) = @_;
   $$self{'zones'}[$zone_num] = $zone_obj;
   # Determine version of the keypad
   $self->_queue_cmd("StatVer/$zone_num");
}

sub _register_source {
   my ($self, $source_obj, $source_num) = @_;
   $$self{'sources'}[$source_num] = $source_obj;
}

sub _send_next_cmd {
   my ($self) = @_;
   if ($$self{'queue'}->[0]) {
      &::print_log("$self->{'port_name'}: sending first command in queue: [$$self{'queue'}->[0]]") if $main::Debug{musica};
      $main::Serial_Ports{$$self{'port_name'}}{'object'}->write("$$self{'queue'}->[0]\r");
   }
}

sub _queue_cmd {
   my ($self, $cmd) = @_;
   if ($$self{'port_name'}) {
      #&::print_log("$self->{'port_name'}: queueing command: [$cmd]") if $main::Debug{musica};
      push @{$$self{'queue'}}, $cmd;
      if ($#{$$self{'queue'}} == 0) {
         # No entries waiting in queue, send right away, and reset data received timer
         $Musica_Systems{$$self{'port_name'}}{'last_data_received'} = $::Time;
         $self->_send_next_cmd();
      }
   } elsif ($$self{'musica_obj'}) {
      $$self{'musica_obj'}->_queue_cmd($cmd);
   } else {
      &::print_log("ERROR: Musica($self->{'object_name'}): Could not find queue in which to place command [$cmd]");
   }
}

# Takes in a number and a minimum and maximum value and converts that to
# a number between 1 and 15.
sub _scale_to_15 {
   my ($val, $min, $max) = @_;
   if ($val < $min) {
      $val = $min;
   }
   if ($val > $max) {
      $val = $max;
   }
   $val -= $min;
   return (int(14*$val/($max-$min))+1);
}

sub _report_error {
   my ($self, $error, $zone) = @_;
   if ((not $zone) or ($zone == 0)) {
      $$self{'last_error'} = $error;
      $self->set_receive('error');
      &::print_log("ERROR: Musica($self->{'port_name'}): $error");
   } elsif ($$self{'zones'}[$zone]) {
      $$self{'zones'}[$zone]->{'last_error'} = $error;
      $$self{'zones'}[$zone]->set_receive('error');
      &::print_log("ERROR: Musica($self->{'port_name'}) zone $zone: $error");
   } else {
      $$self{'last_error'} = "Received error regarding non-existant zone: $error";
      $self->set_receive('error');
   }
}

sub _calc_zone_nudge {
   my ($initial, $direction, $min, $max) = @_;
   &::print_log("Musica: Nudging $direction from $initial...\n");
   if ($direction == 0) {
      $initial--;
      if ($initial < $min) {
         $initial = $min;
      }
   } elsif ($direction == 1) {
      $initial++;
      if ($initial > $max) {
         $initial = $max;
      }
   }
   &::print_log("Musica: returning $initial...\n");
   return $initial;
}

sub _store_zone_nudge {
   my ($self, $zone, $member, $volume, $min, $max) = @_;
   if ($zone == 0) {
      for (my $i = 1; $i <= MAX_ZONES; $i++) {
         if ($$self{'zones'}[$i] and $$self{'zones'}[$i]->{'present'}) {
            $$self{'zones'}[$i]->{$member} = &Musica::_calc_zone_nudge($$self{'zones'}[$i]->{$member}, $volume, $min, $max);
         }
      }
   } else {
      $self->_store_zone_data($zone, $member, $volume);
   }
}

sub _store_zone_data {
   my ($self, $zone, $member, $value) = @_;
   if ($zone == 0) {
      for (my $i = 1; $i <= MAX_ZONES; $i++) {
         if ($$self{'zones'}[$i] and $$self{'zones'}[$i]->{'present'}) {
            $$self{'zones'}[$i]->{$member} = $value;
         }
      }
   } else {
      if ($$self{'zones'}[$zone]) {
         if ($value eq 'X') {
            $$self{'zones'}[$zone]->_report_error("Zone keypad not detected by ADC (tried to set $member)");
         } else {
            $$self{'zones'}[$zone]->{$member} = $value;
         }
      }
   }
}

sub _is_base_obj {
   my ($self, $function) = @_;
   if ($self->{'port_name'}) {
      return 1;
   } else {
      $self->_report_error("$function() can only be called on main Musica object");
      return 0;
   }
}

################################################################################
# Begin public system-wide Musica functions
################################################################################

sub get_musica_obj {
   my ($self) = @_;
   return $self->{'musica_obj'};
}

sub get_object_version {
   return OBJECT_VERSION;
}

sub get_port_name {
   my ($self) = @_;
   return unless ($self->_is_base_obj('get_port_name'));
   return $self->{'port_name'};
}

sub get_zones {
   my ($self) = @_;
   return unless ($self->_is_base_obj('get_zones'));
   return (@{$self->{'zones'}});
}

sub get_sources {
   my ($self) = @_;
   return unless ($self->_is_base_obj('get_sources'));
   return (@{$self->{'sources'}});
}

sub get_adc_version {
   my ($self) = @_;
   return unless ($self->_is_base_obj('get_adc_version'));
   return $self->{'adc_version'};
}

sub get_last_error {
   my ($self) = @_;
   return ($$self{'last_error'});
}

sub all_off {
   my ($self) = @_;
   return unless ($self->_is_base_obj('all_off'));
   $self->_queue_cmd('AllOff');
}

sub activate_doorbell_mute {
   my ($self) = @_;
   return unless ($self->_is_base_obj('activate_doorbell_mute'));
   $self->_queue_cmd("ChangeDoor/1");
}

sub activate_phone_mute {
   my ($self) = @_;
   return unless ($self->_is_base_obj('activate_phone_mute'));
   $self->_queue_cmd("ChangePhone/1");
}

sub switched_outlet_on {
   my ($self) = @_;
   return unless ($self->_is_base_obj('switched_outlet_on'));
   $self->_queue_cmd("ChangeSwOu/1");
}

sub switched_outlet_off {
   my ($self) = @_;
   return unless ($self->_is_base_obj('switched_outlet_off'));
   $self->_queue_cmd("ChangeSwOu/0");
}

sub set_treble {
   my ($self, $treble) = @_;
   $treble = $self->_scale_to_15($treble, -14, 14);
   $self->_queue_cmd("ChangeTreb/$$self{'zone'}/$treble");
}

sub set_bass {
   my ($self, $bass) = @_;
   $bass = $self->_scale_to_15($bass, -14, 14);
   $self->_queue_cmd("ChangeBass/$$self{'zone'}/$bass");
}

sub set_balance {
   my ($self, $balance) = @_;
   $balance = $self->_scale_to_15($balance, -7, 7);
   $self->_queue_cmd("ChangeBal/$$self{'zone'}/$balance");
}

sub set_source {
   my ($self, $source) = @_;
   if (ref $source) {
      # Passing in a reference to an object?
      if ($source->isa('Musica::Source')) {
         $source = $source->{'source'};
      } else {
         $self->_report_error("set_source(): Invalid reference as source parameter: $source");
      }
   } elsif ($Musica::source_name_to_number{uc($source)}) {
      # Specified the source label, look up proper source number
      my $labelid = $Musica::source_name_to_number{uc($source)};
      for (my $i = 1; $i <= MAX_SOURCES; $i++) {
         if ($$self{'musica_obj'}->{'sources'}[$i]->{'label'} == $labelid) {
            $source = $i;
            last;
         }
      }
   }
   unless ($source eq 'E') {
      unless (($source > 0) and ($source <= Musica::MAX_SOURCES)) {
         $self->_report_error("set_source(): Invalid source identifier: $source");
         return;
      }
   }
   $self->_queue_cmd("ChangeSrc/$$self{'zone'}/$source");
}

sub set_volume {
   my ($self, $volume) = @_;
   if ($volume =~ s/%$//) {
      $volume = (35 * ($volume/100));
   }
   unless (($volume >= 0) or ($volume <= 35)) {
      $self->_report_error("set_volume(): volume specified is out of range: $volume");
   }
   $self->_queue_cmd("ChangeVol/$$self{'zone'}/$volume");
}

sub mute {
   my ($self) = @_;
   $self->_queue_cmd("ChangeMute/$$self{'zone'}/1");
}

sub unmute {
   my ($self) = @_;
   $self->_queue_cmd("ChangeMute/$$self{'zone'}/0");
}

sub loudness_on {
   my ($self) = @_;
   $self->_queue_cmd("ChangeLoud/$$self{'zone'}/1");
}

sub loudness_off {
   my ($self) = @_;
   $self->_queue_cmd("ChangeLoud/$$self{'zone'}/0");
}

sub turn_off {
   my ($self) = @_;
   $self->_queue_cmd("ChangeSrc/$$self{'zone'}/0");
}

sub internal_amp {
   my ($self) = @_;
   $self->_queue_cmd("ChangeAmp/$$self{'zone'}/0");
}

sub both_amps {
   my ($self) = @_;
   $self->_queue_cmd("ChangeAmp/$$self{'zone'}/1");
}

sub external_amp {
   my ($self) = @_;
   $self->_queue_cmd("ChangeAmp/$$self{'zone'}/2");
}

sub green_backlight {
   my ($self) = @_;
   $self->_queue_cmd("ChangeBaCo/$$self{'zone'}/0");
}

sub amber_backlight {
   my ($self) = @_;
   $self->_queue_cmd("ChangeBaCo/$$self{'zone'}/1");
}

sub set_backlight_brightness {
   my ($self, $level) = @_;
   if ($level =~ s/%$//) {
      $level = (8 * ($level/100));
   }
   unless (($level >= 0) or ($level <= 8)) {
      $self->_report_error("set_backlight_brightness(): level specified is out of range: $level");
   }
   $self->_queue_cmd("ChangeBaLi/$$self{'zone'}/0");
}

sub nudge_volume_down {
   my ($self) = @_;
   $self->_queue_cmd("NudgeVol/$$self{'zone'}/0");
}

sub nudge_volume_up {
   my ($self) = @_;
   $self->_queue_cmd("NudgeVol/$$self{'zone'}/1");
}

sub nudge_bass_down {
   my ($self) = @_;
   $self->_queue_cmd("NudgeBass/$$self{'zone'}/0");
}

sub nudge_bass_up {
   my ($self) = @_;
   $self->_queue_cmd("NudgeBass/$$self{'zone'}/1");
}

sub nudge_treble_down {
   my ($self) = @_;
   $self->_queue_cmd("NudgeTreb/$$self{'zone'}/0");
}

sub nudge_treble_up {
   my ($self) = @_;
   $self->_queue_cmd("NudgeTreb/$$self{'zone'}/1");
}

sub nudge_balance_left {
   my ($self) = @_;
   $self->_queue_cmd("NudgeBal/$$self{'zone'}/0");
}

sub nudge_balance_right {
   my ($self) = @_;
   $self->_queue_cmd("NudgeBal/$$self{'zone'}/1");
}

sub lock_menu {
   my ($self) = @_;
   $self->_queue_cmd("ExeLock/$$self{'zone'}/1");
}

sub unlock_menu {
   my ($self) = @_;
   $self->_queue_cmd("ExeLock/$$self{'zone'}/0");
}

################################################################################
# End public system-wide Musica functions
################################################################################

package Musica::Zone;

# Object data:
#    musica_obj: pointer to the parent Musica object
#    zone: The numerical zone associated with this zone object
#    keypad_version: The version reported by the keypad
#    on_time: When the keypad was last turned on
#    present: True if the keypad is present
#    source: The selected source 1-4 or E, or 0 for off
#    volume: Volume level (0-35)
#    bass: Bass level 1=-14, 8=0, 15=14
#    treble: Treble level 1=-14, 8=0, 15=14
#    balance: Balance, 1-15, with 8 being centered, 1 is full-left, 15 is full-right
#    loudness: 0 for off and 1 for on
#    mute: 0 for off and 1 for on
#    blcolor:  0 for green and 1 for amber
#    brightness: 0-8 where 0 means it is off
#    audioport: 1 if it is connected
#    amp: 0=room amp, 1=both, 2=external amp
#    locked: 0=unlocked, 1=locked
#    overheat: 0=normal, 1=overheated

@Musica::Zone::ISA = ('Musica');

sub new {
   my ($class, $musica_obj, $zone_num) = @_;
   my $self = {};
   # Assume it is present until told otherwise
   $$self{'present'} = 1;
   $$self{'zone'} = $zone_num;
   $$self{'musica_obj'} = $musica_obj;
   bless $self, $class;
   $musica_obj->_register_zone($self, $zone_num);
   return $self;
}

sub _report_error {
   my ($self, $error) = @_;
   $$self{'last_error'} = $error;
   $self->set_receive('error');
   &::print_log("ERROR: Musica($self->{'musica_obj'}->{'port_name'}) zone $$self{'object_name'}: $error");
}

################################################################################
# Begin public zone-specific Musica functions
################################################################################

sub nudge_source_down {
   my ($self) = @_;
   if ($self->{'source'} eq '0') {
      $self->_report_error("nudge_source_down(): zone is not on.");
   } else {
      $self->_queue_cmd("NudgeSrc/$$self{'zone'}/0");
   }
}

sub nudge_source_up {
   my ($self) = @_;
   if ($self->{'source'} eq '0') {
      $self->_report_error("nudge_source_up(): zone is not on.");
   } else {
      $self->_queue_cmd("NudgeSrc/$$self{'zone'}/1");
   }
}

sub get_zone_num() {
   my ($self) = @_;
   return $self->{'zone'};
}

sub get_keypad_version() {
   my ($self) = @_;
   return $self->{'keypad_version'};
}

sub get_last_on_time() {
   my ($self) = @_;
   return $self->{'on_time'};
}

sub get_source() {
   my ($self) = @_;
   return $self->{'source'};
}

sub get_volume() {
   my ($self) = @_;
   return $self->{'volume'};
}

sub get_bass_level() {
   my ($self) = @_;
   return (($self->{'bass'} - 8) * 2);
}

sub get_treble_level() {
   my ($self) = @_;
   return (($self->{'treble'} - 8) * 2);
}

sub get_balance() {
   my ($self) = @_;
   return ($self->{'balance'} - 8);
}

sub get_loudness() {
   my ($self) = @_;
   return $self->{'loudness'};
}

sub get_mute() {
   my ($self) = @_;
   return $self->{'mute'};
}

sub get_blcolor() {
   my ($self) = @_;
   if ($self->{'blcolor'}) {
      return 'amber';
   } else {
      return 'green';
   }
}

sub get_brightness() {
   my ($self) = @_;
   return $self->{'brightness'};
}

sub get_audioport() {
   my ($self) = @_;
   return $self->{'audioport'};
}

sub get_amp() {
   my ($self) = @_;
   if ($self->{'amp'} == 2) {
      return 'external_amp';
   } elsif ($self->{'amp'} == 1) {
      return 'both';
   } else {
      return 'room_amp';
   }
}

sub get_locked() {
   my ($self) = @_;
   return $self->{'locked'};
}

sub get_overheat() {
   my ($self) = @_;
   return $self->{'overheat'};
}

################################################################################
# End public zone-specific Musica functions
################################################################################

package Musica::Source;

# Object data:
#    musica_obj: pointer to the parent Musica object
#    source: The numerical source associated with this source object
#    label: The numerical label associated with this source
#    zones: An array of all zones using this source

@Musica::Source::ISA = ('Musica');

sub new {
   my ($class, $musica_obj, $source_num) = @_;
   my $self = {};
   $$self{'source'} = $source_num;
   $$self{'musica_obj'} = $musica_obj;
   for (my $i = 1; $i <= Musica::MAX_ZONES; $i++) {
      $$self{'zones'}->[$i] = 0;
   }
   bless $self, $class;
   $musica_obj->_register_source($self, $source_num);
   return $self;
}

sub _report_error {
   my ($self, $error) = @_;
   $$self{'last_error'} = $error;
   $self->set_receive('error');
   &::print_log("ERROR: Musica($self->{'musica_obj'}->{'port_name'}) source $$self{'object_name'}: $error");
}

sub _zone_not_using {
   my ($self, $zone) = @_;
   unless ($$self{'zones'}->[$zone] == 1) {
      return;
   }
   $$self{'zones'}->[$zone] = 0;
   for (my $i = 1; $i <= Musica::MAX_ZONES; $i++) {
      if ($$self{'zones'}->[$i] == 1) {
         # There is still another listener
         return;
      }
   }
   $self->set_receive('no_listeners');
}

sub _zone_is_using {
   my ($self, $zone) = @_;
   if ($$self{'zones'}->[$zone] == 1) {
      # Already being used by this zone
      return;
   }
   $$self{'zones'}->[$zone] = 1;
   $self->set_receive("listener_zone_$zone");
   for (my $i = 1; $i <= Musica::MAX_ZONES; $i++) {
      if ($$self{'zones'}->[$i] == 1) {
         if ($i != $zone) {
            # There was already a listener...
            return;
         }
      }
   }
   $self->set_receive('first_listener');
}

sub _resolve_to_button_id {
   my ($self, $button) = @_;
   if ($button =~ /^\d+$/) {
      if (($button >= 1) and ($button <= 12)) {
         return $button;
      } else {
         $self->_report_error("press_button()/hold_button(): Invalid button ID: $button (must be 1 to 12)");
         return 0;
      }
   }
   if ($Musica::button_name_to_number{$button}) {
      return $Musica::button_name_to_number{$button};
   } else {
      $self->_report_error("press_button()/hold_button(): Invalid button label: $button");
   }
}

################################################################################
# Begin public source-specific Musica functions
################################################################################

sub get_usage_count() {
   my ($self) = @_;
   my $ret = 0;
   for (my $i = 1; $i <= Musica::MAX_ZONES; $i++) {
      if ($$self{'zones'}->[$i] == 1) {
         $ret++;
      }
   }
   return ($ret);
}

sub get_zones() {
   my ($self) = @_;
   my @ret;
   for (my $i = 1; $i <= Musica::MAX_ZONES; $i++) {
      if ($$self{'zones'}->[$i] == 1) {
         push @ret, $i;
      }
   }
   return (@ret);
}

sub press_button() {
   my ($self, $button) = @_;
   if ($button = $self->_resolve_to_button_id($button)) {
      $self->_queue_cmd("ExePress/$$self{'source'}/$button");
   }
}

sub hold_button() {
   my ($self, $button) = @_;
   if ($button = $self->_resolve_to_button_id($button)) {
      $self->_queue_cmd("ExeHold/$$self{'source'}/$button");
   }
}

sub get_button_labels() {
   return (sort keys %Musica::button_name_to_number);
}

sub get_source_labels() {
   return (sort keys %Musica::source_name_to_number);
}

sub get_source_num() {
   my ($self) = @_;
   return ($self->{'source'});
}

sub get_label() {
   my ($self) = @_;
   if ($self->{'label'}) {
      return $Musica::source_number_to_name[$self->{'label'}];
   } else {
      return '';
   }
}

sub set_label {
   my ($self, $label) = @_;
   my $label = uc($label);
   my $labelnum = 0;
   if ($label =~ /^\d+$/) {
      $labelnum = $label;
   } else {
      # Look up label unless a number is already provided
      if ($Musica::source_name_to_number{$label}) {
         $labelnum = $Musica::source_name_to_number{$label};
      }
   }
   unless (($labelnum >= 1) and ($labelnum <= 30)) {
      $self->_report_error("set_label(): Invalid source label: $label (resolved number was $labelnum)");
      return;
   }
   $self->_queue_cmd("ChangeStore/$$self{'source'}/$labelnum");
}


################################################################################
# End public source-specific Musica functions
################################################################################

