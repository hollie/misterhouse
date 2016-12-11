# Category=Alarm System

#@ Interface to Alarm System via PowerFlash module.<br>
#@ See alarm.pl for specifics on how to setup DSC panels for powerflash
#@ and modify alarm.pl for house/unit code of powerflash.

##################################################################
#  Interface to DSC alarm system via PowerFlash X10 module       #
#                                                                #
#   Powerflash wired to PGM2 and COMMON                          #
#   Powerflash set to mode B - Dry Contact                       #
#   Powerflash set to mode 3 - Single Unit On/Off                #
#                                                                #
#   DSC programming location 009 set to 1901                     #
#       19 = PGM1 at factory default                             #
#       01 = PGM2 tracks state of siren/bell (i.e. Alarm)        #
#                                                                #
#                                                                #
#  By: Danal Estes, N5SVV                                        #
#  E-Mail: danal@earthling.net                                   #
#                                                                #
##################################################################

$alarm = new X10_Appliance('E1');    # Modify for your powerflash here.

if ( state_now $alarm) {
    my $state = state $alarm;
    print_log "Alarm System state change. State = $state";
    &alarm_notify("Alarm system siren activated") if $state eq 'on';
    &alarm_notify("Alarm system siren stopped")   if $state eq 'off';
}

# Subroutine to send a page / pcs message, etc.
sub alarm_notify {
    my ($text) = @_;

    my $p1 = new Process_Item(
        "send_sprint_pcs -to danal -text \"$text $Date_Now $Time_Now\" ");
    start $p1;    # Run externally so as not to hang MH process
    my $p2 = new Process_Item(
        "alpha_page -pin 1488774 -message \"$text $Date_Now $Time_Now\" ");
    start $p2;    # Run externally so as not to hang MH process
    net_mail_send(
        account => 'DanalHome',
        to      => 'danal@earthling.net',
        subject => $text,
        text    => "$text $Date_Now $Time_Now"
    );
    net_mail_send(
        account => 'DanalHome',
        to      => 'destes@rosewalker.com',
        subject => $text,
        text    => "$text $Date_Now $Time_Now"
    );
    print_log "Alarm notification sent, text = $text";
    speak "Djeeni says: $text";
}
