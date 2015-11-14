# Category=Solar

#@ This module allows MisterHouse to communicate with a Xantrex GT3.0
#@ grid-tied photovoltaic power inverter, allowing for home automation
#@ monitoring of generated solar power.
#@
#@ Set the following parameters in your mh.private.ini file
#@ (serial_XanGT30_port will vary depending on OS/available ports):
#@ serial_XanGT30_port=/dev/ttyS0
#@ serial_XanGT30_baudrate=9600
#@ serial_XanGT30_handshake=none

=begin comment

XanGT3_0.pl

2005-Dec-26     Created by Brian McKissick (beanot(at)gmail(dot)com).

This module allows MisterHouse to communicate with a Xantrex GT3.0
grid-tied photovoltaic power inverter, allowing for home automation
monitoring of generated solar power.

Thanks to Bruce and everyone else for the continued work on this project!
=cut

my $command;
my $data;
my $ResponseParsed;
my $state;
my $value;
my $ROM_BVer;
my $ROM_MVer;
my $ROM_XVer;
my $ROM_PVer;
my $idn_ModelNo;
my $idn_X_No;
my $idn_SerNo;
my $custom11;
my $custom12;
my $custom21;
my $custom22;
my $TIMECtr;
my $MEASENGYSYS_SystemPower;
my $MEASENGYSYS_SystemTotal;
my $MEASENGYSYS_SystemLife;
my $whlife;
my $MEASIN_Voltage;
my $MEASIN_Current;
my $MEASIN_Power;
my $MEASOUT_Voltage;
my $MEASOUT_Current;
my $MEASOUT_Power;
my $MEASOUT_F_param;
my $MPPTSTAT_Voltage;
my $MPPTSTAT_TD_param;
my $MPPTSTAT_PL_param;
my $POWSEQ_ST_param;
my $POWSEQ_STS_param;
my $POWSEQ_FA_param;
my $RECTIME;
my $MEASENGY_UnitPower;
my $MEASENGY_UnitTotal;
my $MEASENGY_UnitLife;
my $DerateLimit;
my $MEASTEMP_HeatsinkTemp_degC;
my $MEASTEMP_HeatsinkTemp_degF;

$xangt30inv = new Serial_Item( undef, undef, 'serial_XanGT30' );

if ($Startup) {
    $command        = "";
    $ResponseParsed = 0;
}

if ( $data = said $xangt30inv ) {
    $data =~ s/\n//;
    $data =~ s/\r//;

    #    print_log "XanGT3.0: $data";

    if ( $command eq "ROM" ) {
        if ( $data =~ /^B:([^ ]+) M:([^ ]+) X:([^ ]+) P:([^ ]+)$/ ) {
            $ROM_BVer       = $1;
            $ROM_MVer       = $2;
            $ROM_XVer       = $3;
            $ROM_PVer       = $4;
            $ResponseParsed = 1;
            print_log
              "XanGT3.0 ROM Versions: B=$ROM_BVer, M=$ROM_MVer, X=$ROM_XVer, P=$ROM_PVer.";
            speak
              "XanGT3.0 ROM Versions: B=$ROM_BVer, M=$ROM_MVer, X=$ROM_XVer, P=$ROM_PVer.";
        }
    }

    if ( $command eq "idn" ) {
        if ( $data =~ /^M:([^ ]+) X:([^ ]+) S:([^ ]+)$/ ) {
            $idn_ModelNo    = $1;
            $idn_X_No       = $2;
            $idn_SerNo      = $3;
            $ResponseParsed = 1;
            print_log
              "XanGT3.0 IDs: Model=$idn_ModelNo, X=$idn_X_No, Serial=$idn_SerNo.";
            speak
              "XanGT3.0 IDs: Model=$idn_ModelNo, X=$idn_X_No, Serial=$idn_SerNo.";
        }
    }

    if ( $command eq "custom11" ) {
        if ( $data =~ /^................$/ ) {
            $custom11       = $data;
            $ResponseParsed = 1;
            print_log "XanGT3.0 custom screen 1 line 1=$custom11.";
            speak "XanGT3.0 custom screen 1 line 1=$custom11.";
        }
    }

    if ( $command eq "custom12" ) {
        if ( $data =~ /^................$/ ) {
            $custom12       = $data;
            $ResponseParsed = 1;
            print_log "XanGT3.0 custom screen 1 line 2=$custom12.";
            speak "XanGT3.0 custom screen 1 line 2=$custom12.";
        }
    }

    if ( $command eq "custom21" ) {
        if ( $data =~ /^................$/ ) {
            $custom21       = $data;
            $ResponseParsed = 1;
            print_log "XanGT3.0 custom screen 2 line 1=$custom21.";
            speak "XanGT3.0 custom screen 2 line 1=$custom21.";
        }
    }

    if ( $command eq "custom22" ) {
        if ( $data =~ /^................$/ ) {
            $custom22       = $data;
            $ResponseParsed = 1;
            print_log "XanGT3.0 custom screen 2 line 2=$custom22.";
            speak "XanGT3.0 custom screen 2 line 2=$custom22.";
        }
    }

    if ( $command eq "TIME" ) {
        $TIMECtr        = $data;
        $ResponseParsed = 1;
        print_log "XanGT3.0 time=$TIMECtr sec.";
        speak "XanGT3.0 time=$TIMECtr sec.";
    }

    if ( $command eq "MEASENGYSYS" ) {
        if ( $data =~ /^P:([^ ]+) T:([^ ]+) L:([^ ]+)$/ ) {
            $MEASENGYSYS_SystemPower = $1;
            $MEASENGYSYS_SystemTotal = $2;
            $MEASENGYSYS_SystemLife  = $3;
            $ResponseParsed          = 1;
            print_log
              "XanGT3.0 system power=$MEASENGYSYS_SystemPower W, daily total=$MEASENGYSYS_SystemTotal kWh, life=$MEASENGYSYS_SystemLife kWh.";
            speak
              "XanGT3.0 system power=$MEASENGYSYS_SystemPower W, daily total=$MEASENGYSYS_SystemTotal kWh, life=$MEASENGYSYS_SystemLife kWh.";
        }
    }

    if ( $command eq "whlife" ) {
        $whlife         = $data;
        $ResponseParsed = 1;
        print_log "XanGT3.0 whlife=$whlife.";
        speak "XanGT3.0 whlife=$whlife.";
    }

    if ( $command eq "MEASIN" ) {
        if ( $data =~ /^V:([^ ]+) I:([^ ]+) P:([^ ]+)$/ ) {
            $MEASIN_Voltage = $1;
            $MEASIN_Current = $2;
            $MEASIN_Power   = $3;
            $ResponseParsed = 1;
            print_log
              "XanGT3.0 MEASIN voltage=$MEASIN_Voltage V, current=$MEASIN_Current A, power=$MEASIN_Power W.";
            speak
              "XanGT3.0 MEASIN voltage=$MEASIN_Voltage V, current=$MEASIN_Current A, power=$MEASIN_Power W.";
        }
    }

    if ( $command eq "MEASOUT" ) {
        if ( $data =~ /^V:([^ ]+) I:([^ ]+) P:([^ ]+) F:([^ ]+)$/ ) {
            $MEASOUT_Voltage = $1;
            $MEASOUT_Current = $2;
            $MEASOUT_Power   = $3;
            $MEASOUT_F_param = $4;
            $ResponseParsed  = 1;
            print_log
              "XanGT3.0 MEASOUT voltage=$MEASOUT_Voltage V, current=$MEASOUT_Current A, power=$MEASOUT_Power W, F=$MEASOUT_F_param Hz.";
            speak
              "XanGT3.0 MEASOUT voltage=$MEASOUT_Voltage V, current=$MEASOUT_Current A, power=$MEASOUT_Power W, F=$MEASOUT_F_param Hz.";
        }
    }

    if ( $command eq "MPPTSTAT" ) {
        if ( $data =~ /^V:([^ ]+) TD:([^ ]+) PL:([^ ]+)$/ ) {
            $MPPTSTAT_Voltage  = $1;
            $MPPTSTAT_TD_param = $2;
            $MPPTSTAT_PL_param = $3;
            $ResponseParsed    = 1;
            print_log
              "XanGT3.0 MPPTSTAT (peak power) voltage=$MPPTSTAT_Voltage, TD=$MPPTSTAT_TD_param, PL=$MPPTSTAT_PL_param.";
            speak
              "XanGT3.0 MPPTSTAT (peak power) voltage=$MPPTSTAT_Voltage, TD=$MPPTSTAT_TD_param, PL=$MPPTSTAT_PL_param.";
        }
    }

    if ( $command eq "POWSEQ" ) {
        if ( $data =~ /^ST:([^ ]+) STS:([^ ]+ [^ ]+ [^ ]+ [^ ]+) FA:([^ ]+)$/ )
        {
            $POWSEQ_ST_param  = $1;
            $POWSEQ_STS_param = $2;
            $POWSEQ_FA_param  = $3;
            $ResponseParsed   = 1;
            print_log
              "XanGT3.0 POWSEQ ST=$POWSEQ_ST_param, STS=$POWSEQ_STS_param, FA=$POWSEQ_FA_param.";
            speak
              "XanGT3.0 POWSEQ ST=$POWSEQ_ST_param, STS=$POWSEQ_STS_param, FA=$POWSEQ_FA_param.";
        }
    }

    if ( $command eq "RECTIME" ) {
        $RECTIME        = $data;
        $ResponseParsed = 1;
        print_log "XanGT3.0 RECTIME=$RECTIME.";
        speak "XanGT3.0 RECTIME=$RECTIME.";
    }

    if ( $command eq "MEASENGY" ) {
        if ( $data =~ /^P:([^ ]+) T:([^ ]+) L:([^ ]+)$/ ) {
            $MEASENGY_UnitPower = $1;
            $MEASENGY_UnitTotal = $2;
            $MEASENGY_UnitLife  = $3;
            $ResponseParsed     = 1;
            print_log
              "XanGT3.0 unit power=$MEASENGY_UnitPower W, daily total=$MEASENGY_UnitTotal kWh, life=$MEASENGY_UnitLife kWh.";
            speak
              "XanGT3.0 unit power=$MEASENGY_UnitPower W, daily total=$MEASENGY_UnitTotal kWh, life=$MEASENGY_UnitLife kWh.";
        }
    }

    if ( $command eq "DERATELIMIT" ) {
        $DerateLimit    = $data;
        $ResponseParsed = 1;
        print_log "XanGT3.0 derate limit=$DerateLimit.";
        speak "XanGT3.0 derate limit=$DerateLimit.";
    }

    if ( $command eq "MEASTEMP" ) {
        if ( $data =~ /^C:([^ ]+) F:([^ ]+)$/ ) {
            $MEASTEMP_HeatsinkTemp_degC = $1;
            $MEASTEMP_HeatsinkTemp_degF = $2;
            $ResponseParsed             = 1;
            print_log
              "XanGT3.0 heatsink temp=$MEASTEMP_HeatsinkTemp_degF degF ($MEASTEMP_HeatsinkTemp_degC degC).";
            speak
              "XanGT3.0 heatsink temp=$MEASTEMP_HeatsinkTemp_degF degF ($MEASTEMP_HeatsinkTemp_degC degC).";
        }
    }

    if ( $ResponseParsed != 1 ) {
        print_log
          "XanGT3.0 serial input parsing error: command=$command data=$data";
        speak
          "XanGT3.0 serial input parsing error: command=$command data=$data";
    }
}

# Query commands
$v_xangt30_get_rom_ver = new Voice_Cmd("Get XanGT3.0 ROM versions");
if ( $state = said $v_xangt30_get_rom_ver) {
    set $xangt30inv "ROM?";
    $command = "ROM";
}

$v_xangt30_get_ids = new Voice_Cmd("Get XanGT3.0 IDs");
if ( $state = said $v_xangt30_get_ids) {
    set $xangt30inv "idn?";
    $command = "idn";
}

$v_xangt30_get_custom11 = new Voice_Cmd("Get XanGT3.0 custom screen 1 line 1");
if ( $state = said $v_xangt30_get_custom11) {
    set $xangt30inv "custom11?";
    $command = "custom11";
}

$v_xangt30_get_custom12 = new Voice_Cmd("Get XanGT3.0 custom screen 1 line 2");
if ( $state = said $v_xangt30_get_custom12) {
    set $xangt30inv "custom12?";
    $command = "custom12";
}

$v_xangt30_get_custom21 = new Voice_Cmd("Get XanGT3.0 custom screen 2 line 1");
if ( $state = said $v_xangt30_get_custom21) {
    set $xangt30inv "custom21?";
    $command = "custom21";
}

$v_xangt30_get_custom22 = new Voice_Cmd("Get XanGT3.0 custom screen 2 line 2");
if ( $state = said $v_xangt30_get_custom22) {
    set $xangt30inv "custom22?";
    $command = "custom22";
}

$v_xangt30_get_time = new Voice_Cmd("Get XanGT3.0 time");
if ( $state = said $v_xangt30_get_time) {
    set $xangt30inv "TIME?";
    $command = "TIME";
}

$v_xangt30_get_system_stats = new Voice_Cmd("Get XanGT3.0 system stats");
if ( $state = said $v_xangt30_get_system_stats) {
    set $xangt30inv "MEASENGYSYS?";
    $command = "MEASENGYSYS";
}

$v_xangt30_get_whlife = new Voice_Cmd("Get XanGT3.0 whlife");
if ( $state = said $v_xangt30_get_whlife) {
    set $xangt30inv "whlife?";
    $command = "whlife";
}

$v_xangt30_get_measin = new Voice_Cmd("Get XanGT3.0 MEASIN");
if ( $state = said $v_xangt30_get_measin) {
    set $xangt30inv "MEASIN?";
    $command = "MEASIN";
}

$v_xangt30_get_measout = new Voice_Cmd("Get XanGT3.0 MEASOUT");
if ( $state = said $v_xangt30_get_measout) {
    set $xangt30inv "MEASOUT?";
    $command = "MEASOUT";
}

$v_xangt30_get_mpptstat = new Voice_Cmd("Get XanGT3.0 MPPTSTAT");
if ( $state = said $v_xangt30_get_mpptstat) {
    set $xangt30inv "MPPTSTAT?";
    $command = "MPPTSTAT";
}

$v_xangt30_get_powseq = new Voice_Cmd("Get XanGT3.0 POWSEQ");
if ( $state = said $v_xangt30_get_powseq) {
    set $xangt30inv "POWSEQ?";
    $command = "POWSEQ";
}

$v_xangt30_get_rectime = new Voice_Cmd("Get XanGT3.0 RECTIME");
if ( $state = said $v_xangt30_get_rectime) {
    set $xangt30inv "RECTIME?";
    $command = "RECTIME";
}

$v_xangt30_get_unit_stats = new Voice_Cmd("Get XanGT3.0 unit stats");
if ( $state = said $v_xangt30_get_unit_stats) {
    set $xangt30inv "MEASENGY?";
    $command = "MEASENGY";
}

$v_xangt30_get_deratelimit = new Voice_Cmd("Get XanGT3.0 derate limit");
if ( $state = said $v_xangt30_get_deratelimit) {
    set $xangt30inv "DERATELIMIT?";
    $command = "DERATELIMIT";
}

$v_xangt30_get_heatsink_temp = new Voice_Cmd("Get XanGT3.0 heatsink temp");
if ( $state = said $v_xangt30_get_heatsink_temp) {
    set $xangt30inv "MEASTEMP?";
    $command = "MEASTEMP";
}

if ($Startup) {
    run_after_delay 2, "run_voice_cmd 'Get XanGT3.0 ROM versions'";
    run_after_delay 4, "run_voice_cmd 'Get XanGT3.0 IDs'";
}

# These are the commands I found by logging serial traffic between an inverter and the GTView client provided by Xantrex.
# I can only assume that this is only a subset of the total available commands.
# If anyone should find any additional info as to the complete serial protocol spec, I would greatly appreciate updates! Thanks!
#
# Command                       Description
#
# ROM?                          Get ROM Versions
# idn?                          Get Model No., Serial No.(?)
# custom11?                     Get custom display 1 line 1
# custom12?                     Get custom display 1 line 2
# custom21?                     Get custom display 2 line 1
# custom22?                     Get custom display 2 line 2
# TIME?                         Get time (?)
# MEASENGYSYS?                  Get current system power, total (daily) system power, total system life (accum power)
# whlife?                       Get unit life (accum power) ???
# MEASIN?                       Get current array supply voltage, current, and power
# MEASOUT?                      Get V, I, P, F (output voltage, current, power, and frequency)
# MPPTSTAT?                     Get V, TD, PL (???)
# POWSEQ?                       Get ST, STS, FA (???)
# RECTIME?                      Get ???
# MEASENGY?                     Get current power, total (daily) power, and unit life (accum power)
# DERATELIMIT?                  Get limit above which derating occurs (?)
# MEASTEMP?                     Get heatsink temp in degC and degF
# custom11abcdefghijklmnop      Set custom display 1 line 1 to 'abcdefghijklmnop' (16 chars)
# custom12abcdefghijklmnop      Set custom display 1 line 2 to 'abcdefghijklmnop' (16 chars)
# custom21abcdefghijklmnop      Set custom display 2 line 1 to 'abcdefghijklmnop' (16 chars)
# custom22abcdefghijklmnop      Set custom display 2 line 2 to 'abcdefghijklmnop' (16 chars)
# custom11erase                 Clear custom display 1 line 1
# custom12erase                 Clear custom display 1 line 2
# custom21erase                 Clear custom display 2 line 1
# custom22erase                 Clear custom display 2 line 2
# Backlight 0                   Turn off LCD backlight
# Backlight 1                   Turn on LCD backlight (WARNING - backlight will stay ON until turned OFF!)

