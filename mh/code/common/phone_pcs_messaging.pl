#Begin phone_pcs_messaging.pl
# Category = Phone
#
# 2002 Dec 22 - V 1.0  Steve Switzer
#    Original creation
# 2002 Dec 23 - V 1.1  Steve Switzer
#    Added support for Cingular
# 2005 Jan 2 - Joel Moore
#    Added support for Nextel
#

#@ Allows sending of short messages to PCS cell phones.
#@ This requires .INI parms for each phone:
#@ phone_pcs_NAME_number=1234567890
#@ phone_pcs_NAME_service=sprint  #(sprint, verizon, t-mobile, cingular or nextel)


$pcs_phone_test = new Voice_Cmd 'Send test message to [pcs, P C S] phone';
if (said $pcs_phone_test) {
  my $subject="Hi from MisterHouse: $Time_Now";
  &send_pcs_phone(who=>"test",msg=>$subject);
  return;
  my $fake_pcs_phone_var=$config_parms{phone_pcs_test_number};
  my $fake_pcs_phone_var2=$config_parms{phone_pcs_test_service};
}

sub send_pcs_phone {
  my %parms = @_;
  my $pcsnumberparm;my $pcsserviceparm;my $pcsservice;my $pcsnumber;my $addr;
  $pcsnumberparm="phone_pcs_${parms{who}}_number";
  $pcsserviceparm="phone_pcs_${parms{who}}_service";
  $pcsnumber=$config_parms{$pcsnumberparm};
  $pcsservice=$config_parms{$pcsserviceparm};
  if ($parms{msg} eq '') {print_log "PCS ERROR: Cannot send a blank message!";return;}
  if ($pcsnumber eq '') {print_log "PCS ERROR: Number not found for '$parms{who}'";return;}
  if ($pcsservice eq '') {print_log "PCS ERROR: Service not found for '$parms{who}'";return;}
  print_log "PCS: who=$parms{who}, msg=$parms{msg}";
  $addr="$pcsnumber\@messaging.sprintpcs.com"     if lc $pcsservice eq 'sprint';
  $addr="$pcsnumber\@vtext.com"                   if lc $pcsservice eq 'verizon';
  $addr="$pcsnumber\@tmomail.net"                 if lc $pcsservice eq 't-mobile';
  $addr="$pcsnumber\@mycingular.net"              if lc $pcsservice eq 'cingular';
  $addr="$pcsnumber\@messaging.nextel.com"        if lc $pcsservice eq 'nextel';
  if ($addr eq '') {print_log "PCS ERROR: Service with name \"$pcsservice\" is not supported.";return;}
  net_mail_send(to => $addr, msg => $parms{msg}, subject => $parms{msg});
}
#End phone_pcs_messaging.pl
