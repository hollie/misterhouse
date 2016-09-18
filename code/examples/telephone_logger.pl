# Category = Telephone
my $telephone_logger = new Telephone_logger;
warn "telephone logger init failed\n" unless $telephone_logger;

if ( my $state = said $telephone_logger) {
    $_ = $state;
    print_log "telephone logger just said $state\n";
    if (/,/) {
        my $dur     = $Time - $Save{call_start_time};
        my $durtime = $dur;
        my $hours   = int( $dur / 3600 );
        my $minutes = ( $dur / 60 ) % 60;
        my $seconds = $dur % 60;
        my $dur_print;
        $dur_print = sprintf( "%02d:%02d:%02d", $hours, $minutes, $seconds );
        my ( $start, $number, $end ) = /(.*),(\d*),(.*)/;

        if ( length($number) < 10 ) {
            $number = "Unknown";
        }
        else {
            #	    print "start num=$number\n";
            if ( length($number) > 10 ) {
                $number = substr( $number, 1 );
            }

            #	    print "num now=$number\n";
            #	    $_ = $number;
            #	    my ($ac,$exch,$num) = /(\d\d\d)(\d\d\d)(\d\d\d\d)/;
            #	    print "ac=$ac exch=$exch,num=$num\n";
            #	    $number = $ac.$exch.$num;
            #	    print "formatted num=$number";
            logit(
                "$config_parms{data_dir}/phone/logs/phone.$Year_Month_Now.log",
                "O$number name=$dur_print ext=1 line=home type=VOIP dur=$dur_print"
            );
        }

        #	print "end of call to number $number, time is $elapsed_time seconds \n";

    }
    else {
        #	print "start of call, phone is offhook\n";
        $Save{call_start_time} = $Time;
    }

}

