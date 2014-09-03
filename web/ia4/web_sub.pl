
# Category=Web_Functions

sub X10Lamp {
    my $o;
    my $objState;
    my $icon;
    my ( $arg1, $arg2, $arg3 ) = @_;
    my $onIcon  = "/graphics/$arg2.gif";
    my $offIcon = "/graphics/$arg3.gif";
    $o = &get_object_by_name($arg1);
    return 'not found' unless $o;
    $objState = $o->state;
    $icon =
      "<a href=\"/SET;&webpause?$arg1=off\"><font face=arial size=+3 color=990033><b>"
      . $objState
      . "</b></a></font>";

    if ( $objState eq 'on' ) {
        $icon =
          "<a href=\"/SET;&webpause?$arg1=off\"><img border=0 src=$onIcon></a>";
    }
    if ( $objState eq 'off' ) {
        $icon =
          "<a href=\"/SET;&webpause?$arg1=on\"><img border=0 src=$offIcon></a>";
    }
    return $icon;
}

sub webpause {
    my $icon;

    # $icon = "<html>";
    # $icon .= " <body bgcolor=123456 text=lime>";
    $icon .= " <meta http-equiv='Refresh' content='0;URL=lights.shtml'>";

    # $icon .= " <body bgcolor=123456 text=lime>";
    # $icon .= " <font face=arial size=4 color=lime>";
    # $icon .= " <br><br><br><br><ceter>Performing Operation</center>";

    return $icon;
}

sub housemode {
    my $o;
    my $objState;
    my $icon;
    my ( $arg1, $arg2, $arg3 ) = @_;
    my $onIcon  = "/graphics/$arg2.gif";
    my $offIcon = "/graphics/$arg3.gif";
    $o = &get_object_by_name($arg1);
    return 'not found' unless $o;
    $objState = $o->state;
    $icon     = "/graphics/$arg3.gif";

    if ( $objState eq 'on' ) {
        $icon =
          "<a href=\"/SET;&housemodepause?$arg1=off\"><img border=0 src=$onIcon></a>";
    }
    if ( $objState eq 'off' ) {
        $icon =
          "<a href=\"/SET;&housemodepause?$arg1=on\"><img border=0 src=$offIcon></a>";
    }
    return $icon;
}

sub housemodepause {
    my $icon;

    # $icon = "<html>";
    # $icon .= " <body bgcolor=123456 text=lime>";
    $icon .= " <meta http-equiv='Refresh' content='0;URL=modes.shtml'>";

    # $icon .= " <body bgcolor=123456 text=lime>";
    # $icon .= " <font face=arial size=4 color=lime>";
    # $icon .= " <br><br><br><br><ceter>Performing Operation</center>";

    return $icon;
}

sub web_phonelog {

    # Declare Variables

    use vars qw($PhoneName $PhoneNumber $PhoneTime $PhoneDate);

    my ( $PhoneModemString, $NameDone, $NumberDone, $i, $j );
    my ( @rejloglines,      $NumofCalls );
    my ( @callloglines,     $CallLogTempLine );
    my ( $PhoneDateLog, $PhoneTimeLog, $PhoneNameLog, $PhoneNumberLog );
    my $log_out;
    my $customname;

    $customname = "0";
    $log_out    = "";
    open( CALLLOG, "$config_parms{code_dir}/calllog.log" );    # Open for input
    @callloglines = <CALLLOG>;                                 # Open array and
                                                               # read in data
    close CALLLOG;                                             # Close the file

    print_log "Announced Recent Callers.";

    $NumofCalls = 0;
    $log_out =
      "<table width=100% columns=4 cellspacing=3><tr><font color=white size=2>";
    foreach $CallLogTempLine (@callloglines) {
        $NumofCalls = $NumofCalls + 1;
        ( $PhoneDateLog, $PhoneTimeLog, $PhoneNameLog, $PhoneNumberLog ) =
          ( split( '`', $CallLogTempLine ) )[ 0, 1, 2, 3 ];
        $log_out .=
          "<td>$PhoneDateLog</td>     <td>$PhoneTimeLog</td>     <td>$PhoneNameLog</td>      <td>$PhoneNumberLog</td>";
        $log_out .= "</tr>";
    }

    $log_out .= "</table>";
    $log_out .= "</td></tr><tr><td>";

    $log_out .= "<table width=100% columns=2><tr>";
    $log_out .=
      "<td align=left colspan=2 bgcolor=silver><font color=black size=3><b>NUMBER OF CALLS:  $NumofCalls</td>";
    $log_out .=
      "<td align=right colspan=2><a href=\"/SUB;phone.shtml?web_clearphonelog\"><img src=\"/graphics/icon_eraser.gif\"></a></td>";
    $log_out .= "</tr></table>";

    $log_out .= "</td></tr>";
    return $log_out;
}

sub web_clearphonelog {

    my $log_out;

    $log_out = "";

    open( CALLLOG, ">$config_parms{code_dir}/calllog.log" );    # CLEAR Log
    close CALLLOG;

    return $log_out;
}
