=head1 B<PAobj>

=head2 SYNOPSIS

Example initialization:

  use PAobj;
  $paobj = new PAobj('wdio','weeder');

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
    my ($class,$pa_type,$pa_port) = @_;
    my $self={};

    bless $self,$class;

    $pa_type = 'wdio' unless $pa_type;
    $pa_port = 'weeder' unless $pa_port;

    $$self{pa_type} = $pa_type;
    $$self{pa_type_init} = 0;

    $$self{pa_port} = $pa_port;
    $$self{pa_delay} = 0.5;

    return $self;
}

sub init {
    my ($self) = @_;
    %pa_zone_types=();
    my $ref = &::get_object_by_name("pa_allspeakers");
    if (!$ref) {
        &::print_log("\n\nWARNING! PA Zones were not found! Your *.mht file probably doesn't list the PA zones correctly.\n\n");
        return 0;
    }
    $self->check_group('default');

#    my @speakers = $self->get_speakers('allspeakers');
#    for my $room (@speakers) {
#        my $paobjname = "pa_$room";
#        my $ref = &::get_object_by_name($paobjname);
#        my $pa_zone_type = $pa_zone_type_by_zone{$paobjname};
#        print "db INIT room=$room, zonetype=$pa_zone_type\n";
#        $pa_zone_types{$pa_zone_type}++ unless $pa_zone_types{$$ref{pa_type}};
#    }


    if ($$self{pa_type} =~ /^wdio/i) {
        $self->init_weeder();
        return 0 unless %pa_weeder_max_port;
    } elsif (lc $$self{pa_type} eq 'x10') {
        print "x10 PA type initialized...\n" if $main::Debug{pa};
    } elsif (lc $$self{pa_type} eq 'xap') {
        print "xAP PA type initialized...\n" if $main::Debug{pa};
    } elsif (lc $$self{pa_type} eq 'xpl') {
	print "xPL PA type initialized...\n" if $main::Debug{pa};
    } else {
        &::print_log("\n\nWARNING! Unrecognized PA type of \"$$self{pa_type}\". PA code probably will not work.\n\n");
        return 0;
    }
    return 1;
}

sub init_weeder
{
    my ($self) = @_;
    my (%weeder_ref,%weeder_max);
    my @speakers = $self->get_speakers('allspeakers');
    undef %pa_weeder_max_port;
    for my $room (@speakers) {
        print "db init PA Room loaded: $room\n" if $main::Debug{pa};
	my $ref = &::get_object_by_name("pa_$room");
        $ref->{state} = 'off';
        print "db pa type: $$self{pa_type}\n" if $main::Debug{pa};
        my ($card,$id);
        ($card,$id) = $ref->{id_by_state}{'on'} =~ /^D?(.)H(.)/s;

        $weeder_ref{$card} = '' unless $weeder_ref{$card};
        $weeder_ref{$card} .= $id;
        print "db init card: $card, id: $id, Room: $room, List: $weeder_ref{$card}\n" if $main::Debug{pa};
    }

    for my $card ('A' .. 'P','a' .. 'p') {
        if ($weeder_ref{$card}) {
            my $data = $weeder_ref{$card};
            $weeder_max{$card}=$self->last_char($data);
            print "\ndb init weeder board=$card, ports=$data, max port=" . $weeder_max{$card} . "\n" if $main::Debug{pa};
        }
    }
    %pa_weeder_max_port = %weeder_max;
}

sub set
{
    my ($self,$rooms,$state,$mode) = @_;
    my $results = 0;
    print "db: pa_type: $$self{pa_type}, delay: $$self{pa_delay}\n" if $main::Debug{pa};

    print "pa db: set,mode: " . $mode . "\n" if $main::Debug{pa};
    print "pa db: set,rooms: " . $rooms . "\n" if $main::Debug{pa};

    my @speakers = $self->get_speakers($rooms);
    @speakers = $self->get_speakers('') if $#speakers == -1;
    @speakers = $self->get_speakers_speakable($mode,@speakers);
    $results = $self->set_weeder($state,@speakers) if substr(lc $$self{pa_type}, 0, 4) eq 'wdio';
    $results = $self->set_x10($state,@speakers) if lc $$self{pa_type} eq 'x10';
#    $results = $self->set_xap($state,@speakers) if lc $$self{pa_type} eq 'xap';
#    $results = $self->set_xpl($state,@speakers) if lc $$self{pa_type} eq 'xpl';
    select undef, undef, undef, $$self{pa_delay} if $results;

    return $results;
}

sub set_x10
{
    my ($self,$state,@speakers) = @_;
    my $x10_list;
    my $pa_x10_hc;

    for my $room (@speakers) {
	my $ref = &::get_object_by_name("pa_$room");
        if ($ref) {
	   $ref->{state} = $state;
           my ($id) = $ref->{x10_id};
           print "db pa set_x10 id: $id, Room: $room\n" if $main::Debug{pa};
           $pa_x10_hc = substr($id,1,1) unless $pa_x10_hc;
           $x10_list .= substr($id,1,2);
    	}
    }

    $self->print_speaker_states() if $main::Debug{pa};
    $x10_list = 'X' . $x10_list . $pa_x10_hc;
    $x10_list .= ($state eq 'on') ? 'J':'K';
    print "db pa x10 cmd: $x10_list\n" if $main::Debug{pa};
}

sub set_xap {
    my ($self,$rooms,$mode,%voiceparms) = @_;
    my @speakers = $self->get_speakers($rooms);
    @speakers = $self->get_speakers('') if $#speakers == -1;
    @speakers = $self->get_speakers_speakable($mode, @speakers);
    for my $room (@speakers) {
        my $ref = &::get_object_by_name("paxap_$room");
        if ($ref) {
            $ref->send_message($ref->target_address, $ref->class_name => {say => $voiceparms{text}, voice => $voiceparms{voice} });
            print "db pa xap cmd: $ref->{object_name} is sending voice text: $voiceparms{text}\n" if $main::Debug{pa};
        } else {
            print "unable to locate object: paxap_$room\n" if $main::Debug{pa};
        }
    }
}

sub set_xpl {
    my ($self,$rooms,$mode,%voiceparms) = @_;
    my @speakers = $self->get_speakers($rooms);
    @speakers = $self->get_speakers('') if $#speakers == -1;
    @speakers = $self->get_speakers_speakable($mode, @speakers);
    for my $room (@speakers) {
	my $ref = &::get_object_by_name("paxpl_$room");
	if ($ref) {
            my $max_length = $::config_parms{"paxpl_$room" . "_maxlength"};
            $max_length = 0 unless $max_length;
            my $text = $voiceparms{text};
            if ($max_length) {
               $text = substr($text, 0, $max_length) if $max_length < length($text);
            }
	    $ref->send_cmnd($ref->class_name => {speech => $text, voice => $voiceparms{voice} });
            print "db pa xpl cmd: $ref->{object_name} is sending voice text: $voiceparms{text}\n" if $main::Debug{pa};
	} else {
	    print "unable to locate object: paxpl_$room\n" if $main::Debug{pa};
	}
    }
}

sub set_weeder
{
    my ($self,$state,@speakers) = @_;
    my %weeder_ref;
    my $weeder_command='';
    my $command='';
    for my $room (@speakers) {
	my $ref = &::get_object_by_name("pa_$room");
	if ($ref) {
            $ref->{state} = $state;
            my ($card,$id) = $ref->{id_by_state}{'on'} =~ /^D?(.)H(.)/s;
            $weeder_ref{$card}='' unless $weeder_ref{$card};
            $weeder_ref{$card} .= $id;
            print "card: $card, id: $id, Room: $room\n" if $main::Debug{pa};
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
    return 0 unless $command;
    print "sending $weeder_command to the weeder card(s)\n" if $main::Debug{pa};
    $weeder_command =~ s/\\r/\r/g;
    &Serial_Item::send_serial_data($$self{pa_port}, $weeder_command) if $main::Serial_Ports{$$self{pa_port}}{object};
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
        $id = "D$id" if $$self{pa_type} eq 'wdio_old';
        my $ref = &Device_Item::item_by_id($id);
        if ($ref) {
            $state = $ref->{state};
        }
        else {
            $state = 'off';
        }

        $bit_flag = ($state eq 'on') ? 1 : 0;                # get 0 or 1
        print "db get_weeder_string card: $card, bit=$bit state=$bit_flag\n" if $main::Debug{pa};
        $byte_code += ($bit_flag << $bit_counter);        # get bit in byte position

        if ($bit_counter++ >= 3) {
            # pre-pend our string with the new value
            $weeder_code = $decimal_to_hex{$byte_code} . $weeder_code;
            $byte_code = $bit_counter = 0;
        }
    }

    # we have to do this again -- in case we don't have bits on a byte boundry
    if ($bit_counter > 0) {
        # pre-pend our string with the new value
        $weeder_code = $decimal_to_hex{$byte_code} . $weeder_code;
    }

    if ($$self{pa_type} eq 'wdio_old') {
        $card = "D$card";
        $weeder_code = 'h' . $weeder_code;
    }
    return $card . "W$weeder_code";
}

sub get_speakers
{
    my ($self,$rooms) = @_;
    my @pazones;

    print "pa db: get_speakers,rooms: " . $rooms . "\n" if $main::Debug{pa};
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
            print "pa db: name=$ref->{object_name}\n" if $main::Debug{pa};
            if (UNIVERSAL::isa($ref,'Group')) {
                print "pa db: It's a group!\n" if $main::Debug{pa};
                for my $grouproom ($ref->list) {
                    $grouproom = $grouproom->get_object_name;
                    $grouproom =~ s/^\$pa_//;
		    $grouproom =~ s/^\$paxpl_//;
		    $grouproom =~ s/^\$paxap_//;
                    print "pa db:  - member: $grouproom\n" if $main::Debug{pa};
                    push(@pazones, $grouproom);
                }
            } else {
                push(@pazones, $room);
            }
	} elsif (lc $$self{pa_type} eq 'xpl') {
	    $ref = &::get_object_by_name("paxpl_$room");
	    push(@pazones, $room) if $ref;
	} elsif (lc $$self{pa_type} eq 'xap') {
            $ref = &::get_object_by_name("paxap_$room");
	    push(@pazones, $room) if $ref;
        } else {
            &::print_log("WARNING: PA zone of '$room' not found!");
        }
    }
    return @pazones;
}

sub check_group
{
    my ($self,$group) = @_;
    print "db check group=$group\n" if $main::Debug{pa};
    my $ref = &::get_object_by_name("pa_$group");
    if (!$ref) {print "Error! Group does not exist: $group\n"; return;}
    my @list = $ref->list;
    print "db check group=$group, list=$#list\n" if $main::Debug{pa};
    if ($#list == -1) {
        print "db check populating group: $group!\n" if $main::Debug{pa};
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
	$ref = &::get_object_by_name("paxpl_$room") if lc $$self{pa_type} eq 'xpl';
	$ref = &::get_object_by_name("paxap_$room") if !$ref and $$self{pa_type} eq 'xap';
        print "pa db: ref=$ref\n" if $main::Debug{pa};
        print "pa db: name=$ref->{object_name}\n" if $main::Debug{pa};
        if ($ref->{sleeping} == 0) {
            $ref->{mode} = 'normal' unless $ref->{mode};
            my $gss_mode = $ref->{mode};
            if ($gss_mode ne 'sleeping' && ($gss_mode eq 'normal' || $mode eq 'unmuted')) {
                push(@pazones,$room);
                print "pa db: pushing $room into pazones array:$#pazones\n" if $main::Debug{pa};
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
	$ref = &::get_object_by_name("paxpl_$speaker") if !$ref and $$self{pa_type} eq 'xpl';
	$ref = &::get_object_by_name("paxap_$speaker") if !$ref and $$self{pa_type} eq 'xap';
        $room = $ref->{object_name};
	if ($$self{pa_type} eq 'xpl') {
	   $room =~ s/^\$paxpl_//;
	} elsif ($$self{pa_type} eq 'xap') {
	   $room =~ s/^\$paxap_//;
	} else {
           $room =~ s/^\$pa_//;
	}
        print "db name=$room, state=$ref->{state}\n" if $main::Debug{pa};
    }
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

