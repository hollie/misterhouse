# This is a perl TK version ... replaces winbatch display.wbt version
# perl TK faq is at: http://www.perl.com/CPAN-local/doc/FAQs/tk/ptkFAQ.html 

package Display;
use strict;

my %Windows;

sub new {
    my ($class, $text, $time, $title, $font, $window_name, $append) = @_;
    $time = 120 unless defined $time;
    my $auto_quit = 1 unless $time == 0; 
    $title = 'Display Text' unless $title;
    my $self = {text => $text, time => $time, title => $title,
                auto_quit => $auto_quit, font => $font, 
                window_name => $window_name, append => $append};
    bless $self, $class;
    &display($self);
    return $self;
}

sub read_text {

    my ($self) = @_;

    return unless $$self{text};

                                # Gather text to display and find out how wide and tall it is 
    my $file;
    my @data;
    if ($$self{text} =~ /^\S+$/ and -e $$self{text}) { 
        $file = $$self{text};
#       print "db testing $file\n";
        if ($file =~ /\.gif$/i or $file =~ /\.jpg$/i or $file =~ /\.png$/i) {
            $$self{type} = 'photo';
            $$self{title} = "Image: $file";
            return;
        }
        $$self{text} = '';
        open IN, $file or die "Error, could not open file $file:$!\n"; 
        @data = <IN>;
        close IN;
    }
    else { 
        @data = split /\n/, $$self{text};
    }
                                # Find width and height of text
    while (@data) {
        $_ = shift @data;
        my $length = length;
        $$self{width} = $length if !$$self{width} or $length > $$self{width}; 
        $$self{height}++; 
        $$self{height} += int($length/100); # Add more rows if we are line wrapping
        $$self{text} .= $_ if $file;
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
    if ($$self{width} > 150) { 
        $$self{width} = 150; 
    }
    if ($$self{append}) {
        $$self{width} = 100;
        $$self{scroll} = 'se';
    }
}

sub display {
    
    my ($self) = @_;

                                # Do these in the calling pgm, so we can conditionally use in mh.bat
    use Tk; 
    eval "use Tk::JPEG";        # Might not have Tk::JPEG installed
#   print "\nTk::JPEG not installed\n" if $@;

    &read_text($self);

                                # Reuse existing window if present
    my $reuse_flag;
    if ($$self{window_name} and $Windows{$$self{window_name}}) {
        $$self{MW} = $Windows{$$self{window_name}}{mw}; 
        $$self{loop} = 0;
        $reuse_flag++;
    }
                                # New window from main tk 
    elsif ($main::MW) { 
        $$self{MW} = $main::MW->Toplevel; 
        $$self{loop} = 0;
        $Windows{$$self{window_name}}{mw} = $$self{MW} if $$self{window_name};
    } 
                                # Stand alone use (not from mh tk window)
    else { 
        $$self{MW} = MainWindow->new;  
        $$self{loop} = 1;
    } 

    my $l;
    unless ($reuse_flag) {
        $$self{MW}->withdraw;       # Hide until we are resized
        $$self{MW}->title($$self{title});

        my $f1 = $$self{MW}->Frame->pack; 
        my $b1 = $f1->Button(qw/-text Quit(ESC) -command/ => sub{$self->destroy})->pack(-side => 'left'); 
           $l  = $f1->Label(-relief       => 'sunken', -width        => 5,
                            -textvariable => \$$self{time})->pack(-side => 'left'); 

        my $b2 = $f1->Button(qw/-text Pause(F1) 
                             -command/ => sub {$$self{auto_quit} = ($$self{auto_quit}) ? 0:1})->pack(-side => 'left'); 
    }

    if ($$self{type} and $$self{type} eq 'photo') {
        print "db pic\n";
        $$self{photo1} = $$self{MW}->Photo(-file => $$self{text});
#       $$self{MW}->Button(-text => 'Photo', -command => sub {$self->destroy}, -image => $$self{photo1}) ->
        $$self{photo2} = $$self{MW}->Label(-text => 'Photo', -image => $$self{photo1}) ->
            pack(qw/-expand yes -fill both -side bottom/); 
    }
    else {
# From tk font html docs:
#    Courier, Times, or Helvetica 
#    system,  ansi, device, systemfixed  ansifixed  oemfixed

#       $$self{font} = 'Courier* 10 bold' unless $$self{font};
#       $$self{font} = 'system'           unless $$self{font};
#       $$self{font} = 'systemfixed'      if     $$self{font} eq 'fixed';
        $$self{font} = 'Times 10 bold'   unless $$self{font};
        $$self{font} = 'Courier 10 bold'  if    $$self{font} eq 'fixed';

                                # Valid fonts can be listed with xlsfonts 
        my $t1;
        if ($reuse_flag) {
            $t1 = $Windows{$$self{window_name}}{t1};
            if ($$self{append} eq 'bottom') {
                                # If we put at end, tk does not auto-scroll :(
                $t1->insert(('end', $$self{text})); 
            }
            elsif ($$self{append}) {
                $t1->insert(('0.0', $$self{text})); 
            }
            else {
                $t1->delete(('0.0', 'end')); 
                $t1->insert(('0.0', $$self{text})); 
            }
        }
        else {
            $t1 = $$self{MW}->Scrolled('Text', -setgrid => 'true',  
                                          -width => $$self{width}, -height => $$self{height}, 
                                          -font => $$self{font},
#                                         -font => 'systemfixed',
                                          -wrap => 'word', -scrollbars => $$self{scroll}); 
            $Windows{$$self{window_name}}{t1} = $t1;

            $t1->insert(('0.0', $$self{text})); 
            $t1->pack(qw/-expand yes -fill both -side bottom/); 
        }
    }

    $$self{MW}->repeat(1000, sub {return unless $$self{auto_quit}; 
                                  $$self{time}--;  
                                  $l->configure(textvariable => \$$self{time}); # Shouldn't have to do this
#                                 print "$$self{time} mw=$$self{MW}\n";
                                  $self->destroy unless $$self{time} > 0; 
#                                 $b->configure(-text => "Quit (or ESC) auto-quit in $$self{time} seconds (F1 to toggle auto-quit)");; 
#                                   $$self{MW}->withdraw if $$self{time} % 2;   ... test to hide and unhide a window
#                                     $$self{MW}->deiconify unless $$self{time} % 2;
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

                                # Try to avoid a memory leak with photo objects ... doesn't work :(
    $$self{photo2}->destroy if $$self{photo2};
    $$self{photo1}->destroy if $$self{photo1};
    delete $$self{photo1};
    delete $$self{photo2};
    delete $Windows{$$self{window_name}} if $$self{window_name};

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
# Revision 1.20  2001/09/23 19:28:11  winter
# - 2.59 release
#
# Revision 1.19  2001/05/28 21:14:38  winter
# - 2.52 release
#
# Revision 1.18  2001/02/04 20:31:31  winter
# - 2.43 release
#
# Revision 1.17  2001/01/20 17:47:50  winter
# - 2.41 release
#
# Revision 1.16  2000/08/19 01:22:36  winter
# - 2.27 release
#
# Revision 1.15  2000/05/06 17:22:16  winter
# - change default fonts
#
# Revision 1.14  2000/05/06 16:34:32  winter
# - 2.15 release
#
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
