# Category = Internet

#@ This script collects and graphs traffic data from an actiontec mi424 wr router used by Verizon FIOS.
#@ Once this script is activated, <a href='sub;?graph_actiontec_rrd()'>
#@ this graph </a> or <a href='/misc/actiontec_traffic.html'>
#@ this page </a> will show your Internet traffic.

# 09/11/08 created by David Norwood

use HTML::TableExtract;
use RRDs;

my $actiontec_host          = '192.168.1.1';
my $actiontec_username      = 'admin';
my $actiontec_password      = 'password1';
my $actiontec_download_mbps = 10.0;
my $actiontec_upload_mbps   = 2.0;
my $actiontec_url;
my $f_actiontec = "$config_parms{data_dir}/web/actiontec.html";
$v_get_actiontec  = new Voice_Cmd 'Get actiontec info';
$v_read_actiontec = new Voice_Cmd 'What is the internet bit rate?';
$p_get_actiontec  = new Process_Item;
my $RRD   = "$config_parms{data_dir}/rrd/actiontec.rrd";
my $debug = $Debug{actiontec};
my $quiet = $debug ? "" : "-quiet";
my $stage = 'authen';

if ($Reload) {
    $actiontec_username = $config_parms{'actiontec_username'}
      if $config_parms{'actiontec_username'};
    $actiontec_password = $config_parms{'actiontec_password'}
      if $config_parms{'actiontec_password'};
    $actiontec_download_mbps = $config_parms{'actiontec_download_mbps'}
      if $config_parms{'actiontec_download_mbps'};
    $actiontec_upload_mbps = $config_parms{'actiontec_upload_mbps'}
      if $config_parms{'actiontec_upload_mbps'};
    mkdir "$config_parms{data_dir}/rrd/"
      unless -d "$config_parms{data_dir}/rrd/";
    &create_actiontec_rrd($Time) unless -e $RRD;
    $Included_HTML{'Internet'} .=
      qq(<h3>Actiontec Throughput<p><img src='sub;?graph_actiontec_rrd()'><p>\n\n\n);
    $actiontec_host = $config_parms{'actiontec_host'}
      if $config_parms{'actiontec_host'};
    $actiontec_url = "http://$actiontec_host";
    set $p_get_actiontec qq|get_url $quiet $actiontec_url $f_actiontec|;
    $p_get_actiontec->start;
}

if (    new_minute
    and ( $stage eq 'ready' or $stage eq 'authen' )
    and $p_get_actiontec->done )
{
    unlink $f_actiontec;
    $p_get_actiontec->start;
}

if ( said $v_read_actiontec) {
    my $state = $v_read_actiontec->{state};
    my $text =
        "Internet download bit rate: "
      . $Save{actiontec_rx}
      . " Mbps  upload: "
      . $Save{actiontec_tx} . " Mbps";
    $v_read_actiontec->respond("app=network $text");
}

use Digest::MD5;
if ( done_now $p_get_actiontec) {
    my $html      = file_read $f_actiontec;
    my $post_data = "bla=foo";
    my %hidden =
      $html =~ m|\<INPUT type=HIDDEN name=\"([^\"]*)\" value=\"([^\"]*)\">|g;
    my ($url) = $html =~ m|f.action=\"(/cache/\d+/index.cgi)\"|;

    if ( $stage eq 'authen' ) {
        $stage = 'get_main';
        print_log "actiontec stage $stage url $url";
        $hidden{mimic_button_field} = "submit_button_login_submit: ..";
        if ( $html =~ m|$hidden{mimic_button_field}| ) {
            $hidden{user_name} = $actiontec_username;
            $hidden{"passwordmask_$hidden{session_id}"} = $actiontec_password;
            $hidden{md5_pass} =
              Digest::MD5::md5_hex( $hidden{"passwordmask_$hidden{session_id}"}
                  . $hidden{auth_key} );
            $hidden{passwd1} = "                    ";
            foreach my $key ( keys %hidden ) {
                $hidden{$key} = &escape( $hidden{$key} );
                $post_data .= "&$key=$hidden{$key}" if defined $hidden{$key};
            }
            print_log "actiontec post data: $post_data" if $debug;
            set $p_get_actiontec
              qq|get_url $quiet -post "$post_data" $actiontec_url$url $f_actiontec|;
            $p_get_actiontec->start;
        }
        else {
            $stage = 'authen';
            print_log "actiontec: didnt see expected html";
            set $p_get_actiontec qq|get_url $actiontec_url $f_actiontec|;
        }
    }
    elsif ( $stage eq 'get_main' ) {
        $stage = 'get_monitoring';
        print_log "actiontec stage $stage url $url";
        $hidden{mimic_button_field} = "sidebar: actiontec_topbar_status..";
        if ( $html =~ m|$hidden{mimic_button_field}| ) {
            foreach my $key ( keys %hidden ) {
                $hidden{$key} = &escape( $hidden{$key} );
                $post_data .= "&$key=$hidden{$key}" if defined $hidden{$key};
            }
            print_log "actiontec post data: $post_data" if $debug;
            set $p_get_actiontec
              qq|get_url $quiet -post "$post_data" $actiontec_url$url $f_actiontec|;
            $p_get_actiontec->start;
        }
        else {
            $stage = 'authen';
            print_log "actiontec: didnt see expected html";
            set $p_get_actiontec qq|get_url $actiontec_url $f_actiontec|;
        }
    }
    elsif ( $stage eq 'get_monitoring' ) {
        $stage = 'get_nag';
        print_log "actiontec stage $stage url $url";
        $hidden{mimic_button_field} = "btn_tab_goto: 755..";
        if ( $html =~ m|goto: 755..| ) {
            foreach my $key ( keys %hidden ) {
                $hidden{$key} = &escape( $hidden{$key} );
                $post_data .= "&$key=$hidden{$key}" if defined $hidden{$key};
            }
            print_log "actiontec post data: $post_data" if $debug;
            set $p_get_actiontec
              qq|get_url $quiet -post "$post_data" $actiontec_url$url $f_actiontec|;
            $p_get_actiontec->start;
        }
        else {
            $stage = 'authen';
            print_log "actiontec: didnt see expected html";
            set $p_get_actiontec qq|get_url $actiontec_url $f_actiontec|;
        }
    }
    elsif ( $stage eq 'get_nag' ) {
        $stage = 'get_adv_monitoring';
        print_log "actiontec stage $stage url $url";
        $hidden{mimic_button_field} = "submit_button_yes: ..";
        if ( $html =~ m|$hidden{mimic_button_field}| ) {
            foreach my $key ( keys %hidden ) {
                $hidden{$key} = &escape( $hidden{$key} );
                $post_data .= "&$key=$hidden{$key}" if defined $hidden{$key};
            }
            print_log "actiontec post data: $post_data" if $debug;
            set $p_get_actiontec
              qq|get_url $quiet -post "$post_data" $actiontec_url$url $f_actiontec|;
            $p_get_actiontec->start;
        }
        else {
            $stage = 'authen';
            print_log "actiontec: didnt see expected html";
            set $p_get_actiontec qq|get_url $actiontec_url $f_actiontec|;
        }
    }
    elsif ( $stage eq 'get_adv_monitoring' ) {
        $stage = 'ready';
        print_log "actiontec stage $stage url $url";
        $hidden{mimic_button_field} = "btn_tab_goto: 6022..";
        if ( $html =~ m|goto: 6022..| ) {
            foreach my $key ( keys %hidden ) {
                $hidden{$key} = &escape( $hidden{$key} );
                $post_data .= "&$key=$hidden{$key}" if defined $hidden{$key};
            }
            print_log "actiontec post data: $post_data" if $debug;
            set $p_get_actiontec
              qq|get_url $quiet -post "$post_data" $actiontec_url$url $f_actiontec|;
            $p_get_actiontec->start;
        }
        else {
            $stage = 'authen';
            print_log "actiontec: didnt see expected html";
            set $p_get_actiontec qq|get_url $actiontec_url $f_actiontec|;
        }
    }
    elsif ( $stage eq 'ready' ) {
        my $te = HTML::TableExtract->new( headers => ["1 Minute"] );
        $te->parse($html);
        my @cell = $te->rows;
        $Save{actiontec_rx} = $cell[1][0] / 1000;
        $Save{actiontec_tx} = $cell[0][0] / 1000;

        if ( $Save{actiontec_rx} and $Save{actiontec_tx} ) {
            &update_actiontec_rrd( $Time, $Save{actiontec_rx},
                $Save{actiontec_tx} );
            print_log "Internet download bit rate: "
              . $Save{actiontec_rx}
              . " Mbps  upload: "
              . $Save{actiontec_tx} . " Mbps"
              if $debug;
        }
        else {
            $stage = 'authen';
            print_log "actiontec: didnt see expected html";
            set $p_get_actiontec qq|get_url $actiontec_url $f_actiontec|;
        }
    }
}

=begin 
   my $te = new HTML::TableExtract();
   $te->parse($html);

   foreach my $ts ($te->table_states) {
	print "Table (", join(',', $ts->coords), "):\n";
	my $i = 0;
	foreach my $row ($ts->rows) {
		my $j = 0;
		foreach my $col (@$row) {
      		print "$i,$j $col\n";
			$j++;
		}
		$i++;
	}
   }
=cut

# Create database

sub create_actiontec_rrd {
    my $err;
    print "Create RRD database : $RRD\n";

    RRDs::create $RRD,
      '-b', $_[0], '-s', 60,
      "DS:rxmbps:GAUGE:300:U:U",
      "DS:txmbps:GAUGE:300:U:U",
      'RRA:AVERAGE:0.5:1:801',    # details for 6 hours (agregate 1 minute)

      'RRA:MIN:0.5:2:801',        # 1 day (agregate 2 minutes)
      'RRA:AVERAGE:0.5:2:801', 'RRA:MAX:0.5:2:801',

      'RRA:MIN:0.5:5:641',        # 2 day (agregate 5 minutes)
      'RRA:AVERAGE:0.5:5:641', 'RRA:MAX:0.5:5:641',

      'RRA:MIN:0.5:18:623',       # 1 week (agregate 18 minutes)
      'RRA:AVERAGE:0.5:18:623', 'RRA:MAX:0.5:18:623',

      'RRA:MIN:0.5:35:618',       # 2 weeks (agregate 35 minutes)
      'RRA:AVERAGE:0.5:35:618', 'RRA:MAX:0.5:35:618',

      'RRA:MIN:0.5:75:694',       # 1 month (agregate 1h15mn)
      'RRA:AVERAGE:0.5:75:694', 'RRA:MAX:0.5:75:694',

      'RRA:MIN:0.5:150:694',      # 2 months (agregate 2h30mn)
      'RRA:AVERAGE:0.5:150:694', 'RRA:MAX:0.5:150:694',

      'RRA:MIN:0.5:1080:268',     # 6 months (agregate 18 hours)
      'RRA:AVERAGE:0.5:1080:268', 'RRA:MAX:0.5:1080:268',

      'RRA:MIN:0.5:2880:209',     # 12 months (agregate 2 days)
      'RRA:AVERAGE:0.5:2880:209', 'RRA:MAX:0.5:2880:209',

      'RRA:MIN:0.5:4320:279',     # 2 years (agregate 3 days)
      'RRA:AVERAGE:0.5:4320:279', 'RRA:MAX:0.5:4320:279',

      'RRA:MIN:0.5:8640:334',     # 5 years (agregate 6 days)
      'RRA:AVERAGE:0.5:8640:334', 'RRA:MAX:0.5:8640:334';

    my $err = RRDs::error;
    print_log "actiontec create error $err\n" if $err;
}

# Update database

sub update_actiontec_rrd {
    my ( $time, @data ) = @_;

    print_log "actiontec update time = $time data = @data\n" if $debug;
    RRDs::update $RRD, "$time:" . join ':', @data;    # add current data

    my $err = RRDs::error;
    print_log "actiontec update error $err\n" if $err;
}

# Create graph PNG image

sub graph_actiontec_rrd {
    my ( $seconds, $width, $height ) = @_;
    $seconds = 3600 * 6 unless $seconds;
    my $ago = $Time - $seconds;
    $width  = 800 unless $width and $height;
    $height = 100 unless $width and $height;
    my $thumb = $height < 86 ? "--only-graph" : "--lazy";

    unlink "$config_parms{data_dir}/rrd/actiontec.png";
    my ( $graph, $x, $y ) = RRDs::graph(
        "$config_parms{data_dir}/rrd/actiontec.png",
        "--start=$ago",
        "--end=$Time",
        "--width=$width",
        "--height=$height",
        "--lower-limit=-$actiontec_upload_mbps",
        "--upper-limit=$actiontec_download_mbps",
        "--vertical-label=Mb/s",
        "DEF:rxmbps=$RRD:rxmbps:AVERAGE",
        "AREA:rxmbps#2000FF:In traffic",
        "DEF:txmbps=$RRD:txmbps:AVERAGE",
        "CDEF:itxmbps=txmbps,-1,*",
        "AREA:itxmbps#AFAF00:Out traffic",
        $thumb
    );
    my $err = RRDs::error;
    print_log "actiontec graph error $err\n" if $err;
    unlink "$config_parms{data_dir}/rrd/actiontec.jpg";
    `convert $config_parms{data_dir}/rrd/actiontec.png $config_parms{data_dir}/rrd/actiontec.jpg`;
    return file_read "$config_parms{data_dir}/rrd/actiontec.jpg";
}
