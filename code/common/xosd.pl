# Category=Home_Network
#
#@ XOsd control script.

use X::Osd ':all';

#noloop=start
my $osd = X::Osd->new(1);
$Xosd_text  = new Generic_Item;
$Xosd_state = new Generic_Item;

#	$osd->set_font("-*-helvetica-medium-r-normal-*-*-360-*-*-p-*-*-*");
$osd->set_colour("Yellow");
$osd->set_timeout(30);
$osd->set_shadow_colour("White");
$osd->set_outline_colour("Green");

#      $osd->set_pos(XOSD_top);
#      $osd->set_align(XOSD_right);
$osd->set_pos(0);
$osd->set_align(2);
$osd->set_horizontal_offset(0);
$osd->set_vertical_offset(100);
$osd->set_shadow_offset(2);

#noloop=stop

if ( $state = said $Xosd_text) {
    $osd->string( 0, $state );
}

if ( $state = said $Xosd_state) {
    if ( $state eq 'on' ) {
        $osd->show();
    }
    else {
        $osd->hide();
    }
}

sub display_osd {
    my ($text) = @_;
    set $Xosd_text $text;
    set $Xosd_state
      'off~1~on~1~off~1~on~1~off~1~on~1~off~1~on~1~off~1~on~1~off~1~on~15~off';
}

$v_xosd = new Voice_Cmd("Test xosd");

if ( said $v_xosd) {
    $v_xosd->respond('app=osd Testing on-screen display...');
    &display_osd("This is a test");
}

#$osd->set_font("-*-helvetica-medium-r-normal-*-*-360-*-*-p-*-*-*");
#     $osd->set_colour("Yellow");
#      $osd->set_timeout(30);
#	$osd->set_shadow_colour("White") ;
#	$osd->set_outline_colour("Green") ;
##      $osd->set_pos(XOSD_top);
##      $osd->set_align(XOSD_right);
#      $osd->set_pos(0);
#      $osd->set_align(2);
#      $osd->set_horizontal_offset(0);
#      $osd->set_vertical_offset(2);
#      $osd->set_shadow_offset(2);
#  $osd->string(0,'Hello World!');
#  sleep 5;
#      $osd->set_horizontal_offset(0);
#      $osd->set_vertical_offset(50);
#      $osd->set_shadow_offset(1);
#  $osd->percentage(0,56);
#   sleep 5;
#     $osd->set_horizontal_offset(0);
#      $osd->set_vertical_offset(90);
#      $osd->set_shadow_offset(2);
#  $osd->slider(0,34);
#  sleep 5;

