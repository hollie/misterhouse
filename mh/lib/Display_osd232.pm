=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	osd232.pm

Description:
	Allows for displaying one or more pages of text on an Intuitive
	Circuits OSD-232 On-screen display character overlay board with
	RS-232 interface. It should also support their VideoStamp product
	by simply setting the apprpriate baud rate, although I don't have
	one to test.

	See http://www.icircuits.com/prod_osd232.html and
	http://www.icircuits.com/prod_videostamp.html

Author:
	Brent DeShazer
	brent@deshazer.net

License:
	This free software is licensed under the terms of the GNU public license.

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;
package Display_osd232;

use vars qw(@ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA=qw(Exporter);

@EXPORT=qw(
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

use constant osdCLRblack=>0;
use constant osdCLRblue=>1;
use constant osdCLRgreen=>2;
use constant osdCLRcyan=>3;
use constant osdCLRred=>4;
use constant osdCLRmagenta=>5;
use constant osdCLRyellow=>6;
use constant osdCLRwhite=>7;

use constant osdCTLmode=>128;		# parm=1: 0=overlay, 1=full screen
use constant osdCTLposition=>129;	# parm=2: xpos(1-28), ypos(1-11)
use constant osdCTLclear=>130;		# parm=0: (wait 10 ms after command sent)
use constant osdCTLvisible=>131;	# parm=1: 0=hide text, 1=show text
use constant osdCTLtranslucent=>132;	# parm=1: 0=off, 1=on
use constant osdCTLbgcolor=>133;	# parm=1: see osdCLRxxxxxx above
use constant osdCTLzoom=>134;		# parm=3: zoom row (1-11), h-zoom (1-4), v-zoom (1-4)
use constant osdCTLcolor=>135;		# parm-1: see osdCLRxxxxxx above
use constant osdCTLblink=>136;		# parm=1: 0=off, 1=on
use constant osdCTLreset=>137;		# parm=0: (wait 10 ms after command sent)
use constant osdCTLvertoff=>138;	# parm=1: vertical position offset (1-63)
use constant osdCTLhorzoff=>139;	# parm=1: horizontal position offset (1-58)
use constant osdCTLframe=>140;		# parm=1: black character frame 0=off, 1=on

sub new {
    my $classname  = shift;         # What class are we constructing?
    my $this = {};             # Allocate new memory

    bless($this, $classname);       # Mark it of the right type
    $this->_init(@_);               # Call _init with remaining args
    return $this;
}

sub _init {
    my $this = shift;

    $this->{PAGES} = {};	# Hash to store the pages
    $this->{pagecount}=0;
    $this->{currentpage}=0;
    $this->{fliptimer}=&Timer::new();
    $this->{flipping}=0;
    $this->{fliparray}=[];	# Array to store list of flip-able pages
    if (@_) {			# Save any other initialization parameters
        my %extra = @_;
        @$this{keys %extra} = values %extra;
    }
    $this->{PORT}="/dev/osd232" unless $this->{PORT};
    $this->{SPEED}="4800" unless $this->{SPEED};
    &main::serial_port_create('osd232',$this->{PORT},$this->{SPEED},'none','raw');
    $this->reset();
}

# Add a page object
#
# $obj->addpage(NAME OF PAGE,REFERENCE TO PAGE OBJECT)
sub addpage {
    my $this = shift;

    if (@_) {
	my $pageref = shift;
	$this->{PAGES}->{$pageref->pagename()}=$pageref;
	$this->{pagecount}++;
	if ($pageref->flip()) {
	    push(@{$this->{fliparray}},$pageref->pagename());
	}
    }
}

# Remove a page object
#
# $obj->deletepage(NAME OF PAGE)
sub deletepage {
    my $this = shift;

    if (@_) {
	my $pagename=shift;
	delete $this->{PAGES}->{$pagename} if exists $this->{PAGES}->{$pagename};
	$this->{pagecount}--;
	# (***need code to re-do fliparray)
    }
}

# Print out an entire page
# Used for testing
#
# $obj->printpage(NAME OF PAGE)
sub printpage {
    my $this = shift;

    if (@_) {
	my $pagename = shift;
	$this->{PAGES}->{$pagename}->print() if exists $this->{PAGES}->{$pagename};
    }
}

# Start flipping between the defined pages
#
# $obj->startflipping()
sub startflipping {
    my $this = shift;

    my $flipcount=@{$this->{fliparray}};
    if ($flipcount>0) {
    &Timer::set($this->{fliptimer},$this->currentfliprate());
	$this->{flipping}=1;
    }
}

# Stop flipping pages, the screen will be left on whatever
# page was last displayed
#
# $obj->stopflipping()
sub stopflipping {
    my $this = shift;

    if ($this->flipping()) {
	$this->{flipping}=0;
    }
    &Timer::stop($this->{fliptimer});
}

# Flip to the next page
#
# (*** need option to flip to specific page)
#
# $obj->flippage()
sub flippage{
    my $this = shift;

    $this->{currentpage}++;
    if ($this->{currentpage} > (@{$this->{fliparray}}-1)) {
	$this->{currentpage}=0;
    }
    $this->showpage(@{$this->{fliparray}}[$this->{currentpage}]);
    &Timer::set($this->{fliptimer},$this->currentfliprate());
}

# Get the length of time to display the current page we're
# flipping to. This is either the pages custom flip rate or
# the default flip rate if a custom one has not been defined
#
# $obj->currentfliprate()
sub currentfliprate{
    my $this = shift;
    my $pagename=@{$this->{fliparray}}[$this->{currentpage}];

    return $this->fliprate() unless $this->{PAGES}->{$pagename}->fliprate();
    return $this->{PAGES}->{$pagename}->fliprate();
}

# Set or return the name of the control port
#
# $obj->port([PORT NAME])
sub port {
    my $this = shift;

    if (@_) { $this->{PORT} = shift }
    return $this->{PORT};
}

# Set or return the port port speed
#
# $obj->speed([PORT SPEED])
sub speed {
    my $this = shift;

    if (@_) { $this->{SPEED} = shift }
    return $this->{SPEED};
}

# Set or return the default page flip rate
# This is the number of seconds we show pages
# that don't have their own flip rate defined
#
# $obj->fliprate([PAGE FLIP RATE])
sub defaultfliprate {
    my $this = shift;

    if (@_) { $this->{FLIPRATE} = shift }
    return $this->{FLIPRATE};
}

# Reset the osd232
# requires minimum of 10ms delay after reset command
#
# $obj->reset()
sub reset {
    my $this = shift;

    $main::Serial_Ports{osd232}{object}->write(chr(osdCTLreset));
    select undef, undef, undef, 0.02; # delay 20ms just to be safe
    $this->{overlay}=1 unless $this->{overlay};
    $main::Serial_Ports{osd232}{object}->write(chr(osdCTLmode).chr($this->{overlay}));
    $this->clearscreen();
}

# Clear the osd232 display
# requires minimum of 10ms delay after command
#
# $obj->clearscreen();
sub clearscreen {
    $main::Serial_Ports{osd232}{object}->write(chr(osdCTLclear));
    select undef, undef, undef, 0.02; # delay 20ms just to be safe
}

# (***Combine showdisplay and hidedisplay to a single function with
# a parameter determining whether to show or hide)

# $obj->showdisplay();
#
# show the current osd232 display text on the video output signal
sub showdisplay {
    $main::Serial_Ports{osd232}{object}->write(chr(osdCTLvisible).chr(1));
}

# $obj->hidedisplay();
#
# hide the current osd232 display text on the video output signal
sub hidedisplay {
    $main::Serial_Ports{osd232}{object}->write(chr(osdCTLvisible).chr(0));
}

# $obj->background(COLOR);
#
# set the display background color
sub background {
    my ($this,$color) = @_;

    $main::Serial_Ports{osd232}{object}->write(chr(osdCTLbgcolor).chr($color));
}

# $obj->showpage(PAGE NAME)
#
# write a page of text to the osd232 buffer
sub showpage {
    my ($this,$pagename)=@_;

    if (exists $this->{PAGES}->{$pagename}) {
	$this->hidedisplay();
	$this->clearscreen();
	$this->background($this->{PAGES}->{$pagename}->bgcolor());
        $this->{PAGES}->{$pagename}->writedisplay();
	$this->showdisplay();
    }
}

package Display_osd232page;

# Page parameters
#
# PAGENAME - unique name of this page
# BGCOLOR - background color of this page
# FLIP - whether to display this page when doing timed flipping
# FLIPRATE - over-ride default flip rate for this page
#
# Line parameters
#
# TEXT - text to display
# X - horizontal coordinate to display text at
# Y - vertical coordinate to display text at
# TEXTCOLOR - Color to display text in
#
sub new {
    my $classname  = shift;         # What class are we constructing?
    my $this = {};             # Allocate new memory

    bless($this, $classname);       # Mark it of the right type
    $this->_init(@_);               # Call _init with remaining args
    return $this;
}

sub _init {
    my $this = shift;
    $this->{LINES} = {};

    if (@_) {
        my %extra = @_;
        @$this{keys %extra} = values %extra;
    }
    $this->pagename("Page") unless $this->pagename();
    #if a default background color isn't passed as a parameter
    #set this pages background to black
    $this->bgcolor(0) unless $this->{BGCOLOR};
    # flip to added pages by default unless explicity told not to
    $this->flip(1) unless $this->{FLIP};
}

# set or return name of the page
#
# $obj->pagename([NAME OF PAGE])
sub pagename {
    my $this = shift;

    if (@_) { $this->{PAGENAME} = shift }
    return $this->{PAGENAME};
}

# return an object reference to this page
#
# $obj->pageref()
sub pageref {
    my $this = shift;

    return $this;
}

# set or return the bakcground color for this page
#
# $obj->bgcolor([COLOR])
sub bgcolor {
    my $this = shift;

    if (@_) { $this->{BGCOLOR} = shift }
    return $this->{BGCOLOR};
}

# set or return whether this page is included in the flip rotation
#
# $obj->flip([0 - noflip, >=1 - flip])
sub flip {
    my $this = shift;

    if (@_) { $this->{FLIP} = shift }
    return $this->{FLIP};
}

# set or return the flip delay for this page
#
# $obj->fliprate([SECONDS])
sub fliprate {
    my $this = shift;

    if (@_) { $this->{FLIPRATE} = shift }
    return $this->{FLIPRATE};
}

# add a line to this page
#
# $obj->addline(LINE NAME,PARM1=>VALUE,PARM2=>VALUE,...)
sub addline {
    my $this = shift;

    if (@_) {
    	my $line=shift;
        my %extra = @_;
	$this->{LINES}->{$line}={%extra};
    }
}

# delete a line from this page
#
# $obj->deleteline(LINE NAME)
sub deleteline {
    my $this = shift;

    if (@_) {
        my $linename=shift;
        delete $this->{LINES}->{$linename} if exists $this->{LINES}->{$linename};
    }
}

# set or return a value from a lines hash
#
# $obj->values(LINE NAME,VALUE HASH KEY)
sub linekeyvalue {
    my $this = shift;
    my $line = shift;
    my $key = shift;

    if (@_) { $this->{LINES}->{$line}->{$key} = shift }
    return $this->{LINES}->{$line}->{$key};
}

# A convenience function to change the text of a line.
#
# $obj->settext("TEXT TO DISPLAY")
sub settext {
    my ($this,$line,$value)=@_;

    $this->linekeyvalue($line,"TEXT",$value);
}

# Print all the elements of all lines of this page
# Used for testing
#
# $obj->print()
sub print {
    my $this = shift;
    my $line;
    my $element;

    print "Page: ".$this->{PAGENAME}."\n\n";
    foreach $line (keys %{$this->{LINES}}) {
	print "Line: ".$line."\n";
	foreach $element (keys %{$this->{LINES}->{$line}}) {
            print $element;
	    print " : ";
	    print $this->{LINES}->{$line}->{$element};
	    print "\n";
	}
    print "\n";
    }
}

# Write the content of all lines to the osd232 display memory
# Note that whether it actually shows on the screen is dependant
# on whether we are currently hiding or showing the display!
#
# $obj->writedisplay()
    sub writedisplay {
    my $this=shift;
    my $line;
    my $outstring;

    foreach $line (keys %{$this->{LINES}}) {
	if ($this->{LINES}->{$line}->{'X'} && $this->{LINES}->{$line}->{'Y'}) {
	    $outstring=chr(129).chr($this->{LINES}->{$line}->{'X'}).chr($this->{LINES}->{$line}->{'Y'});
	}
	if ($this->{LINES}->{$line}->{'TEXTCOLOR'}) {
	    $outstring=$outstring.chr(135).chr($this->{LINES}->{$line}->{'TEXTCOLOR'});
	}
	$outstring=$outstring.$this->{LINES}->{$line}->{'TEXT'};
	$main::Serial_Ports{osd232}{object}->write($outstring);
    }
}

1;
