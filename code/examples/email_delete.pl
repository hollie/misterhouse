# Category=Informational

#This deletes email off server for the account listed below.
#Larry Roudebush

$v_remove_mail_off_server = new Voice_Cmd('Delete Mail Off Server');

if ( said $v_remove_mail_off_server or $New_Day ) {
    if (&net_connect_check) {
        net_mail_delete( account => 'account_1' );
    }
}
