# Category=Alarm
#@ Starting DSC Alarm Main serial module and secondary DSC/Modem serial Port
#@ Small Process:
#@ - Set Thermostat to day mode at time
#@ - Disarme User Voice Annoncemnt
# $Revision$
# $Date$

if ( $Startup || $Reload ) {
    use DSC5401;

    # DSC5401 startup
    $DSC = new DSC5401;

    #
    # Add second serial port with modem to control DSC escort module
    # via phone line and dial tone
    #
    $Serial_Ports{serialdscescort}{datatype} = 'raw';
    $serial_out_2 = new Serial_Item( undef, undef, 'serialdscescort' );

    set $serial_out_2 "ati0q0v0e0l3m2x4\r\n";

    #set $serial_out_2 "ate1\r\n"; 		# If debug is enable...

}
#
## End of reload

if ( $DSC->state_now =~ /^disarmed/ ) {
    speak(
        mode   => 'unmuted',
        volume => 100,
        rooms  => 'all',
        text   => "Hi $DSC->{user_name}"
    );
}

#
# DSC escort module
# via phone line and dial tone
#
if ( my $datadsc2 = said $serial_out_2) {
    print_log "From Modem No.1 - $datadsc2";
}

&Set_DSC_Thermostat
  if ( ( $Wday == '1' )
    && ( time_now '05:55' )
    && ( $DSC->{partition_status}{1} =~ /ready/ ) );
&Set_DSC_Thermostat
  if ( ( $Wday == '2' )
    && ( time_now '05:55' )
    && ( $DSC->{partition_status}{1} =~ /ready/ ) );
&Set_DSC_Thermostat
  if ( ( $Wday == '3' )
    && ( time_now '05:55' )
    && ( $DSC->{partition_status}{1} =~ /ready/ ) );
&Set_DSC_Thermostat
  if ( ( $Wday == '4' )
    && ( time_now '05:55' )
    && ( $DSC->{partition_status}{1} =~ /ready/ ) );
&Set_DSC_Thermostat
  if ( ( $Wday == '5' )
    && ( time_now '05:55' )
    && ( $DSC->{partition_status}{1} =~ /ready/ ) );
&Set_DSC_Thermostat
  if ( ( $Wday == '6' )
    && ( time_now '05:55' )
    && ( $DSC->{partition_status}{1} =~ /ready/ ) );
&Set_DSC_Thermostat
  if ( ( $Wday == '7' )
    && ( time_now '05:55' )
    && ( $DSC->{partition_status}{1} =~ /ready/ ) );

sub Set_DSC_Thermostat {
    set $serial_out_2 "atdt*#*,*,52121,h\r\n";
}

