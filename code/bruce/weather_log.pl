# Category=Weather

#@ Logs weather data

# Use Generic_Item so we can save between reloads/restarts
my @weather_vars =
  qw(TempIndoor TempOutdoor WindChill HumidIndoor HumidOutdoor WindAvgSpeed sun_sensor);
$weather_stats = new Generic_Item;
$weather_stats->restore_data( 'count',
    ( map { $_ . '_min', $_ . '_max', $_ . '_avg' } @weather_vars ) )
  if $Reload;

# Log data and keep stats
if ( new_minute 1 ) {
    logit "$config_parms{data_dir}/logs/weather.$Year_Month_Now.log",
      sprintf(
        "tin=%4.1f tout=%4.1f wc=%4.1f hi=%4.1f ho=%4.1f wind=%4.1f sun=%4.1f cnt=%5d",
        ( map { $Weather{$_} } @weather_vars ),
        $$weather_stats{count}
      );

    for my $var (@weather_vars) {
        next
          unless $Weather{$var} =~ /\d/
          and $$weather_stats{ $var . '_max' } =~ /\d/;

        #       print "db v=$var ", $$weather_stats{$var . '_min'} . $$weather_stats{$var . '_max'} . $$weather_stats{$var . '_avg'}. "\n";
        $$weather_stats{ $var . '_min' } = $Weather{$var}
          if $Weather{$var} < $$weather_stats{ $var . '_min' };
        $$weather_stats{ $var . '_max' } = $Weather{$var}
          if $Weather{$var} > $$weather_stats{ $var . '_max' };
        $$weather_stats{ $var . '_avg' } += $Weather{$var};
    }
    $$weather_stats{count}++;
}

# Log stats daily
if ($New_Day) {
    logit "$config_parms{data_dir}/logs/weather_avg.$Year.log", sprintf(
        "tim=%4.1f tix=%4.1f tia=%4.1f "
          . "tom=%4.1f tox=%4.1f toa=%4.1f "
          . "wcm=%4.1f wcx=%4.1f wca=%4.1f "
          . "him=%4.1f hix=%4.1f hia=%4.1f "
          . "hom=%4.1f hox=%4.1f hoa=%4.1f "
          . "wdm=%4.1f wdx=%4.1f wda=%4.1f "
          . "snm=%4.1f snx=%4.1f sna=%4.1f "
          . "count=%4d",
        (
            map {
                $$weather_stats{ $_ . '_min' }, $$weather_stats{ $_ . '_max' },
                  $$weather_stats{ $_ . '_avg' } / $$weather_stats{count}
            } @weather_vars
        ),
        $$weather_stats{count}
    );
    $$weather_stats{count} = 0;
    map {
        $$weather_stats{ $_ . '_max' } = -999;
        $$weather_stats{ $_ . '_min' } = 999;
        $$weather_stats{ $_ . '_avg' } = 0
    } @weather_vars;
}

$weather_log = new Voice_Cmd('Show the weather log');
$weather_log->set_info('Shows the daily weather min/max/avg');
if ( said $weather_log) {
    display "$config_parms{data_dir}/logs/weather.$Year_Month_Now.log";
    display "$config_parms{data_dir}/logs/weather_avg.$Year.log";
}
