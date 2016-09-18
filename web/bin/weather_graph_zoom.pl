#!/usr/bin/perl
#
# $Date$
# $Revision$
#
#####################################################################
#  NOM		: weather_graph_zoom.pl
#  DESCRIPTION 	:

=begin comment
#@ Generate html page for weather graphs zoom
#@ mh parameter : nothing
=cut

#--------------------------------------------------------------------
# If you use the graphs on an Internet Web site, please add a link
# to www.misterhouse.net and www.domotix.net for your contribution
#--------------------------------------------------------------------
# 				HISTORY
#--------------------------------------------------------------------
#   DATE   REVISION    AUTHOR	        DESCRIPTION
#--------------------------------------------------------------------
# 14/05/04   1.0   Dominique Benoliel	Creation script
# 25/05/04   1.1   Dominique Benoliel
# - use Time::Local (and not Time::local)
# - change min, max, avg format
# 03/01/08   1.2   Chris Barrett
# - updated to respect the date_format parameter in mh.ini
#####################################################################
use Time::localtime;
use CGI;
use RRDs;
use Time::Local;
use File::Spec;

my $cgi = new CGI;

#==============================================================================
# Principal script
# Create html page for the weather graphs
#==============================================================================

# Debug mode
my $debug = 1 if $main::Debug{weather_graph};

my $rrd_format = $config_parms{weather_rrd_format};
$rrd_format = 'png' unless $rrd_format;    # default format is PNG

$rrd_format = 'gif'
  if $Http{'User-Agent'} eq 'Audrey';      # Audreys can't handle PNGs

tr/A-Z/a-z/ for $rrd_format;

my $native_rrd_format = $rrd_format;       # rrdtool will generate this format

if ( $RRDs::VERSION >= 1.2 and $rrd_format eq 'gif' ) {
    if ( $config_parms{weather_convert_png_to_gif} ) {
        $native_rrd_format = 'png';
    }
    else {
        &print_log(
            'weather_graph_zoom: you need to define weather_convert_png_to_gif in order for me to create GIFs with rrdtool version 1.2+'
        );
        $rrd_format = 'png';
    }
}

print $cgi->header;
print $cgi->start_html;
print &html_header('Weather Graphs Zoom');
print "<BASE TARGET =\"weather output\">";
my $rate = 60 * $config_parms{weather_graph_frequency};
print "<meta http-equiv='refresh' content='" . $rate . ";url='>" if $rate;

&print_prompts($cgi);

if ( $cgi->param ) {

    # Print parameters
    #  if (1) {
    #    my @values;
    #    my $key;
    #    print $cgi->br;
    #    my $lib;
    #    foreach $lib ( @INC ) {
    #	print "INC =" . $lib . "\n";
    #	print $cgi->br;
    #    }
    #    print $cgi->br;
    #    foreach $key ($cgi->param) {
    #      print $cgi->br;
    #      print $key . " = ";
    #      @values = $cgi->param($key);
    #      print "VAL", @values, "VAL";
    #      print $cgi->br;
    #    }
    #  }

    # Convert begin date in Epoch date
    #  my $day = $cgi->param('debday');
    #  my $month = $cgi->param('debmonth');
    #  my $year = $cgi->param('debyear');
    my $debepochtime = timelocal(
        0, 0, 0,
        $cgi->param('debday'),
        $cgi->param('debmonth') - 1,
        $cgi->param('debyear') - 1900
    );

    # Convert end date in Epoch date
    my $endepochtime = timelocal(
        59, 59, 23,
        $cgi->param('endday'),
        $cgi->param('endmonth') - 1,
        $cgi->param('endyear') - 1900
    );
    if ( $endepochtime > time() ) {
        $endepochtime = time();
    }

    if ( $debepochtime <= $endepochtime ) {
        my %sensor_names;
        &main::read_parm_hash( \%sensor_names,
            $main::config_parms{weather_graph_sensor_names} );
        &create_rrdgraph_zoom(
            $debepochtime,          $endepochtime,
            $cgi->param('width'),   $cgi->param('height'),
            $cgi->param('sensor1'), $sensor_names{ $cgi->param('sensor1') },
            $cgi->param('sensor2'), $sensor_names{ $cgi->param('sensor2') }
        );
    }
    else {
        &graph_error('STARTING DATE IS GREATER THAN ENDING DATE');
        return;
    }

    &print_graph;

}

print $cgi->end_html;

#==============================================================================
# Print error
#==============================================================================
sub graph_error {
    my ($message) = @_;
    print $cgi->start_center;
    print $cgi->br;
    print $cgi->br;
    print $cgi->start_table( { -bgcolor => "#000000", -border => "0" } );
    print $cgi->start_Tr;
    print $cgi->start_td( { -align => "center", -bgcolor => "#9999CC" } );
    print $cgi->font( { -size => "4" } );
    print $cgi->start_b;
    print $message;
    print $cgi->end_b;
    print $cgi->end_td;
    print $cgi->end_Tr;
    print $cgi->end_table;
    print $cgi->end_center;
}

#==============================================================================
# Print zoom graph
#==============================================================================
sub print_graph {
    print $cgi->start_center;
    print $cgi->start_table(
        {
            -width       => "591",
            -border      => "0",
            -cellpading  => "0",
            -cellspacing => "0"
        }
    );
    print $cgi->start_Tr;
    print $cgi->start_td( { -align => 'center' } );
    print $cgi->img(
        { src => "/rrd/weather_zoom.$rrd_format?" . time(), align => 'center' }
    );
    print $cgi->end_td;
    print $cgi->end_Tr;
    print $cgi->end_table();
    print $cgi->end_center;
}

#==============================================================================
# Print prompts for parameters
#==============================================================================
sub print_prompts {
    my ($cgi) = @_;
    my $RRDDIR;
    my @tabrrd;
    my $RRDFILE;
    my %sensor_names;
    my @list_sensors;
    my @list_sensors_names;

    # Initialisation parameters first call
    if ( !$cgi->param ) {
        $RRDFILE = "$config_parms{weather_data_rrd}";
        $RRDFILE =~ s/(.*)\/(.*\.rrd)/$2/;
        $cgi->param( -name => 'rrddatabase', -value => $RRDFILE );
        $cgi->param( -name => 'sensor1',     -value => 'temp' );
        $cgi->param( -name => 'sensor2',     -value => 'nosensor' );

        # Begin date = current date - 1 days
        my $endepochtime = time();
        my $debepochtime = $endepochtime - 24 * 3600;
        my $debtime      = localtime($debepochtime);
        $cgi->param( -name => 'debday',   -value => $debtime->mday );
        $cgi->param( -name => 'debmonth', -value => ( $debtime->mon + 1 ) );
        $cgi->param( -name => 'debyear',  -value => ( $debtime->year + 1900 ) );

        # End date = current date
        my $endtime = localtime($endepochtime);
        $cgi->param( -name => 'endday',   -value => $endtime->mday );
        $cgi->param( -name => 'endmonth', -value => $endtime->mon + 1 );
        $cgi->param( -name => 'endyear',  -value => $endtime->year + 1900 );

        $cgi->param( -name => 'height', -value => 250 );
        $cgi->param( -name => 'width',  -value => 600 );
    }

    print $cgi->start_center;
    print $cgi->start_table(
        {
            -width       => "710",
            -border      => "0",
            -cellpading  => "0",
            -cellspacing => "0"
        }
    );
    print $cgi->start_form(
        { -method => 'GET', -action => '/bin/weather_graph_zoom.pl' } );

    # Choose RRD database
    print $cgi->start_Tr;
    print $cgi->start_td(
        { -align => 'right', valign => "center", width => "90" } );
    print '<B>Round Robin Database</B>';
    print $cgi->end_td;
    $RRDDIR = "$config_parms{rrd_dir}";
    opendir DIR, "$RRDDIR" or die "Can't open $RRDDIR: $!";
    @tabrrd = grep /^.*\.rrd$/, readdir(DIR);
    print $cgi->start_td( { -align => 'left', -colspan => 1 } );
    print $cgi->popup_menu(
        -name    => 'rrddatabase',
        -value   => \@tabrrd,
        -default => $cgi->param('rrddatabase')
    );
    print $cgi->end_td;

    # Choose sensor name
    # Sensors list
    print $cgi->start_td( { -align => 'right', valign => "center" } );
    print '<B>Sensor 1</B>';
    print $cgi->br;
    print '<B>Sensor 2</B>';
    print $cgi->end_td;

    print $cgi->start_td(
        { -align => 'left', -colspan => 1, valign => "center" } );
    &main::read_parm_hash( \%sensor_names,
        $main::config_parms{weather_graph_sensor_names} );
    for my $sensor_name ( sort keys %sensor_names ) {
        push @list_sensors, $sensor_name;
    }

    # Later...next release...sort the labels in the popup
    #...to do...

    print $cgi->popup_menu(
        -name    => 'sensor1',
        -value   => \@list_sensors,
        -size    => 1,
        -default => $cgi->param('sensor1'),
        -labels  => \%sensor_names
    );
    print $cgi->br;

    # Add null value
    push @list_sensors, "nosensor";
    $sensor_names{"nosensor"} = "";
    print $cgi->popup_menu(
        -name    => 'sensor2',
        -value   => \@list_sensors,
        -size    => 1,
        -default => $cgi->param('sensor2'),
        -labels  => \%sensor_names
    );
    print $cgi->end_td;

    print $cgi->start_td(
        { -align => 'right', -colspan => 1, valign => "center" } );
    print $cgi->start_b;
    print "Width ";
    print $cgi->br;
    print "Height ";
    print $cgi->end_td;
    print $cgi->start_td(
        { -align => 'left', -colspan => 1, valign => "center" } );
    print $cgi->popup_menu(
        -name      => 'width',
        -size      => 1,
        -maxlength => 4,
        -value     => ( [ 1 .. 5000 ] ),
        -default   => $cgi->param('width')
    );
    print $cgi->br;
    print $cgi->popup_menu(
        -name      => 'height',
        -size      => 1,
        -maxlength => 4,
        -value     => ( [ 1 .. 1500 ] ),
        -default   => $cgi->param('height')
    );
    print $cgi->end_b;
    print $cgi->end_td;

    print $cgi->end_Tr;

    # Choose starting date
    # Init tab of days, months and years
    print $cgi->start_Tr;
    print $cgi->start_td( { -align => 'right', -width => 90 } );
    if ( $main::config_parms{date_format} =~ /^ddmmyy/ ) {
        print '<B>Starting date (dd/mm/yyyy) </B>';
        print $cgi->end_td;
        print $cgi->start_td( { -align => 'left' } );
        print $cgi->popup_menu(
            -name      => 'debday',
            -size      => 1,
            -maxlength => 2,
            -value     => [ 1 .. 31 ],
            -default   => ''
        );
        print $cgi->b(" / ");
        print $cgi->popup_menu(
            -name      => 'debmonth',
            -size      => 1,
            -maxlength => 2,
            -value     => [ 1 .. 12 ],
            -default   => ''
        );
    }
    else {
        print '<B>Starting date (mm/dd/yyyy) </B>';
        print $cgi->end_td;
        print $cgi->start_td( { -align => 'left' } );
        print $cgi->popup_menu(
            -name      => 'debmonth',
            -size      => 1,
            -maxlength => 2,
            -value     => [ 1 .. 12 ],
            -default   => ''
        );
        print $cgi->b(" / ");
        print $cgi->popup_menu(
            -name      => 'debday',
            -size      => 1,
            -maxlength => 2,
            -value     => [ 1 .. 31 ],
            -default   => ''
        );
    }
    print $cgi->b(" / ");
    print $cgi->popup_menu(
        -name      => 'debyear',
        -size      => 1,
        -maxlength => 4,
        -value     => [ 1999 .. 2015 ],
        -default   => ''
    );
    print $cgi->end_td;

    # Choose ending date
    # Init tab of days, months and years
    print $cgi->start_td( { -align => 'right', -width => 90 } );
    if ( $main::config_parms{date_format} =~ /^ddmmyy/ ) {
        print '<B>Ending date (dd/mm/yyyy) </B>';
        print $cgi->end_td;
        print $cgi->start_td( { -align => 'left' } );
        print $cgi->popup_menu(
            -name      => 'endday',
            -size      => 1,
            -maxlength => 2,
            -value     => [ 1 .. 31 ],
            -default   => ''
        );
        print $cgi->b(" / ");
        print $cgi->popup_menu(
            -name      => 'endmonth',
            -size      => 1,
            -maxlength => 2,
            -value     => [ 1 .. 12 ],
            -default   => ''
        );
    }
    else {
        print '<B>Ending date (mm/dd/yyyy) </B>';
        print $cgi->end_td;
        print $cgi->start_td( { -align => 'left' } );
        print $cgi->popup_menu(
            -name      => 'endmonth',
            -size      => 1,
            -maxlength => 2,
            -value     => [ 1 .. 12 ],
            -default   => ''
        );
        print $cgi->b(" / ");
        print $cgi->popup_menu(
            -name      => 'endday',
            -size      => 1,
            -maxlength => 2,
            -value     => [ 1 .. 31 ],
            -default   => ''
        );
    }
    print $cgi->b(" / ");
    print $cgi->popup_menu(
        -name      => 'endyear',
        -size      => 1,
        -maxlength => 4,
        -value     => [ 1999 .. 2015 ],
        -default   => ''
    );
    print $cgi->end_td;

    # Generate the graph
    print $cgi->start_td( { -align => 'center', -colspan => 2 } );
    print $cgi->submit( -name => 'submit', -value => 'Zoom...' );
    print $cgi->end_td;
    print $cgi->end_Tr;

    print $cgi->end_form;

    print $cgi->end_table;
    print $cgi->end_center;
}

#==============================================================================
# Convert step size in seconds to string format
# Input : step size in numeric format
# Output : step size in string format
# Note : d = day, h = hour, mn = minute, s = second
#==============================================================================
sub convertstepz {
    my ($stepnum) = @_;
    my $stepchar = '';
    my $temp;
    my $reste;

    if ( ( $temp = int( $stepnum / ( 24 * 3600 ) ) ) > 0 ) {
        $stepchar = $temp . 'd';
    }
    $reste = $stepnum - ( 24 * 3600 * int( $stepnum / ( 24 * 3600 ) ) );
    if ( ( $temp = int( $reste / 3600 ) ) > 0 ) {
        $stepchar .= $temp . 'h';
    }
    $reste = $reste - 3600 * int( $reste / 3600 );
    if ( ( $temp = int( $reste / 60 ) ) > 0 ) {
        $stepchar .= $temp . 'mn';
    }
    $reste = $reste - 60 * int( $reste / 60 );
    if ( $reste > 0 ) {
        $stepchar .= $reste . 's';
    }
    return $stepchar;
}

#==============================================================================
# rrdtool 1.2 and newer is picky about colons in the comment line
#==============================================================================
sub get_footer1 {
    my $step;
    my $datapoint;
    my $colon;
    my $footer;
    my ( $step, $datapoint ) = @_;
    if ( $RRDs::VERSION >= 1.2 ) {
        $colon = '\\\\\:';
    }
    else {
        $colon = ':';
    }
    $footer =
        "Step size$colon "
      . convertstepz($step)
      . "   Data points$colon $datapoint";
    return $footer;
}

sub get_footer2 {
    my $footer;
    if ( $RRDs::VERSION >= 1.2 ) {
        $footer = '$footer ' . "= \"$config_parms{weather_graph_footer}\";";
        eval $footer;
        $footer =~ s/:/\\\\\:/g;
    }
    else {
        $footer = $config_parms{weather_graph_footer};
    }
    return $footer;
}

#==============================================================================
# Build call function RRD::GRAPH for zoom
#==============================================================================
sub create_rrdgraph_zoom {
    my $celgtime;
    my $create_graph;
    my $colordatamoy  = 'ff0000'; # color of primary variable average line (red)
    my $colordatamoy2 = '330099'; # color of primary variable average line (red)
    my $colorna =
      'C0C0C0';   # color for unknown area or 0 for gaps (barre noire verticale)
    my $colordatamax  = '330099';    # color of min and max
    my $colordatamax2 = 'FFFF00';    # color of min and max
    my $colorwhite    = 'ffffff';    # color white
    my $str_graph;
    my $rrd_graph_dir;
    my $rrd_dir;

    my $err;
    my ( $start, $step, $names, $array );
    my $datapoint;
    my $starttime;
    my $secs;
    my $titrerrd;

    my (
        $time1,   $time2,      $gwidth,  $gheight,
        $sensor1, $libsensor1, $sensor2, $libsensor2
    ) = @_;

    print "SENSOR1=$sensor1 LIBSENSOR1=$libsensor1" if $debug;
    print "SENSOR2=$sensor2 LIBSENSOR2=$libsensor2" if $debug;

    # Calcul max lenght of sensor name
    my $max = 0;
    for my $sensor ( ( $libsensor1, $libsensor2 ) ) {
        if ( length($sensor) > $max ) {
            $max = length($sensor);
        }
    }
    print "Max sensor length name : ", $max if $debug;

    $rrd_graph_dir = $config_parms{weather_graph_dir};
    $rrd_dir       = $config_parms{weather_data_rrd};
    $rrd_dir =~ s/:/\\\\\:/g;

    $secs  = 60;
    $time1 = int( $time1 / $secs ) * $secs;
    $time2 = int( $time2 / $secs ) * $secs;

    $titrerrd =
      ( $sensor2 ne "nosensor" ) ? "$libsensor1, $libsensor2" : "$libsensor1";

    ( $start, $step, $names, $array ) =
      RRDs::fetch "$config_parms{weather_data_rrd}", "AVERAGE", "-s", "$time1",
      "-e", "$time2";
    $err = RRDs::error;
    die "ERROR : function RRDs::fetch : $err" if $err;
    $datapoint = $#$array + 1;
    my $starttime2 = localtime($start);

    # Build conversion string
    my $strvar;
    my $strminvar;
    my $strmaxvar;
    my $libuom;
    my $strvar2;
    my $strminvar2;
    my $strmaxvar2;
    my $libuom2;

    my $footer1;
    my $footer2;

    $footer1 = get_footer1( $step, $datapoint );
    $footer2 = get_footer2();

    $libuom    = "\"Unit of measurement (RRD database)\",";
    $strvar    = "\"CDEF:fvar=var\",";
    $strminvar = "\"CDEF:fmindata=mindata\",";
    $strmaxvar = "\"CDEF:fmaxdata=maxdata\",";
    if (   $sensor1 eq 'temp'
        or $sensor1 eq 'dew'
        or $sensor1 eq 'intemp'
        or $sensor1 eq 'indew'
        or $sensor1 eq 'tempspare1'
        or $sensor1 eq 'tempspare2'
        or $sensor1 eq 'tempspare3'
        or $sensor1 eq 'tempspare4'
        or $sensor1 eq 'tempspare5'
        or $sensor1 eq 'tempspare6'
        or $sensor1 eq 'tempspare7'
        or $sensor1 eq 'tempspare8'
        or $sensor1 eq 'tempspare9'
        or $sensor1 eq 'tempspare10'
        or $sensor1 eq 'dewspare1'
        or $sensor1 eq 'dewspare2'
        or $sensor1 eq 'dewspare3'
        or $sensor1 eq 'chill' )
    {
        $libuom = (
            $config_parms{weather_uom_temp} eq 'C'
            ? "\"Degrees Celcius\","
            : "\"Degrees Fahrenheit\","
        );
        $strvar = (
            $config_parms{weather_uom_temp} eq 'C'
            ? "\"CDEF:fvar=var,32,-,5,9,/,*\","
            : "\"CDEF:fvar=var\","
        );
        $strminvar = (
            $config_parms{weather_uom_temp} eq 'C'
            ? "\"CDEF:fmindata=mindata,32,-,5,9,/,*\","
            : "\"CDEF:fmindata=mindata\","
        );
        $strmaxvar = (
            $config_parms{weather_uom_temp} eq 'C'
            ? "\"CDEF:fmaxdata=maxdata,32,-,5,9,/,*\","
            : "\"CDEF:fmaxdata=maxdata\","
        );
    }
    if ( $sensor1 eq 'press' ) {
        $libuom = (
            $config_parms{weather_uom_baro} eq 'mb'
            ? "\"Millibars (mb)\","
            : "\"inch mercury (inHg)\","
        );
        $strvar = (
            $config_parms{weather_uom_baro} eq 'mb'
            ? "\"CDEF:fvar=var,0.029529987508,/\","
            : "\"CDEF:fvar=var\","
        );
        $strminvar = (
            $config_parms{weather_uom_baro} eq 'mb'
            ? "\"CDEF:fmindata=mindata,0.029529987508,/\","
            : "\"CDEF:fmindata=mindata\","
        );
        $strmaxvar = (
            $config_parms{weather_uom_baro} eq 'mb'
            ? "\"CDEF:fmaxdata=maxdata,0.029529987508,/\","
            : "\"CDEF:fmaxdata=maxdata\","
        );
    }
    if ( $sensor1 eq 'dir' or $sensor1 eq 'avgdir' ) {
        $libuom = "\"Degrees\",";
    }
    if ( $sensor1 eq 'speed' or $sensor1 eq 'avgspeed' ) {
        $libuom = (
            $config_parms{weather_uom_wind} eq 'kph'
            ? "\"Killometers per hour (kph)\","
            : "\"Miles per hour (mph)\","
        );
        $strvar = (
            $config_parms{weather_uom_wind} eq 'kph'
            ? "\"CDEF:fvar=var,1.609344,*\","
            : "\"CDEF:fvar=var\","
        );
        $strminvar = (
            $config_parms{weather_uom_wind} eq 'kph'
            ? "\"CDEF:fmindata=mindata,1.609344,*\","
            : "\"CDEF:fmindata=mindata\","
        );
        $strmaxvar = (
            $config_parms{weather_uom_wind} eq 'kph'
            ? "\"CDEF:fmaxdata=maxdata,1.609344,*\","
            : "\"CDEF:fmaxdata=maxdata\","
        );
    }
    if ( $sensor1 eq 'rate' ) {
        $libuom = (
            $config_parms{weather_uom_rainrate} eq 'mm/hr'
            ? "\"Millimeters per hour (mm/hr)\","
            : "\"Inches per hour (in/hr)\","
        );
        $strvar = (
            $config_parms{weather_uom_rainrate} eq 'mm/hr'
            ? "\"CDEF:fvar=var,0.0393700787402,/\","
            : "\"CDEF:fvar=var\","
        );
        $strminvar = (
            $config_parms{weather_uom_rainrate} eq 'mm/hr'
            ? "\"CDEF:fmindata=mindata,0.0393700787402,/\","
            : "\"CDEF:fmindata=mindata\","
        );
        $strmaxvar = (
            $config_parms{weather_uom_rainrate} eq 'mm/hr'
            ? "\"CDEF:fmaxdata=maxdata,0.0393700787402,/\","
            : "\"CDEF:fmaxdata=maxdata\","
        );
    }
    if ( $sensor1 eq 'rain' ) {
        $libuom = (
            $config_parms{weather_uom_rain} eq 'mm'
            ? "\"Millimeters (mm)\","
            : "\"Inches (in)\","
        );
        $strvar = (
            $config_parms{weather_uom_rain} eq 'mm'
            ? "\"CDEF:fvar=var,0.0393700787402,/\","
            : "\"CDEF:fvar=var\","
        );
        $strminvar = (
            $config_parms{weather_uom_rain} eq 'mm'
            ? "\"CDEF:fmindata=mindata,0.0393700787402,/\","
            : "\"CDEF:fmindata=mindata\","
        );
        $strmaxvar = (
            $config_parms{weather_uom_rain} eq 'mm'
            ? "\"CDEF:fmaxdata=maxdata,0.0393700787402,/\","
            : "\"CDEF:fmaxdata=maxdata\","
        );
    }
    if (   $sensor1 eq 'humid'
        or $sensor1 eq 'inhumid'
        or $sensor1 eq 'humidspare1'
        or $sensor1 eq 'humidspare2'
        or $sensor1 eq 'humidspare3'
        or $sensor1 eq 'humidspare4'
        or $sensor1 eq 'humidspare5'
        or $sensor1 eq 'humidspare6'
        or $sensor1 eq 'humidspare7'
        or $sensor1 eq 'humidspare8'
        or $sensor1 eq 'humidspare9'
        or $sensor1 eq 'humidspare10' )
    {
        $libuom = "\"Percent %\",";
    }

    ( $strvar2    = $strvar ) =~ s/var/var2/g;
    ( $strminvar2 = $strminvar ) =~ s/mindata/mindata2/g;
    ( $strmaxvar2 = $strmaxvar ) =~ s/maxdata/maxdata2/g;

    $str_graph =
      qq^RRDs::graph("$rrd_graph_dir/weather_zoom.$native_rrd_format",
"--title", "Environmental data : $titrerrd",
"--height","$gheight",
"--width", "$gwidth",
"--imgformat", "^ . uc($native_rrd_format) . qq^",
"--alt-autoscale",
"--interlaced",
"--step","120",
"--units-exponent", "0",
"--color","SHADEA#0000CC",
"--color","SHADEB#0000CC",
^
      . "\"--vertical-label\","
      . "$libuom"
      . "\"--start\","
      . "\"$time1\","
      . "\"--end\","
      . "\"$time2\","

      . "\"DEF:var=$rrd_dir:"
      . $sensor1
      . ":AVERAGE\","
      . "$strvar"
      . "\"DEF:mindata=$rrd_dir:"
      . $sensor1
      . ":MIN\","
      . "$strminvar"
      . "\"DEF:maxdata=$rrd_dir:"
      . $sensor1
      . ":MAX\","
      . "$strmaxvar"

      . (
        $sensor2 ne "nosensor"
        ? "\"DEF:var2=$rrd_dir:" . $sensor2 . ":AVERAGE\","
        : ''
      )
      . ( $sensor2 ne "nosensor" ? "$strvar2" : '' )
      . (
        $sensor2 ne "nosensor"
        ? "\"DEF:mindata2=$rrd_dir:" . $sensor2 . ":MIN\","
        : ''
      )
      . ( $sensor2 ne "nosensor" ? "$strminvar2" : '' )
      . (
        $sensor2 ne "nosensor"
        ? "\"DEF:maxdata2=$rrd_dir:" . $sensor2 . ":MAX\","
        : ''
      )
      . ( $sensor2 ne "nosensor" ? "$strmaxvar2" : '' )
      . "\"CDEF:wipeout=var,UN,INF,UNKN,IF\","
      . "\"CDEF:wipeout2=var,UN,NEGINF,UNKN,IF\","
      . "\"LINE2:fvar#$colordatamoy:"
      . sprintf( "%-${max}s", $libsensor1 )
      . " (Average)\"," . qq^
"GPRINT:fmindata:MIN:Min \\\\: %5.1lf",
"GPRINT:fmaxdata:MAX:Max \\\\: %5.1lf",
"GPRINT:fvar:AVERAGE:Avg \\\\: %5.1lf",
"GPRINT:fvar:LAST:Last \\\\: %5.1lf\\\\n",
^
      . (
        $sensor2 ne "nosensor"
        ? "\"LINE2:fvar2#$colordatamoy2:"
          . sprintf( "%-${max}s", $libsensor2 )
          . " (Average)\","
        : ''
      )
      . (
        $sensor2 ne "nosensor" ? "\"GPRINT:fmindata2:MIN:Min \\\\: %5.1lf\","
        : ''
      )
      . (
        $sensor2 ne "nosensor" ? "\"GPRINT:fmaxdata2:MAX:Max \\\\: %5.1lf\","
        : ''
      )
      . (
        $sensor2 ne "nosensor" ? "\"GPRINT:fvar2:AVERAGE:Avg \\\\: %5.1lf\","
        : ''
      )
      . (
        $sensor2 ne "nosensor"
        ? "\"GPRINT:fvar2:LAST:Last \\\\: %5.1lf\\\\n\","
        : ''
      )
      . qq^
"AREA:wipeout#$colorna:No data\\\\n",
"AREA:wipeout2#$colorna:No data\\\\n",
^
      . "\"COMMENT:$footer1\\\\c\"," . "\"COMMENT:$footer2\\\\c\"" . ")";

    print "$str_graph" if $debug;
    eval $str_graph;
    my $err = RRDs::error;
    die "ERROR : function RRDs::graph : $err\n" if $err;
    if ( $rrd_format ne $native_rrd_format ) {
        if ( $rrd_format eq 'gif' and $native_rrd_format eq 'png' ) {
            my $pngFilename =
              File::Spec->catfile( $rrd_graph_dir, "weather_zoom.png" );
            my $gifFilename =
              File::Spec->catfile( $rrd_graph_dir, "weather_zoom.gif" );

            system( $config_parms{weather_convert_png_to_gif},
                $pngFilename, $gifFilename );
        }
        else {
            &print_log(
                "weather_graph_zoom: sorry, don't know how to convert from $native_rrd_format to $rrd_format"
            );
        }
    }
}
