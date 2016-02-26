
=head1 B<Numbered_Menu>

=head2 SYNOPSIS

Read in .menu files with menu_parse (see menu.pl for examples),
then select which menu to use with the first parameter, and
the delay you want with the 2nd.

Example initialization:

  use Numbered_Menu;
  $NM = new Numbered_Menu('default', 2);

  $input_object->tie_items($NM);
  $NM->tie_items($output_object);


Constructor Parameters:

  ex. $x = new Numbered_Menu($y,$i);

  $x              - Reference to the class
  $y              - Menu Name
  $i              - Delay between outputing items from the menu.
                    -1 = Do not automatically advance to the next item
                     0 = Output all items without delay
                    >0 = Number of seconds of delay time

Input states:

  "start"     - Starts the menu code and listens to all other input states.
  "1","2",etc - Selects the numbered item
  "exit"      - Go to parent menu
  "repeat"    - Repeats current item
  "stop"      - Stops the menu code and ignores all input states except for start.
  "previous"  - Advances to the prior menu item.
  "next"      - Advances immediately to the next item in the menu.


Output states:

  "MENU:xxxxxx"   - Menu named xxxxx
  "ITEM:x:yyyy"   - Item number x with name yyyyyy (x is '-' at the end of the menu)
  "RESPONSE:xxxx" - Reponse xxxx from selected item if any
  <input states>  - All input states are echoed exactly to the output state as well.

For keyboard example, enable code/common/keyboard_numbered_menu.pl

=head2 DESCRIPTION

Module that navigates a specified menu using numbered selections.

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package Numbered_Menu;

@Numbered_Menu::ISA = ('Generic_Item');

my $m_menus;
my $m_menugroup;
my $m_itemCount;
my $m_itemCurrent;
my $m_itemIndex;
my $m_itemselected;
my $m_itemPrevious;
my $m_menuCurrent;
my $m_menuPrevious;
my $m_outputTimer;
my $m_outputDelay;
my @m_menuList;
my @m_itemList;
my $m_menuDepth;
my $m_active;

sub new {
    my ( $p_class, $p_menugroup, $p_delay ) = @_;
    my $self = {};

    bless $self, $p_class;

    $p_delay     = 3         unless defined $p_delay;
    $p_menugroup = 'default' unless $p_menugroup;

    $$self{m_menugroup}   = $p_menugroup;
    $$self{m_outputTimer} = new Timer();
    $$self{m_outputDelay} = $p_delay;
    $$self{m_active}      = 0;
    $$self{m_menuDepth}   = 0;

    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    #	&::print_log("State called: $p_state, $p_setby");
    $p_state = lc $p_state;

    return
      unless ( $$self{m_active} or $p_state eq 'start' or $p_state eq 'on' );

    if ( $p_setby ne $$self{m_outputTimer} )  #keep timer states out of the loop
    {
        $self->SUPER::set($p_state);
    }

    if ( $p_setby eq $$self{m_outputTimer} ) {
        if ( $p_state eq 'off' ) {
            $self->sequence_item();
        }
    }
    else                                      #process any request
    {
        if ( $p_state =~ /^[0-9]+/ and $$self{m_active} ) {
            $self->select_item($p_state);
        }
        elsif ( $p_state eq 'exit' and $$self{m_active} ) {
            $self->exit();
        }
        elsif ( $p_state eq 'repeat' and $$self{m_active} ) {
            $self->repeat();
        }
        elsif ( $p_state eq 'next' and $$self{m_active} ) {
            $self->next();
        }
        elsif ( $p_state eq 'previous' and $$self{m_active} ) {
            $self->previous();
        }
        elsif ( $p_state eq 'start' or $p_state eq 'on' ) {
            $self->start();
        }
        elsif ( $p_state eq 'stop' or $p_state eq 'off' ) {
            $self->stop();
        }
    }
}

sub select_menu {
    my ( $self, $p_menu ) = @_;
    return unless $p_menu;    # Avoid mh abend if I run start twice in a row

    my $menus = $$self{m_menus};

    $$self{m_outputTimer}->set(0);    #stop output

    #	&::print_log("Selected Menu: $p_menu : $$self{m_menuDepth}");
    $$self{m_menuCurrent} = $p_menu;

    ${ $$self{m_menuList} }[ $$self{m_menuDepth} ] = $p_menu;

    $$self{m_itemIndex} = 1;
    return unless $$menus{ $$self{m_menuCurrent} };    # Guard against bad menus
    $$self{m_itemCount} = @{ $$menus{ $$self{m_menuCurrent} }{items} };

    if ( $$self{m_menuCurrent} =~ /^states/ ) {
        my $l_menuPrevious = ${ $$self{m_menuList} }[ $$self{m_menuDepth} - 1 ];
        my $l_itemPrevious = ${ $$self{m_itemList} }[ $$self{m_menuDepth} - 1 ];
        my $item = ${ $$menus{$l_menuPrevious}{items} }[ $l_itemPrevious - 1 ];

        #		&::print_log("POP:$$self{m_menuDepth},$l_menuPrevious: $l_itemPrevious : $$item{A}: $$item{Dstates}");
        if ( $$item{A} and $$item{Dstates} ) {
            $self->set_states_for_next_pass(
                "MENU:$$item{Dprefix}command$$item{Dsuffix}");
        }
    }
    else {
        $self->set_states_for_next_pass("MENU:$$self{m_menuCurrent}");
    }
}

sub select_item {
    my ( $self, $p_item ) = @_;
    my $menus = $$self{m_menus};

    $$self{m_outputTimer}->set(0);    #stop output

    if ( $p_item > $$self{m_itemCount} ) {

        #ignore bogus entries
        return;
    }
    $$self{m_itemCurrent} = $p_item;
    ${ $$self{m_itemList} }[ $$self{m_menuDepth} ] = $p_item;

    #	my $tester= ${$$self{m_itemList}}[$$self{m_menuDepth}];
    #	&::print_log("---set: $tester, $$self{m_menuDepth},$p_item:");
    my $item = ${ $$menus{ $$self{m_menuCurrent} }{items} }[ $p_item - 1 ];

    #	&::print_log("GOTO: $$item{goto}");
    if ( $$item{A} )    #action
    {
        if ( $$item{Dstates} ) {
            $$self{m_menuDepth}++;
            $self->select_menu( $$item{'Dstates_menu'} );
            $self->item_delay();
        }
        elsif ( $$item{A} eq 'state_select' ) {
            my $l_item = $p_item - 1;
            my $l_itemPrevious =
              ${ $$self{m_itemList} }[ $$self{m_menuDepth} - 1 ] - 1;
            my $l_menuPrevious =
              ${ $$self{m_menuList} }[ $$self{m_menuDepth} - 1 ];

            #			&::print_log("MenuPreve: $l_menuPrevious");
            my $response =
              &::menu_run( $$self{m_menugroup}, $l_menuPrevious,
                $l_itemPrevious, $l_item, "l" );
            if ($response) {
                $self->set_states_for_next_pass("RESPONSE:$response");
            }
            $self->repeat();
        }
        else {
            #			&::print_log("ARun Item:$$self{m_menuCurrent} : $p_item");
            my $l_item = $$self{m_itemCurrent} - 1;

            #			&::menu_run("$$self{m_menugroup},$$self{m_menuCurrent},$l_item,$$item{D},l");
            my $response =
              &::menu_run( $$self{m_menugroup}, $$self{m_menuCurrent}, $l_item,
                undef, "l" );
            if ($response) {
                $self->set_states_for_next_pass("RESPONSE:$response");
            }
        }
    }
    elsif ( $$item{R} )    #response
    {
        #		&::print_log("RRun Item:$$self{m_menucurrent} : $p_item");
        my $l_item = $$self{m_itemCurrent} - 1;
        my $response =
          &::menu_run( $$self{m_menugroup}, $$self{m_menuCurrent}, $l_item,
            undef, "l" );
        if ($response) {
            $self->set_states_for_next_pass("RESPONSE:$response");
        }
    }
    else                   #menu
    {
        $$self{m_menuDepth}++;
        $self->select_menu( $$item{D} );
        $self->item_delay();
    }
}

sub start {
    my ($self) = @_;
    $$self{m_active}    = 1;
    $$self{m_itemIndex} = 1;
    $$self{m_menuDepth} = 0;

    # Allow for parsed menus elsewhere
    unless ( $$self{m_menus} ) {
        $$self{m_menus} = $main::Menus{ $$self{m_menugroup} };
    }

    my $menu = $$self{m_menus};
    $$self{m_menuCurrent} = ${ $$menu{_menu_list} }[0];
    $self->select_menu( $$self{m_menuCurrent} );
    $self->item_delay();
}

sub stop {
    my ($self) = @_;
    $$self{m_active} = 0;
}

sub repeat {
    my ($self) = @_;
    $self->select_menu( $$self{m_menuCurrent} );
    $self->sequence_item();
}

sub next {
    my ($self) = @_;
    if ( $$self{m_itemIndex} <= $$self{m_itemCount} ) {
        $self->output_item( $$self{m_menuCurrent}, $$self{m_itemIndex} );
        $$self{m_itemIndex}++;
        $self->item_delay();
    }
    else    #End if items
    {
        $self->set_states_for_next_pass("ITEM:-:END");
    }
}

sub previous {
    my ($self) = @_;
    if ( $$self{m_itemIndex} > 0 ) {
        $self->output_item( $$self{m_menuCurrent}, $$self{m_itemIndex} );
        $$self{m_itemIndex}--;
        $self->item_delay();
    }
    else    #End if items
    {
        $self->set_states_for_next_pass("ITEM:+:BEGINING");

        #       $self->exit;            # Walk back to previous menu
    }
}

sub exit {
    my ($self) = @_;
    if ( $$self{m_menuDepth} > 0 ) {
        $$self{m_menuDepth}--;
    }
    $self->select_menu( ${ $$self{m_menuList} }[ $$self{m_menuDepth} ] );
    $self->sequence_item();

}

sub sequence_item {
    my ($self) = @_;
    if ( $$self{m_itemIndex} <= $$self{m_itemCount} ) {
        $self->output_item( $$self{m_menuCurrent}, $$self{m_itemIndex} );
        $$self{m_itemIndex}++;
        $self->item_delay();
    }
    else    #End if items
    {
        $self->set_states_for_next_pass("ITEM:-:END");
    }
}

sub item_delay {
    my ($self) = @_;

    if ( $$self{m_outputDelay} == 0 ) {

        # if delay is set to 0 there should be something in here to immediately call back.
        $self->set( 'off', $$self{m_outputTimer} )
          ;    # might be recursive somehow though?
    }
    elsif ( $$self{m_outputDelay} == -1 ) {

        # Do not automatically advance the item bail out
    }
    else {
        my $l_name = $self->get_object_name();
        my $action = $l_name . "->set('off'," . $l_name . "->{m_outputTimer})";

        #		&::print_log("delay=$$self{m_outputDelay}, Action: $action");
        $$self{m_outputTimer}->set( $$self{m_outputDelay}, $action );
    }
}

sub output_item {
    my ( $self, $p_menu, $p_item ) = @_;
    my $menus = $$self{m_menus};
    my $item  = ${ $$menus{$p_menu}{items} }[ $p_item - 1 ];
    my $name;

    # logic could be simplified quite a bit.. Functionality first.. Optimization last ;)
    if ( $$item{A} ) {
        if ( $$item{Dstates} ) {

            #			&::print_log("--Actions--" . ${$$item{actions}}[0] );
            $name = $$item{Dprefix} . "command" . $$item{Dsuffix};
        }
        else {
            $name = $$item{D};
        }
    }
    elsif ( $$item{R} ) {
        $name = $$item{D};
    }
    else {
        $name = $$item{D};
    }
    $self->set_states_for_next_pass("ITEM:$p_item:$name");
}
1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Jason Sharpee  jason@sharpee.com

Special Thanks to:

  Bruce Winter - MH
  David Norwood - Audible_Menu.pm
  Bill Sobel - Stargate.pm

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

