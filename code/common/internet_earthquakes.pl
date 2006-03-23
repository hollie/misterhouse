# Category = Informational

#@ This module checks the USGS National Earthquake Information Center
#@ to get the most recent earthquakes that have occurred and presents
#@ those that were at least the minimum magnitude(s) specified. You'll
#@ need to have your latitude and longitude parameters set properly.
#@
#@ If you want to customize your magnitude thresholds, set a variable
#@ like this in your ini file:
#@
#@ Earthquake_Magnitudes = 99999 5.5 3000 3.5 100 0
#@
#@ If you prefer kilometers to miles, set Earthquake_Units to metric
#@ e.g. Earthquake_Units=metric
#@ 
#@ You can also set a variable to limit the number of quakes to display.
#@ To show only the two most recent quakes, regardless of magnitude, set
#@ the following variables in your ini file:
#@
#@ Earthquake_Magnitudes = 99999 0
#@ Earthquake_Count = 2

# $Revision$
# $Date$

=begin comment

internet_quakes.pl
 1.4 Switched back to get_url after finger stopped working.  Added a
     process to automatically download an image showing where the
     latest quake was - David Norwood - 1/14/2004
 1.3 Merged in relative date/time reporting and some other
     modifications made to internet_quakes_cal.pl since it was
     derived from this file - Tim Doyle - 11/11/2001
 1.2 Switched from get_url to get_finger, periodic updates, and
     %Save variable to remember old earthquakes so only new ones
     are announced by David Norwood - 2/28/2001
 1.1 Distance thresholds by David Norwood <judapeno@gte.net>
     and other modifications by Tim Doyle - 2/18/2001
 1.0 Original version by Tim Doyle <tim@greenscourt.com>
     using news_yahoo.pl as an example - 2/15/2001

This script checks the USGS National Earthquake Information Center
via ftp to get the last twenty one earthquakes that have occurred
in the world and presents those that were at least the minimum
magnitude(s) specified.

When quakes are read, the date/time and location information are converted
to relative units (i.e. 3 hours ago, yesterday at 5pm, 53 miles away) and
and those that don't meet magnitude thresholds are omitted.

If you want to customize your magnitude thresholds, set a variable
like this in your ini file:

  Earthquake_Magnitudes = 99999 5.5 3000 3.5 100 0

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
    $Included_HTML{'Informational'} .= qq(<h3>Latest Earthquake<p><img src='/data/web/earthquakes.gif?<!--#include code="int(100000*rand)"-->'><p>\n\n\n);
}

# Default Magnitude Thresholds
my %Magnitude_thresholds = (
    99999,  5.5,     # show anything anywhere over 5.5
    500,    3.5,     # show anything within 500 miles over 3.5
    100,    0,       # show anything within 100 miles any size
);

if ($config_parms{Earthquake_Magnitudes}) {
  %Magnitude_thresholds = split ' ', $config_parms{Earthquake_Magnitudes};
}

my $Earthquake_Units=$config_parms{Earthquake_Units};
$Earthquake_Units='imperial' unless $Earthquake_Units;

my $Earthquake_Unit_Name='';
if ($Earthquake_Units eq 'metric') {
	$Earthquake_Unit_Name='kilometers';
} else {
	$Earthquake_Unit_Name='miles';
}

# Maximum number of quakes to show
my $Earthquake_Count = 5;

if ($config_parms{Earthquake_Count}) {
  $Earthquake_Count = $config_parms{Earthquake_Count};
}

$f_earthquakes_txt = new File_Item("$config_parms{data_dir}/web/earthquakes.txt");
$f_earthquakes_gif = new File_Item("$config_parms{data_dir}/web/earthquakes.gif");

my $image;
my $speech;

$p_earthquakes_image = new Process_Item;
$p_earthquakes = new Process_Item("get_url ftp://hazards.cr.usgs.gov/cnss/quake " . $f_earthquakes_txt->name);

$v_earthquakes =  new  Voice_Cmd('[Get,Show,Read,Clear] recent earthquakes');
$v_earthquakes -> set_info('Display recent earthquake information');
$v_earthquakes -> set_authority('anyone');

$state = said $v_earthquakes;

if ( $state eq 'Get' ) {
  unlink $f_earthquakes_txt->name;
  if (&net_connect_check) {
    print_log "Checking for recent earthquakes ...";

    # Use start instead of run so we can detect when it is done
    start $p_earthquakes;
  }
}

if ( $state  eq 'Show' ) {
  my $quake;
  my $num = 0;
  $speech = '';
  foreach (split /\t/, $Save{quakes}) {
    $quake = $_;
    last unless $num < $Earthquake_Count;
    $num += parse_quake($quake);
  }
  if ($speech) {
     respond $speech;
  }
  else {
     respond 'No recent earthquakes to report.';
  }
}

if ( $state eq 'Clear' ) {
  print_log "Clearing recent earthquakes ...";
  $Save{quakes} = "";
}

if ( $state eq 'Read' ) {
  my $quake;
  my $num = 0;
  $speech = '';
  foreach (split /\t/, $Save{quakes}) {
    $quake = $_;
    last unless $num < $Earthquake_Count;
    $num += parse_quake($quake);
  }
  if ($speech) {
     respond "target=speak $speech";
  }
  else {
     respond 'target=speak No recent earthquakes to report.';
  }
}

if (done_now $p_earthquakes) {
  my $new_quakes = "";
  my ($quake, $search);
  my $num = 0;

  #The data returned has oldest on top, and we need to look at the newest data first
  #The following reads the data into an array and then pops lines off the bottom
  my @txtFile = $f_earthquakes_txt->read_all;
  while ($_ = pop @txtFile) {
    #Only look at lines with quake data on them
    if (/^(\S+)\s+(\S+)\s+(\S+)([NS])\s+(\S+)([EW])\s+(\S+)\s+(\S+)M\s+(\S)?\s+(.+)/ ) {
      $search = $quake = $_;
      if ($Save{quakes} !~ /$search/) {
        $new_quakes = $new_quakes . $quake . "\t";
      }
    }
  }
  if ($new_quakes) {
    $Save{quakes} = $new_quakes . $Save{quakes};
#   $Save{quakes} =~ s/^(([^\t]*\t){1,1000}).*/$1/;
    $Save{quakes} =~ s/^(([^\t]*\t){1,21}).*/$1/;   # Save last 21 quakes
    $image = '';
    foreach (split /\t/, $new_quakes) {
      $quake = $_;
      last unless $num < $Earthquake_Count;
      $num += parse_quake($quake);
    }
    set $p_earthquakes_image "get_url $image " . $f_earthquakes_gif->name;
    start $p_earthquakes_image if $image;
    speak ($speech) if $speech ne '';
    $speech='';
  }
}

use Math::Trig;

sub calc_distance {
    my ($lat1, $lon1, $lat2, $lon2) = @_;
    my ($c, $d);
    $c = 57.3; # radian conversion factor

    $lat1 /= $c;
    $lat2 /= $c;
    $lon1 /= $c;
    $lon2 /= $c;
    $d = 2*Math::Trig::asin(sqrt((sin(($lat1-$lat2)/2))**2 + 	cos($lat1)*cos($lat2)*(sin(($lon1-$lon2)/2))**2));

	if ($Earthquake_Units eq 'metric') {
		return $d*6378; # convert to kilometers and return
	}
    return $d*(.5*7915.6);  # convert to miles and return
}

sub calc_age {
    #Get the time sent in. This is UTC
    my $time = shift;
    #Split it up
    my ($qyear, $qmnth, $qdate, $qhour, $qminu, $qseco) = $time =~ m!(\S+)/(\S+)/(\S+)\s+(\S+):(\S+):(\S+)!;
    #Merge it
    my $qtime = timegm($qseco,$qminu,$qhour,$qdate,$qmnth-1,$qyear);
    #Split it again - these are now local time, not UTC
    ($qseco,$qminu,$qhour,$qdate,$qmnth,$qyear) = localtime($qtime);
    $qmnth += 1;
    #Merge it again - this is now local time, not UTC
    $qtime = timelocal($qseco,$qminu,$qhour,$qdate,$qmnth-1,$qyear);


    my $midnight = timelocal(0, 0, 0, $Mday, $Month - 1, $Year - 1900);
    my $diff = (time - timelocal($qseco,$qminu,$qhour,$qdate,$qmnth-1,$qyear));

    return int($diff/60) . " minutes ago " if ($diff < 60*120);
    return int($diff/(60*60)) . " hours ago " if ($qtime > $midnight);
    my $hour;
    $qhour =~ s!^0!!;
    if ($qhour == 0) {$hour = "12 AM"}
    elsif ($qhour < 12) {$hour = "$qhour AM"}
    elsif ($qhour == 12) {$hour = "12 PM"}
    else {$hour = $qhour - 12 . " PM"}
    return "Yesterday at $hour " if ($qtime > $midnight - 60*60*24);
    my $days_ago = int($diff/(60*60*24) + .5);
    return  "$days_ago day" . (($days_ago > 1)?'s':'') . " ago at $hour ";
}

# 03/12/30 15:32:35 34.20N 139.13E 33.0 4.4M B NEAR S. COAST OF HONSHU, JAPAN

sub parse_quake {
    if (my ($qdate, $qtime, $qlatd, $qnoso, $qlong, $qeawe, $qdept, $qmagn, $qqual, $qloca) =
        $_ =~ m!^(\S+)\s+(\S+)\s+(\S+)([NS])\s+(\S+)([EW])\s+(\S+)\s+(\S+)M\s+(\S)?\s+(.+)! ) {
      $qlatd *= -1 if ( $qnoso eq "S" );
      $qlong *= -1 if ( $qeawe eq "W" );
      my $distance = sprintf "%d", calc_distance($config_parms{latitude},
        $config_parms{longitude}, $qlatd, $qlong) + .5;
      for (keys %Magnitude_thresholds) {
        if ( $distance <= $_ and $qmagn >= $Magnitude_thresholds{$_}) {
          my $long_reso = abs(5 * round($qlatd/5)) > 45 ? (abs(5 * round($qlatd/5)) > 65 ? 20 : 10) : 5;
          $image = 'http://earthquake.usgs.gov/recenteqsww/Maps/10/' . $long_reso * round(($qlong < 0 ? 360 + $qlong : $qlong)/$long_reso) . '_' . 5 * round($qlatd/5) . '.gif';
	  $qloca = lc($qloca);
	  $qloca =~ s/\b(\w)/uc($1)/eg;
      $speech .= &calc_age("$qdate $qtime") . "a magnitude $qmagn earthquake occurred $distance $Earthquake_Unit_Name away near $qloca. ";
          return 1;
        }
      }
    }
    return 0;
}

# lets allow the user to control via triggers

if ($Reload and $Run_Members{'trigger_code'}) {
    eval qq(
        &trigger_set('\$New_Hour and net_connect_check', "run_voice_cmd 'Get recent earthquakes'", 'NoExpire', 'get earthquakes')
          unless &trigger_get('get earthquakes');
    );
}
