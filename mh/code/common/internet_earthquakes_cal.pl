# Category = Informational

#@ A California-specific version of the internet_earthquakes script. Uses the same
#@ mh.private.ini settings.

=begin comment

internet_quakes_cal.pl
 1.4 Fixed a bug that kept it from reporting big quakes 
     by David Norwood - 8/10/2001
 1.3 Adapted internet_quakes.pl for California specific data,
     switched back to get_url, added relative time/date reporting 
     by David Norwood - 8/4/2001
 1.2 Switched from get_url to get_finger, periodic updates, and 
     %Save variable to remember old earthquakes so only new ones 
     are announced by David Norwood - 2/28/2001
 1.1 Distance thresholds by David Norwood <judapeno@gte.net>
     and other modifications by Tim Doyle - 2/18/2001
 1.0 Original version by Tim Doyle <tim@greenscourt.com>
     using news_yahoo.pl as an example - 2/15/2001

This script checks the USGS California and Nevada earthquake list via the 
web and reads those that were at least the minimum magnitude(s) specified.

When quakes are read, the date/time and location information are converted
to relative units (i.e. 3 hours ago, yesterday at 5pm, 53 miles away) and 
and those that don't meet magnitude thresholds are omitted.

If you want to customize your magnitude thresholds, set a variable
like this in your ini file:

  Earthquake_Magnitudes = 99999 5.5 3000 3.5 100 0

You can also set a variable to limit the number of quakes to read.
To have only the two most recent quakes spoken, regardless of magnitude, set
the following variables in your ini file:

  Earthquake_Magnitudes = 99999 0
  Earthquake_Count = 2

Note: If you live in the western hemisphere, this script needs your
longitude .ini variable to be negative.

=cut

# Default Magnitude Thresholds
my %Magnitude_thresholds = (
    99999,  5.5,     # show anything anywhere over 5.5
    500,    3.5,     # show anything within 500 miles over 3.5
    100,    0,       # show anything within 100 miles any size
);

if ($config_parms{Earthquake_Magnitudes}) {
  %Magnitude_thresholds = split ' ', $config_parms{Earthquake_Magnitudes};
}

# Maximum number of quakes to read
my $Earthquake_Count = 5;

if ($config_parms{Earthquake_Count}) {
  $Earthquake_Count = $config_parms{Earthquake_Count};
}

my $f_earthquakes_cal_html = "$config_parms{data_dir}/web/earthquakes_cal.html";
my $f_earthquakes_cal_text = "$config_parms{data_dir}/web/earthquakes_cal.text";

$p_earthquakes_cal = new Process_Item("get_url http://quake.wr.usgs.gov/recenteqs/Quakes/quakes0.htm $f_earthquakes_cal_html");

$v_earthquakes_cal =  new  Voice_Cmd('[Get,Show,Read,Clear] recent California earthquakes');
$v_earthquakes_cal -> set_info('Display recent California earthquake information');
$v_earthquakes_cal -> set_authority('anyone');

$state = said $v_earthquakes_cal;

if ( $state eq 'Get' or $New_Hour) {
  if (&net_connect_check) {
    print_log "Checking for recent earthquakes ...";

    # Use start instead of run so we can detect when it is done
    start $p_earthquakes_cal;
  }
}


if ( $state eq 'Show' ) {
  my $text = $Save{quakes_cal};
  $text =~ s/\t/\n/g;
  display $text;
}

if ( $state eq 'Clear' ) {
  print_log "Clearing recent earthquakes ...";
  $Save{quakes_cal} = "";
}

if ( $state eq 'Read' ) {
  my $quake;
  my $num = 0;
  foreach (split /\t/, $Save{quakes_cal}) {
    $quake = $_;
    return unless $num < $Earthquake_Count;
    $num += speak_quake($quake);
  }
}

if (done_now $p_earthquakes_cal) {
  my $new_quakes = "";
  my ($quake, $search);
  my $num = 0;
  my $text = file_read "$f_earthquakes_cal_html";
  $text =~ s/\r/\n/g;
  $text =~ s/<[^>]*>//g;
  foreach (split /\n/, $text) {
    if (/^map /i) {
      $search = $quake = $_;
      $search =~ s/\(/\\(/;
      $search =~ s/\)/\\)/;
      if ($Save{quakes_cal} !~ /$search/) {
        $new_quakes = $new_quakes . $quake . "\t";
      }
      else {
        last;
      }
    }
  }
  if ($new_quakes) {
    $Save{quakes_cal} = $new_quakes . $Save{quakes_cal};
    $Save{quakes_cal} =~ s/^(([^\t]*\t){1,1000}).*/$1/;
    foreach (split /\t/, $new_quakes) {
      $quake = $_;
      return unless $num < $Earthquake_Count;
      $num += speak_quake($quake);
    }
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

    return $d*(.5*7915.6*.86838);  # convert to miles and return
}

sub calc_age {
    my $time = shift;
    my ($qyear, $qmnth, $qdate, $qhour, $qminu, $qseco) = $time =~ m!(\S+)/(\S+)/(\S+)\s+(\S+):(\S+):(\S+)!;
    my $qtime = timelocal($qseco,$qminu,$qhour,$qdate,$qmnth-1,$qyear-1900);
    my $midnight = timelocal(0, 0, 0, $Mday, $Month - 1, $Year - 1900);
    my $diff = (time - timelocal($qseco,$qminu,$qhour,$qdate,$qmnth-1,$qyear-1900));

    return int($diff/60) . " minutes ago " if ($diff < 60*120);
    return int($diff/(60*60)) . " hours ago " if ($qtime > $midnight);
    my $hour;
    $qhour =~ s!^0!!;
    if ($qhour == 0) {$hour = "12 AM"}
    elsif ($qhour < 12) {$hour = "$qhour AM"}
    elsif ($qhour == 12) {$hour = "12 PM"}
    else {$hour = $qhour - 12 . " PM"}
    return "Yesterday at $hour " if ($qtime > $midnight - 60*60*24);
    return int($diff/(60*60*24) + .5) . " days ago at $hour ";
}

sub speak_quake {
    #map 1.3  2001/05/12 20:09:30 33.995N 116.818W 18.3    9 km ( 5 mi) NNW of Cabazon, CA
    if (my ($qmagn, $qdate, $qtime, $qlatd, $qnoso, $qlong, $qeawe, $qdept, $qloca) =
        $_ =~ m!map\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)([NS])\s+(\S+)([EW])\s+(\S+).+km.+mi.+[NSEW]+\s+of\s+(.+)!i ) {
      $qlatd *= -1 if ( $qnoso eq "S" );
      $qlong *= -1 if ( $qeawe eq "W" );
      my $distance = sprintf "%d", calc_distance($config_parms{latitude},
        $config_parms{longitude}, $qlatd, $qlong) + .5;
      for (keys %Magnitude_thresholds) {
        if ( $distance <= $_ and $qmagn >= $Magnitude_thresholds{$_}) {
          $qloca =~ s/, CA$/ California/;
          $qloca =~ s/, NV$/ Nevada/;
          speak &calc_age("$qdate $qtime") . "a magnitude $qmagn earthquake occurred $distance miles away near $qloca";
          return 1;
        }
      }
    }
    return 0;
}




