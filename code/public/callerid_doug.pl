# Category=Phone

=begin comment

From Douglas Parrish on 4/4/2001:

Here is my DB-enabled Caller-ID scripts.  They are not perfect, but they 
might help out if anybody else is trying to do the same thing.

I split the Caller-ID code out from the modem initialization stuff...it 
just seems to make more sense that way.

I also used the existing data in the database instead of 
a 'phone.caller_id.list' file.

I also threw in the PHP page I am using with it for fun....

Have fun!

=cut

use $PhoneModemString;
use DBI;

$v_caller_list = new Voice_Cmd("List all calls for this week");
set_icon $v_caller_list 'phone';

if ( $PhoneModemString = said $phone_modem) {
    my $l = length $PhoneModemString;

    #print "Modem said: $PhoneModemString\n" if $l < 80;
    my $caller_id_data = ' ' . $PhoneModemString;

    if ( $PhoneModemString =~ /NMBR/ ) {
        my ($dbh) =
          DBI->connect( "DBI:mysql:callerid:localhost", "USER", "PASS" );
        my ( $caller, $cid_number, $cid_name, $cid_time ) =
          &Caller_ID::make_speakable( $caller_id_data, 2 );

        my $number = $cid_number;
        $number =~ tr/\-//d;

        my $query_search =
          "SELECT name FROM calls WHERE number = \"$number\" LIMIT 1;";

        my $sth = $dbh->prepare($query_search);
        $sth->execute();

        if ( $sth->rows != 0 ) {
            ($cid_name) = $sth->fetchrow_array();
        }

        $cid_name = "Unknown" if ( $cid_name eq "" );

        if ( $at_home->{state} eq 'off' ) {
            print_log "No one is home, paging with CallerID info.";
            net_im_send("Phone Call:\n  Call from $cid_name at $cid_number.");
        }

        speak("Phone call is from $cid_name");

        print_log "Call from $cid_name \@ $cid_number";

        $cid_number =~ tr/\-//d;

        my $query_insert =
          "INSERT into calls set name=\"$cid_name\", number=\"$cid_number\", local_datetime=unix_timestamp(\"$Year-$Month-$Mday $Hour:$Minute:$Second\");";

        my $sth = $dbh->prepare($query_insert);
        $sth->execute();

        undef $PhoneModemString;
        $sth->finish();

        $dbh->disconnect();
    }
}

## List all calls this week.
if ( state_now $v_caller_list) {
    my ($dbh) = DBI->connect( "DBI:mysql:callerid:localhost", "USER", "PASS" );
    my $query =
      "SELECT name, number, from_unixtime(local_datetime) as when from calls where week(from_unixtime(unix_timestamp(), \"%Y-%m-%d\")) = week(from_unixtime(local_datetime, \"%Y-%m-%d\")) order by when desc;";

    my $cid_name   = "";
    my $cid_number = "";
    my $cid_when   = "";
    my $cid_buffer = "\n";

    my $sth = $dbh->prepare($query);
    $sth->execute();

    while ( ( $cid_name, $cid_number, $cid_when ) = $sth->fetchrow_array() ) {
        $cid_buffer .= "&nbsp;&nbsp;$cid_name - $cid_number - $cid_when\n";
    }
    print_log "$cid_buffer";

    $sth->finish();
    $dbh->disconnect();
}
