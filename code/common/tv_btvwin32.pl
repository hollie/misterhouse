# Category=Entertainment
#
#----------------------------------------------------------------------------
#  NAME		: BTV Win32
#  AUTHOR	: amauri viguera (amauri@viguera.net)
#  DESCRIPTION 	:
#@
#@ Interface with SnapStream's "Personal Video Station" AKA "Beyond TV"
#@ This module has been tested with MH 2.88+ and BTV 3.4 and above
#@
#@ As of version 3.4.4, BTV uses a password-protected MDB file
#@ to store guide data. This module uses a DSN to connect to this data
#@ and extract upcoming shows.
#@
#----------------------------------------------------------------------------
# If you modify this script in any fashion, such as to extend functionality,
# please let me know.  You might come up with something that I want to use :)
#----------------------------------------------------------------------------
#  MH.ini parameters :
#
#  - snapstream_timeoffset=[integer]
#	offset from current timezone vs. time data in the tables.
#	as of 3.4.4, this was 4 hours ahead of Eastern
#  - snapstream_dsnName
#	Name of ODBC DSN pointing to MDB file
#  - snapstream_dsnUID
#	Userid of the DSN. This is mostly future-proofing.
#	In the case of the BTV Access MDB, "sa" will work just fine
#  - snapstream_dsnPwd
#	Password needed to connect to MDB file.
#
#  - debug=snapstream on your private ini will enable progress chatter
#
#  Notes on configuration :
#
#  - You must find the BTV database and set up a DSN pointing to it.
#  	As of BTV 3.4, this file resides on the following path:
#	\Documents and Settings\All Users\Application Data\SnapStream\Beyond TV
#	Filename is SS_PVS_DB.mdb
#	This file is password protected.
#  - modify mh.ini / private.ini with BTV DSN information
#  - make sure that the DSN is not set to exclusive mode and is read only
#
#@ BTV makes periodic updates to the mdb, but it should contain about 2 weeks
#@ worth of data. It's a GOOD idea to automate making a copy of this database
#@ and working on it locally through the DSN than to address the BTV db directly.
#@ This is a REALLY good idea if BTV sits on another machine, as the query can
#@ potentially pause the MH loop.  This can be addressed by moving the data off
#@ the mdb, onto something more robust than Access, but future BTV changes might
#@ make this unecessary. Wait and see for now... :)
#
#@ I've tried to make this as "common/tv_info"-like as possible. They can certainly
#@ co-exist, but they're pretty redundant at this point.  common/tv_grid is still
#@ needed for a guide, or a replacement.
#
#@ Just like tv_info, this script will create and watch a .txt file on data_dir for
#@ changes. If any shows are coming up, they're written to the file and announced
#@ using code borrowed from that module.
#
#----------------------------------------------------------------------------
# 				HISTORY
#----------------------------------------------------------------------------
#   DATE   		REVISION    	AUTHOR	        DESCRIPTION
#----------------------------------------------------------------------------
#
# April 28th, 2004	1.1		a. viguera
#	- updated triggers to inclue both voice_cmd AND time_cron
#	- modified query to include station callsign and channel #
#	- added functionality to write upcoming shows to {data_dir}/tv_info_btv.txt
#	- added set_watch for tv_info_btv using code from common\tv_info.pl
# April 27th, 2004	1.0		a. viguera	initial release
#
#----------------------------------------------------------------------------

use strict;
use Win32::ODBC;

$Win32::ODBC::ODBCPackage = $Win32::ODBC::ODBCPackage;
$ODBCPackage::Version     = $ODBCPackage::Version;

my $htpc_timeoffset = $config_parms{snapstream_timeoffset};
my $htpc_dsnName    = $config_parms{snapstream_dsnName};
my $htpc_dsnUID     = $config_parms{snapstream_dsnUID};
my $htpc_dsnPwd     = $config_parms{snapstream_dsnPwd};

# we use data/tv_info_btv.txt for upcoming shows and monitoring
my $f_tv_file = new File_Item("$config_parms{data_dir}/tv_info_btv.txt");

# test voice commands to enable "on demand" searching - useful for debug
$v_snapstream_localdb = new Voice_Cmd 'search local snapstream db';
$v_snapstream_localdb->set_authority('anyone');
$v_snapstream_localdb->set_info('search the local snapstream database');

sub snapstream_import {

    # funky bit #1: snapstream's data is offset by +4 hours from eastern... *blink*
    # what needs to be done:
    # - figure out where "now" is in snapstream (+x hours in seconds)
    # - add 2 minutes (in seconds) to "snapstream now"
    # - check db for THAT time. works out to whatever offset*3600 seconds + 120 seconds (announce 2 minutes before show start as usual)

    my $snapstreamoffset = ( ( $htpc_timeoffset * 3600 ) + 120 );
    my ( $min, $hour, $mday, $mon, $year ) =
      ( localtime( time + $snapstreamoffset ) )[ 1, 2, 3, 4, 5 ];
    $mon++;    # i hate this... :)

    # TODO: need some kind of error checking here, in case the file is empty or we're using the ini file
    my @keys;
    @keys = file_read( $config_parms{favorite_tv_shows_file} )
      ;        # read data into @keys for processing later

    # format date/time search key to match snapstream format (yyyymmddhhmm). 4/25/04 @ 17:00 = 200404251700
    my $snapstreamdate =
      sprintf( "%04d%02d%02d%02d%02d", 1900 + $year, $mon, $mday, $hour, $min );

    # debug - when in doubt, hardcode and test :)
    # $snapstreamdate = "200404290000" ;
    print
      "\n\nsearching local snapstream db for shows starting at $snapstreamdate...\n"
      if $Debug{snapstream};

    my $msg    = "";    # we pass this back to the page
    my $rowcnt = 0;     # count of rows found in db
    my $count;          # shows to look for
    my $Message;        # ODBC error messages
    my $match_key;      # shows found boolean
    my $symbol;

    # database-related info
    my %HashRow   = ();
    my $db        = '';
    my $Source    = "DSN=$htpc_dsnName;UID=$htpc_dsnUID;PWD=$htpc_dsnPwd";
    my $TableType = 'U';

    # connect to database
    print "\tconnecting to DSN ($htpc_dsnName) as $htpc_dsnUID\n"
      if $Debug{snapstream};
    if ( $db = new Win32::ODBC($Source) ) {
        print STDERR "\tODBC connection successful for data source\n"
          if $Debug{snapstream};
    }
    else {
        $Message = Win32::ODBC::Error();    #-- use when no $db object ref.
        print STDERR "\nMessage: $Message\n";
        print STDERR "ERROR: ODBC error during connection\n";
        exit;
    }

    print "\tpreparing SQL statement\n" if $Debug{snapstream};

    # this took a while using the query wizard in access and a lot of luck... :)
    my $Sql = "";
    $Sql =
      "SELECT PROGRAM_TABLE.progtitle, PROGRAM_TABLE.episodetitle, EPISODE_TABLE.stationnum, EPISODE_TABLE.startdatetime, EPISODE_TABLE.rec_scheduled, STATION_TABLE.tmschan, STATION_TABLE.stationcallsign ";
    $Sql .=
      "FROM (EPISODE_TABLE INNER JOIN PROGRAM_TABLE ON EPISODE_TABLE.EPGID = PROGRAM_TABLE.EPGID) INNER JOIN STATION_TABLE ON EPISODE_TABLE.stationnum = STATION_TABLE.stationnum ";
    $Sql .= "WHERE (((PROGRAM_TABLE.progtitle) IN (";

    # build sql string by tacking along the parts of @keys (shows) for the WHERE IN part of the SELECT statement
    $count = 0;
    for my $key (@keys) {
        $count++;
        next
          if ( $key =~ /\#/ or $key !~ /\w/ )
          ;   # drop comments and crap that hasn't been filtered out of the file
         # escape the quotes (viva Win32::ODBC! :)) - stuff like Punk'd would break it otherwise :)
        $key =~ s/\'/\'\'/g;

        # this is important for SQL syntax: add commas IF we're not at the end (last key) - otherwise we break real bad :)
        if ( $count == @keys ) {
            $Sql .= "\'$key\'";
        }
        else {
            $Sql .= "\'$key\',";
        }
    }

    # and make sure it's just the stuff starting in 2 minutes :)
    $Sql .= "))) AND EPISODE_TABLE.startdatetime=$snapstreamdate";

    # this is a bit much, depending on how many shows you have :)
    # print "BTV:\t SQL statement:\n\n\t$Sql\n\n" if $Debug{snapstream} ;

    # party time
    print "BTV:\texecuting query\n" if $Debug{snapstream};
    if ( $db->Sql($Sql) ) {
        $Message = $db->Error();
        print STDERR "\nERROR:  $Message\n";
        exit;
    }

    print "BTV:\texecution complete. looking for shows\n" if $Debug{snapstream};

    # loop and process each row in the result set for the SELECT
    while ( $db->FetchRow() ) {
        %HashRow = $db->DataHash();
        $rowcnt++;

        # parse the data from $HashRow()
        my ( $progtitle, $episodetitle, $channel, $callsign, $scheduled ) = (
            $HashRow{'progtitle'}, $HashRow{'episodetitle'},
            $HashRow{'tmschan'},   $HashRow{'stationcallsign'},
            $HashRow{'rec_scheduled'}
        );
        $count = 0 unless $count;

        # do something with the results
        print "\tfound $progtitle on $callsign (channel $channel)\n"
          if $Debug{snapstream};
        $msg .= "$progtitle";
        $msg .= ", \'$episodetitle\'" if ( $episodetitle ne "" );
        $msg .= " channel $channel.\n";

        # $msg .= " on $callsign, channel $channel";
        #print "\t$msg" if $Debug{snapstream} ;
    }

    # watch the file for changes
    set_watch $f_tv_file 'favorites now';    # *** Unreliable in tv_info

    # write out new shows to the file (if any)
    open( OUT1, ">$config_parms{data_dir}/tv_info_btv.txt" )
      or die "Error, could not open output file\n";
    print OUT1 "Found $rowcnt favorites now\n";
    print OUT1 "\n";
    print OUT1 "$msg";
    close OUT1;

    print "BTV: db access completed. found $rowcnt matches.\n"
      if $Debug{snapstream};

    # close database and we're done
    $db->Close() || die Win32::ODBC::Error();

}

# Updates a file, which is monitored below ( *** unfortunate as processes are more reliable.)

&snapstream_import() if time_cron('58,28 * * * *');

# Events

if ( said $v_snapstream_localdb) {
    $v_snapstream_localdb->respond('Searching for TV shows of interest...');
    &snapstream_import();
}

# check if the file changed, then act accordingly
# swiped shamelessly (and unfortunately) from common\tv_info.pl - added print if debug for testing
# *** Needs exact same updates as tv_info!  Some already fixed in tv_info.

if ( changed $f_tv_file) {
    my $state = changed $f_tv_file;
    print "BTV:\ntv_info_btv state changed\n" if $Debug{snapstream};

    # TODO: deal with $f_tv_info2 the same way that common\tv_info.pl does
    my $f_tv_info2 = "$config_parms{data_dir}/tv_info_btv2.txt";

    my $summary      = read_head $f_tv_file 6;
    my ($show_count) = $summary =~ /Found (\d+)/;
    my @data         = read_all $f_tv_file;
    shift @data;    # Drop summary;

    my $i = 0;
    foreach my $line (@data) {
        if ( my ( $title, $channel, $start, $end ) =
            $line =~
            /^\d+\.\s+(.+)\.\s+\S+\s+Channel (\d+).+From ([0-9: APM]+) till ([0-9: APM]+)\./
          )
        {
            if ( $state eq 'favorites now' ) {
                $data[$i] = "$title Channel $channel.\n";
            }
            else {
                $data[$i] = "$start Channel $channel $title.\n";
            }
        }
        $i++;
    }

    my $msg = "There ";
    $msg .= ( $show_count > 1 ) ? " are " : " is ";
    $msg .= plural( $show_count, 'favorite show' );
    if ( $state eq 'favorites today' ) {
        if ( $show_count > 0 ) {
            respond "app=tv $msg on today. @data";
        }
        else {
            respond "app=tv There are no favorite shows on today";
        }
    }
    elsif ( $state eq 'favorites now' ) {
        respond "app=tv Notice, $msg starting now.  @data" if $show_count > 0;
    }
    else {
        chomp $summary;    # Drop the cr
        respond "app=tv $summary @data ";
    }
    display $f_tv_info2 if $show_count;
}
