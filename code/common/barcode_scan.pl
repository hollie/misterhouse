# Category=Barcode

#@ Used to scan in barcodes using a keyboard simulator scanner like the CueCat
#@ Decode data is stored in $barcode_data
#@ See barcode_web.pl as an example of how to use that data

#
#   - If scanning paperbacks, check the inside cover for the ISBN EAN code,
#     not the back-of-the-book UPC code
#
# Here is the program flow:
#
# - mh/web/barcode_scan.shtml has a form that calls SET on the Generic_Item $barcode_scan variable
#
# - mh/code/test/barcode_scan.pl wakes up when $barcode_scan changes, and process the data into $barcode_data
#
# - mh/code/test/barcode_web.pl (or mh/code/barcode_inventory.pl) detects $barcode_data change
#   and updates mh/web/barcode_search.html.
#
# - Your original web request, after a few mh passes, returns mh/web/barcode_search.html
#
#

$barcode_data = new Generic_Item;
$barcode_mode = new Generic_Item;
$barcode_mode->set_states(
    'web',
    'add inventory',
    'delete inventory',
    'query inventory',
    'clear inventory'
);
$barcode_mode->set_authority('anyone');

$v_barcode_mode = new Voice_Cmd(
    'Change barcode scan to [entry,add inventory,delete inventory,query inventory,clear inventory] mode'
);
$v_barcode_mode->set_info(
    'Controls what you want to do with barcode scans.  Web will create urls, inventory updates a database'
);
$v_barcode_mode->set_authority('anyone');
$v_barcode_mode->tie_items($barcode_mode);
$v_barcode_mode->tie_event('respond "app=scanner Scanner set to $state mode"');

$barcode_scan = new Generic_Item;
$barcode_scan->set_authority('anyone');
$barcode_scan->set_casesensitive;    # Barcode information is case-sensitive

&tk_entry( 'Barcode', $barcode_scan );

# Scan starts with Alt-F10
$MW->bind( '<Key-F10>', sub { $Tk_objects{entry}{$barcode_scan}->focus() } )
  if $MW and $Reload;

if ( $state = state_now $barcode_scan) {
    play 'barcode_scan';             # See event_sounds.pl
    $state = '.' . $state
      unless $state =~ /^\./
      or length($state) < 20;        # Tk entry drops the leading '.' ???

    my ( $scanner_sn, $type, $code ) = barcode_decode($state);

    $state =~
      s/^\..+?\./\./;    # Drop the scanner Serial Number data from the logs
    ${ $$barcode_scan{state_log} }[0] = "$Time_Date $state";
    my $mode = state $barcode_mode;
    print_log "Barcode scan: $mode $state";

    #   $$barcode_scan{state} = $state;

    # *** Does not clear on tk console!

    set $barcode_scan '';    # Reset widget
    $Info{barcode_data} = undef;

    # If a book, find the ISBN
    if ( $type =~ /^IB/ ) {
        my $isbn;

        if ( length($code) == 10 ) {
            $isbn = $code;
        }
        else {
            $isbn = substr $code, 3, 9;
            $isbn = $isbn . &ISBN_checksum($isbn);
        }
        print_log "Barcode data: $type $code $isbn";
        $Info{barcode_data} = $isbn;
        set $barcode_data "$type $code $isbn";    # Feed back upc and isbn
    }
    else {
        # CheckDigit may not have been transmitted for UPE types
        if (    $type eq 'UPE'
            and $code =~ /^(\d)(\d)(\d)(\d)(\d)(\d)(\d)$/ )
        {
            # only do this if missing the CheckDigit (7 digits instead of 8)
            # some 'newer' scanners have been "fixed" via a software upgrade

            #            print_log "UPC-E Digits : SystemNumber=($1) -- a=($2) b=($3) c=($4) d=($5) e=($6) f=($7)";

            # This CheckDigit computation was derived from converting UPC-E to UPC-A
            # (forumla is different based upon the 7th digit)
            # then computing the CheckDigit for UPC-A
            # UPC-A CheckDigit = 10 - ( [((Add Even-positioned Digits)*3) + (Add Odd-positioned Digits)] % 10 )
            #
            # the formula was then re-written to remove the extra zeros that the
            # UPC-E compression added.
            #
            # So, the net result is the computation of the CheckDigit without converting to UPC-A
            #
            # The "10 - ($cc % 10)" was common code, so it was separated out.

            # Compute the CheckDigit (Part 1)
            my $cc = 0;
            if ( $7 <= 2 ) {
                $cc = ( ( $1 + $3 + $4 + $6 ) * 3 ) + ( $2 + $7 + $5 );
            }
            elsif ( $7 == 3 ) {
                $cc = ( ( $1 + $3 + $6 ) * 3 ) + ( $2 + $4 + $5 );
            }
            elsif ( $7 == 4 ) {
                $cc = ( ( $1 + $3 + $5 + $6 ) * 3 ) + ( $2 + $4 );
            }
            else {
                $cc = ( ( $1 + $3 + $5 + $7 ) * 3 ) + ( $2 + $4 + $6 );
            }

            # Compute the CheckDigit (Part 2)
            $cc = 10 - ( $cc % 10 );

            #           print_log "UPE CheckDigit=($cc)";
            $code .= $cc;

            #  $Save{barcode_data} = $code;

        }    # only if missing the CheckDigit
        $Info{barcode_data} = $code unless $Info{barcode_data};
        print_log "Barcode data: $type $code";
        set $barcode_data
          "$type $code"; # This is what get used elsewhere (e.g. barcode_web.pl)
    }
}

# A bit of perl magic
sub barcode_decode {
    if ( length( $_[0] ) > 20 ) {
        return map {
            tr/a-zA-Z0-9+-/ -_/;
            $_ = unpack 'u', chr( 32 + length() * 3 / 4 ) . $_;
            s/\0+$//;
            $_ ^= "C" x length;
        } $_[0] =~ /\.([^.]+)/g;
    }
    else {
        my $type;
        if ( length( $_[0] ) == 8 ) {
            return ( undef, 'UPE', $_[0] );
        }
        elsif ( length( $_[0] ) == 10 ) {
            return ( undef, 'IB', $_[0] );
        }
        else {
            return ( undef, 'UPC', $_[0] );
        }
    }
}

# Algorithm detailed at http://www.bisg.org/algorithms.html
sub ISBN_checksum {
    my @digits = split //, $_[0];
    my $sum = 0;
    for ( 2 .. 10 ) {
        $sum += $_ * ( pop @digits );
    }
    my $checksum = 11 - $sum % 11;
    $checksum = 'X' if $checksum == 10;
    return $checksum;
}
