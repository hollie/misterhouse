# Category=APRS

# Declare Variables

# Roger Bille

#use vars '$AHubSweUP','$AHubSweUsers','$AHubSweBps','$AHubSwePkts','$AHubSweVer','$AHubSweTime';
#use vars '$AHubEastUP','$AHubEastUsers','$AHubEastBps','$AHubEastPkts','$AHubEastVer','$AHubEastTime';
use vars '$AH2ndStart', '$AH2ndRestarts', '$AH2ndLast', '$AHStart',
  '$AH2ndAvg', '$AH2ndRaw';
use vars '@AHubUP', '@AHubUsers', '@AHubUsersX', '@AHubBps', '@AHubPkts',
  '@AHubVer', '@AHubVerX', '@AHubTime', '@AHubTimeX', '@AHubName', '@AHubRaw',
  '@AHubRawX';
use vars '@AHubCon', '@AHubCon60', '@AHubConX', '@AHubCon60X';
use vars '@APDName', '@APDLoc', '@APDVer', '@APDUsers', '@APDUsers2',
  '@APDList', '@APDTime', '@APDRaw';
use vars '$APDNbr', '$APDLine', '@AHubMail', '@AHubMailX';
use vars '$WXKey';

use vars '@MailName', '@MailStart', '@MailRem', '@MailAddr', '@MailNbr',
  '$MailCount';

# my (@APDName,@APDLoc,@APDVer,@APDUsers,@APDUsers2,@APDList,@APDTime,@APDRaw);

use vars '$FirstName', '$FirstLoc', '$FirstVer', '$FirstUsers', '$FirstUsers2',
  '$FirstTime', '$FirstStart', '$FirstUp', '$FirstList';
use vars '$SecondName', '$SecondLoc', '$SecondVer', '$SecondUsers',
  '$SecondUsers2', '$SecondTime', '$SecondStart', '$SecondUp', '$SecondList';
use vars '$ThirdName', '$ThirdLoc', '$ThirdVer', '$ThirdUsers', '$ThirdUsers2',
  '$ThirdTime', '$ThirdStart', '$ThirdUp', '$ThirdList';
use vars '@CoreCon', '@CoreCon60';

my ( @List, $Loc, $x, $newkey, $MailText, $MailTo );

my ($APRSString);

#my	@fields	= ("NAME","Ver","Users","bps","Pkts","UP");
my ( $key, $count, $AHubNbr );
my ( $Name, $Ver, $VerX, $Users, $UsersX, $Bps, $Pkts, $UP );
my ( @AHub, @AHubLoc, @AHubWWW, @AHcolor, @AFcolor );
my ( $AHubLine, $AH2ndTag );
my ( $AHubUsersSum, $AHubBpsSum, $AHubPktsSum, $AHubUsersXSum, $BordCol );
my (
    $Time1,   $Time2,  $Time3,     $Time4,  $Time5,
    $Diff,    $Avg,    $TempUsers, $TempUp, $TempUsersX,
    $TempUpX, $bgTime, $bgUp,      $bgTimeX
);
my ( $TempBps, $TempPkts, $TempCon, $TempConX );
my $bgRed = "bgcolor=\"#FF0000\"";
my $bgYel = "bgcolor=\"#FFFF00\"";

# Define TNC Socket

##$tnc_second = new Socket_Item(undef, undef, 'second.aprs.net:14501');	  #

# Breakout from	startup	to have	it autostart if	disconnected RB	010918

##unless (active $tnc_second or not $New_Minute) {
##   print_log "Starting a connection	to second";
##   start $tnc_second;
##   $SecondTime = "";
##}

if ($Startup) {
    $AHStart       = time();
    $AH2ndRestarts = 0;
}

if ($Reload) {
    open( AHUB, "$config_parms{code_dir}/ahub.pos" );    # Open	for	input
    @AHub = <AHUB>;    # Open	array and read in data
    close AHUB;        # Close the file
    $AH2ndLast = 0;
    $count     = 0;

    # 	$APDNbr	= 0;
    foreach $AHubLine (@AHub) {
        ( $AHubName[$count], $AHubWWW[$count], $AHubLoc[$count] ) =
          ( split( ',', $AHubLine ) )[ 0, 1, 2 ];    # Split	each line
        $AHubNbr           = $count;
        $AHubMail[$count]  = 0;
        $AHubMailX[$count] = 0;
        if ( $AHubName[$count] eq "ahubwx" ) { $WXKey = $count }

        #		 $AHubVer[$count] =	"";
        #		 $AHubUsers[$count]	= "";
        #		 $AHubBps[$count] =	"";
        #		 $AHubPkts[$count] = "";
        #		 $AHubUP[$count] = "";
        #		 $AHubTime[$count] = "";
        #		 $AHubRaw[$count] =	"";
        #		 $AHubVerX[$count] = "";
        #		 $AHubUsersX[$count] = "";
        #		 $AHubTimeX[$count]	= "";
        #		 $AHubRawX[$count] = "";
        $count++;
    }

    open( AHUB, "$config_parms{code_dir}/ahub.mail" );    # Open	for	input
    @AHub = <AHUB>;    # Open	array and read in data
    close AHUB;        # Close the file
    $count = 0;
    foreach $AHubLine (@AHub) {
        (
            $MailName[$count], $MailStart[$count],
            $MailRem[$count],  $MailAddr[$count]
        ) = ( split( ',', $AHubLine ) )[ 0, 1, 2, 3 ];    # Split	each line

        #		$MailNbr[$count] = 0;
        $MailCount = $count;
        $count++;
    }
    &create_html;
}

if ($New_Minute) {
    for ( $count = 0; $count <= $AHubNbr; $count++ ) {
        $AHubCon[ $count * 60 + $Minute ]  = 0;
        $AHubConX[ $count * 60 + $Minute ] = 0;
        $AHubCon60[$count]                 = 0;
        $AHubCon60X[$count]                = 0;
        for ( $x = 0; $x <= 59; $x++ ) {
            $AHubCon60[$count] =
              $AHubCon60[$count] + $AHubCon[ $count * 60 + $x ];
            $AHubCon60X[$count] =
              $AHubCon60X[$count] + $AHubConX[ $count * 60 + $x ];
        }
    }
    for ( $count = 1; $count <= 3; $count++ ) {
        $CoreCon[ $count * 60 + $Minute ] = 0;
        $CoreCon60[$count] = 0;
        for ( $x = 0; $x <= 59; $x++ ) {
            $CoreCon60[$count] =
              $CoreCon60[$count] + $CoreCon[ $count * 60 + $x ];
        }
    }
}

# Main TNC Parse Procedure

# if	(($APRSString =	said $tnc_output2) and (($APRSString =~	/ahub/i) ||	($APRSString =~	/USERLIST/))) {
if ( $APRSString = said $tnc_output2) {

    # 	print_msg "Aprs: $APRSString";						# Monitor to Msg Window

    if ( $APRSString =~ /ahub/i ) {

        # AHUBSWE>APAH13,TCPIP*:>SM5NRK/AHub 1.3.7,15 users,11692 bps,8352 Pkts	UP=1.88d
        # AHUBWEST>APAH13,TCPIP*:!3241.32N\11425.33W& KB7ZVA/AHub 1.3.7,12 users,8256 bps,5806 Pkts	UP=1.83d
        # AHUBIN>APAX14,TCPIP*:!4015.51N/08515.48WL	ahubin.d2g.com or kb9uqq.d2g.com - Ports 2023, 14439, and 14579! 1 users
        # AHUBSWE>APRS,TCPIP*:!5848.83N/01652.44EI SM5NRK/AFilterX 1.3,	10 users connected
        # 		print_msg "AHub: $APRSString";						# Monitor to Msg Window

        if ( $APRSString =~
            /(.*)>.*:.*AHub (.*),(\d+) users,(\d+) bps,(\d+) Pkts UP=(.*\d\d[hd]).*/
          )
        {
            # 			print_msg "AHub: Processing";
            $Name  = $1;
            $Ver   = $2;
            $Users = $3;
            $Bps   = $4;
            $Pkts  = $5;
            $UP    = $6;
            $key   = -1;

            $count = 0;
            foreach $AHubLine (@AHubName) {
                if ( $Name =~ /$AHubLine/i ) { $key = $count }
                $count++;
            }

            if ( $key >= 0 ) {

                # 				$AHubName[$key]	= $Name;
                $AHubVer[$key]   = $Ver;
                $AHubUsers[$key] = $Users;
                $AHubBps[$key]   = $Bps;
                $AHubPkts[$key]  = $Pkts;
                $AHubUP[$key]    = $UP;

                # 				my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =	gmtime();
                # 				my $utc	= sprintf "%s-%02d-%02d	%02d:%02d:%02d", $year+1900, $mon+1, $mday,	$hour, $min, $sec;
                $AHubTime[$key]   = time();
                $AHubRaw[$key]    = $APRSString;
                $AHubMail[$count] = 0;
                if ( $APRSString =~ /.*Verified.*/ ) {
                    $AHubCon[ $key * 60 + $Minute ]++;

                    #					print_msg "AHub: $AHubCon[$key*60+$Minute]";
                }
                &create_html;
            }
        }
        if ( $APRSString =~ /(.*)>APAH.*:Verified.*/ ) {
            $Name  = $1;
            $count = 0;
            $key   = -1;
            foreach $AHubLine (@AHubName) {
                if ( $Name =~ /$AHubLine/i ) { $key = $count }
                $count++;
            }
            if ( $key >= 0 ) {
                $AHubCon[ $key * 60 + $Minute ]++;

                #				print_msg "AHub: $Name $AHubCon[$key*60+$Minute]";
            }
        }
    }
    if ( ( $APRSString =~ /afilterx/i ) || ( $APRSString =~ />APAX/ ) ) {

        # AHUBSWE>APAH13,TCPIP*:>SM5NRK/AHub 1.3.7,15 users,11692 bps,8352 Pkts	UP=1.88d
        # AHUBWEST>APAH13,TCPIP*:!3241.32N\11425.33W& KB7ZVA/AHub 1.3.7,12 users,8256 bps,5806 Pkts	UP=1.83d
        # AHUBIN>APAX14,TCPIP*:!4015.51N/08515.48WL	ahubin.d2g.com or kb9uqq.d2g.com - Ports 2023, 14439, and 14579! 1 users
        # AHUBSWE>APRS,TCPIP*:!5848.83N/01652.44EI SM5NRK/AFilterX 1.3,	10 users connected

        #		print_msg "AFilX: $APRSString";						# Monitor to Msg Window

        if ( $APRSString =~ /(.*)>.*:.* (\d+) users.*/ ) {

            #			print_msg "AfilX $1	$2";
            $Name   = $1;
            $UsersX = $2;

            if ( $APRSString =~ /.*APAX(\d)(\d),.*/ ) { $VerX = $1 . "." . $2 }
            if ( $APRSString =~ /.*:.*AFilterX (.*),.*/ ) { $VerX = $1 }

            $count = 0;
            $key   = -1;
            foreach $AHubLine (@AHubName) {
                if ( $Name =~ /$AHubLine/i ) { $key = $count }
                $count++;
            }

            # 			print_msg "AFilX Key=$key";

            if ( $key >= 0 ) {

                # 				$AHubName[$key]	= $Name;
                $AHubVerX[$key]   = $VerX;
                $AHubUsersX[$key] = $UsersX;

                # 				my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =	gmtime();
                # 				my $utc	= sprintf "%s-%02d-%02d	%02d:%02d:%02d", $year+1900, $mon+1, $mday,	$hour, $min, $sec;
                $AHubTimeX[$key]   = time();
                $AHubRawX[$key]    = $APRSString;
                $AHubMailX[$count] = 0;
                &create_html;
            }
        }

        if ( $APRSString =~ /(.*)>.*:Verified.*/ ) {
            $Name  = $1;
            $count = 0;
            $key   = -1;
            foreach $AHubLine (@AHubName) {
                if ( $Name =~ /$AHubLine/i ) { $key = $count }
                $count++;
            }
            if ( $key >= 0 ) {
                $AHubConX[ $key * 60 + $Minute ]++;

                #				print_msg "AFil: $Name $AHubConX[$key*60+$Minute]";
            }
        }
    }

    ### Comment out during test of direct connection to second

    #	if ($APRSString	=~ /^APRSERVE/)	{
    #		# APRSERVE>APRS,TCPIP*:USERLIST	:Verified user KB0OFF logged on	using aprsd	2.1.4.{293
    #		# APRSERVE>APRS,TCPIP*:USERLIST	:Disconnected from K4HG.{286
    #		# APRSERVE>APRS,TCPIP*:USERLIST	:Unverified	user KC0CZI-11 logged on using wx-display 8.11c.{284
    #		if ($APRSString	=~ /.*>.*:Verified.*\{(\d+)/) {
## 			print_msg "2nd:	$1";
    #			$AH2ndTag =	$1;
    #			if ($AH2ndTag <	$AH2ndLast - 40) {		# -40 is for packets can come in wrong order
    #				if ($AH2ndRestarts != 0) {
    #					$AH2ndAvg =	$AH2ndAvg +	(time()	- $AH2ndStart)
    #				}
    #				$AH2ndRestarts++;
    #				$AH2ndStart	= time();
    #				my $utc	=  &utc($AH2ndStart);
    #				print_msg "2nd:	Restart	$AH2ndRestarts $utc	$AH2ndStart";
    #				$AH2ndRaw =	$APRSString;
    #				$SecondList = "";
    #				&create_html;
    #			}
    #			$AH2ndLast = $AH2ndTag;
    #		}
    #		$SecondName = "APRSERVE";
    #		$SecondTime = time();
    #		if ($APRSString	=~ /.*erified user (.*) logged.*/) {
    #			print_msg "2nd+:>$1< $SecondList";
    #			$SecondList = $SecondList . $1 . ",";
    #			print_msg "2nd+: $SecondList";
    #		}
    #		if ($APRSString	=~ /.*Disconnected from (.*)\..*/) {
    #			print_msg "2nd-: >$1< $SecondList";
    #			$SecondList =~ s/$1,//;
    #			print_msg "2nd-: $SecondList";
    #		}
    #		@List = split(/,/,$SecondList);
    #		$SecondUsers2 = @List;
##		print_msg "List1 @List";
    #		@List = sort (@List);
##		print_msg "List2 @List";
    #		$SecondList = join (",",@List,"");
##		print_msg "2nd=: $SecondList";
    #	}

    if ( $APRSString =~ />APD/ ) {

        # aprsdKW>APD214,TCPIP*::USERLIST	:Waterloo_ON: Disconnected from	VE1INN.
        # VE7EQU>APD214,TCPIP*::USERLIST :Prince: Disconnected from	VE3KNA.
        # VE7EQU>APD214,TCPIP*::USERLIST :Prince: Unverified user VE3KNA logged	on using aprsd 2.1.4.
        # aprsdCLE2>APD214,TCPIP*::USERLIST	:Cleveland_OH: Disconnected	from PP5UF-1.
        # APRS-1>APD220,TCPIP*::USERLIST :Charlottesville_VA: Disconnected from	N7VMR-1. 88	users
        # aprsdTST>APD220,TCPIP*::USERLIST :Dallas_TX: Verified	 n5vff using APRSd 2.2.0. 5	users

        #		print_msg "APD: $APRSString";

        # 		if ($APRSString	=~ /(.*)>.*:.* (\d+) users.*/) {
        if ( $APRSString =~ /(.*)>APD(\d+),.*:USERLIST :(.*):.*/ ) {

            #  			print_msg "APD: $1	$2";
            $Name = $1;
            $Ver  = $2;
            $Loc  = $3;
            $Loc =~ s/_/ /g;
            $Users = -1;
            if ( $APRSString =~ /.* (\d+) users.*/ ) { $Users = $1 }

            # 			if ($APRSString	=~ /.*:.*AFilterX (.*),.*/)	{ $VerX	= $1};

            $count  = 0;
            $key    = -1;
            $newkey = 0;
            foreach $APDLine (@APDName) {
                if ( $Name =~ /$APDLine/i ) { $key = $count }
                $count++;
            }
            if ( $key == -1 ) {
                $key    = $count;
                $APDNbr = $count;

                # 				print_msg "APD: New entry $key";
                $newkey = 1;
            }

            #  			print_msg "APD: Key=$key";
            #  			print_msg "APD: Name=$Name Ver=$Ver Loc=$Loc";

            $APDName[$key] = $Name;
            $APDVer[$key]  = $Ver;
            $APDLoc[$key]  = $Loc;
            if ( $Users >= 0 ) { $APDUsers[$key] = $Users }
            $APDTime[$key] = time();
            $APDRaw[$key]  = $APRSString;

            if ( $APRSString =~ /.*Verified user (.*) logged.*/ ) {
                $APDList[$key] = $APDList[$key] . $1 . ",";

                #				print_msg "APD+: $APDList[$key]";
            }
            if ( $APRSString =~ /.*Verified  (.*) using.*/ ) {    # first
                $APDList[$key] = $APDList[$key] . $1 . ",";

                #				print_msg "APD+: $APDList[$key]";
            }
            if ( $APRSString =~ /.*Disconnected from (.*)\..*/ ) {
                $APDList[$key] =~ s/$1,//;

                #				print_msg "APD-: $APDList[$key]";
            }
            @List = split( /,/, $APDList[$key] );
            $APDUsers2[$key] = @List;

            #			print_msg "List1 @List";
            @List = sort (@List);

            #			print_msg "List2 @List";
            $APDList[$key] = join( ",", @List, "" );

            #			print_msg "APD=: $APDList[$key]";

            if ( $APDName[$key] eq "APRS-1" ) {
                $FirstName   = $APDName[$key];
                $FirstVer    = $APDVer[$key];
                $FirstLoc    = $APDLoc[$key];
                $FirstUsers  = $APDUsers[$key];
                $FirstUsers2 = $APDUsers2[$key];
                $FirstList   = $APDList[$key];
                $FirstTime   = $APDTime[$key];
                if ( $APRSString =~ /.*[Vv]erified*/ ) {
                    $CoreCon[ 1 * 60 + $Minute ]++;
                }
            }

            if ( $APDName[$key] eq "aprsdCLE2" ) {
                $ThirdName = $APDName[$key];
                $ThirdVer  = $APDVer[$key];
                $ThirdLoc  = $APDLoc[$key];

                #				$ThirdUsers = $APDUsers[$key];		# comment since third does not send users
                $ThirdUsers2 = $APDUsers2[$key];
                $ThirdList   = $APDList[$key];
                $ThirdTime   = $APDTime[$key];
                if ( $APRSString =~ /.*[Vv]erified*/ ) {
                    $CoreCon[ 3 * 60 + $Minute ]++;
                }
            }

            if ( $newkey == 1 ) {    # Sort
                $count = 1;
                while ( $count < @APDName ) {
                    $x = 1;
                    while ( $x < @APDName ) {
                        if ( $APDName[ $x - 1 ] gt $APDName[$x] ) {
                            @APDName[ $x - 1,   $x ] = @APDName[ $x,   $x - 1 ];
                            @APDVer[ $x - 1,    $x ] = @APDVer[ $x,    $x - 1 ];
                            @APDLoc[ $x - 1,    $x ] = @APDLoc[ $x,    $x - 1 ];
                            @APDUsers[ $x - 1,  $x ] = @APDUsers[ $x,  $x - 1 ];
                            @APDUsers2[ $x - 1, $x ] = @APDUsers2[ $x, $x - 1 ];
                            @APDList[ $x - 1,   $x ] = @APDList[ $x,   $x - 1 ];
                            @APDTime[ $x - 1,   $x ] = @APDTime[ $x,   $x - 1 ];
                            @APDRaw[ $x - 1,    $x ] = @APDRaw[ $x,    $x - 1 ];
                        }
                        $x++;
                    }
                    $count++;
                }
            }

            &create_html;
        }
    }
}

##if ($APRSString	= said $tnc_second) {
##	if ($APRSString	=~ /.* (\d+) stations.*/) {
##		$SecondName = "APRServe";
##		$SecondTime = time();
##		$SecondUsers = $1;
#		print_msg "2nd: $APRSString";
##	}
##	if ($APRSString	=~ /.* APRServe (.*) Copyright.*/) {
##		$SecondVer = $1;
#		print_msg "2nd: $APRSString";
##	}

# Uptime 07m 50s    Stations 1482/1482 (inet)   42/42 (serial)
# Uptime 01h 04m 42s    Stations 3406/3406 (inet)   117/117 (serial)
##	if ($APRSString	=~ /.*Uptime (\d*)m (\d*)s.*/) {
##		$SecondStart = time() - $1 * 60 - $2;
#		print_msg "2nd: $APRSString";
##	}
##	if ($APRSString	=~ /.*Uptime (\d*)h (\d*)m (\d*)s.*/) {
##		$SecondStart = time() - $1 * 60 * 60 - $2 * 60 - $3;
#		print_msg "2nd: $APRSString";
##	}
##	if ($APRSString	=~ /.*[Vv]erified.*/) {
##		$CoreCon[2*60+$Minute]++;
#		print_msg "2nd: $APRSString";
##	}

##	if ($SecondStart != "") {
##		$SecondUp = time() - $SecondStart;
##		$SecondUp = round $SecondUp / 3600, 2;
##		$SecondUp = $SecondUp . "h";
##	}
##}

##if (time() - $SecondTime > 240 and $SecondTime != "" and active $tnc_second) {
##	stop $tnc_second;
##	print_msg "2nd: Closing connection";
##}

if ($New_Minute) {
    if ( $FirstStart != "" ) {
        $FirstUp = time() - $FirstStart;
        $FirstUp = round $FirstUp / 3600, 2;
        $FirstUp = $FirstUp . "h";
    }
    if ( $ThirdStart != "" ) {
        $ThirdUp = time() - $ThirdStart;
        $ThirdUp = round $ThirdUp / 3600, 2;
        $ThirdUp = $ThirdUp . "h";
    }
    for ( $count = 0; $count <= $AHubNbr; $count++ ) {
        for ( $key = 0; $key <= $MailCount; $key++ ) {
            $Time1 = time() - $AHubTime[$count];
            $Time2 =
              ( $MailStart[$key] + $AHubMail[$count] * $MailRem[$key] ) * 60;
##			print_msg "Mail1: $AHubName[$count] $MailName[$key] $AHubTime[$count] $MailStart[$key] $AHubMailX[$count] $MailRem[$key] Time1=$Time1 Time2=$Time2";
            if ( $AHubName[$count] eq $MailName[$key]
                and ( time() - $AHubTime[$count] ) >
                ( $MailStart[$key] + $AHubMail[$count] * $MailRem[$key] ) * 60
                and $AHubTime[$count] != "" )
            {
                $Time1 = &utc( $AHubTime[$count] );

                #				$Time4 = &utc($AHubTimeX[$count]);
                $Time2 = &utc( time() );
                $Time3 = ( time() - $AHubTime[$count] ) / 60;
                $Time3 = round $Time3;

                #				$Time5 = (time() - $AHubTimeX[$count])/60;
                #				$Time5 = round $Time5;
                $AHubMail[$count]++;
                print_msg
                  "Warning AHub on $AHubName[$count] $Time1 $AHubMail[$count] $MailAddr[$key]";
                $MailText =
                  "Warning, missing status report from AHub on $AHubName[$count]\n\n";
                $MailText = $MailText . "Warning Time: $Time2\n\n";
                $MailText = $MailText . "AHub warning #: $AHubMail[$count]\n";
                $MailText = $MailText . "AHub Last Status: $Time1\n";
                $MailText = $MailText . "AHub delta time: $Time3 minutes\n";
                $MailText =
                  $MailText . "AHub Last Packet: $AHubRaw[$count]\n\n";
                $MailText =
                  $MailText . "First warning after $MailStart[$key] minutes\n";
                $MailText =
                  $MailText . "Next warning after $MailRem[$key] minutes\n\n";
                $MailText =
                  $MailText . "This is an automatic message from Roger Bille\n";

                #				$MailTo = "$MailAddr[$key];temp\@ahubswe.net";
                #				$MailTo = "$MailAddr[$key]";
                @List = split( / /, $MailAddr[$key] );
                foreach $MailTo (@List) {
                    &net_mail_send(
                        to => "$MailTo",
                        subject =>
                          "Warning $AHubMail[$count] for AHub on $AHubName[$count] $Time1.",
                        text => "$MailText",
                        from => 'APRSstat@ahubswe.net'
                    );
                }
            }
        }
        for ( $key = 0; $key <= $MailCount; $key++ ) {
            $Time1 = time() - $AHubTimeX[$count];
            $Time2 =
              ( $MailStart[$key] + $AHubMailX[$count] * $MailRem[$key] ) * 60;
##			print_msg "Mail2: $AHubName[$count] $MailName[$key] $AHubTimeX[$count] $MailStart[$key] $AHubMailX[$count] $MailRem[$key] Time1=$Time1 Time2=$Time2";
            if ( $AHubName[$count] eq $MailName[$key]
                and ( time() - $AHubTimeX[$count] ) >
                ( $MailStart[$key] + $AHubMailX[$count] * $MailRem[$key] ) * 60
                and $AHubTimeX[$count] != "" )
            {
                #				$Time1 = &utc($AHubTime[$count]);
                $Time4 = &utc( $AHubTimeX[$count] );
                $Time2 = &utc( time() );

                #				$Time3 = (time() - $AHubTime[$count])/60;
                #				$Time3 = round $Time3;
                $Time5 = ( time() - $AHubTimeX[$count] ) / 60;
                $Time5 = round $Time5;
                $AHubMailX[$count]++;
                print_msg
                  "Warning AFilter on $AHubName[$count] $Time4 $AHubMailX[$count] $MailAddr[$key]";
                $MailText =
                  "Warning, missing status report from AFilterX on $AHubName[$count]\n\n";
                $MailText = $MailText . "Warning Time: $Time2\n\n";
                $MailText =
                  $MailText . "AFilterX warning #: $AHubMailX[$count]\n";
                $MailText = $MailText . "AFilterX Last Status: $Time4\n";
                $MailText = $MailText . "AFilterX delta time: $Time5 minutes\n";
                $MailText =
                  $MailText . "AFilterX Last Packet: $AHubRawX[$count]\n\n";
                $MailText =
                  $MailText . "First warning after $MailStart[$key] minutes\n";
                $MailText =
                  $MailText . "Next warning after $MailRem[$key] minutes\n\n";
                $MailText =
                  $MailText . "This is an automatic message from Roger Bille\n";

                #				$MailTo = "$MailAddr[$key];temp\@ahubswe.net";
                #				$MailTo = "$MailAddr[$key]";
                @List = split( / /, $MailAddr[$key] );
                foreach $MailTo (@List) {
                    &net_mail_send(
                        to => "$MailTo",
                        subject =>
                          "Warning $AHubMailX[$count] for AFilterX on $AHubName[$count] $Time4.",
                        text => "$MailText",
                        from => 'APRSstat@ahubswe.net'
                    );
                }
            }
        }
    }
}

sub create_html {

    #	print_msg "New html";
    # Create include files
    &ahub_table;

    #
    # Standard HTML
    #

    $BordCol =
      " bordercolor=\"#FFFFFF\" bordercolorlight=\"#FFFFFF\" bordercolordark=\"#FFFFFF\"";
    $BordCol = $BordCol
      . "	style=\"border-bottom-style: solid;	border-bottom-color: #000000\"";

    open( HTML, ">\\\\server\\d\$\\wwwroot\\ahub.html" );

    print HTML "<html>\n\n<head>\n<title>AHub Statistics</title>\n";

    # 	 print HTML	"<META HTTP-EQUIV=\"Refresh\" CONTENT=\"60\"\n";
    print HTML "</head>\n\n<body>\n\n";

    &ahub_table;

    #	print HTML "<!--webbot bot=\"Include\" U-Include=\"ahub_table.html\" TAG=\"BODY\" -->\n";

    print HTML "\n&nbsp;\n";

    &core_table;

    print HTML "\n&nbsp;\n";

    &aprsd_table;

    &second;

    print HTML "</body>\n\n</html>\n";

    close HTML;

    #
    # Test HTML
    #

    open( HTML, ">\\\\server\\d\$\\wwwroot\\ahub2.html" );

    print HTML "<html>\n\n<head>\n<title>AHub Statistics</title>\n";
    print HTML "<META HTTP-EQUIV=\"Refresh\" CONTENT=\"60\"\n";
    print HTML "</head>\n\n<body>\n\n";

    &ahub_table;

    print HTML "\n&nbsp;\n";

    &core_table;

    #	&core_test_table;

    print HTML "\n&nbsp;\n";

    &aprsd_table;

    #	&aprsd_test_table;

    &second;

    print HTML "</body>\n\n</html>\n";

    close HTML;

    &log_page;

}

sub ahub_table {

    #	open(HTML, ">\\\\server\\d\$\\wwwroot\\ahub_table.html");
    $BordCol =
      " bordercolor=\"#FFFFFF\" bordercolorlight=\"#FFFFFF\" bordercolordark=\"#FFFFFF\"";
    $BordCol = $BordCol
      . "	style=\"border-bottom-style: solid;	border-bottom-color: #000000\"";
    print HTML
      "<h2	align=\"center\">AHub Statistics</h2>\n<table border=\"1\" width=\"100%\">\n";

    print HTML "<tr>\n";
    print HTML "<td	width=\"10%\"><b><font size=\"2\">Server</font></b></td>\n";
    print HTML
      "<td	width=\"14%\"><b><font size=\"2\">Location</font></b></td>\n";
    print HTML
      "<td	width=\"53%\" colspan=\"7\"><b><font size=\"2\"><p align=\"center\">AHub</font></b></td>\n";
    print HTML
      "<td	width=\"37%\" colspan=\"4\"><b><font size=\"2\"><p align=\"center\">AFilterX</font></b></td>\n";
    print HTML "</tr>\n";

    print HTML "<tr>\n";
    print HTML
      "<td	width=\"10%\"$BordCol><b><font size=\"2\"></font></b></td>\n";
    print HTML
      "<td	width=\"14%\"$BordCol><b><font size=\"2\"></font></b></td>\n";
    print HTML
      "<td	width=\"15%\"$BordCol><b><font size=\"2\">Last Update UTC</font></b></td>\n";
    print HTML
      "<td	width=\"7%\"$BordCol><b><font size=\"2\">Version</font></b></td>\n";
    print HTML
      "<td	width=\"6%\"$BordCol><b><font size=\"2\">Users</font></b></td>\n";
    print HTML
      "<td	width=\"7%\"$BordCol><b><font size=\"2\">Connect</font></b></td>\n";
    print HTML
      "<td	width=\"6%\"$BordCol><b><font size=\"2\">bps</font></b></td>";
    print HTML
      "<td	width=\"6%\"$BordCol><b><font size=\"2\">Pkts</font></b></td>\n";
    print HTML
      "<td	width=\"6%\"$BordCol><b><font size=\"2\">UP Time</font></b></td>\n";
    print HTML
      "<td	width=\"14%\"$BordCol><b><font size=\"2\">Last Update UTC</font></b></td>\n";
    print HTML
      "<td	width=\"7%\"$BordCol><b><font size=\"2\">Version</font></b></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol><b><font size=\"2\">Users</font></b></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol><b><font size=\"2\">Connect</font></b></td>\n";
    print HTML "</tr>\n";

    $AHubUsersSum  = 0;
    $AHubBpsSum    = 0;
    $AHubPktsSum   = 0;
    $AHubUsersXSum = 0;

    for ( $count = 0; $count <= $AHubNbr; $count++ ) {

        # code for @AHcolor	and	@AFcolor in	here

        $BordCol =
          " bordercolor=\"#FFFFFF\" bordercolorlight=\"#FFFFFF\" bordercolordark=\"#FFFFFF\"";
        $Time1 = "";
        $Time2 = "";
        if ( $AHubTime[$count] != "" )  { $Time1 = &utc( $AHubTime[$count] ) }
        if ( $AHubTimeX[$count] != "" ) { $Time2 = &utc( $AHubTimeX[$count] ) }
        $bgTime     = "";
        $bgUp       = "";
        $bgTimeX    = "";
        $TempUsers  = $AHubUsers[$count];
        $TempCon    = $AHubCon60[$count];
        $TempUp     = $AHubUP[$count];
        $TempBps    = $AHubBps[$count];
        $TempPkts   = $AHubPkts[$count];
        $TempUsersX = $AHubUsersX[$count];
        $TempConX   = $AHubCon60X[$count];
        if ( &up( $AHubUP[$count] ) < 14400 and $AHubUP[$count] != "" ) {
            $bgUp = $bgYel;
        }
        if ( time() - $AHubTime[$count] > 1500 and $AHubTime[$count] != "" ) {
            $bgTime    = $bgRed;
            $TempUsers = "";
            $TempCon   = "";
            $TempBps   = "";
            $TempPkts  = "";
            $TempUp    = "";
            $bgUp      = "";
        }
        if ( time() - $AHubTimeX[$count] > 1500 and $AHubTimeX[$count] != "" ) {
            $bgTimeX    = $bgRed;
            $TempUsersX = "";
            $TempConX   = "";
        }
        if ( $AHubCon60[$count] == 0 )  { $TempCon  = "" }
        if ( $AHubCon60X[$count] == 0 ) { $TempConX = "" }

        print HTML "<tr>\n";
        print HTML
          "<td	width=\"10%\"$BordCol><a href=$AHubWWW[$count]><font size=\"2\">$AHubName[$count]</font></a></td>\n";
        print HTML
          "<td	width=\"14%\"$BordCol><font	size=\"2\">$AHubLoc[$count]</font></td>\n";
        print HTML
          "<td	width=\"15%\"$BordCol $bgTime><font size=\"2\">$Time1</font></td>\n";
        print HTML
          "<td	width=\"7%\"$BordCol><font size=\"2\">$AHubVer[$count]</font></td>\n";
        print HTML
          "<td	width=\"6%\"$BordCol><font size=\"2\">$TempUsers</font></td>\n";
        print HTML
          "<td width=\"7%\"$BordCol><font size=\"2\">$TempCon</font></td>\n";
        print HTML
          "<td	width=\"6%\"$BordCol><font size=\"2\">$TempBps</font></td>\n";
        print HTML
          "<td	width=\"6%\"$BordCol><font size=\"2\">$TempPkts</font></td>\n";
        print HTML
          "<td	width=\"6%\"$BordCol $bgUp><font size=\"2\">$TempUp</font></td>\n";
        print HTML
          "<td	width=\"14%\"$BordCol $bgTimeX><font size=\"2\">$Time2</font></td>\n";
        print HTML
          "<td	width=\"7%\"$BordCol><font size=\"2\">$AHubVerX[$count]</font></td>\n";
        print HTML
          "<td	width=\"8%\"$BordCol><font size=\"2\">$TempUsersX</font></td>\n";
        print HTML
          "<td	width=\"8%\"$BordCol><font size=\"2\">$TempConX</font></td>\n";
        print HTML "</tr>\n";
        $AHubUsersSum  = $AHubUsersSum + $AHubUsers[$count];
        $AHubBpsSum    = $AHubBpsSum + $AHubBps[$count];
        $AHubPktsSum   = $AHubPktsSum + $AHubPkts[$count];
        $AHubUsersXSum = $AHubUsersXSum + $AHubUsersX[$count];
    }
    $BordCol = $BordCol
      . "	style=\"border-top-style: solid; border-top-color: #000000\"";
    print HTML "<tr>\n";
    print HTML "<td	width=\"10%\"$BordCol><font	size=\"2\">TOTAL</font></td>\n";
    print HTML "<td	width=\"14%\"$BordCol><font	size=\"2\"></font></td>\n";
    print HTML "<td	width=\"15%\"$BordCol><font	size=\"2\"></font></td>\n";
    print HTML "<td	width=\"7%\"$BordCol><font size=\"2\"></font></td>\n";
    print HTML
      "<td	width=\"6%\"$BordCol><font size=\"2\">$AHubUsersSum</font></td>\n";
    print HTML "<td	width=\"7%\"$BordCol><font size=\"2\"></font></td>\n";
    print HTML
      "<td	width=\"6%\"$BordCol><font size=\"2\">$AHubBpsSum</font></td>\n";
    print HTML
      "<td	width=\"6%\"$BordCol><font size=\"2\">$AHubPktsSum</font></td>\n";
    print HTML "<td	width=\"6%\"$BordCol><font size=\"2\"></font></td>\n";
    print HTML "<td	width=\"14%\"$BordCol><font	size=\"2\"></font></td>\n";
    print HTML "<td	width=\"7%\"$BordCol><font size=\"2\"></font></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol><font size=\"2\">$AHubUsersXSum</font></td>\n";
    print HTML "<td	width=\"8%\"$BordCol><font size=\"2\"></font></td>\n";
    print HTML "</tr>\n";
    print HTML "</table>\n\n";
    print HTML
      "<p><font size=\"2\">Time in <span style=\"background-color: #FF0000\">red</span> if no update last 25 minutes. Uptime in <span style=\"background-color: #FFFF00\">yellow</span> if less than 4 hours. Connect is number of connections to the server last 60 minutes</font></p>";

    #	close HTML;
}

sub core_table {
    $BordCol =
      " bordercolor=\"#FFFFFF\" bordercolorlight=\"#FFFFFF\" bordercolordark=\"#FFFFFF\"";
    $BordCol = $BordCol
      . "	style=\"border-bottom-style: solid;	border-bottom-color: #000000\"";
    print HTML
      "<h2	align=\"center\">Core servers Statistics</h2>\n<table border=\"1\"	width=\"100%\">\n";
    print HTML "<tr>\n";
    print HTML "<td	width=\"10%\"><b><font size=\"2\">Server</font></b></td>\n";
    print HTML
      "<td	width=\"14%\"><b><font size=\"2\">Location</font></b></td>\n";
    print HTML
      "<td	width=\"15%\"><b><font size=\"2\">Last Update UTC</font></b></td>\n";
    print HTML "<td	width=\"8%\"><b><font size=\"2\">Version</font></b></td>\n";
    print HTML "<td	width=\"8%\"><b><font size=\"2\">Users</font></b></td>\n";
    print HTML "<td	width=\"8%\"><b><font size=\"2\">Connect</font></b></td>\n";
    print HTML "<td	width=\"8%\"><b><font size=\"2\">UP Time</font></b></td>\n";
    print HTML "</tr>\n";

    $BordCol =
      " bordercolor=\"#FFFFFF\" bordercolorlight=\"#FFFFFF\" bordercolordark=\"#FFFFFF\"";

    # First

    $Time1 = "";
    if ( $FirstTime != "" ) { $Time1 = &utc($FirstTime) }
    $bgTime    = "";
    $bgUp      = "";
    $TempUsers = $FirstUsers;
    $TempCon   = $CoreCon60[1];
    $TempUp    = $FirstUp;
    if ( &up($FirstUp) < 14400 and $FirstUp != "" ) { $bgUp = $bgYel }
    if ( time() - $FirstTime > 1500 and $FirstTime != "" ) {
        $bgTime    = $bgRed;
        $TempUsers = "";
        $TempCon   = "";
        $TempUp    = "";
        $bgUp      = "";
        $FirstUp   = "";
    }
    if ( $CoreCon60[1] == 0 ) { $TempCon = "" }
    print HTML "<tr>\n";
    print HTML
      "<td	width=\"10%\"$BordCol><font	size=\"2\">$FirstName (first)</font></a></td>\n";
    print HTML
      "<td	width=\"14%\"$BordCol><font	size=\"2\">$FirstLoc</font></td>\n";
    print HTML
      "<td	width=\"15%\"$BordCol $bgTime><font size=\"2\">$Time1</font></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol><font size=\"2\">$FirstVer</font></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol><font size=\"2\">$TempUsers</font></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol><font size=\"2\">$TempCon</font></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol $bgUp><font size=\"2\">$TempUp</font></td>\n";
    print HTML "</tr>\n";

    # Second

    $Time1 = "";
    if ( $SecondTime != "" ) { $Time1 = &utc($SecondTime) }
    $bgTime    = "";
    $bgUp      = "";
    $TempUsers = $SecondUsers;
    $TempCon   = $CoreCon60[2];
    $TempUp    = $SecondUp;
    if ( &up($SecondUp) < 14400 and $SecondUp != "" ) { $bgUp = $bgYel }
    if ( time() - $SecondTime > 1500 and $SecondTime != "" ) {
        $bgTime    = $bgRed;
        $TempUsers = "";
        $TempCon   = "";
        $TempUp    = "";
        $bgUp      = "";
    }
    if ( $CoreCon60[2] == 0 ) { $TempCon = "" }
    print HTML "<tr>\n";
    print HTML
      "<td	width=\"10%\"$BordCol><font	size=\"2\">$SecondName (second)</font></a></td>\n";
    print HTML
      "<td	width=\"14%\"$BordCol><font	size=\"2\">$SecondLoc</font></td>\n";
    print HTML
      "<td	width=\"15%\"$BordCol $bgTime><font size=\"2\">$Time1</font></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol><font size=\"2\">$SecondVer</font></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol><font size=\"2\">$TempUsers</font></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol><font size=\"2\">$TempCon</font></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol $bgUp><font size=\"2\">$TempUp</font></td>\n";
    print HTML "</tr>\n";

    # Third

    $Time1 = "";
    if ( $ThirdTime != "" ) { $Time1 = &utc($ThirdTime) }
    $bgTime    = "";
    $bgUp      = "";
    $TempUsers = $ThirdUsers;
    $TempCon   = $CoreCon60[3];
    $TempUp    = $ThirdUp;
    if ( &up($ThirdUp) < 14400 and $ThirdUp != "" ) { $bgUp = $bgYel }
    if ( time() - $ThirdTime > 1500 and $ThirdTime != "" ) {
        $bgTime    = $bgRed;
        $TempUsers = "";
        $TempCon   = "";
        $TempUp    = "";
        $bgUp      = "";
        $ThirdUp   = "";
    }
    if ( $CoreCon60[3] == 0 ) { $TempCon = "" }
    print HTML "<tr>\n";
    print HTML
      "<td	width=\"10%\"$BordCol><font	size=\"2\">$ThirdName (third)</font></a></td>\n";
    print HTML
      "<td	width=\"14%\"$BordCol><font	size=\"2\">$ThirdLoc</font></td>\n";
    print HTML
      "<td	width=\"15%\"$BordCol $bgTime><font size=\"2\">$Time1</font></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol><font size=\"2\">$ThirdVer</font></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol><font size=\"2\">$TempUsers</font></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol><font size=\"2\">$TempCon</font></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol $bgUp><font size=\"2\">$TempUp</font></td>\n";
    print HTML "</tr>\n";

    print HTML "</table>\n\n";
    print HTML
      "<p><font size=\"2\">Time in <span style=\"background-color: #FF0000\">red</span> if no update last 25 minutes. Uptime in <span style=\"background-color: #FFFF00\">yellow</span> if less than 4 hours. Third's users is updated once every 30 minutes</font></p>";
}

sub core_test_table {
    $BordCol =
      " bordercolor=\"#FFFFFF\" bordercolorlight=\"#FFFFFF\" bordercolordark=\"#FFFFFF\"";
    $BordCol = $BordCol
      . "	style=\"border-bottom-style: solid;	border-bottom-color: #000000\"";
    print HTML
      "<h2	align=\"center\">Core servers Statistics</h2>\n<table border=\"1\"	width=\"100%\">\n";
    print HTML "<tr>\n";
    print HTML "<td	width=\"10%\"><b><font size=\"2\">Server</font></b></td>\n";
    print HTML
      "<td	width=\"14%\"><b><font size=\"2\">Location</font></b></td>\n";
    print HTML
      "<td	width=\"15%\"><b><font size=\"2\">Last Update UTC</font></b></td>\n";
    print HTML "<td	width=\"8%\"><b><font size=\"2\">Version</font></b></td>\n";
    print HTML "<td	width=\"8%\"><b><font size=\"2\">Users</font></b></td>\n";
    print HTML "</tr>\n";

    $BordCol =
      " bordercolor=\"#FFFFFF\" bordercolorlight=\"#FFFFFF\" bordercolordark=\"#FFFFFF\"";

    # First

    $Time1 = "";
    if ( $FirstTime != "" ) { $Time1 = &utc($FirstTime) }
    print HTML "<tr>\n";
    print HTML
      "<td	width=\"10%\"$BordCol><font	size=\"2\">$FirstName (first)</font></a></td>\n";
    print HTML
      "<td	width=\"14%\"$BordCol><font	size=\"2\">$FirstLoc</font></td>\n";
    print HTML "<td	width=\"15%\"$BordCol";
    if ( time() - $FirstTime > 1500 and $FirstTime != "" ) {
        print HTML "	bgcolor=\"#FF0000\"";
    }
    print HTML "><font size=\"2\">$Time1</font></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol><font size=\"2\">$FirstVer</font></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol><font size=\"2\">$FirstUsers ($FirstUsers2) $FirstList</font></td>\n";
    print HTML "</tr>\n";

    # Second

    $Time1 = "";
    if ( $SecondTime != "" ) { $Time1 = &utc($SecondTime) }
    print HTML "<tr>\n";
    print HTML
      "<td	width=\"10%\"$BordCol><font	size=\"2\">$SecondName (second)</font></a></td>\n";
    print HTML
      "<td	width=\"14%\"$BordCol><font	size=\"2\">$SecondLoc</font></td>\n";
    print HTML "<td	width=\"15%\"$BordCol";
    if ( time() - $SecondTime > 1500 and $SecondTime != "" ) {
        print HTML "	bgcolor=\"#FF0000\"";
    }
    print HTML "><font size=\"2\">$Time1</font></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol><font size=\"2\">$SecondVer</font></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol><font size=\"2\">$SecondUsers ($SecondUsers2) $SecondList</font></td>\n";
    print HTML "</tr>\n";

    # Third

    $Time1 = "";
    if ( $ThirdTime != "" ) { $Time1 = &utc($ThirdTime) }
    print HTML "<tr>\n";
    print HTML
      "<td	width=\"10%\"$BordCol><font	size=\"2\">$ThirdName (third)</font></a></td>\n";
    print HTML
      "<td	width=\"14%\"$BordCol><font	size=\"2\">$ThirdLoc</font></td>\n";
    print HTML "<td	width=\"15%\"$BordCol";
    if ( time() - $ThirdTime > 1500 and $ThirdTime != "" ) {
        print HTML "	bgcolor=\"#FF0000\"";
    }
    print HTML "><font size=\"2\">$Time1</font></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol><font size=\"2\">$ThirdVer</font></td>\n";
    print HTML
      "<td	width=\"8%\"$BordCol><font size=\"2\">$ThirdUsers ($ThirdUsers) $ThirdList</font></td>\n";
    print HTML "</tr>\n";

    print HTML "</table>\n\n";
    print HTML
      "<p><font size=\"2\">Time in <span style=\"background-color: #FF0000\">red</span> if no update last 25 minutes.</font></p>";
}

sub aprsd_table {
    $BordCol =
      " bordercolor=\"#FFFFFF\" bordercolorlight=\"#FFFFFF\" bordercolordark=\"#FFFFFF\"";
    $BordCol = $BordCol
      . "	style=\"border-bottom-style: solid;	border-bottom-color: #000000\"";
    print HTML
      "<h2	align=\"center\">aprsd Statistics</h2>\n<table border=\"1\"	width=\"100%\">\n";
    print HTML "<tr>\n";
    print HTML "<td	width=\"10%\"><b><font size=\"2\">Server</font></b></td>\n";
    print HTML
      "<td	width=\"14%\"><b><font size=\"2\">Location</font></b></td>\n";
    print HTML
      "<td	width=\"15%\"><b><font size=\"2\">Last Update UTC</font></b></td>\n";
    print HTML "<td	width=\"8%\"><b><font size=\"2\">Version</font></b></td>\n";
    print HTML "<td	width=\"8%\"><b><font size=\"2\">Users</font></b></td>\n";
    print HTML "</tr>\n";

    for ( $count = 0; $count <= $APDNbr; $count++ ) {

        # code for @AHcolor	and	@AFcolor in	here
        $BordCol =
          " bordercolor=\"#FFFFFF\" bordercolorlight=\"#FFFFFF\" bordercolordark=\"#FFFFFF\"";
        $Time1 = "";
        if ( $APDTime[$count] != "" ) { $Time1 = &utc( $APDTime[$count] ) }
        print HTML "<tr>\n";
        print HTML
          "<td	width=\"10%\"$BordCol><font	size=\"2\">$APDName[$count]</font></a></td>\n";
        print HTML
          "<td	width=\"14%\"$BordCol><font	size=\"2\">$APDLoc[$count]</font></td>\n";
        print HTML "<td	width=\"15%\"$BordCol";

        if ( time() - $APDTime[$count] > 1500 and $APDTime[$count] != "" ) {
            print HTML "	bgcolor=\"#FF0000\"";
        }
        print HTML "><font size=\"2\">$Time1</font></td>\n";
        print HTML
          "<td	width=\"8%\"$BordCol><font size=\"2\">$APDVer[$count]</font></td>\n";
        print HTML
          "<td	width=\"8%\"$BordCol><font size=\"2\">$APDUsers[$count]</font></td>\n";
        print HTML "</tr>\n";
    }
    print HTML "</table>\n\n";
    print HTML
      "<p><font size=\"2\">Time in <span style=\"background-color: #FF0000\">red</span> if no update last 25 minutes.</font></p>";
}

sub aprsd_test_table {
    $BordCol =
      " bordercolor=\"#FFFFFF\" bordercolorlight=\"#FFFFFF\" bordercolordark=\"#FFFFFF\"";
    $BordCol = $BordCol
      . "	style=\"border-bottom-style: solid;	border-bottom-color: #000000\"";
    print HTML
      "<h2	align=\"center\">aprsd Statistics</h2>\n<table border=\"1\"	width=\"100%\">\n";
    print HTML "<tr>\n";
    print HTML "<td	width=\"10%\"><b><font size=\"2\">Server</font></b></td>\n";
    print HTML
      "<td	width=\"14%\"><b><font size=\"2\">Location</font></b></td>\n";
    print HTML
      "<td	width=\"15%\"><b><font size=\"2\">Last Update UTC</font></b></td>\n";
    print HTML "<td	width=\"8%\"><b><font size=\"2\">Version</font></b></td>\n";
    print HTML "<td	width=\"8%\"><b><font size=\"2\">Users</font></b></td>\n";
    print HTML "</tr>\n";

    for ( $count = 0; $count <= $APDNbr; $count++ ) {

        # code for @AHcolor	and	@AFcolor in	here
        $BordCol =
          " bordercolor=\"#FFFFFF\" bordercolorlight=\"#FFFFFF\" bordercolordark=\"#FFFFFF\"";
        $Time1 = "";
        if ( $APDTime[$count] != "" ) { $Time1 = &utc( $APDTime[$count] ) }
        print HTML "<tr>\n";
        print HTML
          "<td	width=\"10%\"$BordCol><font	size=\"2\">$APDName[$count]</font></a></td>\n";
        print HTML
          "<td	width=\"14%\"$BordCol><font	size=\"2\">$APDLoc[$count]</font></td>\n";
        print HTML "<td	width=\"15%\"$BordCol";

        if ( time() - $APDTime[$count] > 1500 and $APDTime[$count] != "" ) {
            print HTML "	bgcolor=\"#FF0000\"";
        }
        print HTML "><font size=\"2\">$Time1</font></td>\n";
        print HTML
          "<td	width=\"8%\"$BordCol><font size=\"2\">$APDVer[$count]</font></td>\n";
        print HTML
          "<td	width=\"8%\"$BordCol><font size=\"2\">$APDUsers[$count] ($APDUsers2[$count]) $APDList[$count]</font></td>\n";
        print HTML "</tr>\n";
    }
    print HTML "</table>\n\n";
    print HTML
      "<p><font size=\"2\">Time in <span style=\"background-color: #FF0000\">red</span> if no update last 25 minutes.</font></p>";
}

sub second {
    print HTML "&nbsp;\n<p><font size=\"2\">\n";
    if ( $AH2ndRestarts != 0 ) {
        $Time3 = &utc($AH2ndStart);
        $Time4 = &utc($AHStart);
        $Diff  = round( ( time() - $AH2ndStart ) / 60 );

        print HTML
          "second $AH2ndRestarts restarts since $Time4. Last restart $Time3 (Current uptime = $Diff minutes)."
          ;    # Average uptime =	$Avg minutes";
        if ( $AH2ndRestarts != 1 ) {
            $Avg = round( ( $AH2ndAvg / ( $AH2ndRestarts - 1 ) ) / 60 );
            print HTML " Average uptime	= $Avg minutes";
        }
    }
    print HTML "</font></p>";
}

sub log_page {
    open( HTML, ">\\\\server\\d\$\\wwwroot\\ahublog.html" );
    print HTML "<html>\n\n<head>\n<title>AHub Statistics</title>\n";
    print HTML "<META HTTP-EQUIV=\"Refresh\" CONTENT=\"60\"\n";
    print HTML "</head>\n\n<body>\n\n";

    for ( $count = 0; $count <= $AHubNbr; $count++ ) {
        print HTML
          "<p style=\"margin-top: 0; margin-bottom: 0\"><font size=\"2\">$AHubRaw[$count]</font></p>\n";
        print HTML
          "<p style=\"margin-top: 0; margin-bottom: 0\"><font size=\"2\">$AHubRawX[$count]</font></p>\n";
    }
    for ( $count = 0; $count <= $APDNbr; $count++ ) {
        print HTML
          "<p style=\"margin-top: 0; margin-bottom: 0\"><font size=\"2\">$APDRaw[$count]</font></p>\n";
    }
    print HTML
      "<p style=\"margin-top: 0; margin-bottom: 0\"><font size=\"2\">$AH2ndRaw</font></p>\n";
    print HTML "</body>\n\n</html>\n";
    close HTML;
}

sub utc {
    my ($ltime) = @_;
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      gmtime($ltime);
    my $utc = sprintf "%s-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1,
      $mday, $hour, $min, $sec;
    return $utc;
}

sub up {
    my ($up) = @_;
    if ( $up =~ /(\d*)\.(\d\d)d/ ) { return round( ( $1 + $2 / 100 ) * 86400 ) }
    if ( $up =~ /(\d*)\.(\d\d)h/ ) { return round( ( $1 + $2 / 100 ) * 3600 ) }
    return 0;
}

#my $HtmlFindFlag=0;
my $firstURL  = "http://first.aprs.net:14501";
my $firstFile = "first";
my $text;
my $f_first_page = "$config_parms{data_dir}/web/$firstFile.txt";
my $f_first_html = "$config_parms{data_dir}/web/$firstFile.html";
$p_first_page = new Process_Item("get_url $firstURL $f_first_html");
$v_first_page = new Voice_Cmd('[Get,Read,Show] first annonser');
$v_first_page->set_info('Get first annonser');

my $thirdURL     = "http://third.aprs.net:14501";
my $thirdFile    = "third";
my $f_third_page = "$config_parms{data_dir}/web/$thirdFile.txt";
my $f_third_html = "$config_parms{data_dir}/web/$thirdFile.html";
$p_third_page = new Process_Item("get_url $thirdURL $f_third_html");
$v_third_page = new Voice_Cmd('[Get,Read,Show] third annonser');
$v_third_page->set_info('Get third annonser');

if ( time_cron('3,33 * * * *') ) {
    unlink $f_first_html, $f_third_html;
    start $p_first_page;
    start $p_third_page;
}

if ( said $v_first_page eq 'Get' ) {
    if (&net_connect_check) {

        #		print_log "Retrieving $firstFile ...";
        start $p_first_page;
    }
    else {
        speak "Sorry, you must be logged onto the net";
    }
}

if ( done_now $p_first_page) {
    my $html = file_read $f_first_html;
    $text = HTML::FormatText->new( leftmargin => 0, rightmargin => 150 )
      ->format( HTML::TreeBuilder->new()->parse($html) );
    if ( $text =~ /.*Server up time (.*) hours.*/ ) {
        $FirstStart = time() - $1 * 3600;

        #		print_msg "1st: $FirstStart";
        $FirstTime = time();
    }
    if ( $text =~ /.*Users (\d*).*/ ) {
        $FirstUsers = $1;

        #		print_msg "1st: $FirstUsers";
    }
    file_write( $f_first_page, $text );
}

if ( said $v_third_page eq 'Get' ) {
    if (&net_connect_check) {

        #		print_log "Retrieving $thirdFile ...";
        start $p_third_page;
    }
    else {
        speak "Sorry, you must be logged onto the net";
    }
}

if ( done_now $p_third_page) {
    my $html = file_read $f_third_html;
    $text = HTML::FormatText->new( leftmargin => 0, rightmargin => 150 )
      ->format( HTML::TreeBuilder->new()->parse($html) );
    if ( $text =~ /.*Server up time (.*) hours.*/ ) {
        $ThirdStart = time() - $1 * 3600;

        #		print_msg "3rd: $ThirdStart";
        $ThirdTime = time();
    }
    if ( $text =~ /.*Users (\d*).*/ ) {
        $ThirdUsers = $1;

        #		print_msg "3rd: $ThirdUsers";
    }
    file_write( $f_third_page, $text );
}

#################################
### Special coding for AHUBWX ###
#################################

use vars '$WXList', '$WXConnect', '$WXTime';

# Define TNC Socket

#unless (active $tnc_second or not $New_Minute) {
#   print_log "Starting a connection	to second";
#   start $tnc_second;
#   $SecondTime = "";
#}
if ($Reload) {
    stop $tnc_ahubwx;
    $WXList = "";
}

if ( $APRSString = said $tnc_ahubwx) {

    # 	print_msg "WX: $APRSString";						# Monitor to Msg Window
    if ( $APRSString =~ /AHUBWX>.*:USERLIST :.*/ ) {

        # AHUBWX>APAX16,TCPIP*::USERLIST :Unverified N2YQT/wx-display 8.36d logon 7 connected to KB7ZVA-9/AHUBWX{747
        # AHUBWX>APAX16,TCPIP*:!3242.00N\11425.33WW KB7ZVA-9/AFilterX 1.6.4, 8 users connected
        # AHUBWX>APAX16,TCPIP*::USERLIST :Unverified CW0019 logon using wx-display 8.37b{748
        # AHUBWX>APAX16,TCPIP*::USERLIST :Unverified CW0019/wx-display 8.37b logon 8 connected to KB7ZVA-9/AHUBWX{749
        # AHUBWX>APAX16,TCPIP*::USERLIST :N2YQT disconnected from KB7ZVA-9/AHUBWX{750
        # AHUBWX>APAX16,TCPIP*::USERLIST :CW0019 disconnected from KB7ZVA-9/AHUBWX{751
        #	 	print_msg "WX: $APRSString";						# Monitor to Msg Window

        if ( $APRSString =~ /.*[Vv]erified ([A-Z0-9]*).*logon.*/ ) {

            #		 	print_msg "WX: $1";						# Monitor to Msg Window
            #			$WXList = $WXList . $1 . ",";
            #			print_msg "WX+: $WXList";
            $WXTime = time();
            $WXConnect++;
            $AHubConX[ $WXKey * 60 + $Minute ]++;

            #			print_msg "WXu: $WXConnect $Minute $AHubConX[$WXKey*60+$Minute]";
        }

        #		if ($APRSString	=~ /.*Verified ([A-Z0-9]*).*logon.*/) {
        #		 	print_msg "WX: $1";						# Monitor to Msg Window
        #			$WXList = $WXList . $1 . ",";
        #			print_msg "WX+: $WXList";
        #			$WXConnect++;
        #			$AHubConX[$WXKey*60+$Minute]++;
        #			print_msg "WXv: $WXConnect $Minute $AHubConX[$WXKey*60+$Minute]";
        #			print_msg "WX: $WXConnect";
        #		}
        #		if ($APRSString	=~ /.*Verified  (.*) using.*/) {		# first
        #			$WXList = $WXList . $1 . ",";
        #			print_msg "WX+: $WXList]";
        #		}
        #		if ($APRSString	=~ /.*:USERLIST :(.*) disconnected from .*/) {
        #			$WXList =~ s/$1,//;
        #			print_msg "WX-: $WXList";
        #		}
        #		@List = split(/,/,$WXList);
        #		$APDUsers2[$key] = @List;
        #		print_msg "List1 @List";
        #		@List = sort (@List);
        #		print_msg "List2 @List";
        #		$WXList = join (",",@List,"");
        #		print_msg "WX=: $WXList";
    }
}
if ( time() - $WXTime > 300 and $WXTime != "" and active $tnc_ahubwx) {
    stop $tnc_ahubwx;
    print_msg "WX: Closing connection";
}
