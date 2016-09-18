# Category=TV
#Note: Was tv_grid.pl
#modified to work with WinTV-PVR (http://www.hauppage.com)
#by Jeff Ferris (trackzero@track-zero.com)
#Last modified: 11/20/01

=begin comment

Original version: 11/4/01
Updates:	  11/20/01
			Removed requirement to kill running session using VB script.
			Process now terminated using cmdline arguments available with
			WinTV2K.exe
			
This module is for controlling the Hauppage WinTV PVR USB (and should work
with PCI version via MH...Started with tv_grid_pl and modified from there...

So far, it works for most functions the same as tv_grid.pl did...I can
click the VCR link in the TV grid, and it adds the proper command and
timing to record the given program...There are a couple of issues...

-Can't use tv_grid.pl and wintvpvr_grid.pl at the same time. 

-programs that run past the end of the program grid for the given time frame do not record completely 

-Programs that wrap days (start or end aftermidnight on the displayed grid page) don't quite work. The VCR link adds
it as the current date and an hour value past 24, which tanks the
functions I'm using. I've tried (unsuccessfully) to fix this with
program logic, but so far, not so good. ;) I've left the comments
in the code where I was working on this.

-Can't overlap programs. Withthe 1-min start-up time for wintvpvr, plus the 1-min tail I added so I'd
make sure to catch the end of the programs, this means we can't record back-to-back programs. 

-I drop things into the tv_grid_programming.pl file, just as tv_grid does.
Don't forget to clean out old programming now and again.

=cut

# Note: This $tv_grid is a special name, used by the get_tv_grid program.
#       Do not change it.
$tv_grid        = new Generic_Item();
$p_pvr_rec      = new Process_Item;
$v_kill_wintv32 = new Voice_Cmd('Kill WinTV PVR');
$p_kill_wintv32 = new Process_Item;
my $wintv_loc = "/progra~1/WinTV/WinTV2K.exe";
set $p_kill_wintv32 "$wintv_loc -mOff -nss";

# This item will be set whenever someone clicks on the 'set the vcr' link on the tv web page
if ( my $data = state_now $tv_grid) {

    # command line I need: C:\PROGRA~1\WinTV\WinTV2K.EXE  -c3 -ntod -startr:WinTV_(0)###.mpg -qvcd -limit:3600
    # so: runline = "$wintv_loc -c$channel -ntod -startr:$show_name###.mpg -qvcd -limit:(seconds time_diff{$stop - $start}+60)
    my ( $channel, $start, $stop, $date, $show_name ) =
      $data =~ /(\d+) from (\S+) to (\S+) on (\S+) for (.*)/;
    my ( $stop_hr,  $stop_min )  = $stop =~ /(\d+):(\d+)/;
    my ( $start_hr, $start_min ) = $start =~ /(\d+):(\d+)/;
    my $end_date = $date;

    unless ($start) {
        my $msg = "Bad tv_grid time: $data";
        speak $msg;
        print_log $msg;
        return;
    }

    my $msg =
      "Adding WinTV PVR schedule for $show_name.  Channel $channel from $start to $stop on $date.";
    speak $msg;
    print_log $msg;

    #calc seconds for show
    if ( $stop_hr gt '24' ) {
        $stop_hr = $stop_hr - 24;
        $stop    = "$stop_hr:$stop_min";

        #$date_dd = $date_mm - 1;
        #$end_date = "$date_mm\/$date_dd";
        #display "debug: stop = $stop, end date = $end_date";

    }

    if ( $start_hr gt '24' ) {
        $start_hr = $start_hr - 24;
        $start    = "$start_hr:$start_min";

        #$date_dd = $date_dd - 1;
        #$date = "$date_mm\/$date_dd" ;
        #not sure how to subtract 1 day...
        #display "debug: start = $start, $date";
    }

    my $showsecs =
      &my_str2time("$stop + 00:01") - &my_str2time("$start - 00:01");

    #display "debug: difference = $showsecs";

    $show_name = _clean_text_string("$show_name");
    my $WinTV_Cmdline =
      "$wintv_loc -c$channel -nss -ntod -startr:\\\"$show_name###.mpg\\\" -qvcd -limit:$showsecs";
    display "start: $start Commandline: $WinTV_Cmdline";
    print_log "Recording stopped" if done_now $p_pvr_rec;

    # Write out a new entry in the grid_programing.pl file
    #  - we could/should prune out old code here.
    my $tv_grid_file = "$config_parms{code_dir}/tv_grid_programing.pl";
    print_log "Writing to $tv_grid_file";
    open( TVGRID, ">>$tv_grid_file" )
      or print_log "Error in writing to $tv_grid_file";

    print TVGRID<<eof;
    
    #Start of Program
    if (time_now '$date $start - 00:02') {
        speak "rooms=all \$Time_Now. PVR recording will be started in 1 minute for $show_name";
        #kill any existing instance of WinTV32
        start \$p_kill_wintv32;
    }
    if (time_now '$date $start - 00:01') {
        speak "PVR recording on channel $channel for $show_name";
        set \$p_pvr_rec "$WinTV_Cmdline";
	print_log "starting $WinTV_Cmdline";
	start \$p_pvr_rec;
    }

    if (time_now '$end_date $stop + 00:02') {
        speak "PVR recording stopped for $show_name";
	start \$p_kill_wintv32;	
    }
    # End of Program
    
eof

    close TVGRID;

    &do_user_file($tv_grid_file);    # This will replace the old grid programing

}

if ( $state = said $v_kill_wintv32) {
    print_log "Killing WinTV32";
    start $p_kill_wintv32;
}

# This is what downloads tv data.  This needs to be forked/detatched, as it can take a while
$v_get_tv_grid_data1 = new Voice_Cmd('[Get,reget,redo] tv grid data for today');
$v_get_tv_grid_data7 =
  new Voice_Cmd('[Get,reget,redo] tv grid data for the next week');
$v_get_tv_grid_data1->set_info(
    'Updates the TV database with.  reget will reget html, redo re-uses.  Get will only reget or redo if the data is old.'
);
if ( $state = said $v_get_tv_grid_data1 or $state = said $v_get_tv_grid_data7) {
    if (&net_connect_check) {
        my $days = ( said $v_get_tv_grid_data7) ? 7 : 1;
        $state = ( $state eq 'Get' ) ? '' : "-$state";
        my $pgm =
          "get_tv_grid -zip $config_parms{zip_code} -provider $config_parms{tv_provider} $state -days $days";
        $pgm .= qq[ -hour  "$config_parms{tv_hours}"]
          if $config_parms{tv_hours};
        $pgm .= qq[ -label "$config_parms{tv_label}"]
          if $config_parms{tv_label};

        # Allow data to be stored wherever the alias points to
        $pgm .= qq[ -outdir "$1"]
          if $config_parms{html_alias_tv} =~ /\S+\s+(\S+)/;

        # If we have set the net_mail_send_account, send default web page via email
        my $mail_account = $config_parms{net_mail_send_account};
        my $mail_server =
          $main::config_parms{"net_mail_${mail_account}_server_send"};
        my $mail_to = $main::config_parms{"net_mail_${mail_account}_address"};
        if ( $mail_to and $mail_server ) {
            $pgm .= " -mail_to $mail_to -mail_server $mail_server ";
            $pgm .=
              " -mail_baseref $config_parms{http_server}:$config_parms{http_port} ";
        }

        run $pgm;
        print_log "TV grid update started";
    }
    else {
        speak "Sorry, you must be logged onto the net";
    }
}

# Set the default page to the current time
if ( time_cron "0 $config_parms{tv_hours} * * *" ) {
    my $tvfile = sprintf "%02d_%02d.html", $Mday, $Hour;
    my $tvdir = "$config_parms{html_dir}/tv";
    if ( -e "$tvdir/$tvfile" ) {
        copy "$tvdir/$tvfile", "$tvdir/index.html";

        #       my $tvhtml = file_read "$tvdir/$tvfile";
        #       file_write "$tvdir/index.html", $tvhtml;
    }
}

sub _clean_text_string {
    my ($dtext) = @_;

    #    $dtext = lc($dtext);
    $dtext =~ s/[:\s\?\\\/\*\"\<\>\|]/_/g;
    return $dtext;
}
