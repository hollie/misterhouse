=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	VirtualAudio.pm

Description:
   VirtualAudio::Source represents a virtual audio source that can be played by
   a physical multi-zone audio system.  VirtualAudio::Router can determine
   how to route these virtual audio sources to physical audio sources and zones.

Author:
	Kirk Bauer
	kirk@kaybee.org

   You can get the most current version of this file and other files related
   whole-house music/speech setup here:
     http://www.linux.kaybee.org:81/tabs/whole_house_audio/

License:
	This free software is licensed under the terms of the GNU public license.

Usage:

TODO:
   - Instead of keep_attached_when_possible() set a numeric attachment preference
     or, set a numeric value indicating the difficulty in attaching/detaching
     (i.e. playlists with tons of MP3s are difficult, or something that takes
      5 seconds to do in hardware)
   - do something when a zone selects a source that has not been allocated
   - Implement only_attach_to_sources()
   - Find a way to set up groups of virtual sources so that only one can be selected at once

Special Thanks to: 
	Bruce Winter - Misterhouse

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package VirtualAudio::Source;

sub new
{
	my ($class, $name, $router) = @_;
	my $self={};
	bless $self,$class;
   $$self{'name'} = $name;
   $$self{'attach'} = undef;
   $$self{'detach'} = undef;
   $$self{'difficulty'} = 1;
   @{$$self{'only_sources'}} = ();
   if ($router) {
      $router->add_virtual_sources($self);
   }
	return $self;
}

sub set_data {
   my ($self, $name, $value) = @_;
   $$self{'data'}{$name} = $value;
   return $value;
}

sub delete_data {
   my ($self, $name) = @_;
   delete $$self{'data'}{$name};
}

sub get_data {
   my ($self, $name) = @_;
   return ($$self{'data'}{$name});
}

sub set_action_function {
   my ($self, $ptr) = @_;
   $$self{'function_ptr'} = $ptr;
}

sub attach_difficulty {
   my ($self, $difficulty) = @_;
   $$self{'difficulty'} = $difficulty if defined($difficulty);
   return $$self{'difficulty'};
}

sub only_attach_to_sources {
   my ($self, @sources) = @_;
   push @{$$self{'only_sources'}}, @sources;
}

sub keep_attached_when_possible {
   my ($self) = @_;
   $$self{'keep_attached'} = 1;
}

sub _not_in_use {
   my ($self, $source) = @_;
   if ($$self{'function_ptr'}) {
      $$self{'function_ptr'}->($self, 'not_in_use', $source);
   }
}

sub _in_use {
   my ($self, $source) = @_;
   if ($$self{'function_ptr'}) {
      $$self{'function_ptr'}->($self, 'in_use', $source);
   }
}

sub _attach_to_source {
   my ($self, $source) = @_;
   if ($$self{'function_ptr'}) {
      $$self{'function_ptr'}->($self, 'attach', $source);
   }
}

sub _detach_from_source {
   my ($self, $source) = @_;
   if ($$self{'function_ptr'}) {
      $$self{'function_ptr'}->($self, 'detach', $source);
   }
}

package VirtualAudio::Router;

@VirtualAudio::Router::ISA = ('Generic_Item');

sub new
{
	my ($class, $zones, $sources) = @_;
	my $self={};
	bless $self,$class;
   $$self{'num_zones'} = $zones;
   $$self{'num_sources'} = $sources;
   for (my $i = 1; $i <= $$self{'num_zones'}; $i++) {
      $$self{'zones'}->[$i] = 0;
   }
   for (my $i = 1; $i <= $$self{'num_sources'}; $i++) {
      $$self{'sources'}->[$i] = undef;
   }
   $self->restore_data('attached_sources');
	return $self;
}

sub _handle_resume {
   my ($self, $vsource) = @_;
   &::print_log("VirtualAudio::Router::add_virtual_sources: attached_sources=$$self{attached_sources}");
   if ($$self{'attached_sources'} =~ /\|$$vsource{name}=([^|]+)\|/) {
      unless ($self->_is_source_being_used($1)) {
         unless ($self->get_real_source_number_for_vsource($vsource)) {
            $self->_attach_virtual_source($1, $vsource);
            return 1;
         }
      }
   }
   return 0;
}

sub get_virtual_sources {
   my ($self) = @_;
   return (@{$$self{'virtual_source_order'}});
}

sub resume {
   my ($self) = @_;
   foreach my $vsource ( @{$$self{'virtual_source_order'}}) {
      $self->_handle_resume($vsource);
   }
}

sub add_virtual_sources {
	my ($self, @sources) = @_;
   foreach my $vsource (@sources) {
      my $name = $vsource->{'name'};
      $$self{'virtual_sources'}{$name} = $vsource;
      push @{$$self{'virtual_source_order'}}, $vsource;
      unless ($self->_handle_resume($vsource)) {
         if ($$vsource{'keep_attached'}) {
            my $source = $self->_find_unused_source($vsource);
            if ($source > 0) {
               $self->_attach_virtual_source($source, $vsource);
            }
         }
      }
   }
}

sub remove_virtual_sources {
	my ($self, @sources) = @_;
   foreach my $vsource (@sources) {
      my $name = $vsource;
      if (ref $vsource) {
         $name = $vsource->{'name'};
      }
      my $attached = $self->get_real_source_number_for_vsource($$self{'virtual_sources'}{$name});
      if ($attached > 0) {
         $self->_detach_virtual_source($attached);
      }
      delete $$self{'virtual_sources'}{$name};
      for (my $i = 0; $i < $#{$$self{'virtual_source_order'}}; $i++) {
         if ($$self{'virtual_source_order'}->[$i]->{'name'} eq $name) {
            splice @{$$self{'virtual_source_order'}}, $i, 1;
         }
      }
   }
}

sub _is_source_being_used {
   my ($self, $source) = @_;
   my $used = 0;
   for (my $i = 1; $i <= $$self{'num_zones'}; $i++) {
      if ($$self{'zones'}->[$i] == $source) {
         $used++;
      }
   }
   &::print_log("VirtualAudio::Router::_is_source_being_used($source): returning $used");
   return $used;
}

sub _zone_started_using_source {
	my ($self, $zone, $source) = @_;
   &::print_log("VirtualAudio::Router::_zone_started_using_source($zone, $source)");
   unless ($self->_is_source_being_used($source)) {
      # Unless it was already being used, notify that it is in use
      if ($$self{'sources'}->[$source]) {
         &::print_log("VirtualAudio::Router::_zone_started_using_source($zone, $source): Calling _in_use");
         $$self{'sources'}->[$source]->_in_use($source);
      }
   }
   $$self{'zones'}->[$zone] = $source;
}

sub _detach_virtual_source {
   my ($self, $source) = @_;
   if ($$self{'sources'}->[$source]) {
      $$self{'attached_sources'} =~ s/\|$$self{sources}->[$source]->{name}=[^|]+\|/|/g;
      &::print_log("VirtualAudio::Router::_detach_virtual_source($$self{sources}->[$source]->{name}): attached_sources=$$self{attached_sources}");
      &::print_log("VirtualAudio::Router::_detach_virtual_source($source): Calling _not_in_use");
      $$self{'sources'}->[$source]->_not_in_use($source);
      &::print_log("VirtualAudio::Router::_detach_virtual_source($source): Calling _detach_from_source");
      $$self{'sources'}->[$source]->_detach_from_source($source);
   }
}

sub _attach_virtual_source {
	my ($self, $source, $vsource) = @_;
   &::print_log("VirtualAudio::Router::_attach_virtual_source($source, $$vsource{name})");
   $self->_detach_virtual_source($source);
   $$self{'sources'}->[$source] = $vsource;
   &::print_log("VirtualAudio::Router::_attach_virtual_source($source, $$vsource{name}): Calling _attach_to_source");
   $vsource->_attach_to_source($source);
   # Remember the assignment upon a restart
   $$self{'attached_sources'} =~ s/\|$$vsource{name}=[^|]+\|/|/g;
   $$self{'attached_sources'} =~ s/\|[^=]+=$source\|/|/g;
   $$self{'attached_sources'} .= "$$vsource{name}=$source|";
   unless ($$self{'attached_sources'} =~ /^\|/) {
      $$self{'attached_sources'} = "|$$self{'attached_sources'}";
   }
   &::print_log("VirtualAudio::Router::_attach_virtual_source($$vsource{name}): attached_sources=$$self{attached_sources}");
}

sub _find_unattached_preferred_source {
   my ($self) = @_;
   REATTACH: foreach my $vsource ( @{$$self{'virtual_source_order'}}) {
      if ($$vsource{'keep_attached'}) {
         # Found a source that we want to keep attached whenever possible...
         # Make sure it is indeed attached somewhere...
         for (my $i = 1; $i <= $$self{'num_sources'}; $i++) {
            if ($$self{'sources'}->[$i] eq $vsource) {
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
	my ($self, $zone, $source) = @_;
   &::print_log("VirtualAudio::Router::_zone_stopped_using_source($zone, $source)");
   $$self{'zones'}->[$zone] = 0;
   unless ($self->_is_source_being_used($source)) {
      if ($$self{'sources'}->[$source]) {
         &::print_log("VirtualAudio::Router::_zone_stopped_using_source($zone, $source): Calling _not_in_use");
         $$self{'sources'}->[$source]->_not_in_use($source);
      }
      my $vsource = $self->_find_unattached_preferred_source();;
      if ($vsource > 0) {
         $self->_attach_virtual_source($source, $vsource);
      }
   }
}

# Returns score relating to how good a source is to be allocated to
# a new vsource -- lower score means it is a better choice
sub _rate_source_potential {
   my ($self, $source) = @_;
   my $rating = 0;

   # First, figure out how many virtual sources can connect to 
   # this source... the fewer sources that can connect, the
   # lower the score.
   foreach (@{$$self{'virtual_source_order'}}) {
      if (@{$$_{'only_sources'}}) {
         foreach (@{$$_{'only_sources'}}) {
            if ($_ eq $source) {
               $rating++;
            }
         }
      } else {
         $rating++;
      }
   }

   if ($$self{'sources'}->[$source]) {
      $rating += $$self{'sources'}->[$source]->{'difficulty'};
      if ($$self{'sources'}->[$source]->{'keep_attached'}) {
         $rating += 100;
      }
   }

   return $rating;
}

sub _find_unused_source {
   my ($self, $vsource) = @_;
   my @sources = @{$$vsource{'only_sources'}};
   unless (@sources) {
      for (my $i = 1; $i <= $$self{'num_sources'}; $i++) {
         push @sources, $i;
      }
   }

   my $best_source = 0;
   my $lowest_rating = 1000;
   foreach (@sources) {
      unless ($self->_is_source_being_used($_)) {
         my $rating = $self->_rate_source_potential($_);
         if ($rating < $lowest_rating) {
            $best_source = $_;
            $lowest_rating = $rating;
         }
      }
   }
   return $best_source;
}

sub _attach_best_vsource {
   my ($self, $source) = @_;
   &::print_log("VirtualAudio::Router::_attach_best_vsource($source)");
   my $vsource = $self->_find_unattached_preferred_source();;
   if ($vsource > 0) {
      $self->_attach_virtual_source($source, $vsource);
      return;
   }
   # If none of those, attach first unallocated virtual source
   foreach $vsource ( @{$$self{'virtual_source_order'}}) {
      unless ($self->get_real_source_number_for_vsource($vsource)) {
         # Okay, found an unattached virtual source
         $self->_attach_virtual_source($source, $vsource);
         return;
      }
   }
}

sub specify_source_for_zone {
	my ($self, $zone, $source) = @_;
   &::print_log("VirtualAudio::Router: zone $zone listening to source $source");
   if (($zone !~ /^\d+$/) or ($zone < 1) or ($zone > $$self{'num_zones'})) {
      &::print_log("VirtualAudio::Router::specify_source_for_zone(): ERROR: zone $zone out of range");
      return;
   }
   if (($source < 0) or ($source > $$self{'num_sources'})) {
      &::print_log("VirtualAudio::Router::specify_source_for_zone(): ERROR: source $source out of range");
      return;
   }
   return if ($$self{'zones'}->[$zone] eq $source);
   if ($$self{'zones'}->[$zone] > 0) {
      $self->_zone_stopped_using_source($zone, $$self{'zones'}->[$zone]);
   }
   if ($source > 0) {
      unless ($$self{'sources'}->[$source]) {
         $self->_attach_best_vsource($source);
      }
      $self->_zone_started_using_source($zone, $source);
   }
}

sub _attach_zone_to_source {
   my ($self, $zone, $vsource) = @_;
   my $already = $self->get_real_source_number_for_vsource($vsource);
   if ($already > 0) {
      # Already attached to a source...
      $self->specify_source_for_zone($zone, $already);
      return $already;
   }
   if ($$self{'zones'}->[$zone] > 0) {
      $self->_zone_stopped_using_source($zone, $$self{'zones'}->[$zone]);
   }
   my $source = $self->_find_unused_source($vsource);
   if ($source > 0) {
      $self->_attach_virtual_source($source, $vsource);
      $self->specify_source_for_zone($zone, $source);
   }
   return $source;
}

sub select_virtual_source {
	my ($self, $zone, $vsource) = @_;
   if (($zone < 1) or ($zone > $$self{'num_zones'})) {
      &::print_log("VirtualAudio::Router::specify_source_for_zone(): ERROR: zone $zone out of range");
      return 0;
   }
   unless (ref $vsource and $vsource->isa('VirtualAudio::Source')) {
      if ($$self{'virtual_sources'}{$vsource}) {
         $vsource = $$self{'virtual_sources'}{$vsource};
      } else {
         &::print_log("VirtualAudio::Router::select_virtual_source(): ERROR: virtual source $vsource not found");
         return 0;
      }
   }
   &::print_log("VirtualAudio::Router: zone $zone requesting source $$vsource{name}");
   return $self->_attach_zone_to_source($zone, $vsource);
}

sub _do_next_previous_virtual_source {
   my ($self, $zone, @vsources) = @_;
   if (($zone < 1) or ($zone > $$self{'num_zones'})) {
      &::print_log("VirtualAudio::Router::request_next/previous_virtual_source_for_zone(): ERROR: zone $zone out of range");
      return 0;
   }
   my $curr_vsource = $self->get_virtual_source_obj_for_zone($zone);
   &::print_log("VirtualAudio::Router: current source is $$curr_vsource{name}");
   my $found = 0;
   foreach my $vsource (@vsources) {
      &::print_log("VirtualAudio::Router: checking source: $$vsource{name}");
      if ($curr_vsource) {
         if ($found) {
            # Already found the current source, so take the next one...
            &::print_log("VirtualAudio::Router: found next source: $$vsource{name}");
            return $self->_attach_zone_to_source($zone, $vsource);
         } elsif ($curr_vsource eq $vsource) {
            &::print_log("VirtualAudio::Router: found current source: $$vsource{name}");
            $found = 1;
         }
      } else {
         # No source currently selected... attach to first source found that is already attached
         &::print_log("VirtualAudio::Router: attaching to first source: $$vsource{name}");
         if ($self->get_real_source_number_for_vsource($vsource)) {
            return $self->_attach_zone_to_source($zone, $vsource);
         }
      }
   }
   if ($found) {
      # Found current source at end of list... give the first one
      &::print_log("VirtualAudio::Router: looped around list: $vsources[0]->{name}");
      return $self->_attach_zone_to_source($zone, $vsources[0]);
   }
   return 0;
}

sub request_next_virtual_source_for_zone {
	my ($self, $zone) = @_;
   &::print_log("VirtualAudio::Router: zone $zone requesting next source");
   return $self->_do_next_previous_virtual_source($zone, @{$$self{'virtual_source_order'}});
}

sub request_previous_virtual_source_for_zone {
	my ($self, $zone) = @_;
   &::print_log("VirtualAudio::Router: zone $zone requesting previous source");
   return $self->_do_next_previous_virtual_source($zone, reverse @{$$self{'virtual_source_order'}});
}

sub get_real_source_number_for_zone {
	my ($self, $zone) = @_;
   return $$self{'zones'}->[$zone];
}

sub get_real_source_number_for_vsource {
	my ($self, $vsource) = @_;
   for (my $i = 1; $i <= $$self{'num_sources'}; $i++) {
      if ($$self{'sources'}->[$i] eq $vsource) {
         return $i;
      }
   }
   return 0;
}

sub get_zones_listening_to_vsource {
	my ($self, $vsource) = @_;
   my $source = $self->get_real_source_number_for_vsource($vsource);
   return () unless $source;
   my @ret;
   for (my $i = 1; $i <= $$self{'num_zones'}; $i++) {
      if ($$self{'zones'}->[$i] == $source) {
         push @ret, $i;
      }
   }
   return (@ret);
}

sub get_virtual_source_name_for_real_source {
	my ($self, $source) = @_;
   if ($$self{'sources'}->[$source]) {
      return $$self{'sources'}->[$source]->{'name'};
   }
   return '';
}

sub get_virtual_source_name_for_zone {
	my ($self, $zone) = @_;
   if ($$self{'zones'}->[$zone] > 0) {
      if ($$self{'sources'}->[$$self{'zones'}->[$zone]]) {
         return $$self{'sources'}->[$$self{'zones'}->[$zone]]->{'name'};
      }
   }
   return '';
}

sub get_virtual_source_obj_for_zone {
	my ($self, $zone) = @_;
   if ($$self{'zones'}->[$zone] > 0) {
      if ($$self{'sources'}->[$$self{'zones'}->[$zone]]) {
         return $$self{'sources'}->[$$self{'zones'}->[$zone]];
      }
   }
   return undef;
}

1;

