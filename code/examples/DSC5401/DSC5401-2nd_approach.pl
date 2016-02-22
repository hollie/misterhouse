#Category = DSC
#Authority = admin
# $Revision$
# $Date$

# call to dsc software
$DSC = new DSC5401;
my $PWD = "####";

# insert in SQL database
sub DSC2SQL {
    my $Msg = shift;
    my %TempData;
    my $TimeNow = `date "+%Y-%m-%d %H:%M:%S"`;
    chomp $TimeNow;

    $TempData{'timestamp'} = $TimeNow;
    $TempData{'message'}   = "$Msg";
    $SQL->insert( "AlarmEvent", \%TempData );
    return;
}

# display alarm system message if there is a status change
if ( my $AlarmState = $DSC->state_now ) {
    print_log "DSC->state_now is [$AlarmState]";

    DSC2SQL("system $AlarmState by $DSC->{user_name} ($DSC->{user_id})")
      if $AlarmState =~ /^armed/i;
    Send_Email( "misterhouse",
        "Alarm armed by user $DSC->{user_name} or MH reboot",
        $::config_parms{Pager} )
      if $AlarmState =~ /^armed/i;

    DSC2SQL("system $AlarmState by $DSC->{user_name} ($DSC->{user_id})")
      if $AlarmState =~ /^disarmed/i;
    Send_Email( "misterhouse", "Alarm disarmed by user $DSC->{user_name}",
        $::config_parms{Pager} )
      if $AlarmState =~ /^disarmed/i;

    DSC2SQL("system is now in $AlarmState") if $AlarmState =~ /^alarm/i;
    Send_Email( "misterhouse", "ALARM ALARM activated", $::config_parms{Pager} )
      if $AlarmState =~ /^alarm/i;
}

# open light when disarm system
# tell greating message
$All_Interior_Lights_B = new X10_Item('B');
if ( $DSC->state_now =~ /^disarmed/i ) {
    set $All_Interior_Lights_B ON if $Dark;

    # speak welcome message
    my $VMcount = vocp_countmsgs(100);
    my $VMnew   = vocp_countnewmsgs(100);
    my $t       = $DSC->{IntTstatTemp}{1};
    $t =~ s/^0+//;    # remove leading zero
    my $TTS = "Bonjour $DSC->{user_name}. ";
    $TTS .= "La tempez rature intairieure est de $t degrer. ";
    $TTS .= "Vous avez $VMcount messages dans la boite vocale. ";
    $TTS .= "Et vous avez $VMnew nouveaux messages. ";
    SpeakFrench("$TTS");

    $::config_parms{DSC_5401_time_log} = 0;
    $::config_parms{DSC_5401_ring_log} = 0;
    $::config_parms{DSC_5401_temp_log} = 0;
    $::config_parms{DSC_5401_part_log} = 0;
    $::config_parms{DSC_5401_zone_log} = 0;
}

# close light when leaving
if ( $DSC->state_now =~ /^armed/i ) {
    SpeakFrench("L'alarme est activer");
    set $All_Interior_Lights_B OFF;
    $::config_parms{DSC_5401_time_log} = 0;
    $::config_parms{DSC_5401_ring_log} = 1;
    $::config_parms{DSC_5401_temp_log} = 0;
    $::config_parms{DSC_5401_part_log} = 1;
    $::config_parms{DSC_5401_zone_log} = 1;
}

# keep the latest temperature recorded by the DSC system, more reliable than iButton
#if ( $DSC->{ExtTstatTemp_now} ) {
#   $Save{DSC_ExtTstatTemp} = $DSC->{ExtTstatTemp_now};
#}

#if ( $DSC->{IntTstatTemp_now} ) {
#   $Save{DSC_IntTstatTemp} = $DSC->{IntTstatTemp_now};
#}

# if we have a movement outside and the system is armed, we send the video
# motion could run a shell script when it complete his video
# the on_movie_end parameter define this script
# I put a touch on a file when we have a new file
if ( new_second 5 ) {
    if ( !( time_now '23:59' ) && !( time_now '$Time_Sunset' ) ) {
        if ( $DSC->{partition_status}{1} =~ /armed/ ) {
            if ( -e $::config_parms{MotionLastMovie} ) {
                my $MovieFile = "Unknown";

                # send the movie
                if ( open F, "$::config_parms{MotionLastMovie}" ) {
                    $MovieFile = <F>;
                    close F;
                    system(
                        "/usr/bin/mime-construct                    \\
                  --to \"email\@gaetanlord.ca\"               \\
                  --subject  \"Motion detected\"              \\
                  --string   \"Filename $MovieFile\"          \\
                  --type video/mpeg --file-attach $MovieFile"
                    );
                }

                # send a page to my cell phone
                ($MovieFile) = $MovieFile =~
                  /.*\/(.*)$/;    # get only the file name without path
                Send_Email(
                    "Motion detected",
                    "Motion detected in file $MovieFile",
                    $::config_parms{Pager}
                );
                print_log "Motion detected while alarm is on ($MovieFile)";
                unlink $::config_parms{MotionLastMovie};
            }
        }
    }
}

#mime-construct \
#  --to       "email@gaetanlord.ca" \
#  --subject  "Mpeg " \
#  --string   "Your computer is on fire" \
#  --type video/mpeg --file-attach $1

#if ($DSC->{zone_now}) {
#   print_log "A: zone_now = $DSC->{zone_now}";
#   print_log "A: zone_now_msg = $DSC->{zone_now_msg}";
#}

#if ( $DSC->{zone_now_alarm} ) {
#   print_log "B: zone_now = $DSC->{zone_now}";
#   print_log "B: zone_now_msg = $DSC->{zone_now_msg}";
#   print_log "B: zone_now_cmd = $DSC->{zone_now_cmd}";
#   print_log "B: zone_now_msg = $DSC->{zone_now_msg}";
#   print_log "B: zone_now_state = $DSC->{zone_now_state}";
#   print_log "B: zone_now_alarm = $DSC->{zone_now_alarm}";
#   print_log "B: zone_now_cmd = $DSC->{zone_now_cmd}";
#}

# display text message about any zone event
#if ( my $ZoneEvent = $DSC->zone_now ) {
#   print_log  $DSC->{zone_now_msg};
#}

# zone_now_open return the last open zone ID
# then if zone 12 open, a message is speak on the speaker
#if ( $DSC->{zone_now_open} eq "012" ) {
#   SpeakFrench("quelqu'un a ouvert la porte avant");
#}

# some call return only the zone ID and not the name, then
# a call to zone_name will return the name
# those call are
# zone_now_alarm
# zone_now_alarm_restore
# zone_now_fault
# zone_now_fault_restore
# zone_now_open
# zone_now_restored
# zone_now_tamper
# zone_now_tamper_restore
# this will display a message for any zone open
#if ( my $zone_id = $DSC->zone_now_open ) {
#   my $name = $DSC->zone_name($zone_id);
#   print_log "zone $name is open";
#}

# display what is the system status for the partition
# when there is a state change
#if ( my $PartState = $DSC->partition_now ) {
#    print_log  $DSC->{partition_now_msg} . $DSC->{state} ;
#}

# call to user_name return user from last command (arm etc.)
# speak french welcome message if gaetan disarm system
# note user name should be in lower case
#if ( $DSC->state_now =~ /disarmed/ && $DSC->user_name eq "Gaetan") {
#    SpeakFrench("Bonjour Gaetan");
#}

# call to user_id return user from last command (arm etc.)
# speak English welcome message if user ID 0040 disarm system
#if ( $DSC->state_now =~ /disarmed/ && $DSC->user_id eq "0040") {
#    SpeakEnglish("Hi Gaetan");
#}

# display exterior temperature from thermostat 1 ( thermostat number from 1 to 4)
# If there is no temperature available then -999 is returned
# use IntTstat for interior thermostat
#if (new_second 10) {
#   my ($t,$time,$epoch)=$DSC->ExtTstat(1);
#   print_log "Exterior thermostat 1 report $t degree at $time" if $t <> -999 ;
#}

# display every zone name ( 1 to 32)
#if (new_second 10) {
#    for ( 1 .. 32 ) {
#       print "$_ " . $DSC->zone_name($_) ."\n";
#    }
#}

# Simple web interface event
# Misterhouse panel
# Categories
# Alarm
my $state;
$v_alarm_cmd_list = new Voice_Cmd "DSC List all panel command";
$DSC->cmd_list if said $v_alarm_cmd_list;

# 000
$v_alarm_poll = new Voice_Cmd "DSC Poll PC5401 card";
$DSC->cmd("000") if said $v_alarm_poll;

# 001
$v_alarm_status = new Voice_Cmd "DSC Status Report";
$DSC->cmd("001") if said $v_alarm_status;

$v_alarm_partition_arm =
  new Voice_Cmd "DSC Arm partition 1 without access code";
$DSC->cmd( "PartitionArmControl", 1 ) if said $v_alarm_partition_arm;

# 010
$v_alarm_set_time_date =
  new Voice_Cmd "DSC Set Alarm system to the current computer time";
if ( said $v_alarm_set_time_date) {
    my ( $sec, $m, $h, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime(time);
    $year = sprintf( "%02d", $year % 100 );
    $mon += 1;
    $m    = ( $m < 10 )    ? "0" . $m    : $m;
    $h    = ( $h < 10 )    ? "0" . $h    : $h;
    $mday = ( $mday < 10 ) ? "0" . $mday : $mday;
    $mon  = ( $mon < 10 )  ? "0" . $mon  : $mon;
    my $TimeStamp = "$h$m$mon$mday$year";
    &::print_log("Setting time on DSC panel to $TimeStamp");
    &::logit(
        "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
        "Setting time on DSC panel to $TimeStamp"
    );
    $DSC->cmd( "SetDateTime", $TimeStamp );
}

# here you have to give the user access code, replace #### with the access code
# note this is not secure
# 033
$v_alarm_partition_arm_code =
  new Voice_Cmd "DSC Arm partition 1 from webpage with user code";
$DSC->cmd( "PartitionArmControlWithCode", "1", "$PWD" )
  if said $v_alarm_partition_arm_code;

# here you have to give the user access code, replace #### with the access code
# note this is not secure
# 040
$v_alarm_partition_disarm =
  new Voice_Cmd "DSC Disarm partition 1 from webpage with user code";
$DSC->cmd( "PartitionDisarmControl", "1", "$PWD" )
  if said $v_alarm_partition_disarm;

# 050
$v_alarm_verbose_arming = new Voice_Cmd "DSC Verbose arming message [on,off]";
$DSC->cmd( "VerboseArmingControl", $state )
  if $state = said $v_alarm_verbose_arming;

# 056
$v_alarm_time_broadcast = new Voice_Cmd "DSC Periodical Time Message [on,off]";
$DSC->cmd( "TimeBroadcastControl", $state )
  if $state = said $v_alarm_time_broadcast;

# 057
$v_alarm_temp_broadcast_on = new Voice_Cmd "DSC Periodical Temp Message ON";
$DSC->cmd( "TemperatureBroadcastControl", 1 )
  if said $v_alarm_temp_broadcast_on;
$v_alarm_temp_broadcast_off = new Voice_Cmd "DSC Periodical Temp Message OFF";
$DSC->cmd( "TemperatureBroadcastControl", 0 )
  if said $v_alarm_temp_broadcast_off;

