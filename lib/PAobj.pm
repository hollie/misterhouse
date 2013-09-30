=head1 B<PAobj>

=head2 SYNOPSIS

Example initialization:

  use PAobj;

Enable pa_control.pl using "Common code activation" in the IA5 interface
to activate an instance of this PA code.

=head2 DESCRIPTION

Centralized control of various PA zone types.

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

my (%pa_weeder_max_port,%pa_zone_types,%pa_zone_type_by_zone);

package PAobj;

@PAobj::ISA = ('Generic_Item');

sub last_char
{
    my ($self,$string) = @_;
    my @chars=split(//, $string);
    return((sort @chars)[-1]);
}

sub new
{
    my ($class) = @_;
    my $self={};

    bless $self,$class;

    $$self{pa_delay} = 0.5;

    return $self;
}

sub init {
    my ($self) = @_;
    %pa_zone_types=();
    my $ref2 = &::get_object_by_name("pa_allspeakers");
    if (!$ref2) {
        &::print_log("\n\nWARNING! PA Zones were not found! Your *.mht file probably doesn't list the PA zones correctly.\n\n");
        return 0;
    }
    $self->check_group('default');

    my @speakers = $self->get_speakers('allspeakers');
    my (@speakers_wdio,@speakers_x10,@speakers_obj,@speakers_xap,@speakers_xpl);

    for my $room (@speakers) {
        my $ref = &::get_object_by_name("pa_$room");
        my $type = $ref->get_type();
        print "PAObj: init: room=$room\n";
        print "PAObj: init: room=$room, zonetype=$type\n";
        $pa_zone_types{$type}++ unless $pa_zone_types{$type};
        
        if($type eq 'wdio') {
            push(@speakers_wdio,$room);
        }
        if($type eq 'x10') {
            push(@speakers_x10,$room);
        }
        if($type eq 'xap') {
            push(@speakers_xap,$room);
        }
        if($type eq 'xpl') {
            push(@speakers_xpl,$room);
        }
        if($type eq 'object') {
            push(@speakers_obj,$room);
        }
    }
    
    print "PAObj: speakers_wdio: $#speakers_wdio\n" if $main::Debug{pa};
    print "PAObj: speakers_x10: $#speakers_x10\n" if $main::Debug{pa};
    print "PAObj: speakers_xap: $#speakers_xap\n" if $main::Debug{pa};
    print "PAObj: speakers_xpl: $#speakers_xpl\n" if $main::Debug{pa};
    print "PAObj: speakers_obj: $#speakers_obj\n" if $main::Debug{pa};

    if ($#speakers_wdio > -1) {
        $self->init_weeder(@speakers_wdio);
        return 0 unless %pa_weeder_max_port;
    }
    if ($pa_zone_types{'x10'}) {
        print "PAObj: x10 PA type initialized...\n" if $main::Debug{pa};
    }
    if ($pa_zone_types{'xap'}) {
        print "PAObj: xAP PA type initialized...\n" if $main::Debug{pa};
    }
    if ($pa_zone_types{'xpl'}) {
        print "PAObj: xPL PA type initialized...\n" if $main::Debug{pa};
    }
    return 1;
}

sub init_weeder
{
    my ($self,@speakers) = @_;
    my (%weeder_ref,%weeder_max);
    undef %pa_weeder_max_port;
    for my $room (@speakers) {
        print "PAObj: init PA Room loaded: $room\n" if $main::Debug{pa};
        my $ref = &::get_object_by_name('pa_' . $room . '_obj');
        $ref->{state} = 'off';
        my ($card,$id);
        ($card,$id) = $ref->{id_by_state}{'on'} =~ /^D?(.)H(.)/s;

        $weeder_ref{$card} = '' unless $weeder_ref{$card};
        $weeder_ref{$card} .= $id;
        print "PAObj: init card: $card, id: $id, Room: $room, List: $weeder_ref{$card}\n" if $main::Debug{pa};
    }

    for my $card ('A' .. 'P','a' .. 'p') {
        if ($weeder_ref{$card}) {
            my $data = $weeder_ref{$card};
            $weeder_max{$card}=$self->last_char($data);
            print "\nPAObj: init weeder board=$card, ports=$data, max port=" . $weeder_max{$card} . "\n" if $main::Debug{pa};
        }
    }
    %pa_weeder_max_port = %weeder_max;
}

sub set
{
    my ($self,$rooms,$state,$mode,%voiceparms) = @_;
    my $results = 0;
    print "PAObj: delay: $$self{pa_delay}\n" if $main::Debug{pa};
    print "PAObj: set,mode: " . $mode . "\n" if $main::Debug{pa};
    print "PAObj: set,rooms: " . $rooms . "\n" if $main::Debug{pa};

    my @speakers = $self->get_speakers($rooms);
    @speakers = $self->get_speakers('') if $#speakers == -1;
    @speakers = $self->get_speakers_speakable($mode,@speakers);

    my (@speakers_wdio,@speakers_x10,@speakers_obj,@speakers_xap,@speakers_xpl);

    for my $room (@speakers) {
        my $ref = &::get_object_by_name("pa_$room");
        my $type = lc $ref->get_type();
        if($type eq 'wdio' || $type eq 'wdio_old') {
            print "PAObj: speakers_wdio: Adding $room\n" if $main::Debug{pa};
            push(@speakers_wdio,$room);
        }
        if($type eq 'x10') {
            print "PAObj: speakers_x10: Adding $room\n" if $main::Debug{pa};
            push(@speakers_x10,$room);
        }
        if($type eq 'xap') {
            print "PAObj: speakers_xap: Adding $room\n" if $main::Debug{pa};
            push(@speakers_xap,$room) if $state eq 'on'; #Only need to send if speech is starting
        }
        if($type eq 'xpl') {
            print "PAObj: speakers_xpl: Adding $room\n" if $main::Debug{pa};
            push(@speakers_xpl,$room) if $state eq 'on'; #Only need to send if speech is starting
        }
        if($type eq 'object') {
            print "PAObj: speakers_object: Adding $room\n" if $main::Debug{pa};
            push(@speakers_obj,$room);
        }
    }
    
    print "PAObj: speakers_wdio: $#speakers_wdio\n" if $main::Debug{pa};
    print "PAObj: speakers_x10: $#speakers_x10\n" if $main::Debug{pa};
    print "PAObj: speakers_xap: $#speakers_xap\n" if $main::Debug{pa};
    print "PAObj: speakers_xpl: $#speakers_xpl\n" if $main::Debug{pa};
    print "PAObj: speakers_obj: $#speakers_obj\n" if $main::Debug{pa};
    
    #TODO: Properly handle $results across multiple types
    #TODO: Break up the wdio zones based on serial port, in case there are more than one.
    $results = $self->set_weeder($state,'weeder',@speakers_wdio) 			if $#speakers_wdio > -1;
    $results = $self->set_x10($state,@speakers_x10) 			if $#speakers_x10 > -1;
    $results = $self->set_xap($state,\@speakers_xap,\%voiceparms) 	if $#speakers_xap > -1;	
    $results = $self->set_xpl($state,\@speakers_xpl,\%voiceparms) 	if $#speakers_xpl > -1;
    $results = $self->set_obj($state,@speakers_obj) 			if $#speakers_obj > -1;

    select undef, undef, undef, $$self{pa_delay} if $results;

    return $results;
}

sub set_obj
{
    my ($self,$state,@speakers) = @_;
    for my $room (@speakers) {
        print "PAObj: set_obj: " . $room . " / " . $state . "\n" if $main::Debug{pa};
        my $ref = &::get_object_by_name("pa_$room");
        if ($ref) {
            $ref->set($state);
        }
    }
}

sub set_x10
{
    my ($self,$state,@speakers) = @_;
    my ($x10_list,$pa_x10_hc,$ref,$refobj);

    for my $room (@speakers) {
        print "PAObj: set_x10: " . $room . " / " . $state . "\n" if $main::Debug{pa};
        $ref = &::get_object_by_name('pa_'.$room);
        $refobj = &::get_object_by_name('pa_'.$room.'_obj');
        if ($refobj && $ref) {
            my ($id) = $ref->get_address();
            print "PAObj: set_x10 ID: $id, State: $state, Room: $room\n" if $main::Debug{pa};
            $refobj->set($state);
        }
    }
}

sub set_xap {
    my ($self,$state,$param1,$param2) = @_;
    my @speakers = @$param1;
    my %voiceparms = %$param2;
    return unless $#speakers > -1;
    for my $room (@speakers) {
        print "PAObj: set_xap: " . $room . " / " . $state . "\n" if $main::Debug{pa};
        my $ref = &::get_object_by_name('pa_'.$room.'_obj');
        if ($ref) {
            $ref->send_message($ref->target_address, $ref->class_name => {say => $voiceparms{text}, volume => $voiceparms{volume}, mode => $voiceparms{mode}, voice => $voiceparms{voice} });
            print "PAObj: xap cmd: $ref->{object_name} is sending voice text: $voiceparms{text}\n" if $main::Debug{pa};
        } else {
            print "PAObj: Unable to locate object for: pa_$room\n" if $main::Debug{pa};
        }
    }
}

sub set_xpl {
    my ($self,$state,$param1,$param2) = @_;
    my @speakers = @$param1;
    my %voiceparms = %$param2;
    return unless $#speakers > -1;
    for my $room (@speakers) {
        print "PAObj: set_xpl: " . $room . " / " . $state . "\n" if $main::Debug{pa};
        my $ref = &::get_object_by_name('pa_'.$room.'_obj');
        if ($ref) {
            my $max_length = $::config_parms{"pa_$room" . "_maxlength"};
            $max_length = 0 unless $max_length;
            my $text = $voiceparms{text};
            if ($max_length) {
               $text = substr($text, 0, $max_length) if $max_length < length($text);
            }
            $ref->send_cmnd($ref->class_name => {speech => $text, voice => $voiceparms{voice}, volume => $voiceparms{volume}, mode => $voiceparms{mode} });
            print "PAObj: set_xpl: $ref->{object_name} is sending voice text: $voiceparms{text}\n" if $main::Debug{pa};
        } else {
            print "PAObj: Unable to locate object for: pa_$room\n" if $main::Debug{pa};
        }
    }
}

sub set_weeder
{
    my ($self,$state,$weeder_port,@speakers) = @_;
    my %weeder_ref;
    my $weeder_command='';
    my $command='';
    for my $room (@speakers) {
        print "PAObj: set_weeder: " . $room . " / " . $state . "\n" if $main::Debug{pa};
        my $ref = &::get_object_by_name('pa_'.$room.'_obj');
        if ($ref) {
            $ref->{state} = $state;
            my ($card,$id) = $ref->{id_by_state}{'on'} =~ /^D?(.)H(.)/s;
            $weeder_ref{$card}='' unless $weeder_ref{$card};
            $weeder_ref{$card} .= $id;
            print "PAObj: card: $card, id: $id, Room: $room\n" if $main::Debug{pa};
        }
    }

    $self->print_speaker_states() if $main::Debug{pa};

    for my $card ('A' .. 'P','a' .. 'p') {
        if ($weeder_ref{$card}) {
            $command = '';
            my $data = $weeder_ref{$card};
            $command = $self->get_weeder_string($card,$data);
            $weeder_command .= "$command\\r" if $command;
        }
    }
    return 0 unless $weeder_command;
    print "PAObj: Sending $weeder_command to the weeder card(s)\n" if $main::Debug{pa};
    $weeder_command =~ s/\\r/\r/g;
    &Serial_Item::send_serial_data($weeder_port, $weeder_command) if $main::Serial_Ports{$weeder_port}{object};
    return 1;
}

sub get_weeder_string
{
    my ($self,$card,$data) = @_;

    my $bit_counter=0;
    my ($bit_flag,$state,$ref,$bit,$byte_code,$weeder_code,$id);

    # yea, there are cleaner ways to do this, but this should work
    my %decimal_to_hex = qw(0 0 1 1 2 2 3 3 4 4 5 5 6 6 7 7 8 8 9 9 10 A 11 B 12 C 13 D 14 E 15 F);
    $byte_code = $bit_counter = 0;
    $weeder_code = '';

    for $bit ('A' .. $pa_weeder_max_port{$card}) {
        $id = $card . 'L' . $bit;
        $id = "D$id" if $$self{pa_type} eq 'wdio_old'; #TODO: Find way to implement this with new code
        my $ref = &Device_Item::item_by_id($id);
        if ($ref) {
            $state = $ref->{state};
        }
        else {
            $state = 'off';
        }

        $bit_flag = ($state eq 'on') ? 1 : 0;                # get 0 or 1
        print "PAObj: get_weeder_string card: $card, bit=$bit state=$bit_flag\n" if $main::Debug{pa};
        $byte_code += ($bit_flag << $bit_counter);        # get bit in byte position

        if ($bit_counter++ >= 3) {
            # pre-pend our string with the new value
            $weeder_code = $decimal_to_hex{$byte_code} . $weeder_code;
            $byte_code = $bit_counter = 0;
        }
    }

    # we have to do this again -- in case we don't have bits on a byte boundary
    if ($bit_counter > 0) {
        # pre-pend our string with the new value
        $weeder_code = $decimal_to_hex{$byte_code} . $weeder_code;
    }

    if ($$self{pa_type} eq 'wdio_old') { #TODO: Find way to implement this with new code
        $card = "D$card";
        $weeder_code = 'h' . $weeder_code;
    }
    return $card . "W$weeder_code";
}

sub get_speakers
{
    my ($self,$rooms) = @_;
    my @pazones;

    print "PAObj: get_speakers,rooms: " . $rooms . "\n" if $main::Debug{pa};
    if ($::mh_speakers->{rooms}) {
        $rooms = $::mh_speakers->{rooms};
        $::mh_speakers->{rooms} = '';
    }
    $rooms = 'default' unless $rooms;

    #Gather list of zones that will be used for speaking/playing
    for my $room (split(/[,;|]/, $rooms)) {
        no strict 'refs';
        my $ref = &::get_object_by_name("pa_$room");
        if ($ref) {
            print "PAObj: name=$ref->{object_name}\n" if $main::Debug{pa};
            if (UNIVERSAL::isa($ref,'Group')) {
                print "PAObj: It's a group!\n" if $main::Debug{pa};
                for my $grouproom ($ref->list) {
                    $grouproom = $grouproom->get_object_name;
                    $grouproom =~ s/^\$pa_//;
                    $grouproom =~ s/^\$paxpl_//;
                    $grouproom =~ s/^\$paxap_//;
                    print "PAObj:  - member: $grouproom\n" if $main::Debug{pa};
                    push(@pazones, $grouproom);
                }
            } else {
                push(@pazones, $room);
            }
        } else {
            &::print_log("PAObj: WARNING: PA zone of '$room' not found!");
        }
    }
    return @pazones;
}

sub check_group
{
    my ($self,$group) = @_;
    print "PAObj: check group=$group\n" if $main::Debug{pa};
    my $ref = &::get_object_by_name("pa_$group");
    if (!$ref) {print "Error! Group does not exist: $group\n"; return;}
    my @list = $ref->list;
    print "PAObj: check group=$group, list=$#list\n" if $main::Debug{pa};
    if ($#list == -1) {
        print "PAObj: check populating group: $group!\n" if $main::Debug{pa};
        for my $room ($self->get_speakers('allspeakers')) {
            my $ref2 = &::get_object_by_name("pa_$room");
            $ref->add($ref2);
        }
    }
}

sub get_speakers_speakable
{
    my ($self,$mode,@zones) = @_;
    my @pazones;

    $mode = state $::mode_mh unless $mode;
    return @pazones if $mode eq 'mute' or $mode eq 'offline';

    for my $room (@zones) {
        my $ref = &::get_object_by_name("pa_$room");
        print "PAObj: speakable: name=$ref->{object_name}\n" if $main::Debug{pa};
        if ($ref->{sleeping} == 0) {
            $ref->{mode} = 'normal' unless $ref->{mode};
            my $gss_mode = $ref->{mode};
            if ($gss_mode ne 'sleeping' && ($gss_mode eq 'normal' || $mode eq 'unmuted')) {
                push(@pazones,$room);
                print "PAObj: speakable: Pushing $room into pazones array:$#pazones\n" if $main::Debug{pa};
            }
        }
    }
    return @pazones;
}

sub set_delay
{
    my ($self,$delay) = @_;
    $$self{pa_delay} = $delay;
}

sub print_speaker_states
{
    my ($self) = @_;
    my @speakers = $self->get_speakers('allspeakers');
    my ($ref,$room);
    for my $speaker (@speakers) {
        $ref = &::get_object_by_name("pa_$speaker");
        $room = $ref->{object_name};
        $room =~ s/^\$pa_//;
        print "PAObj: name=$room, state=$ref->{state}\n" if $main::Debug{pa};
    }
}

package PAobj_zone;

@PAobj_zone::ISA = ('Generic_Item');

sub last_char
{
    my ($self,$string) = @_;
    my @chars=split(//, $string);
    return((sort @chars)[-1]);
}

#Type Address	Name			Groups               		Serial   Other
sub new
{
    my ($class,$paz_address,$paz_name,$paz_groups,$paz_serial,$paz_other) = @_;
    my $self={};

    bless $self,$class;

    $$self{name}		= $paz_name;
    $$self{address}	= $paz_address;
    $$self{groups}	= $paz_groups;
    $$self{serial}	= $paz_serial;
    $$self{other}		= $paz_other;

    return $self;
}

sub init
{
    my ($self) = @_;
}

sub get_address
{
    my ($self) = @_;
    return $$self{address};
}

sub get_name
{
    my ($self) = @_;
    return $$self{name};
}

sub get_groups
{
    my ($self) = @_;
    return $$self{groups};
}

sub get_serial
{
    my ($self) = @_;
    return $$self{serial};
}

sub get_type
{
    my ($self) = @_;
    return $$self{other};
}


1;


=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Steve Switzer  steve@switzerny.org

Special Thanks to:

  Bruce Winter - MH
  Jason Sharpee - Example Perl Modules to "steal",learn from. :)
  Ross Towbin - Providing me with code snippets for "setting weeder with more than 8 ports"


=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

