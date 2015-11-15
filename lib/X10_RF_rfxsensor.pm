
=begin comment

X10_RF_rfxsensor.pm

This module contains routines called by X10_RF.pm to determine if a
group of RF data bytes represents a valid rfxsensor command and
to decompose that data and set the state of the specific rfxsensor
specified by the command to the state specified by the command.

The rfxsensor is a wireless temperature/humidity/pressure/low voltage sensor
that can have up to 8 one-wire sensors attached.  The default address of the
first sensor (the built-in one) is 00f0, the second is 01f1, the third is
02f2, and so on.  Here is the information on it:
http://www.rfxcom.com/documents/RFXSensor.pdf

David Norwood

=cut

use strict;

package X10_RF;

use X10_RF;

#------------------------------------------------------------------------------

# Subroutine: rf_is_rfxsensor
#	Determine if <bytes> represents a valid rfxsensor style command.

sub rf_is_rfxsensor {
    my (@bytes) = @_;

    my @rbytes;
    for ( my $i = 0; $i < 4; $i++ ) {
        $rbytes[$i] = ord( pack( "b8", unpack( "b*", $bytes[$i] ) ) );
    }

    my $B0H = $rbytes[0] >> 4;
    my $B0L = $rbytes[0] & 0x0F;
    my $B1H = $rbytes[1] >> 4;
    my $B1L = $rbytes[1] & 0x0F;
    my $B2H = $rbytes[2] >> 4;
    my $B2L = $rbytes[2] & 0x0F;
    my $B3H = $rbytes[3] >> 4;
    my $B3L = $rbytes[3] & 0x0F;

    # check if unit bytes are in the right format here
    my $found = ( $B0L == $B1L and ( 0xf - $B0H ) == $B1H );

    # check parity bits here
    $found = $found
      && ( $B3L ==
        ( 0xf - ( ( $B0H + $B0L + $B1H + $B1L + $B2H + $B2L + $B3H ) & 0xf ) )
      );
    return $found;
}

#------------------------------------------------------------------------------

# Subroutine: rf_process_rfxsensor
#	Given a valid rfxsensor style command in <bytes>, set the state
#	of rfxsensor specified by the command to the state specfied by
#	the command.
#	<module> indicates the source of the request (w800)

sub rf_process_rfxsensor {
    my ( $module, @bytes ) = @_;

    my $lc_module = lc $module;
    my @rbytes;
    for ( my $i = 0; $i < 4; $i++ ) {
        $rbytes[$i] = ord( pack( "b8", unpack( "b*", $bytes[$i] ) ) );
    }

    my ( $cmd, $device_id, $id, $state );
    my ($measurement);

    # Unlike X-10 security devices, the rfxsensor's ID is 2 bytes long
    $device_id = $rbytes[0] * 256 + $rbytes[1];
    $id        = $rbytes[0];

    if ( $rbytes[3] & 0x10 )
    {    # device has no set temperature (set temp always 0x00)
        use Switch;
        switch ( $rbytes[2] ) {
            case 0x01 {
                &::print_log(
                    "$module: rfxsensor: info: sensor addresses incremented")
            }
            case 0x02 {
                &::print_log("$module: rfxsensor: info: battery low detected")
            }
            case 0x03 {
                &::print_log(
                    "$module: rfxsensor: info: conversion not ready, 1 retry is done"
                  )
            }
            case 0x81 {
                &::print_log(
                    "$module: rfxsensor: error: no 1-wire device connected")
            }
            case 0x82 {
                &::print_log("$module: rfxsensor: error: 1-Wire ROM CRC error")
            }
            case 0x83 {
                &::print_log(
                    "$module: rfxsensor: error: 1-Wire device connected is not a DS18B20 or DS2438"
                  )
            }
            case 0x84 {
                &::print_log(
                    "$module: rfxsensor: error: no end of read signal received from 1-Wire device"
                  )
            }
            case 0x85 {
                &::print_log(
                    "$module: rfxsensor: error: 1-Wire scratchpad CRC error")
            }
            case 0x86 {
                &::print_log(
                    "$module: rfxsensor: error: temperature conversion not ready in time"
                  )
            }
            case 0x87 {
                &::print_log(
                    "$module: rfxsensor: error: A/D conversion not ready in time"
                  )
            }
        }
    }
    else {
        $measurement = $rbytes[2] * 8 + ( $rbytes[3] >> 5 );

        # let's assume these are standard type 3 rfxsensors and the zeroth sensor is a ds2438 temperature sensor
        if ( $id % 8 == 0 ) {
            $measurement *= -1 if ( $rbytes[2] & 0x80 );    # check for sign bit
            $measurement *= .125;                           # this is celcius
            if ( $main::config_parms{weather_uom_temp} == 'F' ) {
                $measurement = &::convert_c2f($measurement);
            }
        }

        # and the 1st sensor is the ds2438 A/D converter with an attached humidity sensor, create a dummy object even if you don't have
        # the humidity sensor so you don't get unmatched device errors
        elsif ( $id % 8 == 1 ) {
            $measurement *= 10;    # this is mVols from the A/D conversion
            &::print_log(
                "$module: rfxsensor: the A/D input is $measurement mVolts")
              if ( $main::Debug{$lc_module} );

            # get temperature
            my $tmp_id = $id - 1;
            $tmp_id =
              $tmp_id * 256 +
              ( ( 0xf - ( $tmp_id >> 4 ) ) * 16 ) +
              ( $tmp_id & 0xf );
            $tmp_id = lc sprintf "%04x", $tmp_id;
            my $temperature = &rf_get_RF_Item( $module, 'rfxsensor',
                "unmatched device $tmp_id", $tmp_id );
            if ( $main::config_parms{weather_uom_temp} == 'F' ) {
                $temperature = &::convert_f2c($temperature);
            }

            # get supply voltage
            my $tmp_id = $id + 1;
            $tmp_id =
              $tmp_id * 256 +
              ( ( 0xf - ( $tmp_id >> 4 ) ) * 16 ) +
              ( $tmp_id & 0xf );
            $tmp_id = lc sprintf "%04x", $tmp_id;
            my $supply_voltage = &rf_get_RF_Item( $module, 'rfxsensor',
                "unmatched device $tmp_id", $tmp_id );
            if (    defined $temperature
                and defined $supply_voltage
                and $supply_voltage )
            {
                $measurement =
                  ( ( ( $measurement / $supply_voltage ) - 0.16 ) / 0.0062 ) /
                  ( 1.0546 - 0.00216 * $temperature )
                  ;    # this is % relative humidity
            }
            else {
                &::print_log(
                    "$module: rfxsensor: error: can't calculate relative humidity without temperature and supply voltage measurements"
                );
                return undef;
            }
        }

        # and the 2nd sensor is the ds2438 supply voltage, create a dummy object even if you don't care
        elsif ( $id % 8 == 2 ) {
            $measurement *= 10;    # this is mVols
        }

        # assume any other device ids are ds18b20 temperature sensors, since they are cheap
        else {
            $measurement *= -1 if $rbytes[2] & 0x80;    # check for sign bit
            $measurement = $measurement / 4 * .5;       # this is celcius
            if ( $main::config_parms{weather_uom_temp} == 'F' ) {
                $measurement = &::convert_c2f($measurement);
            }
        }
    }

    my $item_id = lc sprintf "%04x", $device_id;

    # Set the state of any items or classes associated with this device.
    &rf_set_RF_Item( $module, 'rfxsensor', "unmatched device 0x$item_id",
        $item_id, undef, $measurement );

    return $measurement;
}

1;

=begin comment

This module doesn't decode the "initialization" bytes sent by the rfxsensor.  This wouldn't
add much functionality to this module because it wouldn't tell us how a DS2438 is being
used.

=cut
