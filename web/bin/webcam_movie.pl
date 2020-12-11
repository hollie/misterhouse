#
# Movie file generator
#
# v 0.00  Pete Flaherty	- initial concept
#
# generate a webcam Movie file for the directory passed in
# we sxpect an argument that is the path to the jpg files

my $movieDir = $ARGV[0];

chdir $config_parms{html_dir} . $config_parms{wc_slide_dir} . "/" . $movieDir;

my $html = "
<html><head>
<META HTTP-EQUIV='CACHE-CONTROL' CONTENT='NO-STORE'>
<script src='/bin/webcam_applet_data.pl?" . $movieDir . "'></script>
<script src='/cameras/wc_ss_functions.js'> </script>

</head>
<body bgcolor='#175169'>" . $movieDir . "


<script src='/cameras/wc_ss_circbuff.js'></script>
<CENTER>
<!-- <TABLE>
    <TR>
        <TD> -->
            <a href='javascript:gotoshow()'> <img name='slide' src='/cameras/images/cams-bg.jpg' border=0 width=640 height=480></a>
<br>
<!--        </TD>
    </TR>
    <TR>
        <TD ALIGN='center'> -->
<INPUT TYPE='submit' VALUE='Close Window' NAME='GOBACK' onClick='ssClose()')>&nbsp&nbsp

<INPUT TYPE='submit' VALUE='|<<' NAME='REWIND' alt='Back to begining' onClick='ssRewind()')>
<INPUT TYPE='submit' VALUE='<<<' NAME='BACKSK' alt='Go back 2 Buffers' onClick='ssSkBk2()  ')>
<INPUT TYPE='submit' VALUE='<<' NAME='BACKSK'  alt='Go to begining of Buffer' onClick='ssSkBack()  ')>
<INPUT TYPE='submit' VALUE='|<' NAME='BACK'    alt='Go back 1 frame' onClick='ssBack()  ')>
<INPUT TYPE='submit' VALUE='||' NAME='PAUSE'   alt='Pause' onClick='ssPause() ')>
<INPUT TYPE='submit' VALUE=' > ' NAME='PLAY'   alt='Play Normally' onClick='ssPlay()  ')>
<INPUT TYPE='submit' VALUE='>|' NAME='FRAME'   alt='Go Forward 1 Frame' onClick='ssFrame() ')>
<INPUT TYPE='submit' VALUE='>>' NAME='FAST'    alt='Go faster' onClick='ssFast()  ')>
<INPUT TYPE='submit' VALUE='>>>' NAME='SkFwd'    alt='Go to next Buffers worth' onClick='ssSkFwd()  ')>
<INPUT TYPE='submit' VALUE='>>|' NAME='END'    alt='Skip to last Buffer' onClick='ssEnd()  ')>

<!--            <SCRIPT SRC='/cameras/wc_ss_controls.js'></SCRIPT> -->
<!--        </TD>
    </TR>
    <TR>
        <TD id='PicLoad'> image info
        </TD>
    </TR>
</TABLE>
-->
</CENTER>

<SCRIPT SRC='/cameras/wc_ss_show.js'></SCRIPT>
</body>
<HEAD>
<META HTTP-EQUIV='CACHE-CONTROL' CONTENT='NO-STORE'>
</HEAD>
</html>
";

return $html;

