# Description: Function that return an image source by getting a X10 object as input
# Use: Call this form a .shtml page with a X10 object as parameter
# Ex: <img src="<!--#include code="&X10Icon('$HallLights')"-->">
# By: samuel bagfors

sub X10Lamp {
    my $o;
    my $objState;
    my $icon;
    my ($arg1)  = @_;
    my $onIcon  = "/images/lighton.gif";
    my $offIcon = "/images/lightoff.gif";
    $o        = &get_object_by_name($arg1);
    $objState = $o->state;
    $icon     = "/images/dim.gif";
    if ( $objState eq 'on' ) {
        $icon = "<a href=\"/SET;referer?$arg1=off\"><imgsrc=$onIcon></a>";
    }
    if ( $objState eq 'off' ) {
        $icon = "<a href=\"/SET;referer?$arg1=on\"><imgsrc=$offIcon></a>";
    }
    return $icon;
}

# Use this function for this form of icon include:
#  <img src=http://localhost:8081/sub?web_icon_state('$test_lights')>

sub web_icon_state {
    my ($item) = @_;
    my $obj    = &get_object_by_name($item);
    my $state  = $obj->state;
    my $icon   = "$main::config_parms{html_dir}/graphics/$state.gif";
    print "db icon=$icon s=$state i=$item\n";
    my $image = file_read $icon;
    return $image;
}

