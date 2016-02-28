
#@ Used by bin/get_email to filter incoming email announcements

# Modify this rule for use with get_email
#  - $from_full has the full email address, not just the name portion.
sub get_email_rule {
    my ( $from, $to, $subject, $from_full, $body ) = @_;

    print
      "Debug in get_email_rule: to=$to from=$from from_full=$from_full subject=$subject\n"
      if $Debug{email};

    # Junk mail is out of control.   Filter only for good stuff
    return unless $from =~ /(winter|helen|nora)/i;

    my $from_words = () = $from =~ /\S+/g;

    return if $from =~ /^\s+$/;

    #   print "dbx1 email_rule f=$from. t=$to s=$subject\n";
    return if $from_full =~ /newsletter/;    # Covers [newsletter@x10.com]
    return 'The S F gals' if $to =~ /FEM-SF/;
    return 'The S F gals' if $to =~ /sfpanet/;
    return                if $to =~ /par\@/;
    return                if $subject =~ /\[TINI\]/;
    return                if $subject =~ /\[ECS\]/;
    return                if $subject =~ /\[ProGear\]/;
    return                if $to =~ /\.NET\@/;
    return 'The HA guys'  if $subject =~ /\[LHA/;
    return                if $subject =~ /xapautomation/;
    return                if $subject =~ /xAP_/i;
    return                if $subject =~ /_xpl/i;
    return                if $from =~ /emergencyemailnetwork.net/i;
    return                if $from =~ /InfoBeat/;
    return                if $from =~ /TipWorld/;
    return                if $from =~ /alert/i;
    return                if $from =~ /X10 Newsletter/;

    #   return                         if $subject =~ /test \d+/;
    return 'filtered no store'
      if $from =~ /get tv grid/;    # no store -> will not store in data/email
    return if $from =~ /Cron Daemon/;
    return if $from =~ /admin/i;
    return if $from =~ /postmaster/i;
    return if $from =~ /^mail/i;

    #   return                         if $from =~ /mailman-owner/i;
    #   return                         if $from =~ /Mail Delivery Subsystem/i;
    return                             if $from =~ /\?/;
    return 'The Mister House guys'     if $subject =~ /\[misterhouse-/;
    return 'The Mister House guys'     if $subject =~ /\[mh]/;
    return 'A Mister House subscriber' if $subject =~ /subscribe notification/i;
    return
      if $to =~ /listserv.activestate.com/i
      or $from_full =~ /listserv.activestate.com/i;
    return if $to =~ /perl-/i;
    return if $from_full =~ /perl-/i;
    return 'The phone guys' if $to =~ /ktx/ or $subject =~ /kx-t/i;
    return 'filtered - klug'
      if $to =~ /klug/i;    # filtered -> will not be spoken (like blank)
    return 'filtered no store'
      if $from =~ /\S+[0-9]{3,}/
      ;    # If we get a joe#### type address, assume it is junk mail.
    return 'filtered no store'
      if $from =~
      /[0-9]{5,}/;   # If we get a ######  type address, assume it is junk mail.
    return 'filtered no store' if $from_words > 3;

    #   return 'junk mail'             if $from =~ /[0-9]{5,}/;    # If we get a ######  type address, assume it is junk mail.

    $from =~ s/\./ Dot /g;    # ...change "." to the word "Dot"
    $from =~ s/\@/ At /g;     # ...change \@  to the word "At"

    return $from;
}

# from=Multiple Lenders Compete for your Loan

return 1;
