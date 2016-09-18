use strict;

package Weather_Item;

=head1 NAME

B<Weather_Item> - This object can be used to track data stored in the global %Weather array.

=head1 SYNOPSIS

  $WindSpeed = new Weather_Item 'WindSpeed';
  $WindSpeed-> tie_event('print_log "Wind speed is now at $state"');

  $freezing = new Weather_Item 'TempOutdoor < 32';
  if (state_now $fountain eq ON and state $freezing) {
    speak "Sorry fountains don't work too well when frozen";
    set $fountain OFF
  }

  $Windy = new Weather_Item 'WindSpeed > 15';
  speak "Wind is gusting at $Weather{WindSpeed} mph" if state $Windy;

  # For current state, easiest to use it directly
  speak "Outdoor temperature is $Weather{TempOutdoor} degrees";

=head1 DESCRIPTION

=head1 INHERITS

B<Generic_Item>

=head1 METHODS

=over

=cut

# $w_x = new Weather_Item(TempIndoor);         # returns e.g. 68/82/etc
# $w_x = new Weather_Item('TempIndoor > 99')   # returns evaluated expression if defined else return value undefined

@Weather_Item::ISA = ('Generic_Item');
my @weather_item_list;

sub Init {
    &::MainLoop_pre_add_hook( \&Weather_Item::check_weather, 1 );
}

sub check_weather {
    if ($::New_Msecond_250) {
        for my $self (@weather_item_list) {
            my $state = $self->state;    # Gets current state
            if ( defined $state
                and ( !defined $self->{state} or $self->{state} ne $state ) )
            {
                &Generic_Item::set_states_for_next_pass( $self, $state );
            }
        }
    }
}

sub clear_weather_item_list {
    undef @weather_item_list;
}

sub item_transform($) {
    $_ = shift;
    ( $_ =~ /^(and|or|not|eq|ne|clear|cloudy|sunny|partly|mostly)$/i )
      ? "$_"
      : "\$::Weather{$_}";
}

=item C<new($type)>

$type is the name of the %Weather index you want to monitor.  $type can also have a =<> comparison operator in it so you can make the object a true/false test.

=cut

sub new {
    my ( $class, $type ) = @_;
    my @members;

    if ($type) {
        $type =~ s/\x20+/\x20/g;                           # consolidate spaces
        $type =~ s/([^0-9 \W]+)/item_transform($1)/egi;    # markup items
        $type =~
          s/(partly cloudy|partly sunny|mostly cloudy|mostly sunny|clear|cloudy)/"'" . ucfirst(lc($1)) . "'"/egi
          ;    # normalize condition strings
        $type =~ s/ = '/ eq '/gi;    # quote condition strings

        $type =~ s/[^<>=]= /== /g; # double equal signs (no assignments allowed)
            # *** test with super syntax as well as module function calls

        $type =~ s/&[^0-9 \W]+:{0,}[^0-9 \W]+\(.*\)//g
          ;    # no function calls either (for safety)
        $type =~ s/(state|item_transform|check_weather)//gi
          ;    # short-circuit methods (hack)

        # Save weather hash keys in member list (to be checked for existence in state sub before expression is evaluated)

        while ( $type =~ /\$::Weather{(.*?)}/g ) {
            push @members, $1 if !grep $1 eq $_, @members;
        }

        print "Weather_Item test: $type vars=@members\n" if $::Debug{weather};

    }
    else {
        warn 'Empty expression is not allowed.';
    }

    my $self = { type => $type, list => \@members };
    bless $self, $class;
    push @weather_item_list, $self;
    return $self;

}

=item C<state>

Returns the last state, or 1/0 if $comparition and $limit were used.

=cut

sub state {
    my ($self) = @_;
    my $valid;

    $valid = 1;

    # check that all members are defined

    for ( @{ $self->{list} } )
    {    # short-circuit evaluation if any member is undefined
        $valid = 0 if !defined $main::Weather{$_};
    }

    my $results;
    if ($valid) {
        $results = eval $self->{type} if $valid;
        print
          "Weather_Item eval error: object=$self->{object_name} test=$self->{type} error=$@"
          if $@;
    }

    return $results;
}

sub default_setstate {
    warn "Unable to control the weather.";
    return -1;
}

1;

=back

=head1 INHERITED METHODS

=over

=item C<tate_now>

Returns the state only when the weather data changed.

=back

=head1 INI PARAMETERS

NONE

=head1 AUTHOR

UNK

=head1 SEE ALSO

For examples on interface code that stores data into %Weather, see mh/code/bruce/weather_monitor.pl (uses mh/lib/Weather_wx200.pm), mh/code/public/iButton_ws_client.pl, and mh/code/public/weather_com.pl

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

#
# $Log: Weather_Item.pm,v $
# Revision 1.6  2003/02/08 05:29:24  winter
#  - 2.78 release
#
# Revision 1.5  2001/08/12 04:02:58  winter
# - 2.57 update
#
#
