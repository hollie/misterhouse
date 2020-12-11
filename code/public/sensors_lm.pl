
=begin comment

Return the Ambient or CPU temperature as measured by the sensors utility
under Mister House (Linux only).

By Denis Cheong <zylantha@bigfoot.com>

This is my first publishable MH module :)  

It is a very simple routine that allows you to use the lm_sensors package
(Linux only) to return temperature information as monitored by the onboard
thermal diodes on your motherboard, and include it in your MH web pages.

There is ample documentation in the code on how to get it working.

Why display temperatures as recorded by your motherboard?  Well apart from
the obvious hardware monitoring function, my MH motherboard (Asus P2B-F)
has a "Power Supply Temp Sensor" jumper to which I have a $5 thermal diode
from www.coolpc.com.au attached, hanging *outside* MH\'s case, so it
measures the ambient temperature of the room rather than the motherboard
or CPU temperature - makes a very cheap additional temperature sensor for
those without iButtons or any other temperature monitoring hardware.  For
better temperature monitoring I should really put the sensor in front of
the intake fan on the front of the case, however the wire is not long
enough :(

 Steps to get this working:
   1. Install the RPMs lm-sensors & sensors (or compile & install source)
   2. Configure the sensors package (run sensors-detect)
   3. Load the appropriate sensors modules using modprobe
   4. Name the sensors appropriately by modifying sensors.conf
   5. Ensure that sensors are detected & working by running 'sensors'
   6. Add a line similar to the following to mh.ini:
       sensors_cmd=sensors -c /etc/sensors-temp.conf w83781d-isa-0290
      (note: I use a restricted config file to return just temperatures
       and restrict the output to use the temperature sensor chip so it
       runs faster.  You could get away with just "sensors" if this
       does not matter to you.
   7. Copy this script to your MH /code directory
   8. In one your appropriate web pages, insert the line similar to:
       <!-- #include code="sensor_output('Lounge Temp')" -->
      (note 'Lounge Temp' corresponds to the name you gave the sensor
       in sensors.conf.  You can output any of the sensors you have; my
       temp2 sensor is on a wire hanging outside of the MH case so that
       it measures the ambient temperature rather than case or CPU temp
       which is quite handy :)

   To do ... record the last time that the sensor was read so that
             the 'sensors' program is not run every single time a reading
             is requested (a maximum of once every 1.5 seconds is the
             maximum useable resolution of the sensors package (actually
             of the lm78 chipset) anyway)

=cut

my ($sensors_output);

sub sensor_output($) {
    my ($which_sensor) = @_;

    $sensors_output = qx/$config_parms{sensors_cmd}/;

    my ($ret) = $sensors_output =~ /${which_sensor}:\s+(.+?)\s+\(/i;

    return $ret;
}

