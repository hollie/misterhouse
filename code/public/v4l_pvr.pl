# Category = PVR

=begin comment

v4l_pvr.pl 

06/30/2002 Created by David Norwood (dnorwood2@yahoo.com)
06/30/2003 added dbm of recorded shows so we don't re-record them, made record command configurable 

This script adds Personal Video Recorder (PVR) functionality to Misterhouse systems running Linux.  

Features: 

- Automatically records shows that match a list of keywords
- Records shows selected from the TV listings
- Uses divx4rec for recording, MPlayer for playback, and Xawtv for live TV 
- Basic web interface for specifying shows to record, watching recordings and live TV 

Requirements:

- misterhouse: http://www.misterhouse.net
- A TV tuner card supported by video4linux 
- Optionally, a video card with TVOUT capability
- A kernel that supports v4l1 or v4l2 and a driver for your card (probably bttv)
    RedHat 7.2 was sufficient for me, but you can get the latest here: http://bytesex.org/bttv/
- xawtv for watching live TV and changing channels: http://bytesex.org/xawtv/
- avifile: http://avifile.sourceforge.net/
- divx4linux: http://www.divx.com/
- nvrec: http://nvrec.sourceforge.net/
- mplayer for video playback: http://www.mplayerhq.hu/homepage/
- a2x for controlling X windows applications: http://www.cl.cam.ac.uk/a2x-voice/a2x-faq.html

Setup:

Install and configure all the above software.  Copy the following scripts into your misterhouse 
code directory.   

mh/code/public/v4l_pvr.pl 
mh/code/bruce/internet_logon.pl
mh/code/bruce/tv_info.pl

Delete tv_grid.pl from your code directory if you have it.

Set the following parameters in your private mh.ini file.  

pvr_video_dir=/bigdisk/videos             # optional, defaults to "$config_parms{data_dir}/videos"
pvr_record_opts=divx4rec -norm PAL        # override recording command, see default below 
html_select_length=9999                   # causes web interface to list commands separately 
zip_code=91360                            # go to http://tv.zap2it.com and enter your zip code...
tv_provider=296974                        # select your provider, click View Listings, code will be in URL
tv_hours=0,2,4,6,8,10,12,14,16,18,20,22   # ensures show database will be complete 

Restart misterhouse, browse to http://localhost:8080/mh4, and click on PVR.  

Problems: 

- need to make more configurable 
- videos don't contain index according to mplayer 
- zap2it show data only has half hour resolution 

=cut

my $video_dir = "$config_parms{data_dir}/videos";
my $outfile1  = "$config_parms{data_dir}/pvr_info1.txt";
my $outfile2  = "$config_parms{data_dir}/pvr_info2.txt";
my $dbm_file  = "$config_parms{data_dir}/pvr_recorded.dbm";

#my $logfile = "$config_parms{data_dir}/pvr_logfile.txt";
my $logfile = "/dev/null";
my $record_opts =
  'divx4rec -N 32 -d /dev/dsp -v /dev/video0 -mixsrc /dev/mixer:line -mixvol /dev/mixer:line:0 '
  . '-vq 25 -vg 10 -vb 3600 -w 384 -h 288 -norm NTSC -input Television ';

$v_livetv =
  new Voice_Cmd
  'Live TV [on,off,mute,volume down,volume up,channel down,channel up,'
  . 'record half hour,record hour,record 2 hours,2,11,31,38,41,44,46,54,64]';
$v_pvr =
  new Voice_Cmd
  'PVR [pause,quit,volume down,volume up,skip 10 seconds,skip minute,skip 10 minutes,'
  . 'back 10 seconds,back minute,back 10 minutes,cancel recording,debug]';
$t_pvr      = new Timer;
$p_pvr      = new Process_Item;
$f_pvr_file = new File_Item $outfile1;
my ( $db, %RECORDED, $state, $line, $pre, $filename, $key, $seconds, $frames );

if ($Reload) {
    $v_livetv->set_icon('nostat.gif');
    $v_pvr->set_icon('nostat.gif');
    $p_pvr->set_errlog($logfile);
    $record_opts = "$config_parms{pvr_record_opts}"
      if "$config_parms{pvr_record_opts}";
    $video_dir = "$config_parms{pvr_video_dir}"
      if "$config_parms{pvr_video_dir}";
    mkdir "$video_dir", 0777 unless -d "$video_dir";
    $db = tie( %RECORDED, 'DB_File', $dbm_file, O_RDWR | O_CREAT, 0666 )
      or print "\nError, can not open dbm file $dbm_file: $!";
    update_html();
}

if ( $state = said $v_livetv) {
    $key = "";
    if ( $state eq 'on' ) {

        #Audio::Mixer::set_cval('line', 40);
        system 'aumix -d /dev/mixer -l 100';
        run "killall xawtv; xawtv -f -display :0 setnorm ntsc";
        set $TV 'on';
        set $AMP 'on';
        set $TV 'video1';
        set $AMP 'vcr';
    }
    elsif ( $state =~ /^\d+$/ ) {
        $key = "setchannel $state";
    }
    elsif ( $state =~ /^record/ ) {
        $seconds = 60 * 30  if $state eq 'record half hour';
        $seconds = 60 * 60  if $state eq 'record hour';
        $seconds = 60 * 120 if $state eq 'record 2 hours';
        run "killall xawtv";
        my $title = time_date_stamp(3);
        pvr_record( $title, 0, $seconds );
    }
    elsif ( $state eq 'volume down' ) {

        #change_vol('vol', '-7');
        set $AMP 'vol-';
    }
    elsif ( $state eq 'volume up' ) {

        #change_vol('vol', '7');
        set $AMP 'vol+';
    }
    elsif ( $state eq 'off' )          { $key = 'quit' }
    elsif ( $state eq 'mute' )         { $key = 'volume mute' }
    elsif ( $state eq 'channel down' ) { $key = 'setchannel prev' }
    elsif ( $state eq 'channel up' )   { $key = 'setchannel next' }
    run "xawtv-remote -d :0 $key" if $key;
}

$quit_timer = new Timer;

if ( $state = said $v_pvr) {
    $key = "";
    if ( $state eq 'pause' ) { $key = 'p' }
    elsif ( $state eq 'quit' ) {
        if ( active $quit_timer) {
            set $TV 'off';
            set $AMP 'off';
        }
        set $quit_timer 5;
        $key = 'q';
    }
    elsif ( $state eq 'volume down' ) {

        #change_vol('vol', '-7');
        set $AMP 'vol-';
    }
    elsif ( $state eq 'volume up' ) {

        #change_vol('vol', '7');
        set $AMP 'vol+';
    }
    elsif ( $state eq 'cancel recording' ) {
        stop $p_pvr;
        update_html();
    }
    elsif ( $state eq 'debug' ) {
        foreach ( sort keys %RECORDED ) {
            print "$_\n";
        }
    }
    elsif ( $state eq 'skip 10 seconds' ) { $key = "\ctRight\ct" }
    elsif ( $state eq 'skip minute' )     { $key = "\ctUp\ct" }
    elsif ( $state eq 'skip 10 minutes' ) { $key = "\ctPrior\ct" }
    elsif ( $state eq 'back 10 seconds' ) { $key = "\ctLeft\ct" }
    elsif ( $state eq 'back minute' )     { $key = "\ctDown\ct" }
    elsif ( $state eq 'back 10 minutes' ) { $key = "\ctNext\ct" }
    run "echo $key | a2x" if $key;
}

# Check for favorite shows every 1/2 hour
if ( time_cron('0,30 * * * *') and $Save{pvr_shows} ) {
    my ( $min, $hour, $mday, $mon ) = ( localtime(time) )[ 1, 2, 3, 4 ];
    $mon++;
    run
      qq[get_tv_info -times $hour:$min -dates $mon/$mday -keys "$Save{pvr_shows}" -outfile1 $outfile1 -outfile2 $outfile2 -title_only];
    set_watch $f_pvr_file;
}

#Found 5 TV shows.                             5/17

#1.  A Pup Named scooby-Doo: Horror of the Haunted Hairpiece.  TOON Channel 30.  From 12:00 PM till 12:30 PM.
#(Children's) TVG CC

if ( $state = changed $f_pvr_file) {
    pvr_check();
}

sub pvr_check {
    my $summary      = read_head $f_pvr_file 6;
    my ($show_count) = $summary =~ /Found (\d+)/;
    my @data         = read_all $f_pvr_file;
    shift @data;    # Drop summary;
    foreach $line (@data) {
        $line =~ s/[,()']//g;
        if ( my ( $title, $channel, $start, $end ) =
            $line =~
            /^\d+\.\s+(.+)\.\s+\S+\s+Channel (\d+).+From ([0-9: APM]+) till ([0-9: APM]+)\./
          )
        {
            my $diff = my_time_diff( $start, $end );
            my $has_subtitle = $title =~ s/: +/-/g;
            if ($has_subtitle) {
                if ( $RECORDED{$title} ) {
                    print "$title has already been recorded, skipping \n";
                    next;
                }
            }
            else {
                $title .= '_' . time_date_stamp 6;
            }
            my $ret = pvr_record( $title, $channel, $diff );
            $RECORDED{$title} = $Time if $ret == 0 and $has_subtitle;
            print "RECORDED: ret $ret has $has_subtitle title $title \n";
            $db->sync;
            return
              if $ret == 0
              or $ret == 1;    # recording started okay or another is in process
        }
    }
}

sub pvr_record {
    my ( $title, $chan, $duration ) = @_;
    $title =~ s/ /_/g;
    $title =~ tr/',.;*$?!#//d;
    $title =~ s/\//-/g;
    $title =~ s/&/and/g;
    my $frames = $duration * 30;
    if ( -e "$video_dir/$title.avi" ) {
        print_log "$title already exists, skipping\n";
        return 4;
    }
    if ( !done $p_pvr) {
        my $remaining = minutes_remaining $t_pvr;
        if ( $remaining < 2 ) {
            print_log
              "Stopping previous recording with $remaining minutes remaining\n";
            stop $p_pvr;
        }
        else {
            print_log
              "Cannot record $title due to previous recording with $remaining minutes remaining\n";
            return 1;
        }
    }
    print_log "Recording - $title - channel $chan for $duration seconds.\n";
    if ($chan) {
        $pre = "v4lctl setchannel $chan";
        return 4 if $chan > 90;
    }
    else {
        $pre = "echo";
    }

    #Audio::Mixer::set_cval('line', 0);
    #Audio::Mixer::set_cval('rec', 20);
    #system 'aumix -d /dev/mixer -l 10 -l R';
    set $p_pvr $pre, "$record_opts -F $frames -o $video_dir/$title.avi";
    start $p_pvr if done $p_pvr;
    $filename = "$title.avi";
    set $t_pvr $duration;
    update_html();
    return 0;
}

if ( done_now $p_pvr) {
    update_html();
}

sub my_time_diff {
    my ( $s, $e ) = @_;
    my ( $sh, $sm, undef, $sp ) = $s =~ /(\d+):(\d+)( (.M))?/;
    my ( $eh, $em, undef, $ep ) = $e =~ /(\d+):(\d+)( (.M))?/;
    $sh = 0 if $sh == 12 and $sp;
    $eh = 0 if $eh == 12 and $ep;
    $sh += 12 if $sp eq 'PM';
    $eh += 12 if $ep eq 'PM';
    $eh += 24 if $sp eq 'PM' and $ep eq 'AM';
    return 60 * ( ( $eh * 60 + $em ) - ( $sh * 60 + $sm ) );
}

sub update_html {
    opendir VIDS, $video_dir;
    my @list = grep { !/^\./ && -f "$video_dir/$_" } readdir VIDS;
    closedir VIDS;
    $Included_HTML{PVR} = '<HEAD>

<SCRIPT LANGUAGE="JavaScript">
var keysPressed

function checkKey() {
  if (keysPressed) {
    keysPressed = keysPressed.replace("undefined", "")
    }
  if (keysPressed != String.fromCharCode(17) && keysPressed != String.fromCharCode(17) + String.fromCharCode(16) ) {
    // Make keysPressed nothing unless last keydown was CTRL
    keysPressed = ""
    }
  var ascCode = window.event.keyCode
  var pressed = String.fromCharCode(ascCode)
  var msg = "You pressed the " + pressed + " key (= " + ascCode + " in ASCII).  "
  msg = msg + "So far you have pressed   "
  keysPressed = keysPressed + pressed
  if (keysPressed) {
    msg = msg + keysPressed
    }
  // alert(msg)
  if (keysPressed == String.fromCharCode(17) + "D" ) {
  //   alert("You pressed CTRL+>.  I will try to activate your link.")
    location.href = "RUN;no_response?PVR_quit" // activate the link
    }
  if (keysPressed == String.fromCharCode(17) + String.fromCharCode(16) + String.fromCharCode(190) ) {
  //   alert("You pressed CTRL+>.  I will try to activate your link.")
    location.href = "RUN;no_response?PVR_skip_minute" // activate the link
    }
  }
</SCRIPT>

</HEAD>

<BODY onKeyDown="checkKey()">




<table border=0 cellspacing=0 cellpadding=8><tr><td rowspan=2 valign=top>
      <b>Previously recorded videos</b><spacer height=20><br>';
    foreach ( sort @list ) {
        my $file = $_;
        my $link = $_;
        $link =~ s/ /%20/g;
        $Included_HTML{PVR} .=
            '<a target="control" href="SUB;referer?delete_video('
          . $link
          . ')">Delete</a>&nbsp&nbsp'
          . '<a href="SUB;play_video('
          . $link . ')">'
          . $file
          . '</a><br>';
    }
    $Included_HTML{PVR} .= 'none' unless @list;
    $Included_HTML{PVR} .= '</td><td valign=top>
      <b>Shows to record automatically</b><spacer height=20><br>
      <table border=0 cellspacing=2 cellpadding=0><tr><td rowspan=2>
      <form action="SET;referer" target="control" name=fm><select name="$pvr_list" size="15">'
      . "\n";
    my $i = 0;
    foreach ( split ',', $Save{pvr_shows} ) {
        $Included_HTML{PVR} .=
            '<option value="'
          . $i++ . '">'
          . $_
          . "&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp\n";
    }
    $Included_HTML{PVR} .= '</select></td><td valign=top>
      <input type=image name=$pvr_up src=/graphics/up.gif width=16 height=16 border=0 alt="Up" vspace=2>
      &nbsp&nbsp<input value="" size="30" name=$pvr_text> <input type=submit value="Add" name=$pvr_add><br>
      <input type=image name=$pvr_dn src=/graphics/dn.gif width=16 height=16 border=0 alt="Down" vspace=2></td></tr><tr><td valign=bottom>
      <input type=image name=$pvr_x src=/graphics/x.gif width=16 height=16 border=0 alt="Delete">
      <br><spacer height=20><br></td></tr></table>
      <b>Remaining disk space</b>&nbsp&nbsp' . &disk_space . '<br>
      <b>PVR Status</b>&nbsp&nbsp' . &pvr_stat . '&nbsp&nbsp&nbsp
      <a target="control" href="SUB;referer?update_html()">Refresh</a><br>
      <a target="_BLANK" href="/tv">TV Listings</a><p>
      </td></tr></table></form>' . "\n";
    return 0;
}

$pvr_list = new Generic_Item;
$pvr_up_x = new Generic_Item;
$pvr_up_y = new Generic_Item;
$pvr_dn_x = new Generic_Item;
$pvr_dn_y = new Generic_Item;
$pvr_x_x  = new Generic_Item;
$pvr_x_y  = new Generic_Item;
$pvr_add  = new Generic_Item;
$pvr_text = new Generic_Item;

if ( state_now $pvr_up_x =~ /\d/ ) {
    my $show = state $pvr_list;
    return unless $show;
    my @shows = split ',', $Save{pvr_shows};
    my $tmp = $shows[$show];
    $shows[$show] = $shows[ $show - 1 ];
    $shows[ $show - 1 ] = $tmp;
    $Save{pvr_shows} = join ',', (@shows);
    update_html();
}

if ( state_now $pvr_dn_x =~ /\d/ ) {
    my $show = state $pvr_list;
    my @shows = split ',', $Save{pvr_shows};
    return if $show > @shows;
    my $tmp = $shows[$show];
    $shows[$show] = $shows[ $show + 1 ];
    $shows[ $show + 1 ] = $tmp;
    $Save{pvr_shows} = join ',', (@shows);
    update_html();
}

if ( state_now $pvr_x_x =~ /\d/ ) {
    my $show = state $pvr_list;
    my @shows = split ',', $Save{pvr_shows};
    splice @shows, $show, 1;
    $Save{pvr_shows} = join ',', (@shows);
    update_html();
}

if ( state_now $pvr_add) {
    my $show = state $pvr_text;
    return unless $show;
    $Save{pvr_shows} .= ',' . $show;
    update_html();
}

sub play_video {
    my $file = shift;
    print_log "Playing $file\n";

    #Audio::Mixer::set_cval('pcm', 80);
    system 'aumix -d /dev/mixer -l 0 -w 80 -v 100';

    #    run "killall -s 9 mplayer; killall xawtv; mplayer -fs -ao oss:/dev/dsp1 -quiet '$video_dir/$file'";
    run
      "killall -s 9 mplayer; killall xawtv; mplayer -fs -ao oss:/dev/dsp -quiet -idx '$video_dir/$file'";
    set $TV 'on';
    set $AMP 'on';
    set $TV 'video1';
    set $AMP 'vcr';
}

sub delete_video {
    my $file = shift;
    print_log "Deleting $file\n";
    unlink "$video_dir/$file";
    update_html();
}

sub change_vol {
    my ( $ctrl, $change ) = @_;
    my @vol             = Audio::Mixer::get_cval($ctrl);
    my $volume_previous = ( $vol[0] + $vol[1] ) / 2;
    Audio::Mixer::set_cval( $ctrl, $volume_previous + $change );
}

sub disk_space {
    open DF, "df $video_dir |";
    my $line = <DF>;
    $line = <DF>;
    close DF;
    my ($kb) = $line =~ /^\S+\s+\S+\s+\S+\s+(\S+)/;
    return sprintf( "%.1F GB", $kb / 1024**2 ) if $kb > 1024**2;
    return sprintf( "%.1F MB", $kb / 1024 )    if $kb > 1024;
    return sprintf( "%.1F KB", $kb );
}

sub pvr_stat {
    return 'Idle' if done $p_pvr;
    return
        "Recording $filename with "
      . $t_pvr->minutes_remaining
      . " minutes remaining";
}

# The rest of this code is taken from tv_grid.pl

# Note: This $tv_grid is a special name, used by the get_tv_grid program.
#       Do not change it.
$tv_grid = new Generic_Item();

# This item will be set whenever someone clicks on the 'set the vcr' link on the tv web page
if ( my $data = state_now $tv_grid) {

    # http://house:8080/SET?$tv_grid?channel_2_from_7:00_to_8:00

    my ( $channel, $start, $stop, $date, $show_name ) =
      $data =~ /(\d+) from (\S+) to (\S+) on (\S+) for (.*)/;

    unless ($start) {
        my $msg = "Bad tv_grid time: $data";
        speak $msg;
        print_log $msg;
        return;
    }

    my $has_subtitle = $show_name =~ s/: */-/g;
    $show_name .= '_' . time_date_stamp 6 unless $has_subtitle;
    $show_name =~ s/&/and/g;
    $show_name =~ s/[\'\,\.\;\*\$\?\!\#\/]//g;
    my $msg =
      "Scheduling recording of $show_name.  Channel $channel from $start to $stop on $date.";
    speak $msg;
    print_log $msg;

    &trigger_set( "time_now '$date $start'",
        "pvr_record('$show_name', $channel, my_time_diff('$start', '$stop'))" );

}

# This is what downloads tv data.  This needs to be forked/detatched, as it can take a while
$v_get_tv_grid_data1 = new Voice_Cmd('[Get,reget,redo] tv grid data for today');
$v_get_tv_grid_data7 =
  new Voice_Cmd('[Get,reget,redo] tv grid data for the next week');
$v_get_tv_grid_data1->set_icon('nostat.gif');
$v_get_tv_grid_data1->set_info(
    'Updates the TV database with.  reget will reget html, redo re-uses.  Get will only reget or redo if the data is old.'
);
$v_get_tv_grid_data7->set_icon('nostat.gif');
$v_get_tv_grid_data7->set_info(
    'Updates the TV database with.  reget will reget html, redo re-uses.  Get will only reget or redo if the data is old.'
);
if ( $state = said $v_get_tv_grid_data1 or $state = said $v_get_tv_grid_data7) {

    if (&net_connect_check) {
        my $days = ( said $v_get_tv_grid_data7) ? 7 : 1;
        $state = ( $state eq 'Get' ) ? '' : "-$state";

        # Call with -db sat to use sat_* parms instead of tv_* parms
        my $pgm = "get_tv_grid -db tv $state -days $days ";

        #        my $pgm = "get_tv_grid -preserveraw -debug -db tv $state -hour 12";

        # Allow data to be stored wherever the alias points to
        my $tvdir = "$config_parms{html_dir}/tv";
        $tvdir = &html_alias('tv') if &html_alias('tv');
        $pgm .= qq[ -outdir "$tvdir"] if $tvdir;

        # If we have set the net_mail_send_account, send default web page via email
        my $mail_account = $config_parms{net_mail_send_account};
        my $mail_server =
          $main::config_parms{"net_mail_${mail_account}_server_send"};
        my $mail_to = $main::config_parms{"net_mail_${mail_account}_address"};
        if (    $mail_to
            and $mail_server
            and $main::config_parms{"tv_email_grids"} )
        {
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
# Check it a few minutes prior to the hour
#f (time_cron "0 $config_parms{tv_hours} * * *") {
if ( time_cron "50 * * * *" ) {
    my ( $hour, $mday ) = ( localtime( time + 600 ) )[ 2, 3 ];
    my $tvfile = sprintf "%02d_%02d.html", $mday, $hour;
    my $tvdir = "$config_parms{html_dir}/tv";
    $tvdir = &html_alias('tv') if &html_alias('tv');
    if ( -e "$tvdir/$tvfile" ) {
        print_log "Updating TV index page with $tvfile";
        copy "$tvdir/$tvfile", "$tvdir/index.html";
    }
}
