# Category=Network

#@ AzInfo v1.42 Azureus Bit Torrent Client monitor and notification
#@ This reads the Azureus 'stats file' to detemine status and
#@ progress of torrent file downloads
#@ Add these entries to your mh.ini file:
#@ azinfo_file = (path to stats file)
#@ azinfo_progress = number of times to annouce a file's progress.
#@   (ie 4 notifies at every 25% completion) Set to 0 for no progress updates
#@ azinfo_webgui = 1 (if html web control is installed)
#@ azinfo_webgui_ip = ip address of azureus
#@ azinfo_webgui_port = port of webgui

##  1.20 released version
##  1.30 updated to fix 'unable to recognise encoding of this document' errors with
##       Azureus 2.3.0.6. Added error checking to XMLin
##  1.31 updated to remove WARNING messages when azureus is idle
##  1.40 added control for HTML WebGUI
##  1.41 tweaked HTML WebGUI webcontrol options
##  1.42 removed debug output

=begin comment
For this to work, Azureus has to write out stats information. This can be enabled by;
 Tools->Options, then on the options page select the Statistics option, and enable.
 I use /tmp as the save directory, no XSL file name, frequency of 1 minute, and no
 'export peer details' option.

Another useful feature is if you also configure Azureus to monitor a file location
 for adding new torrent files. This way, Azureus can be run on the server, new torrent
 files can be dropped into a shared directory, and azinfo to monitor progress.

This module was tested with Azureus 2.3.0.2 to 2.3.0.6

todo: - when the last torrent is removed, the xml does not have any download information
	for the script to process. So then a single torrent is removed, and azureus is idle,
	the script does not progress far enough to remove the last torrent from memory.
      - When Azureus shuts down it doesnt clean out its stats file, so azinfo still thinks
	things are running when they are actually not. Fixed this locally by modifying my
	azureus script to delete the file on program exit.

=cut

use XML::Simple;
use Data::Dumper;
my $az_debug = 0;

if ( ($Startup) or ($Reload) ) {

    use vars qw(%active_torrents);
    %active_torrents = ();

    if ( $config_parms{azinfo_progress} ) {
        my $tmp = 100 / $config_parms{azinfo_progress};
        print_log "AzInfo: v1.42 loaded with notification at $tmp%";
    }
    else {
        print_log "AzInfo: v1.42 loaded with notifications disabled";
    }
    print "AzInfo Debug Mode active\n" if $az_debug;
    print Dumper(%active_torrents) if $az_debug;
}

if (    ( -f $config_parms{azinfo_file} )
    and ( file_changed $config_parms{azinfo_file} ) )
{

    # Run this in an eval loop since sometimes XMLin errors out reading azureus stats file
    my $ref =
      eval { XMLin( $config_parms{azinfo_file}, forcearray => ['DOWNLOAD'] ); };
    print_log "AzInfo: WARNING: Problem parsing Azureus Stats XML: $@" if ($@);

    # Get status on all active torrents. Notify when done, high hash errors, and at each 10%
    # completion status.
    #
    # If defined then run through loop, otherwise exit out.

    if ( not defined @{ $ref->{DOWNLOADS}->{DOWNLOAD} } ) {
        my @tmp_acn =
          keys %active_torrents;  #only print error if there are active torrents
        print_log
          "AzInfo: WARNING: Torrent array undefined! ($#tmp_acn active torrents)"
          if ( $#tmp_acn >= 1 );
    }
    else {

        foreach my $torrent ( @{ $ref->{DOWNLOADS}->{DOWNLOAD} } ) {
            print
              "DB: $Time_Now Looking for $torrent->{TORRENT}->{HASH}=$active_torrents{$torrent->{TORRENT}->{HASH}}->{NAME}\n"
              if $az_debug;
            print Dumper(%active_torrents) if $az_debug;
            unless (
                defined $active_torrents{ $torrent->{TORRENT}->{HASH} }->{NAME}
              )
            {
                print_log
                  "Torrent: New torrent $torrent->{TORRENT}->{NAME} added.";
                my ($t_notify) =
                  split( /[\.' '_]/, $torrent->{TORRENT}->{NAME} );
                speak( rooms => "all", text => "Download $t_notify started" );
                $active_torrents{ $torrent->{TORRENT}->{HASH} } = {
                    "FLAG"            => 2,
                    "DOWNLOAD_STATUS" => $torrent->{DOWNLOAD_STATUS},
                    "NAME"            => $torrent->{TORRENT}->{NAME},
                    "HASH_ERR"        => 0,
                    "COMPLETION"      => 0
                };

            }
            else {
                print
                  "DB: $Time_Now Updating $torrent->{TORRENT}->{HASH}=$active_torrents{$torrent->{TORRENT}->{HASH}}->{NAME}\n"
                  if $az_debug;
                $active_torrents{ $torrent->{TORRENT}->{HASH} }->{FLAG} = 2;
                unless ( $active_torrents{ $torrent->{TORRENT}->{HASH} }
                    ->{DOWNLOAD_STATUS} eq $torrent->{DOWNLOAD_STATUS} )
                {
                    print_log
                      "Torrent: $torrent->{TORRENT}->{NAME} Changed status to $torrent->{DOWNLOAD_STATUS}";
                    if ( $torrent->{DOWNLOAD_STATUS} eq 'Seeding' ) {
                        my ($t_notify) =
                          split( /[\.' '_]/, $torrent->{TORRENT}->{NAME} );
                        print_log
                          "Torrent: $torrent->{TORRENT}->{NAME} completed at $Time_Now";
                        speak(
                            rooms => "all",
                            text  => "Download $t_notify completed"
                        );
                    }
                    $active_torrents{ $torrent->{TORRENT}->{HASH} }
                      ->{DOWNLOAD_STATUS} = $torrent->{DOWNLOAD_STATUS};
                }

                #-------------------------------------------------------
                # Test area for active torrents
                if ( ( $torrent->{HASH_FAILS} > 50 )
                    and
                    !$active_torrents{ $torrent->{TORRENT}->{HASH} }->{HASH_ERR}
                  )
                {
                    $active_torrents{ $torrent->{TORRENT}->{HASH} }->{HASH_ERR}
                      = 1;
                    print_log
                      "Torrent: Warning! $torrent->{TORRENT}->{NAME} has more than 50 hash errors!";
                    my ($t_notify) =
                      split( /[\.' '_]/, $torrent->{TORRENT}->{NAME} );
                    speak(
                        rooms => "all",
                        text => "Download $t_notify has a high number of errors"
                    );
                }

                if ( $config_parms{azinfo_progress} ) {
                    my $t_completed = sprintf(
                        "%.1f",
                        (
                            (
                                $torrent->{DOWNLOADED}->{RAW} -
                                  $torrent->{DISCARDED}->{RAW} -
                                  (
                                    $torrent->{HASH_FAILS} *
                                      $torrent->{TORRENT}->{PIECE_LENGTH}
                                  )
                            ) / $torrent->{TORRENT}->{SIZE}->{RAW}
                        ) * $config_parms{azinfo_progress}
                    );
                    if (
                        int($t_completed) !=
                        $active_torrents{ $torrent->{TORRENT}->{HASH} }
                        ->{COMPLETION} )
                    {
                        my $t_save =
                          $active_torrents{ $torrent->{TORRENT}->{HASH} }
                          ->{COMPLETION} * $config_parms{azinfo_file};
                        $active_torrents{ $torrent->{TORRENT}->{HASH} }
                          ->{COMPLETION} = int($t_completed);
                        my $t_db = $t_completed;
                        $t_completed = $t_completed *
                          ( 100 / $config_parms{azinfo_progress} );
                        print_log
                          "Torrent: $torrent->{TORRENT}->{NAME} now at $t_completed%";
                        my ($t_notify) =
                          split( /[\.' '_]/, $torrent->{TORRENT}->{NAME} );
                        speak(
                            rooms => "all",
                            text =>
                              "Download $t_notify now at $t_completed percent"
                        ) if ( $t_completed < 100 );
                    }
                }

                #-------------------------------------------------------

            }
        }

        while ( my $hash = each %active_torrents ) {
            print
              "DB: $Time_Now Checking for removal $hash=$active_torrents{$hash}->{NAME}\n"
              if $az_debug;
            if ( $active_torrents{$hash}->{FLAG} == 0 ) {
                print_log
                  "Torrent: $active_torrents{$hash}->{NAME} Has been removed";
                delete $active_torrents{$hash};
                print Dumper(%active_torrents) if $az_debug;
            }
            else {
                $active_torrents{$hash}->{FLAG}--;
                print
                  "DB: $Time_Now Found $hash=$active_torrents{$hash}->{NAME} flag=$active_torrents{$hash}->{FLAG}\n"
                  if $az_debug;

            }
        }
    }
}    # End of Monitor Code

sub web_torrents {

    my $html_dl_hdr    = ();
    my $html_dl_data   = ();
    my $html_seed_hdr  = ();
    my $html_seed_data = ();
    my $html_footer    = ();
    my $tor_dl         = 0;
    my $tor_seed       = 0;
    my $name_length =
      45;    ## Limited to 45 characters to display nice on the Audrey's

    #if file doesn't exist print error, else
    if ( not( -f $config_parms{azinfo_file} ) ) {
        my $html = "<html>
<head>
<style>
TR.wvtrow {font-family:Arial; font-size:11; color:#000000}
TR.wvtheader {font-family:Tahoma; font-size:11; color:#101010}
</style>
</head>
<body>" . &html_header("Error: Azureus not installed or running!");
        $html .= "</body>";
        my $html_page = &html_page( '', $html );
        return &html_page( '', $html );
    }

    my $ref =
      eval { XMLin( $config_parms{azinfo_file}, forcearray => ['DOWNLOAD'] ); };
    if ($@) {
        print_log "AzInfo_Web: ERROR: Problem parsing Azureus Stats XML:$@";
        my $html = "<html>
<head>
<style>
TR.wvtrow {font-family:Arial; font-size:11; color:#000000}
TR.wvtheader {font-family:Tahoma; font-size:11; color:#101010}
</style>
</head>
<body>"
          . &html_header(
            "Error: Temporary problem reading stats file. Try again");
        $html .= "</body>";
        my $html_page = &html_page( '', $html );
        return &html_page( '', $html );
    }

    foreach my $torrent ( @{ $ref->{DOWNLOADS}->{DOWNLOAD} } ) {

        if ( $torrent->{DOWNLOAD_STATUS} eq 'Seeding' ) {
            $tor_seed++;
            $html_seed_data .=
              "<tr id='resultrow' vAlign=center bgcolor='#EEEEEE' class='wvtrow'>\n";
            my $t_name = sprintf( "%-30s", $torrent->{TORRENT}->{NAME} );
            $html_seed_data .= "<td nowrap>$t_name</td>";
            $html_seed_data .=
              "<td nowrap>$torrent->{UPLOAD_SPEED}->{TEXT}</td><tr>\n";
        }

        else {
            $tor_dl++;
            $html_dl_data .= "<tr id='resultrow' vAlign=center ";
            if ( $torrent->{TRACKER_STATUS} eq "OK" ) {
                $html_dl_data .= "bgcolor='#EEEEEE'";
            }
            else {
                $html_dl_data .= "bgcolor='#FFCC00'";
            }

            $html_dl_data .= " class='wvtrow'>";

            my $t_name = $torrent->{TORRENT}->{NAME};
            if ( length( $torrent->{TORRENT}->{NAME} ) > $name_length ) {
                $t_name = substr( $torrent->{TORRENT}->{NAME}, 0,
                    ( $name_length - 3 ) );
                $t_name .= "...";
            }
            my $t_completed = sprintf(
                "%.1f%",
                (
                    (
                        $torrent->{DOWNLOADED}->{RAW} -
                          $torrent->{DISCARDED}->{RAW} -
                          (
                            $torrent->{HASH_FAILS} *
                              $torrent->{TORRENT}->{PIECE_LENGTH}
                          )
                    ) / $torrent->{TORRENT}->{SIZE}->{RAW}
                ) * 100
            );

            $html_dl_data .=
              "<td nowrap><a href=\"SUB?web_torrent_details($torrent->{TORRENT}->{HASH})\">$t_name</a></td>";

            if ( $torrent->{DOWNLOAD_STATUS} =~ m/downloading/i ) {
                if ( $torrent->{ETA} eq chr(0x221e) )
                {    ##www1.tip.nl/~t876506/utf8tbl.html
                    $html_dl_data .= "<td nowrap><i>tbd</i></td>";
                }
                else {
                    $html_dl_data .= "<td nowrap>$torrent->{ETA}</td>";
                }
            }
            else {    #Problem with torrent, not downloading
                $html_dl_data .= "<td nowrap>$torrent->{DOWNLOAD_STATUS}</td>";
            }
            $html_dl_data .= "<td nowrap>$t_completed</td>";
            $html_dl_data .=
              "<td nowrap>$torrent->{DOWNLOAD_SPEED}->{TEXT}</td>";
            $html_dl_data .= "</tr>\n";
        }
    }

    if ( $tor_dl == 1 ) {
        $html_dl_hdr = &html_header("1 Active Torrent");
    }
    else {
        $html_dl_hdr = &html_header("$tor_dl Active Torrents");
    }

    if ( $tor_seed == 1 ) {
        $html_seed_hdr = &html_header("1 Torrent Seeding");
    }
    else {
        $html_seed_hdr = &html_header("$tor_seed Torrents Seeding");
    }

    $html_seed_hdr .=
      "<table width=100% cellspacing=2><tbody><font face=COURIER size=2><tr id='resultrow' bgcolor='#9999CC' class='wvtheader'><th align='left'>Name";
    if ( $config_parms{azinfo_webgui} ) {
        $html_seed_hdr .=
          "  <a href=\"SUB;referer?web_torrent_control(seeds,startall)\">( START ALL )</a>   ";
        $html_seed_hdr .=
          "  <a href=\"SUB;referer?web_torrent_control(seeds,stopall)\">( STOP ALL )</a>   ";
    }
    $html_seed_hdr .= "</th><th align='left'>Upload Speed</th>";

    my $az_ver = $ref->{AZUREUS_VERSION};
    my $az_gdl = $ref->{GLOBAL}->{DOWNLOAD_SPEED}->{TEXT};
    my $az_gul = $ref->{GLOBAL}->{UPLOAD_SPEED}->{TEXT};
    my $html   = "<html>
<head>
<style>
TR.wvtrow {font-family:Arial; font-size:11; color:#000000}
TR.wvtheader {font-family:Tahoma; font-size:11; color:#101010}
</style>
</head>
<body>" . &html_header("Azureus ($az_ver) Downloads");

    $html .= $html_dl_hdr;

    if ( $tor_dl > 0 ) {
        $html .=
          "<table width=100% cellspacing=2><tbody><font face=COURIER size=2><tr id='resultrow' bgcolor='#9999CC' class='wvtheader'><th align='left'>Name";
        if ( $config_parms{azinfo_webgui} ) {
            $html .=
              "  <a href=\"SUB;no_response?web_torrent_control(downloads,startall)\">( START ALL )</a>   ";
            $html .=
              "  <a href=\"SUB;no_response?web_torrent_control(downloads,stopall)\">( STOP ALL )</a>   ";
        }
        $html .=
          "</th><th align='left'>ETA</th><th align='left'>Completed</th><th align='left'>Download Speed</th>";
        $html .= $html_dl_data;
    }

    if ( $tor_seed > 0 ) {
        $html .= "<BR>" . $html_seed_hdr . $html_seed_data;
    }

    if ( ( $tor_seed > 0 ) or ( $tor_dl > 0 ) ) {
        $html .= &html_header("Downloading:$az_gdl      Uploading:$az_gul");
    }

    $html .= "</body>";

## print $html;
    my $html_page = &html_page( '', $html );
    return &html_page( '', $html );

}

sub web_torrent_details {

    my $html_data = ();
    my ($hash)    = @_;
    my $found     = 0;

##print "db: arg=$hash";

    if ( not( -f $config_parms{azinfo_file} ) ) {
        my $html = "<html>
<head>
<style>
TR.wvtrow {font-family:Arial; font-size:11; color:#000000}
TR.wvtheader {font-family:Tahoma; font-size:11; color:#101010}
</style>
</head>
<body>" . &html_header("Error: Azureus not installed or running!");
        $html .= "</body>";
        my $html_page = &html_page( '', $html );
        return &html_page( '', $html );
    }

    my $ref = eval {
        XMLin(
            $config_parms{azinfo_file},
            forcearray    => ['DOWNLOAD'],
            suppressempty => undef
        );
    };
    if ($@) {
        print_log "AzInfo_Web: ERROR: Problem parsing Azureus Stats XML:$@";
        my $html = "<html>
<head>
<style>
TR.wvtrow {font-family:Arial; font-size:11; color:#000000}
TR.wvtheader {font-family:Tahoma; font-size:11; color:#101010}
</style>
</head>
<body>"
          . &html_header(
            "Error: Temporary problem reading stats file. Try again");
        $html .= "</body>";
        my $html_page = &html_page( '', $html );
        return &html_page( '', $html );
    }

    foreach my $torrent ( @{ $ref->{DOWNLOADS}->{DOWNLOAD} } ) {

        if ( $torrent->{TORRENT}->{HASH} eq $hash ) {
            my $tor_name = $torrent->{TORRENT}->{NAME};
            $found = 1;

## Header
            $html_data = &html_header("Details for: $tor_name ");

## Transfer
            $html_data .=
              "<table width=100% cellspacing=2><tbody><font face=COURIER size=2><tr id='resultrow' bgcolor='#9999CC' class='wvtheader'><th align='left' colspan=\"3\">Transfer";
            if ( $config_parms{azinfo_webgui} ) {
                $html_data .=
                  "  <a href=\"SUB;referer?web_torrent_control($torrent->{TORRENT}->{HASH},start)\">(START)</a>   ";
                $html_data .=
                  "  <a href=\"SUB;referer?web_torrent_control($torrent->{TORRENT}->{HASH},stop)\">(STOP)</a>   ";
            }
            $html_data .= "</th>\n";
            $html_data .=
              "<tr id='resultrow' vAlign=center bgcolor='#EEEEEE' class='wvtrow'>";
            $html_data .= "<td nowrap>Time Elapsed: $torrent->{ELAPSED}</td>";
            $html_data .= "<td nowrap>Time Remaining:";
            if ( $torrent->{ETA} eq chr(0x221e) ) {
                $html_data .= "<i>tbd</i></td>";
            }
            else {
                $html_data .= "$torrent->{ETA}</td>";
            }
            my $t_completed = sprintf(
                "%.1f%",
                (
                    (
                        $torrent->{DOWNLOADED}->{RAW} -
                          $torrent->{DISCARDED}->{RAW} -
                          (
                            $torrent->{HASH_FAILS} *
                              $torrent->{TORRENT}->{PIECE_LENGTH}
                          )
                    ) / $torrent->{TORRENT}->{SIZE}->{RAW}
                ) * 100
            );
            $html_data .= "<td nowrap>Completed: $t_completed</td></tr>\n";

            $html_data .=
              "<tr id='resultrow' vAlign=center bgcolor='#EEEEEE' class='wvtrow'>";
            $html_data .=
              "<td nowrap>Downloaded: $torrent->{DOWNLOADED}->{TEXT}</td>";
            $html_data .=
              "<td nowrap>Download Speed: $torrent->{DOWNLOAD_SPEED}->{TEXT}</td>";
            $html_data .= "<td ";
            if ( $torrent->{HASH_FAILS} > 30 ) {
                $html_data .= "bgcolor='#FFCC00' ";
            }
            $html_data .=
              "nowrap>Hash Fails: $torrent->{HASH_FAILS}</td></tr>\n";

            $html_data .=
              "<tr id='resultrow' vAlign=center bgcolor='#EEEEEE' class='wvtrow'>";
            $html_data .=
              "<td nowrap>Uploaded: $torrent->{UPLOADED}->{TEXT}</td>";
            $html_data .=
              "<td nowrap>Upload Speed: $torrent->{UPLOAD_SPEED}->{TEXT}</td>";
            my $t_ratio = $torrent->{SHARE_RATIO} / 1000;
            $html_data .= "<td nowrap>Share Ratio: $t_ratio</td></tr>\n";

            $html_data .=
              "<tr id='resultrow' vAlign=center bgcolor='#EEEEEE' class='wvtrow'>";
            $html_data .=
              "<td nowrap>Seeds: $torrent->{TOTAL_SEEDS} Connected</td>";
            $html_data .=
              "<td nowrap>Peers: $torrent->{TOTAL_LEECHERS} Connected</td>";
            $html_data .=
              "<td nowrap>Swarm Speed: $torrent->{TOTAL_SPEED}->{TEXT}</td></tr>\n";

            $html_data .= "</table>\n";

## Info
            $html_data .=
              "<table width=100% cellspacing=2><tbody><font face=COURIER size=2><tr id='resultrow' bgcolor='#9999CC' class='wvtheader'><th align='left' colspan=\"3\">Info</th>";

            $html_data .=
              "<tr id='resultrow' vAlign=center bgcolor='#EEEEEE' class='wvtrow'>";
            my $t_name = sprintf( "%-30s", $torrent->{TORRENT}->{NAME} );
            $html_data .=
              "<td colspan=\"3\" nowrap>File Name: $t_name</td></tr>";

            $html_data .=
              "<tr id='resultrow' vAlign=center bgcolor='#EEEEEE' class='wvtrow'>";
            my $t_save = sprintf( "%-30s", $torrent->{DOWNLOAD_DIR} );
            $html_data .= "<td colspan=\"3\" nowrap>Save in: $t_save</td></tr>";

            $html_data .=
              "<tr id='resultrow' vAlign=center bgcolor='#EEEEEE' class='wvtrow'>";
            $html_data .=
              "<td colspan=\"3\" nowrap>Hash: $torrent->{TORRENT}->{HASH}</td></tr>\n";

            $html_data .=
              "<tr id='resultrow' vAlign=center bgcolor='#EEEEEE' class='wvtrow'>";
            $html_data .=
              "<td nowrap>\# of Pieces: $torrent->{TORRENT}->{PIECE_COUNT}</td>";
            my $t_plength =
              sprintf( "%4.2f", $torrent->{TORRENT}->{PIECE_LENGTH} / 1000 );
            $html_data .= "<td nowrap>Size: $t_plength kb</td>\n";
            $html_data .=
              "<td nowrap>Total Size: $torrent->{TORRENT}->{SIZE}->{TEXT}</td></tr>\n";

            $html_data .=
              "<tr id='resultrow' vAlign=center bgcolor='#EEEEEE' class='wvtrow'>";
            $html_data .=
              "<td nowrap>Tracker Status: $torrent->{TRACKER_STATUS}</td>";
            my $t_time = gmtime $torrent->{TORRENT}->{CREATION_DATE};
            $html_data .=
              "<td colspan=\"2\" nowrap>Created on: $t_time</td></tr>\n";

            $html_data .=
              "<tr id='resultrow' vAlign=center bgcolor='#EEEEEE' class='wvtrow'>";
            $html_data .= "<td colspan=\"3\" nowrap>Comment: ";

            if ( defined $torrent->{TORRENT}->{COMMENT} ) {
                $html_data .= "$torrent->{TORRENT}->{COMMENT}</td></tr>\n";
            }
            else {
                $html_data .= "No Comment</td></tr>\n";
            }

            $html_data .= "</table><br>\n";
        }
    }

## if html_hdr = () then not found, return error

    my $html = "<html>
<head>
<style>
TR.wvtrow {font-family:Arial; font-size:11; color:#000000}
TR.wvtheader {font-family:Tahoma; font-size:11; color:#101010}
</style>
</head>
<body>";

    $html .= $html_data;

    if ( $found == 0 ) {
        $html .= &html_header("Cannot find Torrent! ");
        print_log
          "Torrent: Error, Web_Torrent_Details cannot find torrent hash=$hash";
    }

    $html .= "</body>";

    my $html_page = &html_page( '', $html );
    return &html_page( '', $html );

}    #end web_torrent_detail

sub web_torrent_control {

    my ( $hash, $action ) = @_;
    my $control_url =
      "http://$config_parms{azinfo_webgui_ip}:$config_parms{azinfo_webgui_port}/index.tmpl";
    my $control_id = substr $hash, 0, 5;

    print_log "AzInfo: AzControl: changing torrent $hash to $action";

    if ( $action eq 'start' ) {
        run "get_url -quiet $control_url?fstart=$control_id /dev/null";
    }
    elsif ( $action eq 'stop' ) {
        run "get_url -quiet $control_url?stop=$control_id /dev/null";
    }
    elsif ( $action eq 'stopall' ) {
        if ( $hash eq 'downloads' ) {
            run "get_url -quiet $control_url?stop=alld /dev/null";
        }
        elsif ( $hash eq 'seeds' ) {
            run "get_url -quiet $control_url?stop=alls /dev/null";
        }
    }
    elsif ( $action eq 'startall' ) {
        if ( $hash eq 'downloads' ) {
            run "get_url -quiet $control_url?start=alld /dev/null";
        }
        elsif ( $hash eq 'seeds' ) {
            run "get_url -quiet $control_url?start=alls /dev/null";
        }
    }
    print_log "db: end of subroutine" if $az_debug;

}    #end web_torrent_control
