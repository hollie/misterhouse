use strict;

package Weather_Data;

@Weather_Data::ISA = ('Item');

use vars qw(%weather);
my @weather_item_list;

my $timer_sbweather_date = new Timer();
my $timer_vwweather_date = new Timer();

my $wx200_port;

# Common items:
# IsRaining, WindAvgSpeed, WindGustSpeed, WindAvgDir, HumidIndoor, HumidOutdoor, TempIndoor, TempOutdoor, Barom, RainTotal, RainYest, RainRate

my @weather_sbtype = qw(TimeStamp 
TempIndoor TempIndoorH TempIndoorL TempOutdoor TempOutdoorH TempOutdoorL 
HumidIndoor HumidIndoorH HumidIndoorL HumidOutdoor HumidOutdoorH HumidOutdoorL
WindGustSpeed WindGustDir WindAvgSpeed WindAvgDir WindHighSpeed WindHighDir 
Barom BaromSea RainTotal RainRate RainYest 
DewIndoor DewIndoorH DewIndoorL DewOutdoor DewOutdoorH DewOutdoorL WindChill WindChillL);

my @weather_vwtype = qw(Year Month Day Hour Minute Second
WindAvgSpeed WindGustSpeed WindAvgDir 
HumidIndoor HumidOutdoor
TempIndoor TempOutdoor
Barom
RainTotal
RainYest
RainRate
WeatherCondition);

sub Init
{
    $wx200_port = new Serial_Item(undef, undef, 'serial_wx200') if ($main::config_parms{serial_wx200}) 
    &::MainLoop_pre_add_hook(  \&Weather_Data::ProcessWeatherItems, 1 );
    &::MainLoop_post_add_hook( \&Weather_Data::ResetWeatherItems,   1 );
}

sub ProcessWeatherItems
{
    # Don't do it on the minute ... that is when sbweather updates!
    if (($main::New_Second and $main::Second == 30)) 
    {
        # Handle SB weather (code from Bruce)
        if($main::config_parms{weather_sblog_file} ne undef)
        {
            UpdateSbWeather(time);
        }

        # Handle Virtual weather
        if($main::config_parms{weather_vwlog_file} ne undef)
        {
            UpdateVwWeather();
        }

        if ($main::config_parms{serial_wx200} ne undef)         
        {
            UpdateWx200Weather();
        }

        # else check wx200
        # else parse web data?
        # else ?

        # WES handle object invocation.  Loop thru all current commands and
        # set tied objects to the corosponding state.
        my $object;
        foreach $object (@weather_item_list)
        {
            if($object->state_now)
            {
                unshift(@{$$object{state_log}}, "$main::Time_Date $object->state_now");
                pop @{$$object{state_log}} if @{$$object{state_log}} > $main::config_parms{max_state_log_entries};

                print "Object link: starting enumeration\n" if $main::config_parms{debug} eq 'events';
                my $ref;
                foreach $ref (@{$object->{'objects'}})
                {
                    my $state;
                    $state = ($ref->[1] ne undef) ? $ref->[1] : $object->state;
                    print "Object link: Setting $ref->[0] to $state\n" if $main::config_parms{debug} eq 'events';
                    $ref->[0]->set($state);
                }
                foreach $ref (@{$object->{'objects:'.lc($object->state)}})
                {
                    my $state;
                    $state = ($ref->[1] ne undef) ? $ref->[1] : $object->state;
                    print "Object link: Setting $ref->[0] to $state\n" if $main::config_parms{debug} eq 'events';
                    $ref->[0]->set($state);
                }

                print "Event link: starting enumeration\n" if $main::config_parms{debug} eq 'events';
                foreach $ref (@{$object->{'events'}})
                {
                    print "Event link: starting eval\n" if $main::config_parms{debug} eq 'events';
                    package main;   
                    eval $ref->[0];
                    package Weather_Data;
                }
                foreach $ref (@{$object->{'events:'.lc($object->state)}})
                {
                    print "Event link: starting eval\n" if $main::config_parms{debug} eq 'events';
                    package main;   
                    eval $ref->[0];
                    package Weather_Data;
                }
            }
        }
    }
}

sub ResetWeatherItems
{
    # Don't do it on the minute ... that is when sbweather updates!
    if (($main::New_Second and $main::Second == 30)) 
    {
        # Reset the object so state_now doesn't trigger
        my $object;
        foreach $object (@weather_item_list)
        {
            $object->{state} = $weather{$object->{type}};
        }
    }
}
        
sub UpdateSbWeather
{
    # Take the 2nd to last record from todays file
    my @temp = get_sbweather_record(time);

    my $i = 0;

    # If we got valid data
    my $raintotal_prev = $weather{RainTotal};
    if (@temp < 2) 
    {
        %weather = map{@weather_sbtype[$i++], 'unknown'} @weather_sbtype;
    }
    else 
    {
        %weather = map{@weather_sbtype[$i++], $_} @temp;

        $weather{HumidOutdoor} = 100 if $weather{HumidOutdoor} > 100;

        $weather{RainRecent} = round(($weather{RainTotal} - $raintotal_prev), 2) if $raintotal_prev > 0;
        if ($weather{RainRecent} > 0) 
        {
            #speak "Notice, it just rained $weather{RainRecent} inches";
            $weather{IsRaining}++;
        }
        elsif ($main::Minute % 20) 
        {   # Reset every 20 minutes
            $weather{IsRaining} = 0;
        }
    }                                
}

sub get_sbweather_record 
{
    my ($time) = @_;
    my $tail;
    
    #10/28/1998 08:35:32,72.500000,86.360000,63.860000,46.940000,98.060000,29.120000,45.000000,78.000000,33.000000,97.000000,97.000000,29.000000,0.000000,296.000000,0.000000,296.000000,41.831900,29.000000,28.850810,28.850810,13.818898,0.000000,0.905512,51.800000,75.200000,39.200000,46.400000,78.800000,32.000000,46.400000,14.000000

    # Read and parse data into %weather array
    my($min, $hour, $mday, $mon, $year) = (localtime($time))[1,2,3,4,5];
    my($wdate, $wtime, $whour, $wmin);
    my $date = sprintf("%02d%02d%4d", 1+$mon, $mday, 1900 + $year);
    my $file = $main::config_parms{weather_sblog_file};

    return unless -e $file;

    # If looking for current record, just tail the current file ... much faster
    if ($time > (time - 120)) 
    {
        my @tail = &file_tail($file);
        $tail = $tail[-2];      # Last record may not be complete
    }
    # Otherwise, parse the appropriate file till we get a time that matches
    else 
    {
        open (SBDATA, $file) or print "Warning, could not open weather file $file: $!\n";
        while (<SBDATA>) 
        {
            ($wdate, $whour, $wmin) = $_ =~ /^(\S+) +(\S+):(\S+):\S+\,/;
            #           print "db whour=$whour wmin=$wmin\n";
            if ($whour >= $hour and $wmin >= $min) 
            {
                $tail = $_;
                #               print "db min=$min tail=$tail\n";
                last;
            }
        }
        print "db date=$date,$wdate hour=$hour,$whour min=$min,$wmin\n" if $main::config_parms{debug} eq 'weather';
    }

    my @data = split(',', $tail);

    # Check to see if weather data is current
    ($wdate, $wtime) = split(' ', $data[0]);
    ($whour, $wmin) = split(':', $wtime);
    $wdate =~ s/\///g;
    my $time_diff = ($hour + $min/60) - ($whour + $wmin/60);
    
    # Make sure we have the right date, and if today, we are with an hour

    if (($date ne $wdate and $hour > 1) or ($time == time and $time_diff > 1)) 
    {
        if (inactive $timer_sbweather_date and (time - $main::Time_Startup_time) > 60 * 5 ) 
        {
            ::print_log "Weather data is not operational";
            set $timer_sbweather_date 60*60; # only warn once an hour
        }
        return;
    }
    else 
    {
        return @data;
    }
}

sub UpdateVwWeather
{
    my ($time) = time;
    my $tail;
    
    # 2000,6,7,23,58,9,0,0,357,35,84,77,53,28.00,0.28,0.00,0.00,0

    if($::New_Day)
    {
        $weather{WindHighDir} = undef
        $weather{WindHighSpeed} = undef;

        $weather{HumidIndoorH} = undef;
        $weather{HumidIndoorL} = undef;
        $weather{HumidOutdoorH} = undef;
        $weather{HumidOutdoorL} = undef;

        $weather{TempIndoorH} = undef;
        $weather{TempIndoorL} = undef;
        $weather{TempOutdoorH} = undef;
        $weather{TempOutdoorL} = undef;
    }

    # Read and parse data into %weather array
    my($min, $hour, $mday, $mon, $year) = (localtime($time))[1,2,3,4,5];
    my($wdate, $wyear, $wmonth, $wday, $whour, $wmin, $wsec);
    my $date = sprintf("%02d%02d%4d", 1+$mon, $mday, 1900 + $year);
    my $file = $main::config_parms{weather_vwlog_file};

    return unless -e $file;

    my @temp;
    open (SBDATA, $file) or print "Warning, could not open weather file $file: $!\n";
    for (<SBDATA>) 
    {
        @temp = split /,/;
    }

    if(@temp != 18)
    {
        print "Invalid data read from weather file $file\n";
        return;
    }


    # Check to see if weather data is current
    ($wyear, $wmonth, $wday, $whour, $wmin) = @temp;
    $wdate = sprintf("%02d%02d%4d", $wmonth, $wday, $wyear);

    my $time_diff = ($hour + $min/60) - ($whour + $wmin/60);
    
    # Make sure we have the right date, and if today, we are with an hour

    if (($date ne $wdate and $hour > 1) or ($time == time and $time_diff > 1)) 
    {
        if (inactive $timer_vwweather_date and (time - $main::Time_Startup_time) > 60 * 2 ) 
        {
            ::print_log "Weather data is not operational";
            set $timer_vwweather_date 60*60; # only warn once an hour
        }
        return;
    }

    print "db date=$date,$wdate hour=$hour,$whour min=$min,$wmin\n" if $main::config_parms{debug} eq 'weather';

    # If we got valid data
    my $raintotal_prev = $weather{RainTotal};

    my $i = 0;
    map{$weather{$weather_vwtype[$i++]} = $_} @temp;

    $weather{HumidOutdoor} = 100 if $weather{HumidOutdoor} > 100;

    $weather{WindHighDir} = $weather{WindAvgDir} if $weather{WindAvgSpeed} > $weather{WindHighSpeed} or $weather{WindHighDir} eq undef;
    $weather{WindHighSpeed} = $weather{WindAvgSpeed} if $weather{WindAvgSpeed} > $weather{WindHighSpeed} or $weather{WindHighSpeed} eq undef;
    $weather{WindHighSpeed} = $weather{WindGustSpeed} if $weather{WindGustSpeed} > $weather{WindHighSpeed};

    $weather{HumidIndoorH} = $weather{HumidIndoor} if $weather{HumidIndoor} > $weather{HumidIndoorH} or $weather{HumidIndoorH} eq undef;
    $weather{HumidIndoorL} = $weather{HumidIndoor} if $weather{HumidIndoor} < $weather{HumidIndoorL} or $weather{HumidIndoorL} eq undef;
    $weather{HumidOutdoorH} = $weather{HumidOutdoor} if $weather{HumidOutdoor} > $weather{HumidOutdoorH} or $weather{HumidOutdoorH} eq undef;
    $weather{HumidOutdoorL} = $weather{HumidOutdoor} if $weather{HumidOutdoor} < $weather{HumidOutdoorL} or $weather{HumidOutdoorL} eq undef;

    $weather{TempIndoorH} = $weather{TempIndoor} if $weather{TempIndoor} > $weather{TempIndoorH} or $weather{TempIndoorH} eq undef;
    $weather{TempIndoorL} = $weather{TempIndoor} if $weather{TempIndoor} < $weather{TempIndoorL} or $weather{TempIndoorL} eq undef;
    $weather{TempOutdoorH} = $weather{TempOutdoor} if $weather{TempOutdoor} > $weather{TempOutdoorH} or $weather{TempOutdoorH} eq undef;
    $weather{TempOutdoorL} = $weather{TempOutdoor} if $weather{TempOutdoor} < $weather{TempOutdoorL} or $weather{TempOutdoorL} eq undef;

    $weather{RainRecent} = ::round(($weather{RainTotal} - $raintotal_prev), 2) if $raintotal_prev > 0;
    if ($weather{RainRecent} > 0) 
    {
        #speak "Notice, it just rained $weather{RainRecent} inches";
        $weather{IsRaining}++;
    }
    elsif ($main::Minute % 20) 
    {   # Reset every 20 minutes
        $weather{IsRaining} = 0;
    }

}

sub UpdateWx200Weather
{
    if (my $data = said $wx200_port) 
    {
        # Process data, and reset incomplete data not processed this pass
        my $debug = 1 if $main::config_parms{debug} eq 'weather';
        my $remainder = &read_wx200($data, \%weather, $debug);
        set_data $wx200_port $remainder if $remainder;

        # Process data, and reset incomplete data not processed this pass
        my $raintotal_prev = 0;
        $weather{RainRecent} = round(($weather{RainTotal} - $raintotal_prev), 2) if $raintotal_prev > 0;
        if ($weather{RainRecent} > 0) 
        {
            $weather{IsRaining}++;
        }
        elsif ($::Minute % 20) 
        {  # Reset every 20 minutes
            $weather{IsRaining} = 0;
        }
    }
}

#
#
#
package Weather_Item;

# $x = new Weather_Item(TempIndoor);     # returns e.g. 68/82/etc
# $x = new Weather_Item(TempIndoor,>,99) # returns e.g. false/true

sub new 
{
    my ($class, $key, $comparison, $limit) = @_;

    if(($comparison ne undef) and ($comparison ne '<' and $comparison ne '>' and $comparison ne '='))
    {
        print "Invalid comparison operator (<>= valid) in Weather_Item\n";
        return;
    }
    #&? Verify key is valid here!

    my $self = {key => $key, comparison => $comparison, limit => $limit};
    bless $self, $class;
    push(@weather_item_list,$self);
    return $self;
}

sub state
{
    my ($self) = @_;
    return $Weather_Data::weather{$self->{type}} if($self->{comparison} eq undef);
    return ($Weather_Data::weather{$self->{type}} < ($self->{limit}) ? 1 : 0) if($self->{comparison} eq '<');
    return ($Weather_Data::weather{$self->{type}} > ($self->{limit}) ? 1 : 0) if($self->{comparison} eq '>');
    return ($Weather_Data::weather{$self->{type}} == ($self->{limit}) ? 1 : 0) if($self->{comparison} eq '=');
    return undef;
}

sub state_now
{
    my ($self) = @_;

    if($self->{state} ne $Weather_Data::weather{$self->{type}})
    {
        return $self->state();
    }
    return undef;
}

sub set
{
    print "Sorry, unable to control the weather.\n";
    return undef;
}

1;



