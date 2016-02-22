########################################################
##  this is a sample mh code module that demoes potential
##    use of the caddx.pm misterhouse lib.
##  (which currently requires a separately running instance
##    of caddx.pl).
##
##  the items in this example are defined in caddx_motion.mht
########################################################
########################################################
########################################################
use caddx;
set_icon $Office_Motion "motion";
set_icon $Kitchen_Motion "motion";
set_icon $Basement_Motion "motion";
if ($Reload) {
    ## $Office_Motion -> tie_event('&set_motion($FootRest,$state);');
    $Kitchen_Motion->tie_event('&set_motion($GR_Couch,$state);');
    $Basement_Motion->tie_event('&set_motion($basement_overhead,$state);');
    $Garage_Door_2_Car->tie_event('&smtp_notify($Garage_Door_2_Car,$state);');
    $Waterbug->tie_event('&smtp_notify($Waterbug,$state);');
    $Sump_Pit->tie_event('&smtp_notify($Sump_Pit,$state);');

    #&smtp_notify({object_name=>'test_send'},"reload");
}
########################
#  set_motion
#    this routine will trap set on/off/quiescent requests, and
#    suppress the "set" calls for quiescent events.
#    (since they are meaningless and undefined in the web interface).
########################
sub set_motion {
    my ( $obj, $state ) = @_;
    print "set_motion $obj $state\n";

    ## suppress msgs that transition to quiescent
    return if ( $state =~ /quiescent/i );

    ## suppress msgs that do not transition
    if ( $obj->state() eq $state ) {
        return;
    }

    set $obj $state;
}

