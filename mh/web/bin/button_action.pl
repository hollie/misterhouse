
# Process requests from the clicks on button_light images

# Use 'server side' image map xy to notice dim/bright requrests
# ISMAP data looks like this:  state?39,24
# Example: http://house:8080/bin/button_action.pl?X10_Item&$all_lights_living&on?39,24

my ($list_name, $item, $state_xy) = @ARGV;

my ($state, $x, $y) = $state_xy =~ /(\S+)\?(\d+),(\d+)/;
#print "db ln=$list_name, i=$item, s=$state_xy xy=$x,$y\n";

                                # Do not dim the dishwasher :)
unless (eval qq|$item->isa('X10_Appliance')|) {
    $state = 'dim'      if $x < 40;   # Left  side of image
    $state = 'brighten' if $x > 110;  # Right side of image
}

eval qq|$item->set("$state", 'web')|;
print "button_action.pl eval error: $@\n" if $@;

#   print "dbx4a i=$item s=$state\n";
#   my $object = &get_object_by_name($item);
#   $state =   $$object{state};
#   print "dbx4b i=$item s=$state\n";


my $h = &referer("/bin/list_buttons.pl?$list_name");
return &http_redirect($h);



