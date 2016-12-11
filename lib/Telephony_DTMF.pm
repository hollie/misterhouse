
=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Telephony_DTMF.pm

Description:
	

Author:
	Jason Sharpee
	jason@sharpee.com

License:
	This free software is licensed under the terms of the GNU public license.

Usage:

	Example initialization:

	
	Constructor Parameters:

	Input states:

	Output states:
		"x"		- DTMF received (x = '1,2,3,4,5,6,7,8,9,0,*,#,^,+');
		"onhook"	- Device went on hook
		"offhook"	- Device went off hook

	For DTMF input and output examples, see code/public/ivr.pl

Bugs:
	There isnt a whole lot of error handling currently present in this version.  Drop me
	an email if you are seeing something odd.

Special Thanks to: 
	Bruce Winter - MH
		

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package Telephony_DTMF;

@Telephony_DTMF::ISA = ('Generic_Item');

my %m_actions;
my %m_times;

sub new {
    my ( $class, $p_telephony ) = @_;
    my $self = {};
    bless $self, $class;
    $self->add($p_telephony);
    return $self;
}

sub add {
    my ( $class, $p_telephony ) = @_;
    $p_telephony->tie_items( $class, 'dtmf' );
    $p_telephony->tie_items( $class, 'hook' );
}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;
    &::print_log(
        "Telephony DTMF state:$p_state:$p_setby" . $p_setby->address() );
    $p_state = lc $p_state;
    if ( $p_state =~ /^dtmf/ ) {
        $p_state = $p_setby->dtmf();
    }
    elsif ( $p_state =~ /^hook/ ) {
        if ( lc( $p_setby->hook ) eq 'on' ) {
            $p_state = '+';
        }
        else {
            $p_state = '^';
        }
    }
    $self->check_sequences( $p_state, $p_setby );
    $self->SUPER::set( $p_state, $p_setby );
}

sub tie_sequence {
    my ( $self, $p_seq, $p_action, $p_time ) = @_;

    #	$m_actions{$p_seq}=$p_action;
    $$self{m_actions}{$p_seq} = $p_action;
    $$self{m_times}{$p_seq}   = $p_time;
}

sub check_sequences {
    my ( $self, $p_state, $p_setby ) = @_;

    #assemble the current sequence
    my $l_sequence;
    my $l_event;
    my @l_times;
    my $l_prevtime;

    #figure in current event
    @l_times[0] = 0;

    #Get loged sequence and times
    my @state_log = $self->state_log();

    #	&::print_log("statelog:" . @state_log );
    for my $l_index ( 0 .. @state_log - 1 ) {
        $l_event = @state_log[$l_index];
        $l_event =~ /^(\S+\/\S+\/\S+\s\S+:\S+:\S+\s\S+)\s(\S+)\s/;

        #		&::print_log("Event:$l_event,$1". &main::my_str2time($1) . ":"
        #. $main::Time_Date . ":" . &main::my_str2time($main::Time_Date)  );
        @l_times[ $l_index + 1 ] =
          &main::my_str2time($main::Time_Date) - &main::my_str2time($1);

        #		&::print_log("Event:$l_event:" . $l_times[$l_index+1]);
        $l_sequence = $2 . $l_sequence;
    }
    $l_sequence = $l_sequence . $p_state;

    #	&::print_log("SEQ1:$l_sequence:");
    #	&::print_log("SEQ2:$l_sequence:");

    #assemble the times on each event.
    foreach my $l_seq ( keys %{ $$self{m_actions} } ) {
        &::print_log("Check seq:$l_seq:$l_sequence");

        #		&::print_log("Check seq:$l_seq:" . length($l_seq). ":" . $m_times{$l_seq} . ":");
        #		&::print_log("Time:" . $l_times[length($l_seq)-1] . ":" . $l_times[@l_times-1] );
        #		if ($l_times[length($l_seq)-1] <= $m_times{$l_seq})
        if ( $l_times[ length($l_seq) - 1 ] <= $$self{m_times}{$l_seq} ) {
            my $l_regseq = $l_seq;
            $l_regseq =~ s/\+/\\\+/g;
            $l_regseq =~ s/\^/\\\^/g;
            $l_regseq =~ s/\*/\\\*/g;
            $l_regseq = $l_regseq . '$';
            if ( $l_sequence =~ /$l_regseq/ ) {
                my $l_temp;

                #				$l_temp = $m_actions{$l_seq};
                $l_temp = $$self{m_actions}{$l_seq};
                eval($l_temp);
                &::print_log("Match:$l_temp");

                #				&::print_log("Match2:" . $l_temp . ":");
            }
        }
    }
}

1;

