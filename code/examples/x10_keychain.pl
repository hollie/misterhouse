#> I have one of the Key Chain Remotes that I want my wife to be able to
#> use from the car.
#> I have a group of X10_Items called $outside_lights and the code within
#> mh controls these lights just fine. But, I want to activate the same
#> group ($outside_lights) with the key chain remote. I'm leaving it set to
#> its default house code of "A" and want to utilize the identifiers 5&6
#> (selected from the switch inside the battery compartment).

# Lots of ways to do it.  Here is one suggestion:

$keychain = new Serial_Item( 'XA5AJ', '1-on' );
$keychain->add( 'XA5AK', '1-off' );
$keychain->add( 'XA6AJ', '2-on' );
$keychain->add( 'XA6AK', '2-off' );

set $outside_lights ON  if state_now $keychain eq '1-on';
set $outside_lights OFF if state_now $keychain eq '1-off';

#Here is another:

$keychain1 = new X10_Item 'A5';
$keychain1->tie_items($outside_lights);

