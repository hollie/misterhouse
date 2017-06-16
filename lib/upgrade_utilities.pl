package upgrade_utilities;

#set of subroutines that will store code that perform system-wide updates for new MH versions
<<<<<<< Updated upstream
use strict;
use RRD::Simple;

=======
use strict; 
use RRD::Simple; 
>>>>>>> Stashed changes
#added dependancy lib/site/RRD/Simple.pm
#weather_rrd_update.pl
#update 06/15/17 12:24:00 PM Oops2: /Users/howard/Develop/mh/data/rrd/weather_data.rrd: expected 107 data source readings (got 37) from 1497551040

sub upgrade_checks {

    &rrd_new_datasources();
}

sub rrd_new_datasources {
    &main::print_log("[Updater] : Checking RRD Schemas");
    my $rrd = RRD::Simple->new();
<<<<<<< Updated upstream

    my @sources = ( $main::config_parms{data_dir} . "/rrd/weather_data.rrd" );
    push @sources, $main::config_parms{weather_data_rrd} if ( defined $main::config_parms{weather_data_rrd} and $main::config_parms{weather_data_rrd} );

    my %dschk;
    my %newds;

    #for MH 4.3, add in some TempSpares as well as 30 placeholders
    $dschk{'4.3'} = "dsgauge020";
    @{ $newds{'4.3'} } = (
        { "NAME" => 'tempspare11', "TYPE" => "GAUGE" },
        { "NAME" => 'tempspare12', "TYPE" => "GAUGE" },
        { "NAME" => 'tempspare13', "TYPE" => "GAUGE" },
        { "NAME" => 'tempspare14', "TYPE" => "GAUGE" },
        { "NAME" => 'tempspare15', "TYPE" => "GAUGE" }
    );
    for ( my $i = 1; $i < 21; $i++ ) {
        push @{ $newds{'4.3'} }, { "NAME" => 'dsgauge' . sprintf( "%03d", $i ), "TYPE" => "GAUGE" };
    }
    for ( my $i = 1; $i < 11; $i++ ) {
        push @{ $newds{'4.3'} }, { "NAME" => 'dsderive' . sprintf( "%03d", $i ), "TYPE" => "DERIVE" };
    }

    foreach my $rrdfile (@sources) {
        if ( -e $rrdfile ) {
            &main::print_log("[Updater::RRD] : Checking file $rrdfile...");

            my %rrd_ds = map { $_ => 1 } $rrd->sources($rrdfile);

            foreach my $key ( keys %dschk ) {

                unless ( exists $rrd_ds{ $dschk{$key} } ) {
                    foreach my $ds ( @{ $newds{$key} } ) {
                        unless ( exists $rrd_ds{ $ds->{NAME} } ) {
                            &main::print_log("[Updater::RRD] : v$key Adding new Data Source name:$ds->{NAME} type:$ds->{TYPE}");
                            $rrd->add_source( $rrdfile, $ds->{NAME} => $ds->{TYPE} );    #could also be DERIVE
                        }
                        else {
                            &main::print_log("[Updater::RRD] : v$key Skipping Existing Data Source $ds->{NAME}");

                        }

                    }
=======
    
    my @sources = ($main::config_parms{data_dir} . "/rrd/weather_data.rrd");
    push @sources, $main::config_parms{weather_data_rrd} if (defined $main::config_parms{weather_data_rrd} and $main::config_parms{weather_data_rrd});
    
    my %dschk;
    my %newds;
    #for MH 4.3, add in some TempSpares as well as 30 placeholders
    $dschk{'4.3'} = "dsgauge020";
    @{$newds{'4.3'}} = ({"NAME" => 'tempspare11', "TYPE" => "GAUGE"}, 
            {"NAME" =>'tempspare12',"TYPE" => "GAUGE"},
            {"NAME" =>'tempspare13', "TYPE" => "GAUGE"},
            {"NAME" =>'tempspare14', "TYPE" => "GAUGE"},
            {"NAME" =>'tempspare15', "TYPE" => "GAUGE"});
    for (my $i=1; $i<21; $i++) {
        push @{$newds{'4.3'}}, {"NAME" => 'dsgauge' . sprintf("%03d",$i), "TYPE" => "GAUGE"};
    }
    for (my $i=1; $i<11; $i++) {
        push @{$newds{'4.3'}}, {"NAME" => 'dsderive' . sprintf("%03d",$i), "TYPE" => "DERIVE"};
    }    
    

    foreach my $rrdfile (@sources) {
        if (-e $rrdfile) {
            &main::print_log("[Updater::RRD] : Checking file $rrdfile...");

            my %rrd_ds = map { $_ => 1 } $rrd->sources($rrdfile);
    
            foreach my $key (keys %dschk) {
    
                unless (exists $rrd_ds{$dschk{$key}}) {
                    foreach my $ds (@{$newds{$key}}) {
                        unless (exists $rrd_ds{$ds->{NAME}}) {
                            &main::print_log("[Updater::RRD] : v$key Adding new Data Source name:$ds->{NAME} type:$ds->{TYPE}");
                            $rrd->add_source($rrdfile, $ds->{NAME} => $ds->{TYPE}); #could also be DERIVE
                        } else {
                            &main::print_log("[Updater::RRD] : v$key Skipping Existing Data Source $ds->{NAME}");

                        }
                       
                    } 
>>>>>>> Stashed changes
                }
            }
        }
    }
}

<<<<<<< Updated upstream
1;
=======
1;
>>>>>>> Stashed changes
