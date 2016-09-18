# Category = Informational

#@ This script checks the USGS National Earthquake Information Center
#@ to get the most recent earthquakes that have occurred and presents
#@ those that were at least the minimum magnitude(s) specified. You'll
#@ need to have your latitude and longitude parameters set properly.<BR>
#@<BR>
#@ If you want to customize your magnitude thresholds, set a variable
#@ like this in your ini file.  You can specify any number of distance,
#@ magnitude pairs:<BR>
#@     Earthquake_Magnitudes = 99999 5.5 3000 3.5 100 0<BR>
#@<BR>
#@ If you prefer kilometers to miles, set Earthquake_Units to metric<BR>
#@     Earthquake_Units=metric<BR>
#@<BR>
#@ You can also set a variable to limit the number of quakes to speak.<BR>
#@     Earthquake_Count = 2<BR>
#@<BR>
#@ Finally, this script creates a listing of earthquakes with the most recent
#@ on top.  The page is linked into the web UI under Weather / Earthquakes.
#@ The default is to list all of the earthquakes, more than 2000.  However,
#@ you can set the following parameter to filter that list using the same
#@ Earthquakes_Magnitudes thresholds used for speech.<BR>
#@     Earthquake_Display = filtered | all<BR>
#@<BR>
#@ You might also set get_url=useragent in your ini file.  This parameter
#@ will permit get_url to timeout if there is a problem retrieving a
#@ file over the internet; otherwise the process might hang indefinitely.
#@ This affects all code that retrieves URLs so make sure you system is
#@ still working after setting this parameter.

# $Revision$
# $Date$

=begin comment

code/common/internet_quakes.pl, bin/get_earthquakes
 1.6 Changed spoken quake count logic so that quakes exceeding the 
     spoken limit will still be marked spoken.  Otherwise each hour
     the remainder will be spoken.  It is possible for the old logic
     to never catch up if count is too low. Added a note to use
     get_url=useragent in the ini file to the code description. 
 1.5 This is a major rewrite triggered because the USGS stopped 
     updating the previous file cnss/quake.  The only sutiable file 
     contains all magnitudes making it much larger (2000+ lines).  
     This resulted in the need to parse the file in a background 
     Process_Item to prevent pauses and to reconsider how earthquakes
     are stored between calls.  Major changes include:
     - Implemented bin/get_earthquakes to retrieve and parse the 
       data file.  This script also gets the map image of the latest
       event.  Much of the existing code was moved to that script.
     - Implemented a DBM file structure (with DB_File) for storing 
       earthquake data in {data_dir}/web/earthquakes.dbm
     - bin/get_earthquakes writes the {data_dir}/web/earthquakes.txt
       file for viewing in the web interface and also retrieves the map 
       image of the latest earthquake as {data_dir}/web/earthquakes.gif.
     The new data source has a slightly different format and contains over 
     2000 earthquake events including the smaller magnitudes retrieved 
     with internet_quakes_cal.pl.  It might be possible now to use 
     this file rather than the CA specific version.
     - Michael Stovenour - 3/1/2009
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

When quakes are read, the date/time and location information are converted
to relative units (i.e. 3 hours ago, yesterday at 5pm, 53 miles away) and
and those that don't meet magnitude thresholds are not spoken.

Note: If you live in the western hemisphere, this script needs your
longitude .ini variable to be negative.

Use the following url to edit the dbm file after copying it to ~/data:
http://localhost:8080/bin/dbmedit.cgi?file=earthquakes.dbm&columns=gmt%2Clat%2Clon%2Cdepth%2Cmagnitude%2Csource%2Clocation%2Cdistance%2Cspeak%2Cspoken&delim=28

=cut

# Add earthquake image to Informational category web page
if ($Reload) {
    $Included_HTML{'Informational'} .=
      qq(<h3>Latest Earthquake<p><img src='/data/web/earthquakes.gif?<!--#include code="int(100000*rand)"-->'><p>\n\n\n);
}

#The variables below are used by the get_earthquakes script called below
#as a background Process_Item.  These empty references cause the .ini parms
#to show up in the code activation screens.
#TODO - modify the code activation screens so that they can be
#explicitly "told" about an .ini parm using some form of perl comment
my $dummy = $config_parms{Earthquake_Magnitudes};
$dummy = $config_parms{Earthquake_Display};
$dummy = $config_parms{latitude};
$dummy = $config_parms{longitude};

#TODO - Why doesn't the .ini file just say kilometers if user wants kilometers?
my $Earthquake_Units = lc( $config_parms{Earthquake_Units} );
$Earthquake_Units = 'miles' unless $Earthquake_Units;
my $Earthquake_Unit_Name = 'miles';    #default to miles
if ( $Earthquake_Units eq 'metric' ) {
    $Earthquake_Unit_Name = 'kilometers';
}
elsif ( $Earthquake_Units eq 'kilometers' ) {
    $Earthquake_Unit_Name = 'kilometers';
}

# Maximum number of quakes to speak
my $Earthquake_Count = 5;
if ( $config_parms{Earthquake_Count} ) {
    $Earthquake_Count = $config_parms{Earthquake_Count};
}

my $speech;
my $f_earthquakes_dbm = "$config_parms{data_dir}/web/earthquakes.dbm";
my $get_cmd = "get_earthquakes" . ( $Debug{earthquakes} ? ' -v' : '' );
$p_earthquakes = new Process_Item($get_cmd);
$v_earthquakes = new Voice_Cmd('[Get,Read,Clear] recent earthquakes');
$v_earthquakes->set_info('Display recent earthquake information');
$v_earthquakes->set_authority('anyone');

$state = said $v_earthquakes;

if ( $state eq 'Get' ) {
    if (&net_connect_check) {
        if ( !$p_earthquakes->done() ) {
            $v_earthquakes->respond(
                "app=earthquakes Can not get earthquakes. Get earthquakes is already running..."
            );
        }
        else {
            start $p_earthquakes;
            $v_earthquakes->respond(
                "app=earthquakes Checking for recent earthquakes...");
        }
    }
}
elsif ( $state eq 'Clear' ) {
    if ( !$p_earthquakes->done() ) {
        $v_earthquakes->respond(
            "app=earthquakes Can not clear earthquakes. Get earthquakes is running..."
        );
    }
    else {
        $v_earthquakes->respond(
            "app=earthquakes Clearing recent earthquakes ...");
        unlink $f_earthquakes_dbm;
        delete $Save{quakes};    #Delete the old save var if it exists
    }
}
elsif ( $state eq 'Read' ) {
    if (
        $speech = earthquake_read(
            'all',             $f_earthquakes_dbm,
            $Earthquake_Count, $Earthquake_Unit_Name
        )
      )
    {
        $v_earthquakes->respond("app=earthquakes $speech");
    }
    else {
        $v_earthquakes->respond(
            'app=earthquakes No recent earthquakes to report.');
    }
}

if ( done_now $p_earthquakes) {
    if (
        $speech = earthquake_read(
            'new',             $f_earthquakes_dbm,
            $Earthquake_Count, $Earthquake_Unit_Name
        )
      )
    {
        $v_earthquakes->respond(
            "app=earthquakes connected=0 important=1 $speech");
    }
}

sub earthquake_read {
    my ( $scope, $f_dbm, $countMax ) = @_;

    my $speech = '';

    my %DBM;
    if ( !tie( %DBM, 'DB_File', $f_dbm, O_RDWR | O_CREAT, 0666 ) ) {
        print_log("internet_earthquake: Can not open dbm file $f_dbm: $!");
        return $speech;
    }

    my @keysSpeak;
    my @dbmEvent;
    if ( $scope eq 'all' ) {
        @keysSpeak =
          grep { @dbmEvent = split( $;, $DBM{$_} ); $dbmEvent[8] } keys(%DBM);
    }
    else {
        @keysSpeak = grep {
            @dbmEvent = split( $;, $DBM{$_} );
            $dbmEvent[8]
              && !$dbmEvent[9]
        } keys(%DBM);
    }

    #  0   1   2    3      4        5      6         7       8     9
    #[gmt,lat,lon,depth,magnitude,source,location,distance,speak,spoken]

    my $key;
    my $count = 0;
    print_log( "internet_earthquakes: Found "
          . scalar(@keysSpeak)
          . " quakes to speak" )
      if $Debug{earthquakes};
    foreach $key (@keysSpeak) {
        @dbmEvent = split( $;, $DBM{$key} );

        #Only speak countMax but mark them all spoken
        if ( $count < $countMax ) {

            #Create the speech for matching items
            my $qloca = lc( $dbmEvent[6] );
            $qloca =~ s/\b(\w)/uc($1)/eg;
            $speech .=
                &calc_earthquake_age( $dbmEvent[0] )
              . " a magnitude "
              . $dbmEvent[4]
              . " earthquake occurred "
              . $dbmEvent[7]
              . " $Earthquake_Unit_Name away "
              . ( ( $qloca =~ /^near/i ) ? '' : 'near ' )
              . "$qloca. ";
        }

        #Update the spoken flag
        $dbmEvent[9] = 1;
        $DBM{$key} = join( $;, @dbmEvent );

        $count++;
    }

    untie %DBM;
    return $speech;
}

sub calc_earthquake_age {

    #Get the time sent in. This is UTC epoc seconds
    my $qtimeUTC = shift;

    # print ("UTC:" . $qtimeUTC . "\n");

    #Split it - these are now local time, not UTC
    my ( $qseco, $qminu, $qhour, $qdate, $qmnth, $qyear ) =
      localtime($qtimeUTC);
    $qmnth += 1;

    #Merge it again - this is now local time, not UTC
    my $qtime = timelocal( $qseco, $qminu, $qhour, $qdate, $qmnth - 1, $qyear );
    return time_date_stamp( 23, $qtime );
}

# lets allow the user to control via triggers
# noloop=start
&trigger_set(
    '$New_Hour and net_connect_check',
    "run_voice_cmd 'Get recent earthquakes'",
    'NoExpire',
    'get earthquakes'
) unless &trigger_get('get earthquakes');

# noloop=stop
