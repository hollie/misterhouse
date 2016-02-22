# $Date$
# $Revision$

# Authority: anyone

use Image::Resize;
my $url;
foreach my $argnum ( 0 .. $#ARGV ) {
    $url .= "$ARGV[$argnum] ";
}
chop($url);
my $image_file = $url;
unless ( $url =~ m/^\// ) {
    $url = "/" . $url;
}
$image_file =~ s/^\///;
$image_file =~ s/:/-/g;
$image_file =~ s/\//-/g;
$image_file =~ s/(.+)\.(.+)$/$1/;
my $img;
my $nocache = 0;

#$nocache = 1;
$image_file = "$config_parms{html_alias_cache}/$image_file.jpg";
unless ( -e "$image_file" or $nocache ) {
    $url = $config_parms{html_alias_photos} . $url;
    my $image = Image::Resize->new($url);
    my $gd = $image->resize( 50, 50 );
    $img .= $gd->jpeg();
    open( FH, ">$image_file" );
    print FH $img;
    close(FH);
}
else {
    open( FH, $image_file );
    binmode FH;
    my ( $buf, $data, $n );
    while ( ( $n = read FH, $data, 4 ) != 0 ) {
        $img .= $data;
    }
    close(FH);
}
return &mime_header( $image_file, 1, length $img ) . $img;
