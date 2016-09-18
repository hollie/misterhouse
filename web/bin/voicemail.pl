
# Links to various voicemail boxes.  Set mh.ini phone_voicemail_* parms
#  MCI:  http://www.theneighborhood.com

# Authority: anyone

if ( 'mci' eq lc $config_parms{phone_voicemail_type} ) {
    my $phone =
      ($Authorized) ? $config_parms{phone_voicemail_number} : '0001112222';
    my $pin = ($Authorized) ? $config_parms{phone_voicemail_pin} : '9999';
    return qq[
<form method="POST" ACTION='http://messagecenter.mci.com/secure/login.jsp' NAME="login_form">
<input type="hidden" size="12" name="partnername" value="">
<input type="hidden" size="10" name="user_name" value='$phone'>
<input type="hidden" size="4"  name="password"  value='$pin'>
<input type="image" src="images/voicemails.gif" border=0 value="Submit" name="submit" border=0 alt="Submit">
</form>
];
}

elsif ( 'asterisk' eq lc $config_parms{phone_voicemail_type} ) {
    my $mailbox = ($Authorized) ? $config_parms{phone_voicemail_number} : '25';
    my $pin = ($Authorized) ? $config_parms{phone_voicemail_pin} : '9999';
    return qq[<form method="POST"
ACTION='$config_parms{phone_voicemail_url}'
NAME="login_form">
<input type="hidden" size="12" name="action" value='login'>
<input type="hidden" size="10" name="mailbox" value='$mailbox'>
<input type="hidden" size="4"  name="password"  value='$pin'>
<input type="image" src="images/voicemails.gif" border=0 value="Submit"
name="submit" alt="Voicemail">
</form>];
}
elsif ( 'vocp' eq lc $config_parms{phone_voicemail_type} ) {
    return
      qq[<a href='sub?vocp_display_voicemail'><img src="images/voicemails.gif" alt='Voice Mail' border=0></a>];

}

else {
    return
      qq[<a href='voicemail.shtml'><img src="images/voicemails.gif" alt='Voice mail' border=0></a><br>];
}
