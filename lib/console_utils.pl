
=head1 B<console_utils>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item B<UnDoc>

=cut

#===============
sub choose_menu {

    #===============

    local ( $CON_IN, $CON_OUT, @choices ) =
      @_;    # Could use my, but then need to pass CON_OUT to highlight subs

    # save settings
    my $oldT = $CON_OUT->Title();

    my ( $wLeft, $wTop, $wRight, $wBottom ) = $CON_OUT->Window();

    my $X = $wRight - $wLeft;
    my $Y = $wBottom - $wTop;

    my $dX = 45;
    my $dY = 6;

    my $cX = $wLeft;
    my $cY = $wTop + 13;

    my $BACKGROUND = $CON_OUT->ReadRect( $cX, $cY, $cX + $dX, $cY + $dY );

    Window( $CON_OUT, $FG_WHITE | $BG_BLACK, " ", $cX, $cY, $dX, $dY );

    $CON_OUT->Attr( $FG_WHITE | $BG_BLACK );

    my $i = 0;
    while ( $i <= $#choices ) {
        $CON_OUT->Cursor( $wLeft + 2, $cY + $i + 1 );
        $CON_OUT->Write( $choices[$i] );
        $i++;
    }

    $CON_IN->Flush();
    my $key   = 0;
    my @event = ();
    my $test  = 1;
    highlightTest(1);
    my $return = "";
    my ( $mX, $mY ) = $CON_OUT->Cursor();

    while ( $key != 27 ) {

        @event = $CON_IN->Input();

        # A KEY PRESSED
        if ( $event[0] == 1 and $event[1] ) {

            # UP ARROW
            if ( $event[3] == 38 and $event[4] == 72 and $test > 1 ) {
                $test = $test - 1;
                highlightTest($test);
            }

            # DOWN ARROW
            if ( $event[3] == 40 and $event[4] == 80 and $test < 5 ) {
                $test = $test + 1;
                highlightTest($test);
            }

            $key = $event[5];

            # ENTER
            if ( $key == 13 ) {
                $return = ( $choices[ $test - 1 ] );
                $key    = 27;
            }
        }
        elsif ( $event[0] == 2 ) {
            $mX = $event[1];
            $mY = $event[2];
            if ( $event[3] == 1 ) {
                for $m ( 1 .. 5 ) {
                    if (    ( $mX >= $cX + 1 and $mX <= $cX + $dX )
                        and ( $mY == $cY + $m ) )
                    {
                        $return = (
                            "",          "testInfo",
                            "testBox",   "testScroll",
                            "testTitle", "testWindow"
                        )[$m];
                        $key = 27;
                    }
                }
            }
        }
        $CON_OUT->Cursor( $mX, $mY );
    }
    $CON_IN->Flush();

    $CON_OUT->WriteRect( $BACKGROUND, $cX, $cY, $cX + $dX, $cY + $dY );
    $CON_OUT->Cursor( $oldX, $oldY, $oldS, $oldV );
    $CON_OUT->Title($oldT);

    #   $CON_OUT->Attr($FG_WHITE | $BG_CYAN);

    return $return;
}

#===========
sub Window {

    #===========
    my ( $O, $Attr, $Char, $Col, $Row, $Width, $Height ) = @_;
    filledBox( $O, $Attr, $Char, $Col, $Row, $Width, $Height );
    borderBox( $O, $Col, $Row, $Width, $Height );
}

#==============
sub filledBox {

    #==============
    my ( $O, $color, $char, $left, $top, $width, $height ) = @_;
    my $row = 0;
    for $row ( $top .. $top + $height ) {
        $O->FillAttr( $color, $width, $left, $row );
        $O->FillChar( $char, $width, $left, $row );
    }
}

#==============
sub borderBox {

    #==============
    my ( $O, $left, $top, $width, $height ) = @_;

    $O->FillChar( chr(218), 1,          $left,              $top );
    $O->FillChar( chr(196), $width - 2, $left + 1,          $top );
    $O->FillChar( chr(191), 1,          $left + $width - 1, $top );

    my $row = 0;
    for $row ( $top + 1 .. $top + $height - 1 ) {
        $O->FillChar( chr(179), 1, $left, $row );
        $O->FillChar( chr(179), 1, $left + $width - 1, $row );
    }

    $O->FillChar( chr(192), 1,          $left,              $top + $height );
    $O->FillChar( chr(196), $width - 2, $left + 1,          $top + $height );
    $O->FillChar( chr(217), 1,          $left + $width - 1, $top + $height );

}

#==================
sub highlightMenu {

    #==================
    my ($menu) = @_;
    my $m;
    for $m ( 1 .. 3 ) {
        if ( $m == $menu ) {
            $CON_OUT->FillAttr(
                $FG_BLACK | $BG_WHITE, $menulen[$m],
                $menupos[$m],          $wTop + 1
            );
        }
        else {
            $CON_OUT->FillAttr( $FG_WHITE | $BG_BLUE,
                $menulen[$m], $menupos[$m], $wTop + 1 );
        }
    }
}

#==================
sub highlightTest {

    #==================
    my ($i) = @_;
    for $m ( 1 .. 5 ) {
        if ( $m == $i ) {
            $CON_OUT->FillAttr( $FG_BLACK | $BG_WHITE,
                43, $wLeft + 1, $wTop + 13 + $m );
        }
        else {
            $CON_OUT->FillAttr( $FG_WHITE | $BG_BLUE,
                43, $wLeft + 1, $wTop + 13 + $m );
        }
    }
}

#================
sub explodeAttr {

    #================
    my $O    = shift;
    my $Attr = shift;
    $Attr = $ATTR_INVERSE unless defined($Attr);
    my ( $wLeft, $wTop, $wRight, $wBottom ) = $O->Window();

    my $X = $wRight - $wLeft;
    my $Y = $wBottom - $wTop;

    return if $X == 0 or $Y == 0;    # No window

    my $times = int( ( $X > $Y ) ? ( $Y / 2 ) : ( $X / 2 ) );

    my $left   = $wLeft + int( $X / 2 );
    my $right  = $wLeft + int( $X / 2 );
    my $top    = $wTop + int( $Y / 2 );
    my $bottom = $wTop + int( $Y / 2 );

    my ( $cip, $ciop );
    for $cip ( 0 .. $times ) {
        for $ciop ( $top .. $bottom ) {
            $O->FillAttr( $Attr, ( $right - $left ), $left, $ciop );
        }
        $top  -= int( ( $Y / 2 ) / $times );
        $left -= int( ( $X / 2 ) / $times );
        $bottom += int( ( $Y / 2 ) / $times );
        $right  += int( ( $X / 2 ) / $times );

        #       millisleep(5); # sleeps for 5 milliseconds
    }

    # the final touch
    ( $wLeft, $wTop, $wRight, $wBottom ) = $O->Window();
    $X = $wRight - $wLeft + 1;
    $Y = $wBottom - $wTop + 1;
    $O->FillAttr( $Attr, $X * $Y, $wLeft, $wTop );
}

1;    # For require

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

