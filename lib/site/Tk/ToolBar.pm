
package Tk::ToolBar;

use strict;
use Tk::Frame;
use Tk::Balloon;

use base qw/Tk::Frame/;
use Tk::widgets qw(Frame);

use Carp;
use POSIX qw/ceil/;

Construct Tk::Widget 'ToolBar';

use vars qw/$VERSION/;
$VERSION = 0.09;

my $edgeH = 24;
my $edgeW = 5;

my $sepH  = 24;
my $sepW  = 3;

my %sideToSticky = qw(
		      top    n
		      right  e
		      left   w
		      bottom s
		      );

my $packIn     = '';
my @allWidgets = ();
my $floating   = 0;
my %packIn;
my %containers;
my %isDummy;

1;

sub ClassInit {
    my ($class, $mw) = @_;
    $class->SUPER::ClassInit($mw);

    # load the images.
    my $imageFile = Tk->findINC('ToolBar/tkIcons');

    if (defined $imageFile) {
	local *F;
	open F, $imageFile;

	local $_;

	while (<F>) {
	    chomp;
	    my ($n, $d) = (split /:/)[0, 4];

	    $mw->Photo($n, -data => $d);
	}
	close F;
    } else {
	carp <<EOW;
WARNING: can not find tkIcons. Your installation of Tk::ToolBar is broken.
         No icons will be loaded.
EOW
;
    }
}

sub Populate {
    my ($self, $args) = @_;

    $self->SUPER::Populate($args);
    $self->{MW}     = $self->parent;
    $self->{SIDE}   = exists $args->{-side}          ? delete $args->{-side}          : 'top';
    $self->{STICKY} = exists $args->{-sticky}        ? delete $args->{-sticky}        : 'nsew';
    $self->{USECC}  = exists $args->{-cursorcontrol} ? delete $args->{-cursorcontrol} : 1;
    $self->{STYLE}  = exists $args->{-mystyle}       ? delete $args->{-mystyle}       : 0;
    $packIn         = exists $args->{-in}            ? delete $args->{-in}            : '';

    if ($packIn) {
      unless ($packIn->isa('Tk::ToolBar')) {
	croak "value of -packin '$packIn' is not a Tk::ToolBar object";
      } else {
	$self->{SIDE} = $packIn->{SIDE};
      }
    }

    unless ($self->{STICKY} =~ /$sideToSticky{$self->{SIDE}}/) {
	croak "can't place '$self->{STICKY}' toolbar on '$self->{SIDE}' side";
    }

    $self->{CONTAINER} = $self->{MW}->Frame;
    $self->_packSelf;

    my $edge = $self->{CONTAINER}->Frame(qw/
					 -borderwidth 2
					 -relief ridge
					 /);

    $self->{EDGE} = $edge;

    $self->_packEdge($edge, 1);

    $self->ConfigSpecs(
		       -movable          => [qw/METHOD  movable          Movable             1/],
		       -close            => [qw/PASSIVE close            Close              15/],
		       -activebackground => [qw/METHOD  activebackground ActiveBackground/, Tk::ACTIVE_BG],
		       -indicatorcolor   => [qw/PASSIVE indicatorcolor   IndicatorColor/,   '#00C2F1'],
		       -indicatorrelief  => [qw/PASSIVE indicatorrelief  IndicatorRelief    flat/],
		       -float            => [qw/PASSIVE float            Float              1/],
		      );

    push @allWidgets => $self;

    $containers{$self->{CONTAINER}} = $self;

    $self->{BALLOON} = $self->{MW}->Balloon;

    # check for Tk::CursorControl
    $self->{CC} = undef;
    if ($self->{USECC}) {
	local $^W = 0; # suppress message from Win32::API
	eval "require Tk::CursorControl";
	unless ($@) {
	    # CC is installed. Use it.
	    $self->{CC} = $self->{MW}->CursorControl;
	}
    }
}

sub activebackground {
    my ($self, $c) = @_;

    return unless $c; # ignore falses.

    $self->{ACTIVE_BG} = $c;
}

sub _packSelf {
    my $self = shift;

    my $side = $self->{SIDE};
    my $fill = 'y';
    if ($side eq 'top' or $side eq 'bottom') { $fill = 'x' }

    if ($packIn && $packIn != $self) {
	my $side = $packIn->{SIDE} =~ /top|bottom/ ? 'left' : 'top';

	$self->{CONTAINER}->pack(-in => $packIn->{CONTAINER},
				 -side => $side,
				 -anchor => ($fill eq 'x' ? 'w' : 'n'),
				 -expand => 0);
	$self->{CONTAINER}->raise;
	$packIn{$self->{CONTAINER}} = $packIn->{CONTAINER};
    } else {
	# force a certain look! for now.
	my $slave = ($self->{MW}->packSlaves)[0];

	$self->configure(qw/-relief raised -borderwidth 1/);
	$self->pack(-side => $side, -fill => $fill,
		    $slave ? (-before => $slave) : ()
		    );

	$self->{CONTAINER}->pack(-in => $self,
				 -anchor => ($fill eq 'x' ? 'w' : 'n'),
				 -expand => 0);

	$packIn{$self->{CONTAINER}} = $self;
    }
}

sub _packEdge {
    my $self = shift;
    my $e    = shift;
    my $w    = shift;

    my $s    = $self->{SIDE};

    my ($pack, $pad, $nopad, $fill);

    if ($s eq 'top' or $s eq 'bottom') {
      if ($w) {
	$e->configure(-height => $edgeH, -width => $edgeW);
      } else {
	$e->configure(-height => $sepH, -width => $sepW);
      }
      $pack  = 'left';
      $pad   = '-padx';
      $nopad = '-pady';
      $fill  = 'y';
    } else {
      if ($w) {
	$e->configure(-height => $edgeW, -width => $edgeH);
      } else {
	$e->configure(-height => $sepW, -width => $sepH);
      }

      $pack  = 'top';
      $pad   = '-pady';
      $nopad = '-padx';
      $fill  = 'x';
    }

    if (exists $self->{SEPARATORS}{$e}) {
	$e->configure(-cursor => $pack eq 'left' ? 'sb_h_double_arrow' : 'sb_v_double_arrow');
	$self->{SEPARATORS}{$e}->pack(-side   => $pack,
				      -fill   => $fill);
    }

    $e->pack(-side  => $pack, $pad => 5,
	     $nopad => 0,  -expand => 0);
}

sub movable {
    my ($self, $value) = @_;

    if (defined $value) {
	$self->{ISMOVABLE} = $value;
	my $e = $self->_edge;

	if ($value) {
	    $e->configure(qw/-cursor fleur/);
	    $self->afterIdle(sub {$self->_enableEdge()});
	} else {
	    $e->configure(-cursor => undef);
	    $self->_disableEdge($e);
	}
    }

    return $self->{ISMOVABLE};
}

sub _enableEdge {
  my ($self) = @_;

  my $e     = $self->_edge;
  my $hilte = $self->{MW}->Frame(-bg     => $self->cget('-indicatorcolor'),
				 -relief => $self->cget('-indicatorrelief'));

  my $dummy = $self->{MW}->Frame(
				 qw/
				 -borderwidth 2
				 -relief ridge
				 /);

  $self->{DUMMY} = $dummy;

  my $drag     = 0;
  #my $floating = 0;
  my $clone;

  my @mwSize;  # extent of mainwindow.

  $e->bind('<1>'         => sub {
	     $self->{CC}->confine($self->{MW}) if defined $self->{CC};
	     my $geom      = $self->{MW}->geometry;
	     my ($rx, $ry) = ($self->{MW}->rootx, $self->{MW}->rooty);

	     if ($geom =~ /(\d+)x(\d+)/) {#\+(\d+)\+(\d+)/) {
#	       @mwSize = ($3, $4, $1 + $3, $2 + $4);
	       @mwSize = ($rx, $ry, $1 + $rx, $2 + $ry);
	     } else {
	       @mwSize = ();
	     }

	     if (!$self->{ISCLONE} && $self->{CLONE}) {
	       $self->{CLONE}->destroy;
	       $self->{CLONE} = $clone = undef;
	       @allWidgets = grep Tk::Exists, @allWidgets;
	     }

	   });

  $e->bind('<B1-Motion>' => sub {
	     my ($x, $y) = ($self->pointerx - $self->{MW}->rootx - ceil($e->width /2) - $e->x,
			    $self->pointery - $self->{MW}->rooty - ceil($e->height/2) - $e->y);

	     my ($px, $py) = $self->pointerxy;

	     $dummy = $self->{ISCLONE} ? $self->{CLONE}{DUMMY} : $self->{DUMMY};

	     unless ($drag or $floating) {
	       $drag = 1;
	       $dummy->raise;
	       my $noclone = $self->{ISCLONE} ? $self->{CLONE} : $self;
	       $noclone->packForget;
	       $noclone->{CONTAINER}->pack(-in => $dummy);
	       $noclone->{CONTAINER}->raise;
	       ref($_) eq 'Tk::Frame' && $_->raise for $noclone->{CONTAINER}->packSlaves;
	     }
	     $hilte->placeForget;

	     if ($self->cget('-float') &&
		 (@mwSize and
		 $px < $mwSize[0] or
		 $py < $mwSize[1] or
		 $px > $mwSize[2] or
		 $py > $mwSize[3])) {

	       # we are outside .. switch to toplevel mode.
	       $dummy->placeForget;
	       $floating = 1;

	       unless ($self->{CLONE} || $self->{ISCLONE}) {
		 # clone it.
		 my $clone = $self->{MW}->Toplevel(qw/-relief ridge -borderwidth 2/);
		 $clone->withdraw;
		 $clone->overrideredirect(1);
		 $self->_clone($clone);
		 $self->{CLONE} = $clone;
	       }

	       $clone = $self->{ISCLONE} || $self->{CLONE};
	       $clone->deiconify unless $clone->ismapped;
	       $clone->geometry("+$px+$py");

	     } else {
	       $self->{ISCLONE}->withdraw if $self->{CLONE} && $self->{ISCLONE};

	       $dummy->place('-x' => $x, '-y' => $y);
	       $floating = 0;

	       if (my $newSide = $self->_whereAmI($x, $y)) {
		 # still inside main window.
		 # highlight the close edge.
		 $clone && $clone->ismapped && $clone->withdraw;
		 #$self->{ISCLONE}->withdraw if $self->{CLONE} && $self->{ISCLONE};

		 my ($op, $pp);
		 if ($newSide =~ /top/) {
		   $op = [qw/-height 5/];
		   $pp = [qw/-relx 0 -relwidth 1 -y 0/];
		 } elsif ($newSide =~ /bottom/) {
		   $op = [qw/-height 5/];
		   $pp = [qw/-relx 0 -relwidth 1 -y -5 -rely 1/];
		 } elsif ($newSide =~ /left/) {
		   $op = [qw/-width 5/];
		   $pp = [qw/-x 0 -relheight 1 -y 0/];
		 } elsif ($newSide =~ /right/) {
		   $op = [qw/-width 5/];
		   $pp = [qw/-x -5 -relx 1 -relheight 1 -y 0/];
		 }

		 $hilte->configure(@$op);
		 $hilte->place(@$pp);
		 $hilte->raise;
	       }
	     }
	   });

    $e->bind('<ButtonRelease-1>' => sub {
	my $noclone = $self->{ISCLONE} ? $self->{CLONE} : $self;
	$noclone->{CC}->free($noclone->{MW}) if defined $noclone->{CC};
	return unless $drag;

	$drag = 0;
	$dummy->placeForget;

	# forget everything if it's cloned.
	return if $clone && $clone->ismapped;

	# destroy the clone.
	#$clone->destroy;

	#return unless $self->_whereAmI(1);
	$noclone->_whereAmI(1);
	$hilte->placeForget;

	# repack everything now.
	my $ec = $noclone->_edge;
	my @allSlaves = grep {$_ ne $ec} $noclone->{CONTAINER}->packSlaves;
	$_   ->packForget for $noclone, @allSlaves, $noclone->{CONTAINER};

	$noclone->_packSelf;
	$noclone->_packEdge($ec, 1);
	$noclone->_packWidget($_) for @allSlaves;
    });
}

sub _whereAmI {
    my $self = shift;

    my $flag = 0;
    my ($x, $y);

    if (@_ == 1) {
	$flag = shift;
	my $e    = $self->_edge;
	($x, $y) = ($self->pointerx - $self->{MW}->rootx - ceil($e->width /2) - $e->x,
		    $self->pointery - $self->{MW}->rooty - ceil($e->height/2) - $e->y);
    } else {
	($x, $y) = @_;
    }

    my $x2 = $x + $self->{CONTAINER}->width;
    my $y2 = $y + $self->{CONTAINER}->height;

    my $w  = $self->{MW}->Width;
    my $h  = $self->{MW}->Height;

    # bound check
    $x     = 1      if $x  <= 0;
    $y     = 1      if $y  <= 0;
    $x     = $w - 1 if $x  >= $w;
    $y     = $h - 1 if $y  >= $h;

    $x2    = 0      if $x2 <= 0;
    $y2    = 0      if $y2 <= 0;
    $x2    = $w - 1 if $x2 >= $w;
    $y2    = $h - 1 if $y2 >= $h;

    my $dx = 0;
    my $dy = 0;

    my $close = $self->cget('-close');

    if    ($x       < $close) { $dx = $x }
    elsif ($w - $x2 < $close) { $dx = $x2 - $w }

    if    ($y       < $close) { $dy = $y }
    elsif ($h - $y2 < $close) { $dy = $y2 - $h }

    $packIn       = '';
    if ($dx || $dy) {
	my $newSide;
	if ($dx && $dy) {
	    # which is closer?
	    if (abs($dx) < abs($dy)) {
		$newSide = $dx > 0 ? 'left' : 'right';
	    } else {
		$newSide = $dy > 0 ? 'top' : 'bottom';
	    }
	} elsif ($dx) {
	    $newSide = $dx > 0 ? 'left' : 'right';
	} else {
	    $newSide = $dy > 0 ? 'top' : 'bottom';
	}

	# make sure we're stickable on that side.
	return undef unless $self->{STICKY} =~ /$sideToSticky{$newSide}/;

	$self->{SIDE} = $newSide if $flag;
	return $newSide;
    } elsif ($flag) {
	# check for overlaps.
	for my $w (@allWidgets) {
	    next if $w == $self;

	    my $x1 = $w->x;
	    my $y1 = $w->y;
	    my $x2 = $x1 + $w->width;
	    my $y2 = $y1 + $w->height;

	    if ($x > $x1 and $y > $y1 and $x < $x2 and $y < $y2) {
		$packIn = $w;
		last;
	    }
	}

      $self->{SIDE} = $packIn->{SIDE} if $packIn;
#	if ($packIn) {
#	  $self->{SIDE} = $packIn->{SIDE};
#	} else {
#	  return undef;
#	}
    } else {
	return undef;
    }

    return 1;
}

sub _disableEdge {
    my ($self, $e) = @_;

    $e->bind('<B1-Motion>'       => undef);
    $e->bind('<ButtonRelease-1>' => undef);
}

sub _edge {
    $_[0]->{EDGE};
}

sub ToolButton {
    my $self = shift;
    my %args = @_;

    my $type = delete $args{-type} || 'Button';

    unless ($type eq 'Button' or
	    $type eq 'Checkbutton' or
	    $type eq 'Menubutton' or
	    $type eq 'Radiobutton') {

	croak "toolbutton can be only 'Button', 'Menubutton', 'Checkbutton', or 'Radiobutton'";
    }

    my $m = delete $args{-tip}         || '';
    my $x = delete $args{-accelerator} || '';

    my $b = $self->{CONTAINER}->$type(%args,
				      $self->{STYLE} ? () : (
							     -relief      => 'flat',
							     -borderwidth => 1,
							    ),
				     );

    $self->_createButtonBindings($b);
    $self->_configureWidget     ($b);

    push @{$self->{WIDGETS}} => $b;
    $self->_packWidget($b);

    $self->{BALLOON}->attach($b, -balloonmsg => $m) if $m;
    $self->{MW}->bind($x => [$b, 'invoke'])         if $x;

    # change the bind tags.
    #$b->bindtags([$b, ref($b), $b->toplevel, 'all']);

    return $b;
}

sub ToolLabel {
    my $self = shift;

    my $l = $self->{CONTAINER}->Label(@_);

    push @{$self->{WIDGETS}} => $l;

    $self->_packWidget($l);

    return $l;
}

sub ToolEntry {
    my $self = shift;
    my %args = @_;

    my $m = delete $args{-tip} || '';
    my $l = $self->{CONTAINER}->Entry(%args, -width => 5);

    push @{$self->{WIDGETS}} => $l;

    $self->_packWidget($l);
    $self->{BALLOON}->attach($b, -balloonmsg => $m) if $m;

    return $l;
}

sub ToolLabEntry {
    my $self = shift;
    my %args = @_;

    require Tk::LabEntry;
    my $m = delete $args{-tip} || '';
    my $l = $self->{CONTAINER}->LabEntry(%args, -width => 5);

    push @{$self->{WIDGETS}} => $l;

    $self->_packWidget($l);
    $self->{BALLOON}->attach($b, -balloonmsg => $m) if $m;

    return $l;
}

sub ToolOptionmenu {
    my $self = shift;
    my %args = @_;

    my $m = delete $args{-tip} || '';
    my $l = $self->{CONTAINER}->Optionmenu(%args);

    push @{$self->{WIDGETS}} => $l;

    $self->_packWidget($l);
    $self->{BALLOON}->attach($b, -balloonmsg => $m) if $m;

    return $l;
}

sub separator {
    my $self = shift;
    my %args = @_;

    my $move = 1;
    $move    = $args{-movable} if exists $args{-movable};
    my $just = $args{-space} || 0;

    my $f    = $self->{CONTAINER}->Frame(-width => $just, -height => 0);

    my $sep  = $self->{CONTAINER}->Frame(qw/
					 -borderwidth 5
					 -relief sunken
					 /);

    $isDummy{$f} = $self->{SIDE};

    push @{$self->{WIDGETS}} => $sep;
    $self->{SEPARATORS}{$sep} = $f;
    $self->_packWidget($sep);

    $self->_createSeparatorBindings($sep) if $move;

    if ($just eq 'right' || $just eq 'bottom') {
      # just figure out the good width.
    }

    return 1;
}

sub _packWidget {
    my ($self, $b) = @_;

    return $self->_packEdge($b) if exists $self->{SEPARATORS}{$b};

    my ($side, $pad, $nopad) = $self->{SIDE} =~ /^top$|^bottom$/ ? 
	qw/left -padx -pady/ : qw/top -pady -padx/;

    if (ref($b) eq 'Tk::LabEntry') {
	$b->configure(-labelPack => [-side => $side]);
    }

    my @extra;
    if (exists $packIn{$b}) {
	@extra = (-in => $packIn{$b});

	# repack everything now.
	my $top = $containers{$b};
	$top->{SIDE} = $self->{SIDE};

	my $e = $top->_edge;
	my @allSlaves = grep {$_ ne $e} $b->packSlaves;
	$_   ->packForget for @allSlaves;

	$top->_packEdge($e, 1);
	$top->_packWidget($_) for @allSlaves;
    }

    if (exists $isDummy{$b}) { # swap width/height if we need to.
	my ($w, $h);

	if ($side eq 'left' && $isDummy{$b} =~ /left|right/) {
	    $w = 0;
	    $h = $b->height;
	} elsif ($side eq 'top'  && $isDummy{$b} =~ /top|bottom/) {
	    $w = $b->width;
	    $h = 0;
	}

	$b->configure(-width => $h, -height => $w) if defined $w;
	$isDummy{$b} = $self->{SIDE};
    }

    $b->pack(-side => $side, $pad => 4, $nopad => 0, @extra);
}

sub _packWidget_old {
    my ($self, $b) = @_;

    return $self->_packEdge($b) if exists $self->{SEPARATORS}{$b};

    my ($side, $pad, $nopad) = $self->{SIDE} =~ /^top$|^bottom$/ ? 
	qw/left -padx -pady/ : qw/top -pady -padx/;

    if (ref($b) eq 'Tk::LabEntry') {
	$b->configure(-labelPack => [-side => $side]);
    }

    my @extra;
    if (exists $packIn{$b}) {
	@extra = (-in => $packIn{$b});

	# repack everything now.
	my $top = $containers{$b};
	$top->{SIDE} = $self->{SIDE};

	my $e = $top->_edge;
	my @allSlaves = grep {$_ ne $e} $b->packSlaves;
	$_   ->packForget for @allSlaves;

	$top->_packEdge($e, 1);
	$top->_packWidget($_) for @allSlaves;
    }

    $b->pack(-side => $side, $pad => 4, $nopad => 0, @extra);
}

sub _configureWidget {
    my ($self, $w) = @_;

    $w->configure(-activebackground => $self->{ACTIVE_BG});
}

sub _createButtonBindings {
    my ($self, $b) = @_;

    my $bg = $b->cget('-bg');

    $b->bind('<Enter>' => [$b, 'configure', qw/-relief raised/]);
    $b->bind('<Leave>' => [$b, 'configure', qw/-relief flat/]);
}

sub _createSeparatorBindings {
  my ($self, $s) = @_;

  my ($ox, $oy);

  $s->bind('<1>'         => sub {
	     $ox = $s->XEvent->x;
	     $oy = $s->XEvent->y;
	   });

  $s->bind('<B1-Motion>' => sub {
	     my $x = $s->XEvent->x;
	     my $y = $s->XEvent->y;

	     my $f = $self->{SEPARATORS}{$s};

	     if ($self->{SIDE} =~ /top|bottom/) {
	       my $dx = $x - $ox;

	       my $w  = $f->width + $dx;
	       $w     = 0 if $w < 0;

	       $f->GeometryRequest($w, $f->height);
	     } else {
	       my $dy = $y - $oy;

	       my $h  = $f->height + $dy;
	       $h     = 0 if $h < 0;

	       $f->GeometryRequest($f->width, $h);
	     }
	   });
}

sub Button     { goto &ToolButton     }
sub Label      { goto &ToolLabel      }
sub Entry      { goto &ToolEntry      }
sub LabEntry   { goto &ToolLabEntry   }
sub Optionmenu { goto &ToolOptionmenu }

sub _clone {
  my ($self, $top, $in) = @_;

  my $new = $top->ToolBar(qw/-side top -cursorcontrol/, $self->{USECC}, ($in ? (-in => $in, -movable => 0) : ()));
  my $e   = $self->_edge;

  my @allSlaves = grep {$_ ne $e} $self->{CONTAINER}->packSlaves;
  for my $w (@allSlaves) {
    my $t = ref $w;
    $t =~ s/Tk:://;

    if ($t eq 'Frame' && exists $containers{$w}) { # embedded toolbar
      my $obj = $containers{$w};
      $obj->_clone($top, $new);
    }

    if ($t eq 'Frame' && exists $self->{SEPARATORS}{$w}) {  # separator
      $new->separator;
    }

    my %c = map { $_->[0], $_->[4] || $_->[3] } grep {defined $_->[4] || $_->[3] } grep @$_ > 2, $w->configure;
    delete $c{$_} for qw/-offset -class -tile -visual -colormap -labelPack/;

    if ($t =~ /.button/) {
      $new->Button(-type => $t,
		   %c);
    } else {
      $new->$t(%c);
    }
  }

  $new ->{MW}      = $self->{MW};
  $new ->{CLONE}   = $self;
  $new ->{ISCLONE} = $top;
  $self->{ISCLONE} = 0;
}

__END__

=pod

=head1 NAME

Tk::ToolBar - A toolbar widget for Perl/Tk

=for category Tk Widget Classes

=head1 SYNOPSIS

        use Tk;
        use Tk::ToolBar;

        my $mw = new MainWindow;
        my $tb = $mw->ToolBar(qw/-movable 1 -side top
                                 -indicatorcolor blue/);

        $tb->ToolButton  (-text  => 'Button',
                          -tip   => 'tool tip',
                          -command => sub { print "hi\n" });
        $tb->ToolLabel   (-text  => 'A Label');
        $tb->Label       (-text  => 'Another Label');
        $tb->ToolLabEntry(-label => 'A LabEntry',
                          -labelPack => [-side => "left",
                                         -anchor => "w"]);

        my $tb2 = $mw->ToolBar;
	$tb2->ToolButton(-image   => 'navback22',
			 -tip     => 'back',
			 -command => \&back);
        $tb2->ToolButton(-image   => 'navforward22',
			 -tip     => 'forward',
			 -command => \&forward);
        $tb2->separator;
        $tb2->ToolButton(-image   => 'navhome22',
			 -tip     => 'home',
			 -command => \&home);
        $tb2->ToolButton(-image   => 'actreload22',
			 -tip     => 'reload',
			 -command => \&reload);

        MainLoop;

=head1 DESCRIPTION

This module implements a dockable toolbar. It is in the same spirit as the
"short-cut" toolbars found in most major applications, such as most web browsers
and text editors (where you find the "back" or "save" and other shortcut buttons).

Buttons of any type (regular, menu, check, radio) can be created inside this widget.
You can also create Label, Entry and LabEntry widgets.
Moreover, the ToolBar itself can be made dockable, such that it can be dragged to
any edge of your window. Dragging is done in "real-time" so that you can see the
contents of your ToolBar as you are dragging it. Furthermore, if you are close to
a stickable edge, a visual indicator will show up along that edge to guide you.
ToolBars can be made "floatable" such that if they are dragged beyond their
associated window, they will detach and float on the desktop.
Also, multiple ToolBars are embeddable inside each other.

If you drag a ToolBar to within 15 pixels of an edge, it will stick to that
edge. If the ToolBar is further than 15 pixels away from an edge and still
inside the window, but you
release it over another ToolBar widget, then it will be embedded inside the
second ToolBar. You can "un-embed" an embedded ToolBar simply by dragging it
out. You can change the 15 pixel limit using the B<-close> option.

Various icons are built into the Tk::ToolBar widget. Those icons can be used
as images for ToolButtons (see L</SYNOPSIS>). A demo program is bundled with
the module that should be available under the 'User Contributed Demonstrations'
when you run the B<widget> program. Run it to see a list of the available
images.

Tk::ToolBar attempts to use Tk::CursorControl if it's already installed on
the system. You can further control this using the I<-cursorcontrol> option.
See L</PREREQUISITES>.

The ToolBar is supposed to be created as a child of a Toplevel (MainWindow is
a Toplevel widget) or a Frame. You are free to experiment otherwise,
but expect the unexpected :-)

=head1 WIDGET-SPECIFIC OPTIONS

The ToolBar widget takes the following arguments:

=over 4

=item B<-side>

This option tells the ToolBar what edge to I<initially> stick to. Can be one of 'top', 'bottom',
'left' or 'right'. Defaults to 'top'. This option can be set only during object
creation. Default is 'top'.

=item B<-movable>

This option specifies whether the ToolBar is dockable or not. A dockable ToolBar
can be dragged around with the mouse to any edge of the window, subject to the
sticky constraints defined by I<-sticky>. Default is 1.

=item B<-close>

This option specifies, in pixels, how close we have to drag the ToolBar an edge for the
ToolBar to stick to it. Default is 15.

=item B<-sticky>

This option specifies which sides the toolbar is allowed to stick to. The value
must be a string of the following characters 'nsew'. A string of 'ns' means that
the ToolBar can only stick to the north (top) or south (bottom) sides. Defaults to
'nsew'. This option can be set only during object creation.

=item B<-in>

This option allows the toolbar to be embedded within another already instantiated
Tk::ToolBar object. The value must be a Tk::ToolBar object. This option can be set
only during object creation.

=item B<-float>

This option specifies whether the toolbar should "float" on the desktop if
dragged outside of the window. It defaults to 1. Note that this value is
ignored if I<-cursorcontrol> is set to 1.

=item B<-cursorcontrol>

This option specifies whether to use Tk::CursorControl to confine the cursor
during dragging. The value must be either 1 or 0. The default is 1 which
checks for Tk::CursorControl and uses it if present.

=item B<-mystyle>

This option indicates that you want to control how the ToolBar looks like
and not rely on Tk::ToolBar's own judgement. The value must be either
1 or 0. For now, the only thing this controls is the relief of ToolButtons
and the borderwidth. Defaults to 0.

=item B<-indicatorcolor>

This option controls the color of the visual indicator that tells you
whether you are close enough to an edge when dragging the ToolBar.
Defaults to some shade of blue and green (I like it :P).

=item B<-indicatorrelief>

This option controls the relief of the visual indicator that tells you
whether you are close enough to an edge when dragging the ToolBar.
Defaults to flat.

=back

=head1 WIDGET METHODS

The following methods are used to create widgets that are placed inside
the ToolBar. Widgets are ordered in the same order they are created, left to right.

For all widgets, except Labels, a tooltip can be specified via the B<-tip> option.
An image can be specified using the -image option for Button- and Label-based widgets.

=over 4

=item I<$ToolBar>-E<gt>B<ToolButton>(?-type => I<buttonType>,? I<options>)

=item I<$ToolBar>-E<gt>B<Button>(?-type => I<buttonType>,? I<options>)

This method creates a new Button inside the ToolBar.
The I<-type> option can be used to specify
what kind of button to create. Can be one of 'Button', 'Checkbutton', 'Menubutton', or
'Radiobutton'. A tooltip message can be specified via the -tip option.
An accelerator binding can be specified using the -accelerator option.
The value of this option is any legal binding sequence as defined
in L<bind>. For example,
C<-accelerator =E<gt> 'E<lt>fE<gt>'> will invoke the button when the 'f' key is pressed.
Any other options will be passed directly to the constructor
of the button. The Button object is returned.

=item I<$ToolBar>-E<gt>B<ToolLabel>(I<options>)

=item I<$ToolBar>-E<gt>B<Label>(I<options>)

This method creates a new Label inside the ToolBar.
Any options will be passed directly to the constructor
of the label. The Label object is returned.

=item I<$ToolBar>-E<gt>B<ToolEntry>(I<options>)

=item I<$ToolBar>-E<gt>B<Entry>(I<options>)

This method creates a new Entry inside the ToolBar.
A tooltip message can be specified via the -tip option.
Any other options will be passed directly to the constructor
of the entry. The Entry object is returned.

=item I<$ToolBar>-E<gt>B<ToolLabEntry>(I<options>)

=item I<$ToolBar>-E<gt>B<LabEntry>(I<options>)

This method creates a new LabEntry inside the ToolBar.
A tooltip message can be specified via the -tip option.
Any other options will be passed directly to the constructor
of the labentry. The LabEntry object is returned.
In horizontal ToolBars, the label of the LabEntry widget
will be packed to the left of the entry. On vertical
ToolBars, the label will be packed on top of the entry.

=item I<$ToolBar>-E<gt>B<ToolOptionmenu>(I<options>)

=item I<$ToolBar>-E<gt>B<Optionmenu>(I<options>)

This method creates a new Optionmenu inside the ToolBar.
A tooltip message can be specified via the -tip option.
Any other options will be passed directly to the constructor
of the Optionmenu. The Optionmenu object is returned.

=item I<$ToolBar>-E<gt>B<separator>(?-movable => 0/1, -space => num?)

This method inserts a separator. Separators are movable by default.
To change that, set the -movable option to 0. If you want to add some
space to the left of a separator (or at the top if your ToolBar is
vertical), then you can specify the amount of space (in pixels) via
the -space option. This can be used to "right-justify" some buttons.

=back

=head1 IMAGES

Tk::ToolBar now comes with a set of useful images that can be used
in your Tk programs. To view those images, run the B<widget> program
that is bundled with Tk, scroll down to the 'User Contributed
Demonstrations', and click on the Tk::ToolBar entry.

Note that the images are created using the L<text|Photo> method. Also,
Tk::ToolBar, upon its creation, pre-loads all of the bundled images
into memory. This means that those images are available for use in other
widgets in your Tk program. This also means that unless those images
are explicitly destroyed, they will use up a small amount of memory even
if you are not using them explicitly.

As far as I know, all the bundled images are in the free domain. If that
is not the case, then please let me know.

=head1 BUGS

Not really a bug, but a feature ;-)
The ToolBar widget assumes that you use I<pack> in its parent.
Actually, it will I<pack()> itself inside its parent. If you are using
another geometry manager, then you I<MIGHT> get some weird behaviour.
I have tested it very quickly, and found no surprises, but let me know
if you do.

Another thing I noticed is that on slower window managers dragging a
ToolBar might not go very smoothly, and you can "drop" the ToolBar
midway through dragging it. I noticed this on Solaris 7 and 8, running
any of OpenLook, CDE or GNOME2 window managers. I would appreciate any
reports on different platforms.

=head1 TODO

I have implemented everything I wanted, and then some.
Here are things that were requested, but are not implemented yet.
If you want more, send me requests.

=over 4

=item o Allow buttons to be "tied" to menu items. Somewhat taken care of
with the -accelerator method for buttons.

=item o Implement Drag-n-Drop to be able to move Tool* widgets interactively.
Do we really want this?

=back


=head1 PREREQUISITES

Tk::ToolBar uses only core pTk modules. So you don't need any special
prerequisites. But, if Tk::CursorControl is installed on your system,
then Tk::ToolBar will use it to confine the cursor to your window when
dragging ToolBars (unless you tell it not to).

Note also that Tk::CursorControl is defined as a prerequisite in
Makefile.PL. So, during installation you might get a warning saying:

C<Warning: prerequisite Tk::CursorControl failed to load ...>

if you don't have it installed. You can ignore this warning if you
don't want to install Tk::CursorControl. Tk::ToolBar will continue
to work properly.

=head1 INSTALLATION

Either the usual:

	perl Makefile.PL
	make
	make install

or just stick it somewhere in @INC where perl can find it. It's in pure Perl.

=head1 ACKNOWLEDGEMENTS

The following people have given me helpful comments and bug reports to keep me busy:
Chris Whiting, Jack Dunnigan, Robert Brooks, Peter Lipecka, Martin Thurn and Shahriar Mokhtarzad.

Also thanks to the various artists of the KDE team for creating those great icons,
and to Adrian Davis for packaging them in a Tk-friendly format.

=head1 AUTHOR

Ala Qumsieh I<aqumsieh@cpan.org>

=head1 COPYRIGHTS

This module is distributed under the same terms as Perl itself.

=cut
