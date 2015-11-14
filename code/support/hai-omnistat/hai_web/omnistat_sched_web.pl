# Authority: admin

# 132 columns max
# 3456789112345678921234567893123456789412345678951234567896123456789712345678981234567899123456789012345678911234567892123456789312

=begin comment
This page can be used to program Omnistats.
You can also call it as http://server:8080/hai/omnistat_sched_web.pl?location=mbr_stat

Originally by Joel Davidson, Daniel Arnold et al
The HTML of this page is based on work by Kent Noonan.

2011/01/09 -- Mickey Argo/Karl Suchy/Marc MERLIN
- Added Omnistat2 code

2009/08/03 -- merlin
- cleanups, added debugging, logging and comments
- fixed to support 24H time, like the rest of the world uses :)
- added code to report stat not found errors as opposed to outputting perl errors
- output the stat type on the screen
- fixed to work with more than one thermostat
- fixed incorrect perl: $location == $statname should be $location eq $statname


=cut

# Authority: admin
my $html;
my @days;
my @vaca;
my $reg;
my $i;
my $location;
my $stat;
my $debug = '';
my $NAME  = "omnistat_sched_web.pl";

Omnistat::omnistat_debug( "$NAME: got args " . join( ", ", @ARGV ) );

#Get the thermostat to work on if provided in the URL
$location = $ARGV[0];

#this turns http://server:8080/hai/$NAME?location=bar into 'bar' -- merlin
if ( $location =~ /([^=]+)=(.+)/ and $2 ne "" ) {
    $location = $2;
    Omnistat::omnistat_debug("$NAME: Got location $location from URL");
}
my @locations;    #Holds the names of all the stats

#Get omnistat object names
foreach my $object_type (&::list_object_types) {
    foreach my $object_name ( &::list_objects_by_type($object_type) ) {
        my $object = &::get_object_by_name("$object_name");
        $object = $object_name unless $object;
        if ( $object and $object->isa('Omnistat') ) {
            Omnistat::omnistat_debug("$NAME: Found stat $object_name");
            push @locations, $object_name;
            if ( not $location ) {
                $location = $object_name;
                Omnistat::omnistat_debug(
                    "$NAME: Will set location to $location");
            }
        }
    }
}

#Now, we should either have a location from the URL or from the object list
$stat = &::get_object_by_name("$location");

if ( not $stat ) {
    if ( not $location ) {
        die
          "$NAME was not able to get an omnistat object, check your stat definitions in mycode/omnistat.pl";
    }
    else {
        die
          "$NAME was not able to get an omnistat object with location \"$location\"";
    }
}
else {
    Omnistat::omnistat_debug("$NAME: will work with stat $location");
}

my $IsOmnistat2 = 0;
$IsOmnistat2 = 1 if ( $stat->is_omnistat2 );

#Loop through the arguments passed
for ( $i = 1; $i <= $#ARGV; $i++ ) {
    Omnistat::omnistat_debug("$NAME: looking at arg# $i: $ARGV[$i]");

    # support 24H time like the rest of the educated world :) -- merlin
    if ( $ARGV[$i] =~ /(\w+?)=(\d+$|[012]?[0-9]:\d+(?: AM| PM|))/ and $2 ne "" )
    {
        #see if its a temp or time
        if ( $i % 3 != 1 ) {

            #It's a temp
            my $temp;
            Omnistat::omnistat_debug("$NAME: parsing temp arg# $i $1 => $2");
            $reg  = $i + 20;                         #Get the register to set
            $reg  = sprintf( "0x%x", $reg );
            $temp = &Omnistat::translate_temp($2);
            $stat->set_reg( $reg, $temp );
            $_     = "Set temp reg #$reg to $2 ($temp)";
            $debug = $debug . "$_<br>\n";
            Omnistat::omnistat_log($_);
        }
        else {
            #It's a time
            my $time;
            Omnistat::omnistat_debug("$NAME: parsing time arg# $i $1 => $2");
            $reg  = $i + 20;                         #Get the register to set
            $reg  = sprintf( "0x%x", $reg );
            $time = &Omnistat::translate_time($2);
            $stat->set_reg( $reg, $time );
            $_     = "Set time reg #$reg to $2 ($time)";
            $debug = $debug . "$_<br>\n";
            Omnistat::omnistat_log($_);
        }
    }
}

# Weekday (RC-xx) or Monday (Omnistat2)
my ( $wmt, $wmc, $wmh, $wdt, $wdc, $wdh, $wet, $wec, $weh, $wnt, $wnc, $wnh ) =
  split ' ', $stat->read_cached_reg( "0x15", 12 );
$days[0][0][0] = &Omnistat::translate_time($wmt);
$days[0][0][1] = &Omnistat::translate_temp($wmc);
$days[0][0][2] = &Omnistat::translate_temp($wmh);
$days[0][1][0] = &Omnistat::translate_time($wdt);
$days[0][1][1] = &Omnistat::translate_temp($wdc);
$days[0][1][2] = &Omnistat::translate_temp($wdh);
$days[0][2][0] = &Omnistat::translate_time($wet);
$days[0][2][1] = &Omnistat::translate_temp($wec);
$days[0][2][2] = &Omnistat::translate_temp($weh);
$days[0][3][0] = &Omnistat::translate_time($wnt);
$days[0][3][1] = &Omnistat::translate_temp($wnc);
$days[0][3][2] = &Omnistat::translate_temp($wnh);

# Tuesday to Friday for Omnistat2
my $weekday_or_monday = 'Weekday';
if ($IsOmnistat2) {

    # Used later down to display Monday or Weekday for the first day.
    $weekday_or_monday = 'Monday';
    ( $wmt, $wmc, $wmh, $wdt, $wdc, $wdh, $wet, $wec, $weh, $wnt, $wnc, $wnh )
      = split ' ', $stat->read_cached_reg( "0x4B", 12 );
    $days[1][0][0] = &Omnistat::translate_time($wmt);
    $days[1][0][1] = &Omnistat::translate_temp($wmc);
    $days[1][0][2] = &Omnistat::translate_temp($wmh);
    $days[1][1][0] = &Omnistat::translate_time($wdt);
    $days[1][1][1] = &Omnistat::translate_temp($wdc);
    $days[1][1][2] = &Omnistat::translate_temp($wdh);
    $days[1][2][0] = &Omnistat::translate_time($wet);
    $days[1][2][1] = &Omnistat::translate_temp($wec);
    $days[1][2][2] = &Omnistat::translate_temp($weh);
    $days[1][3][0] = &Omnistat::translate_time($wnt);
    $days[1][3][1] = &Omnistat::translate_temp($wnc);
    $days[1][3][2] = &Omnistat::translate_temp($wnh);
    split ' ', $stat->read_cached_reg( "0x57", 12 );
    $days[2][0][0] = &Omnistat::translate_time($wmt);
    $days[2][0][1] = &Omnistat::translate_temp($wmc);
    $days[2][0][2] = &Omnistat::translate_temp($wmh);
    $days[2][1][0] = &Omnistat::translate_time($wdt);
    $days[2][1][1] = &Omnistat::translate_temp($wdc);
    $days[2][1][2] = &Omnistat::translate_temp($wdh);
    $days[2][2][0] = &Omnistat::translate_time($wet);
    $days[2][2][1] = &Omnistat::translate_temp($wec);
    $days[2][2][2] = &Omnistat::translate_temp($weh);
    $days[2][3][0] = &Omnistat::translate_time($wnt);
    $days[2][3][1] = &Omnistat::translate_temp($wnc);
    $days[2][3][2] = &Omnistat::translate_temp($wnh);
    split ' ', $stat->read_cached_reg( "0x63", 12 );
    $days[3][0][0] = &Omnistat::translate_time($wmt);
    $days[3][0][1] = &Omnistat::translate_temp($wmc);
    $days[3][0][2] = &Omnistat::translate_temp($wmh);
    $days[3][1][0] = &Omnistat::translate_time($wdt);
    $days[3][1][1] = &Omnistat::translate_temp($wdc);
    $days[3][1][2] = &Omnistat::translate_temp($wdh);
    $days[3][2][0] = &Omnistat::translate_time($wet);
    $days[3][2][1] = &Omnistat::translate_temp($wec);
    $days[3][2][2] = &Omnistat::translate_temp($weh);
    $days[3][3][0] = &Omnistat::translate_time($wnt);
    $days[3][3][1] = &Omnistat::translate_temp($wnc);
    $days[3][3][2] = &Omnistat::translate_temp($wnh);
    split ' ', $stat->read_cached_reg( "0x6F", 12 );
    $days[4][0][0] = &Omnistat::translate_time($wmt);
    $days[4][0][1] = &Omnistat::translate_temp($wmc);
    $days[4][0][2] = &Omnistat::translate_temp($wmh);
    $days[4][1][0] = &Omnistat::translate_time($wdt);
    $days[4][1][1] = &Omnistat::translate_temp($wdc);
    $days[4][1][2] = &Omnistat::translate_temp($wdh);
    $days[4][2][0] = &Omnistat::translate_time($wet);
    $days[4][2][1] = &Omnistat::translate_temp($wec);
    $days[4][2][2] = &Omnistat::translate_temp($weh);
    $days[4][3][0] = &Omnistat::translate_time($wnt);
    $days[4][3][1] = &Omnistat::translate_temp($wnc);
    $days[4][3][2] = &Omnistat::translate_temp($wnh);
}

# Saturday/Sunday (all stats)
( $wmt, $wmc, $wmh, $wdt, $wdc, $wdh, $wet, $wec, $weh, $wnt, $wnc, $wnh ) =
  split ' ', $stat->read_cached_reg( "0x21", 12 );
$days[5][0][0] = &Omnistat::translate_time($wmt);
$days[5][0][1] = &Omnistat::translate_temp($wmc);
$days[5][0][2] = &Omnistat::translate_temp($wmh);
$days[5][1][0] = &Omnistat::translate_time($wdt);
$days[5][1][1] = &Omnistat::translate_temp($wdc);
$days[5][1][2] = &Omnistat::translate_temp($wdh);
$days[5][2][0] = &Omnistat::translate_time($wet);
$days[5][2][1] = &Omnistat::translate_temp($wec);
$days[5][2][2] = &Omnistat::translate_temp($weh);
$days[5][3][0] = &Omnistat::translate_time($wnt);
$days[5][3][1] = &Omnistat::translate_temp($wnc);
$days[5][3][2] = &Omnistat::translate_temp($wnh);
( $wmt, $wmc, $wmh, $wdt, $wdc, $wdh, $wet, $wec, $weh, $wnt, $wnc, $wnh ) =
  split ' ', $stat->read_cached_reg( "0x2d", 12 );
$days[6][0][0] = &Omnistat::translate_time($wmt);
$days[6][0][1] = &Omnistat::translate_temp($wmc);
$days[6][0][2] = &Omnistat::translate_temp($wmh);
$days[6][1][0] = &Omnistat::translate_time($wdt);
$days[6][1][1] = &Omnistat::translate_temp($wdc);
$days[6][1][2] = &Omnistat::translate_temp($wdh);
$days[6][2][0] = &Omnistat::translate_time($wet);
$days[6][2][1] = &Omnistat::translate_temp($wec);
$days[6][2][2] = &Omnistat::translate_temp($weh);
$days[6][3][0] = &Omnistat::translate_time($wnt);
$days[6][3][1] = &Omnistat::translate_temp($wnc);
$days[6][3][2] = &Omnistat::translate_temp($wnh);

#Vacation Mode Data (test)
#my ( $vsc, $vsh ) =
#  split ' ', $stat->read_cached_reg( "0x81", 2 );
#my ( $ved, $veh ) =
#  split ' ', $stat->read_cached_reg( "0x95", 2 );
#$vaca[0][0] = &Omnistat::translate_temp($vsc);
#$vaca[0][1] = &Omnistat::translate_temp($vsh);
#$vaca[1][0] = &Omnistat::translate_time($ved);
#$vaca[1][1] = &Omnistat::translate_time($veh);

my $pretty_name =
  &pretty_object_name($location) . " (" . $stat->get_stat_type() . ")";

$html = '<html><body>' . &html_header('Browse Items') . "
<!DOCTYPE HTML PUBLIC '-//W3C//DTD HTML 4.01 Transitional//EN'>
<html>
<head>
<!--#include var='$config_parms{html_style}' --><base target='output'>
</head>
<body>
<h3 style='text-align: center;'><small>Schedule for $pretty_name<br>
</small></h3>
<form action='$NAME' method='post'><small>
Thermostat ";

#Create the list of thermostats
if ( $#locations > 0 ) {

    #Omnistat::omnistat_debug("$NAME: Got multiple locations (".($#locations+1).") for drop down menu");

    $html = $html . "<select name ='location' onChange='this.form.submit();'>";

    foreach my $statname (@locations) {
        if ( $location eq $statname ) {

            #Omnistat::omnistat_debug("$NAME: Selecting $statname in drop down menu since it is location $location. Objects are ".&::get_object_by_name($statname)." and ".&::get_object_by_name($statname));
            $html =
                $html
              . "<option SELECTED  value ='$statname'>"
              . &pretty_object_name($statname)
              . "</option>";
        }
        else {
            $html =
                $html
              . "<option value ='$statname'>"
              . &pretty_object_name($statname)
              . "</option>";
        }
    }
    $html = $html . "</select>";
}
else {
    Omnistat::omnistat_debug(
        "$NAME: Got single location $location, skipping drop down menu");
    $html = $html . $pretty_name;
    $html = $html . "<input name='location' value='$location' type='hidden'>";
}

$html .= "

&nbsp; <input value='Refresh' type='submit'> &nbsp; <input
 value='Send to stat' type='submit'>&nbsp;&nbsp; <input type='reset'> </small>
  <table style='text-align: left; width: 560px; height: 355px;'
 border='1' cellpadding='0' cellspacing='0'>
    <tbody>
      <tr>
        <td colspan='1' rowspan='2'
 style='vertical-align: top; font-weight: bold; text-align: center;'>Day<br>
        </td>
        <td colspan='1' rowspan='2' style='vertical-align: top;'><br>
        </td>
        <td colspan='2' rowspan='1'
 style='vertical-align: top; font-weight: bold; text-align: center;'>Time (0 to clear)<br>
        </td>
        <td colspan='2' rowspan='1'
 style='vertical-align: top; font-weight: bold; text-align: center;'>Cool
        </td>
        <td colspan='2' rowspan='1'
 style='vertical-align: top; text-align: center;'><span
 style='font-weight: bold;'>Heat</span><br>
        </td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Current<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>Set&nbsp;&nbsp;&nbsp;
        <br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>Current<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>Set&nbsp;&nbsp;&nbsp;
        <br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>Current<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>Set&nbsp;&nbsp;&nbsp;
        <br>
        </small></td>
      </tr>
      <tr>
        <td colspan='1' rowspan='4'
 style='vertical-align: top; text-align: center;'><small>&nbsp;<br>
        <br>
$weekday_or_monday<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>Morning<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[0][0][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[0][0][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[0][0][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Day<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[0][1][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[0][1][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[0][1][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Evening<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[0][2][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[0][2][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[0][2][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Night<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[0][3][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[0][3][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[0][3][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td colspan='1' rowspan='4'
 style='vertical-align: top; text-align: center;'><small>&nbsp;<br>
        <br> ";

if ($IsOmnistat2) {
    $html .= "
Tuesday<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>Morning<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[1][0][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[1][0][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[1][0][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Day<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[1][1][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[1][1][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[1][1][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Evening<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[1][2][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[1][2][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[1][2][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Night<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[1][3][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[1][3][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[1][3][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td colspan='1' rowspan='4'
 style='vertical-align: top; text-align: center;'><small>&nbsp;<br>
        <br>
Wednesday<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>Morning<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[2][0][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[2][0][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[2][0][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Day<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[2][1][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[2][1][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[2][1][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Evening<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[2][2][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[2][2][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[2][2][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Night<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[2][3][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[2][3][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[2][3][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
       <tr>
        <td colspan='1' rowspan='4'
 style='vertical-align: top; text-align: center;'><small>&nbsp;<br>
        <br>
Thursday<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>Morning<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[3][0][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[3][0][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[3][0][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Day<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[3][1][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[3][1][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[3][1][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Evening<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[3][2][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[3][2][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[3][2][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Night<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[3][3][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[3][3][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[3][3][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
       <tr>
        <td colspan='1' rowspan='4'
 style='vertical-align: top; text-align: center;'><small>&nbsp;<br>
        <br>
Friday<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>Morning<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[4][0][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[4][0][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[4][0][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Day<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[4][1][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[4][1][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[4][1][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Evening<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[4][2][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[4][2][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[4][2][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Night<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[4][3][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[4][3][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[4][3][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
       <tr>
        <td colspan='1' rowspan='4'
 style='vertical-align: top; text-align: center;'><small>&nbsp;<br>
        <br>";
}

$html .= "
Saturday<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>Morning<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[5][0][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[5][0][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[5][0][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Day<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[5][1][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[5][1][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[5][1][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Evening<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[5][2][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[5][2][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[5][2][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Night<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[5][3][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[5][3][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[5][3][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
       <tr>
        <td colspan='1' rowspan='4'
 style='vertical-align: top; text-align: center;'><small>&nbsp;<br>
        <br>
Sunday<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>Morning<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[6][0][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[6][0][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[6][0][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Day<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[6][1][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[6][1][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[6][1][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Evening<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[6][2][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[6][2][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[6][2][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
      <tr>
        <td style='vertical-align: top; text-align: center;'><small>Night<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[6][3][0]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_time'
 maxlength='8' size='8' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[6][3][1]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
        <td style='vertical-align: top; text-align: center;'><small>$days[6][3][2]<br>
        </small></td>
        <td style='vertical-align: top; text-align: center;'><small><input name='heat_temp'
 maxlength='2' size='2' type='text'></small></td>
      </tr>
    </tbody>
  </table>
</form>
$debug
<br>
<a href='omnistat_setup_web.pl'>Set Thermostat(s)</a><br>
<br>
</body>
</html>
";

return &html_page( '', $html );
