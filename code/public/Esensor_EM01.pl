
=begin comment

For sensor from:  http://www.eEsensors.com

I have the data posting to:
$TempSpare1, $HumidSpare1, $SunSensor, $E_sensor185 (Dry Contact)

Let me know if you have any questions. I have 3 of them running in Misterhouse under "$xxxxSapre1, Spare2, and Spare3.

Rick "TheBassman" Bassett
Salt Lake City USA
http://thebassman.is-a-geek.net

=cut

# Category = Weather

# set $f_sensor184_url = IP address in mh.ini or mh.private.ini  http://www.eEsensors.com
# Support added my Rick "TheBassman" Bassett	http://thebassman.is-a-geek.net	  thebassmanis@gmail.com

$TempSpare1  = new Weather_Item 'TempSpare1';
$HumidSpare1 = new Weather_Item 'HumidSpare1';

#$SunSensor    = new Weather_Item 'sun_sensor';   #Could be used for the Lumination sensor. Uncomment throughout the file to use
#$Esensor184	= new Weather_Item 'Esensor184';  #Could be used for the contact feature.  Uncomment throughout the file to use

my $f_sensor184_text = "$config_parms{data_dir}/web/esensor184.txt";
my $f_sensor184_html = "$config_parms{data_dir}/web/esensor184.html";
my $f_sensor184_url  = $config_parms{Esensor184_id};

$p_check_sensor184 = new Process_Item
  qq[get_url "http://$f_sensor184_url/index.html" "$f_sensor184_html"];
$v_check_sensor184 = new Voice_Cmd('[Get,Read,Check] sernsor184');

if ( ( $New_Minute and ( ( $Minute % 5 ) == 2 ) ) ) {
    if (&net_connect_check) {
        $v_check_sensor184->respond("Getting sensor184 data...");
        start $p_check_sensor184;
    }
    else {
        $v_check_sensor184->respond("Cannot retrieve data.");
    }
}

if ( done_now $p_check_sensor184) {

    my $html = file_read $f_sensor184_html;

    my $text = &html_to_text($html);

    $text =~ /\D\D\d+TF\D+([\d.]+)\D*HU\D*([\d.]+)\D*IL\D*[\d.]+/;
    file_write( $f_sensor184_text, $text );

    if ( $v_check_sensor184->{state} eq 'Check' ) {
        $v_check_sensor184->respond("connected=0 important=1 $text");
    }
    else {
        $v_check_sensor184->respond("connected=0 data retrieved.");
    }
}
my $text2 = file_read $f_sensor184_text;

my ( $TempSpare1, $HumidSpare1 ) =
  $text2 =~ /\D\D\d+TF\D+([\d.]+)\D*HU\D*([\d.]+)\D*IL\D*[\d.]+/;

#    my ($E_sensor185, $TempIndoor, $HumidIndoor, $SunSensor) = $text2 =~ /\D(\D)\d+TF\D+([\d.]+)\D*HU\D*([\d.]+)\D*IL\D*([\d.]+)/;

$Weather{TempSpare1}  = $TempSpare1;
$Weather{HumidSpare1} = $HumidSpare1;

#$Weather{sun_sensor} = $SunSensor;
#$Esensor184 = $E_sensor184;

