
=begin comment

This file is called directly from the browser with: 

  http://localhost:8080/bin/tv_search.pl?search_string

=cut

#my ($string) = @ARGV;
my ($MyArgs) = "";

#$string =~ s/search=//;         # Allow for ?string or ?search=string

my $i = 0;
while ( @ARGV[$i] ) {

    #		print @ARGV[$i] ."\n";
    my ( $param, $value ) = split( /=/, @ARGV[$i] );
    print "Param:$param Value:$value\n";
    if ( $param eq "time" || $param eq "times" ) {
        $MyArgs .= " -times \"$value\" ";
    }
    if ( $param eq "dates" ) {
        $MyArgs .= " -dates \"$value\" ";
    }
    if ( $param eq "genre" ) {
        $MyArgs .= " -genre \"$value\" ";
    }
    if ( $param eq "channel" || $param eq "channels" ) {
        $MyArgs .= " -channels \"$value\" ";
    }
    if ( ( $param eq "search" || $param eq "keys" ) && length($value) > 1 ) {
        $MyArgs .= " -keys \"$value\" ";
    }
    if ( $param eq "keyfile" ) {
        $MyArgs .= " -keyfile \"$value\" ";
    }
    $i++;
}
if ( !( $MyArgs =~ /channels/gi ) ) {
    $MyArgs .= " -channels \"$config_parms{tv_my_favorites_channels}\" ";
}

set_watch $f_tv_file;

run qq[get_tv_info_ge $MyArgs -table];
my ($count) = 10;

my $html = "There ";
while ( $count > 0 ) {
    if ( changed $f_tv_file) {
        my $f_tv_info2   = "$config_parms{data_dir}/tv_info2.txt";
        my $summary      = read_head $f_tv_file 6;
        my ($show_count) = $summary =~ /Found (\d+)/;

        if ( $show_count == 0 ) {
            $html = "Sorry nothing found ";
        }
        else {
            $html = file_read "$config_parms{data_dir}/tv_info2.html";
        }

        $count = 0;
    }
    $count = $count - 1;
    sleep(1);
}
return &html_page( '', $html, ' ' );

