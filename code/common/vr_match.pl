sub phrase_match1 {
    my ($phrase) = @_;
    my (%list1);
    my $d_min1  = 999;
    my $set1    = 'abcdefghijklmnopqrstuvwxyz0123456789';
    my @phrases = &Voice_Cmd::voice_items( 'mh', 'no_category' );
    for my $phrase2 ( sort @phrases ) {
        my $d = pdistance( $phrase, $phrase2, $set1, \&distance, { -cost => [ 0.5, 0, 4 ], -mode => 'set' } );

        #       my $brianlendist = abs(length($phrase)-length($phrase2));
        #       $d = $brianlendist + $d;
        #       print_log "---------------- $phrase --- $phrase2 --- $d";
        push @{ $list1{$d} }, $phrase2 if $d <= $d_min1;
        $d_min1 = $d if $d < $d_min1;
    }
    return ${ $list1{$d_min1} }[0];
}
