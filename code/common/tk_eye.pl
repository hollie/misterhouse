# Category = MisterHouse

#@ Adds a 'program active eye' to the tk interface

my $eye_pos = 0;
my $eye_dir = 1;

if ($eye_dir) {
    $eye_dir = 0 if ++$eye_pos > 65;
}
else {
    $eye_dir = 1 if --$eye_pos == 0;
}

if ($MW) {

    # I get "couldn't recognize data in image file" errors with .jpg files.  .gifs should be faster anyway
    #   $Tk_objects{eye_photo}->configure(-file => "$Pgm_Path/images/eye/eye" . ($eye_pos + 1) . ".jpg");
    $Tk_objects{eye_photo}->configure(
        -file => "$Pgm_Path/images/eye/eye" . ( $eye_pos + 1 ) . ".gif" );

    #$Tk_objects{eye} = '      ';
    #substr($Tk_objects{eye}, $eye_pos, 1) = '=';
}

# *** Configurable for old style (different threshold for textbox movement)
# *** Bind to click -> goes to mh Web site

#noloop=start
if ($MW) {
    $Tk_objects{eye}->destroy()      if defined( $Tk_objects{eye} );
    $Tk_objects{eye_photo}->delete() if defined( $Tk_objects{eye_photo} );
    $Tk_objects{eye_photo} =
      $Tk_objects{menu_bar}->Photo( -file => "$Pgm_Path/../docs/mh_logo.gif" );
    $Tk_objects{eye} = $Tk_objects{menu_bar}->Label(
        -height => 16,
        -width  => 16,
        -image  => $Tk_objects{eye_photo},
        -relief => 'sunken'
    )->pack(qw/-side right -anchor e/);

    #&tk_mlabel(\$Tk_objects{eye});
}

#noloop=stop
