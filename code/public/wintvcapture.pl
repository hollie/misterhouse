# Category= Security

=begin comment
This program illustrates the use of sendkeys to control a program (WinTV32) and capture TV pictures
 from a Hauppage WinTV card. Sendkeys creates the equivalent of keyboard presses for a 
running program. Most Windows show valid key commands with an underlined or bold letter 
in the dropdown menus. Otherwise you can systematicly try every key, including shift, alt,
 and control versions to see what they do. There are often hidden features.
To send eg "alt f" you send "alt" then "f" then deactivate " alt" with "alt-". But to send "alt" 
rather than "a", "l", "t", you send \alt\. But \ is a special character so it has to be
 escaped with \, so you actually send \\alt\\. phew!
The original program by Jeff Pagel captures pictures and files them under date and time. The bits 
of that are commented out. 
My cheat to speed it up just gets the picture into a holding file in \ia5\security\images by first
manually saving a picture there in WinTV32 so that the program remembers that location. Then
I changed the <img> tag in ia5\security\main.shtml to
<img src="images/Q.jpg" > so the security web page displays it.
Bazyle Butcher.
=cut

$v_CaptureWinTv32 = new Voice_Cmd("Capture Camera");

if ( said $v_CaptureWinTv32) {
    &CaptureWinTv32;
}

# -------------------------------------------------------
sub CaptureWinTv32 {
    speak "start capture";

    #my $string1 = '\\ALT\\f\\ALT-\\a\\ALT\\t\\ALT-\\j\\ALT\\n\\ALT-\\';
    #my $FileName = sprintf("Car_%s_%2.2i__%2.2i_%2.2i_%2.2i",$Year_Month_Now, substr($Date_Now, 9, 2), $Hour, $Minute, $Second);
    #my $FileName = "frontdoorcam";
    #my $string2 = '\\TAB\\\\TAB\\\\TAB\\\\TAB\\\\TAB\\\\TAB\\\\TAB\\90';
    my $string1  = '\\ALT\\f\\ALT-\\a';
    my $string3  = '\\ALT\\s\\ALT-\\';
    my $FileName = "Q";                   # long names are slow

    my $KeyCommand = $string1 . $FileName . $string3;

    #my $KeyCommand = $string1.$FileName.$string2.$string3; # building command like this is versatile
    # WinTV32 must be running, but you can minimise it
    if ( my $window = &sendkeys_find_window( 'WinTV32', 'WinTV32' ) ) {
        &SendKeys( $window, $KeyCommand, 0, 300 )
          ;    # the 300 is a delay between key to give the program time,

        #adjust for your CPU speed, I'm running 1500MHz. Start with a bigger number to see how it works
        print_log "Picture captured";
    }

    #  my $SourcePath = 'c:\mh\mh\web\images\\'.$FileName.".jpg";
    #  my $DestPath = 'E:\mh\data\proxy\carftp\\'.$FileName.".jpg";

    #  print_log "CarCam SourcePath: $SourcePath";
    # print_log "CarCam DestPath: $DestPath";

    #  my $rc = copy("$SourcePath", "$DestPath") or print_log "Error copying carcam to proxy: $!";
    # print_log "CarCam copy results: $rc";
}    #end of sub
