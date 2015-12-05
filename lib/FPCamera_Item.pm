
package FPCamera_Item;

use warnings;

@FPCamera_Item::ISA = ('Generic_Item');

#  $backyard_cam = FPCamera_Item;
#  $backyard_cam -> set_img("http://127.0.0.1/image.cgi");
#  $backyard_cam -> set_link("http://zm/monitors");

sub new {
    my ($class) = @_;
    my $self = {};
    bless $self, $class;

    # States active/inactive?
    return $self;
}

sub set_img {
    my ( $self, $addr ) = @_;
    $self->{img} = $addr;
}

sub get_img {
    my ($self) = @_;
    my $img = "";
    $img = $self->{img} if ( defined $self->{img} );
    return $img;
}

sub set_video {
    my ( $self, $addr ) = @_;
    $self->{video} = $addr;
}

sub get_video {
    my ($self) = @_;
    my $video = "";
    $video = $self->{video} if ( defined $self->{video} );
    return $video;
}

sub set_thumbnail {
    my ( $self, $addr ) = @_;
    $self->{tn} = $addr;
}

sub get_thumbnail {
    my ($self) = @_;
    my $tn = "";
    $tn = $self->{tn} if ( defined $self->{tn} );
    return $tn;
}

sub set_link {

    # just return a link to a source. Used by IA7 floorplan interface if the image is clicked
    my ( $self, $addr ) = @_;
    $self->{link} = $addr;
}

sub get_link {
    my ($self) = @_;
    my $link = "";
    $link = $self->{link} if ( defined $self->{link} );
    return $link;
}
