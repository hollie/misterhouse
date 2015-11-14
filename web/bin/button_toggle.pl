# Return an href linked image that can be used to toggle the given object
# Call like this:   <!--#include file="/bin/button_toggle.pl?vacation_mode"-->
# Other examples are in in web/ia5/modes/main.shtml

# Authority: anyone

my ( $object, $referer ) = @ARGV;

my $state = eval "state \$$object";
print "button_toggle.pl error: $@" if $@;

# Use a custom .gif or auto-generate one with button.pl (if GD is installed)
my $image = "/graphics/${object}_$state.gif";
$image = '' unless &http_get_local_file($image);
$image = "/bin/button.pl?\$$object&item&$state" if !$image and $Info{module_GD};

if ($image) {
    $image = "<img src=$image alt='$object' border=0>";
}
else {
    $image = "$object -> $state";
}

print "button_toggle.pl:  o=$object s=$state i=$image\n"
  if $main::Debug{button};
if ($referer) {
    return "<a href='/SET;referer${referer}?$object=toggle'>$image</a>";
}
else {
    return "<a href='/SET;referer?$object=toggle'>$image</a>";
}

