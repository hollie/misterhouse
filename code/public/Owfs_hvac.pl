use strict;
$^W = 0;    # Avoid redefined sub msgs

# From Kirk Bauer on 2/2004, for use with RCS TR40 theromstat.

use vars '$thermostat';

my ( $function, @parms ) = @ARGV;

my (
    $sun_0_time, $sun_0_temp, $sun_0_zone,
    $sun_1_time, $sun_1_temp, $sun_1_zone
);
my (
    $sun_2_time, $sun_2_temp, $sun_2_zone,
    $sun_3_time, $sun_3_temp, $sun_3_zone
);
my (
    $mon_0_time, $mon_0_temp, $mon_0_zone,
    $mon_1_time, $mon_1_temp, $mon_1_zone
);
my (
    $mon_2_time, $mon_2_temp, $mon_2_zone,
    $mon_3_time, $mon_3_temp, $mon_3_zone
);
my (
    $tue_0_time, $tue_0_temp, $tue_0_zone,
    $tue_1_time, $tue_1_temp, $tue_1_zone
);
my (
    $tue_2_time, $tue_2_temp, $tue_2_zone,
    $tue_3_time, $tue_3_temp, $tue_3_zone
);
my (
    $wed_0_time, $wed_0_temp, $wed_0_zone,
    $wed_1_time, $wed_1_temp, $wed_1_zone
);
my (
    $wed_2_time, $wed_2_temp, $wed_2_zone,
    $wed_3_time, $wed_3_temp, $wed_3_zone
);
my (
    $thu_0_time, $thu_0_temp, $thu_0_zone,
    $thu_1_time, $thu_1_temp, $thu_1_zone
);
my (
    $thu_2_time, $thu_2_temp, $thu_2_zone,
    $thu_3_time, $thu_3_temp, $thu_3_zone
);
my (
    $fri_0_time, $fri_0_temp, $fri_0_zone,
    $fri_1_time, $fri_1_temp, $fri_1_zone
);
my (
    $fri_2_time, $fri_2_temp, $fri_2_zone,
    $fri_3_time, $fri_3_temp, $fri_3_zone
);
my (
    $sat_0_time, $sat_0_temp, $sat_0_zone,
    $sat_1_time, $sat_1_temp, $sat_1_zone
);
my (
    $sat_2_time, $sat_2_temp, $sat_2_zone,
    $sat_3_time, $sat_3_temp, $sat_3_zone
);

if ( $function eq 'set' ) {
    return &hvac_set();
}
elsif ( $function eq 'up' ) {
    my $currsp = $thermostat->get_temp_sp();
    if ( $currsp < 80 ) {
        $currsp++;
        $thermostat->set_temp_sp($currsp);
        $thermostat->set_hold(1);
    }
    return &hvac_ask();
}
elsif ( $function eq 'down' ) {
    my $currsp = $thermostat->get_temp_sp();
    if ( $currsp > 60 ) {
        $currsp--;
        $thermostat->set_temp_sp($currsp);
        $thermostat->set_hold(1);
    }
    return &hvac_ask();
}
elsif ( $function eq 'cancel' ) {
    return &hvac_cancel();
}
elsif ( $function eq 'restore_defaults' ) {
    return &hvac_restore();
}
else {
    return &hvac_ask();
}

sub get_schedule {
    my @schedule = $thermostat->get_schedule();
    $sun_0_time = $schedule[0][0][0];
    $sun_0_temp = $schedule[0][0][1];
    $sun_0_zone = $schedule[0][0][2];
    $sun_1_time = $schedule[0][1][0];
    $sun_1_temp = $schedule[0][1][1];
    $sun_1_zone = $schedule[0][1][2];
    $sun_2_time = $schedule[0][2][0];
    $sun_2_temp = $schedule[0][2][1];
    $sun_2_zone = $schedule[0][2][2];
    $sun_3_time = $schedule[0][3][0];
    $sun_3_temp = $schedule[0][3][1];
    $sun_3_zone = $schedule[0][3][2];
    $mon_0_time = $schedule[1][0][0];
    $mon_0_temp = $schedule[1][0][1];
    $mon_0_zone = $schedule[1][0][2];
    $mon_1_time = $schedule[1][1][0];
    $mon_1_temp = $schedule[1][1][1];
    $mon_1_zone = $schedule[1][1][2];
    $mon_2_time = $schedule[1][2][0];
    $mon_2_temp = $schedule[1][2][1];
    $mon_2_zone = $schedule[1][2][2];
    $mon_3_time = $schedule[1][3][0];
    $mon_3_temp = $schedule[1][3][1];
    $mon_3_zone = $schedule[1][3][2];
    $tue_0_time = $schedule[2][0][0];
    $tue_0_temp = $schedule[2][0][1];
    $tue_0_zone = $schedule[2][0][2];
    $tue_1_time = $schedule[2][1][0];
    $tue_1_temp = $schedule[2][1][1];
    $tue_1_zone = $schedule[2][1][2];
    $tue_2_time = $schedule[2][2][0];
    $tue_2_temp = $schedule[2][2][1];
    $tue_2_zone = $schedule[2][2][2];
    $tue_3_time = $schedule[2][3][0];
    $tue_3_temp = $schedule[2][3][1];
    $tue_3_zone = $schedule[2][3][2];
    $wed_0_time = $schedule[3][0][0];
    $wed_0_temp = $schedule[3][0][1];
    $wed_0_zone = $schedule[3][0][2];
    $wed_1_time = $schedule[3][1][0];
    $wed_1_temp = $schedule[3][1][1];
    $wed_1_zone = $schedule[3][1][2];
    $wed_2_time = $schedule[3][2][0];
    $wed_2_temp = $schedule[3][2][1];
    $wed_2_zone = $schedule[3][2][2];
    $wed_3_time = $schedule[3][3][0];
    $wed_3_temp = $schedule[3][3][1];
    $wed_3_zone = $schedule[3][3][2];
    $thu_0_time = $schedule[4][0][0];
    $thu_0_temp = $schedule[4][0][1];
    $thu_0_zone = $schedule[4][0][2];
    $thu_1_time = $schedule[4][1][0];
    $thu_1_temp = $schedule[4][1][1];
    $thu_1_zone = $schedule[4][1][2];
    $thu_2_time = $schedule[4][2][0];
    $thu_2_temp = $schedule[4][2][1];
    $thu_2_zone = $schedule[4][2][2];
    $thu_3_time = $schedule[4][3][0];
    $thu_3_temp = $schedule[4][3][1];
    $thu_3_zone = $schedule[4][3][2];
    $fri_0_time = $schedule[5][0][0];
    $fri_0_temp = $schedule[5][0][1];
    $fri_0_zone = $schedule[5][0][2];
    $fri_1_time = $schedule[5][1][0];
    $fri_1_temp = $schedule[5][1][1];
    $fri_1_zone = $schedule[5][1][2];
    $fri_2_time = $schedule[5][2][0];
    $fri_2_temp = $schedule[5][2][1];
    $fri_2_zone = $schedule[5][2][2];
    $fri_3_time = $schedule[5][3][0];
    $fri_3_temp = $schedule[5][3][1];
    $fri_3_zone = $schedule[5][3][2];
    $sat_0_time = $schedule[6][0][0];
    $sat_0_temp = $schedule[6][0][1];
    $sat_0_zone = $schedule[6][0][2];
    $sat_1_time = $schedule[6][1][0];
    $sat_1_temp = $schedule[6][1][1];
    $sat_1_zone = $schedule[6][1][2];
    $sat_2_time = $schedule[6][2][0];
    $sat_2_temp = $schedule[6][2][1];
    $sat_2_zone = $schedule[6][2][2];
    $sat_3_time = $schedule[6][3][0];
    $sat_3_temp = $schedule[6][3][1];
    $sat_3_zone = $schedule[6][3][2];
    return (@schedule);
}

sub set_schedule {
    my ($self) = @_;
    my @schedule = ();
    $schedule[0][0][0] = $self->{sun_0_time};
    $schedule[0][0][1] = $self->{sun_0_temp};
    $schedule[0][0][2] = $self->{sun_0_zone};
    $schedule[0][1][0] = $self->{sun_1_time};
    $schedule[0][1][1] = $self->{sun_1_temp};
    $schedule[0][1][2] = $self->{sun_1_zone};
    $schedule[0][2][0] = $self->{sun_2_time};
    $schedule[0][2][1] = $self->{sun_2_temp};
    $schedule[0][2][2] = $self->{sun_2_zone};
    $schedule[0][3][0] = $self->{sun_3_time};
    $schedule[0][3][1] = $self->{sun_3_temp};
    $schedule[0][3][2] = $self->{sun_3_zone};
    $schedule[1][0][0] = $self->{mon_0_time};
    $schedule[1][0][1] = $self->{mon_0_temp};
    $schedule[1][0][2] = $self->{mon_0_zone};
    $schedule[1][1][0] = $self->{mon_1_time};
    $schedule[1][1][1] = $self->{mon_1_temp};
    $schedule[1][1][2] = $self->{mon_1_zone};
    $schedule[1][2][0] = $self->{mon_2_time};
    $schedule[1][2][1] = $self->{mon_2_temp};
    $schedule[1][2][2] = $self->{mon_2_zone};
    $schedule[1][3][0] = $self->{mon_3_time};
    $schedule[1][3][1] = $self->{mon_3_temp};
    $schedule[1][3][2] = $self->{mon_3_zone};
    $schedule[2][0][0] = $self->{tue_0_time};
    $schedule[2][0][1] = $self->{tue_0_temp};
    $schedule[2][0][2] = $self->{tue_0_zone};
    $schedule[2][1][0] = $self->{tue_1_time};
    $schedule[2][1][1] = $self->{tue_1_temp};
    $schedule[2][1][2] = $self->{tue_1_zone};
    $schedule[2][2][0] = $self->{tue_2_time};
    $schedule[2][2][1] = $self->{tue_2_temp};
    $schedule[2][2][2] = $self->{tue_2_zone};
    $schedule[2][3][0] = $self->{tue_3_time};
    $schedule[2][3][1] = $self->{tue_3_temp};
    $schedule[2][3][2] = $self->{tue_3_zone};
    $schedule[3][0][0] = $self->{wed_0_time};
    $schedule[3][0][1] = $self->{wed_0_temp};
    $schedule[3][0][2] = $self->{wed_0_zone};
    $schedule[3][1][0] = $self->{wed_1_time};
    $schedule[3][1][1] = $self->{wed_1_temp};
    $schedule[3][1][2] = $self->{wed_1_zone};
    $schedule[3][2][0] = $self->{wed_2_time};
    $schedule[3][2][1] = $self->{wed_2_temp};
    $schedule[3][2][2] = $self->{wed_2_zone};
    $schedule[3][3][0] = $self->{wed_3_time};
    $schedule[3][3][1] = $self->{wed_3_temp};
    $schedule[3][3][2] = $self->{wed_3_zone};
    $schedule[4][0][0] = $self->{thu_0_time};
    $schedule[4][0][1] = $self->{thu_0_temp};
    $schedule[4][0][2] = $self->{thu_0_zone};
    $schedule[4][1][0] = $self->{thu_1_time};
    $schedule[4][1][1] = $self->{thu_1_temp};
    $schedule[4][1][2] = $self->{thu_1_zone};
    $schedule[4][2][0] = $self->{thu_2_time};
    $schedule[4][2][1] = $self->{thu_2_temp};
    $schedule[4][2][2] = $self->{thu_2_zone};
    $schedule[4][3][0] = $self->{thu_3_time};
    $schedule[4][3][1] = $self->{thu_3_temp};
    $schedule[4][3][2] = $self->{thu_3_zone};
    $schedule[5][0][0] = $self->{fri_0_time};
    $schedule[5][0][1] = $self->{fri_0_temp};
    $schedule[5][0][2] = $self->{fri_0_zone};
    $schedule[5][1][0] = $self->{fri_1_time};
    $schedule[5][1][1] = $self->{fri_1_temp};
    $schedule[5][1][2] = $self->{fri_1_zone};
    $schedule[5][2][0] = $self->{fri_2_time};
    $schedule[5][2][1] = $self->{fri_2_temp};
    $schedule[5][2][2] = $self->{fri_2_zone};
    $schedule[5][3][0] = $self->{fri_3_time};
    $schedule[5][3][1] = $self->{fri_3_temp};
    $schedule[5][3][2] = $self->{fri_3_zone};
    $schedule[6][0][0] = $self->{sat_0_time};
    $schedule[6][0][1] = $self->{sat_0_temp};
    $schedule[6][0][2] = $self->{sat_0_zone};
    $schedule[6][1][0] = $self->{sat_1_time};
    $schedule[6][1][1] = $self->{sat_1_temp};
    $schedule[6][1][2] = $self->{sat_1_zone};
    $schedule[6][2][0] = $self->{sat_2_time};
    $schedule[6][2][1] = $self->{sat_2_temp};
    $schedule[6][2][2] = $self->{sat_2_zone};
    $schedule[6][3][0] = $self->{sat_3_time};
    $schedule[6][3][1] = $self->{sat_3_temp};
    $schedule[6][3][2] = $self->{sat_3_zone};
    $thermostat->set_schedule(@schedule);
}

sub hvac_ask {
    my $html     = &html_header('HVAC Status');
    my $currtemp = $Weather{TempIndoor};          #$thermostat->get_temp();
    my ( $currsp, $currZone ) = $thermostat->get_schedule_sp();
    $currsp = $thermostat->get_temp_sp();
    my $system_mode = $thermostat->get_system_mode();
    my $fan_mode    = $thermostat->get_fan_mode();
    my $state       = $thermostat->get_state();
    my $hold        = $thermostat->get_hold();
    my $state_disp  = $state;

    my $hold_timer        = $thermostat->get_hold_timer();
    my $hold_timer_remain = $thermostat->get_hold_timer_remain();

    if ($hold) {
        if ( $hold_timer eq "00:00" ) {
            $hold_timer_remain = "Forever";
        }
        $state_disp .= "  "
          . '<font style="color:red">HOLD '
          . "$hold_timer_remain"
          . '</font>';
    }

    my %temps = $thermostat->get_temperatures();

    &get_schedule();

    $html = qq|
<HTML><HEAD><TITLE>HVAC Status</TITLE></HEAD>
<BODY>
<meta http-equiv="refresh" content="30">
$html
<table border=1>
 <tr><th>Time Now</th><td> $Time_Date</td>
|;

    foreach my $location ( keys %temps ) {
        my $temp = $temps{$location};
        $html .= "<tr><th>$location Temperature</th><td> $temp</td>";
    }
    $html .= "<tr><th>Average Temperature</th><td> $currtemp</td>";

    $html .= qq|
 <tr><th>Outside Temperature</th><td> $Weather{TempOutdoor}</td>
 <tr><th>Outside Humidity</th><td> $Weather{HumidOutdoor}</td>
 <tr><th>Current HVAC Situation</th><td> $state_disp</td>
 <tr><th>Current Setpoint</th><td> $currsp</td>
 <tr><th>Current Zone</th><td> $currZone</td>
 <tr><th>System</th>
 <td>
 <form action='Owfs_hvac.pl?set' method=post>
   <select name=system_mode>
     <option selected>$system_mode</option>
     <option value=off>Off</option>
     <option value=heat>Heat</option>
     <option value=cool>Cool</option>
   </select>
   <input type=submit value="Change">
 </form>
 </td>
 <tr><th>Fan</th>
 <td>
 <form action='Owfs_hvac.pl?set' method=post>
   <select name=fan_mode>
     <option selected>$fan_mode</option>
     <option value=auto>Auto</option>
     <option value=on>On</option>
   </select>
   <input type=submit value="Change">
 </form>
 </td>
 </table>
|;

    if ($hold) {
        $html .=
          '<P>Click <a href="Owfs_hvac.pl?cancel">here to cancel the hold</a>.</P>';
    }
    else {
        $html .= qq|
<h3>Override the setpoints here</h3>
<form action='Owfs_hvac.pl?set' method=post>Temp SP:
  <select name=temp_sp>
    <option selected>$currsp</option>
    <option value=60>60</option>
    <option value=61>61</option>
    <option value=62>62</option>
    <option value=63>63</option>
    <option value=64>64</option>
    <option value=65>65</option>
    <option value=66>66</option>
    <option value=67>67</option>
    <option value=68>68</option>
    <option value=69>69</option>
    <option value=70>70</option>
    <option value=71>71</option>
    <option value=72>72</option>
    <option value=73>73</option>
    <option value=74>74</option>
    <option value=75>75</option>
    <option value=76>76</option>
    <option value=77>77</option>
    <option value=78>78</option>
    <option value=79>79</option>
    <option value=80>80</option>
  </select>
  &nbsp;F&nbsp<input type=submit value='Activate Hold'>
  Hold Timer: <input type=input name=hold_timer size=5 value="$hold_timer">
</form>
|;
    }
    $html .= qq|
<a href="Owfs_hvac.pl?up">UP</a>&nbsp;&nbsp;&nbsp;
<a href="Owfs_hvac.pl?down">DOWN</a>
|;

    $html .= qq|
 <p>
 <form action='Owfs_hvac.pl?set' method=post>
   <table border=1>
     <tr>
       <th>Day</th>
       <th>Morning</th>
       <th>Daytime</th>
       <th>Evening</th>
       <th>Night</th>
     </tr>
     <tr>
       <td>Sun</td>
       <td>
         <input type=input name=sched_000 size=7 value="$sun_0_time">
         <input type=input name=sched_001 size=2 value="$sun_0_temp">
         <input type=input name=sched_002 size=1 value="$sun_0_zone">
       </td>
       <td>
         <input type=input name=sched_010 size=7 value="$sun_1_time">
         <input type=input name=sched_011 size=2 value="$sun_1_temp">
         <input type=input name=sched_012 size=1 value="$sun_1_zone">
       </td>
       <td>
         <input type=input name=sched_020 size=7 value="$sun_2_time">
         <input type=input name=sched_021 size=2 value="$sun_2_temp">
         <input type=input name=sched_022 size=1 value="$sun_2_zone">
       </td>
       <td>
         <input type=input name=sched_030 size=7 value="$sun_3_time">
         <input type=input name=sched_031 size=2 value="$sun_3_temp">
         <input type=input name=sched_032 size=1 value="$sun_3_zone">
       </td
     </tr>
     <tr>
       <td>Mon</td>
       <td>
         <input type=input name=sched_100 size=7 value="$mon_0_time">
         <input type=input name=sched_101 size=2 value="$mon_0_temp">
         <input type=input name=sched_102 size=1 value="$mon_0_zone">
       </td>
       <td>
         <input type=input name=sched_110 size=7 value="$mon_1_time">
         <input type=input name=sched_111 size=2 value="$mon_1_temp">
         <input type=input name=sched_112 size=1 value="$mon_1_zone">
       </td>
       <td>
         <input type=input name=sched_120 size=7 value="$mon_2_time">
         <input type=input name=sched_121 size=2 value="$mon_2_temp">
         <input type=input name=sched_122 size=1 value="$mon_2_zone">
       </td>
       <td>
         <input type=input name=sched_130 size=7 value="$mon_3_time">
         <input type=input name=sched_131 size=2 value="$mon_3_temp">
         <input type=input name=sched_132 size=1 value="$mon_3_zone">
       </td>
     </tr>
     <tr>
       <td>Tue</td>
       <td>
         <input type=input name=sched_200 size=7 value="$tue_0_time">
         <input type=input name=sched_201 size=2 value="$tue_0_temp">
         <input type=input name=sched_202 size=1 value="$tue_0_zone">
       </td>
       <td>
         <input type=input name=sched_210 size=7 value="$tue_1_time">
         <input type=input name=sched_211 size=2 value="$tue_1_temp">
         <input type=input name=sched_212 size=1 value="$tue_1_zone">
       </td>
       <td>
         <input type=input name=sched_220 size=7 value="$tue_2_time">
         <input type=input name=sched_221 size=2 value="$tue_2_temp">
         <input type=input name=sched_222 size=1 value="$tue_2_zone">
       </td>
       <td>
         <input type=input name=sched_230 size=7 value="$tue_3_time">
         <input type=input name=sched_231 size=2 value="$tue_3_temp">
         <input type=input name=sched_232 size=1 value="$tue_3_zone">
       </td>
     </tr>
     <tr>
       <td>Wed</td>
       <td>
         <input type=input name=sched_300 size=7 value="$wed_0_time">
         <input type=input name=sched_301 size=2 value="$wed_0_temp">
         <input type=input name=sched_302 size=1 value="$wed_0_zone">
       </td>
       <td>
         <input type=input name=sched_310 size=7 value="$wed_1_time">
         <input type=input name=sched_311 size=2 value="$wed_1_temp">
         <input type=input name=sched_312 size=1 value="$wed_1_zone">
       </td>
       <td>
         <input type=input name=sched_320 size=7 value="$wed_2_time">
         <input type=input name=sched_321 size=2 value="$wed_2_temp">
         <input type=input name=sched_322 size=1 value="$wed_2_zone">
       </td>
       <td>
         <input type=input name=sched_330 size=7 value="$wed_3_time">
         <input type=input name=sched_331 size=2 value="$wed_3_temp">
         <input type=input name=sched_332 size=1 value="$wed_3_zone">
       </td>
     </tr>
     <tr>
       <td>Thu</td>
       <td>
         <input type=input name=sched_400 size=7 value="$thu_0_time">
         <input type=input name=sched_401 size=2 value="$thu_0_temp">
         <input type=input name=sched_402 size=1 value="$thu_0_zone">
       </td>
       <td>
         <input type=input name=sched_410 size=7 value="$thu_1_time">
         <input type=input name=sched_411 size=2 value="$thu_1_temp">
         <input type=input name=sched_412 size=1 value="$thu_1_zone">
       </td>
       <td>
         <input type=input name=sched_420 size=7 value="$thu_2_time">
         <input type=input name=sched_421 size=2 value="$thu_2_temp">
         <input type=input name=sched_422 size=1 value="$thu_2_zone">
       </td>
       <td>
         <input type=input name=sched_430 size=7 value="$thu_3_time">
         <input type=input name=sched_431 size=2 value="$thu_3_temp">
         <input type=input name=sched_432 size=1 value="$thu_3_zone">
       </td>
     </tr>
     <tr>
       <td>Fri</td>
       <td>
         <input type=input name=sched_500 size=7 value="$fri_0_time">
         <input type=input name=sched_501 size=2 value="$fri_0_temp">
         <input type=input name=sched_502 size=1 value="$fri_0_zone">
       </td>
       <td>
         <input type=input name=sched_510 size=7 value="$fri_1_time">
         <input type=input name=sched_511 size=2 value="$fri_1_temp">
         <input type=input name=sched_512 size=1 value="$fri_1_zone">
       </td>
       <td>
         <input type=input name=sched_520 size=7 value="$fri_2_time">
         <input type=input name=sched_521 size=2 value="$fri_2_temp">
         <input type=input name=sched_522 size=1 value="$fri_2_zone">
       </td>
       <td>
         <input type=input name=sched_530 size=7 value="$fri_3_time">
         <input type=input name=sched_531 size=2 value="$fri_3_temp">
         <input type=input name=sched_532 size=1 value="$fri_3_zone">
       </td>
     </tr>
     <tr>
       <td>Sat</td>
       <td>
         <input type=input name=sched_600 size=7 value="$sat_0_time">
         <input type=input name=sched_601 size=2 value="$sat_0_temp">
         <input type=input name=sched_602 size=1 value="$sat_0_zone">
       </td>
       <td>
         <input type=input name=sched_610 size=7 value="$sat_1_time">
         <input type=input name=sched_611 size=2 value="$sat_1_temp">
         <input type=input name=sched_612 size=1 value="$sat_1_zone">
       </td>
       <td>
         <input type=input name=sched_620 size=7 value="$sat_2_time">
         <input type=input name=sched_621 size=2 value="$sat_2_temp">
         <input type=input name=sched_622 size=1 value="$sat_2_zone">
       </td>
       <td>
         <input type=input name=sched_630 size=7 value="$sat_3_time">
         <input type=input name=sched_631 size=2 value="$sat_3_temp">
         <input type=input name=sched_632 size=1 value="$sat_3_zone">
       </td>
     </tr>
   </table>
   <input type=submit value="Change">
 </form>
 <form action='Owfs_hvac.pl?restore_defaults' method=post>
   <input type=submit name=restore_defaults value="Restore Defaults">
 </form>
|;

    $html .= qq|
 <p /><table border=1 cellpadding=5>
 <tr><th colspan=2>Guest Room Fan</th><th colspan=2>Master Bedroom Fan</th><th colspan=2>Gym Fan</th><th colspan=2>Library Fan</th><th colspan=2>Attic Fan</th><th colspan=2>Porch Fan</th><th colspan=2>Kitchen Fan</th></tr>
<tr>
|;

    $html .=
      (     "<p><td>" . "0"
          . "</td><td><form action='/SET;referer' name=gr_fan><select onchange='gr_fan.submit()' name='\$gr_fan_motor'><option></option><option value='off'>Off</option><option value='low'>Low</option><option value='med'>Medium</option><option value='high'>High</option></form></td>"
      );
    $html .=
      (     "<td>" . "1"
          . "</td><td><form action='/SET;referer' name=mb_fan><select onchange='mb_fan.submit()' name='\$mb_fan_motor'><option></option><option value='off'>Off</option><option value='low'>Low</option><option value='med'>Medium</option><option value='high'>High</option></form></td>"
      );
    $html .=
      (     "<td>" . "2"
          . "</td><td><form action='/SET;referer' name=gym_fan><select onchange='gym_fan.submit()' name='\$gym_fan_motor'><option></option><option value='off'>Off</option><option value='low'>Low</option><option value='med'>Medium</option><option value='high'>High</option></form></td>"
      );
    $html .=
      (     "<td>" . "3"
          . "</td><td><form action='/SET;referer' name=lb_fan><select onchange='lb_fan.submit()' name='\$lb_fan_motor'><option></option><option value='off'>Off</option><option value='low'>Low</option><option value='med'>Medium</option><option value='high'>High</option></form></td>"
      );
    $html .=
      (     "<td>" . "4"
          . "</td><td><form action='/SET;referer' name=at_fan><select onchange='at_fan.submit()' name='\$at_fan_motor'><option></option><option value='off'>Off</option><option value='low'>Low</option><option value='med'>Medium</option><option value='high'>High</option></form></td>"
      );
    $html .=
      (     "<td>" . "5"
          . "</td><td><form action='/SET;referer' name=po_fan><select onchange='po_fan.submit()' name='\$po_fan_motor'><option></option><option value='off'>Off</option><option value='low'>Low</option><option value='med'>Medium</option><option value='high'>High</option></form></td>"
      );
    $html .=
      (     "<td>" . "6"
          . "</td><td><form action='/SET;referer' name=kt_fan><select onchange='kt_fan.submit()' name='\$kt_fan_motor'><option></option><option value='off'>Off</option><option value='low'>Low</option><option value='med'>Medium</option><option value='high'>High</option></form></td>"
      );
    $html .= "</tr></table>";

    my $logFile = "$config_parms{data_dir}/logs/hvac/$Year_Month_Now.log";
    $html .= "<h3>Today's Log</h3><pre>";
    unless ( open( HVACLOG, $logFile ) ) {
        print_log "Could not open hvac log: $!";
    }
    my @lines;
    while ( my $line = <HVACLOG> ) {
        unshift @lines, $line;
    }
    close(HVACLOG);
    foreach (@lines) {
        $html .= $_;
    }
    $html .= "\n</pre>";
    return &html_page( '', $html );
}

sub hvac_cancel {
    return 'Not authorized to make updates' unless $Authorized;
    $thermostat->set_hold(0);
    my ( $currsp, $currZone ) = $thermostat->get_schedule_sp();
    $thermostat->set_temp_sp($currsp);
    return &hvac_ask();
}

sub hvac_restore {
    return 'Not authorized to make updates' unless $Authorized;
    $thermostat->restore_defaults();
    return &hvac_ask();
}

sub hvac_set {
    return 'Not authorized to make updates' unless $Authorized;
    my @schedule = &get_schedule();
    foreach (@parms) {
        if ( $_ =~ s/temp_sp=// ) {
            $thermostat->set_temp_sp($_);
            $thermostat->set_hold(1);
        }
        elsif ( $_ =~ s/system_mode=// ) {
            $thermostat->set_system_mode($_);
        }
        elsif ( $_ =~ s/fan_mode=// ) {
            $thermostat->set_fan_mode($_);
        }
        elsif ( $_ =~ /sched_(\d)(\d)(\d)=(.*)/ ) {
            $schedule[$1][$2][$3] = $4;
        }
        elsif ( $_ =~ s/hold_timer=// ) {
            $thermostat->set_hold_timer($_);
        }
    }
    $thermostat->set_schedule(@schedule);
    return &hvac_ask();
}
