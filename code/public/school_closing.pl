# Category=Informational

#@ Check for snow days ... thats when the Schools decide it is too
#@ cold or snowy to drive busses in, so they cancel school and
#@ let parents drive kids around to various sledding hills.

# Screen scrape the Rochester school status from the local radio web page

my $f_school_closing1 = "$config_parms{data_dir}/web/school_closing1.html";
my $f_school_closing2 = "$config_parms{data_dir}/web/school_closing2.html";
$v_school_closing = new Voice_Cmd 'Check for school closing';

# These 2 get_urls are run sequentially
$p_school_closing = new Process_Item
  "get_url http://www.kroc.com/kroc_fm/school_closings.php3 $f_school_closing1",
  "get_url http://www.kttc.com/closings.html                $f_school_closing2";

my ( $school_closing_prev1, $school_closing_prev2 );
if ( said $v_school_closing) {

    # Read old data, if > 1 day old
    $school_closing_prev1 = file_read $f_school_closing1
      if ( $Time - ( stat $f_school_closing1 )[9] > 3600 * 12 );
    $school_closing_prev2 = file_read $f_school_closing2
      if ( $Time - ( stat $f_school_closing2 )[9] > 3600 * 12 );
    unlink $f_school_closing1;
    unlink $f_school_closing2;
    start $p_school_closing;
    print_log 'Checking for school closing';
}

if ( done_now $p_school_closing) {
    my $html = file_read $f_school_closing1;

    #   print "db p=$school_closing_prev1 h=$html\n";
    if (
        $html ne $school_closing_prev1
        and

        #       $html =~ /Rochester Public.+?([^\=\"\/]+?.gif).+?<TD>(.*?)<\/TD>/si) {
        $html =~ /Rochester Public.+?([^\=\"\/]+?.gif)/si
      )
    {
        my $image  = $1;
        my $status = $2;

        # May not have text, so use gif
        unless ($status) {
            $status = lc $image;
            $status =~ s/school_//;
            $status =~ s/\.gif//;
        }
        if ( $status and $status !~ /on[ _]?time/ ) {
            speak
              "rooms=all Important school notice from K R O C. School status: $status";
            speak
              "rooms=all Important school notice from K R O C. School status: $status";
        }
        else {
            print_log "School status from KROC:  $image";
        }
    }
    else {
        print_log "Bad school closing data from KROC";
    }

    $html = file_read $f_school_closing2;
    if (    $html ne $school_closing_prev2
        and $html =~ /Rochester Public.+?<td.+?([^>]+)<\/font/si )
    {
        my $status = $1;
        chomp $status;
        if ($status) {
            speak
              "rooms=all Important school notice from K T T C.  School status: $status";
            speak
              "rooms=all Important school notice from K T T C.  School status: $status";
        }
    }

}

# KROC
# Rochester Public</b> ...                                                                              <TD>Closed for the Day</TD>
# Rochester Public</b></FONT></TD><TD valign=center><IMG src="images/school_ontime.gif" alt="On Time"></TD><TD></TD></TR>
# Rochester Public</b></FONT></TD><TD valign=center><IMG src="images/school_closed.gif" alt="Closed"></TD><TD></TD></TR>
#                                 <TD valign=center><IMG src="images/school_alert.gif" alt="Alert"></TD><TD>2 hours late</TD>

# KTTC
#Hollandale Christian
#</font></strong></td><td width="25%" align="left" bgcolor="FFF79C"><font size = "3" color="FF0000"><strong>Closed Today
#</font></strong></td>
#Lewiston-Altura Public
#</font></strong></td><td width="25%" align="left" bgcolor="FFF79C"><font size = "3" color="FF0000"><strong>2 Hour Delay
#</font></strong></td>
