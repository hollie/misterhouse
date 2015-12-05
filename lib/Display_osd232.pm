
=head1 B<Display_osd232>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Allows for displaying one or more pages of text on an Intuitive Circuits OSD-232 On-screen display character overlay board with RS-232 interface. It should also support their VideoStamp product by simply setting the apprpriate baud rate, although I don't have one to test.

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=cut

use strict;

package Display_osd232;

use vars qw(@ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter);

@EXPORT = qw(
  osdCLRblack
  osdCLRblue
  oseCLRgreen
  osdCLRcyan
  osdCLRred
  osdCLRmagenta
  osdCLRyellow
  osdCLRwhite
  osdCTLcolor
);

use constant osdCLRblack   => 0;
use constant osdCLRblue    => 1;
use constant osdCLRgreen   => 2;
use constant osdCLRcyan    => 3;
use constant osdCLRred     => 4;
use constant osdCLRmagenta => 5;
use constant osdCLRyellow  => 6;
use constant osdCLRwhite   => 7;

use constant osdCTLmode        => 128; # parm=1: 0=overlay, 1=full screen
use constant osdCTLposition    => 129; # parm=2: xpos(1-28), ypos(1-11)
use constant osdCTLclear       => 130; # parm=0: (wait 10 ms after command sent)
use constant osdCTLvisible     => 131; # parm=1: 0=hide text, 1=show text
use constant osdCTLtranslucent => 132; # parm=1: 0=off, 1=on
use constant osdCTLbgcolor     => 133; # parm=1: see osdCLRxxxxxx above
use constant osdCTLzoom =>
  134;    # parm=3: zoom row (1-11), h-zoom (1-4), v-zoom (1-4)
use constant osdCTLcolor   => 135;   # parm-1: see osdCLRxxxxxx above
use constant osdCTLblink   => 136;   # parm=1: 0=off, 1=on
use constant osdCTLreset   => 137;   # parm=0: (wait 10 ms after command sent)
use constant osdCTLvertoff => 138;   # parm=1: vertical position offset (1-63)
use constant osdCTLhorzoff => 139;   # parm=1: horizontal position offset (1-58)
use constant osdCTLframe   => 140;   # parm=1: black character frame 0=off, 1=on

sub new {
    my $classname = shift;           # What class are we constructing?
    my $this      = {};              # Allocate new memory

    bless( $this, $classname );      # Mark it of the right type
    $this->_init(@_);                # Call _init with remaining args
    return $this;
}

sub _init {
    my $this = shift;

    $this->{PAGES}       = {};              # Hash to store the pages
    $this->{pagecount}   = 0;
    $this->{currentpage} = 0;
    $this->{fliptimer}   = &Timer::new();
    $this->{flipping}    = 0;
    $this->{fliparray} = [];    # Array to store list of flip-able pages
    if (@_) {                   # Save any other initialization parameters
        my %extra = @_;
        @$this{ keys %extra } = values %extra;
    }
    $this->{PORT}  = "/dev/osd232" unless $this->{PORT};
    $this->{SPEED} = "4800"        unless $this->{SPEED};
    &main::serial_port_create( 'osd232', $this->{PORT}, $this->{SPEED}, 'none',
        'raw' );
    $this->reset();
}

=item C<addpage(NAME OF PAGE,REFERENCE TO PAGE OBJECT)>

Add a page object

=cut

sub addpage {
    my $this = shift;

    if (@_) {
        my $pageref = shift;
        $this->{PAGES}->{ $pageref->pagename() } = $pageref;
        $this->{pagecount}++;
        if ( $pageref->flip() ) {
            push( @{ $this->{fliparray} }, $pageref->pagename() );
        }
    }
}

=item C<deletepage(NAME OF PAGE)>

Remove a page object

=cut

sub deletepage {
    my $this = shift;

    if (@_) {
        my $pagename = shift;
        delete $this->{PAGES}->{$pagename}
          if exists $this->{PAGES}->{$pagename};
        $this->{pagecount}--;

        # (***need code to re-do fliparray)
    }
}

=item C<printpage(NAME OF PAGE)>

Print out an entire page. Used for testing

=cut

sub printpage {
    my $this = shift;

    if (@_) {
        my $pagename = shift;
        $this->{PAGES}->{$pagename}->print()
          if exists $this->{PAGES}->{$pagename};
    }
}

=item C<startflipping()>

Start flipping between the defined pages

=cut

sub startflipping {
    my $this = shift;

    my $flipcount = @{ $this->{fliparray} };
    if ( $flipcount > 0 ) {
        &Timer::set( $this->{fliptimer}, $this->currentfliprate() );
        $this->{flipping} = 1;
    }
}

=item C<stopflipping()>

Stop flipping pages, the screen will be left on whatever page was last displayed

=cut

sub stopflipping {
    my $this = shift;

    if ( $this->flipping() ) {
        $this->{flipping} = 0;
    }
    &Timer::stop( $this->{fliptimer} );
}

=item C<flippage()>

Flip to the next page (*** need option to flip to specific page)

=cut

sub flippage {
    my $this = shift;

    $this->{currentpage}++;
    if ( $this->{currentpage} > ( @{ $this->{fliparray} } - 1 ) ) {
        $this->{currentpage} = 0;
    }
    $this->showpage( @{ $this->{fliparray} }[ $this->{currentpage} ] );
    &Timer::set( $this->{fliptimer}, $this->currentfliprate() );
}

=item C<currentfliprate()>

Get the length of time to display the current page we're flipping to. This is either the pages custom flip rate or the default flip rate if a custom one has not been defined

=cut

sub currentfliprate {
    my $this     = shift;
    my $pagename = @{ $this->{fliparray} }[ $this->{currentpage} ];

    return $this->fliprate() unless $this->{PAGES}->{$pagename}->fliprate();
    return $this->{PAGES}->{$pagename}->fliprate();
}

=item C<port([PORT NAME])>

Set or return the name of the control port

=cut

sub port {
    my $this = shift;

    if (@_) { $this->{PORT} = shift }
    return $this->{PORT};
}

=item C<speed([PORT SPEED])>

Set or return the port port speed

=cut

sub speed {
    my $this = shift;

    if (@_) { $this->{SPEED} = shift }
    return $this->{SPEED};
}

=item C<fliprate([PAGE FLIP RATE])>

Set or return the default page flip rate. This is the number of seconds we show pages that don't have their own flip rate defined

=cut

sub defaultfliprate {
    my $this = shift;

    if (@_) { $this->{FLIPRATE} = shift }
    return $this->{FLIPRATE};
}

=item C<reset()>

Reset the osd232 requires minimum of 10ms delay after reset command

=cut

sub reset {
    my $this = shift;

    $main::Serial_Ports{osd232}{object}->write( chr(osdCTLreset) );
    select undef, undef, undef, 0.02;    # delay 20ms just to be safe
    $this->{overlay} = 1 unless $this->{overlay};
    $main::Serial_Ports{osd232}{object}
      ->write( chr(osdCTLmode) . chr( $this->{overlay} ) );
    $this->clearscreen();
}

=item C<clearscreen()>

Clear the osd232 display requires minimum of 10ms delay after command

=cut

sub clearscreen {
    $main::Serial_Ports{osd232}{object}->write( chr(osdCTLclear) );
    select undef, undef, undef, 0.02;    # delay 20ms just to be safe
}

=item C<showdisplay()>

Show the current osd232 display text on the video output signal (***Combine showdisplay and hidedisplay to a single function with a parameter determining whether to show or hide)

=cut

sub showdisplay {
    $main::Serial_Ports{osd232}{object}->write( chr(osdCTLvisible) . chr(1) );
}

=item C<hidedisplay()>

hide the current osd232 display text on the video output signal

=cut

sub hidedisplay {
    $main::Serial_Ports{osd232}{object}->write( chr(osdCTLvisible) . chr(0) );
}

=item C<background(COLOR)>

set the display background color

=cut

sub background {
    my ( $this, $color ) = @_;

    $main::Serial_Ports{osd232}{object}
      ->write( chr(osdCTLbgcolor) . chr($color) );
}

=item C<showpage(PAGE NAME)>

write a page of text to the osd232 buffer

=cut

sub showpage {
    my ( $this, $pagename ) = @_;

    if ( exists $this->{PAGES}->{$pagename} ) {
        $this->hidedisplay();
        $this->clearscreen();
        $this->background( $this->{PAGES}->{$pagename}->bgcolor() );
        $this->{PAGES}->{$pagename}->writedisplay();
        $this->showdisplay();
    }
}

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Brent DeShazer
brent@deshazer.net

=head2 SEE ALSO

See http://www.icircuits.com/prod_osd232.html and http://www.icircuits.com/prod_videostamp.html

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.



=head1 B<Display_osd232page>

=head2 SYNOPSIS

Page parameters

  PAGENAME - unique name of this page
  BGCOLOR - background color of this page
  FLIP - whether to display this page when doing timed flipping
  FLIPRATE - over-ride default flip rate for this page

Line parameters

  TEXT - text to display
  X - horizontal coordinate to display text at
  Y - vertical coordinate to display text at
  TEXTCOLOR - Color to display text in

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=cut

package Display_osd232page;

sub new {
    my $classname = shift;    # What class are we constructing?
    my $this      = {};       # Allocate new memory

    bless( $this, $classname );    # Mark it of the right type
    $this->_init(@_);              # Call _init with remaining args
    return $this;
}

sub _init {
    my $this = shift;
    $this->{LINES} = {};

    if (@_) {
        my %extra = @_;
        @$this{ keys %extra } = values %extra;
    }
    $this->pagename("Page") unless $this->pagename();

    #if a default background color isn't passed as a parameter
    #set this pages background to black
    $this->bgcolor(0) unless $this->{BGCOLOR};

    # flip to added pages by default unless explicity told not to
    $this->flip(1) unless $this->{FLIP};
}

=item C<pagename([NAME OF PAGE])>

set or return name of the page

=cut

sub pagename {
    my $this = shift;

    if (@_) { $this->{PAGENAME} = shift }
    return $this->{PAGENAME};
}

=item C<pageref()>

return an object reference to this page

=cut

sub pageref {
    my $this = shift;

    return $this;
}

=item C<bgcolor([COLOR])>

set or return the bakcground color for this page

=cut

sub bgcolor {
    my $this = shift;

    if (@_) { $this->{BGCOLOR} = shift }
    return $this->{BGCOLOR};
}

=item C<flip([0 - noflip, >=1 - flip])>

set or return whether this page is included in the flip rotation

=cut

sub flip {
    my $this = shift;

    if (@_) { $this->{FLIP} = shift }
    return $this->{FLIP};
}

=item C<fliprate([SECONDS])>

set or return the flip delay for this page

=cut

sub fliprate {
    my $this = shift;

    if (@_) { $this->{FLIPRATE} = shift }
    return $this->{FLIPRATE};
}

=item C<addline(LINE NAME,PARM1=>VALUE,PARM2=>VALUE,...)>

add a line to this page

=cut

sub addline {
    my $this = shift;

    if (@_) {
        my $line  = shift;
        my %extra = @_;
        $this->{LINES}->{$line} = {%extra};
    }
}

=item C<deleteline(LINE NAME)>

delete a line from this page

=cut

sub deleteline {
    my $this = shift;

    if (@_) {
        my $linename = shift;
        delete $this->{LINES}->{$linename}
          if exists $this->{LINES}->{$linename};
    }
}

=item C<values(LINE NAME,VALUE HASH KEY)>

set or return a value from a lines hash

=cut

sub linekeyvalue {
    my $this = shift;
    my $line = shift;
    my $key  = shift;

    if (@_) { $this->{LINES}->{$line}->{$key} = shift }
    return $this->{LINES}->{$line}->{$key};
}

=item C<settext("TEXT TO DISPLAY")>

A convenience function to change the text of a line.

=cut

sub settext {
    my ( $this, $line, $value ) = @_;

    $this->linekeyvalue( $line, "TEXT", $value );
}

=item C<print()>

Print all the elements of all lines of this page. Used for testing

=cut

sub print {
    my $this = shift;
    my $line;
    my $element;

    print "Page: " . $this->{PAGENAME} . "\n\n";
    foreach $line ( keys %{ $this->{LINES} } ) {
        print "Line: " . $line . "\n";
        foreach $element ( keys %{ $this->{LINES}->{$line} } ) {
            print $element;
            print " : ";
            print $this->{LINES}->{$line}->{$element};
            print "\n";
        }
        print "\n";
    }
}

=item C<writedisplay()>

Write the content of all lines to the osd232 display memory.  Note that whether it actually shows on the screen is dependant on whether we are currently hiding or showing the display!

=cut

sub writedisplay {
    my $this = shift;
    my $line;
    my $outstring;

    foreach $line ( keys %{ $this->{LINES} } ) {
        if ( $this->{LINES}->{$line}->{'X'} && $this->{LINES}->{$line}->{'Y'} )
        {
            $outstring =
                chr(129)
              . chr( $this->{LINES}->{$line}->{'X'} )
              . chr( $this->{LINES}->{$line}->{'Y'} );
        }
        if ( $this->{LINES}->{$line}->{'TEXTCOLOR'} ) {
            $outstring =
                $outstring
              . chr(135)
              . chr( $this->{LINES}->{$line}->{'TEXTCOLOR'} );
        }
        $outstring = $outstring . $this->{LINES}->{$line}->{'TEXT'};
        $main::Serial_Ports{osd232}{object}->write($outstring);
    }
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Brent DeShazer
brent@deshazer.net

=head2 SEE ALSO

See http://www.icircuits.com/prod_osd232.html and http://www.icircuits.com/prod_videostamp.html

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

