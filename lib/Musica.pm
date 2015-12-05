
=head1 B<Musica>

=head2 SYNOPSIS

Important Note:

   Because the new FM-Tuner keypads (and possibly other newer keypads?) take
   *forever (minutes) to respond to the StatVer command, their version is
   stored in the persistant Misterhouse %Save hash.  This means that if you
   change the physical keypad, you'll need to stop Misterhouse, edit
   data_dir/mh_temp.saved_states.persistent, and search for 'Musica' and
   remove or modify the entry for the zone you chaged.  Then start Misterhouse
   back up.  If you simply remove a keypad, just take the entry for that zone
   out of your .mht file -- you don't need to worry about %Save.

   Also, some keypads never respond to the StatVer command Misterhouse sends
   to try to find the version of each keypad.  Watch your print log and if
   You see StatVer being re-send over and over again for a specific keypad,
   you may want to specify its version in your .mht file as so:

      MUSICA_ZONE, music_kitchen,    Musica, 1, 40822

   My keypads (version 40822) do respond to StatVer after 2-3 minutes and
   then this version is stored by the Musica module in the persistent %Save
   hash.

   The only keypad versions I know are:
      30419: MU4601 keypad
      40822: MU4602 FM-Tuner keypad

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
   controlling functions such as set_volume()) any resulting object state
   changes will have the set_by set to 'misterhouse'.  By contrast, new states
   initiated by the keypad or Musica remote control have a set_by of 'keypad'.
   You can also see that your command took effect by calling get_volume() and
   seeing that it returns the volume you set.  Note that this function will
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
   and the letter 'F' for the integrated FM tuner.
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

   white_backlight(): Set backlight to the color white (instead of green when applicable).

   blue_backlight(): Set backlight to the color blue (instead of amber when applicable).

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

   set_preset_label(number, label): Sets FM preset 1-8 to specified numeric
   or text label.  Label must be one listed in %source_name_to_number_30419.

   set_preset_frequency(number, freq): Sets FM preset 1-8 to specified frequency,
   where 8950 is 89.5, for example.

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

Controlling the Musica zone objects using functions:

   The following functions allow you to make changes to a specific Musica
   zone from Misterhouse.

   set_source(source): Sets the zone to the specified source, where 'source'
   is a number between 1 and 4 or E for the local expansion source.  Turns
   the zone ON if it is not already on.

   turn_off(): Turns off the zone.
   nudge_source_up(): Switches to the next source (must already be on).
   nudge_source_down(): Switches to the previous source (must already be on).
   delay_off(seconds): Automatically turn the zone off in the specified number
      of seconds.  Timer is cancelled if the user selects a new source or if
      this function is called with '0' for the argument.  Also can be reset
      by calling this function again.  Returns current delay if no argument
      is provided.

Controlling the Musica zone objects using set()

   The following input states are recognized by the Musica zone objects:
      off: Turn zone off
      1: Turn to source 1
      2: Turn to source 2
      3: Turn to source 3
      4: Turn to source 4
      E: Turn to external input
      volumeXX: Set volume where XX ranges from 0 to 35
      mute: Mutes the zone
      unmute: Unmutes the zone

Retrieving data from the Musica zone object:

   get_musica_obj(): Returns the main musica object.
   get_zone_num(): Returns the zone number (from 1 to 6) for this object.
   get_keypad_version(): Returns the version number returned by the keypad.
   get_last_on_time(): Returns the last time the keypad was turned on
      (in Epoch format, as $::Time expresses it)
   get_source(): Returns the currently-selected source number, or 0 if off.
   get_source_obj(): Returns the currently-selected source object.
   get_volume(): Returns the volume, from 0 to 35.
   get_bass_level(): Returns the bass level from -14 to 14.
   get_treble_level(): Returns the bass level from -14 to 14.
   get_balance(): Returns the balance where -7 is full-left, 7 is full-right,
      and 0 is centered.
   get_loudness(): Returns 1 if on, 0 if off.
   get_mute(): Returns 1 if on, 0 if off.
   get_blcolor(): Returns 'green' or 'amber' to indicate backlight color.
      ('green' == 'white' and 'amber' == 'blue' on applicable keypads)
   get_brightness(): Returns backlight brightness from 0 to 8 where 0 means
      that the backlight is currently off.
   get_audioport(): Returns 1 if the audioport is connected.
   get_amp(): Returns 'room_amp', 'both', or 'external_amp'.
   get_locked(): Returns 1 if the keypad is locked.
   get_overheat(): Returns 1 if the keypad is overheated.
   get_button_labels(): Returns a list of the names of the 12 programmable
      buttons on the Musica keypad and remote.
   press_button(button): Sends the IR code associated with pressing the
      specified button for this source.  Button can be specified as either
      a number from 1 to 12 or as a label as returned by get_button_labels().
   hold_button(button): Sends the IR code associated with holding the
      specified button for this source.  Button can be specified as either
      a number from 1 to 12 or as a label as returned by get_button_labels().

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
   color_amber: The backlight color in this zone was changed to amber
      (or blue on applicable keypads).
   color_green: The backlight color in this zone was changed to green
      (or white on applicable keypads).
   backlight_on: The backlight was turned on (not given when the backlight
      comes on when the zone is turned on).
   backlight_off: The backlight was turned off.
   brightness_changed: The backlight brightness was changed.
   internal_amp: The user has chosen to use the internal amp only.
   internal_external_amp: The user has chosen to use the internal amp as well
      as an amp connected through the Expansion Interface Module.
   external_amp: Only the external amp is being used.
   locked: The keypad has been locked
   unlocked: The keypad has been unlocked
   overheated: The zone keypad has become overheated
   heat_normal: The zone keypad is no longer overheated
   button_pressed_*: A button was pressed (button names can be found after
      this comment section or by calling get_button_labels() on a zone
      object).
   button_held_*: A button was pressed and held (button names can be found
      after this comment section or by calling get_button_labels() on a
      zone object).

Controlling the Musica source object:

   The following functions allow you to make changes to a particular source
   accessible from the Musica system.

   set_label(label): Sets the global label for this particular source.  The
      label can either be given as a number between 1 and 30 or as a string.
      Only certain strings are allowed, and these strings can be determined
      by calling get_source_labels() on a source object.

Retrieving data from a Musica source object:

   get_musica_obj(): Returns the main musica object.
   get_source_num(): Returns the numerical source number associated with
      this source object.
   get_label(): Returns the label for the source as a string.
   get_source_labels(): Returns a list of valid source labels.
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

Usage Examples:

   To better understand the following examples, you should know that I have
   an array of MP3 players defined as:

      my @players;
      if ($Startup) {
         push @players, undef;
         foreach ('channel12', 'channel34', 'channel56', 'channel78') {
            push @players, new AlsaPlayer($_);
         }
      }

   Then I create an array of all of the Musica::Source objects (which
   are already defined in my .mht file):

      my @musica_sources = ( $music_source1, $music_source2, $music_source3,
                             $music_source4 );

   The 'first_listener' and 'no_listeners' states are handy to start/stop
   or pause/unpause something like an MP3 player, or even to power on/off
   sources or send out IR commands.

      foreach (@musica_sources) {
         if (state_now $_ eq 'first_listener') {
            $players[$_->get_source_num()]->unpause();
         }
         if (state_now $_ eq 'no_listeners') {
            $players[$_->get_source_num()]->pause();
         }
      }

   To watch for button presses on all keypads and all sources and take
   the appropriate action:

      foreach (@musica_sources) {
         if (state_now $_ eq 'button_pressed_next') {
            $players[$_->get_source_num()]->next_song();
         }
         if (state_now $_ eq 'button_pressed_previous') {
            $players[$_->get_source_num()]->previous_song();
         }
         if (state_now $_ eq 'button_pressed_pause') {
            $players[$_->get_source_num()]->pause_toggle();
         }
         if (state_now $_ eq 'button_pressed_play') {
            $players[$_->get_source_num()]->unpause();
         }
      }

MUSICA SYSTEM BUGS:

   [ADC Version M30419/Keypad Version R40822 (FM-Tuner)]
   - Keypad takes FOREVER (1-4 minutes) to respond to StatVer.
   - When you hold down a button on the keypad often times a button pressed
   event is sent right after the button held event.  This code will ignore
   a press right after a hold.
   - Never sends back a copy of the ChangeAmp command nor does it send
   an EventData message back.
   - Does not respond to various commands like ChangeVol, ChangeBass, etc.
   Instead, sends an EventData message showing the changes (bug or protocol
   change?)

   [ADC Version M30419/Keypad Version R30419]
   If I send the ChangeSrc command at least three seconds after the
   ChangeStore command then it works fine.  But if the gap is two seconds or
   less the zone never turns on like it should.

   [ADC Version M30419/Keypad Version R30419]
   ADC never responds to a NudgeSrc to a zone that is off.
      Workaround: only sends command if the zone is already on.

   [ADC Version M30419/Keypad Version R30419]
   ChangeSwOu command is always responded to with ChangeSwOu/1 whether you
   are trying to turn it on or off, and it seems to have no effect?

   [ADC Version M30419/Keypad Version R30419]
   The backlight brightness sent in EventData comes in as 0 until you
   change the backlight from its original value (or at least that is
   what happened to me).

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

=head2 DESCRIPTION

Allows control of the Musica whole-house audio system by Netstreams over the
RS232 port.  This system has excellent controllability through Misterhouse
and provides 6 zones and 4 sources with very nice keypads.

http://www.netstreams.com

If you are interested in installing a Netstreams Musica system yourself,
contact me and I can put you in contact with somebody who can give you
a good price.

Note that you must use a null-modem cable between the Musica system and your
Misterhouse computer.

This module uses Rev 2.0 of the Musica RS-232 protocol.

=head2 INHERITS

B<Serial_Item>

=head2 METHODS

=over

=item B<UnDoc>

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
  %source_name_to_number_30419 @source_number_to_name_30419
  %button_name_to_number @button_number_to_name
  %button_name_to_number_40822 @button_number_to_name_40822
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
    'XMRADIO'  => 21,
    'XM RADIO' => 21,
    'POP'      => 22,
    'R&B'      => 23,
    'RAP'      => 24,
    'RADIO'    => 25,
    'HD RADIO' => 25,
    'ROCK'     => 26,
    'SAT'      => 27,
    'SAT2'     => 28,
    'SOUL'     => 29,
    'WESTERN'  => 30
);

%source_name_to_number_30419 = (
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
    'XMRADIO'  => 21,
    'XM RADIO' => 21,
    'POP'      => 22,
    'R&B'      => 23,
    'RAP'      => 24,
    'RADIO'    => 25,
    'HD RADIO' => 25,
    'ROCK'     => 26,
    'SAT'      => 27,
    'SAT2'     => 28,
    'SOUL'     => 29,
    'CD2'      => 30,
    'TALK'     => 31,
    'NEWS'     => 32,
    'SIRIUS'   => 33,
    'TRAFFIC'  => 34,
    'WEATHER'  => 35,
    'SPORTS'   => 36,
    'NPR'      => 37,
    'DSS'      => 38,
    'M SERVER' => 39,
    'M-SERVER' => 39,
    'DISH'     => 40,
    ''         => 41,
    'EXTAUDIO' => 42,
    'MASTER'   => 43,
    'BEDROOM'  => 44,
    'KITCHEN'  => 45,
    'DINING'   => 46,
    'LIVING'   => 47,
    'FAMILY'   => 48,
    'GREAT'    => 49,
    'STUDY'    => 50,
    'OUTSIDE'  => 51,
    'ROOM'     => 52,
);

@source_number_to_name = (
    '',        'CD',       'AUX',   'TAPE',     'TUNER',    'TUNER2',
    'AM',      'FM',       'MP3',   'BLUES',    'CHILDREN', 'CLASSIC',
    'COUNTRY', 'DAD',      'DANCE', 'DVD',      'LIGHTS',   'INTERNET',
    'JAZZ',    'REQUEST',  'MOM',   'XM RADIO', 'POP',      'R&B',
    'RAP',     'HD RADIO', 'ROCK',  'SAT',      'SAT2',     'SOUL',
    'WESTERN'
);

@source_number_to_name_30419 = (
    '',        'CD',      'AUX',   'TAPE',     'TUNER',    'TUNER2',
    'AM',      'FM',      'MP3',   'BLUES',    'CHILDREN', 'CLASSIC',
    'COUNTRY', 'DAD',     'DANCE', 'DVD',      'LIGHTS',   'INTERNET',
    'JAZZ',    'REQUEST', 'MOM',   'XMRADIO',  'POP',      'R&B',
    'RAP',     'RADIO',   'ROCK',  'SAT',      'SAT2',     'SOUL',
    'CD2',     'TALK',    'NEWS',  'SIRIUS',   'TRAFFIC',  'WEATHER',
    'SPORTS',  'NPR',     'DSS',   'M SERVER', 'DISH',     ''
);

%button_name_to_number = (
    'pause'    => 1,
    'stop'     => 2,
    'play'     => 3,
    'rewind'   => 4,
    'up'       => 5,
    'forward'  => 6,
    'left'     => 7,
    'down'     => 8,
    'right'    => 9,
    'previous' => 10,
    'power'    => 11,
    'next'     => 12,
);

%button_name_to_number_40822 = (
    'pause'    => 1,     # 1
    'stop'     => 2,     # 9
    'play'     => 3,     # 2
    'shuffle'  => 4,     # 3
    'repeat'   => 6,     # 4
    'left'     => 7,     # 7
    'right'    => 9,     # 8
    'previous' => 10,    # 5
    'mode'     => 11,    # 0
    'next'     => 12,    # 6
);

@button_number_to_name = (
    '',        'pause', 'stop', 'play',  'rewind',   'up',
    'forward', 'left',  'down', 'right', 'previous', 'power',
    'next'
);

@button_number_to_name_40822 = (
    '',       'pause', 'stop', 'play',  'shuffle',  '',
    'repeat', 'left',  '',     'right', 'previous', 'mode',
    'next'
);

my %commands_to_keys = (

    #  ChangeSrc seems to be okay to send with the current value
    #   'ChangeSrc' => 'source',
    'ChangeTreb' => 'treble',
    'ChangeBass' => 'bass',
    'ChangeBal'  => 'balance',
    'ChangeVol'  => 'volume',
    'ChangeMute' => 'mute',
    'ChangeLoud' => 'loudness',
    'ChangeAmp'  => 'amp',
    'ChangeBaCo' => 'blcolor',
    'ChangeBaLi' => 'brightness',
);

# The version of this Misterhouse object
use constant OBJECT_VERSION => '2.0';

# Maximum number of zones and sources in the system
use constant MAX_ZONES   => 6;
use constant MAX_SOURCES => 4;

# Maximum amount of time to wait for a response to a command (in seconds)
use constant MAX_RESPONSE_WAIT => 5;

# How long after a zone turns on should mute/volume changes not be reported?
use constant IGNORE_AFTER_ON => 15;

# How long after a button_held to ignore a button_pressed
use constant IGNORE_BUTTON_PRESSED_AFTER_HELD => 2;

# How long to wait for a zone to turn on
use constant MAX_ZONE_ON_DELAY => 10;

# How to handle sources... with 5602 system, each zone seems to have its own
# source labels which it sends at startup.
# Set this to 1 to send out the source label when a zone selects a source
use constant SOURCE_SEND_LABELS => 1;

# Set this to 1 to ignore source label changes from keypads
use constant SOURCE_IGNORE_LABLES => 1;

my %Musica_Systems;

sub serial_startup {

    # Nothing needs to be done here...
}

sub _check_for_data {
    for my $port_name ( keys %Musica_Systems ) {
        if (
            (
                $Musica_Systems{$port_name}{'last_data_received'} +
                MAX_RESPONSE_WAIT
            ) < $::Time
          )
        {
            # It has been a while since we received data for this object... so, call
            # the _send_next_cmd() function which will re-send the first item in the
            # queue (if there is one present) just to try the command again
            if ( $Musica_Systems{$port_name}{'object'}->{'queue'}->[0] ) {
                $Musica_Systems{$port_name}{'object'}->{'waiting_for_zone'} = 0;
                if (
                    (
                        $Musica_Systems{$port_name}{'object'}->{'resend_count'}
                        < 3
                    )
                    or ( $Musica_Systems{$port_name}{'object'}->{'queue'}->[0]
                        =~ /^StatVer/ )
                  )
                {
                    $Musica_Systems{$port_name}{'object'}->{'resend_count'}++;
                    $Musica_Systems{$port_name}{'object'}
                      ->_report_error( "Going to re-send command ["
                          . $Musica_Systems{$port_name}{'object'}->{'queue'}
                          ->[0]
                          . "] ($Musica_Systems{$port_name}{'object'}->{'resend_count'} times)"
                      );
                    $Musica_Systems{$port_name}{'object'}->_send_next_cmd();
                }
                elsif (
                    $Musica_Systems{$port_name}{'object'}->{'resend_count'} ==
                    3 )
                {
                    $Musica_Systems{$port_name}{'object'}->{'resend_count'}++;
                    $Musica_Systems{$port_name}{'object'}->_report_error(
                        "Resetting serial connection to re-send command ["
                          . $Musica_Systems{$port_name}{'object'}->{'queue'}
                          ->[0]
                          . "] ($Musica_Systems{$port_name}{'object'}->{'resend_count'} times)"
                    );
                    &::serial_port_reopen($port_name);
                }
                elsif (
                    $Musica_Systems{$port_name}{'object'}->{'resend_count'} <
                    6 )
                {
                    $Musica_Systems{$port_name}{'object'}->{'resend_count'}++;
                    $Musica_Systems{$port_name}{'object'}
                      ->_report_error( "Going to re-send command ["
                          . $Musica_Systems{$port_name}{'object'}->{'queue'}
                          ->[0]
                          . "] ($Musica_Systems{$port_name}{'object'}->{'resend_count'} times)"
                      );
                    $Musica_Systems{$port_name}{'object'}->_send_next_cmd();
                }
                else {
                    $Musica_Systems{$port_name}{'object'}
                      ->_critical_error( "Re-sent command ["
                          . $Musica_Systems{$port_name}{'object'}->{'queue'}
                          ->[0]
                          . '] too many times, dropping' );
                    $Musica_Systems{$port_name}{'object'}->_found_response();
                }
                $Musica_Systems{$port_name}{'last_data_received'} = $::Time;
            }
        }
        for ( my $i = 1; $i <= MAX_ZONES; $i++ ) {
            if ( $Musica_Systems{$port_name}{'object'}->{'zones'}[$i] ) {
                if ( $Musica_Systems{$port_name}{'object'}->{'zones'}[$i]
                    ->{'just_turned_on'} )
                {
                    if (
                        (
                            $Musica_Systems{$port_name}{'object'}
                            ->{'zones'}[$i]->{'on_time'} + MAX_ZONE_ON_DELAY
                        ) <= $::Time
                      )
                    {
                        if ( $Musica_Systems{$port_name}{'object'}
                            ->{'on_repeat_count'} < 3 )
                        {
                            $Musica_Systems{$port_name}{'object'}
                              ->{'on_repeat_count'}++;
                            $Musica_Systems{$port_name}{'object'}
                              ->_report_error(
                                "Turning zone $i on again since it did not turn on before"
                              );
                            $Musica_Systems{$port_name}{'object'}
                              ->{'zones'}[$i]->{'on_time'} = $::Time;
                            $Musica_Systems{$port_name}{'object'}->_queue_cmd(
                                "ChangeSrc/$i/$Musica_Systems{$port_name}{'object'}->{'zones'}[$i]->{'just_turned_on'}"
                            );
                        }
                        elsif ( $Musica_Systems{$port_name}{'object'}
                            ->{'on_repeat_count'} == 3 )
                        {
                            $Musica_Systems{$port_name}{'object'}
                              ->{'on_repeat_count'}++;
                            $Musica_Systems{$port_name}{'object'}
                              ->_report_error(
                                "Resetting serial connection to turn zone $i on again since it did not turn on before"
                              );
                            &::serial_port_reopen($port_name);
                        }
                        elsif ( $Musica_Systems{$port_name}{'object'}
                            ->{'on_repeat_count'} < 6 )
                        {
                            $Musica_Systems{$port_name}{'object'}
                              ->{'on_repeat_count'}++;
                            $Musica_Systems{$port_name}{'object'}
                              ->_report_error(
                                "Turning zone $i on again since it did not turn on before"
                              );
                            $Musica_Systems{$port_name}{'object'}
                              ->{'zones'}[$i]->{'on_time'} = $::Time;
                            $Musica_Systems{$port_name}{'object'}->_queue_cmd(
                                "ChangeSrc/$i/$Musica_Systems{$port_name}{'object'}->{'zones'}[$i]->{'just_turned_on'}"
                            );
                        }
                        else {
                            $Musica_Systems{$port_name}{'object'}
                              ->_critical_error(
                                "Turning zone $i on again since it did not turn on before"
                              );
                        }
                    }
                }
            }
        }
        &::check_for_generic_serial_data($port_name)
          if $::Serial_Ports{$port_name}{'object'};
        my $data = $::Serial_Ports{$port_name}{'data_record'};
        next if !$data;
        $Musica_Systems{$port_name}{'object'}->_parse_data($data);
        $main::Serial_Ports{$port_name}{'data_record'}    = '';
        $Musica_Systems{$port_name}{'last_data_received'} = $::Time;
    }
}

sub reset {
    my ($self) = @_;
    $$self{'queue'} = ();
    foreach ( @{ $$self{'zones'} } ) {
        $_->{'just_turned_on'} = 0;
    }
    $self->_queue_cmd('EventData/0/1');
    $self->_queue_cmd('EventSrc/1');
    $self->_queue_cmd('EventStore/0/1');
    $self->_queue_cmd('StatVer/0');
}

sub new {
    my ( $class, $port_name ) = @_;
    my $self = {};
    $$self{'port_name'} = $port_name;
    $$self{'zone'}      = 0;
    &::print_log(
        "$self->{'port_name'}: Netstreams Musica Misterhouse Module Version "
          . OBJECT_VERSION );
    for ( my $i = 1; $i <= MAX_ZONES; $i++ ) {
        $$self{'zones'}[$i] = undef;
    }
    @{ $$self{'queue'} } = ();
    bless $self, $class;
    $$self{'musica_obj'} = $self;
    $Musica_Systems{$port_name}{'object'} = $self;
    if ( 1 == scalar( keys %Musica_Systems ) ) {  # Add hooks on first call only
        &::MainLoop_pre_add_hook( \&Musica::_check_for_data, 1 );
    }
    &::serial_port_create( $port_name,
        $::config_parms{ $port_name . "_serial_port" }, 9600 );
    $self->_queue_cmd('EventData/0/1');
    $self->_queue_cmd('EventSrc/1');
    $self->_queue_cmd('EventStore/0/1');
    $self->_queue_cmd('StatVer/0');
    return $self;
}

sub _store_zone_source {
    my ( $self, $zone, $source, $set_by ) = @_;
    &::print_log("$self->{'port_name'}: _store_zone_source($zone,$source)")
      if $main::Debug{musica};
    if ( $$self{'zones'}[$zone] and ( $source ne 'X' ) ) {
        my $currsrc = $$self{'zones'}[$zone]->{'source'};
        &::print_log(
            "$self->{'port_name'}: _store_zone_source($zone,$source): $currsrc")
          if $main::Debug{musica};
        unless ( $currsrc eq $source ) {
            $$self{'timerOff'}->stop() if $$self{'timerOff'};
            if ( $currsrc eq '0' ) {

                # Currently off
                $$self{'zones'}[$zone]->set_receive( 'zone_on', $set_by );
                &::print_log(
                    "$self->{'port_name'}: _store_zone_source($zone,$source): Zone just turned on"
                ) if $main::Debug{musica};
                if (   ( $source eq '1' )
                    or ( $source eq '2' )
                    or ( $source eq '3' )
                    or ( $source eq '4' ) )
                {
                    # 5602 keypads don't seem to get the source labels unless they are on, so
                    # make sure to set the labels whenever a source is selected
                    if (SOURCE_SEND_LABELS) {
                        $$self{'sources'}[$source]->set_label(
                            $$self{'sources'}[$source]->get_label() );
                    }
                }
            }
            else {
                if ( $source eq '0' ) {
                    if ( defined $currsrc ) {
                        &::print_log(
                            "$self->{'port_name'}: _store_zone_source($zone,$source): Zone just turned off"
                        ) if $main::Debug{musica};
                        $$self{'zones'}[$zone]
                          ->set_receive( 'zone_off', $set_by );
                        if ( $$self{'timerOff'} ) {
                            $$self{'timerOff'}->set(0);
                        }
                    }
                }
                else {
                    &::print_log(
                        "$self->{'port_name'}: _store_zone_source($zone,$source): Zone source changed"
                    ) if $main::Debug{musica};
                    $$self{'zones'}[$zone]
                      ->set_receive( 'source_changed', $set_by );
                    if (   ( $source eq '1' )
                        or ( $source eq '2' )
                        or ( $source eq '3' )
                        or ( $source eq '4' ) )
                    {
                        # 5602 keypads don't seem to get the source labels unless they are on, so
                        # make sure to set the labels whenever a source is selected
                        if (SOURCE_SEND_LABELS) {
                            $$self{'sources'}[$source]->set_label(
                                $$self{'sources'}[$source]->get_label() );
                        }
                    }
                }
            }
            $$self{'zones'}[$zone]->{'source'} = $source;
            if ( $$self{'sources'}[$currsrc] ) {
                $$self{'sources'}[$currsrc]->_zone_not_using($zone);
            }
            if ( $$self{'sources'}[$source] ) {
                $$self{'sources'}[$source]->_zone_is_using($zone);
            }
        }
    }
}

sub _found_response {
    my ($self) = @_;
    &::print_log(
        "$self->{'port_name'}: found response for: [$self->{'queue'}->[0]]")
      if $main::Debug{musica};
    $self->{'last_received'}      = $self->{'next_last_received'};
    $self->{'next_last_received'} = $$self{'queue'}->[0];
    shift @{ $$self{'queue'} };
    $self->{'resend_count'} = 0;
    $self->_send_next_cmd();
}

sub _check_first_cmd {
    my ( $self, $zone, $cmd ) = @_;
    return unless $$self{'zones'}[$zone];
    return unless ( $$self{'zones'}[$zone]->{'keypad_version'} >= 40822 );
    return if ( $$self{'zones'}[$zone]->{'just_turned_on'} );
    my $compare = $$self{'queue'}->[0];
    if ($compare) {

        # Now, see if we got a response to the first command in the queue
        if ( $cmd eq $compare ) {
            $self->_found_response();
            return 1;
        }
    }
    return 0;
}

sub _see_if_zone_just_turned_on {
    my ( $self, $zone, $new_source, $set_by ) = @_;
    return 0 unless $$self{'zones'}[$zone];
    return 0 unless defined( $$self{'zones'}[$zone]->{'source'} );
    my $currsrc = $$self{'zones'}[$zone]->{'source'};
    &::print_log(
        "$self->{'port_name'}: Zone $zone exists and source is defined (currsrc=$currsrc, new_source=$new_source), just_turned_on="
          . $$self{'zones'}[$zone]->{'just_turned_on'} )
      if $main::Debug{musica};
    if ( ( $currsrc eq '0' ) and ( $new_source ne '0' ) ) {

        # Currently off
        unless ( $$self{'zones'}[$zone]->{'just_turned_on'} ) {
            $$self{'zones'}[$zone]->{'on_time'} = $::Time;
            &::print_log(
                "$self->{'port_name'}: setting just_turned_on=$new_source (zone $zone)"
            ) if $main::Debug{musica};
            $$self{'zones'}[$zone]->{'just_turned_on'}    = $new_source;
            $$self{'zones'}[$zone]->{'just_turned_on_by'} = $set_by;
            $$self{'on_repeat_count'}                     = 0;
            &::print_log(
                "$self->{'port_name'}: Recording that zone $zone was just turned on"
            ) if $main::Debug{musica};
        }
        return 1;
    }
    return 0;
}

sub _parse_data {
    my ( $self, $data ) = @_;
    &::print_log("$self->{'port_name'}: parsing serial data: [$data]")
      if $main::Debug{musica};

    # First, check to see if we got a Busy response which means we need to re-send
    # the first command in the queue
    if ( $data eq 'Busy' ) {
        &::print_log("$self->{'port_name'}: re-sending first command in queue")
          if $main::Debug{musica};
        $self->_send_next_cmd();
        return;
    }
    my ( $cmd, $value ) = ( $data =~ m=^([^/]+)/(.*)$= );
    unless ( $data =~ /\// ) {
        $cmd = $data;
    }
    if ( $cmd eq 'State' ) {
        $cmd = 'Chang';
    }
    my $compare = $$self{'queue'}->[0];
    $compare =~ s/\/.*$//;
    if ($compare) {

        # Now, see if we got a response to the first command in the queue
        if ( $cmd eq $compare ) {
            unless ( $compare eq 'ChangeSrc' ) {
                $self->_found_response();
            }
        }
    }
    if ( $cmd eq 'StatVer' ) {
        my ( $zone, $version ) = split /\//, $value;
        $version =~ s/^\D//;
        if ( $zone == 0 ) {
            $$self{'adc_version'} = $version;
            &::print_log(
                "$self->{'port_name'}: Netstreams Musica ADC Version: $version"
            );
        }
        elsif ( $$self{'zones'}[$zone] ) {
            if ( $version eq 'X' ) {
                $version = 'Not Present';
                $self->_report_error( 'Zone keypad not detected by ADC',
                    $zone );
                $$self{'zones'}[$zone]->{'present'} = 0;
            }
            else {
                $$self{'zones'}[$zone]->{'keypad_version'} = $version;
                $main::Save{"Musica-Keypad$zone-Version"} = $version;
                &::print_log(
                    "$self->{'port_name'}: Netstreams Musica Zone $zone Keypad Version: $version"
                );
                $self->_process_keypad_version($zone);
            }
        }
    }
    elsif ( $cmd eq 'EventPress' ) {
        if ( ( $compare eq 'ExePress' ) or ( $compare eq 'ExeHold' ) ) {

            # Both ExePress and ExeHold commands respond with EventPress
            $self->_found_response();
        }
        else {
            my ( $source, $button, $zone ) = split /\//, $value;
            my $action = 'button_pressed_';
            my $ignore = 0;
            if ( $button > 12 ) {
                $button -= 12;
                $action                    = 'button_held_';
                $$self{'last_held_time'}   = $main::Time;
                $$self{'last_held_button'} = $button;
            }
            elsif ( $$self{'last_held_time'} and $$self{'last_held_button'} ) {
                if ( ( $main::Time - $$self{'last_held_time'} ) <=
                    IGNORE_BUTTON_PRESSED_AFTER_HELD )
                {
                    if ( $$self{'last_held_button'} == $button ) {
                        &::print_log(
                            "$self->{'port_name'}: ignoring button press because of recent button hold"
                        ) if $main::Debug{musica};
                        $ignore = 1;
                    }
                }
            }
            unless ($ignore) {
                if ( $$self{'zones'}[$zone] ) {
                    if ( $$self{'zones'}[$zone]->{'keypad_version'} >= 40822 ) {
                        $$self{'zones'}[$zone]->set_receive(
                            $action . $button_number_to_name_40822[$button],
                            'keypad' );
                    }
                    else {
                        $$self{'zones'}[$zone]->set_receive(
                            $action . $button_number_to_name[$button],
                            'keypad' );
                    }
                }
                if ( $$self{'sources'}[$source] ) {
                    if (    ( $$self{'zones'}[$zone] )
                        and
                        ( $$self{'zones'}[$zone]->{'keypad_version'} >= 40822 )
                      )
                    {
                        $$self{'sources'}[$source]->set_receive(
                            $action . $button_number_to_name_40822[$button],
                            'keypad' );
                    }
                    else {
                        $$self{'sources'}[$source]->set_receive(
                            $action . $button_number_to_name[$button],
                            'keypad' );
                    }
                }
            }
        }
    }
    elsif ( $cmd eq 'ExeLock' ) {
        my ( $zone, $lock ) = split /\//, $value;
        $self->_store_zone_data( $zone, 'locked', $lock,
            ( $lock ? 'locked' : 'unlocked' ) );
    }
    elsif ( $cmd eq 'ChangeVol' ) {
        my ( $zone, $volume ) = split /\//, $value;
        $self->_store_zone_data( $zone, 'volume', $volume, 'volume_changed' );
    }
    elsif ( $cmd eq 'NudgeVol' ) {
        my ( $zone, $volume ) = split /\//, $value;
        $self->_store_zone_nudge( $zone, 'volume', $volume, 0, 35,
            'volume_changed' );
    }
    elsif ( $cmd eq 'ChangeMute' ) {
        my ( $zone, $mute ) = split /\//, $value;
        $self->_store_zone_data( $zone, 'mute', $mute,
            ( $mute ? 'mute_on' : 'mute_off' ) );
    }
    elsif ( $cmd eq 'ChangeTreb' ) {
        my ( $zone, $treble ) = split /\//, $value;
        $self->_store_zone_data( $zone, 'treble', $treble, 'treble_changed' );
    }
    elsif ( $cmd eq 'NudgeTreb' ) {
        my ( $zone, $treble ) = split /\//, $value;
        $self->_store_zone_nudge( $zone, 'treble', $treble, 1, 15,
            'treble_changed' );
    }
    elsif ( $cmd eq 'ChangeBass' ) {
        my ( $zone, $bass ) = split /\//, $value;
        $self->_store_zone_data( $zone, 'bass', $bass, 'bass_changed' );
    }
    elsif ( $cmd eq 'NudgeBass' ) {
        my ( $zone, $bass ) = split /\//, $value;
        $self->_store_zone_nudge( $zone, 'bass', $bass, 1, 15, 'bass_changed' );
    }
    elsif ( $cmd eq 'ChangeBal' ) {
        my ( $zone, $balance ) = split /\//, $value;
        $self->_store_zone_data( $zone, 'balance', $balance,
            'balance_changed' );
    }
    elsif ( $cmd eq 'NudgeBal' ) {
        my ( $zone, $balance ) = split /\//, $value;
        $self->_store_zone_nudge( $zone, 'balance', $balance, 1, 15,
            'balance_changed' );
    }
    elsif ( $cmd eq 'ChangeLoud' ) {
        my ( $zone, $loudness ) = split /\//, $value;
        $self->_store_zone_data( $zone, 'loudness', $loudness,
            ( $loudness ? 'loudness_on' : 'loudness_off' ) );
    }
    elsif ( $cmd eq 'ChangeAmp' ) {
        my ( $zone, $amp ) = split /\//, $value;
        my $newstate = 'internal_amp';
        if ( $amp == 1 ) {
            $newstate = 'internal_external_amp';
        }
        elsif ( $amp == 2 ) {
            $newstate = 'external_amp';
        }
        $self->_store_zone_data( $zone, 'amp', $amp, $newstate );
    }
    elsif ( $cmd eq 'ChangeBaCo' ) {
        my ( $zone, $color ) = split /\//, $value;
        $self->_store_zone_data( $zone, 'blcolor', $color,
            ( $color ? 'color_amber' : 'color_green' ) );
    }
    elsif ( $cmd eq 'ChangeBaLi' ) {
        my ( $zone, $level ) = split /\//, $value;
        $self->_store_zone_data( $zone, 'brightness', $level,
            'brightness_changed' );
    }
    elsif ( $cmd eq 'NudgeSrc' ) {
        my ( $zone, $source ) = split /\//, $value;
        $self->_store_zone_source( $zone, $source, 'misterhouse' );
    }
    elsif ( $cmd eq 'ChangeSrc' ) {
        my ( $zone, $source ) = split /\//, $value;
        if ( $zone == 0 ) {
            for ( my $i = 1; $i <= MAX_ZONES; $i++ ) {
                $self->_store_zone_source( $i, $source, 'misterhouse' );
            }
        }
        else {
            unless (
                $self->_see_if_zone_just_turned_on(
                    $zone, $source, 'misterhouse'
                )
              )
            {
                $self->_store_zone_source( $zone, $source, 'misterhouse' );
            }
        }
        if ( $compare eq 'ChangeSrc' ) {
            $self->_found_response();
        }
    }
    elsif ( $cmd eq 'ChangeStore' ) {
        my ( $source, $label ) = split /\//, $value;
        if ( $$self{'sources'}[$source] ) {
            $$self{'sources'}[$source]->{'label'} = $label;
        }
    }
    elsif ( $cmd eq 'EventStore' ) {
        unless (SOURCE_IGNORE_LABLES) {
            my ( $zone, @sources ) = split /\//, $value;
            my $changed = 0;
            for ( my $i = 1; $i <= MAX_SOURCES; $i++ ) {
                if ( $$self{'sources'}[$i] ) {
                    unless (
                        $$self{'sources'}[$i]->{'label'} eq $sources[ $i - 1 ] )
                    {
                        if ( $$self{'sources'}[$i]->{'label'} ) {
                            $changed = $i;
                            $$self{'sources'}[$i]->{'label'} =
                              $sources[ $i - 1 ];
                            if ( $$self{'zones'}[$zone] ) {
                                $$self{'sources'}[$i]
                                  ->set_receive( 'label_changed',
                                    $$self{'zones'}[$zone] );
                            }
                            else {
                                $$self{'sources'}[$i]
                                  ->set_receive( 'label_changed', undef );
                            }
                        }
                    }
                }
            }
            if ( $$self{'zones'}[$zone] ) {
                $$self{'zones'}[$zone]
                  ->set_receive( 'changed_label_source_' . $changed, 'keypad' )
                  if $changed;
            }
        }
    }
    elsif ( $cmd eq 'EventSrc' ) {
        my (@sources) = split /\//, $value;
        my $who = 'keypad';
        if ( $self->{'next_last_received'} eq 'AllOff' ) {
            $who = 'misterhouse';
        }
        for ( my $i = 1; $i <= MAX_ZONES; $i++ ) {
            unless (
                $self->_see_if_zone_just_turned_on(
                    $i, $sources[ $i - 1 ], $who
                )
              )
            {
                $self->_store_zone_source( $i, $sources[ $i - 1 ], $who );
            }
        }
    }
    elsif ( $cmd eq 'EventData' ) {
        my (
            $zone,     $volume, $bass,    $treble,     $balance,
            $loudness, $mute,   $blcolor, $brightness, $audioport,
            $amp,      $locked, $overheat
        ) = split /\//, $value;
        if ( $$self{'zones'}[$zone] ) {
            if ( $self->_check_first_cmd( $zone, "ChangeVol/$zone/$volume" ) ) {
                $self->_store_zone_data( $zone, 'volume', $volume,
                    'volume_changed' );
            }
            elsif ( $$self{'zones'}[$zone]->{'volume'} != $volume ) {
                if (
                    defined( $$self{'zones'}[$zone]->{'volume'} )
                    and (
                        (
                            $$self{'zones'}[$zone]->{'on_time'} +
                            IGNORE_AFTER_ON
                        ) < $::Time
                    )
                  )
                {
                    $$self{'zones'}[$zone]
                      ->set_receive( 'volume_changed', 'keypad' );
                }
                $$self{'zones'}[$zone]->{'volume'} = $volume;
            }
            if ( $self->_check_first_cmd( $zone, "ChangeBass/$zone/$bass" ) ) {
                $self->_store_zone_data( $zone, 'bass', $bass, 'bass_changed' );
            }
            elsif ( $$self{'zones'}[$zone]->{'bass'} != $bass ) {
                $$self{'zones'}[$zone]->set_receive( 'bass_changed', 'keypad' )
                  if defined $$self{'zones'}[$zone]->{'bass'};
                $$self{'zones'}[$zone]->{'bass'} = $bass;
            }
            if ( $self->_check_first_cmd( $zone, "ChangeTreb/$zone/$treble" ) )
            {
                $self->_store_zone_data( $zone, 'treble', $treble,
                    'treble_changed' );
            }
            elsif ( $$self{'zones'}[$zone]->{'treble'} != $treble ) {
                $$self{'zones'}[$zone]
                  ->set_receive( 'treble_changed', 'keypad' )
                  if defined $$self{'zones'}[$zone]->{'treble'};
                $$self{'zones'}[$zone]->{'treble'} = $treble;
            }
            if ( $self->_check_first_cmd( $zone, "ChangeBal/$zone/$balance" ) )
            {
                $self->_store_zone_data( $zone, 'balance', $balance,
                    'balance_changed' );
            }
            elsif ( $$self{'zones'}[$zone]->{'balance'} != $balance ) {
                $$self{'zones'}[$zone]
                  ->set_receive( 'balance_changed', 'keypad' )
                  if defined $$self{'zones'}[$zone]->{'balance'};
                $$self{'zones'}[$zone]->{'balance'} = $balance;
            }
            if (
                $self->_check_first_cmd( $zone, "ChangeLoud/$zone/$loudness" ) )
            {
                $self->_store_zone_data( $zone, 'loudness', $loudness,
                    ( $loudness ? 'loudness_on' : 'loudness_off' ) );
            }
            elsif ( $$self{'zones'}[$zone]->{'loudness'} != $loudness ) {
                if ($loudness) {
                    $$self{'zones'}[$zone]
                      ->set_receive( 'loudness_on', 'keypad' )
                      if defined $$self{'zones'}[$zone]->{'loudness'};
                }
                else {
                    $$self{'zones'}[$zone]
                      ->set_receive( 'loudness_off', 'keypad' )
                      if defined $$self{'zones'}[$zone]->{'loudness'};
                }
                $$self{'zones'}[$zone]->{'loudness'} = $loudness;
            }
            if ( $self->_check_first_cmd( $zone, "ChangeMute/$zone/$mute" ) ) {
                $self->_store_zone_data( $zone, 'mute', $mute,
                    ( $mute ? 'mute_on' : 'mute_off' ) );
            }
            elsif ( $$self{'zones'}[$zone]->{'mute'} != $mute ) {
                if (
                    defined( $$self{'zones'}[$zone]->{'mute'} )
                    and (
                        (
                            $$self{'zones'}[$zone]->{'on_time'} +
                            IGNORE_AFTER_ON
                        ) < $::Time
                    )
                  )
                {
                    if ($mute) {
                        $$self{'zones'}[$zone]
                          ->set_receive( 'mute_on', 'keypad' );
                    }
                    else {
                        $$self{'zones'}[$zone]
                          ->set_receive( 'mute_off', 'keypad' );
                    }
                }
                $$self{'zones'}[$zone]->{'mute'} = $mute;
            }
            if ( $self->_check_first_cmd( $zone, "ChangeBaCo/$zone/$blcolor" ) )
            {
                $self->_store_zone_data( $zone, 'blcolor', $blcolor,
                    ( $blcolor ? 'color_amber' : 'color_green' ) );
            }
            elsif ( $$self{'zones'}[$zone]->{'blcolor'} != $blcolor ) {
                if ($blcolor) {
                    $$self{'zones'}[$zone]
                      ->set_receive( 'color_amber', 'keypad' )
                      if defined $$self{'zones'}[$zone]->{'blcolor'};
                }
                else {
                    $$self{'zones'}[$zone]
                      ->set_receive( 'color_green', 'keypad' )
                      if defined $$self{'zones'}[$zone]->{'blcolor'};
                }
                $$self{'zones'}[$zone]->{'blcolor'} = $blcolor;
            }
            if (
                $self->_check_first_cmd(
                    $zone, "ChangeBaLi/$zone/$brightness"
                )
              )
            {
                $self->_store_zone_data( $zone, 'brightness', $brightness,
                    'brightness_changed' );
            }
            elsif ( $$self{'zones'}[$zone]->{'brightness'} != $brightness ) {
                if ( defined $$self{'zones'}[$zone]->{'brightness'} ) {
                    if ( $$self{'zones'}[$zone]->{'brightness'} == 0 ) {
                        $$self{'zones'}[$zone]
                          ->set_receive( 'backlight_on', 'keypad' );
                    }
                    elsif ( $brightness == 0 ) {
                        $$self{'zones'}[$zone]
                          ->set_receive( 'backlight_off', 'keypad' );
                    }
                    else {
                        $$self{'zones'}[$zone]
                          ->set_receive( 'brightness_changed', 'keypad' );
                    }
                }
                $$self{'zones'}[$zone]->{'brightness'} = $brightness;
            }
            unless ( $$self{'zones'}[$zone]->{'audioport'} == $audioport ) {
                if ($audioport) {
                    $$self{'zones'}[$zone]
                      ->set_receive( 'audio_port_connected', 'keypad' )
                      if defined $$self{'zones'}[$zone]->{'audioport'};
                }
                else {
                    $$self{'zones'}[$zone]
                      ->set_receive( 'audio_port_disconnected', 'keypad' )
                      if defined $$self{'zones'}[$zone]->{'audioport'};
                }
                $$self{'zones'}[$zone]->{'audioport'} = $audioport;
            }
            if ( $self->_check_first_cmd( $zone, "ChangeAmp/$zone/$amp" ) ) {
                my $newstate = 'internal_amp';
                if ( $amp == 1 ) {
                    $newstate = 'internal_external_amp';
                }
                elsif ( $amp == 2 ) {
                    $newstate = 'external_amp';
                }
                $self->_store_zone_data( $zone, 'amp', $amp, $newstate );
            }
            elsif ( $$self{'zones'}[$zone]->{'amp'} != $amp ) {
                if ( $amp == 0 ) {
                    $$self{'zones'}[$zone]
                      ->set_receive( 'internal_amp', 'keypad' )
                      if defined $$self{'zones'}[$zone]->{'amp'};
                }
                elsif ( $amp == 1 ) {
                    $$self{'zones'}[$zone]
                      ->set_receive( 'internal_external_amp', 'keypad' )
                      if defined $$self{'zones'}[$zone]->{'amp'};
                }
                else {
                    $$self{'zones'}[$zone]
                      ->set_receive( 'external_amp', 'keypad' )
                      if defined $$self{'zones'}[$zone]->{'amp'};
                }
                $$self{'zones'}[$zone]->{'amp'} = $amp;
            }
            unless ( $$self{'zones'}[$zone]->{'locked'} == $locked ) {
                if ($locked) {
                    $$self{'zones'}[$zone]->set_receive( 'locked', 'keypad' )
                      if defined $$self{'zones'}[$zone]->{'locked'};
                }
                else {
                    $$self{'zones'}[$zone]->set_receive( 'unlocked', 'keypad' )
                      if defined $$self{'zones'}[$zone]->{'locked'};
                }
                $$self{'zones'}[$zone]->{'locked'} = $locked;
            }
            unless ( $$self{'zones'}[$zone]->{'overheat'} == $overheat ) {
                if ($overheat) {
                    $$self{'zones'}[$zone]
                      ->set_receive( 'overheated', 'keypad' )
                      if defined $$self{'zones'}[$zone]->{'overheat'};
                }
                else {
                    $$self{'zones'}[$zone]
                      ->set_receive( 'heat_normal', 'keypad' )
                      if defined $$self{'zones'}[$zone]->{'overheat'};
                }
                $$self{'zones'}[$zone]->{'overheat'} = $overheat;
            }
            if ( $$self{'zones'}[$zone]->{'just_turned_on'} ) {
                &::print_log(
                    "$self->{'port_name'}: Got first EventData after zone $zone was turned on, setting zone_on state"
                ) if $main::Debug{musica};
                $self->_store_zone_source(
                    $zone,
                    $$self{'zones'}[$zone]->{'just_turned_on'},
                    $$self{'zones'}[$zone]->{'just_turned_on_by'}
                );
                $$self{'zones'}[$zone]->{'just_turned_on'} = 0;
                if ( $$self{'waiting_for_zone'} == $zone ) {
                    &::print_log(
                        "$self->{'port_name'}: Queue was waiting on this zone, sending next message"
                    ) if $main::Debug{musica};
                    $$self{'waiting_for_zone'} = 0;
                    $self->_send_next_cmd();
                }
            }
        }
    }
}

sub _process_keypad_version {
    my ( $self, $zone_num ) = @_;
    if ( $$self{'zones'}[$zone_num]->{'keypad_version'} < 40822 ) {

        # Use older source names if any keypad is older...
        %source_name_to_number = %source_name_to_number_30419;
        @source_number_to_name = @source_number_to_name_30419;
    }
}

sub _register_zone {
    my ( $self, $zone_obj, $zone_num ) = @_;
    $$self{'zones'}[$zone_num] = $zone_obj;

    # Determine version of the keypad
    if ( $$self{'zones'}[$zone_num]->{'keypad_version'} ) {
        &::print_log(
            "$self->{'port_name'}: Netstreams Musica Zone $zone_num Keypad Version: "
              . $$self{'zones'}[$zone_num]->{'keypad_version'}
              . " (as specified in your .mht file)" );
        $self->_process_keypad_version($zone_num);
    }
    else {
        if ( $main::Save{"Musica-Keypad$zone_num-Version"} ) {
            $$self{'zones'}[$zone_num]->{'keypad_version'} =
              $main::Save{"Musica-Keypad$zone_num-Version"};
            &::print_log(
                "$self->{'port_name'}: Netstreams Musica Zone $zone_num Keypad Version: "
                  . $main::Save{"Musica-Keypad$zone_num-Version"}
                  . " (restored from \%Save)" );
            $self->_process_keypad_version($zone_num);
        }
        else {
            $self->_queue_cmd("StatVer/$zone_num");
        }
    }
}

sub _register_source {
    my ( $self, $source_obj, $source_num ) = @_;
    $$self{'sources'}[$source_num] = $source_obj;
}

sub _send_next_cmd {
    my ($self) = @_;
    if ( $$self{'queue'}->[0] ) {
        my ( $cmd, $zone, $value );
        if ( ( $cmd, $zone, $value ) =
            ( $$self{'queue'}->[0] =~ /^([^\/]+)\/(\d+)\/(\d+)/ ) )
        {
            &::print_log(
                "$self->{'port_name'}: checking command '$cmd' '$zone' '$value'"
            ) if $main::Debug{musica};
            if ( $$self{'zones'}[$zone] ) {

                # Check to make sure the zone still isn't turning on
                if ( $$self{'zones'}[$zone]->{'just_turned_on'} ) {
                    &::print_log(
                        "$self->{'port_name'}: just_turned_on=$$self{'zones'}[$zone]->{'just_turned_on'} (zone $zone)"
                    ) if $main::Debug{musica};
                    my $moved = '';

                    # See if we can find a command for another zone meanwhile
                    for ( my $i = 0;
                        $i <= scalar( @{ $$self{'queue'} } ); $i++ )
                    {
                        if ( $$self{'queue'}->[$i] =~ /^[^\/]+\/(\d+)/ ) {
                            if ( $$self{'zones'}[$1]
                                and
                                not $$self{'zones'}[$zone]->{'just_turned_on'} )
                            {
                                $moved = $$self{'queue'}->[$i];
                                splice @{ $$self{'queue'} }, $i, 1;
                                unshift @{ $$self{'queue'} }, $moved;
                            }
                        }
                    }
                    if ($moved) {
                        &::print_log(
                            "$self->{'port_name'}: Moved command '$moved' to front of queue since we are waiting on zone $zone to turn on"
                        ) if $main::Debug{musica};
                        $self->_send_next_cmd();
                    }
                    else {
                        # Nothing to send, so we have to wait...
                        $$self{'waiting_for_zone'} = $zone;
                        &::print_log(
                            "$self->{'port_name'}: Queue stalled while waiting for zone $zone to turn on"
                        );
                        return;
                    }
                }

                # Check to see if this command is necessary since the new keypads will not
                # respond with an EventData if these messages don't change anythig
                if ( $commands_to_keys{$cmd} ) {
                    &::print_log(
                        "$self->{'port_name'}: $cmd -> $commands_to_keys{$cmd}")
                      if $main::Debug{musica};
                    if (
                        defined $$self{'zones'}[$zone]
                        ->{ $commands_to_keys{$cmd} } )
                    {
                        if ( $$self{'zones'}[$zone]->{ $commands_to_keys{$cmd} }
                            == $value )
                        {
                            &::print_log(
                                "$self->{'port_name'} zone $zone: dropping unnecessary command (already set to value): [$$self{'queue'}->[0]]"
                            ) if $main::Debug{musica};
                            shift @{ $$self{'queue'} };
                            $self->_send_next_cmd();
                            return;
                        }
                    }
                }
            }
        }
        &::print_log(
            "$self->{'port_name'}: sending first command in queue: [$$self{'queue'}->[0]]"
        ) if $main::Debug{musica};
        $main::Serial_Ports{ $$self{'port_name'} }{'object'}
          ->write("$$self{'queue'}->[0]\r");
        $Musica_Systems{ $$self{'port_name'} }{'last_data_received'} = $::Time;
        if ( $cmd and ( $cmd eq 'ChangeAmp' ) ) {
            if (    $$self{'zones'}[$zone]
                and $$self{'zones'}[$zone]->{'keypad_version'} >= 40822 )
            {
                # This version does not respond to this message
                shift @{ $$self{'queue'} };
            }
        }
    }
}

sub _queue_cmd {
    my ( $self, $cmd ) = @_;
    if ( $$self{'port_name'} ) {
        &::print_log("$self->{'port_name'}: queueing command: [$cmd]")
          if $main::Debug{musica};
        if ( ( $cmd =~ /^ChangeSrc\// ) and ( $#{ $$self{'queue'} } >= 1 ) ) {

            # Make sure ChangeSrc commands come before other commands (but never in front of existing first command)
            my $last = 0;
            for ( my $i = 1; $i <= $#{ $$self{'queue'} }; $i++ ) {
                if ( $$self{'queue'}->[$i] =~ /^ChangeSrc\// ) {
                    $last = $i;
                }
            }
            splice @{ $$self{'queue'} }, 1, 0, $cmd;
        }
        else {
            push @{ $$self{'queue'} }, $cmd;
        }
        if ( $#{ $$self{'queue'} } == 0 ) {

            # No entries waiting in queue, send right away, and reset data received timer
            $Musica_Systems{ $$self{'port_name'} }{'last_data_received'} =
              $::Time;
            $self->_send_next_cmd();
        }
    }
    elsif ( $$self{'musica_obj'} ) {
        $$self{'musica_obj'}->_queue_cmd($cmd);
    }
    else {
        &::print_log(
            "ERROR: Musica($self->{'object_name'}): Could not find queue in which to place command [$cmd]"
        ) if $main::Debug{musica};
    }
}

# Takes in a number and a minimum and maximum value and converts that to
# a number between 1 and 15.
sub _scale_to_15 {
    my ( $val, $min, $max ) = @_;
    if ( $val < $min ) {
        $val = $min;
    }
    if ( $val > $max ) {
        $val = $max;
    }
    $val -= $min;
    return ( int( 14 * $val / ( $max - $min ) ) + 1 );
}

sub _print_log {
    my ( $self, $msg, $zone ) = @_;
    if ( ( not $zone ) or ( $zone == 0 ) ) {
        &::print_log("Musica($self->{'port_name'}): $msg")
          if $main::Debug{musica};
    }
    elsif ( $$self{'zones'}[$zone] ) {
        &::print_log("Musica($self->{'port_name'}) zone $zone: $msg")
          if $main::Debug{musica};
    }
}

sub _critical_error {
    my ( $self, $error ) = @_;
    $self->_report_error($error);
    if ( $self->{'critical_error_function'} ) {
        $self->{'critical_error_function'}->($error);
    }
}

sub _report_error {
    my ( $self, $error, $zone ) = @_;
    if ( ( not $zone ) or ( $zone == 0 ) ) {
        $$self{'last_error'} = $error;
        $self->set_receive('error');
        &::print_log("ERROR: Musica($self->{'port_name'}): $error");
    }
    elsif ( $$self{'zones'}[$zone] ) {
        $$self{'zones'}[$zone]->{'last_error'} = $error;
        $$self{'zones'}[$zone]->set_receive('error');
        &::print_log("ERROR: Musica($self->{'port_name'}) zone $zone: $error");
    }
    else {
        $$self{'last_error'} =
          "Received error regarding non-existant zone: $error";
        $self->set_receive('error');
    }
}

sub _calc_zone_nudge {
    my ( $initial, $direction, $min, $max ) = @_;
    if ( $direction == 0 ) {
        $initial--;
        if ( $initial < $min ) {
            $initial = $min;
        }
    }
    elsif ( $direction == 1 ) {
        $initial++;
        if ( $initial > $max ) {
            $initial = $max;
        }
    }
    return $initial;
}

sub _store_zone_nudge {
    my ( $self, $zone, $member, $value, $min, $max, $newstate ) = @_;
    if ( $zone == 0 ) {
        for ( my $i = 1; $i <= MAX_ZONES; $i++ ) {
            if ( $$self{'zones'}[$i] and $$self{'zones'}[$i]->{'present'} ) {
                $self->_store_zone_data(
                    $zone, $member,
                    &Musica::_calc_zone_nudge(
                        $$self{'zones'}[$i]->{$member},
                        $value, $min, $max
                    ),
                    $newstate
                );
            }
        }
    }
    else {
        $self->_store_zone_data( $zone, $member, $value, $newstate );
    }
}

sub _store_zone_data {
    my ( $self, $zone, $member, $value, $newstate ) = @_;
    if ( $zone == 0 ) {
        for ( my $i = 1; $i <= MAX_ZONES; $i++ ) {
            if ( $$self{'zones'}[$i] and $$self{'zones'}[$i]->{'present'} ) {
                if ( $$self{'zones'}[$i]->{$member} != $value ) {
                    $$self{'zones'}[$i]->{$member} = $value;
                    $$self{'zones'}[$i]
                      ->set_receive( $newstate, 'misterhouse' );
                }
            }
        }
    }
    else {
        if ( $$self{'zones'}[$zone] ) {
            if ( $value eq 'X' ) {
                $$self{'zones'}[$zone]->_report_error(
                    "Zone keypad not detected by ADC (tried to set $member)");
            }
            else {
                if ( $$self{'zones'}[$zone]->{$member} != $value ) {
                    $$self{'zones'}[$zone]->{$member} = $value;
                    $$self{'zones'}[$zone]
                      ->set_receive( $newstate, 'misterhouse' );
                }
            }
        }
    }
}

sub _is_base_obj {
    my ( $self, $function ) = @_;
    if ( $self->{'port_name'} ) {
        return 1;
    }
    else {
        $self->_report_error(
            "$function() can only be called on main Musica object");
        return 0;
    }
}

sub get_zone_obj {
    my ( $self, $zone_num ) = @_;
    return $$self{'zones'}[$zone_num];
}

################################################################################
# Begin public system-wide Musica functions
################################################################################

sub set_critical_error_function {
    my ( $self, $ptr ) = @_;
    $self->{'critical_error_function'} = $ptr;
}

sub get_musica_obj {
    my ($self) = @_;
    return $self->{'musica_obj'};
}

sub get_object_version {
    return OBJECT_VERSION;
}

sub get_port_name {
    my ($self) = @_;
    return unless ( $self->_is_base_obj('get_port_name') );
    return $self->{'port_name'};
}

sub get_zones {
    my ($self) = @_;
    return unless ( $self->_is_base_obj('get_zones') );
    return ( @{ $self->{'zones'} } );
}

sub get_sources {
    my ($self) = @_;
    return unless ( $self->_is_base_obj('get_sources') );
    return ( @{ $self->{'sources'} } );
}

sub get_adc_version {
    my ($self) = @_;
    return unless ( $self->_is_base_obj('get_adc_version') );
    return $self->{'adc_version'};
}

sub get_last_error {
    my ($self) = @_;
    return ( $$self{'last_error'} );
}

sub all_off {
    my ($self) = @_;
    return unless ( $self->_is_base_obj('all_off') );
    $self->_queue_cmd('AllOff');
}

sub activate_doorbell_mute {
    my ($self) = @_;
    return unless ( $self->_is_base_obj('activate_doorbell_mute') );
    $self->_queue_cmd("ChangeDoor/1");
}

sub activate_phone_mute {
    my ($self) = @_;
    return unless ( $self->_is_base_obj('activate_phone_mute') );
    $self->_queue_cmd("ChangePhone/1");
}

sub switched_outlet_on {
    my ($self) = @_;
    return unless ( $self->_is_base_obj('switched_outlet_on') );
    $self->_queue_cmd("ChangeSwOu/1");
}

sub switched_outlet_off {
    my ($self) = @_;
    return unless ( $self->_is_base_obj('switched_outlet_off') );
    $self->_queue_cmd("ChangeSwOu/0");
}

sub set_treble {
    my ( $self, $treble ) = @_;
    $treble = _scale_to_15( $treble, -14, 14 );
    $self->_queue_cmd("ChangeTreb/$$self{'zone'}/$treble");
}

sub set_bass {
    my ( $self, $bass ) = @_;
    my $newbass = _scale_to_15( $bass, -14, 14 );
    $self->_queue_cmd("ChangeBass/$$self{'zone'}/$newbass");
}

sub set_balance {
    my ( $self, $balance ) = @_;
    $balance = _scale_to_15( $balance, -7, 7 );
    $self->_queue_cmd("ChangeBal/$$self{'zone'}/$balance");
}

sub set_source {
    my ( $self, $source ) = @_;
    if ( ref $source ) {

        # Passing in a reference to an object?
        if ( $source->isa('Musica::Source') ) {
            $source = $source->{'source'};
        }
        else {
            $self->_report_error(
                "set_source(): Invalid reference as source parameter: $source");
        }
    }
    elsif ( $Musica::source_name_to_number{ uc($source) } ) {

        # Specified the source label, look up proper source number
        my $labelid = $Musica::source_name_to_number{ uc($source) };
        for ( my $i = 1; $i <= MAX_SOURCES; $i++ ) {
            if ( $$self{'musica_obj'}->{'sources'}[$i]->{'label'} == $labelid )
            {
                $source = $i;
                last;
            }
        }
    }
    unless ( ( $source eq 'E' ) or ( $source eq 'F' ) ) {
        unless ( ( $source > 0 ) and ( $source <= Musica::MAX_SOURCES ) ) {
            $self->_report_error(
                "set_source(): Invalid source identifier: $source");
            return;
        }
    }
    $self->_queue_cmd("ChangeSrc/$$self{'zone'}/$source");
}

sub set_volume {
    my ( $self, $volume ) = @_;
    if ( $volume =~ s/%$// ) {
        $volume = ( 35 * ( $volume / 100 ) );
    }
    unless ( ( $volume >= 0 ) or ( $volume <= 35 ) ) {
        $self->_report_error(
            "set_volume(): volume specified is out of range: $volume");
    }
    $volume =~ s/^\s+//;
    $volume =~ s/\s+$//;
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

sub white_backlight {
    my ($self) = @_;
    $self->_queue_cmd("ChangeBaCo/$$self{'zone'}/0");
}

sub amber_backlight {
    my ($self) = @_;
    $self->_queue_cmd("ChangeBaCo/$$self{'zone'}/1");
}

sub blue_backlight {
    my ($self) = @_;
    $self->_queue_cmd("ChangeBaCo/$$self{'zone'}/1");
}

sub set_backlight_brightness {
    my ( $self, $level ) = @_;
    if ( $level =~ s/%$// ) {
        $level = ( 8 * ( $level / 100 ) );
    }
    unless ( ( $level >= 0 ) or ( $level <= 8 ) ) {
        $self->_report_error(
            "set_backlight_brightness(): level specified is out of range: $level"
        );
    }
    $self->_queue_cmd("ChangeBaLi/$$self{'zone'}/$level");
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

sub set_preset_label {
    my ( $self, $number, $label ) = @_;
    my $label    = uc($label);
    my $labelnum = 0;
    if ( $label =~ /^\d+$/ ) {
        $labelnum = $label;
    }
    else {
        # Look up label unless a number is already provided
        if ( $Musica::source_name_to_number{$label} ) {
            $labelnum = $Musica::source_name_to_number{$label};
        }
    }
    $self->_queue_cmd("Chang/41/$$self{'zone'}/$number/$labelnum");
}

sub set_preset_frequency {
    my ( $self, $number, $freq ) = @_;
    $self->_queue_cmd("Chang/4A/$$self{'zone'}/$number/$freq");
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
    my ( $class, $musica_obj, $zone_num, $version ) = @_;
    my $self = {};

    # Assume it is present until told otherwise
    $$self{'present'}        = 1;
    $$self{'zone'}           = $zone_num;
    $$self{'musica_obj'}     = $musica_obj;
    $$self{'keypad_version'} = $version if ($version);
    bless $self, $class;
    $musica_obj->_register_zone( $self, $zone_num );
    return $self;
}

sub _report_error {
    my ( $self, $error ) = @_;
    $$self{'last_error'} = $error;
    $self->set_receive('error');
    &::print_log(
        "ERROR: Musica($self->{'musica_obj'}->{'port_name'}) zone $$self{'object_name'}: $error"
    );
}

sub set {
    my ( $self, $state ) = @_;
    &::print_log("$$self{'object_name'}: got state: $state")
      if $main::Debug{musica};
    if ( $state eq 'off' ) {
        &::print_log("$$self{'object_name'}: got state off, turning off zone")
          if $main::Debug{musica};
        $self->turn_off();
    }
    elsif ( $state =~ s/^volume// ) {
        &::print_log("$$self{'object_name'}: got state volume change: $state")
          if $main::Debug{musica};
        $self->set_volume($state);
    }
    elsif ( $state eq 'mute' ) {
        $self->mute();
    }
    elsif ( $state eq 'unmute' ) {
        $self->unmute();
    }
    elsif (( $state eq 'E' )
        or ( $state eq 'F' )
        or ( ( $state =~ /^\d+$/ ) and ( $state >= 1 ) and ( $state <= 4 ) ) )
    {
        &::print_log("$$self{'object_name'}: got state $state, changing source")
          if $main::Debug{musica};
        $self->set_source($state);
    }
    else {
        &::print_log("$$self{'object_name'}: got unknown Musica state: $state");
    }
}

sub _resolve_to_button_id {
    my ( $self, $button ) = @_;
    if ( $button =~ /^\d+$/ ) {
        if ( ( $button >= 1 ) and ( $button <= 12 ) ) {
            return $button;
        }
        else {
            $self->_report_error(
                "press_button()/hold_button(): Invalid button ID: $button (must be 1 to 12)"
            );
            return 0;
        }
    }
    if ( $$self{'keypad_version'} >= 40822 ) {
        if ( $Musica::button_name_to_number_40822{$button} ) {
            return $Musica::button_name_to_number_40822{$button};
        }
    }
    else {
        if ( $Musica::button_name_to_number{$button} ) {
            return $Musica::button_name_to_number{$button};
        }
    }
    $self->_report_error(
        "press_button()/hold_button(): Invalid button label: $button");
}

################################################################################
# Begin public zone-specific Musica functions
################################################################################

sub delay_off {
    my ( $self, $delay ) = @_;
    if ( defined($delay) ) {
        &::print_log("$$self{'object_name'}: delay_off set to $delay")
          if $main::Debug{musica};
        unless ( $$self{'timerOff'} ) {
            $$self{'timerOff'} = new Timer();
        }
        $$self{'timerOff'}->set( $delay, $self );
    }
    if ( $$self{'timerOff'} ) {
        return $$self{'timerOff'}->query();
    }
    else {
        return 0;
    }
}

sub nudge_source_down {
    my ($self) = @_;
    if ( $self->{'source'} eq '0' ) {
        $self->_report_error("nudge_source_down(): zone is not on.");
    }
    else {
        $self->_queue_cmd("NudgeSrc/$$self{'zone'}/0");
    }
}

sub nudge_source_up {
    my ($self) = @_;
    if ( $self->{'source'} eq '0' ) {
        $self->_report_error("nudge_source_up(): zone is not on.");
    }
    else {
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

sub get_source_obj() {
    my ($self) = @_;
    return $self->{'source'};
    if ( $$self{'sources'}[ $self->{'source'} ] ) {
        return $$self{'sources'}[ $self->{'source'} ];
    }
    return undef;
}

sub get_volume() {
    my ($self) = @_;
    return $self->{'volume'};
}

sub get_bass_level() {
    my ($self) = @_;
    return ( ( $self->{'bass'} - 8 ) * 2 );
}

sub get_treble_level() {
    my ($self) = @_;
    return ( ( $self->{'treble'} - 8 ) * 2 );
}

sub get_balance() {
    my ($self) = @_;
    return ( $self->{'balance'} - 8 );
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
    if ( $self->{'blcolor'} ) {
        return 'amber';
    }
    else {
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
    if ( $self->{'amp'} == 2 ) {
        return 'external_amp';
    }
    elsif ( $self->{'amp'} == 1 ) {
        return 'both';
    }
    else {
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

sub get_button_labels() {
    my ($self) = @_;
    if ( $$self{'keypad_version'} >= 40822 ) {
        return ( sort keys %Musica::button_name_to_number_40822 );
    }
    else {
        return ( sort keys %Musica::button_name_to_number );
    }
}

sub press_button() {
    my ( $self, $button ) = @_;
    if ( $button = $self->_resolve_to_button_id($button) ) {
        $self->_queue_cmd("ExePress/$$self{'source'}/$button");
    }
}

sub hold_button() {
    my ( $self, $button ) = @_;
    if ( $button = $self->_resolve_to_button_id($button) ) {
        $self->_queue_cmd("ExeHold/$$self{'source'}/$button");
    }
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
    my ( $class, $musica_obj, $source_num ) = @_;
    my $self = {};
    $$self{'source'}     = $source_num;
    $$self{'musica_obj'} = $musica_obj;
    for ( my $i = 1; $i <= Musica::MAX_ZONES; $i++ ) {
        $$self{'zones'}->[$i] = 0;
    }
    bless $self, $class;
    $musica_obj->_register_source( $self, $source_num );
    return $self;
}

sub _report_error {
    my ( $self, $error ) = @_;
    $$self{'last_error'} = $error;
    $self->set_receive('error');
    &::print_log(
        "ERROR: Musica($self->{'musica_obj'}->{'port_name'}) source $$self{'object_name'}: $error"
    );
}

sub _zone_not_using {
    my ( $self, $zone ) = @_;
    unless ( $$self{'zones'}->[$zone] == 1 ) {
        return;
    }
    $$self{'zones'}->[$zone] = 0;
    for ( my $i = 1; $i <= Musica::MAX_ZONES; $i++ ) {
        if ( $$self{'zones'}->[$i] == 1 ) {

            # There is still another listener
            return;
        }
    }
    $self->set_receive('no_listeners');
}

sub _zone_is_using {
    my ( $self, $zone ) = @_;
    if ( $$self{'zones'}->[$zone] == 1 ) {

        # Already being used by this zone
        return;
    }
    $$self{'zones'}->[$zone] = 1;
    $self->set_receive("listener_zone_$zone");
    for ( my $i = 1; $i <= Musica::MAX_ZONES; $i++ ) {
        if ( $$self{'zones'}->[$i] == 1 ) {
            if ( $i != $zone ) {

                # There was already a listener...
                return;
            }
        }
    }
    $self->set_receive('first_listener');
}

################################################################################
# Begin public source-specific Musica functions
################################################################################

sub get_usage_count() {
    my ($self) = @_;
    my $ret = 0;
    for ( my $i = 1; $i <= Musica::MAX_ZONES; $i++ ) {
        if ( $$self{'zones'}->[$i] == 1 ) {
            $ret++;
        }
    }
    return ($ret);
}

sub get_zones() {
    my ($self) = @_;
    my @ret;
    for ( my $i = 1; $i <= Musica::MAX_ZONES; $i++ ) {
        if ( $$self{'zones'}->[$i] == 1 ) {
            push @ret, $i;
        }
    }
    return (@ret);
}

sub get_source_labels() {
    return ( sort keys %Musica::source_name_to_number );
}

sub get_source_num() {
    my ($self) = @_;
    return ( $self->{'source'} );
}

sub get_label() {
    my ($self) = @_;
    if ( $self->{'label'} ) {
        return $Musica::source_number_to_name[ $self->{'label'} ];
    }
    else {
        return '';
    }
}

sub set_label {
    my ( $self, $label ) = @_;
    my $label    = uc($label);
    my $labelnum = 0;
    if ( $label =~ /^\d+$/ ) {
        $labelnum = $label;
    }
    else {
        # Look up label unless a number is already provided
        if ( $Musica::source_name_to_number{$label} ) {
            $labelnum = $Musica::source_name_to_number{$label};
        }
    }
    unless (( $labelnum >= 1 )
        and ( $labelnum <= $#Musica::source_number_to_name ) )
    {
        $self->_report_error(
            "set_label(): Invalid source label: $label (resolved number was $labelnum)"
        );
        return;
    }
    $self->_queue_cmd("ChangeStore/$$self{'source'}/$labelnum");
}

################################################################################
# End public source-specific Musica functions
################################################################################

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Kirk Bauer  kirk@kaybee.org

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

