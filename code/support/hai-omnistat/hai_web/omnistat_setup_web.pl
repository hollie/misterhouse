# Authority: admin

# 132 columns max
# 3456789112345678921234567893123456789412345678951234567896123456789712345678981234567899123456789012345678911234567892123456789312

=begin comment
Originally by Joel Davidson, Daniel Arnold et al
The HTML of this page is based on work by Kent Noonan.

2011/01/09 -- Mickey Argo/Karl Suchy/Marc MERLIN
- Added Omnistat2 code

2009/08/03 -- merlin
- cleanups, added debugging, logging and comments
- added code to report stat not found errors as opposed to outputting perl errors
- output the stat type on the screen
- fixed to work with more than one thermostat
- fixed incorrect perl: $location == $statname should be $location eq $statname
- added option to restore setpoints to what's programmed, making use of Daniel's cool function
- added option to set/remove hold
- reworked gui a bit, including updating the stat as soon as a drop down list is updated (good for the
  backend, smaller separate updates are better than big ones which can create more of a hang).

=cut

use vars
  qw($stat_cool_temp $stat_heat_temp $stat_mode $stat_fan $stat_hold $stat_indoor_temp $stat_output);
use strict;
my $html;
my $stat;
my $NAME = "omnistat_setup_web.pl";

Omnistat::omnistat_debug( "$NAME: got args " . join( ", ", @ARGV ) );

#Get the arguments.
# mmmh, this is a hackish way to parse web arguments, but happens to work if they are sent
# exacly in the right order, which they are as long as the form isn't modified -- merlin
my ( $location, $heat_temp, $cool_temp, $mode, $fan, $hold, $submit ) = @ARGV;
if ( $location =~ /([^=]+)=(.+)/ & $2 ne "" ) {
    $location = $2;
    Omnistat::omnistat_debug("$NAME: Got location $location from URL");
}
if ( $submit =~ /([^=]+)=(.+)/ & $2 ne "" ) {
    $submit = $2;
    Omnistat::omnistat_debug("$NAME: Got submit value of $submit from URL");
}

my @locations;    #Holds the names of all the stats
                  #Get first omnistat object names
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

#Get the omnistat by name
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

my $print_cycle    = "";
my $print_vacation = "";

if ( $stat->is_omnistat2 ) {
    $print_cycle    = "<option value='cycle'>Cycle</option>";
    $print_vacation = "<option value='vacation'>Vacation</option>";
}

if ( $submit eq 'reset stat to scheduled values' ) {
    Omnistat::omnistat_debug(
        "$NAME: Got 'reset to scheduled values' for $location");
    $stat->restore_setpoints();
}

# Parse variable to remove everything before the value
# If the variable is not null, send it to the stat
if ( $cool_temp =~ /([^=]+)=(\d+)/ & $2 ne "" ) {
    $stat->cool_setpoint($2);
    Omnistat::omnistat_log("set cool to $2");
    speak "$location Air conditioning set to $2 degrees";
}

if ( $heat_temp =~ /([^=]+)=(\d+)/ & $2 ne "" ) {
    $stat->heat_setpoint($2);
    Omnistat::omnistat_log("set heat to $2");
    speak "$location Heat set to $2 degrees";
}

if ( $mode =~ /([^=]+)=(.+)/ & $2 ne "" ) {
    $stat->mode($2);
    Omnistat::omnistat_log("set mode to $2");
    speak "Thermostat $location mode set to $2";
}

if ( $fan =~ /([^=]+)=(.+)/ & $2 ne "" ) {
    $stat->fan($2);
    Omnistat::omnistat_log("set $location fan to $2");
    speak "Thermostat $location fan set to $2";
}

if ( $hold =~ /([^=]+)=(.+)/ & $2 ne "" ) {
    $stat->hold($2);
    Omnistat::omnistat_log("set $location hold to $2");
    speak "Thermostat $location hold set to $2";
}

# this will pickup changes we may have just made
(
    $stat_cool_temp, $stat_heat_temp, $stat_mode, $stat_fan, $stat_hold,
    $stat_indoor_temp, $stat_output
) = $stat->read_group1("true");

my $pretty_name =
  &pretty_object_name($location) . " (" . $stat->get_stat_type() . ")";

#Write the HTML page
$html = '<html><body>' . &html_header('Browse Items') . "
<h3 style='text-align: center;'>Thermostat status
</h3>
<table style='text-align: left; margin-left: auto; margin-right: auto;'
 border='0' cellpadding='2' cellspacing='2'>
  <tbody>
    <tr>
      <td style='vertical-align: top; text-align: center;'>
      <div style='text-align: center;'><span style='font-weight: bold;'>$pretty_name</span><br>
      </div>
      <table
 style='background-color: rgb(153, 255, 255); text-align: left; width: 250px; height: 140px;'
 border='1' cellpadding='2' cellspacing='2'>
        <tbody>
          <tr>
            <td
 style='vertical-align: top; text-align: left; font-size: 100%;'>
 <center><br>
            <form style='vertical-align: top; font-size: 85%;' action='$NAME' method='post'>";

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
$html = $html
  . "<br><br><a style='font-size: 120%; font-weight: bold;'> Current temp&nbsp;$stat_indoor_temp
              <br>
              <br>
              <a style='font-size: 120%; font-weight: bold;'> Current stat mode:&nbsp;$stat_output
              <br>
              <br>
              </a>Heat&nbsp;&nbsp;$stat_heat_temp&nbsp;<input name='heat_temp' maxlength='2' size='2'
 style='vertical-align: top; font-size: 85%;' type='text'>&nbsp;&nbsp;Cool&nbsp;&nbsp;$stat_cool_temp&nbsp;
              <input name='cool_temp' maxlength='2' size='2' style='vertical-align: top; font-size: 85%;' type='text'> <br>
<p align=center><table border='1' cellpadding='2' cellspacing='2'>
<tr>
<th>Mode</th><td><em>$stat_mode</em></td>
<td>	      <select name='mode' class='dropDown' style='vertical-align: top; font-size: 85%;' onChange='this.form.submit();'>>
              <option value=''>No Change</option>
              <option value='off'>Off</option>
              <option value='cool'>Cool</option>
              <option value='heat'>Heat</option>
              <option value='auto'>Auto</option>
              </select>
</td></tr>

<th>Fan</th><td><em>$stat_fan</em></td>
<td>          <select name='fan' class='dropDown' style='vertical-align: top; font-size: 85%;' onChange='this.form.submit();'>>
              <option value=''>No Change</option>
              <option value='on'>On</option>
              <option value='auto'>Auto</option>
              $print_cycle
              </select>
              <br>
</td></tr>

<th>Hold</th><td><em>$stat_hold</em></td>
<td>          <select name='hold' class='dropDown' style='vertical-align: top; font-size: 85%;' onChange='this.form.submit();'>>
              <option value=''>No Change</option>
              <option value='on'>On</option>
              <option value='off'>Off</option>
              $print_vacation
              </select>
</td></tr></table></p>

              <br>
              <input type='submit' name=submit_but value='Send to stat' style='font-size: 85%; font-weight: bold;'>&nbsp;&nbsp;
	      <p><b>or</b><p>
              <input type='submit' name=submit_but value='reset stat to scheduled values' style='font-size: 85%; font-weight: bold;'>&nbsp;&nbsp;
	      </center>
	      </p>
            </td>
          </tr>
        </tbody>
      </table>
      </td>
      <td style='vertical-align: top;'>
      </td>
    </tr>
  </tbody>
</table>
<a href='omnistat_sched_web.pl'>Program schedule</a></body>
</html>";
return &html_page( '', $html );
