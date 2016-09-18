# Category=MisterHouse
#
#@ Demo how to interface mh user scripts to MBM (Mother Board Monitor).
#@ Voice command is added to category "MisterHouse".
#@ Requires mh.ini parm MBM_module=MBM_mh
#
# MBM monitors Temperature, Voltage, Fans, etc. via sensors included in many motherboards
# MBM runs on Windows only
# MBM available at http://mbm.livewiredev.com
#
# mh.ini parm "MBM_module=MBM_mh" required.
# See /mh/code/common/MBM.pl for example user script.
#
# MBM must be installed and configured.
# Win32::API must be installed via "ppm install Win32-API"
# Do not confuse Win32::API with Win32API
#
#    By: Danal Estes
# Email: danal@earthling.net
#  January 25, 2003 - Original Code
#

# mh.ini parm "MBM_module=MBM_mh" required.
$config_parms{MBM_module}
  ;    # Use in void context, just so web interface will show it.

# Most motherboards have 1 or 2 temp, 6 voltage, 1 or 2 fans... let's demo more than enough

$MBM_t1 = new MBM_mh( 'temperature', 1 );
$MBM_t2 = new MBM_mh( 'temperature', 2 );
$MBM_t3 = new MBM_mh( 'temperature', 3 );
$MBM_t4 = new MBM_mh( 'temperature', 4 );
$MBM_t5 = new MBM_mh( 'temperature', 5 );
$MBM_t6 = new MBM_mh( 'temperature', 6 );

$MBM_v1 = new MBM_mh( 'voltage', 1 );
$MBM_v2 = new MBM_mh( 'voltage', 2 );
$MBM_v3 = new MBM_mh( 'voltage', 3 );
$MBM_v4 = new MBM_mh( 'voltage', 4 );
$MBM_v5 = new MBM_mh( 'voltage', 5 );
$MBM_v6 = new MBM_mh( 'voltage', 6 );
$MBM_v7 = new MBM_mh( 'voltage', 7 );
$MBM_v8 = new MBM_mh( 'voltage', 8 );

$MBM_f1 = new MBM_mh( 'fan', 1 );
$MBM_f2 = new MBM_mh( 'fan', 2 );
$MBM_f3 = new MBM_mh( 'fan', 3 );
$MBM_f4 = new MBM_mh( 'fan', 4 );

$v_MBM_sensors = new Voice_Cmd("Show MBM Sensors");
if ( my $state = said $v_MBM_sensors) {
    my $line = '<pre>';
    $line .= sprintf( "MBM Timestamp for %d total readings is %s<br>",
        $MBM_t1->count, $MBM_t1->time );
    $line .= sprintf( "Temp 1 name %-12.12s is %3d max %3d min %3d<br>",
        $MBM_t1->name, $MBM_t1->state, $MBM_t1->high, $MBM_t1->low );
    $line .= sprintf( "Temp 2 name %-12.12s is %3d max %3d min %3d<br>",
        $MBM_t2->name, $MBM_t2->state, $MBM_t2->high, $MBM_t2->low );
    $line .= sprintf( "Temp 3 name %-12.12s is %3d max %3d min %3d<br>",
        $MBM_t3->name, $MBM_t3->state, $MBM_t3->high, $MBM_t3->low );
    $line .= sprintf( "Temp 4 name %-12.12s is %3d max %3d min %3d<br>",
        $MBM_t4->name, $MBM_t4->state, $MBM_t4->high, $MBM_t4->low );
    $line .= sprintf( "Temp 5 name %-12.12s is %3d max %3d min %3d<br>",
        $MBM_t5->name, $MBM_t5->state, $MBM_t5->high, $MBM_t5->low );
    $line .= sprintf( "Temp 6 name %-12.12s is %3d max %3d min %3d<br>",
        $MBM_t6->name, $MBM_t6->state, $MBM_t6->high, $MBM_t6->low );
    $line .= sprintf( "Volt 1 name %-12.12s is %7.3f max %7.3f min %7.3f<br>",
        $MBM_v1->name, $MBM_v1->state, $MBM_v1->high, $MBM_v1->low );
    $line .= sprintf( "Volt 2 name %-12.12s is %7.3f max %7.3f min %7.3f<br>",
        $MBM_v2->name, $MBM_v2->state, $MBM_v2->high, $MBM_v2->low );
    $line .= sprintf( "Volt 3 name %-12.12s is %7.3f max %7.3f min %7.3f<br>",
        $MBM_v3->name, $MBM_v3->state, $MBM_v3->high, $MBM_v3->low );
    $line .= sprintf( "Volt 4 name %-12.12s is %7.3f max %7.3f min %7.3f<br>",
        $MBM_v4->name, $MBM_v4->state, $MBM_v4->high, $MBM_v4->low );
    $line .= sprintf( "Volt 5 name %-12.12s is %7.3f max %7.3f min %7.3f<br>",
        $MBM_v5->name, $MBM_v5->state, $MBM_v5->high, $MBM_v5->low );
    $line .= sprintf( "Volt 6 name %-12.12s is %7.3f max %7.3f min %7.3f<br>",
        $MBM_v6->name, $MBM_v6->state, $MBM_v6->high, $MBM_v6->low );
    $line .= sprintf( "Volt 7 name %-12.12s is %7.3f max %7.3f min %7.3f<br>",
        $MBM_v7->name, $MBM_v7->state, $MBM_v7->high, $MBM_v7->low );
    $line .= sprintf( "Volt 8 name %-12.12s is %7.3f max %7.3f min %7.3f<br>",
        $MBM_v8->name, $MBM_v8->state, $MBM_v8->high, $MBM_v8->low );
    $line .= sprintf( "Fan 1  name %-12.12s is %4d max %4d min %4d<br>",
        $MBM_f1->name, $MBM_f1->state, $MBM_f1->high, $MBM_f1->low );
    $line .= sprintf( "Fan 2  name %-12.12s is %4d max %4d min %4d<br>",
        $MBM_f2->name, $MBM_f2->state, $MBM_f2->high, $MBM_f2->low );
    $line .= sprintf( "Fan 3  name %-12.12s is %4d max %4d min %4d<br>",
        $MBM_f3->name, $MBM_f3->state, $MBM_f3->high, $MBM_f3->low );
    $line .= sprintf( "Fan 4  name %-12.12s is %4d max %4d min %4d<br>",
        $MBM_f4->name, $MBM_f4->state, $MBM_f4->high, $MBM_f4->low );
    respond "$line";
}
##
# The following code was used during development of the interface .pm modules
# to ensure "state" vs. "state_now" works correctly.  No longer needed, but
# may be of some interest as an example.
##

=begin 

use vars '$MBM_oldcount';
 my $state     = state $MBM_f1;
 my $state_now = state_now $MBM_f1;
 my $count     = count $MBM_f1;
if (!($MBM_oldcount == $count)) {
  print_log "Count change on MBM_f1, count $count old $MBM_oldcount state $state pass $Loop_Count";
  $MBM_oldcount=$count;
}
if ($state_now) {
  print_log "State now    on MBM_f1, count $count old $MBM_oldcount state $state pass $Loop_Count now $state_now";
}

=cut 

