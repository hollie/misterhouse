
=begin comment

Reads temp,pressure,humidity from the sensor sold at http://www.froggyhome.com.

See mh/lib/FroggyRita.pm for more information. 

=cut

# Category = Froggy

$v_Froggy = new FroggyRita;
my ( $RitaTemp, $RitaPres, $RitaHum, $RitaTime );

# get data every 5 minutes

if ( new_minute 5 ) {
    my ( $RitaTemp, $RitaPres, $RitaHum, $RitaTime ) = $v_Froggy->GetData;
}
