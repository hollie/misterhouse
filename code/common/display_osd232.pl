
# Category = MisterHouse

#@ Displays data on Intuitive Circuits OSD-232 video overlay interface,
#@ so you can overlay text onto your TV screen.

use Display_osd232;

my $osd=new Display_osd232(PORT=>"/dev/osd232",SPEED=>"4800",FLIPRATE=>10);

if ($Startup) {
my $weatherpage=new Display_osd232page(PAGENAME=>"Weather",FLIPRATE=>20);
$weatherpage->addline("temptext",TEXT=>"Temp:",X=>1,Y=>1,TEXTCOLOR=>osdCLRyellow);
$weatherpage->addline("temp",TEXT=>"78",X=>8,Y=>1,TEXTCOLOR=>osdCLRwhite);
$weatherpage->addline("humiditytext",TEXT=>"Humi:",X=>16,Y=>1,TEXTCOLOR=>osdCLRyellow);
$weatherpage->addline("humidity",TEXT=>"63",X=>23,Y=>1,TEXTCOLOR=>osdCLRwhite);
$weatherpage->addline("raintext",TEXT=>"Rain:",X=>1,Y=>2,TEXTCOLOR=>osdCLRyellow);
$weatherpage->addline("rain",TEXT=>"00.00",X=>7,Y=>2,TEXTCOLOR=>osdCLRwhite);
$weatherpage->addline("windtext",TEXT=>"Wind:",X=>14,Y=>2,TEXTCOLOR=>osdCLRyellow);
$weatherpage->addline("wind",TEXT=>"105 NNW",X=>20,Y=>2,TEXTCOLOR=>osdCLRwhite);
$weatherpage->addline("alerttext",TEXT=>"Last alert:",X=>1,Y=>4,TEXTCOLOR=>osdCLRyellow);
$weatherpage->addline("alerttime",TEXT=>"Monday, 08/26/96  11:01 PM",X=>1,Y=>5,TEXTCOLOR=>osdCLRwhite);

my $securitypage=new Display_osd232page(PAGENAME=>"Security",FLIPRATE=>5);
$securitypage->addline("securitytext",TEXT=>"Last Security Event:",X=>1,Y=>1,TEXTCOLOR=>osdCLRyellow);
$securitypage->addline("security",TEXT=>"Cheryl armed AWAY",X=>1,Y=>2,TEXTCOLOR=>osdCLRwhite);
# more to come once OMNI interface working

my $phonepage=new Display_osd232page(PAGENAME=>"Phones");
$phonepage->addline("phonetext",TEXT=>"Last call:",X=>1,Y=>1,TEXTCOLOR=>osdCLRyellow);
$phonepage->addline("phone",TEXT=>"Brents cell phone",X=>1,Y=>2,TEXTCOLOR=>osdCLRwhite);
$phonepage->addline("phonetime",TEXT=>"07/07/05 11:31 AM",X=>1,Y=>3,TEXTCOLOR=>osdCLRwhite);
$phonepage->addline("vmtext",TEXT=>"Voicemail:",X=>1,Y=>5,TEXTCOLOR=>osdCLRyellow);
$phonepage->addline("voicemails",TEXT=>"6",X=>12,Y=>5,TEXTCOLOR=>osdCLRwhite);

my $miscpage=new Display_osd232page(PAGENAME=>"Misc");
$miscpage->addline("sunrisetext",TEXT=>"Sunrise:",X=>1,Y=>1,TEXTCOLOR=>osdCLRyellow);
$miscpage->addline("sunrise",TEXT=>$Time_Sunrise,X=>10,Y=>1,TEXTCOLOR=>osdCLRwhite);
$miscpage->addline("sunsettext",TEXT=>"Sunset:",X=>1,Y=>2,TEXTCOLOR=>osdCLRyellow);
$miscpage->addline("sunset",TEXT=>$Time_Sunset,X=>9,Y=>2,TEXTCOLOR=>osdCLRwhite);
$miscpage->addline("moonphasetext",TEXT=>"Moon Phase:",X=>1,Y=>4,TEXTCOLOR=>osdCLRcyan);
$miscpage->addline("moonphase",TEXT=>$Moon{phase},X=>1,Y=>5,TEXTCOLOR=>osdCLRwhite);
$miscpage->addline("moonbrighttext",TEXT=>"Moon Bright:",X=>1,Y=>6,TEXTCOLOR=>osdCLRcyan);
$miscpage->addline("moonbright",TEXT=>$Moon{brightness}." percent",X=>14,Y=>6,TEXTCOLOR=>osdCLRwhite);
$miscpage->addline("moonagetext",TEXT=>"Moon Age:",X=>1,Y=>7,TEXTCOLOR=>osdCLRcyan);
$miscpage->addline("moonage",TEXT=>$Moon{age}." days",X=>11,Y=>7,TEXTCOLOR=>osdCLRwhite);

$osd->addpage($weatherpage->pageref());
$osd->addpage($securitypage->pageref());
$osd->addpage($phonepage->pageref());
$osd->addpage($miscpage->pageref());

}

$v_osd_clear = new  Voice_Cmd('Clear the OSD232','');
if (said $v_osd_clear) {
	$osd->clearscreen();
}

$v_osd_weather = new  Voice_Cmd('Display the OSD232 weather page','');
if (said $v_osd_weather) {
	$osd->showpage("Weather");
}

$v_osd_security = new  Voice_Cmd('Display the OSD232 security page','');
if (said $v_osd_security) {
	$osd->showpage("Security");
}

$v_osd_phones = new  Voice_Cmd('Display the OSD232 phones page','');
if (said $v_osd_phones) {
	$osd->showpage("Phones");
}

$v_osd_misc = new  Voice_Cmd('Display the OSD232 misc page','');
if (said $v_osd_misc) {
	$osd->showpage("Misc");
}

$v_osd_flip = new  Voice_Cmd('Flip to next OSD232 page','');
if (said $v_osd_flip) {
	$osd->flippage();
}

if ($osd->{fliptimer}->expired()) {
	$osd->flippage();
}

$v_osd_init = new  Voice_Cmd('Initialize the OSD232','');
if (said $v_osd_init or $Startup) {
	print_log "Initializing osd232";
	$osd->reset();
	$osd->showpage("Weather");
	print_log "osd232 initialization complete";
	$osd->startflipping();
}
