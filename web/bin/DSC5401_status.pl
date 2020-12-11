# DSC5401_status.pl
#
# $Revision$
# $Date$

my $html = qq[
<html>
<script language="JavaScript" type="text/JavaScript">
<!--
function setBullets() {

content=parent.content_frame.document;

if (content.images.length == 0) {
  // content frame hasn't been loaded yet
  return;
}
];

my @name = DSC5401->ZoneName;
my $size = scalar(@name) - 1;

$html .= qq[
];
for ( 1 .. $size ) {
    if ( $name[$_] ) {
        $html .= qq{content.images["ZONE_$_"].src="};
        my $status = $DSC->{zone_status}{$_};
        if ( $status eq 'restored' ) {
            $html .= '/graphics/green_bullet.gif';
        }
        else {
            $html .= '/graphics/red_bullet.gif';
        }
        $html .= qq[";\n];
    }
}
$html .= qq[
}

function doInit() {
setBullets();
setTimeout("doTimer()",2000);
}

function doTimer() {
location.href="DSC5401_status.pl";
}
-->
</script>
<body onload="doInit()">
</body>
</html>
];

return &html_page( '', $html );

