
=begin comment

DSC Alarm users,

This is my BETA V0.2 for DSC serial module, it's still in DEV, but I would like to share it....

Our current result in MH log:

# 12/28/04 02:20:03 PM MH <--- DSC PC5401 - DSC Command: 550 Data:1420122804 CKS=92
# 12/28/04 02:17:55 PM MH <--- DSC PC5401 - (610) Zone Restored: 012 CKS=2A
# 12/28/04 02:17:52 PM MH <--- DSC PC5401 - (609) Zone Open: 012 CKS=32
# 12/28/04 02:17:46 PM MH <--- DSC PC5401 - (610) Zone Restored: 012 CKS=2A
# 12/28/04 02:17:43 PM MH <--- DSC PC5401 - (609) Zone Open: 012 CKS=32
# 12/28/04 02:17:40 PM MH <--- DSC PC5401 - (610) Zone Restored: 012 CKS=2A
# 12/28/04 02:17:37 PM MH <--- DSC PC5401 - (609) Zone Open: 012 CKS=32
# 12/28/04 02:17:24 PM MH <--- DSC PC5401 - (610) Zone Restored: 012 CKS=2A
# 12/28/04 02:17:21 PM MH <--- DSC PC5401 - (609) Zone Open: 012 CKS=32
# 12/28/04 02:17:20 PM MH <--- DSC PC5401 - (610) Zone Restored: 012 CKS=2A
# 12/28/04 02:17:14 PM MH <--- DSC PC5401 - (609) Zone Open: 012 CKS=32

Best regards,
Jocelyn

=cut

-------------dsc_pc5401 . pl--------------------

  # Category=Alarm System
  #@ Interface to DSC alarm system via DSC PC5401 Serial Module V0.2beta

##################################################################
  #  Interface to DSC alarm system via DSC PC5400 Printer Module   #
  #                                                                #
  #  Add these entries to your mh.ini or mh.private.ini file:      #
  #                                                                #
  #    serialdsc_port=/dev/ttyS0  or COM2                          #
  #    serialdsc_baudrate=9600                                     #
  #    serialdsc_datatype=raw                                      #
  #                                                                #
  #  Date: 2004-12-28                                              #
  #                                                                #
##################################################################

  if ( $Startup || $Reload ) {
    $Serial_Ports{serialdsc}{datatype} = 'raw';
    $serial_out = new Serial_Item( undef, undef, 'serialdsc' );

    #- Variables for code output
    my $DSCcmd;
    my $checksum;
    my $CKStmp;
    my $CKStmp2;

    #- Variables for code input
    my $datadsc;
    my $dsc_rx_code;

    #- Others functions variables
    my $ShortYear;
    my $LongHour;

}    # END of reload

#- Each new day Sync DSC Time Clock to MH
if ($New_Day) {
    $ShortYear = substr( "$Year", 2, 2 );
    $LongHour = "$Hour";
    if ( length $LongHour eq 1 ) {
        $LongHour = "0$Hour";
    }
    else {
        $LongHour = "$Hour";
    }
    &mh2dsc5401("010$LongHour$Minute$Month$Mday$ShortYear");
    print_log
      "MH ---> DSC PC5401 - Clock Adjust $LongHour:$Minute $Month/$Mday/$Year";
}    # END of new day

#-----------------------------#
# Read Data from PC5401 to MH #
#-----------------------------#
if ( my $datadsc = said $serial_out) {
    $dsc_rx_code = dsc_rx_data($datadsc);

    #
    #- TODO: Insert codes here for upgrading MH variables
    #

    #if ($config_parms{debug} eq 'DSC')
    #{
    logit( "/usr/local/mh/data/logs/serialdsc.$Year_Month_Now.log", $datadsc );
    print_log "MH <--- DSC PC5401 - $dsc_rx_code";

    #}
}    #-- End of read data

#------------------------------------------------------------------------------
#               SuB Routine Section
#------------------------------------------------------------------------------
#
#---------------------------------
#  Sub Presention of Received Data
#---------------------------------
sub dsc_rx_data ($) {
    my $dsc_rx_out;
    my $dsc_rx_info;
    my $dsc_tmp_code;
    my $dsc_tmp_data;
    my $dsc_tmp_cks;
    my $dsc_tmp_length;

    $dsc_rx_info = $_[0];        # Parsing received informtion
    $dsc_rx_info =~ s/\s+$//;    # Remove endding spaces
    $dsc_tmp_length = length $dsc_rx_info;    # Calculate the string length

    $dsc_tmp_code = substr( $dsc_rx_info, 0, 3 );  # Separation Command Code and
    $dsc_tmp_data =
      substr( $dsc_rx_info, 3, ( $dsc_tmp_length - 5 ) );    # data information
    $dsc_tmp_cks =
      substr( $dsc_rx_info, ( $dsc_tmp_length - 2 ), 2 );    # and Checksum

    #
    #- TODO: Add here verify received checksum before to processing information
    #

    if ( $dsc_tmp_code eq "610" ) {
        $dsc_rx_out = "($dsc_tmp_code) Zone Restored: $dsc_tmp_data";
    }
    elsif ( $dsc_tmp_code eq "609" ) {
        $dsc_rx_out = "($dsc_tmp_code) Zone Open: $dsc_tmp_data";
    }
    elsif ( $dsc_tmp_code eq "500" ) {
        $dsc_rx_out =
          "($dsc_tmp_code) OK Last command received is : $dsc_tmp_data";
    }
    elsif ( $dsc_tmp_code eq "501" ) {
        $dsc_rx_out = "($dsc_tmp_code) Error! : Receive Bad CheckSum";
    }
    elsif ( $dsc_tmp_code eq "502" ) {
        $dsc_rx_out = "($dsc_tmp_code) Error! : $dsc_tmp_data";
    }
    elsif ( $dsc_tmp_code eq "560" ) {
        $dsc_rx_out = "($dsc_tmp_code) Phone Ring Detected!";
    }
    elsif ( $dsc_tmp_code eq "561" ) {
        $dsc_rx_out = "($dsc_tmp_code) Indoor Temp : $dsc_tmp_data";
    }
    elsif ( $dsc_tmp_code eq "562" ) {
        $dsc_rx_out = "($dsc_tmp_code) Outdoor Temp : $dsc_tmp_data";
    }
    elsif ( $dsc_tmp_code eq "601" ) {
        $dsc_rx_out = "($dsc_tmp_code) Zone alarm in : $dsc_tmp_data";
    }
    elsif ( $dsc_tmp_code eq "602" ) {
        $dsc_rx_out = "($dsc_tmp_code) Zone alarm Restore : $dsc_tmp_data";
    }

    #
    #- TODO: Add others RX code here
    #

    else { $dsc_rx_out = "DSC Command: $dsc_tmp_code Data:$dsc_tmp_data" }
    return "$dsc_rx_out" . " CKS=$dsc_tmp_cks";
}
#
#-----------------------------
#  SUB MH write ---> PC5401
#-----------------------------
#
sub mh2dsc5401($) {

    #- $DSCcmd = "000";               # ex: 6543 (654 for Part in alarm cmd and 3 for Part #)
    #- $DSCcmd = "001";               # ex: Status Report
    #- $DSCcmd = "0560";              # ex: Set Time Broadcast Off
    #- $DSCcmd = "0561";              # ex: Set Time Broadcast On
    #- $DSCcmd = "0100940122504";     # Set date and time CCC HH:MM MM/DD/YY

    $DSCcmd = $_[0];

    my $idecstr;
    $idecstr = 0;
    $CKStmp  = 0;
    $CKStmp2 = 0;

    while ( $idecstr < length($DSCcmd) ) {
        $CKStmp2 = unpack( "C", substr( $DSCcmd, $idecstr, 1 ) );
        $CKStmp  = $CKStmp + $CKStmp2;
        $idecstr = $idecstr + 1;
        print_log "$CKStmp <-- $CKStmp2 ($idecstr)"
          if ( $config_parms{debug} eq 'DSC' );
    }
    $checksum = uc substr( unpack( "H8", pack( "N", $CKStmp ) ), 6, 2 );
    print_log "$CKStmp --> $checksum" if ( $config_parms{debug} eq 'DSC' );
    print_log "$CKStmp --> $checksum";

    #
    # Notes: set $serial_out "00090\r\n";
    #        set $serial_out "00191\r\n";

    set $serial_out "$DSCcmd$checksum\r\n";

    #if ($config_parms{debug} eq 'DSC')
    #{
    print_log "MH ---> DSC PC5401 - CMD/Data:$DSCcmd CKS:$checksum";

    #}
}

#-----------------------------
#  END of Sub Routine Section
#-----------------------------
