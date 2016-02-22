# Category=Sprinklers

=begin comment 

By David Norwood, dnorwood2@yahoo.com	

This is how I control sprinker valves wired to a SECU-16, which is attached to an Ocelot. 
If you have more than one module attached to your Ocelot, use something like 'OUTPUT8@2high'. 

=cut

$back_yard_north_lawn_sprinklers =
  new Serial_Item( 'OUTPUT8high', ON, "ncpuxa" );
$back_yard_north_lawn_sprinklers->add( 'OUTPUT8low', OFF );
$back_yard_south_lawn_sprinklers =
  new Serial_Item( 'OUTPUT9high', ON, "ncpuxa" );
$back_yard_south_lawn_sprinklers->add( 'OUTPUT9low', OFF );
$back_yard_far_flowerbed_sprinklers =
  new Serial_Item( 'OUTPUT10high', ON, "ncpuxa" );
$back_yard_far_flowerbed_sprinklers->add( 'OUTPUT10low', OFF );
$back_yard_near_flowerbed_sprinklers =
  new Serial_Item( 'OUTPUT11high', ON, "ncpuxa" );
$back_yard_near_flowerbed_sprinklers->add( 'OUTPUT11low', OFF );
$front_yard_north_lawn_sprinklers =
  new Serial_Item( 'OUTPUT12high', ON, "ncpuxa" );
$front_yard_north_lawn_sprinklers->add( 'OUTPUT12low', OFF );
$front_yard_south_lawn_sprinklers =
  new Serial_Item( 'OUTPUT13high', ON, "ncpuxa" );
$front_yard_south_lawn_sprinklers->add( 'OUTPUT13low', OFF );
$side_yard_garden_sprinklers = new Serial_Item( 'OUTPUT14high', ON, "ncpuxa" );
$side_yard_garden_sprinklers->add( 'OUTPUT14low', OFF );
$front_yard_flowerbed_sprinklers =
  new Serial_Item( 'OUTPUT15high', ON, "ncpuxa" );
$front_yard_flowerbed_sprinklers->add( 'OUTPUT15low', OFF );

# noloop=start

my $list_sprinkler_items =
  join( ',', sort grep { /sprinkler/ } &list_objects_by_type('Serial_Item') );
$list_sprinkler_items =~ s/\$//g;
$list_sprinkler_toggle = new Voice_Cmd 'Toggle [' . $list_sprinkler_items . ']';

# noloop=stop

eval
  "my \$toggle = \$$state->state eq 'off' ? 'on' : 'off'; \$$state->set(\$toggle); print_log 'Turning $state ' . \$toggle"
  if $state = state_now $list_sprinkler_toggle;

=begin comment

The following code is an example of using the rain forecast to skip sprinkler cycles before and after 
the rain.

=cut

my $sprinkers_log = "$config_parms{data_dir}/sprinkers.log";

if ( time_cron "40 4,16 * * *" ) {
    foreach my $day ( split /\|/, $Weather{"Forecast Days"} ) {
        my $chance = $Weather{"Chance of rain $day"};
        if ( $chance > 50 ) {
            $Save{sprinkler_skip} = 3;
            last;
        }
    }
    return unless $Save{sprinkler_skip};
    if ( $Save{sprinkler_skip} == 3 ) {
        logit $sprinkers_log, "Rain forecasted, skipping sprinklers.";
        speak "Rain forecasted, skipping sprinklers.";
    }
    else {
        logit $sprinkers_log, "Skipping sprinklers due to recent rain.";
        speak "Skipping sprinklers due to recent rain.";
    }
    system 'nxacmd -v 2 -n 1';
}

$Save{sprinkler_skip}-- if $Save{sprinkler_skip} and $New_Day;

