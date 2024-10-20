package Tk::CursorControl;

require 5.005_62;
use Tk 800.015;
use Carp;
use strict;

$Tk::CursorControl::VERSION = '0.4';

my $AlreadyInit   = 0;
my $CurrentObject = 0;
my $Main;

#Create Aliases to some public methods.
*jail = \&confine;
*free = \&release;
*Show = \&show;

Construct Tk::Widget 'CursorControl';

sub new {
  my ( $me, $parent ) = @_;
  my $class = ref($me) || $me;
  my $self = {};
  bless $self => $class;

  # provide access to class data
  $self->{_Init}       = \$AlreadyInit;
  $self->{_CurrentObj} = \$CurrentObject;

  # set MainWindow reference in 'accessible' class data
  $Main = $parent->MainWindow;
  $parent->OnDestroy( sub { $self->DESTROY } );
  $self->{MAIN} = \$Main if ( defined $Main );

  if ( ${ $self->{_Init} } == 0 ) {
    ++${ $self->{_Init} };
    $self->_init;
    ${ $self->{_CurrentObj} } =
      $self;    #store object in case user tries to create two!
    return $self;
  }
  else {
    ++${ $self->{_Init} };    # DESTROY will be called, so increment anyway
        # These error messages are now suppressed - JD October 13, 2003
        # Thanks for the suggestion Ala.
    ### carp "A $class object has ALREADY been created !";
    ### carp "The object returned is the original object for $class";
   # This means that either a module already called Tk::CursorControl on behalf
   # of the user (i.e. via a 'use SomeModule' where the code within SomeModule
   # creates a Tk::CursorControl object ---OR--- the programmer didn't read the
   # documentation and tried to create two or more CursorControl objects for one
   # MainWindow.
    return ${ $self->{_CurrentObj} };    #return ORIGINALLY created object
  }
}

# For erroneous understanding of this Class!
sub _errmsg { croak "You cannot $_[1] a ", ref( $_[0] ); }

########## Public NON-methods ##########
# Just in case someone treats this like a Tk widget
# Override geometry managers

sub pack      { $_[0]->_errmsg('pack') }
sub grid      { $_[0]->_errmsg('grid') }
sub form      { $_[0]->_errmsg('form') }
sub place     { $_[0]->_errmsg('place') }
sub configure { $_[0]->_errmsg('configure') }
sub cget      { $_[0]->_errmsg('cget') }

########## Public Methods ##########
sub confine {
  my ( $self, $widget ) = @_;
  unless ( defined $widget ) {
    carp "\$cursor->confine(\$widget)";
    return;
  }

  #free the cursor if already confined elsewhere
  $self->release if ( $self->{Confined} );

  #does the widget exist? is it mapped?
  return unless ( $self->_check($widget) );

  if ( $self->{Type} eq 'win32' ) {
    $self->_Win32confine($widget);
  }
  else {

    #Then $self->{Type} is the default 'unix'
    $self->_Unixconfine($widget);
  }
}

sub release {
  my $self = shift;
  if ( $self->{Type} eq 'win32' ) {
    $self->_Win32release;
  }
  else {

    #Then $self->{Type} is the default 'unix'
    $self->_Unixrelease;
  }
}

sub hide {
  my $self = shift;
  my $w;

  foreach $w (@_) {

    #bind to Enter and Leave Events
    if ( $self->{Type} eq 'win32' ) {

 #Showcursor is a system-wide API - so we want to ensure that the cursor doesn't
 #disappear forever!
      $self->_Win32saveBindings($w);
      $self->_Win32setBindings($w);
      $self->_Win32hidecursor;
    }
    else {
      $self->_setOldCursor($w);
      $w->configure( -cursor =>
          [ '@' . $self->{bitmapfile}, $self->{maskfile}, 'black', 'white' ] );
    }
  }
}

sub show {
  my $self = shift;

  foreach my $w (@_) {

    #delete bindings for hide Events for specified widget
    if ( $self->{Type} eq 'win32' ) {
      $self->_Win32restoreBindings($w);
      $self->_Win32showcursor;
    }
    else {
      my $cursor = $self->_getOldCursor($w);
      $w->configure( -cursor => $cursor ) if ($cursor);
    }
  }
}

sub moveto {

# Similar to the warpto sub. Instead - we always use the root window coordinates
# So, all we are interested in is the starting x,y coordinates and the ending
# x,y coordinates. Most of the code is a copy and paste from the warpto sub.

  my $self = shift;
  my $w;

  #parse the time off the arguments...there has to be a better way!
  my $movetime = 1000;    #default to 1 second (1000ms)
  if ( grep /time/, @_ ) {
    my $i = 0;
    my $timefound;
    map {
      if (/time/) {
        splice @_, $i, 1;
        $timefound = pop(@_);
        $movetime = $timefound if ( $timefound =~ /\d+/ );
      }
      $i++;
    } @_;
  }

  #minimum time allowed
  $movetime = 25 if ( $movetime < 25 );

# Three ways of warping:
# 1. Pass a widget reference - default warp the cursor to the center.
# 2. Pass a widget reference and x,y value - warp the cursor to x,y of that widget.
# 3. Pass only an x,y coordinate (with no widget reference) then it is treated like
#    a screen coordinate.

  my $finalx;
  my $finaly;
  my $startx = ${ $self->{MAIN} }->pointerx;
  my $starty = ${ $self->{MAIN} }->pointery;

  my $argnum = scalar(@_);
  my $ref    = ref( $_[0] );
  if ( $ref and $ref =~ /^Tk/ ) {
    $w = shift;

    # Does the widget exist and is it mapped?
    return unless ( $self->_check($w) );

    if ( $argnum == 1 ) {

      #assume only a widget reference passed
      $self->release if ( $self->{Confined} );

      #Get ROOT coordinates of the final position
      $finalx = $w->rootx + ( $w->width / 2 );
      $finaly = $w->rooty + ( $w->height / 2 );

    }
    elsif ( $argnum == 3 ) {

      #assume a widget reference AND x,y value passed
      my $x = shift;
      my $y = shift;

      $self->release if ( $self->{Confined} );

      #warp pointer to x,y coordinate relative to widgets NW corner
      my $width  = $w->width;
      my $height = $w->height;
      $x = 0           if ( $x < 0 );
      $x = $width - 1  if ( $x > $width );
      $y = 0           if ( $y < 0 );
      $y = $height - 1 if ( $y > $height );

      $finalx = $w->rootx + $x;
      $finaly = $w->rooty + $y;
    }
  }    #end if $widget is passed
  elsif ( $argnum == 2 ) {

    # Assume only an x,y value passed..

    my $X = shift;
    my $Y = shift;

    $self->release if ( $self->{Confined} );

# Sanity check - don't warp beyond the screen. The window managers won't let you
# anyways - but we might as well not try!
    my $sw = ${ $self->{MAIN} }->screenwidth;
    my $sh = ${ $self->{MAIN} }->screenheight;

    $X = 0   if ( $X < 0 );
    $Y = 0   if ( $Y < 0 );
    $X = $sw if ( $X > $sw );
    $Y = $sh if ( $Y > $sh );

    $finalx = $X;
    $finaly = $Y;

  }

  return unless ( defined $finalx and defined $finaly );

  #finally "move" the cursor (based on time passed)
  my $denom  = $movetime / 25;
  my $deltax = ( $finalx - $startx ) / $denom;
  my $deltay = ( $finaly - $starty ) / $denom;
  my $interx = $startx;
  my $intery = $starty;
  for ( my $i = 1 ; $i <= $denom ; $i++ ) {
    $interx = $interx + $deltax;
    $intery = $intery + $deltay;
    $self->warpto( $interx, $intery );
    ${ $self->{MAIN} }->update;

    # Blocking is actually a good thing here.
    ${ $self->{MAIN} }->after(25);
  }

  # Now make sure we end up where we originally wanted !
  # Round off errors may have crept in.
  $self->warpto( $finalx, $finaly );

}

sub warpto {

  my $self = shift;
  my $w;

# Three ways of warping:
# 1. Pass a widget reference - default warp the cursor to the center.
# 2. Pass a widget reference and x,y value - warp the cursor to x,y of that widget.
# 3. Pass only an x,y coordinate (with no widget reference) then it is treated like
#    a screen coordinate.

  my $argnum = scalar(@_);
  my $ref    = ref( $_[0] );
  if ( $ref and $ref =~ /^Tk/ ) {
    $w = shift;

    # Does the widget exist and is it mapped?
    return unless ( $self->_check($w) );

    if ( $argnum == 1 ) {

      #assume only a widget reference passed
      $self->release if ( $self->{Confined} );

      #warp pointer to the center of the widget
      my $x = ( $w->width / 2 );
      my $y = ( $w->height / 2 );

      $w->eventGenerate(
        "<Motion>",
        -when => 'head',
        -x    => $x,
        -y    => $y,
        -warp => 1
      );
    }
    elsif ( $argnum == 3 ) {

      #assume a widget reference AND x,y value passed
      my $x = shift;
      my $y = shift;

      $self->release if ( $self->{Confined} );

      #warp pointer to x,y coordinate relative to widgets NW corner
      my $width  = $w->width;
      my $height = $w->height;
      $x = 0           if ( $x < 0 );
      $x = $width - 1  if ( $x > $width );
      $y = 0           if ( $y < 0 );
      $y = $height - 1 if ( $y > $height );

      $w->eventGenerate(
        "<Motion>",
        -when => 'head',
        -x    => $x,
        -y    => $y,
        -warp => 1
      );
    }
  }    #end if $widget is passed
  elsif ( $argnum == 2 ) {

# Assume only an x,y value passed..
# Warp to specific screen coordinates. There is no way to do this outright using
# eventGenerate...at least "I" couldn't find one.
# So we use the rootx and rooty of the MainWindow as our anchor position.
# and we might end up actually warping to negative values of x and y.

    my $X = shift;
    my $Y = shift;

    $self->release if ( $self->{Confined} );

    # works on windows even if iconified - check on unix. Maybe not needed!!
    # return unless ( $self->_check(${$self->{MAIN}}) );

# Sanity check - don't warp beyond the screen. The window managers won't let you
# anyways - but we might as well not try!
    my $sw = ${ $self->{MAIN} }->screenwidth;
    my $sh = ${ $self->{MAIN} }->screenheight;

    $X = 0   if ( $X < 0 );
    $Y = 0   if ( $Y < 0 );
    $X = $sw if ( $X > $sw );
    $Y = $sh if ( $Y > $sh );

    my $x = $X - ${ $self->{MAIN} }->rootx;
    my $y = $Y - ${ $self->{MAIN} }->rooty;

    ${ $self->{MAIN} }->eventGenerate(
      "<Motion>",
      -when => 'head',
      -x    => $x,
      -y    => $y,
      -warp => 1
    );
  }

}

sub destroy { shift->DESTROY }

############# Private methods ##################
sub _check {
  my ( $self, $w ) = @_;
  my $ok = 1;
  unless ( $ok = Exists($w) ) {
    carp "Widget $w: Does not exist!";
  }
  unless ( $ok = $w->viewable ) {
    carp "Widget $w: is not mapped";
  }
  return $ok;
}

sub _getposition {

  #return the top left corner and width/height of widget passed.
  my ( $self, $w ) = @_;
  my $x0     = $w->rootx;
  my $y0     = $w->rooty;
  my $width  = $w->width;
  my $height = $w->height;

  return ( $x0, $y0, $width, $height );
}

sub _getbbox {

  #return the absolute screen coordinates (i.e. bbox)
  my ( $self, $w ) = @_;
  my @c = $self->_getposition($w);
  return ( $c[0], $c[1], $c[0] + $c[2], $c[1] + $c[3] );
}

sub _init {
  my $self = shift;

  $self->{Type} = 'unix';    #default to 'perl based' cursor confine

  if ( $Tk::platform eq 'MSWin32' ) {
    if ( eval "require Win32::API" ) {

      #Create API's
      $self->{ClipCursor} =
        Win32::API->new( 'user32', 'ClipCursor', ['P'], 'N' );
      $self->{ShowCursor} =
        Win32::API->new( 'user32', 'ShowCursor', ['N'], 'N' );
      $self->{Type} = 'win32' if ( $self->{ClipCursor} && $self->{ShowCursor} );
      $self->{DisplayCount} = 0;
      return if $self->{Type} eq 'win32';
      croak "Creating API objects failed for unknown reason";
    }
    else {
      croak "Please install Win32::API !!";
    }
  }
  else {

    #retrieve proper filenames for transparent cursor for *NIX..
    $self->{bitmapfile} = Tk->findINC('trans_cur.xbm');
    $self->{maskfile}   = Tk->findINC('trans_cur.mask');
    croak "Files for tranparent cursor not found"
      unless ( $self->{bitmapfile} && $self->{maskfile} );
  }
}

####### On Unix Only #############
sub _setOldCursor {

  #save the current cursor on a ->hide command
  my ( $self, $w ) = @_;
  my $oldcursor = $w->cget('-cursor') || 'left_ptr';
  $self->{OldCursor}{$w} = $oldcursor if ($oldcursor);
}

sub _getOldCursor {

  #get saved cursor on a ->show command
  my ( $self, $w ) = @_;
  my $cursor = $self->{OldCursor}{$w};
  delete $self->{OldCursor}{$w};
  return ($cursor);
}

sub _Unixconfine {
  my ( $self, $w ) = @_;
  my @coords = $self->_getposition($w);

# Stop Class <Leave> bindings from being triggered - as a Leave should NEVER occur
# Why? Because the cursor is 'supposed' to be confined to the widget! Since this
# event 'will' still occur we Tk->break it before the Class binding occurs.
# An example if we did not do this (and I know from testing) is: a Button relief rapidly
# changing between sunken and normal to causing massive flickering

# Also - We cannot guarantee a Motion binding will get triggered for the passed widget.
# Instead we overwrite the Motion binding for the toplevel containg $widget. This virtually
# guarantees (fingers crossed) that a proper Motion binding exists. Of course the Leave
# event must stay with the passed $widget.

  my @bindtags = $w->bindtags;
  $w->bindtags( [ @bindtags[ 1, 0, 2, 3 ] ] );

  #Save current leave binding..if there is one
  my $old_leave;
  my $old_motion;
  eval { $old_leave  = $w->Tk::bind('<Any-Leave>') };
  eval { $old_motion = $w->toplevel->bind('<Motion>') };
  ( defined $old_leave )
    ? ( $self->{OldLeave} = $old_leave )
    : ( $self->{OldLeave} = 0 );
  ( defined $old_motion )
    ? ( $self->{OldMotion} = $old_motion )
    : ( $self->{OldMotion} = 0 );

  $w->Tk::bind( '<Any-Leave>', sub { $_[0]->break } );

  $w->toplevel->bind(
    '<Motion>',
    sub {
      $self->{OldMotion}->Call if ( $self->{OldMotion} );
      $self->_warpToConfine( $w, @coords );
    }
  );
  $self->{Confined} = $w;
}

sub _Unixrelease {
  my $self = shift;

  #Restore proper bindtag order for widget..
  return unless $self->{Confined};
  my @bindtags = $self->{Confined}->bindtags;
  $self->{Confined}->bindtags( [ @bindtags[ 1, 0, 2, 3 ] ] );

  ( $self->{OldLeave} )
    ? ( $self->{Confined}->Tk::bind( '<Any-Leave>', $self->{OldLeave} ) )
    : ( $self->{Confined}->Tk::bind( '<Any-Leave>', '' ) );
  ( $self->{OldMotion} )
    ? ( $self->{Confined}->toplevel->bind( '<Motion>', $self->{OldMotion} ) )
    : ( $self->{Confined}->toplevel->bind( '<Motion>', '' ) );

  $self->{Confined} = 0;
}

sub _warpToConfine {
  my ( $self, $w, $x0, $y0, $wi, $he ) = @_;

  my $e = $w->XEvent;
  my ( $x, $y ) = ( $e->x, $e->y );

  my $warpneeded = 0;

  if ( $x <= 0 ) {
    $x          = 1;
    $warpneeded = 1;
  }
  elsif ( $x >= $wi ) {
    $x          = $wi - 1;
    $warpneeded = 1;
  }

  if ( $y <= 0 ) {
    $y          = 1;
    $warpneeded = 1;
  }
  elsif ( $y >= $he ) {
    $y          = $he - 1;
    $warpneeded = 1;
  }

  if ($warpneeded) {
    $w->eventGenerate(
      "<Motion>",
      -when => 'head',
      -x    => $x,
      -y    => $y,
      -warp => 1
    );
  }
}

########### On Win32 Only #############
sub _Win32confine {
  my ( $self, $w ) = @_;
  my @coords = $self->_getbbox($w);

  my $rect = CORE::pack "L4", @coords;

  if ( defined $self->{ClipCursor} ) {
    $self->{ClipCursor}->Call($rect);
    $self->{Confined} = 1;
  }
}

sub _Win32release {
  my $self = shift;
  my $null = 0;
  if ( defined $self->{ClipCursor} ) {
    $self->{ClipCursor}->Call($null);
    $self->{Confined} = 0;
  }
}

sub _Win32saveBindings {
  my ( $self, $w ) = @_;

  # Save current Enter, Leave and Unmap bindings..if there are any
  # Fully specify Tk::bind in case of a canvas widget.
  my $old_leave;
  my $old_enter;
  my $old_unmap;
  eval { $old_leave = $w->Tk::bind('<Leave>') };
  eval { $old_enter = $w->Tk::bind('<Enter>') };
  eval { $old_unmap = $w->Tk::bind('<Unmap>') };
  ( defined $old_leave )
    ? ( $self->{Win32Leave}{$w} = $old_leave )
    : ( $self->{Win32Leave}{$w} = 0 );
  ( defined $old_enter )
    ? ( $self->{Win32Enter}{$w} = $old_enter )
    : ( $self->{Win32Enter}{$w} = 0 );
  ( defined $old_unmap )
    ? ( $self->{Win32Unmap}{$w} = $old_unmap )
    : ( $self->{Win32Unmap}{$w} = 0 );
}

sub _Win32setBindings {
  my ( $self, $w ) = @_;
  $w->Tk::bind(
    '<Enter>',
    sub {
      $self->{Win32Enter}{$w}->Call if ( $self->{Win32Enter}{$w} );
      $self->_Win32hidecursor;
    }
  );
  $w->Tk::bind(
    '<Leave>',
    sub {
      $self->{Win32Leave}{$w}->Call if ( $self->{Win32Leave}{$w} );
      $self->_Win32showcursor;
    }
  );

  #ensure cursor gets shown again if widget disappears..
  $w->Tk::bind(
    '<Unmap>',
    sub {
      $self->{Win32Unmap}{$w}->Call if ( $self->{Win32Unmap}{$w} );
      $self->_Win32showcursor;
    }
  );
}

sub _Win32restoreBindings {
  my ( $self, $w ) = @_;
  ( $self->{Win32Enter}{$w} )
    ? ( $w->Tk::bind( '<Enter>', $self->{Win32Enter}{$w} ) )
    : ( $w->Tk::bind( '<Enter>', '' ) );
  ( $self->{Win32Leave}{$w} )
    ? ( $w->Tk::bind( '<Leave>', $self->{Win32Leave}{$w} ) )
    : ( $w->Tk::bind( '<Leave>', '' ) );
  ( $self->{Win32Unmap}{$w} )
    ? ( $w->Tk::bind( '<Unmap>', $self->{Win32Unmap}{$w} ) )
    : ( $w->Tk::bind( '<Unmap>', '' ) );
}

sub _Win32hidecursor {
  my $self = shift;
  $self->_Win32resetDisplayCount;
  $self->{DisplayCount} = $self->{ShowCursor}->Call(0);
}

sub _Win32showcursor {
  my $self = shift;
  $self->_Win32resetDisplayCount;
  $self->{DisplayCount} = $self->{ShowCursor}->Call(1);
}

sub _Win32resetDisplayCount {
  my $self = shift;

  #Decrement display count to get ready for a hide. i.e. set count to 0.
  if ( $self->{DisplayCount} > 0 ) {
    my $count = $self->{DisplayCount};
    for ( my $i = $count ; $i > 0 ; $i-- ) {
      $self->{DisplayCount} = $self->{ShowCursor}->Call(0);
    }
  }

  #Increment display count to get ready for a show. i.e. set count to -1.
  elsif ( $self->{DisplayCount} < 0 ) {
    my $count = $self->{DisplayCount};
    for ( my $i = $count ; $i < -1 ; $i++ ) {
      $self->{DisplayCount} = $self->{ShowCursor}->Call(1);
    }
  }
}

########################################
sub DESTROY {
  my $self = shift;
  $self->release;
  ##carp "DESTROY CALLED ON $self";
  --${ $self->{_Init} };    #decrement initialize value
}

1;

__END__

=head1 NAME

Tk::CursorControl - Manipulate the mouse cursor programmatically

=head1 SYNOPSIS

    use Tk::CursorControl;
    $cursor = $main->CursorControl;

    # Lock the mouse cursor to $widget
    $cursor->confine($widget);

    # Free the cursor
    $cursor->release;

    # cursor disappears over $widget
    $cursor->hide($widget);

    # show cursor again over $widget
    $cursor->show($widget);

    # warp cursor to $widget (jump)
    $cursor->warpto($widget);

    # move cursor to $widget
    $cursor->moveto($widget);

=head1 DESCRIPTION

B<Tk::CursorControl> is-B<NOT>-a Tk::Widget.
Rather, it I<uses> Tk and encompasses a collection of methods
used to manipulate the cursor I<(aka pointer)> programmatically
from a Tk program.

=head1 STANDARD OPTIONS

B<Tk::CursorControl> does I<not> accept any standard options

=head1 METHODS

The following methods are available:

=over 4

=item I<$cursor>-E<gt>B<confine>( $widget )

Confine the cursor to stay within the bounding box of $widget.

=over 4

=item I<$cursor>-E<gt>B<jail>( $widget )

Alias for the B<confine> method.

=back

=item I<$cursor>-E<gt>B<release>

Release the cursor. Used to restore proper cursor functionality
after a confine. Note: I<$widget> does B<not> need to be specified.

=over 4

=item I<$cursor>-E<gt>B<free>

Alias for the B<release> method.

=back

=item I<$cursor>-E<gt>B<hide>( @widgets )

Make cursor I<invisible> over each widget in @widgets.

=item I<$cursor>-E<gt>B<show>( @widgets )

Make cursor I<visible> over each widget in @widgets. This is used after a B<hide>.
B<Note: S>how (capital S) can be used as well.

=item I<$cursor>-E<gt>B<warpto>( $widget I<?x,y?>)

Warp the cursor to the specified I<(?x,y?)> position in $widget. If the x,y values
are not specified, then the I<center> of the widget is used as the target.

OR

=item I<$cursor>-E<gt>B<warpto>( X,Y )

Warp the cursor to the specified I<X,Y> screen coordinate.

=item I<$cursor>-E<gt>B<moveto>( $widget I<?x,y?>, -time=E<gt>I<integer in milliseconds>)

Move the cursor to the specified I<(?x,y?)> position in $widget in I<-time> milliseconds.
If the x,y values are not specified, then the I<center> of the widget is used as the
target. The -time value defaults to 1000ms (1 second) if not specified. The smaller the
time, the faster the cursor will move. The time given will not be exact. See bugs below.

OR

=item I<$cursor>-E<gt>B<moveto>( X,Y, -time=E<gt>I<integer in milliseconds>)

Move the cursor to the specified I<X,Y> screen coordinate in I<-time> milliseconds.
The -time value defaults to 1000ms (1 second) if not specified. The smaller the
time, the faster the cursor will move. The time given will not be exact. See bugs below.

=back

=head1 DEPENDENCIES

B<Win32::API> is required on Win32 systems.

=head1 POSSIBLE USES

Don't e-mail me to debate whether or not a program I<should> warp or 
hide a cursor. I will give you a few instances where "I think" a
module like this could come in handy.

1. Confining a canvas item to remain within the Canvas boundaries
on a move. See the cursor demonstration in 'widget'.

2. Giving the user some 'leeway' on clicking near an item. Say,
clicking on the picture of a thermometer, warps the cursor to a
Tk::Scale (right beside it) which actually controls that thermometer.

3. Confining a window within another window (Tk::MDI should be
upgraded to 'use Tk::CursorControl')

4. A step by step, show and tell session on 'How to use this GUI'.

5. Make the cursor disappear for a keyboard only Tk::Canvas game.

The key to using this module properly, is subtlety! Don't start making
the cursor warp all over the screen or making it disappear sporadically.
That is a misuse of the functionality.

For some 'real world' applications which already have these types of
functionality, see any Multiple Document Interface (MDI); such as in
Excel or Word). Also have a look at the Win32 color chooser. The cursor
will be confined to the color palette while the button is pressed. Also,
try clicking on the gradient bar to the right of the palette. See what
happens to the mouse cursor?!
I'll bet you didn't even know that this existed until now.

If you discover another good use for this module, I would definitely
like to hear about it ! I<That> is the type of e-mail I would welcome.

=head1 BUGS & IDIOSYNCRASIES

B<Take ONE please!>

B<Tk::CursorControl> only allows ONE object per MainWindow! If you try
to create more than one, B<only the first object created will be returned>.
This will also be true if using a widget or module which already defines
a Tk::CursorControl object.

B<Bindings>

B<Tk::CursorControl> internally generates E<lt>EnterE<gt>,
E<lt>LeaveE<gt> and E<lt>MotionE<gt> bindings for the I<$widget>
passed. Any user-defined bindings of the same type for I<$widget>
should I<still> get executed. This feature has not been completely
tested.

B<Win32>

This module makes heavy use of the ShowCursor and ClipCursor API's on 
Win32. Be aware that when you change a cursor using the API, you
are doing so for your entire system. You, (the programmer) are
responsible for generating the show/hide and confine/release commands
in the proper order.

For every hide - you I<*will*> want a show. For every confine - you
I<*should*> have a release. There are cautionary measures built-in
to ensure that the cursor doesn't disappear forever or get locked
within a widget.

i.e. A B<release> is automatically called if you try to confine
the cursor to two widgets at the same time.

In other words, the last B<confine> always wins!

B<Unix>

The methods for hiding and confining the cursor on Unix-based systems
is different than for Win32.

A blank cursor is defined using the Tk::Widget configure method for
each widget passed. Two files have been provided for this purpose in
the installation - I<trans_cur.xbm> and I<trans_cur.mask>. These files
must exist under a B<Tk-E<gt>FindINC> directory.

Confining a cursor on *nix does I<not> use any sort of API or Xlib
calls. Motion events are generated on the toplevel window to confine
the cursor to the proper widget. On slow systems, this will make the
cursor I<look> like it is attached to the widget sides with a spring.
On faster systems, while still there, this I<bouncing> type action
is much less noticible.

B<moveto>

The time parameter passed to a moveto method will not be exact. The
reason for this is because a crude L<Tk::After|Tk::After> command is
used to I<wait> for a very short period. You will find that the
actual time taken for the cursor to stop is alway slightly B<more>
than the time you specified. This time difference will be greater
on slower computers. The time error will also increase for higher
time values.

B<Other>

Warping the cursor will cause problems for users of absolute location
pointing devices (like graphics tablets). Users of graphics tablets
should B<not> use this module.

=head1 AUTHOR

B<Jack Dunnigan> <dunniganj@cpan.org>.

Copyright (c) 2002-2004 Jack Dunnigan. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

My thanks to Tk gurus Steve Lidie and Slaven Rezic for their suggestions
and their patches. This is my first module on CPAN and I appreciate
their help. Thanks to Ala Qumsieh for utilizing the power of my module
in L<Tk::Toolbar|Tk::Toolbar>.

=cut




