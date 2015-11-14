
=head1 B<CID_Log>

=head2 SYNOPSIS

Example initialization:

  use CID_Log;
  $cid = new CID_Log($telephony_driver);

Constructor Parameters:

  ex. $x = new CID_Log($y);
  $x              - Reference to the class
  $y              - Telephony driver reference

Input states:

  "cid"           - Caller ID event
  "ring"          - Ring event 'to pass along to other consumers of this object'

Output states:

  "cid"           - Caller ID event
  "ring"          - Ring event 'to pass along to other consumers of this object'

=head2 DESCRIPTION

Logs a call

=head2 INHERITS

B<Telephony_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package CID_Log;

@CID_Log::ISA = ('Telephony_Item');

sub new {
    my ( $class, $p_telephony, $p_datafile ) = @_;
    my $self = {};

    bless $self, $class;

    $self->add($p_telephony) if defined $p_telephony;

    return $self;
}

sub add {
    my ( $self, $p_telephony ) = @_;
    if ( defined $p_telephony ) {
        $p_telephony->tie_items( $self, 'cid' );
        $p_telephony->tie_items( $self, 'dialed' );
    }

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    #	&::print_log("CIDLOG $p_state, $p_setby");
    return if ( $p_setby->cid_name() =~ /MSG OFF/ );
    return if ( $p_setby->cid_name() =~ /MSG WAITING/ );
    if ( $p_state =~ /^CID/i ) {
        $self->cid_name( $p_setby->cid_name() );
        $self->cid_number( $p_setby->cid_number() );
        $self->cid_type( $p_setby->cid_type() );
        $self->address( $p_setby->address() );
        $self->ring_count( $p_setby->ring_count() );
        $self->log( $p_setby, 'in' );
    }
    elsif ( $p_state =~ /^DIALED/i ) {
        $self->cid_name( $p_setby->cid_name() );
        $self->cid_number( $p_setby->cid_number() );
        $self->cid_type( $p_setby->cid_type() );
        $self->address( $p_setby->address() );
        $self->ring_count(0);
        $self->log( $p_setby, 'out' );
    }
    $self->SUPER::set($p_state);
}

sub log {
    my ( $self, $p_telephony, $tempsource ) = @_;

    my ( $l_number, $l_name, $l_address );

    $l_number = $p_telephony->cid_number();
    if ( $p_telephony->isa('CID_Lookup')
        and ( $tempsource eq 'in' ) )    # outgoing log doesn't want formatted
    {
        $l_number = $p_telephony->formated_number()
          if $p_telephony->formated_number() ne '';
    }
    $l_name = $p_telephony->cid_name()
      || $p_telephony->city();    # Needed in UK, as there is no NAME data in UK
    $l_address = $p_telephony->address();

    #Log to text file
    if ( lc $tempsource eq 'out' ) {

        #		&::logit("$::config_parms{data_dir}/phone/logs/phone.$::Year_Month_Now.log",
        #		"O$l_number name=$l_name line=$l_address type=$tempsource");
        my $duration  = '00:00:00';
        my $extension = 'unknown';
        my $call_type = 'POTS';
        if ( $p_telephony && $p_telephony->isa('Telephony_Item') ) {
            $extension = $p_telephony->extension() if $p_telephony->extension();
            $duration = $p_telephony->call_duration()
              if $p_telephony->call_duration();
            $call_type = $p_telephony->call_type() if $p_telephony->call_type();
        }
        my $log_line =
          "O$l_number name=$duration ext=$extension line=$l_address type=$call_type";
        print "LOG LINE: $log_line\n";
        &::logit(
            "$::config_parms{data_dir}/phone/logs/phone.$::Year_Month_Now.log",
            $log_line
        );
    }
    else {
        &::logit(
            "$::config_parms{data_dir}/phone/logs/callerid.$::Year_Month_Now.log",
            "$l_number name=$l_name line=$l_address type=$tempsource"
        );
    }

    #Log to dbm
    &::logit_dbm( "$::config_parms{data_dir}/phone/callerid.dbm",
        $l_number, "$::Time_Now $::Date_Now $::Year name=$l_name" );

    # If this caller is not in our caller_id_file, let's save their info
    # in the same format as caller_id_file but to a different file.
    # then we can periodically copy lines from this 2nd file into
    # our caller_id_file. this doesn't check to see if the caller is already
    # in caller_id_file2, because it might be meaningful to see how many
    # calls you receive from a number not in your caller_id_file list.
    if ( $p_telephony->isa('CID_Lookup') ) {
        unless ( $p_telephony->category() ) {

            #			&::print_log("LOG:". $::config_parms{caller_id_file2} .":");
            if ( $::config_parms{caller_id_file2} ) {
                &::logit( $::config_parms{caller_id_file2},
                    "$l_number\t$l_name\t*\n", 0 );
            }
        }
    }
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Jason Sharpee
jason@sharpee.com

Special Thanks to:
Bruce Winter - MH

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

