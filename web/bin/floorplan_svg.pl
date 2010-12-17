=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	floorplan_svg.pl
	
Description:
	Provides a function to render SVG floorplan .

Author:
	Pierrick DINTRAT
	pierrick.dintrat@laposte.net

License:
	This free software is licensed under the terms of the GNU public license.

Usage:
    http://localhost:8080/bin/floorplan_svg.pl
    http://localhost:8080/bin/floorplan_svg.pl?Property
    http://localhost:8080/bin/floorplan_svg.pl?Upstairs
	
Bugs:
	
Special Thanks to: 
	Bruce Winter - MH
	Jason Sharpee - floorplan.pl		
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use SVG;
$^W = 0;                 

my $object_name = shift || '$Property';
my $object = &get_object_by_name($object_name);

# This was giving Firefox fits until I change it to this setup
# create an SVG object
my $svg = SVG->new('xmlns:xlink'	=> 'http://www.w3.org/1999/xlink',
		   xmlns		=> 'http://www.w3.org/2000/svg',
		   viewBox		=> "0 0 1200 800", #
                   preserveAspectRatio	=> "none",
		   -indent		=> '  ',
);

my $top=$svg->group( id => 'group_top',style=> { stroke=>'green', fill=>'black' });

#return &svg_error('FloorPlan', "No $object_name Group found to generate a floorplan from") unless $object;

#&draw_top($top);
&web_fp($object);
&svg_page($svg->xmlify);

sub web_fp #render table representation of objects and their co-ordinates
{
	my ($p_obj) = @_;

	my @l_objs;
	my @n_objs;
	my $l_html;
	my @l_fp;
	my ($l_x,$l_y,$l_w,$l_h);
	my ($l_xmax,$l_ymax)=(-1,-1);
	my %l_rendered;
	my $l_obj;
	my $l_xscale=12;
	my $l_yscale=5;
	use vars qw($i $j); 

        # I know I need this but I'm not sure as to the what or the why - njc
        my $xOffset =  20; # Mine 105, his 110
        my $yOffset =  20; # Mine 120, his 110

        my $units = 10;         # 15px = 1 ft

	$i=1;
	$j=125;

	my $l_bcolor='#CCCCCC';
	my $l_acolor='#00FF00';

	my $title_room=$svg->text(id=>"title", x=>50, y=>75)->cdata(web_fp_filter_name($object_name));
	my $y=$svg->group( id => 'group_y',style=> { stroke=>'black', fill=>'white'});
	

	if ($p_obj->isa('Group')) 
	{
		@l_objs=@{$$p_obj{members}};
		for my $obj (@l_objs) { # Rooms
			($l_x,$l_y,$l_w,$l_h) = $obj->get_fp_location();

			# Just for keeping floorplan.pl coordonates
			# It was 10, I'm not sure that 12 is correct
			# times 10, the rooms are given in feet (I guess)
			$l_x *= 12; $l_x += $xOffset;	# Corrective offset to move it of the right edge of the display area
			$l_y *= 12; $l_y += $yOffset;    	# Corrective offset to move it of the top edge of the display area
			$l_w *= 12;
			$l_h *= 12;

			if ($l_x ne "") 
			{ 
				$y->rectangle(x=>$l_x, y=>$l_y,width =>$l_w, height => $l_h,ry=> 0,fill=>'lightgray',id=> "rect_y-$i" );
				my $group_name=$svg->text(id=>"room_name_$i",x=>$l_x+16,y=>$l_y+16)->cdata(web_fp_filter_name($obj->{object_name}));
				$i++;
				$j=125;
			} 
			@n_objs = @{$$obj{members}}; # This is the Devices within the Room
			for my $item (@n_objs) {
				my ($l_x_item,$l_y_item) = $item->get_fp_location();

				$l_x_item *= $units;
				$l_x_item += $l_x;
				$l_y_item *= $units;
				$l_y_item += $l_y;

				my ($l_text,$l_state,$l_image) = web_fp_item($item);

				$svg->anchor(-href=>"/bin/SET;referer?$l_text")->image(x=>$l_x_item,y=>$l_y_item,width=>15,height=>15,'-href'=>"$l_image");
			}
		}
	} 
	else 
	{
				($l_x,$l_y,$l_w,$l_h) = $p_obj->get_fp_location();
				my ($l_text,$l_state,$l_image) = web_fp_item($p_obj);
				$svg->text(x=>$l_x+6,y=>$l_y+6)->cdata(web_fp_filter_name($l_text));
				$svg->image(x=>$l_x,y=>$l_y,width=>15,height=>15,'-href'=>"$l_image");
	}
}


sub web_fp_item #render all items based on type
{
	my ($p_obj) = @_;

	my $l_html;
	my $l_text;
	my $l_state;
	my $l_image;

	$l_text=$$p_obj{object_name} . "=" . $p_obj->state;
	if ($p_obj->isa('Light_Item') or 
	    $p_obj->isa('Fan_Light') or
	    $p_obj->isa('X10_Item')) {
		if ($p_obj->state eq 'off') {
			$l_image='/graphics/fp-light-off.gif';
			$l_state='on';
			$l_text=$$p_obj{object_name} . "=" . $l_state;
		} else {
			$l_image='/graphics/fp-light-on.gif';
			$l_state='off';
			$l_text=$$p_obj{object_name} . "=" . $l_state;
		}	
	} elsif ($p_obj->isa('Motion_Item')) {
		if (lc($p_obj->state) eq 'on') {
			$l_image='/graphics/fp-motion-on.gif';
		} elsif ($p_obj->state eq 'check' ) {
			$l_image='/graphics/x.gif';
		} else {
			$l_image='/graphics/fp-motion-off.gif';
		}	
	} elsif ($p_obj->isa('Door_Item')) {
		if ($p_obj->state eq 'open') {
			$l_image='/graphics/fp-door-open.png';
		} else {
			$l_image='/graphics/fp-door-closed.png';
		}	
	} elsif ($p_obj->isa('Photocell_Item')) {
		if ($p_obj->state eq 'dark') {
			$l_image='/graphics/fp-dark-on.gif';
		} elsif ($p_obj->state eq 'check' ) {
			$l_image='/graphics/x.gif';
		} else {
			$l_image='/graphics/fp-dark-off.gif';
		}	
	} elsif ($p_obj->isa('Presence_Monitor')) {
		if ($p_obj->state eq 'occupied') {
			$l_image='/graphics/fp-people.gif';
		} elsif ($p_obj->state eq 'predict') {
			$l_image='/graphics/a1+.gif';
		} else {
			$l_image='/graphics/1pixel.gif';
		}	
	} elsif ($p_obj->isa('Appliance_Item')) {

#	} elsif ($p_obj->isa('Camera_Item')) {
#		if ($p_obj->state eq 'on') {
#			$l_image="/usr/local/mh/web/graphics/" . web_fp_filter_name($p_obj->{object_name}) . ".gif";
#			$p_obj->get_imagefile($l_image);
#			$l_anchor= "<a href='/bin/SUB;web_fp_camera_popup?" . $p_obj->{object_name} . "'>";
#		} else {
#			$l_image='camera.gif';
#		}	
	} elsif ($p_obj->isa('HVAC_Item')) {

	} elsif ($p_obj->isa('Temperature_Item')) {
		$l_text=$p_obj->{object_name};
		$l_text.=':' . $p_obj->state();
	} elsif ($p_obj->isa('iButton')) {
		$l_text=web_fp_filter_name($p_obj->{object_name});
		$l_text.=':' . $p_obj->read_temp();
	} else { #Unknown object
		$l_text=web_fp_filter_name($p_obj->{object_name});
		$l_text.=':' . $p_obj->state();
	}

	return ($l_text,$l_state,$l_image);
}

sub web_fp_filter_name
{
	my ($p_text) = @_;
	$p_text=~ s/^\$//g;
	$p_text=~ s/^\S_//g;
	$p_text=~ s/_/ /g;
	return $p_text;
}

sub draw_top
{
	my ($group_top)=@_;

	# Admin button icon_auth.pl
	my $icon = '/ia5/images/login.gif';
	if ($Authorized) 
	{
		$icon = "/ia5/images/logout_$Authorized.gif";
		$icon = '/ia5/images/logout.gif' unless &http_get_local_file($icon);
	}

	my $action = ($Authorized) ? "/UNSET_PASSWORD?user=$Authorized" : "/SET_PASSWORD?user=$Authorized";
			   
	$group_top->anchor(-href=>"$config_parms{html_file}")->image(x=>5,y=>5,width=>238,height=>55,'-href'=>"/ia5/images/mhlogo.gif",id=>'top_1');
	# $group_top->anchor(-href=>"./javascript:history.go(-1)")->image(x=>650,y=>5,width=>65,height=>55,'-href'=>"/ia5/images/back.gif",id=>'top_2');
	$group_top->anchor(-href=>"$config_parms{'web_href_my_mh'}",target => 'main')->image(x=>800,y=>5,width=>65,height=>55,'-href'=>"/ia5/images/my_mh.gif",id=>'top_3');
	$group_top->anchor(-href=>"/bin/menu.pl")->image(x=>900,y=>5,width=>65,height=>55,'-href'=>"/ia5/images/menus.gif",id=>'top_4');
	$group_top->anchor(-href=>"/ia5/house/search.html")->image(x=>1000,y=>5,width=>65,height=>55,'-href'=>"/ia5/images/search.gif",id=>'top_5');
	$group_top->anchor(-href=>"$action")->image(x=>1100,y=>5,width=>65,height=>55,'-href'=>"$icon",id=>'top_6');

}


