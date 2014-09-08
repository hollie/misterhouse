use strict;

package Text_Cmd;

=head1 NAME

B<Text_Cmd>

=head1 SYNOPSIS

Create a widget for inputing text commands
  $Text_Input = new Generic_Item;
  &tk_entry("Text Input", $Text_Input, "tcmd1", $tcmd1);

  if ($state = state_now $Text_Input) {
    my $set_by = get_set_by $Text_Input;
    print_log "Text_Input set_by $set_by typed $state";
    run_voice_cmd($state, undef, $set_by);
  }

Create commands
  $tcmd1 = new Text_Cmd('hi (a|b|c)');
  $tcmd2 = new Text_Cmd('bye *(.*)');
  $tcmd3 = new Text_Cmd('(hi.*) (bye.*)');

Fire events if the commands match text input
  $tcmd1->tie_event('print_log "tcmd1 state: $state"');
  print_log "tcmd2 state=$state" if $state = state_now $tcmd2;
  print_log "tcmd3 state=$state set_by=$tcmd3->{set_by}, target=$tcmd3->{target}" if $state = state_now $tcmd3;

=head1 DESCRIPTION

Use this object if you want to fire events based on text entered. Unlike the Voice_Cmd item, you can use Text_Cmd to capture arbitrary text, using a regular expression.

Like Voice_Cmd items, all text passed to the run_voice_cmd and process_external_command functions will be tested against all Text_Cmd items. All items that match will fire their state_now methods.

=head1 INHERITS

B<Generic_Item>

=head1 METHODS

=over

=cut

my ( $hooks_added, @list_objects );

@Text_Cmd::ISA = ('Generic_Item');

=item C<new($re_string)>

$re_string - is any valid regular expresion.  Use the () grouping to pick the data that will be returned with the state_now method.

=cut

sub new {
    my ( $class, $text ) = @_;
    my $self = {};
    $$self{state} = '';
    $$self{text}  = $text;
    bless $self, $class;
    &::Reload_pre_add_hook( \&Text_Cmd::reload_reset, 1 ) unless $hooks_added++;
    push @list_objects, $self;
    return $self;
}

sub reload_reset {
    undef @list_objects;
}

sub set_matches {
    my ( $text, $set_by, $no_log, $respond ) = @_;
    $set_by = 'unknown' unless $set_by;
    my @list_matches;
    for my $object (@list_objects) {
        my ($state) = &check_match( $object, $text );
        next unless defined $state;
        set $object $state, $set_by, $respond;
        &main::print_log(
            "Text_Cmd match: '$text' matches $object->{object_name} text '$object->{text}'"
        ) unless $no_log;
        push @list_matches, $object;
    }
    return @list_matches;
}

sub check_match {
    my ( $self, $text ) = @_;
    my $filter = $$self{text};

    #   print "Testing $text against $filter\n";
    $text =~ s/^ *//;    # Drop leading
    $text =~ s/ *$//;    # Drop trailing
    if ( $text =~ /^$filter$/i ) {
        my $state = $1;
        $state .= "|$2" if defined $2;
        $state .= "|$3" if defined $3;
        $state .= "|$4" if defined $4;
        $state = 1 unless defined $state;

        #       print "Matched with $1,$2,$3. s=$state\n";
        return $state;
    }
    return undef;
}

=back

=head1 INHERITED METHODS

=over

=item C<state>

Returns the text from the () match in the $re_string.  If there was not () grouping, it returns 1.  If there is more than one () grouping, the resulting matches are concatonated together with | as a separator.

=item C<state_now>

Returns the state that was received or sent in the current pass.

=back

=head1 INI PARAMETERS

NONE

=head1 AUTHOR

UNK

=head1 SEE ALSO

NONE

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

#
# $Log: Text_Cmd.pm,v $
# Revision 1.3  2004/02/01 19:24:35  winter
#  - 2.87 release
#
#

1;
