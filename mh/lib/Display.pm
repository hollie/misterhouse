# This is a perl TK version ... replaces winbatch display.wbt version
# perl TK faq is at: http://www.perl.com/CPAN-local/doc/FAQs/tk/ptkFAQ.html 

package Display;
use strict;

sub new {
    my ($class, $text, $time, $title, $font) = @_;
    $time = 120 unless defined $time;
    my $auto_quit = 1 unless $time == 0; 
    $title = 'Display Text' unless $title;
    my $self = {text => $text, time => $time, title => $title, auto_quit => $auto_quit, font => $font};
    bless $self, $class;
    &display($self);
    return $self;
}

sub read_text {

    my ($self) = @_;

                                # Gather text to display and find out how wide and tall it is 
    my $file = $$self{text};
    if (-e $file) { 
        $$self{text} = '';
        open IN, $file or die "Error, could not open file $file:$!\n"; 
        while (<IN>) { 
            my $length = length;
            $$self{width} = $length if $length > $$self{width}; 
            $$self{height}++; 
            $$self{height} += int($length/80); # Add more rows if we are line wrapping
            $$self{text} .= $_; 
        } 
        close IN;
    }
    else { 
        my $length = length($$self{text});
        $$self{width}  = $length;    # Not fair if we have \n, but good enough
        $$self{height} = $$self{text} =~ tr/\n//; # Count number of lines
        $$self{height} += int($length/80); # Add more rows if we are line wrapping
    }
    
    $$self{height} += 2;           # Allow for some margin
    $$self{width}  += 2;

    if ($$self{height} < 5) { 
        $$self{height} = 5; 
    }
    if ($$self{width} < 20) { 
        $$self{width} = 20; 
    }
    
    if ($$self{height} > 40) { 
        $$self{height} = 40; 
        $$self{scroll} = 'e'; 
    }
    else { 
        $$self{scroll} = 0; 
    }
    if ($$self{width} > 80) { 
        $$self{width} = 80; 
    }
}


sub display {
    
    my ($self) = @_;

                                # Do these in the calling pgm, so we can conditionally use in mh.bat
    use Tk; 
#   use Tk::Entry;      # Needed for perl2exe
#   use Tk::Button;     # Needed for perl2exe
#   use Tk::Text;       # Needed for perl2exe
#   use Tk::Scrollbar;      # Needed for perl2exe

#   use Tk::AddScrollbars;  # Needed for perl2exe


    &read_text($self);

    if ($main::MW) { 
        $$self{MW} = $main::MW->Toplevel; 
        $$self{loop} = 0;
    } 
    else { 
        $$self{MW} = MainWindow->new;  
        $$self{loop} = 1;
    } 
    $$self{MW}->withdraw;       # Hide until we are resized
    $$self{MW}->title($$self{title});

    my $f1 = $$self{MW}->Frame->pack; 
    my $b1 = $f1->Button(qw/-text Quit(ESC) -command/ => sub{$self->destroy})->pack(-side => 'left'); 
    my $l  = $f1->Label(-relief       => 'sunken', -width        => 5,
                        -textvariable => \$$self{time})->pack(-side => 'left'); 

    my $b2 = $f1->Button(qw/-text Pause(F1) 
                         -command/ => sub {$$self{auto_quit} = ($$self{auto_quit}) ? 0:1})->pack(-side => 'left'); 


# From tk font html docs:
# Courier, Times, or Helvetica 
# system,  ansi, device, systemfixed  ansifixed  oemfixed

    $$self{font} = 'Courier* 10 bold' unless $$self{font};
    $$self{font} = 'systemfixed'      if     $$self{font} eq 'fixed';

    # Valid fonts can be listed with xlsfonts 
    my $t1 = $$self{MW}->Scrolled('Text', -setgrid => 'true',  
                                  -width => $$self{width}, -height => $$self{height}, 
                                  -font => $$self{font},
#                                 -font => 'systemfixed',
                                  -wrap => 'word', -scrollbars => $$self{scroll}); 

    $t1->insert(('0.0', $$self{text})); 
    $t1->pack(qw/-expand yes -fill both -side bottom/); 

    $$self{MW}->repeat(1000, sub {return unless $$self{auto_quit}; 
                                  $$self{time}--;  
                                  $l->configure(textvariable => \$$self{time}); # Shouldn't have to do this
#                                 print "$$self{time} mw=$$self{MW}\n";
                                  $self->destroy unless $$self{time} > 0; 
#                 $b->configure(-text => "Quit (or ESC) auto-quit in $$self{time} seconds (F1 to toggle auto-quit)");; 
#                 $$self{MW}->withdraw if $$self{time} % 2;   ... test to hide and unhide a window
#                                 $$self{MW}->deiconify unless $$self{time} % 2;
                              }); 

    $$self{MW}->bind('<q>'         => sub{$self->destroy});
    $$self{MW}->bind('<Escape>'    => sub{$self->destroy});
    $$self{MW}->bind('<F3>'        => sub{$self->destroy});
    $$self{MW}->bind('<Control-c>' => sub{$self->destroy});

    $$self{MW}->bind('<F1>' => sub {$$self{auto_quit} = ($$self{auto_quit}) ? 0:1}); 

                                # Try everything to get focus
#   $$self{MW}->tkwait('visibility', $$self{MW}); 
    $$self{MW}->deiconify;
    $$self{MW}->raise;
    $$self{MW}->focusForce;
    $$self{MW}->focus('-force');
#   $$self{MW}->grabGlobal; 
#   $$self{MW}->grab("-global");  # This will disable the minimize-maximize-etc controls

    MainLoop if $$self{loop};

}

sub destroy {
    my ($self) = @_;
    # Normal exit IF Mainloop is local AND we were not called externally
    if ($$self{loop} and $0 =~ /display/) {
        $$self{MW}->destroy;
        exit;
#   &exit;
    }
    else {
#   print "db self=$self mw=$$self{MW}\n";
        $$self{MW}->destroy;
        return;
    }
}

return 1;

__END__

    # The following does not work ... MainLoop is best.
    DoOneEvent(0); 
print "start\n";
while (1) { 
    my $TK_WAIT        = 0x00;      # Wait for an event 
    my $TK_DONT_WAIT   = 0x01;      # Do not wait 
    my $TK_X_EVENTS    = 0x02;      # Do not wait 
    my $TK_FILE_EVENTS = 0x04;      # Do not wait 
    my $TK_TIMER_EVENTS= 0x08;      # Do not wait 
    my $TK_IDLE_EVENTS = 0x10;      # Do not wait 
    my $TK_ALL_EVENTS  = $TK_X_EVENTS | $TK_FILE_EVENTS | $TK_TIMER_EVENTS | $TK_IDLE_EVENTS; 
    my $tk_activity; 
    print "loop\n";
    while(1) { 
        last unless $tk_activity = DoOneEvent($TK_DONT_WAIT); 
        print "a=$tk_activity\n";
    } 
#    select undef,undef,undef,.1; #sub-second sleep 
#    sleep 1; 
    my $i; 
    print "a=$tk_activity", $i++, "\n"; 
}

#
# $Log$
# Revision 1.13  2000/01/27 13:38:47  winter
# - update version number
#
# Revision 1.12  1999/07/05 22:31:55  winter
# - refine the width and heigth calculations
#
# Revision 1.11  1999/05/30 21:09:10  winter
# - change default width from 100 to 80
#
# Revision 1.10  1999/03/28 00:32:33  winter
# - hide window on create, then unhide at the end
#
# Revision 1.9  1999/02/08 00:29:16  winter
# - do a eval use lib, so we can call from mh.exe
#
# Revision 1.8  1999/02/04 14:36:41  winter
# - take out debug
#
# Revision 1.7  1999/01/30 19:57:05  winter
# - change default width from 120 to 100
#
# Revision 1.6  1999/01/23 16:29:47  winter
# - no change
#
# Revision 1.5  1999/01/23 16:27:18  winter
# - only use TK (not the other TKs).  Tabbify.
#
# Revision 1.4  1999/01/07 01:58:04  winter
# - do not force focus
#
# Revision 1.3  1998/12/10 14:35:20  winter
# - do all kinds of stuff to force focus
#
# Revision 1.2  1998/12/07 14:34:28  winter
# - fix height/width calculation.  Fix global grab.
#
# Revision 1.1  1998/11/15 22:05:46  winter
# - add to CVS
#
#
#
