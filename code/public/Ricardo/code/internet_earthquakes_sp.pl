# Category = Informational

# $Date$
# $Revision$

#@ This module checks the Spanish Geographic Institute earthquake
#@ Information Center to get the most recent earthquakes that have
#@ occurred and presents those that were at least the minimum
#@ magnitude(s) specified. You'll need to have your latitude and
#@ longitude parameters set properly.
#@
#@ If you want to customize your magnitude thresholds, set a variable
#@ like this in your ini file:
#@
#@ Earthquake_Magnitudes = 99999 5.5 1000 3.5 500 0
#@
#@ You can also set a variable to limit the number of quakes to display.
#@ To show only the two most recent quakes, regardless of magnitude, set
#@ the following variables in your ini file:
#@
#@ Earthquake_Magnitudes = 99999 0
#@ Earthquake_Count = 2

=begin comment

internet_earthquakes_sp.pl

When quakes are read, the date/time and location information are converted
to relative units (i.e. 3 hours ago, yesterday at 5pm, 53 miles away) and 
and those that don't meet magnitude thresholds are omitted.

If you want to customize your magnitude thresholds, set a variable
like this in your ini file:

  Earthquake_Magnitudes = 99999 5.5 1000 3.5 500 0

You can also set a variable to limit the number of quakes to display.
To show only the two most recent quakes, regardless of magnitude, set
the following variables in your ini file:

  Earthquake_Magnitudes = 99999 0
  Earthquake_Count = 2

Note: If you live in the western hemisphere, this script needs your
longitude .ini variable to be negative.

=cut

# Add earthquake image to Informational category web page
if ($Reload) {
    $Included_HTML{'Informational'} .=
      qq(<h3>Latest Earthquake<p><img src='/data/web/earthquakes.gif?<!--#include code="int(100000*rand)"-->'><p>\n\n\n);
}

# Default Magnitude Thresholds
my %Magnitude_thresholds = (
    99999, 5.5,    # show anything anywhere over 5.5
    1000,  3.5,    # show anything within 1000 Km over 3.5
    500,   0,      # show anything within 500 Km any size
);

if ( $config_parms{Earthquake_Magnitudes} ) {
    %Magnitude_thresholds = split ' ', $config_parms{Earthquake_Magnitudes};
}

# Maximum number of quakes to show
my $Earthquake_Count = 5;

if ( $config_parms{Earthquake_Count} ) {
    $Earthquake_Count = $config_parms{Earthquake_Count};
}

my $f_earthquakes_html = "$config_parms{data_dir}/web/earthquakes.html";
my $f_earthquakes_data = "$config_parms{data_dir}/earthquakes_data";
$f_earthquakes_file = new File_Item($f_earthquakes_data);
$f_earthquakes_gif =
  new File_Item("$config_parms{data_dir}/web/earthquakes.gif");

my $image;
$p_earthquakes_image = new Process_Item;

#p_earthquakes = new Process_Item qq[get_url "http://pangea.ign.es/servidor/sismo/cnis/proximo/proximo.html" "$f_earthquakes_html"];

$v_earthquakes = new Voice_Cmd('[Lee,Lista,Dime,Borra] terremotos recientes');
$v_earthquakes->set_info('Muestra la información de terremotos recientes');
$v_earthquakes->set_authority('anyone');
set_icon $v_earthquakes 'net';

$state = said $v_earthquakes;

if (   ( $state eq 'Lee' )
    or ( ( state $mode_mh eq 'normal' ) and time_cron("0,30 * * * *") ) )
{
    if (&net_connect_check) {

        #print_log "Buscando los terremotos recientes ...";

        &get_ec_earthquakes;
    }
}

if ( $state eq 'Lista' ) {
    my $text = $Save{quakes};
    $text =~ s/\t/\n/g;
    display $text;
}

if ( $state eq 'Borra' ) {
    print_log "Borrando lista de terremotos recientes ...";
    $Save{quakes} = "";
}

if ( $state eq 'Dime' ) {
    my $quake;
    my $num = 0;
    foreach ( split /\t/, $Save{quakes} ) {
        $quake = $_;
        return unless $num < $Earthquake_Count;
        $num += speak_quake($quake);
    }
}

if ( ( changed $f_earthquakes_file) or $Startup ) {

    #&update_earthquake_data if (changed $f_earthquakes_data);
    #&update_earthquake_data if $Startup;
    #sub update_earthquake_data {
    my $new_quakes = "";
    my ( $quake, $search );
    my $num = 0;

    my $text = file_read $f_earthquakes_data;

    #print "File: $f_earthquakes_data\n";
    #print "Terremotos text ---------->>>>\n$text\n";

    foreach ( split /\n/, $text ) {

        #Only look at lines with quake data on them
        if (/^(\d+)\s+(\S+)\s+(\S+)\s+(\S+)([NS])\s+(\S+)([EW])\s+(\S+)\s+(.+)/)
        {
            $search = $quake = $_;

            #    print "Terremoto: $quake\n";
            if ( $Save{quakes} !~ /$search/ ) {
                $new_quakes = $new_quakes . $quake . "\t";
            }
        }
    }
    if ($new_quakes) {
        $Save{quakes} = $new_quakes . $Save{quakes};

        #   $Save{quakes} =~ s/^(([^\t]*\t){1,1000}).*/$1/;
        $Save{quakes} =~ s/^(([^\t]*\t){1,21}).*/$1/;    # Save last 21 quakes
        $image = '';
        foreach ( split /\t/, $new_quakes ) {
            $quake = $_;
            last unless $num < $Earthquake_Count;
            $num += speak_quake($quake);
        }
        set $p_earthquakes_image "get_url $image " . $f_earthquakes_gif->name;
        start $p_earthquakes_image if $image;
    }
}

use Math::Trig;

sub calc_distance {
    my ( $lat1, $lon1, $lat2, $lon2 ) = @_;
    my ( $c, $d );
    $c = 57.3;    # radian conversion factor

    $lat1 /= $c;
    $lat2 /= $c;
    $lon1 /= $c;
    $lon2 /= $c;
    $d = 2 * Math::Trig::asin(
        sqrt(
            ( sin( ( $lat1 - $lat2 ) / 2 ) )**2 +
              cos($lat1) * cos($lat2) * ( sin( ( $lon1 - $lon2 ) / 2 ) )**2
        )
    );

    return $d * ( .5 * 7915.6 * .86838 ) * 1.609344;  # convert to Km and return
}

sub calc_age {

    #Get the time sent in. This is UTC
    my $time = shift;

    #Split it up
    my ( $qyear, $qmnth, $qdate, $qhour, $qminu, $qseco ) =
      $time =~ m!(\S+)/(\S+)/(\S+)\s+(\S+):(\S+):(\S+)!;

    #Merge it
    my $qtime = timegm( $qseco, $qminu, $qhour, $qdate, $qmnth - 1, $qyear );

    #Split it again - these are now local time, not UTC
    ( $qseco, $qminu, $qhour, $qdate, $qmnth, $qyear ) = localtime($qtime);
    $qmnth += 1;

    #Merge it again - this is now local time, not UTC
    $qtime = timelocal( $qseco, $qminu, $qhour, $qdate, $qmnth - 1, $qyear );

    my $midnight = timelocal( 0, 0, 0, $Mday, $Month - 1, $Year - 1900 );
    my $diff = (
        time -
          timelocal( $qseco, $qminu, $qhour, $qdate, $qmnth - 1, $qyear ) );

    return "hace " . int( $diff / 60 ) . " minutos " if ( $diff < 60 * 120 );
    return "hace " . int( $diff / ( 60 * 60 ) ) . " horas "
      if ( $qtime > $midnight );
    my $hour;
    if ( $qhour != 0 ) { $qhour =~ s!^0!! }

    #   $qminu =~ s!^0!!;
    $hour = "$qhour $qminu";

    #   if ($qhour == 0) {$hour = "12 AM"}
    #   elsif ($qhour < 12) {$hour = "$qhour AM"}
    #   elsif ($qhour == 12) {$hour = "12 PM"}
    #   else {$hour = $qhour - 12 . " PM"}
    return "Ayer a las $hour " if ( $qtime > $midnight - 60 * 60 * 24 );
    return
        "hace "
      . int( $diff / ( 60 * 60 * 24 ) + .5 )
      . " días a las $hour ";
}

# EVENTO FECHA-HORA GMT LATITUD LONGITUD MAG SENTIDO MEC PROF LOCALIZACIÓN
# 516257 2004/10/15 08:21:44 36.53N 4.51W 2.2 84 S TORREMOLINOS

sub speak_quake {

    #   print "Speak_quake: $_\n";
    if (
        my (
            $qevent, $qdate, $qtime,  $qlatd, $qnoso, $qlong,
            $qeawe,  $qmagn, $qpercv, $qmec,  $qdept, $qloca
        )
        = $_ =~
        m!^(\d+)\s+(\S+)\s+(\S+)\s+(\S+)([NS])\s+(\S+)([EW])\s+(\S+)\s*(SI)?\s*(\S+)?\s*(\d+)?\s+(.+)!
      )
    {
        my $distance;
        my $clatd = $config_parms{quakes_ref_latitude};
        my $clong = $config_parms{quakes_ref_longitude};
        my $ccity = $config_parms{quakes_ref_city};
        $qlatd *= -1 if ( $qnoso eq "S" );
        $qlong *= -1 if ( $qeawe eq "W" );
        if ( $clatd && $clong && $ccity ) {

            # reference to a diferent place
            $distance = sprintf "%d kilómetros de %s,",
              calc_distance( $clatd, $clong, $qlatd, $qlong ) + .5, $ccity;
        }
        else {
            # reference distance to mh home city
            $distance = sprintf "%d kilómetros",
              calc_distance( $config_parms{latitude}, $config_parms{longitude},
                $qlatd, $qlong ) + .5;
        }
        for ( keys %Magnitude_thresholds ) {
            if ( $distance <= $_ and $qmagn >= $Magnitude_thresholds{$_} ) {

                #         my $long_reso = abs(5 * round($qlatd/5)) > 45 ? (abs(5 * round($qlatd/5)) > 65 ? 20 : 10) : 5;
                $image = 'http://pangea.ign.es/servidor/sismo/cnis/proximo/'
                  . $qevent . '.gif';
                my ( $direction, $local, $area, $where );
                ( $direction, $local ) = $qloca =~ m!^([NS]?[EW]?)\s+(.+)!;

                #         print "qloca: $qloca, direction: $direction, local: $local\n";
                if ($direction) {
                    $direction =
                      convert_direction( &convert_to_degrees($direction) );
                    my $aux = $local;
                    ( $local, $area ) = $aux =~ m!^(.+?)\.(\S+)!;
                    $local = lc $local;
                    $where = "al $direction de "
                      . ( $local ? "$local ($area)" : lc $aux );
                }
                else {
                    ( $local, $area ) = $qloca =~ m!^(.+?)\.(\S+)!;
                    $local = lc $local;
                    $where =
                      "cerca de " . ( $local ? "$local ($area)" : lc $qloca );
                }
                speak &calc_age("$qdate $qtime")
                  . "ha ocurrido un seísmo de magintud $qmagn a una distancia de $distance $where";
                return 1;
            }
        }
    }
    return 0;
}

## lets allow the user to control via triggers
#
#if ($Reload) {
#    eval qq(
#        &trigger_set('\$New_Hour and net_connect_check', "run_voice_cmd 'Lee terremotos recientes'", 'NoExpire', 'get earthquakes')
#          unless &trigger_get('get earthquakes');
#    );
#}

# Fetch the raw HTML weather page from the es.weather.yahoo.com
# update the parsed data file.
sub get_ec_earthquakes {
    my $force = shift;

    my $pgm = "get_earthquakes_sp";
    $pgm .= " -reget" if $force;

    #print_log "running $pgm";
    run $pgm;

    #print_log "Earthquakes update started";

    set_watch $f_earthquakes_file;
}

# convert text wind direction to degrees.
sub convert_to_degrees {
    my $text = shift;
    my $dir;

    ( $text eq 'N' )   && ( $dir = 0 );
    ( $text eq 'NNE' ) && ( $dir = 22 );
    ( $text eq 'NE' )  && ( $dir = 45 );
    ( $text eq 'ENE' ) && ( $dir = 67 );

    ( $text eq 'E' )   && ( $dir = 90 );
    ( $text eq 'ESE' ) && ( $dir = 112 );
    ( $text eq 'SE' )  && ( $dir = 135 );
    ( $text eq 'SSE' ) && ( $dir = 157 );

    ( $text eq 'S' )   && ( $dir = 180 );
    ( $text eq 'SSW' ) && ( $dir = 202 );
    ( $text eq 'SW' )  && ( $dir = 225 );
    ( $text eq 'WSW' ) && ( $dir = 247 );

    ( $text eq 'W' )   && ( $dir = 270 );
    ( $text eq 'WNW' ) && ( $dir = 292 );
    ( $text eq 'NW' )  && ( $dir = 315 );
    ( $text eq 'NNW' ) && ( $dir = 337 );

    return $dir;
}

