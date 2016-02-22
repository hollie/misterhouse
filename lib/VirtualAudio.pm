
=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	VirtualAudio.pm

Description:
   VirtualAudio::Source represents a virtual audio source that can be played by
   a physical multi-zone audio system.  VirtualAudio::Router can determine
   how to route these virtual audio sources to physical audio sources and zones.

   Basically, this module changes how you look at your whole-house audio
   system.  Currently, you probably think of your system as having 2, 4, or 6
   sources.  Source 1 is your FM tuner, source 2 is your CD player, etc.

   With this module you have to have another way of selecting sources,
   since you will have more than your current number.  In my case, I have arrow
   keys on the keypads and remotes that I use to scroll through virtual sources.
   I also have twelve keys that I can hold down for one second to jump straight
   to a particular source.  It is kind of like tuning your radio with preset
   stations.

   Your user interface may be different, but the important thing is that you
   provide to the user more sources than the system physically supports.
   The user just requests a source an this module does the dirty work of
   connecting the requested source to a real source input.

Hardware Requirements:
   - You need some sort of whole-house audio system, with any number of
   source inputs and any number of zone outputs.  You must have limited
   control over the system from Misterhouse as described next and I think
   a RS232 interface is your only option at this point.

   - You need to be able to control the whole-house audio system to the
   extent that you must be able to tell any specific zone to listen to
   any specific source.  In other words, you need to be able to tell
   zone 2 to listen to source 3.

   - You need to be able to watch for zones being turned on or off or being
   manually tuned to a specific source.  These activities need to be
   reported to the virtual audio router.

   - You need to be able to provide some way for the user to select or scroll
   through virtual sources, such as a keypad whose activity you can monitor,
   or an IR or even X10 remote, or voice interface, etc.

Author:
	Kirk Bauer
	kirk@kaybee.org

   You can get the most current version of this file and other files related
   whole-house music/speech setup here:
     http://www.linux.kaybee.org:81/tabs/whole_house_audio/

License:
	This free software is licensed under the terms of the GNU public license.

Definitions:
   Virtual Audio Router: you need one of these for each whole-house audio
      system.  It decides when and to which inputs to connect virtual sources.
      Virtual sources are sometimes referred to by their name which is
      defined when the object is created.
   Virtual Source: An audio source that can be connected to one or more
      real source inputs to your whole-house audio system.  It may always
      be connected to only one input, or it may be able to be connected to
      all inputs.
   Real Source Input: One of your physical source inputs of your whole-house
      audio system.
   Zone: One of your physical output zones of your whole-house audio system.

Usage:
   First of all, it may be best to visit my web interface above and get a
   overview of my setup and all of my code.  But I'll try to document just
   this VirtualAudio module by itself here.  Please note that you do not
   need to use any specific virtual sources or any specific hardware, but
   my examples are based on my setup, which includes multiple MP3 outputs
   using AlsaPlayer.pm as well as the Netstreams Musica system using
   Musica.pm.  You'll have to change the code to match your situation,
   but you'll find that this virtual audio code was written to be very
   flexible.

   .MHT Entries

      To begin with, you can define these objects in your .mht files:

         VIRTUAL_AUDIO_ROUTER, audio_router, 6, 4
         VIRTUAL_AUDIO_SOURCE, v_voice,        audio_router
         VIRTUAL_AUDIO_SOURCE, v_classical,    audio_router
         VIRTUAL_AUDIO_SOURCE, v_romantic,     audio_router
         VIRTUAL_AUDIO_SOURCE, v_new_age,      audio_router
         VIRTUAL_AUDIO_SOURCE, v_kirk_mp3s,    audio_router
         VIRTUAL_AUDIO_SOURCE, v_pink_floyd,   audio_router
         VIRTUAL_AUDIO_SOURCE, v_rock,         audio_router
         VIRTUAL_AUDIO_SOURCE, v_tivo,         audio_router, 3|4
         VIRTUAL_AUDIO_SOURCE, v_pvr,          audio_router, 3|4
         VIRTUAL_AUDIO_SOURCE, v_dvd,          audio_router, 3|4
         VIRTUAL_AUDIO_SOURCE, v_tuner,        audio_router, 3|4
         VIRTUAL_AUDIO_SOURCE, v_internet,     audio_router, 3|4

      So, I have defined one audio router ($audio_router) to be used with a
      whole-house audio system with 6 zones and 4 sources.  Even if you did not
      read my web page above, you'll need to know that I have an IR-controlled
      switch box in front of the source 3 and 4 inputs.

      Next, I have defined 12 virtual sources.  The first I use in Misterhouse for
      voice only and to play MP3s through the existing MP3 jukebox functionality.
      The next six virtual sources are all MP3 sources with five different
      playlists.  The next four sources are devices connected through the
      zone2/zone3 outputs of my home theater receiver, and the last source goes
      directly into the switch boxes.

      The last five sources have an extra parameter specifying that they can
      only be attached to the real source inputs 3 and 4 of my whole-house
      audio system, since those are the inputs with the switch boxes in front
      of them.

   User-code Initialization

      Upon code reload (and startup) you need to set up your virtual
      source objects' data fields.  You can have any number of virtual
      sources and are not required to have any specific ones.  The
      set_data() function can be used to set arbitrary name/value pairs
      for the object and is only to be used by your user code.  This
      data is ignored by the Virtual Audio router.  I have chosen a
      select few of my sources' initialization code to include below.
      The only thing you are required to do is specify a valid
      function using set_action_function() as shown below.

      # Define the playlists that I'll add to the virtual audio sources
      # defined in my .mht file
      my $pl_kirk_mp3s = new PlayList;

      if ($Reload) {
         print_log "VirtualAudio: Reload block is running...";

         # Load files into playlists
         $pl_kirk_mp3s->add_files('/mnt/mp3s/KirkAll.m3u');

         # Set handlers for all virtual sources (I use the same for all)
         # !! REQUIRED !!
         $v_kirk_mp3s->set_action_function(\&handle_virtual_source);
         $v_voice->set_action_function(\&handle_virtual_source);
         $v_internet->set_action_function(\&handle_virtual_source);
         $v_pvr->set_action_function(\&handle_virtual_source);

         # Keep 'v_voice' virtual source attached whenever possible.  The 'v_voice' source
         # represents a clear ALSA output channel to be used for Misterhouse speech output
         $v_voice->keep_attached_when_possible();
         $v_voice->set_data('label', 'LIGHTS');

         $v_internet->set_data('label', 'INTERNET');
         $v_internet->set_data('switch_input', 'SOURCE3');

         $v_pvr->set_data('label', 'SAT2');
         $v_pvr->set_data('switch_input', 'SOURCE2');
         $v_pvr->set_data('receiver_input', 'CBL-SAT');

         # Setup all MP3 playlists
         $pl_kirk_mp3s->randomize();
         $v_kirk_mp3s->set_data('playlist', $pl_kirk_mp3s);
         $v_kirk_mp3s->set_data('shuffle', 1);
         $v_kirk_mp3s->set_data('label', 'DAD');
         $v_kirk_mp3s->set_data('switch_input', 'SOURCE1');

         # Resume audio sources across a restart/reload
         $audio_router->resume();
      }

   Action Function
      All of your virtual sources must have a action function for it
      specified with set_action_function().  I use one function for
      all of my virtual sources, but you could use different functions
      for different sources.  This function must accept three arguments:
         1) The virtual source object being acted upon
         2) The requested action to be taken:
            - attach
            - detach
            - in_use
            - not_in_use
         3) The real source input number the virtual source needs to be
            connected to, is connected to, or is about to be removed from.

      For attach/detach you must do whatever is necessary to attach or
      detach this virtual source from the specified real source input.
      This may include switching relays/switch boxes and/or loading
      playlists.

      For in_use/not_in_use you can take any action you so desire such as
      pausing playback or turning on/off sources.

      Here is my attach function which is of course very specific to my
      particular setup.  Please note that I have cut out a some stuff such as
      code that automatically turns off my zone2/zone3 outputs when not in
      use.  You can get the full function from the musica.pl file available
      from my web site above.

         sub handle_virtual_source {
           my ($obj, $action, $source) = @_;
           print_log "VirtualAudio: got action $action for $$obj{name} (source=$source)";
           if ($obj->get_data('label')) {
              print_log "VirtualAudio:    $$obj{name} has label: " . $obj->get_data('label');
           }
           if ($obj->get_data('playlist')) {
              print_log "VirtualAudio:    $$obj{name} has playlist: " . $obj->get_data('playlist');
           }
           if ($action eq 'attach') {
              if ($obj->get_data('switch_input')) {
                 print_log "VirtualAudio: Switch input for $$obj{name} is " . $obj->get_data('switch_input') . " (source=$source)";
                 if ($source == 3) {
                    set $IR_Switch1 $obj->get_data('switch_input');
                 } elsif ($source == 4) {
                    set $IR_Switch2 $obj->get_data('switch_input');
                 }
              }
              if ($obj->get_data('label')) {
                 $musica_sources[$source]->set_label($obj->get_data('label'));
              }
              if ($obj->get_data('playlist')) {
                 $players[$source]->remove_all_playlists();
                 $players[$source]->shuffle($obj->get_data('shuffle'));
                 $players[$source]->add_playlist($obj->get_data('playlist'));
                 $players[$source]->pause();
              }
              if ($$obj{name} eq 'v_voice') {
                 &set_default_alsaplayer($players[$source]);
                 $players[$source]->stop();
              }
           } elsif ($action eq 'detach') {
              if ($obj->get_data('playlist')) {
                 $players[$source]->pause();
                 $players[$source]->remove_playlist($obj->get_data('playlist'));
              }
           } elsif ($action eq 'in_use') {
              if ($obj->get_data('playlist')) {
                 $players[$source]->unpause();
              }
              if ($obj->get_data('receiver_input')) {
                 print_log "VirtualAudio: Object $$obj{name} has receiver input (source=$source): " . $obj->get_data('receiver_input');
                 if ($source == 3) {
                    print_log "VirtualAudio: Object $$obj{name} (source=$source) selecting input: " . $obj->get_data('receiver_input');
                    set $IR_Zone2 'ZONEON';
                    set $IR_Zone2 $obj->get_data('receiver_input');
                 } elsif ($source == 4) {
                    print_log "VirtualAudio: Object $$obj{name} (source=$source) selecting input: " . $obj->get_data('receiver_input');
                    set $IR_Zone3 'ZONEON';
                    set $IR_Zone3 $obj->get_data('receiver_input');
                 }
              } else {
                 &check_zones_off($obj, $source);
              }
           } elsif ($action eq 'not_in_use') {
              if ($obj->get_data('playlist')) {
                 $players[$source]->pause();
              }
              &check_zones_off($obj, $source);
           }
        }

   User Interface
      Well, the above is about it when it comes to creating and using virtual
      audio sources.  But you'll also need to provide a way for the user of
      your audio system to select the virtual source they want to listen to.
      Since this module is not specific to any hardware, your interface can
      be whatever you choose.  In my case, I use the Netstreams Musica
      keypads and my Home Theater Master MX-500 remote controls.

      The virtual audio router provides a set of functions to allow you to
      select a virtual source for a zone.

         select_virtual_source(zone_num, vsource_name): requests virtual
            source 'vsource_name' for zone number 'zone_num'.

         request_previous_virtual_source_for_zone(zone_num): selects the
            previous virtual source for zone number 'zone_num'.

         request_next_virtual_source_for_zone(zone_num): selects the
            next virtual source for zone number 'zone_num'.

      Note: the order of the virtual sources for request_next/previous is
      the order the virtual sources are defined in your .mht file.

      Here are some examples from my Musica system:

      my @musica_zones = ( undef, $music_kitchen, $music_mb, $music_patio );
      foreach (@musica_zones) {
         next unless $_;
         if ($state = state_now $_) {
            if ($state eq 'button_held_pause') {
               # User pressed a button that jumps straight to the classical virtual source
               my $source = $audio_router->select_virtual_source($_->get_zone_num(), 'v_classical');
               # If source returned is greater than 0, the zone needs to listen
               # to that particular real source input.
               $_->set_source($source) if ($source > 0);
            } elsif ($state eq 'button_pressed_right') {
               # User requesting next virtual source
               my $source = $audio_router->request_next_virtual_source_for_zone($_->get_zone_num());
               $_->set_source($source) if ($source > 0);
            } elsif ($state eq 'button_pressed_left') {
               # User requesting previous virtual source
               my $source = $audio_router->request_previous_virtual_source_for_zone($_->get_zone_num());
               $_->set_source($source) if ($source > 0);
            }
         }
      }

   Monitoring your whole-house audio system
      You must watch for zones being turned on or off or being manually
      changed to other sources and notify the virtual audio router of
      these activities.  If the zone is turned on, you need to tell
      the virtual audio router which source it is listening to.  If a
      zone is turned off you tell the virtual audio router that it is
      listening to source 0.  On a source change, just report the new
      physical source.

      my @musica_zones = ( undef, $music_kitchen, $music_mb, $music_patio );
      foreach (@musica_zones) {
         next unless $_;
         if ($state = state_now $_) {
            if (($state eq 'zone_on') or ($state eq 'zone_off') or ($state eq 'source_changed')) {
               # With the Musica system, get_source() will always return the current
               # source or 0 if the zone is off, so I just call this funciton in all cases
               my $source = $_->get_source();
               if ($source eq 'E') {
                  # 'E' is the local zone-specific source so listening to this source
                  # is the same as being off to the virtual audio router.
                  $source = 0;
               }
               $audio_router->specify_source_for_zone($_->get_zone_num(), $source);
            }
         }
      }

   Information retrieval
      There are numerous functions that allow you to retrieve information
      about the current state of the virtual audio router.  These I use for
      my web-based control/info page.

      get_virtual_source_obj_for_zone(zone_num): Returns the virtual source
         object that zone 'zone_num' is currently listening to, or undefined
         if the zone is off.

      get_virtual_source_name_for_zone(zone_num): Returns the name of the
         virtual source that zone 'zone_num' is currently listening to, or
         undefined if the zone is off.

      get_virtual_source_obj_for_real_source(source_num): Returns the virtual
         source object that is currently connected to the real source input
         'source_num'.

      get_zones_listening_to_vsource(vsource_name): Returns an array of zone
         numbers for each zone currently listening to 'vsource_name'.
      get_zones_listening_to_vsource(vsource): Returns an array of zone
         numbers for each zone currently listening to object 'vsource'.

      get_zones_listening_to_source(source): Returns an array of zone
         numbers for each zone currently listening to source number 'source'.



      get_real_source_number_for_vsource(vsource_name): Returns the real
         source input number that 'vsource_name' is attached to.

      get_real_source_number_for_zone(zone_num): Returns the real source
         input number that 'zone_num' is attached to.

TODO:
   - do something when a zone selects a source that has not been allocated
   - handle the case when a source can't be selected because it can only
     be connected to specific real source inputs, but it/they is/are in use,
     but the source currently connected to it could be moved to a different
     real source input.

Special Thanks to:
	Bruce Winter - Misterhouse

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package VirtualAudio::Source;

sub new {
    my ( $class, $name, $router, $sources ) = @_;
    my $self = {};
    bless $self, $class;
    $$self{'name'}       = $name;
    $$self{'attach'}     = undef;
    $$self{'detach'}     = undef;
    $$self{'difficulty'} = 1;
    @{ $$self{'only_sources'} } = ();

    if ($router) {
        $router->add_virtual_sources($self);
    }
    if ($sources) {
        my @source_list = split /\|/, $sources;
        push @{ $$self{'only_sources'} }, @source_list;
    }
    return $self;
}

sub set_data {
    my ( $self, $name, $value ) = @_;
    $$self{'data'}{$name} = $value;
    return $value;
}

sub delete_data {
    my ( $self, $name ) = @_;
    delete $$self{'data'}{$name};
}

sub get_data {
    my ( $self, $name ) = @_;
    return ( $$self{'data'}{$name} );
}

sub set_action_function {
    my ( $self, $ptr ) = @_;
    $$self{'function_ptr'} = $ptr;
}

sub attach_difficulty {
    my ( $self, $difficulty ) = @_;
    $$self{'difficulty'} = $difficulty if defined($difficulty);
    return $$self{'difficulty'};
}

sub only_attach_to_sources {
    my ( $self, @sources ) = @_;
    push @{ $$self{'only_sources'} }, @sources;
}

sub keep_attached_when_possible {
    my ($self) = @_;
    $$self{'keep_attached'} = 1;
}

sub _not_in_use {
    my ( $self, $source ) = @_;
    if ( $$self{'function_ptr'} ) {
        $$self{'function_ptr'}->( $self, 'not_in_use', $source );
    }
}

sub _in_use {
    my ( $self, $source ) = @_;
    if ( $$self{'function_ptr'} ) {
        $$self{'function_ptr'}->( $self, 'in_use', $source );
    }
}

sub _attach_to_source {
    my ( $self, $source ) = @_;
    if ( $$self{'function_ptr'} ) {
        $$self{'function_ptr'}->( $self, 'attach', $source );
    }
}

sub _detach_from_source {
    my ( $self, $source ) = @_;
    if ( $$self{'function_ptr'} ) {
        $$self{'function_ptr'}->( $self, 'detach', $source );
    }
}

package VirtualAudio::Router;

@VirtualAudio::Router::ISA = ('Generic_Item');

sub new {
    my ( $class, $zones, $sources ) = @_;
    my $self = {};
    bless $self, $class;
    $$self{'num_zones'}   = $zones;
    $$self{'num_sources'} = $sources;
    for ( my $i = 1; $i <= $$self{'num_zones'}; $i++ ) {
        $$self{'zones'}->[$i] = 0;
    }
    for ( my $i = 1; $i <= $$self{'num_sources'}; $i++ ) {
        $$self{'sources'}->[$i] = undef;
    }
    $self->restore_data('attached_sources');
    return $self;
}

sub _handle_resume {
    my ( $self, $vsource ) = @_;
    &::print_log(
        "VirtualAudio::Router::add_virtual_sources: attached_sources=$$self{attached_sources}"
    );
    if ( $$self{'attached_sources'} =~ /\|$$vsource{name}=([^|]+)\|/ ) {
        unless ( $self->_is_source_being_used($1) ) {
            unless ( $self->get_real_source_number_for_vsource($vsource) ) {
                $self->_attach_virtual_source( $1, $vsource );
                return 1;
            }
        }
    }
    return 0;
}

sub get_virtual_sources {
    my ($self) = @_;
    return ( @{ $$self{'virtual_source_order'} } );
}

sub resume {
    my ($self) = @_;
    foreach my $vsource ( @{ $$self{'virtual_source_order'} } ) {
        $self->_handle_resume($vsource);
    }
}

sub add_virtual_sources {
    my ( $self, @sources ) = @_;
    foreach my $vsource (@sources) {
        my $name = $vsource->{'name'};
        $$self{'virtual_sources'}{$name} = $vsource;
        push @{ $$self{'virtual_source_order'} }, $vsource;
        unless ( $self->_handle_resume($vsource) ) {
            if ( $$vsource{'keep_attached'} ) {
                my $source = $self->_find_unused_source($vsource);
                if ( $source > 0 ) {
                    $self->_attach_virtual_source( $source, $vsource );
                }
            }
        }
    }
}

sub remove_virtual_sources {
    my ( $self, @sources ) = @_;
    foreach my $vsource (@sources) {
        my $name = $vsource;
        if ( ref $vsource ) {
            $name = $vsource->{'name'};
        }
        my $attached =
          $self->get_real_source_number_for_vsource(
            $$self{'virtual_sources'}{$name} );
        if ( $attached > 0 ) {
            $self->_detach_virtual_source($attached);
        }
        delete $$self{'virtual_sources'}{$name};
        for ( my $i = 0; $i < $#{ $$self{'virtual_source_order'} }; $i++ ) {
            if ( $$self{'virtual_source_order'}->[$i]->{'name'} eq $name ) {
                splice @{ $$self{'virtual_source_order'} }, $i, 1;
            }
        }
    }
}

sub _is_source_being_used {
    my ( $self, $source, $ignore_zone ) = @_;
    my $used = 0;
    for ( my $i = 1; $i <= $$self{'num_zones'}; $i++ ) {
        unless ( $ignore_zone and ( $i == $ignore_zone ) ) {
            if ( $$self{'zones'}->[$i] == $source ) {
                $used++;
            }
        }
    }
    &::print_log(
        "VirtualAudio::Router::_is_source_being_used($source, $ignore_zone): returning $used"
    );
    return $used;
}

sub _zone_started_using_source {
    my ( $self, $zone, $source ) = @_;
    &::print_log(
        "VirtualAudio::Router::_zone_started_using_source($zone, $source)");
    unless ( $self->_is_source_being_used( $source, $zone ) ) {

        # Unless it was already being used, notify that it is in use
        if ( $$self{'sources'}->[$source] ) {
            &::print_log(
                "VirtualAudio::Router::_zone_started_using_source($zone, $source): Calling _in_use"
            );
            $$self{'sources'}->[$source]->_in_use($source);
        }
    }
    $$self{'zones'}->[$zone] = $source;
}

sub _detach_virtual_source {
    my ( $self, $source ) = @_;
    if ( $$self{'sources'}->[$source] ) {
        $$self{'attached_sources'} =~
          s/\|$$self{sources}->[$source]->{name}=[^|]+\|/|/g;
        &::print_log(
            "VirtualAudio::Router::_detach_virtual_source($$self{sources}->[$source]->{name}): attached_sources=$$self{attached_sources}"
        );
        &::print_log(
            "VirtualAudio::Router::_detach_virtual_source($source): Calling _not_in_use"
        );
        $$self{'sources'}->[$source]->_not_in_use($source);
        &::print_log(
            "VirtualAudio::Router::_detach_virtual_source($source): Calling _detach_from_source"
        );
        $$self{'sources'}->[$source]->_detach_from_source($source);
    }
}

sub _attach_virtual_source {
    my ( $self, $source, $vsource ) = @_;
    &::print_log(
        "VirtualAudio::Router::_attach_virtual_source($source, $$vsource{name})"
    );
    $self->_detach_virtual_source($source);
    $$self{'sources'}->[$source] = $vsource;
    &::print_log(
        "VirtualAudio::Router::_attach_virtual_source($source, $$vsource{name}): Calling _attach_to_source"
    );
    $vsource->_attach_to_source($source);

    # Remember the assignment upon a restart
    $$self{'attached_sources'} =~ s/\|$$vsource{name}=[^|]+\|/|/g;
    $$self{'attached_sources'} =~ s/\|[^=]+=$source\|/|/g;
    $$self{'attached_sources'} .= "$$vsource{name}=$source|";
    unless ( $$self{'attached_sources'} =~ /^\|/ ) {
        $$self{'attached_sources'} = "|$$self{'attached_sources'}";
    }
    &::print_log(
        "VirtualAudio::Router::_attach_virtual_source($$vsource{name}): attached_sources=$$self{attached_sources}"
    );
}

sub _find_unattached_preferred_source {
    my ($self) = @_;
    REATTACH: foreach my $vsource ( @{ $$self{'virtual_source_order'} } ) {
        if ( $$vsource{'keep_attached'} ) {

            # Found a source that we want to keep attached whenever possible...
            # Make sure it is indeed attached somewhere...
            for ( my $i = 1; $i <= $$self{'num_sources'}; $i++ ) {
                if ( $$self{'sources'}->[$i] eq $vsource ) {
                    next REATTACH;
                }
            }

            # The source is not in use, try to attach
            return $vsource;
        }
    }
    return 0;
}

sub _zone_stopped_using_source {
    my ( $self, $zone, $source ) = @_;
    &::print_log(
        "VirtualAudio::Router::_zone_stopped_using_source($zone, $source)");
    $$self{'zones'}->[$zone] = 0;
    unless ( $self->_is_source_being_used($source) ) {
        if ( $$self{'sources'}->[$source] ) {
            &::print_log(
                "VirtualAudio::Router::_zone_stopped_using_source($zone, $source): Calling _not_in_use"
            );
            $$self{'sources'}->[$source]->_not_in_use($source);
        }
        my $vsource = $self->_find_unattached_preferred_source();
        if ( $vsource > 0 ) {
            $self->_attach_virtual_source( $source, $vsource );
        }
    }
}

# Returns score relating to how good a source is to be allocated to
# a new vsource -- lower score means it is a better choice
sub _rate_source_potential {
    my ( $self, $source ) = @_;
    my $rating = 0;

    # First, figure out how many virtual sources can connect to
    # this source... the fewer sources that can connect, the
    # lower the score.
    foreach ( @{ $$self{'virtual_source_order'} } ) {
        if ( @{ $$_{'only_sources'} } ) {
            foreach ( @{ $$_{'only_sources'} } ) {
                if ( $_ eq $source ) {
                    $rating++;
                }
            }
        }
        else {
            $rating++;
        }
    }

    if ( $$self{'sources'}->[$source] ) {
        $rating += $$self{'sources'}->[$source]->{'difficulty'};
        if ( $$self{'sources'}->[$source]->{'keep_attached'} ) {
            $rating += 100;
        }
    }

    return $rating;
}

sub _find_unused_source {
    my ( $self, $vsource ) = @_;
    my @sources = @{ $$vsource{'only_sources'} };
    unless (@sources) {
        for ( my $i = 1; $i <= $$self{'num_sources'}; $i++ ) {
            push @sources, $i;
        }
    }

    my $best_source   = 0;
    my $lowest_rating = 1000;
    foreach (@sources) {
        unless ( $self->_is_source_being_used($_) ) {
            my $rating = $self->_rate_source_potential($_);
            if ( $rating < $lowest_rating ) {
                $best_source   = $_;
                $lowest_rating = $rating;
            }
        }
    }
    return $best_source;
}

sub _attach_best_vsource {
    my ( $self, $source ) = @_;
    &::print_log("VirtualAudio::Router::_attach_best_vsource($source)");
    my $vsource = $self->_find_unattached_preferred_source();
    if ( $vsource > 0 ) {
        $self->_attach_virtual_source( $source, $vsource );
        return;
    }

    # If none of those, attach first unallocated virtual source
    foreach $vsource ( @{ $$self{'virtual_source_order'} } ) {
        unless ( $self->get_real_source_number_for_vsource($vsource) ) {

            # Okay, found an unattached virtual source
            $self->_attach_virtual_source( $source, $vsource );
            return;
        }
    }
}

sub specify_source_for_zone {
    my ( $self, $zone, $source ) = @_;
    &::print_log(
        "VirtualAudio::Router: zone $zone listening to source $source");
    if (   ( $zone !~ /^\d+$/ )
        or ( $zone < 1 )
        or ( $zone > $$self{'num_zones'} ) )
    {
        &::print_log(
            "VirtualAudio::Router::specify_source_for_zone(): ERROR: zone $zone out of range"
        );
        return;
    }
    if ( ( $source < 0 ) or ( $source > $$self{'num_sources'} ) ) {
        &::print_log(
            "VirtualAudio::Router::specify_source_for_zone(): ERROR: source $source out of range"
        );
        return;
    }
    return if ( $$self{'zones'}->[$zone] eq $source );
    if ( $$self{'zones'}->[$zone] > 0 ) {
        $self->_zone_stopped_using_source( $zone, $$self{'zones'}->[$zone] );
    }
    if ( $source > 0 ) {
        unless ( $$self{'sources'}->[$source] ) {
            $self->_attach_best_vsource($source);
        }
        $self->_zone_started_using_source( $zone, $source );
    }
}

sub _attach_zone_to_source {
    my ( $self, $zone, $vsource ) = @_;
    my $already = $self->get_real_source_number_for_vsource($vsource);
    if ( $already > 0 ) {

        # Already attached to a source...
        $self->specify_source_for_zone( $zone, $already );
        return $already;
    }
    if ( $$self{'zones'}->[$zone] > 0 ) {
        $self->_zone_stopped_using_source( $zone, $$self{'zones'}->[$zone] );
    }
    my $source = $self->_find_unused_source($vsource);
    if ( $source > 0 ) {
        $self->_attach_virtual_source( $source, $vsource );
        $self->specify_source_for_zone( $zone, $source );
    }
    return $source;
}

sub select_virtual_source {
    my ( $self, $zone, $vsource ) = @_;
    if ( ( $zone < 1 ) or ( $zone > $$self{'num_zones'} ) ) {
        &::print_log(
            "VirtualAudio::Router::specify_source_for_zone(): ERROR: zone $zone out of range"
        );
        return 0;
    }
    unless ( ref $vsource and $vsource->isa('VirtualAudio::Source') ) {
        if ( $$self{'virtual_sources'}{$vsource} ) {
            $vsource = $$self{'virtual_sources'}{$vsource};
        }
        else {
            &::print_log(
                "VirtualAudio::Router::select_virtual_source(): ERROR: virtual source $vsource not found"
            );
            return 0;
        }
    }
    &::print_log(
        "VirtualAudio::Router: zone $zone requesting source $$vsource{name}");
    return $self->_attach_zone_to_source( $zone, $vsource );
}

sub _do_next_previous_virtual_source {
    my ( $self, $zone, @vsources ) = @_;
    if ( ( $zone < 1 ) or ( $zone > $$self{'num_zones'} ) ) {
        &::print_log(
            "VirtualAudio::Router::request_next/previous_virtual_source_for_zone(): ERROR: zone $zone out of range"
        );
        return 0;
    }
    my $curr_vsource = $self->get_virtual_source_obj_for_zone($zone);
    &::print_log(
        "VirtualAudio::Router: current source is $$curr_vsource{name}");
    my $found = 0;
    foreach my $vsource (@vsources) {
        &::print_log("VirtualAudio::Router: checking source: $$vsource{name}");
        if ($curr_vsource) {
            if ($found) {

                # Already found the current source, so take the next one...
                &::print_log(
                    "VirtualAudio::Router: found next source: $$vsource{name}");
                return $self->_attach_zone_to_source( $zone, $vsource );
            }
            elsif ( $curr_vsource eq $vsource ) {
                &::print_log(
                    "VirtualAudio::Router: found current source: $$vsource{name}"
                );
                $found = 1;
            }
        }
        else {
            # No source currently selected... attach to first source found that is already attached
            &::print_log(
                "VirtualAudio::Router: attaching to first source: $$vsource{name}"
            );
            if ( $self->get_real_source_number_for_vsource($vsource) ) {
                return $self->_attach_zone_to_source( $zone, $vsource );
            }
        }
    }
    if ($found) {

        # Found current source at end of list... give the first one
        &::print_log(
            "VirtualAudio::Router: looped around list: $vsources[0]->{name}");
        return $self->_attach_zone_to_source( $zone, $vsources[0] );
    }
    return 0;
}

sub request_next_virtual_source_for_zone {
    my ( $self, $zone ) = @_;
    &::print_log("VirtualAudio::Router: zone $zone requesting next source");
    return $self->_do_next_previous_virtual_source( $zone,
        @{ $$self{'virtual_source_order'} } );
}

sub request_previous_virtual_source_for_zone {
    my ( $self, $zone ) = @_;
    &::print_log("VirtualAudio::Router: zone $zone requesting previous source");
    return $self->_do_next_previous_virtual_source( $zone,
        reverse @{ $$self{'virtual_source_order'} } );
}

sub get_real_source_number_for_zone {
    my ( $self, $zone ) = @_;
    return $$self{'zones'}->[$zone];
}

sub get_real_source_number_for_vsource {
    my ( $self, $vsource ) = @_;
    for ( my $i = 1; $i <= $$self{'num_sources'}; $i++ ) {
        if ( $$self{'sources'}->[$i] eq $vsource ) {
            return $i;
        }
    }
    return 0;
}

sub get_zones_listening_to_source {
    my ( $self, $source ) = @_;
    my @ret;
    for ( my $i = 1; $i <= $$self{'num_zones'}; $i++ ) {
        if ( $$self{'zones'}->[$i] == $source ) {
            push @ret, $i;
        }
    }
    return (@ret);
}

sub get_zones_listening_to_vsource {
    my ( $self, $vsource ) = @_;
    my $source = $self->get_real_source_number_for_vsource($vsource);
    return () unless $source;
    my @ret;
    for ( my $i = 1; $i <= $$self{'num_zones'}; $i++ ) {
        if ( $$self{'zones'}->[$i] == $source ) {
            push @ret, $i;
        }
    }
    return (@ret);
}

sub get_virtual_source_obj_for_real_source {
    my ( $self, $source ) = @_;
    return $$self{'sources'}->[$source];
}

sub get_virtual_source_name_for_real_source {
    my ( $self, $source ) = @_;
    if ( $$self{'sources'}->[$source] ) {
        return $$self{'sources'}->[$source]->{'name'};
    }
    return '';
}

sub get_virtual_source_name_for_zone {
    my ( $self, $zone ) = @_;
    if ( $$self{'zones'}->[$zone] > 0 ) {
        if ( $$self{'sources'}->[ $$self{'zones'}->[$zone] ] ) {
            return $$self{'sources'}->[ $$self{'zones'}->[$zone] ]->{'name'};
        }
    }
    return '';
}

sub get_virtual_source_obj_for_zone {
    my ( $self, $zone ) = @_;
    if ( $$self{'zones'}->[$zone] > 0 ) {
        if ( $$self{'sources'}->[ $$self{'zones'}->[$zone] ] ) {
            return $$self{'sources'}->[ $$self{'zones'}->[$zone] ];
        }
    }
    return undef;
}

1;
