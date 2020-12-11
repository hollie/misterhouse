
# Category=Security

#@ This script is a reference holder to access the Webcam parameters
#@  <br>
#@  <br>These are the settings for the Webcams mh.ini:/mh.private.ini file

#@<table cellSpacing=0 cellPadding=2 border=1>
#@<tr><th>
#@</th><th>If these settings aren't in the mh.ini the default is the value shown BOLD</th></tr>
#@<tr><td>Max Cam windows</td><td>wc_max=<b>4</b> &nbsp total number of cameras</td></tr>
#@<tr><td>web address <br> for each cam [x]<br>up to wc_max</td>
#@  <td>wc_address_[x]=http://webcam.ip.address:PORT/dir/filename.jpg,DESCTIPTION<br>
#@  Description will be the text tag for the image frames<br>
#@  Cameras are numbered from 1 to whatever</td></tr>
#@<tr><td>Storage location for<br>webcam images</td><td>wc_slide_dir=<b>/cameras</b></td></tr>
#@</table>

my $wc_max = $config_parms{wc_max};

my $wc_address_1 = $config_parms{wc_address_1};
my $wc_address_2 = $config_parms{wc_address_2};
my $wc_address_3 = $config_parms{wc_address_3};
my $wc_address_4 = $config_parms{wc_address_4};

my $wc_slide_dir = $config_parms{wc_slide_dir};

#my $wc_bg_color		= $config_parms{wc_bg_color};
