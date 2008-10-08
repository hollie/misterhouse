=begin comment

EIB_Item.pm - EIB (European Installation Bus) items.

Info:

EIB/KNX website:
    http://konnex.org

Notes:
    The following EIB types are supported:
    EIS  1: Switches
    EIS  2: Dimmers
    EIS  3: Time
    EIS  4: Date
    EIS  5: Values (weather stations etc)
    EIS  6: Scaling (0 - 100%)
    EIS  7: Motor drives
    EIS 15: 14 byte text messages

Authors:
 09/09/2005  Created by Peter Sjödin peter@sjodin.net

 $Date$
 $Revision$

=cut

use strict;

package EIB_Item;
@EIB_Item::ISA = ('Generic_Item');

my %eib_item_by_id;

sub reset {
    undef %eib_item_by_id;   # Reset on code re-load
}

# Lookup EIB_Item with the given address
sub eib_item_by_id {
    my($id) = @_;
    return $eib_item_by_id{$id};
}

# Generic EIB_Item class. This class is not instantiated directly. It is used to inherit common
# EIB properties
sub new {
    my ($class, $id, $mode) =  @_;
    my $self  = $class->SUPER::new();

   print "\n\nWarning: duplicate ID codes on different EIB_Item objects:\n " .
         "id=$id states=@{${eib_item_by_id($id)}{states}}\n\n" if (eib_item_by_id($id));

    add($self, $id);
    bless $self, $class;
    $self->{groupaddr} = $id if $id;

    if (defined $mode) {
	$self->{readable} = 1 if (index($mode, "R") != -1 || index($mode, "r") != -1);
    }
    if ($self->{readable}) {
	# trigger future EIB read command
	$self->read_request();
    }
    return $self;
}

sub add {
    my ($self, $id, $state) = @_;
    $state = $id  unless (defined $state && $state ne '');

    $$self{state_by_id}{$id} = $state if defined $id;
    $$self{id_by_state}{$state} = $id if defined $state;
    push(@{$$self{states}}, $state) if defined $state;
    print "**** WARNING **** Duplicated state \'$state\' for id \'$id\'\n", $state, $id
	if ($id && eib_item_by_id($id));
    $eib_item_by_id{$id} = $self;
}

# Item name to appear in logs etc
sub printname {
    my($name) = @_;

    if ($name =~ /\d+\/\d+\/\d+/) {
	my $item = eib_item_by_id($name);
	$name = $item->{object_name} if (defined $item && defined $item->{object_name});
    }
    return $name;
}

# set_receive: detected an EIB event on the bus
# Update item state to reflect the value in the event
sub set_receive {
    my ($self, $state, $set_by, $target) = @_;

    return if &main::check_for_tied_filters($self, $state, $set_by);
    # Set target to symbolic item name, if possible
    $target = $self->{groupaddr} unless (defined $target);
    $target = &printname($target);
    &Generic_Item::set_states_for_next_pass($self, $state, $set_by, $target);
}

sub set {
    my ($self, $state, $set_by, $target) = @_;

    return 0 if &main::check_for_tied_filters($self, $state, $set_by);

    if ($state eq 'toggle') {
        if ($$self{state} eq 'on') {
            $state = 'off';
        }
        elsif ($$self{state} eq 'off') {
            $state = 'on';
	}
        else {
	    &main::print_log("Can't toggle EIB_Item object $self->{object_name} in state $$self{state}");
	    return 0;
        }
        &main::print_log("Toggling EIB_Item object $self->{object_name} from $$self{state} to $state");
    }

    $target = $self->{groupaddr} unless (defined $target);
    $target = &printname($target);

    &Generic_Item::set_states_for_next_pass($self, $state, $set_by, $target);

    return 1 if     $main::Save{mode} eq 'offline';

# If encode method exists, generate and send EIB message
    my $data = $self->encode($state) if $self->can("encode");
    $self->send_write_msg($data) if (defined $data);

    return 1;
}

sub readable {
    my ($self) = @_;

    return (defined $self->{readable});
}

# send_write_msg: generate EIB message to set a value
sub send_write_msg {
    my ($self, $data) = @_;
    my $msg;

    $msg->{'type'} = 'write';
    $msg->{'dst'} = $self->{groupaddr};
    $msg->{'data'} = $data;
    EIB_Device::send_msg($msg);
}

# send_read_msg: generate EIB message to read a value
sub send_read_msg {
    my ($self, $data) = @_;
    my $msg;

    $msg->{'type'} = 'read';
    $msg->{'dst'} = $self->{groupaddr};
    $msg->{'data'} = [0];
    EIB_Device::send_msg($msg);
}

# receive_write_msg: process a message to set a value
sub receive_write_msg {
    my ($self, $state, $set_by, $target) = @_;

    $self->set_receive($state, $set_by, $target);
}

# receive_reply_msg: process a message with a reply value (read response)
sub receive_reply_msg {
    my ($self, $state, $set_by, $target) = @_;
    my $t;

    $self->stop_read_timer();
    $self->{read_attempts} = undef;
    $self->set_receive($state, $set_by, $target, 1);
}

# receive_msg: entry point from device interace. Analyse message and call appropriate receive_*_msg
# handler
sub receive_msg {
    my ($msg) = @_;

    my $addr = $msg->{'dst'};
    my $op = $msg->{'type'};
    my @data = @{$msg->{'data'}};
    my $eib_item = EIB_Item::eib_item_by_id($addr);
    my $state = decode $eib_item @data if ($eib_item && $op ne 'read');


    if ($eib_item) {
	&main::print_log("EIB $op from $msg->{'src'} to $msg->{'dst'}",
			 $op eq 'read' ? "" : defined $state ? ": \"$state\"" : ": \"[@data]\"")
	    if $main::config_parms{eib_errata} >= 3;
	if ($op eq 'write') {
	    $eib_item->receive_write_msg($state, $msg->{'src'}, $msg->{'dst'});
	}
	elsif ($op eq 'reply') {
	    $eib_item->receive_reply_msg($state, $msg->{'src'}, $msg->{'dst'});
	}
    }
    else {
	&main::print_log("EIB $op from $msg->{'src'} to $msg->{'dst'}",
			 $op eq 'read' ? "" : defined $state ? ": \"$state\"" : ": \"[@data]\"", ". Item not found.") if $main::config_parms{eib_errata} >= 2;
;
    }
}

# start_read_timer: set a timeout for waiting for read response
sub start_read_timer {
    my ($self, $interval) = @_;

    $interval = 0 + $::config_parms{eib_read_retry_interval} unless defined $interval;
    $self->{get_timer} = new Timer;
    $self->{get_timer}->set($interval, sub {EIB_Item::read_timeout($self);}, 1);
    $self->{get_timer}->start();
}

# stop_read_timer: disable timer
sub stop_read_timer {
    my ($self) = @_;

    return unless defined $self->{get_timer};
    $self->{get_timer}->unset();
    $self->{get_timer} = undef;
}

# read_timeout: No reply to read request. Retry or give up.
sub read_timeout {
    my ($self) = @_;

    stop_read_timer($self);
    $self->{read_timeouts}++;
    if  ($self->{read_timeouts} > $::config_parms{eib_max_read_attempts}) {
	&main::print_log( "EIB read failure for group ", $self->{groupaddr});
    }
    else {
	$self->send_read_msg();
	start_read_timer($self);
    }
}

# read_request: send a read request, and start timer
sub read_request {
    my ($self) = @_;

    $self->send_read_msg();
    $self->{read_timeouts} = 0;
    $self->start_read_timer();
}

# delayed_read_request: wait a while and then send a read request. If a read
# request is sent too soon, the EIB actuator may not have obtained a stable value, so we want
# to delay before sending the request.
sub delayed_read_request {
    my ($self, $interval) = @_;

    $interval = 2 unless defined $interval;
    $self->{read_timeouts} = -1; # ugly...
    $self->start_read_timer($interval);
}

# EIB1_Item: switch items (on/off)
package EIB1_Item;

@EIB1_Item::ISA = ('EIB_Item');

sub new {
    my ($class, $id, $mode) = @_;

    my $self  = $class->SUPER::new($id, $mode);
    $self->add($id . 'on', 'on');
    $self->add($id . 'off', 'off');
    return $self;
}

sub eis_type {
    return '1';
}

# decode: translate EIS 1 data to state (on/off)
sub decode {
    my ($self, @data) = @_;
    unless ($#data == 0) {
	&main::print_log("Not EIS type 1 data received for $self->{groupaddr}: \[@data\]") if $main::config_parms{eib_errata} >= 2;
	return;
    }
    if ($data[0] == 0) {
	return 'off';
    }
    else {
	return 'on';
    }
}

# encode: translate state to EIS 1 data
sub encode {
    my ($self, $state) = @_;

    if ($state eq 'on') {
	return ([1]);
    }
    elsif ($state eq 'off') {
	return ([0]);
    }
    else {
	print "Invalid state for EIS type 1: \'$state\'\n";
	return;
    }
}

# EIB1G_Item: a group of EIB1 items. Setting the value of an  EIB1 group will affect all members in the
# group.
# The class is used to keep track of EIB1 group memberships. If a write message is detected, all members
# will be updated.
package EIB1G_Item;

@EIB1G_Item::ISA = ('EIB1_Item');

sub new {
    my ($class, $id, $groupstr) = @_;
    my @groups = split /\|/, $groupstr;

    my $self  = $class->SUPER::new($id);
    $self->{'linked_groups'} = \@groups;
    return $self;
}

sub eis_type {
    return '1';
}

sub set_receive {
    my ($self, $state, $set_by, $target) = @_;

    $self->SUPER::set_receive($state, $set_by, $target);
    map { my $ei = EIB_Item::eib_item_by_id($_);
	  $ei->set_receive($state, $set_by, $target);
      } @{$self->{'linked_groups'}};
}

# EIS 2: Dimming
# EIB dimmers can be controlled in three different ways:
# 1. "control": brighten, dim, stop. Handled by class EIB21_Item
# 2. "value": numerical value: Handled by class EIB6_Item
# 3. "position": on, off. Handled by class EIB1_Item
#
# Class EIB2_Item is a meta-item to represent dimmers, consist of the three underlying item.
# The main purpose is to make a dimmer appear as a single item, while the real work is done
# by the three underlying items.
#
# The identifier for the EIB2_Item is composed of the concatenation of the addresses of
# the three underlying items, with '|' between them. For example, '1/0/90|1/0/91|1/4/1' is a dimmer
# with control address 1/0/90, value address 1/0/91, and position address 1/4/1.
#

package EIB2_Item;

@EIB2_Item::ISA = ('EIB_Item');

# new: create an EIB2_Item. Instantiate the three underlying items.
sub new {
    my ($class, $id) = @_;
    my @groups;
    my ($subid, $item);

    my $self  = $class->SUPER::new($id);

    @groups = split(/\|/, $id);
    print "Three group addresses required for dimmer. Found $#groups in $id\n" if ($#groups != 2);

    $subid = $groups[0];
    $self->{Position} = $subid;
    $item = new EIB23_Item($subid, "R", $id);
    $item->add($subid . 'on', 'on');
    $item->add($subid . 'off', 'off');
    $self->add($id . 'on', 'on');
    $self->add($id . 'off', 'off');

    $subid = $groups[1];
    $self->{Control} = $subid;
    $item = new EIB21_Item($subid, "", $id);
    $item->add($subid . 'brighten', 'brighten');
    $item->add($subid . 'dim', 'dim');
    $item->add($subid . 'stop', 'stop');
    $self->add($id . 'brighten', 'brighten');
    $self->add($id . 'dim', 'dim');
    $self->add($id . 'stop', 'stop');

    $subid = $groups[2];
    $self->{Value} = $subid;
    $item = new EIB22_Item($subid, "R", $id);

     return $self;
}

sub eis_type {
    return '2';
}

# position: return "position" sub-item
sub position {
    my ($self) = @_;
    my $subitem;

    return unless defined $self->{Position};
    return $eib_item_by_id{$self->{Position}};
}

# control: return "control" sub-item
sub control {
    my ($self) = @_;
    my $subitem;

    return unless defined $self->{Control};
    return $eib_item_by_id{$self->{Control}};
			}
# value: return "value" sub-item
sub value {
    my ($self) = @_;
    my $subitem;

    return unless defined $self->{Value};
    return $eib_item_by_id{$self->{Value}};
 }

# Set EIB2 item.
# Parse state to determine the corresponding sub-item to call.

sub set {
    my ($self, $state, $set_by, $target) = @_;
    my $subitem;

    my $ret = $self->SUPER::set($state, $set_by, $target);
    return 0 unless $ret;

    if ($state eq 'toggle' ||
	$state eq 'on' ||
	$state eq 'off') {
	$subitem = $self->position();
    }
    elsif ($state =~ /^(stop|brighten|dim)$/) {
	$subitem = $self->control();
    }
    elsif ($state =~ /^\d+$/ ||
	   $state =~ /^(\+|\-)\d+$/ ||
	   $state =~ /^\d+\%$/) {
	$subitem = $self->value();
    }
    else {
	&main::print_log(" $self->{object_name}: Bad EIB dimmer state \'$state\'\n");
    }

    $subitem->set($state, $set_by, $target) if (defined $subitem);
    return 1;
}

# set_receive: received an event from one of the sub_items. If it
# was a numerical value ("Value"), update the "Position" subitem to
# 'on' or 'off'.  If the value was zero, also set self to 'off'.
# Update level (0-100) to represent dimmer position

sub set_receive {
    my ($self, $state, $set_by, $target) = @_;
    my $onoff;

    if ($state =~ /(\d+)/) {
	$self->{level} = $1;
	if ($1 eq '0') {
	    $onoff = 'off';
	}
	else {
	    $onoff = 'on';
	}
	$self->SUPER::set_receive($onoff, $set_by, $target);
	my $pos = $self->position();
	if (defined $pos && $pos->state_final() ne $onoff) {
	    $pos->set_receive($onoff, $set_by, $target);
	}
    }
    elsif ($state eq 'on' || $state eq 'off') {
	$self->SUPER::set_receive($state, $set_by, $target);
	if ($state eq 'off') {
	    $self->{level} = 0;
	    my $val = $self->value();
	    if (defined $val && $val->state_final() != 0) {
		$val->set_receive(0, $set_by, $target);
	    }
	}
    }
    if ($state eq 'on') {
	my $value = value $self;
	delayed_read_request $value if (defined $value);
    }
}

# state_level: return 'on', 'off' or 'dim', depending on current setting
# (as obtained from "value" sub-item)
sub state_level {
    my ($self) = @_;

    my $state = $self->{state};
    my $level = $self->value()->{state};
    if (!defined $state or !($state eq 'on' or $state eq 'off')) {
        if (defined $level and $level =~ /^[\+\-\d\%]+$/) {
            $state = 'dim';
            $state = 'off' if $level ==   0;
            $state = 'on'  if $level == 100;
        }
        elsif ($state =~ /^[\+\-\d\%]+$/ or $state eq 'dim' or $state eq 'brighten') {
            $state = 'dim';
        }
        else {
            $state = ''; # unknown
        }
    }
    elsif ($state eq 'on' and defined $level and $level < 100) {
        $state = 'dim';
    }
    return $state;
}

# EIS 2 subitem: generic class for the three dimming sub-functions

package EIB2_Subitem;

@EIB2_Subitem::ISA = ('EIB_Item');

sub new {
    my ($class, $id, $mode, $dimmerid) = @_;
    my @args;

    my $self  = $class->SUPER::new($id, $mode);
    $self->{'Dimmer'} = $dimmerid;
    return $self;
}

# dimmer: return "dimmer" meta-item
sub dimmer {
    my ($self) = @_;
    my $subitem;

    return unless defined $self->{Dimmer};
    return $eib_item_by_id{$self->{Dimmer}};
 }

# set_receive: forward to meta-item
sub set_receive {
    my ($self, $state, $set_by, $target) = @_;

    $self->SUPER::set_receive($state, $set_by, $target);
    my $dimmer = dimmer $self;
    if (defined $dimmer) {
	$dimmer->set_receive($state, $set_by, $target);
    }
    else {
	&main::print_log("No dimmer defined for dimmer subitem $self->{groupaddr}");
    }
}

# EIS 21: Dimming sub-function "control"

package EIB21_Item;

@EIB21_Item::ISA = ('EIB2_Subitem');

sub eis_type {
    return '2.1';
}

# dimmer_timeout: dimmer should have reached stable state. Issue a read request to obtain
# current value
sub dimmer_timeout {
    my ($self) = @_;
    my $value;

    $value = $self->dimmer()->value();
    $value->send_read_msg();
}


# set
#
# To allow adjusting dimmer value in real-time from for example web interface:
# If state is set to same dim/brighten value twice before dimmer timer has expired,
# it means "stop"
# for example, first 'dim' means start dimming, second means stop dimming
# (This behaviour is configurable via configuration parameter "eib_dim_stop_on_repeat")
sub set {
    my ($self, $state, $set_by, $target) = @_;
    my $subitem;

    if ($::config_parms{eib_dim_stop_on_repeat} &&  defined $self->{dimmer_timer}) {
	if (($state eq 'brighten' && $self->{state} eq 'brighten') ||
	    ($state eq 'dim' && $self->{state} eq 'dim')) {
	    $state = 'stop';
	}
    }
    return $self->SUPER::set($state, $set_by, $target);
}

sub decode {
    my ($self, @data) = @_;
    unless ($#data == 0) {
	&main::print_log("Not EIS type 21 data received for $self->{groupaddr}: \[@data\]") if $main::config_parms{eib_errata} >= 2;
	return;
    }
    if (($data[0] & 0x7) == 0) {
	return 'stop';
    }
    elsif (($data[0] & 0x8) == 0) {
	return 'dim';
    }
    else {
	return 'brighten';
    }
}

sub encode {
    my ($self, $state) = @_;

    if ($state eq 'stop') {
	return ([0]);
    }
    elsif ($state eq 'dim') {
	return ([1]);
    }
    elsif ($state eq 'brighten') {
	return ([9]);
    }
    else {
	print "Invalid state for EIS type 2.1: \'$state\'\n";
	return;
    }
}

# set_receive: if it is a 'stop' event, generate a read request
# for the 'Value' sub-item, to learn the actual dimmer setting
sub set_receive {
    my ($self, $state, $set_by, $target) = @_;
    my ($dimmer, $value);

    $self->SUPER::set_receive($state, $set_by, $target);
    if ($state eq 'stop') {
	$dimmer = dimmer $self;
	$value = value $dimmer	if (defined $dimmer);
	if (defined $value) {
	    delayed_read_request $value;
	}
	else {
	    &main::print_log("No dimmer value subitem for dimmer control $self->{groupaddr}");
	}
	$self->{dimmer_timer}->unset() if defined $self->{dimmer_timer};
    }
    elsif ($state eq 'dim' || $state eq 'brighten') {
# let some time pass and then issue a read request, to find out the final dimmer level.
# The time is configurable via configuration parameter "eib_dimmmer_time".

	$self->{dimmer_timer} = new Timer unless defined $self->{dimmer_timer};
	if ($self->{dimmer_timer}->inactive()) {
	    my $interval = 0 + $::config_parms{eib_dimmer_timer};
	    $self->{dimmer_timer}->set($interval, sub {EIB21_Item::dimmer_timeout($self);}, 1);
	}
   }
}

# EIS 2.2: Dimming sub-function "value". Set dimmer to a given brightness level
# (0-100) with 8 bit resolution
# Values are coded according to EIS 6

package EIB22_Item;

# Multiple inheritance -- use encode/decode methods from EIB6_Item,
# the rest from EIB2_Subitem
@EIB22_Item::ISA = ('EIB2_Subitem', 'EIB6_Item'); # order is important!

sub eis_type {
    return '2.2';
}

# set receive -- detected a "read" or "write" message on the bus.  For
# readable actuators, don't trust the values in "write" messages, as
# they may not have been accepted by the actuator. So if it is a
# write, and the actuator is readable, generate a read request to
# obtain the actual value from the actuator

sub set_receive {
    my ($self, $state, $set_by, $target, $read) = @_;

    if (!$read && $self->{readable}) {
	$self->delayed_read_request();
    }
    else {
	$self->SUPER::set_receive($state, $set_by, $target);
    }
}


# EIS 2.3: Dimming sub-function "position". Set dimmer to on/off.
# Values are coded according to EIS 1

package EIB23_Item;

# Multiple inheritance -- use encode/decode methods from EIB1_Item, and the rest from
# EIB2_Subitem
@EIB23_Item::ISA = ('EIB2_Subitem', 'EIB1_Item'); # order is important!

sub eis_type {
    return '2.3';
}

# EIB3_Item:  Uhrzeit

package EIB3_Item;

@EIB3_Item::ISA = ('EIB_Item');

my @DoW = qw(Sun Mon Tue Wed Thu Fri Sat Sun);

sub eis_type {
  return '3';
}

sub decode {
  my ($self, @data) = @_;
  my $res;

  unless ($#data == 3) {
    &main::print_log("Not EIS type 3 data received for $self->{groupaddr}: \[@data\]") if $main::config_parms{eib_errata} >= 3;
    return;
  }
  my $weekday = ($data[1] & 0xE0) >> 5;
  my $hour    = $data[1] & 0x1F;
  my $minute  = $data[2] & 0xFF;
  my $second  = $data[3] & 0xFF;

  $res = sprintf("%s, %02i:%02i:%02i",$DoW[$weekday],$hour,$minute,$second);
  &main::print_log("EIS3 for $self->{groupaddr}: >$res<") if $main::config_parms{eib_errata} >= 3;
  return $res;
}

sub encode {
  my ($self, $state) = @_;
  my $time = &main::my_str2time($state);
  my ($sec, $min, $hour, $mday, $mon, $year, $wday) = localtime($time);
  my $res1 = sprintf("%s, %02i:%02i:%02i",$DoW[$wday],$hour,$min,$sec);
  my @res = (0);

  if ($wday == 0) { $wday = 7; }

  push (@res, $wday << 5 | $hour);
  push (@res, $min );
  push (@res, $sec );

  my $res = '[' . join(" ",@res) . ']';
  
  &main::print_log("EIS3 for $self->{groupaddr}: >$res< >$res1<") if $main::config_parms{eib_errata} >= 3;
  return \@res;

}

# EIB4_Item:  Uhrzeit

package EIB4_Item;

@EIB4_Item::ISA = ('EIB_Item');

my @DoW = qw(Sun Mon Tue Wed Thu Fri Sat Sun);

sub eis_type {
  return '3';
}

sub decode {
  my ($self, @data) = @_;
  my $res;

  unless ($#data == 3) {
    &main::print_log("Not EIS type 4 data received for $self->{groupaddr}: \[@data\]") if $main::config_parms{eib_errata} >= 3;
    return;
  }
  my $mday    = $data[1] & 0x1F;
  my $mon     = $data[2] & 0x0F;
  my $year    = $data[3] & 0x7F;

  $res = sprintf("%02i/%02i/%02i",$mon,$mday,($year+2000) % 100);
  &main::print_log("EIS4 for $self->{groupaddr}: >$res<") if $main::config_parms{eib_errata} >= 2;
  return $res;
}

sub encode {
  my ($self, $state) = @_;
  my $time = &main::my_str2time($state);
  my ($sec, $min, $hour, $mday, $mon, $year, $wday) = localtime($time);
  my $res1 = sprintf("%02i/%02i/%02i",$mon + 1,$mday,$year % 100 );
  my @res = (0);

  push (@res, $mday);
  push (@res, $mon + 1);
  push (@res, $year - 100);

  my $res = '[' . join(" ",@res) . ']';
  
  &main::print_log("EIS4 for $self->{groupaddr}: >$res< >$res1<") if $main::config_parms{eib_errata} >= 3;
  return \@res;

}

# EIS 5: Value
# Represents real values
package EIB5_Item;

@EIB5_Item::ISA = ('EIB_Item');

sub eis_type {
    return '5';
}

sub decode {
    my ($self, @data) = @_;
    my $res;

    unless ($#data == 2) {
	&main::print_log("Not EIS type 5 data received for $self->{groupaddr}: \[@data\]") if $main::config_parms{eib_errata} >= 2;
	return;
    }
    my $sign = $data[1] & 0x80;
    my $exp = ($data[1] & 0x78) >> 3;
    my $mant = (($data[1] & 0x7) << 8) | $data[2];

    $mant = -(~($mant - 1) & 0x7ff) if $sign != 0;
    $res = (1 << $exp) * 0.01 * $mant;
    return $res;
}

sub encode {
    my ($self, $state) = @_;
    my $data;

    my $sign = ($state <0 ? 0x8000 : 0);
    my $exp  = 0;
    my $mant = 0;

    $mant = int($state * 100.0);
    while (abs($mant) > 2047) {
        $mant = $mant >> 1;
        $exp++;
    }

    $data = $sign | ($exp << 11) | ($mant & 0x07ff);

    return([0, $data >> 8, $data & 0xff]);
}

# EIB6_Item: "scaling". Relative values 0-100% with 8 bit resolution

package EIB6_Item;

@EIB6_Item::ISA = ('EIB_Item');

sub eis_type {
    return '6';
}

sub decode {
    my ($self, @data) = @_;
    my $res;

    unless ($#data == 1) {
	&main::print_log("Not EIS type 6 data received for $self->{groupaddr}: \[@data\]") if $main::config_parms{eib_errata} >= 2;
	return;
    }
    $res = sprintf("%.0f", $data[1] * 100 / 255);
    return $res;
}

sub encode {
    my ($self, $state) = @_;
    my $newval;
    if ($state =~ /^(\d+)$/) {
	$newval = $1;
    }
    elsif ($state =~ /^\+(\d+)$/) {
	$newval = $self->{state} + $1;
	$newval = 100 if ($newval > 100);
    }
    elsif ($state =~ /^\-(\d+)$/) {
	if ($self->{state} < $1) {
	    $newval = 0;
	}
	else {
	    $newval = $self->{state} - $1;
	}
    }
    elsif ($state =~ /^(\d+)\%$/) {
	$newval = $1;
    }
    else {
	print "Invalid state for EIS type 6: \'$state\'\n";
	return;
    }
    my $byte = sprintf ("%.0f", $newval * 255 / 100);
    return([0, int $byte]);
}


# set receive -- detected a "read" or "write" message on the bus.  For
# readable actuators, don't trust the values in "write" messages, as
# they may not have been accepted by the actuator. So if it is a
# write, and the actuator is readable, generate a read request to
# obtain the actual value from the actuator

sub set_receive {
    my ($self, $state, $set_by, $target, $read) = @_;

    if (!$read && $self->{readable}) {
	$self->delayed_read_request();
    }
    else {
	$self->SUPER::set_receive($state, $set_by, $target);
    }
}

# EIS 7: Drive control
# Blinds, windows, etc
# Drives can be controlled in two different ways:
# 1. "move": up/down
# 2. "stop": stop/step movement
#
# NB EIS7 objects may not be read, since this can cause drive movements
#

package EIB7_Item;

@EIB7_Item::ISA = ('EIB_Item');

sub new {
    my ($class, $id, $opmode) = @_;
    my @groups;
    my ($subid, $item);

    my $self  = $class->SUPER::new($id);

    @groups = split(/\|/, $id);
    if ($#groups != 1) {
	print "Bad EIS 7 drive group addresses \'$id\'";
	return;
    }

    if (not defined $opmode) {
	$self->{OperatingMode} = 'shutter';
    } else {
	$self->{OperatingMode} = $opmode;
    }

    $subid = $groups[0];
    $self->{Move} = $subid;
    $item = new EIB71_Item($subid, "", $id);
    $item->add($subid . 'up', 'up');
    $item->add($subid . 'down', 'down');
    $self->add($id . 'up', 'up');
    $self->add($id . 'down', 'down');

    if ($self->{OperatingMode} eq 'shutter') {
        $subid = $groups[1];
        $self->{Stop} = $subid;
        $item = new EIB72_Item($subid, "", $id);
        $item->add($subid . 'stop', 'stop');
        $self->add($id . 'stop', 'stop');
    } elsif ($self->{OperatingMode} eq 'blind') {
        $subid = $groups[1];
        $self->{Step} = $subid;
        $item = new EIB73_Item($subid, "", $id);
        $item->add($subid . 'step-up', 'step-up');
        $item->add($subid . 'step-down', 'step-down');
        $self->add($id . 'step-up', 'step-up');
        $self->add($id . 'step-down', 'step-down');
    } else {
	print "Bad EIS 7 operating mode \'$self->{OperatingMode}\'";
	return;
    }

    return $self;
}

sub eis_type {
    return '7';
}

# set EIB drive item. Parse state to determine the corresponding
# sub-item to call.
# Don't modify own state here -- that will be done later,
# when/if the sub-items call set_receive for this item.

sub set {
    my ($self, $state, $set_by, $target) = @_;
    my $subitem;

    return unless $self->SUPER::set($state, $set_by, $target);

    if ($state eq 'up' || $state eq 'down') {
	$subitem = $self->{Move};
    }
    elsif ($state eq 'stop') {
	$subitem = $self->{Stop};
    }
    elsif ($state eq 'step-up' || $state eq 'step-down') {
	$subitem = $self->{Step};
    }
    else {
	&main::print_log(" $self->{object_name}: Bad EIB drive state \'$state\'\n");
	return;
    }
    if (my $ref = $eib_item_by_id{$subitem}) {
	$ref->set($state, $set_by, $target);
    }
    else {
	&main::print_log("$self->{object_name}: No subitem for EIB drive state \'$state\'\n");
    }
    return 1;
}

# EIS 7 subitem: generic class for drive sub-functions

package EIB7_Subitem;

@EIB7_Subitem::ISA = ('EIB_Item');

# Instantiated with last args "driveid": the id of EIS7 item to which this
# subitem belongs

sub new {
    my ($class, $id, $mode, $driveid) = @_;
    my @args;

    my $self  = $class->SUPER::new($id, $mode);
    $self->{Drive} = $driveid;
    return $self;
}

# set_receive: forward to main Drive item (EIS7 item)
sub set_receive {
    my ($self, $state, $set_by, $target) = @_;

    $self->SUPER::set_receive($state, $set_by, $target);
    if (defined $self->{Drive}) {
	if (my $drive = $eib_item_by_id{$self->{Drive}}) {
	    $drive->set_receive($state, $set_by, $target);
	}
    }
}

# EIS 71: Dimming sub-function "move"

package EIB71_Item;

@EIB71_Item::ISA = ('EIB7_Subitem');

sub eis_type {
    return '7.1';
}

sub decode {
    my ($self, @data) = @_;
    unless ($#data == 0) {
	&main::print_log("Not EIS type 71 data received for $self->{groupaddr}: \[@data\]") if $main::config_parms{eib_errata} >= 2;
	return;
    }
    if ($data[0] == 0) {
	return 'up';
    }
    else {
	return 'down';
    }
}

sub encode {
    my ($self, $state) = @_;

    if ($state eq 'up') {
	return ([0]);
    }
    elsif ($state eq 'down') {
	return ([1]);
    }
    else {
	print "Invalid state for EIS type 7.1: \'$state\'\n";
	return;
    }
}

# EIS 72: Drive sub-function "stop"

package EIB72_Item;

@EIB72_Item::ISA = ('EIB7_Subitem');


sub eis_type {
    return '7.2';
}

sub decode {
    my ($self, @data) = @_;
    unless ($#data == 0) {
	&main::print_log("Not EIS type 72 data received for $self->{groupaddr}: \[@data\]") if $main::config_parms{eib_errata} >= 2;
	return;
    }
    return 'stop';
}

sub encode {
    my ($self, $state) = @_;

    return ([0]);
}

# EIS 73: Drive sub-function "step-up/step-down"

package EIB73_Item;

@EIB73_Item::ISA = ('EIB7_Subitem');


sub eis_type {
    return '7.3';
}

sub decode {
    my ($self, @data) = @_;
    unless ($#data == 0) {
	&main::print_log("Not EIS type 73 data received for $self->{groupaddr}: \[@data\]") if $main::config_parms{eib_errata} >= 2;
	return;
    }
    if ($data[0] == 0) {
        return 'step-up';
    } else {
        return 'step-down';
    }
}

sub encode {
    my ($self, $state) = @_;

    if ($state eq 'step-up') {
        return ([0]);
    } elsif ($state eq 'step-down') {
        return ([1]);
    } else {
        print "Invalid state for EIS type 7.3: \'$state\'\n";
        return;
    }
}

# EIB9_Item: 32-bit float

package EIB9_Item;

@EIB9_Item::ISA = ('EIB_Item');

sub eis_type {
    return '9';
}

sub decode {
    my ($self, @data) = @_;
    my $res;

    unless ($#data == 4) {
        &main::print_log("Not EIS type 9 data received for $self->{groupaddr}: \[@data\]") if $main::config_parms{eib_errata} >= 2;
        return;
    }
    my $res = unpack "f", pack "L", (($data[1] << 24 ) | ($data[2] << 16 ) | ($data[3] << 8 ) | $data[4]);
    
#    &main::print_log("EIS9 for $self->{groupaddr}: >$res<");
    return $res;
}

sub encode {
    my ($self, $state) = @_;
    my $res;
    $res = unpack "L", pack "f", $state;
    #&main::print_log("Res: $res State: $state \n");
    return([0, ($res & 0xff000000) >> 24, ($res & 0xff0000) >> 16, ($res & 0xff00) >> 8, $res & 0xff]);
}

# EIB10_Item: 16-bit unsigned integer
package EIB10_Item;

@EIB10_Item::ISA = ('EIB_Item');

sub eis_type {
    return '10';
}

sub decode {
    my ($self, @data) = @_;
    my $res;

    unless ($#data == 2) {
        &main::print_log("Not EIS type 10 data received for $self->{groupaddr}: \[@data\]") if $main::config_parms{eib_errata} >= 2;
        return;
    }
    my $res = ($data[1] << 8) | $data[2];

#    &main::print_log("EIS10 for $self->{groupaddr}: >$res<");
    return $res;
}

sub encode {
    my ($self, $state) = @_;

    return([0, ($state & 0xff00) >> 8, $state & 0xff]);
}

# EIB11_Item: 32-bit unsigned integer

package EIB11_Item;

@EIB11_Item::ISA = ('EIB_Item');

sub eis_type {
    return '11';
}

sub decode {
    my ($self, @data) = @_;
    my $res;

    unless ($#data == 4) {
	&main::print_log("Not EIS type 11 data received for $self->{groupaddr}: \[@data\]") if $main::config_parms{eib_errata} >= 2;
	return;
    }
    my $res = ($data[1] << 24 ) | ($data[2] << 16 ) | ($data[3] << 8 ) | $data[4];

#    &main::print_log("EIS11 for $self->{groupaddr}: >$res<");
    return $res;
}

sub encode {
    my ($self, $state) = @_;

    return([0, ($state & 0xff000000) >> 24, ($state & 0xff0000) >> 16, ($state & 0xff00) >> 8, $state & 0xff]);
}

# EIB11S_Item: 32-bit _S_IGNED integer

package EIB11S_Item;

@EIB11S_Item::ISA = ('EIB_Item');

sub eis_type {
    return '11';
}

sub decode {
    my ($self, @data) = @_;
    my $res;

    unless ($#data == 4) {
        &main::print_log("Not EIS type 11 data received for $self->{groupaddr}: \[@data\]") if $main::config_parms{eib_errata} >= 2;
        return;
    }
    my $res = ($data[1] << 24 ) | ($data[2] << 16 ) | ($data[3] << 8 ) | $data[4];
    
#    &main::print_log("EIS11 for $self->{groupaddr}: >$res<");
    if ($data[1] < 128) { 
        return $res;
        }
    else{
        return (0-(0xFFFFFFFF-$res+1));
    }
}

sub encode {
    my ($self, $state) = @_;
    my $res;
    if (int($state) < 0) {
        $res = ($state + 0xFFFFFFFF +1);
        }
    else {
        $res = $state;
        }
    #&main::print_log("Res: $res State: $state \n");
    return([0, ($res & 0xff000000) >> 24, ($res & 0xff0000) >> 16, ($res & 0xff00) >> 8, $res & 0xff]);
}

# EIB15_Item: 14-Byte Text Message

package EIB15_Item;

@EIB15_Item::ISA = ('EIB_Item');

sub eis_type {
    return '15';
}

sub decode {
    my ($self, @data) = @_;
    my $res;

    unless ($#data == 14) {
	&main::print_log("Not EIS type 15 data received for $self->{groupaddr}: \[@data\]") if $main::config_parms{eib_errata} >= 2;
	return;
    }
    $res = pack ("xC*", @data);
    &main::print_log("EIS15 for $self->{groupaddr}: >$res<");
    return $res;
}

sub encode {
    my ($self, $state) = @_;
    my $newstate;
    $newstate = sprintf ("%-14.14s", $state);
    my @res = (0);
    push (@res, unpack ("C*", $newstate));
    return \@res;
}


package EIBW_Item;

@EIBW_Item::ISA = ('EIB_Item');

# new: create an EIBW_Item. Instantiate the three underlying items.
sub new {
    my ($class, $id) = @_;
    my @groups;
    my ($subid, $item);

    my $self  = $class->SUPER::new($id);

    @groups = split(/\|/, $id);
    print "Two group addresses required for window. Found $#groups in $id\n" if ($#groups != 1);

    $subid = $groups[0];
    $item = new EIBW1_Item($subid, "R", $id);
    $item->add($subid . 'on', 'on');
    $item->add($subid . 'off', 'off');

    $self->{Top} = $subid;

    if ($groups[0] ne $groups[1]) {
      $subid = $groups[1];
      $item = new EIBW1_Item($subid, "", $id);
      $item->add($subid . 'on', 'on');
      $item->add($subid . 'off', 'off');
    }

    $self->{Bottom} = $subid;
    
    $self->add($id . 'open', 'open');
    $self->add($id . 'tilt', 'tilt');
    $self->add($id . 'close', 'close');

    return $self;
}

sub eis_type {
    return 'w';
}

# position: return "position" sub-item
sub top {
    my ($self) = @_;
    my $subitem;

    return unless defined $self->{Top};
    return $eib_item_by_id{$self->{Top}};
}

# control: return "control" sub-item
sub bottom {
    my ($self) = @_;
    my $subitem;

    return unless defined $self->{Bottom};
    return $eib_item_by_id{$self->{Bottom}};
}

# set_receive: received an event from one of the sub_items.

sub set_receive {
    my ($self, $state, $set_by, $target) = @_;

    my $top    = $self->top()->state_final();
    my $bottom = $self->bottom()->state_final();

    $state = "closed";
    $state = "tilt"  if ($top eq "on" && $bottom eq "off");
    $state = "open" if ($top eq "on" && $bottom eq "on");

    #&main::print_log("################### t:$top b:$bottom w:$state ");

    $self->SUPER::set_receive($state, $set_by, $target);
}

# EIS 2 subitem: generic class for the three dimming sub-functions

package EIBW_Subitem;

@EIBW_Subitem::ISA = ('EIB_Item');

sub new {
    my ($class, $id, $mode, $windowid) = @_;
    my @args;

    my $self  = $class->SUPER::new($id, $mode);
    $self->{'Window'} = $windowid;
    return $self;
}

sub window {
    my ($self) = @_;
    my $subitem;

    return unless defined $self->{Window};
    return $eib_item_by_id{$self->{Window}};
 }

# set_receive: forward to meta-item
sub set_receive {
    my ($self, $state, $set_by, $target) = @_;

    $self->SUPER::set_receive($state, $set_by, $target);
    my $window = window $self;
    if (defined $window) {
	$window->set_receive($state, $set_by, $target);
    }
    else {
	&main::print_log("No window defined for window subitem $self->{groupaddr}");
    }
}

package EIBW1_Item;

# Multiple inheritance -- use encode/decode methods from EIB1_Item, and the rest from
# EIBW_Subitem
@EIBW1_Item::ISA = ('EIBW_Subitem', 'EIB1_Item'); # order is important!

sub eis_type {
    return 'w.3';
}

