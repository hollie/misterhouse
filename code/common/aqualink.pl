# Category=Pool

#@ This module allows MisterHouse to communicate with a Jandy AquaLink RS
#@ Serial Adapter (#7620), allowing for Home Automation control of a Jandy
#@ AquaLink RS Pool Control system.
#@ 
#@ Set the following parameters in your mh.private.ini file:
#@ aqualink_port=COM9
#@ aqualink_baudrate=9600
#@ aqualink_handshake=none
#@ aqualink_datatype=records

=begin comment

aqualink.pl
 1.2 Moved spa.log to log directory - 10/16/02
     Added back some logging routines that were previously lost
 1.1 Misc enhancements by Tim Doyle <tim@greenscourt.com> - 11/17/2001
     Fixed AUX naming bug
     Queries pool data at startup and saves data for use later (like on Audrey pages)
     Plays alert.wav if the pool temp drops below 40 degrees
     Fixed the 'spa' command
     Logs spa temp data when heating
     General fine-tuning

 1.0 Original version by Tim Doyle <tim@greenscourt.com> - 5/9/2001

This script allows MisterHouse to communicate with a Jandy AquaLink RS
Serial Adapter (#7620), allowing for Home Automation control of a Jandy
AquaLink RS Pool Control system.

=cut

my $command;
my $data;
my $state;
my $units;
my $value;
my $Cleaner;
my $SpaReady;
my $Waterfall;
my $AUX1mode;
my $AUX2mode;
my $AUX3mode;
my $CLEANRmode;
my $POOLHTmode;
my $POOLSPmode;
my $PUMPmode;
my $SPAmode;
my $SPASPmode;
my $SPAHTmode;
my $VBATmode;
my $SpaHeating;

my $AUX1 = ($config_parms{Jandy_AUX1}) ? $config_parms{Jandy_AUX1} : 'pool auxiliary device 1';
my $AUX2 = ($config_parms{Jandy_AUX2}) ? $config_parms{Jandy_AUX2} : 'pool auxiliary device 2';
my $AUX3 = ($config_parms{Jandy_AUX3}) ? $config_parms{Jandy_AUX3} : 'pool auxiliary device 3';

$jandy = new Serial_Item(undef, undef, 'serial1');

if ( $Startup ) {
  set $jandy "#ECHO=0";                          #Don't echo our commands
  set $jandy "#COSMSGS=1";                       #Tell us when things change
#  set $jandy "#OPTIONS?";                        #Get the Power Center Options
}

if ( $data = said $jandy ) {
  $data =~ s/\n//;
  $data =~ s/\r//;
  print_log "AquaLink: $data";

  if ( $data =~ m#^!00\s(\S+)\s=\s(.*)# ) {
    my $command = $1;
    my $value = $2;

    if ( $value eq '1' ) { $value = 'on'; }
    if ( $value eq '0' ) { $value = 'off'; }

    if ( $value =~ m#^(\S+)\s([F|C])# ) {
      $value = $1;
      $units = $2;
    }

    if ( $command eq 'AIRTMP' ) {
      #speak "The air in the pool equipment area is currently $value degrees.";
      $Save{PoolAirTemp} = $value;
    }

    if ( $command eq 'AUX1' ) {
      if ( $AUX1mode eq 'check' ) {
        speak "The $AUX1 is currently $value.";
      } else {
        speak "The $AUX1 has been turned $value.";
      }
    }

    if ( $command eq 'AUX2' ) {
      if ( $AUX2mode eq 'check' ) {
        speak "The $AUX2 is currently $value.";
      } else {
        speak "The $AUX2 has been turned $value.";
      }
    }

    if ( $command eq 'AUX3' ) {
      if ( $AUX3mode eq 'check' ) {
        speak "The $AUX3 is currently $value.";
      } else {
        speak "The $AUX3 has been turned $value.";
      }
      $Save{PoolAUX3} = $value;
    }

    if ( $command eq 'CLEANR' ) {
      if ( $CLEANRmode eq 'check' ) {
        speak "The pool cleaner is currently $value.";
      } else {
        speak "The pool cleaner has been turned $value.";
      }
      $Save{PoolCleaner} = $value;
    }

    if ( $command eq 'MODEL' ) {
      speak "The Jandy RS unit is model $value.";
    }

    if ( $command eq 'OK' ) {
      speak "The AquaLink unit responded OK.";
    }

    if ( $command eq 'OPMODE' ) {
      speak "The pool is currently in $value mode.";
    }

    if ( $command eq 'LEDS' ) {
      #It appears this data isn't updated except periodically, and thus can be stale
      speak "The LED values are $value";
      $value =~ m#^(\S+)\s(\S+)\s(\S+)\s(\S+)\s(\S+)#;

      my $LED3  = vec(chr($1),2,2);
      my $LED4  = vec(chr($1),3,2);
      my $LED5  = vec(chr($2),0,2);
      my $LED6  = vec(chr($2),1,2);
      my $LED7  = vec(chr($2),2,2);
      my $LED15 = vec(chr($4),2,2);
      my $LED16 = vec(chr($4),3,2);

      speak "Pump $LED7 Heater $LED15 $LED16 Spa $LED6 AUX1 $LED5 AUX2 $LED4 AUX3 $LED3";
    }

    if ( $command eq 'OPTIONS' ) {
      #speak "Beta Test";
      #speak vec $value,0,1;
      #speak vec $value,1,1;
      #speak vec $value,2,1;
      #speak vec $value,3,1;
      #speak vec $value,4,1;
      #speak vec $value,5,1;
      #speak vec $value,6,1;
      #speak vec $value,7,1;

      speak "Examining your Power Center Option Settings";
      #Switch 8
      if ( $value > 127 ) {
        speak "You have a heat pump";
        $value = $value - 128;
      } else {
        speak "You have a gas heater";
      }

      #Switch 7
      if ( $value > 63 ) {
        speak "You have an unknown setting";
        $value = $value - 64;
      }

      #Switch 6
      if ( $value > 31 ) {
        speak "You have an unknown setting";
        $value = $value - 32;
      }

      #Switch 5
      if ( $value > 15 ) {
        speak "You have an unknown setting";
        $value = $value - 16;
      }

      #Switch 4
      if ( $value > 7 ) {
        speak "You have the heater cooldown mode disabled";
        $value = $value - 8;
      } else {
        speak "You have the heater cooldown mode enabled";
      }

      #Switch 3
      if ( $value > 3 ) {
        speak "You have spa spillover / waterfall enabled";
        $value = $value - 4;
        $Waterfall = '1';
      } else {
        speak "You have AUX3 enabled";
        $Waterfall = '0';
      }

      #Switch 2
      if ( $value > 1 ) {
        speak "You have a two speed pump";
        $value = $value - 2;
      } else {
        speak "You have a one speed pump";
      }

      #Switch 1
      if ( $value > 0 ) {
        speak "You have a pool cleaner";
        $Cleaner = '1';
      } else {
        speak "You have AUX1 enabled";
        $Cleaner = '0';
      }
    }

    if ( $command eq 'POOLHT' ) {
      if ( $POOLHTmode eq 'check' ) {
        speak "The pool heater is currently $value.";
      } else {
        speak "The pool heater has been turned $value.";
      }
      $Save{PoolHeater} = $value;
    }

    if ( $command eq 'POOLSP' ) {
      if ( $POOLSPmode eq 'check' ) {
        speak "The pool setpoint is currently $value degrees.";
      } else {
        speak "The pool setpoint has been set to $value degrees.";
      }
    }

    if ( $command eq 'POOLTMP' ) {
      speak "The pool is currently $value degrees.";
      if ($value < 40) {
        play(rooms => 'all', file => "alert.wav");
      }
      $Save{PoolTemp} = $value;
      &logpool;
    }

    if ( $command eq 'PUMP' ) {
      if ( $PUMPmode eq 'check' ) {
        speak "The pool pump is currently $value.";
      } else {
        speak "The pool pump has been turned $value.";
# I used this when it was below freezing for extra insurance
#        if (lc($value) eq 'off') {
#          run_voice_cmd 'Turn the pool pump ON';
#          play('file' => 'alert.wav');
#          speak "The pool pump just turned off. Turning it back on.";
#          run_after_delay 2, "run_voice_cmd 'Turn the pool cleaner ON'";
#        }
      }
      $Save{PoolPump} = $value;
    }

    if ( $command eq 'SPA' ) {
      if ( $SPAmode eq 'check' ) {
        speak "The spa is currently $value.";
      } else {
        speak "The spa has been turned $value.";
      }
      $Save{PoolSpaPump} = $value;
    }

    if ( $command eq 'SPAHT' ) {
      if ( $SPAHTmode eq 'check' ) {
        speak "The spa heater is currently $value.";
      } else {
        speak "The spa heater has been turned $value.";

        if (lc $value eq 'on') {
          &logspa("start");
          $SpaHeating = 1;
        }
      }
      $Save{PoolSpaHeater} = $value;
    }

    if ( $command eq 'SPASP' ) {
      if ( $SPASPmode eq 'check' ) {
        speak "The spa setpoint is currently $value degrees.";
      } else {
        speak "The spa setpoint has been set to $value degrees.";
      }
    }

    if ( $command eq 'SPATMP' ) {
      speak "The spa is currently $value degrees.";
      $Save{PoolSpaTemp} = $value;
      &logspa("heat");

      if ($SpaHeating) {
        if ($value > 95) { 
          $SpaHeating = 0; 
          speak "It is now ready.";
        } else {
          my $TimeLeft = int((96-$value)/.7);  # My heater can raise the spa temp 7 degrees in 10 minutes
          speak "It should be ready in $TimeLeft minutes.";
        }
      }
    }

    if ( $command eq 'VBAT' ) {
      if ( $value =~ m#^(\S+)\sLOW# ) {
        $value = $1/100;
        speak "Warning: The pool battery is low at $value volts.";
      } else {
        if ($VBATmode eq 'check') {
          $value = $value/100;
          speak "The pool battery is currently at $value volts.";
          $VBATmode = '';
        }
      }
    }

    if ( $command eq 'VERS' ) {
      speak "The Jandy RS Serial Adapter firmware is version $value.";
    }
  }

  if ( $data =~ m#^\?(\S+)\s(.*)# ) {
    my $ErrCode = $1;
    my $ErrMesg = $2;
    speak "Error: $ErrMesg";
    print_log "Error: $ErrCode $ErrMesg";
  }

  #Check for a reset of the RS Serial Adapter
  if ( $data =~ m#^Jandy Products.*# ) {
    #This bombs out - need to delay these with a timer
    set $jandy "#ECHO=0";                          #Don't echo our commands
    set $jandy "#COSMSGS=1";                       #Tell us when things change
  }
}

#POOL
$v_pool_pump_set = new Voice_Cmd("Turn the pool pump [ON,OFF]");
if ($state = said $v_pool_pump_set) {
  set $jandy "#PUMP=$state";
  $PUMPmode = 'set';
}

$v_pool_pump_chk = new Voice_Cmd("Check the pool pump status");
if ($state = said $v_pool_pump_chk) {
  set $jandy "#PUMP?";
  $PUMPmode = 'check';
}

$v_pool_heat_set = new Voice_Cmd("Turn the pool heater [ON,OFF]");
if ($state = said $v_pool_heat_set) {
  set $jandy "#POOLHT=$state";
  $POOLHTmode = 'set';
}

$v_pool_heat_chk = new Voice_Cmd("Check the pool heater status");
if ($state = said $v_pool_heat_chk) {
  set $jandy "#POOLHT?";
  $POOLHTmode = 'check';
}

$v_pool_temp = new Voice_Cmd("Check the pool temperature");
if ($state = said $v_pool_temp) {
  set $jandy "#POOLTMP?";
}

$v_pool_sp_up = new Voice_Cmd("Increase the pool setpoint");
if ($state = said $v_pool_sp_up) {
  set $jandy "#POOLSP+";
  $POOLSPmode = 'set';
}

$v_pool_sp_dn = new Voice_Cmd("Decrease the pool setpoint");
if ($state = said $v_pool_sp_dn) {
  set $jandy "#POOLSP-";
  $POOLSPmode = 'set';
}

$v_pool_sp = new Voice_Cmd("Check the pool setpoint");
if ($state = said $v_pool_sp) {
  set $jandy "#POOLSP?";
  $POOLSPmode = 'check';
}

#SPA

$v_spa_ready = new Voice_Cmd("spa");
if ($state = said $v_spa_ready) {
  run_after_delay 2, "run_voice_cmd 'Turn the spa ON'";
  run_after_delay 4, "run_voice_cmd 'Turn the spa heater ON'";
  $SpaReady = 'true';
}


$v_spa_pump_set = new Voice_Cmd("Turn the spa [ON,OFF]");
if ($state = said $v_spa_pump_set) {
  set $jandy "#SPA=$state";
  $SPAmode = 'set';
}

$v_spa_pump_chk = new Voice_Cmd("Check the spa status");
if ($state = said $v_spa_pump_chk) {
  set $jandy "#SPA?";
  $SPAmode = 'check';
}

$v_spa_heat_set = new Voice_Cmd("Turn the spa heater [ON,OFF]");
if ($state = said $v_spa_heat_set) {
  set $jandy "#SPAHT=$state";
  $SPAHTmode = 'set';
}

$v_spa_heat_chk = new Voice_Cmd("Check the spa heater status");
if ($state = said $v_spa_heat_chk) {
  set $jandy "#SPAHT?";
  $SPAHTmode = 'check';
}

$v_spa_temp = new Voice_Cmd("Check the spa temperature");
if ($state = said $v_spa_temp) {
  set $jandy "#SPATMP?";
}

$v_spa_sp_up = new Voice_Cmd("Increase the spa setpoint");
if ($state = said $v_spa_sp_up) {
  set $jandy "#SPASP+";
  $SPASPmode = 'set';
}

$v_spa_sp_dn = new Voice_Cmd("Decrease the spa setpoint");
if ($state = said $v_spa_sp_dn) {
  set $jandy "#SPASP-";
  $SPASPmode = 'set';
}

$v_spa_sp = new Voice_Cmd("Check the spa setpoint");
if ($state = said $v_spa_sp) {
  set $jandy "#SPASP?";
  $SPASPmode = 'check';
}

#OTHER
$v_pool_cleaner_set = new Voice_Cmd("Turn the pool cleaner [ON,OFF]");
if ($state = said $v_pool_cleaner_set) {
  set $jandy "#CLEANR=$state";
  $CLEANRmode = 'set';
}

$v_pool_cleaner_chk = new Voice_Cmd("Check the pool cleaner");
if ($state = said $v_pool_cleaner_chk) {
  set $jandy "#CLEANR?";
  $CLEANRmode = 'check';
}

#This bombs out as I have the cleaner instead - have it check and do this instead
$v_pool_AUX1_set = new Voice_Cmd("Turn the $AUX1 [ON,OFF]");
if ($state = said $v_pool_AUX1_set) {
  set $jandy "#AUX1=$state";
  $AUX1mode = 'set';
}

$v_pool_AUX1_chk = new Voice_Cmd("Check the $AUX1 status");
if ($state = said $v_pool_AUX1_chk) {
  if ($Cleaner eq '1') {
    speak "Your system doesn't use AUX 1 - Use Cleaner instead";
  } else {
    set $jandy "#AUX1?";
    $AUX1mode = 'check';
  }
}

$v_pool_AUX2_set = new Voice_Cmd("Turn the $AUX2 [ON,OFF]");
if ($state = said $v_pool_AUX2_set) {
  set $jandy "#AUX2=$state";
  $AUX2mode = 'set';
}

$v_pool_AUX2_chk = new Voice_Cmd("Check the $AUX2 status");
if ($state = said $v_pool_AUX2_chk) {
  set $jandy "#AUX2?";
  $AUX2mode = 'check';
}

$v_pool_AUX3_set = new Voice_Cmd("Turn the $AUX3 [ON,OFF]");
if ($state = said $v_pool_AUX3_set) {
  set $jandy "#AUX3=$state";
  $AUX3mode = 'set';
}

$v_pool_AUX3_chk = new Voice_Cmd("Check the $AUX3 status");
if ($state = said $v_pool_AUX3_chk) {
  set $jandy "#AUX3?";
  $AUX3mode = 'check';
}

$v_air_temp = new Voice_Cmd("Check the air temperature");
if ($state = said $v_air_temp) { set $jandy "#AIRTMP?"; }

#MISC

$v_pool_mode_chk = new Voice_Cmd("Check the pool mode");
if ($state = said $v_pool_mode_chk) { set $jandy "#OPMODE?"; }

$v_pool_diag = new Voice_Cmd("Run the pool diagnostics");
if ($state = said $v_pool_diag) { set $jandy "#DIAG"; }

$v_pool_options = new Voice_Cmd("Get the Power Center options");
if ($state = said $v_pool_options) { set $jandy "#OPTIONS?"; }

$v_pool_leds = new Voice_Cmd("Get the L E D Status");
if ($state = said $v_pool_leds) { set $jandy "#LEDS?"; }

$v_pool_vers = new Voice_Cmd("Get the pool version");
if ($state = said $v_pool_vers) { set $jandy "#VERS?"; }

$v_pool_model = new Voice_Cmd("Get the Jandy RS model");
if ($state = said $v_pool_model) { set $jandy "#MODEL?"; }

$v_reset = new Voice_Cmd("Reset the Jandy RS Serial Adapter");
if ($state = said $v_reset) {
  set $jandy "#RST";
  speak "Resetting the Jandy RS Serial Adapter";
}

$v_pool_battery = new Voice_Cmd("Check the pool battery");
if ($state = said $v_pool_battery) {
  set $jandy "#VBAT?";
  $VBATmode = 'check';
}

if ($Startup) {
  run_after_delay 2, "run_voice_cmd 'Check the pool pump status'";
  run_after_delay 4, "run_voice_cmd 'Check the pool heater status'";
  run_after_delay 6, "run_voice_cmd 'Check the pool temperature'";
  run_after_delay 8, "run_voice_cmd 'Check the spa status'";
  run_after_delay 10, "run_voice_cmd 'Check the spa heater status'";
  run_after_delay 12, "run_voice_cmd 'Check the spa temperature'";
  run_after_delay 14, "run_voice_cmd 'Check the pool cleaner'";
  run_after_delay 16, "run_voice_cmd 'Check the pool auxiliary device 3 status'";
  run_after_delay 18, "run_voice_cmd 'Check the air temperature'";
}


sub logspa {
  my $text = @_;
  my $spadb = "$config_parms{data_dir}/log/spa.log"; 
  open(SPADB, ">>$spadb");
  print SPADB "$Date_Now $Time_Now $Save{PoolSpaTemp} $Save{PoolAirTemp} $text\n";
  close SPADB;
}

sub logpool {
  my $pooldb = "$config_parms{data_dir}/log/pool.log"; 
  open(POOLDB, ">>$pooldb");
  print POOLDB "$Date_Now $Time_Now $Save{PoolTemp} $Save{PoolAirTemp}\n";
  close POOLDB;
}


#Commands
#
#Q=Query T=Toggle S=Set A=Action
#Uppercase = supported  Lowercase = unsupported
#
#
#AIRTMP     Q      Air Temperature
#AUX1       QtS    Auxiliary 1
#AUX2       QtS    Auxiliary 2
#AUX3       QtS    Auxiliary 3
#CLEANR     QtS    Cleaner
#CMDCHR     qs     Command Character
#COSMSGS    S      Change of Service Messages
#DIAG       A      Run Diagnostics
#ECHO       qS     Echo back commands
#ERRCHR     qs     Error Character
#LEDS       q      LED Status
#MODEL      Q      Model Number of AquaLink RS System
#NRMCHR     qs     Normal Character
#OPMODE     Q      Operational Mode (Auto, Service, Timeout)
#OPTIONS    Q      Options DIP Switch Settings
#POOLHT     QtS    Pool Heater
#POOLSP     QS     Pool Setpoint
#POOLTMP    Q      Pool Temp
#PUMP       QtS    Pump
#RSPFMT     qs     Response Format
#RST        A      Reset Serial Adapter
#S1         q      Serial Adapter DIP Switch
#SPA        QtS    Spa
#SPAHT      QtS    Spa Heater
#SPASP      QS     Spa Setpoint
#SPATMP     Q      Spa Temp
#UNITS      q      Temp Units
#VBAT       Q      Battery Voltage
#VERS       Q      Version of RS Serial Adapter
