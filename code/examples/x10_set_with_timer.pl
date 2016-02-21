#> I was just wondering if anyone has tried to set up a voice command that
#> would allow a user to predefine light states and turn a light on for  a
#> specific amount of time?  Here is an example:
#>
#> my $light_states = 'on,brighten,dim,off,status';
#> my $lighttimer = '1,5,10,20';
#>
#> $v_bedroom_computer_light = new  Voice_Cmd "Bedroom Computer Light
#> [$light_states] for [$lighttimer] minutes.";

#Unfortunatly we can not currently specify multiple states in one command,
#but we CAN use set_with_timer to simplify your code.  Here is an example:

my $light_states = 'on,brighten,dim,off,status';

$v_light1 = new Voice_Cmd "Light [$light_states] for 1 minute";
$v_light5 = new Voice_Cmd "Light [$light_states] for 5 minute";

set_with_timer $light $state, 1 if $state = $v_light1;
set_with_timer $light $state, 5 if $state = $v_light5;

