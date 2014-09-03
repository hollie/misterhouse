
=begin Comment

For those with a Hauppauge WinTV Card, here is a little script to play and
control the radio program through MH.  There is no volume control, just
station selection and off.
 
=cut

# Category=Music

#This is to control the WinTV Radio included with Hauppauge WinTV line of cards
#Add the following line to your mh.private.ini:
#  WinRadio=D:\Progra~1\WinTV\radio.exe
#Change the numbers to match your local stations
#Add the following to an HTML page to play via the web:
#  <a href='/RUN?Set_house_radio_to_100.3'>KCYY 100.3 Country</a>

$v_radio_control = new Voice_Cmd(
    "Set House radio to [90.1,91.7,92.5,92.9,95.1,96.1,97.3,98.5,99.5,100.3,101.1,101.9,104.5,105.3,106.7,/QUIT]"
);

if ( $state = said $v_radio_control) {
    run qq[$config_parms{WinRadio} "$state"];

}

