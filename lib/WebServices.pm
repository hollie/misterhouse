# WebServices.pm
# $Date$
# $Revision$

=begin comment
-------------------------------------------------------------------------------

Description:
	This file defines the misterhouse methods that will be callable from 
	the soap server.  Any method in the file will be callable.  Most of the
	the methods here will just be wrappers for the main mh functions.

Requires:
	SOAP::Lite  Available from CPAN http://search.cpan.org
	SoapServer.pm  

Authors:
	Mike Wiebke mw65@yahoo.com

-------------------------------------------------------------------------------
=cut

package WebServices;

sub TestArray {
    my @x = [ 1, 2, 3 ];
    return @x;
}

sub ListObjectsByType {
    $self = shift;
    my $obj_type = shift;

    # main::print_log "Listing objects of type $obj_type by SoapServer";
    my @results = &main::list_objects_by_type($obj_type);
    return [@results];
}

sub ListObjectsByFile {
    return &main::list_objects_by_file();
}

sub ListObjectTypes {
    my @results = &main::list_object_types();
    return [@results];
}

sub RunVoiceCommand {
    my ( $self, $cmd ) = @_;

    return &main::run_voice_cmd( $cmd, undef, "SOAP" );
}

sub SetItemState {
    my ( $self, $item, $state ) = @_;

    $item =~ s/\$//;
    $item = '$main::' . $item;

    my $eval_cmd =
      qq[($item and ref($item) ne '' and ref($item) ne 'SCALAR' and $item->can('set')) ?
		           ($item->set("$state", 'SOAP')) : ($item = "$state")];

    eval $eval_cmd;

    if ($@) {
        return ( 0, $@ );
    }
    else {
        return ( 1, $state );
    }
}

sub GetItemState {
    my ( $self, $item ) = @_;

    $item =~ s/\$//;
    $item = '$main::' . $item;

    my $state;

    #my $eval_cmd = qq^\$state = $item->state^;

    my $eval_cmd =
      qq[($item and ref($item) ne '' and ref($item) ne 'SCALAR' and $item->can('state')) ? (\$state = $item->state) : ($item)];

    eval $eval_cmd;

    return $@ ? $@ : $state;
}

1;

