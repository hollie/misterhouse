# DSC5401_web.pl
#
# $Revision$
# $Date$

my $html = '';

$html .= qq[
<html>
<frameset rows="0%,100%"> 
  <frame name="status_frame" frameborder=0 noresize scrolling=none src="DSC5401_status.pl">
  <frame name="content_frame" frameborder=0 noresize scrolling=none src="DSC5401_web_content.pl">
</frameset>
</html>
];
return &html_page( '', $html );
