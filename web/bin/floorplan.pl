
=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	floorplan.pl

Description:
	Provides a function to render an HTML table from the objects in the group
	passed as a parameter.

Author:
	Jason Sharpee
	jason@sharpee.com

Contributors:
	Neil Cherry <ncherry@linuxha.com>

License:
	This free software is licensed under the terms of the GNU public license.

Usage:
    http://localhost:8080/bin/floorplan.pl
    http://localhost:8080/bin/floorplan.pl?Property
    http://localhost:8080/bin/floorplan.pl?Upstairs

Bugs:
	-  Recursion is in use. Be carefull of problems with referencing the parent
	group from a child element.  Someone could add a max_level in there to be safe.

	-  If you overlap item co-ordinates, be carefull.  I dont have Z-order checking
	in here either yet and can makes tables get goofy.   Your table will look correct if
	all of your coords are correct. "Garbage in -> Garbage out"

Special Thanks to:
	Bruce Winter - MH

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

$^W = 0;    # Avoid redefined sub msgs

# Authority: anyone

my $object_name = shift || '$Property';
my $object = &get_object_by_name($object_name);
return &html_page( 'FloorPlan',
    "No $object_name Group found to generate a floorplan from" )
  unless $object;

my $html = "<meta http-equiv='refresh' content='10;URL='>";

#$html .= "<title>Floorplan</title>";

# $om is optional
use vars '$om';
if ($om) {
    $html .= "People Count: " . $om->people() . "<br>";
    $html .= "Minimum Count: " . $om->min_count() . "<br>";
}

$html .= &web_fp($object);

return &html_page( 'FloorPlan', $html );

sub web_fp    #render table representation of objects and their co-ordinates
{
    my ($p_obj) = @_;

    my @l_objs;
    my $l_html;
    my @l_fp;
    my ( $l_x, $l_y, $l_w, $l_h );
    my ( $l_xmax, $l_ymax ) = ( -1, -1 );
    my %l_rendered;
    my $l_obj;
    my $l_xscale = 12;
    my $l_yscale = 5;

    #	my $l_xscale=30;
    #	my $l_yscale=20;
    my $l_bcolor = '#CCCCCC';
    my $l_acolor = '#00FF00';

    if ( $p_obj->isa('Group') ) {
        @l_objs = @{ $$p_obj{members} };
        for my $obj (@l_objs) {
            ( $l_x, $l_y, $l_w, $l_h ) = $obj->get_fp_location();
            if ( $l_x ne "" ) {    #Only do items with co-ordinates
                for ( my $h = $l_y;
                    $h < $l_y + $l_h;
                    $h++ )    # Create Virtual Frame Buffer of object blocks
                {
                    for ( my $w = $l_x;
                        $w < $l_x + $l_w;
                        $w++ )    # Create Virtual Frame buffer of object blocks
                    {
                        $l_fp[$w][$h] = $obj;
                        $l_xmax = $w if $l_xmax < $w;
                        $l_ymax = $h if $l_ymax < $h;
                    }
                }
            }
        }
        $l_html .= web_fp_item($p_obj) . "<br>";
        if ( @l_objs > 0 ) {
            $l_html .=
                "<table border='0' width='"
              . $l_xmax * $l_xscale
              . "' height='"
              . $l_ymax * $l_yscale . "'>\n";
            for ( my $x = 0;
                $x <= $l_xmax;
                $x++ )    #initialize table with (hopefully) accurate sizing
            {
                $l_html .= "<td></td>";
            }
            for ( my $y = 0;
                $y <= $l_ymax;
                $y++ )    #Create HTML Table stucture of Virtual Frame buffer
            {
                $l_html .= "<tr>\n";
                $l_html .=
                  "\t<td width='" . $l_xscale . "' height='" . $l_yscale . "'>";
                $l_html .= "</td>\n";
                for ( my $x = 0; $x <= $l_xmax; $x++ ) {
                    $l_obj = $l_fp[$x][$y];
                    if ( $l_obj ne "" ) {   #Only do if object is at coordinates
                        if ( $l_rendered{$l_obj} eq '' ) {
                            $l_rendered{$l_obj} = 1;
                            ( $l_x, $l_y, $l_w, $l_h ) =
                              $l_obj->get_fp_location();
                            if ( $l_x eq '' ) { $l_x = 1; }
                            if ( $l_y eq '' ) { $l_y = 1; }
                            if ( $l_w eq '' ) { $l_w = 1; }
                            if ( $l_h eq '' ) { $l_h = 1; }
                            if ( $l_obj->isa('Group') ) {    #recurse groups
                                $l_html .=
                                    "\t<td bgcolor='$l_bcolor' width='"
                                  . $l_xscale * $l_w
                                  . "' height='"
                                  . $l_yscale * $l_h
                                  . "' colspan='$l_w' rowspan='$l_h'>";
                                $l_html .= web_fp($l_obj);
                            }
                            else {
                                $l_html .= "\t<td bgcolor='"
                                  . web_fp_idle_color( $l_obj, $l_acolor,
                                    $l_bcolor )
                                  . "' colspan='$l_w' rowspan='$l_h'>";
                                $l_html .= web_fp_item($l_obj);
                            }
                            $l_html .= "</td>\n";
                        }
                    }
                    else {    #Blank space
                        $l_html .=
                            "\t<td width='"
                          . $l_xscale
                          . "' height='"
                          . $l_yscale . "'>";
                        $l_html .= "</td>\n";
                    }
                }

                $l_html .= "</tr>\n";
            }
            $l_html .= "</table>\n";
        }
        for my $obj (@l_objs) {
            if ( $l_rendered{$obj} ne 1 ) {
                $l_html .= web_fp_item($obj);
            }
        }
    }
    else {
        $l_html .= web_fp_item($p_obj);
    }
    return $l_html;
}

sub web_fp_item    #render all items based on type
{
    my ($p_obj) = @_;

    my $l_html;
    my $l_text;
    my $l_state;
    my $l_image;

    #	print "--$p_obj:". $p_obj->state;
    $l_text = $$p_obj{object_name} . ":" . $p_obj->state;
    if ( $p_obj->isa('Group') ) {

        # Leave Group First as it is a Generic_Item too and we don't
        # want an Icon for the Group (how would you deal with On/Off
        # state of a group with mixed on and off device states?)
        $l_text = web_fp_filter_name( $p_obj->{object_name} );
    }
    elsif ($p_obj->isa('Light_Item')
        or $p_obj->isa('Fan_Light')
        or $p_obj->isa('Weeder_Light')
        or $p_obj->isa('UPB_Device')
        or $p_obj->isa('Insteon_Device')
        or $p_obj->isa('Insteon::DeviceController')
        or $p_obj->isa('Insteon::BaseLight')
        or $p_obj->isa('UPB_Link')
        or $p_obj->isa('EIB_Item')
        or $p_obj->isa('EIB1GItem')
        or $p_obj->isa('EIB2_Item')
        or $p_obj->isa('EIO_Item')
        or $p_obj->isa('UIO_Item')
        or $p_obj->isa('X10_Item') )
    {
        if ( $p_obj->state eq 'off' ) {
            $l_image = 'fp-light-off.gif';
            $l_state = 'on';
        }
        else {
            $l_image = 'fp-light-on.gif';
            $l_state = 'off';
        }
    }
    elsif ( $p_obj->isa('Motion_Item') || $p_obj->isa('X10_Sensor') ) {
        $l_state = 'motion';
        if ( lc( $p_obj->state ) eq 'motion' ) {
            $l_image = 'fp-motion-on.gif';
        }
        elsif ( $p_obj->state eq 'check' ) {
            $l_image = 'x.gif';
        }
        else {
            $l_image = 'fp-motion-off.gif';
        }
    }
    elsif ( $p_obj->isa('Door_Item') ) {
        if ( $p_obj->state eq 'open' ) {
            $l_image = 'fp-door-open.png';
            $l_state = 'closed';
        }
        elsif ( $p_obj->state eq 'check' ) {
            $l_image = 'x.gif';
        }
        else {
            $l_image = 'fp-door-closed.png';
            $l_state = 'open';
        }
    }
    elsif ( $p_obj->isa('RF_Item') ) {

        # Not setting $l_state because MH can't transmit it to Security.
        if ( lc( $p_obj->state ) =~ /^arm/ ) {
            $l_image = 'fp-alarm-armed.gif';
        }
        elsif ( lc( $p_obj->state ) eq 'disarm' ) {
            $l_image = 'fp-alarm-disable.gif';
        }
        elsif ( lc( $p_obj->state ) eq 'panic' ) {
            $l_image = 'fp-alarm-panic.gif';
        }
        elsif ( lc( $p_obj->state ) eq /^alert/ ) {
            $l_image = 'fp-door-open.png';
        }
        elsif ( lc( $p_obj->state ) =~ /^normal/ ) {
            $l_image = 'fp-door-closed.png';
        }
        else {
            $l_image = 'x.gif';
        }
    }
    elsif ( $p_obj->isa('Photocell_Item') ) {
        if ( $p_obj->state eq 'dark' ) {
            $l_image = 'fp-dark-on.gif';
        }
        elsif ( $p_obj->state eq 'check' ) {
            $l_image = 'x.gif';
        }
        else {
            $l_image = 'fp-dark-off.gif';
        }
    }
    elsif ( $p_obj->isa('Presence_Monitor') ) {
        if ( $p_obj->state eq 'occupied' ) {
            $l_image = 'fp-people.gif';
        }
        elsif ( $p_obj->state eq 'predict' ) {
            $l_image = 'a1+.gif';
        }
        else {
            $l_image = '1pixel.gif';
        }
    }
    elsif ( $p_obj->isa('Appliance_Item') ) {

        #	} elsif ($p_obj->isa('Camera_Item')) {
        #		if ($p_obj->state eq 'on') {
        #			$l_image="/usr/local/mh/web/graphics/" . web_fp_filter_name($p_obj->{object_name}) . ".gif";
        #			$p_obj->get_imagefile($l_image);
        #			$l_anchor= "<a href='/bin/SUB;web_fp_camera_popup?" . $p_obj->{object_name} . "'>";
        #		} else {
        #			$l_image='camera.gif';
        #		}
    }
    elsif ( $p_obj->isa('HVAC_Item') ) {

    }
    elsif ( $p_obj->isa('Temperature_Item') ) {
        $l_text = $p_obj->{object_name};
        $l_text .= ':' . $p_obj->state();
    }
    elsif ( $p_obj->isa('iButton') ) {
        $l_text = web_fp_filter_name( $p_obj->{object_name} );
        $l_text .= ':' . $p_obj->read_temp();
    }
    elsif ( $p_obj->isa('Generic_Item') ) {
        if ( $p_obj->state eq 'off' ) {
            $l_image = 'fp-light-off.gif';
            $l_state = 'on';
        }
        else {
            $l_image = 'fp-light-on.gif';
            $l_state = 'off';
        }
    }
    else {    #Unknown object
        $l_text = web_fp_filter_name( $p_obj->{object_name} );
        $l_text .= ':' . $p_obj->state();
    }

    # Check for custom icons
    my %icons = $p_obj->get_fp_icons();
    if ( ( keys %icons ) and $icons{ $p_obj->state } ) {
        $l_image = $icons{ $p_obj->state };
    }

    if ( $l_state ne '' ) {
        my ($l_str) = $l_text =~ /\$(.*)/;
        $l_html .=
            "<a href='/bin/SET;referer?"
          . $p_obj->{object_name}
          . "=$l_state' title='"
          . $l_str . "'>";
    }
    if ( $l_image ne '' ) {
        $l_html .= "<img src='/graphics/$l_image' border=0 alt='$l_text'>";
    }
    else {
        $l_html .= "<font size='-2'>$l_text</font>";
    }
    if ( $l_state ne '' ) {
        $l_html .= "</a>";
    }
    return $l_html;
}

sub web_fp_idle_color #Fade color from acolor to bcolor over idle_time of object
{
    my ( $p_object, $p_acolor, $p_bcolor, $p_maxtime ) = @_;

    my ( $l_ared, $l_agreen, $l_ablue ) = $p_acolor =~ /#*(..)(..)(..)/;
    my ( $l_bred, $l_bgreen, $l_bblue ) = $p_bcolor =~ /#*(..)(..)(..)/;

    ( $l_ared, $l_agreen, $l_ablue ) =
      ( hex $l_ared, hex $l_agreen, hex $l_ablue );
    ( $l_bred, $l_bgreen, $l_bblue ) =
      ( hex $l_bred, hex $l_bgreen, hex $l_bblue );

    my ( $l_red, $l_green, $l_blue );
    my $l_time;

    #	my $l_max=10*60;
    $p_maxtime = 10 * 60 if !defined $p_maxtime;
    my $l_percent;
    my $l_basecolor = 40;
    my $l_maxcolor  = 255;
    my $l_color;

    $l_time = $p_object->get_idle_time();
    if ( $l_time > $p_maxtime ) {
        $l_time = $p_maxtime;
    }
    $l_percent = $l_time / $p_maxtime;
    if ( $l_ared > $l_bred ) {
        $l_red = int( $l_ared - ( ( $l_ared - $l_bred ) * ($l_percent) ) );
    }
    else {
        $l_red = int( $l_ared + ( ( $l_bred - $l_ared ) * ($l_percent) ) );
    }
    if ( $l_agreen > $l_bgreen ) {
        $l_green =
          int( $l_agreen - ( ( $l_agreen - $l_bgreen ) * ($l_percent) ) );
    }
    else {
        $l_green =
          int( $l_agreen + ( ( $l_bgreen - $l_agreen ) * ($l_percent) ) );
    }
    if ( $l_ablue > $l_bblue ) {
        $l_blue = int( $l_ablue - ( ( $l_ablue - $l_bblue ) * ($l_percent) ) );
    }
    else {
        $l_blue = int( $l_ablue + ( ( $l_bblue - $l_ablue ) * ($l_percent) ) );
    }

    return ("#"
          . sprintf( "%02X", $l_red )
          . sprintf( "%02X", $l_green )
          . sprintf( "%02X", $l_blue ) );
}

sub web_fp_camera_popup {

}

sub web_fp_filter_name {
    my ($p_text) = @_;
    $p_text =~ s/^\$//g;
    $p_text =~ s/^\S_//g;
    $p_text =~ s/_/ /g;
    return $p_text;
}
