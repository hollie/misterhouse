
                                # Modify this rule for use with get_email
sub get_email_rule {
    my ($from, $to, $subject) = @_;

#   print "Debug in get_email_rule: to=$to from=$from subject=$subject\n";

    return 'The S F gals'          if $to =~ /FEM-SF/;
    return                         if $subject =~ /\[TINI\]/;
    return                         if $subject =~ /\[ECS\]/;
    return 'The HA guys'           if $subject =~ /\[LHA/;
    return                         if $from =~ /InfoBeat/;
    return                         if $from =~ /TipWorld/;
    return                         if $from =~ /X10 Newsletter/;
    return                         if $subject =~ /Car tracking report/;
    return                         if $from =~ /get tv grid/;
    return                         if $from =~ /Cron Daemon/;
    return 'The Mister House guys' if $subject =~ /\[misterhouse-/;
    return 'A new Mister House subscriber' if $subject =~ / subscribe notification/i;
    return 'The perl guys'         if $to =~ /Perl-Win32-Users/;
    return 'The phone guys'        if $to =~ /ktx/ or $subject =~ /kx-t/i;
    return                         if $to =~ /klug/;
    return 'junk mail'             if $from =~ /\S+[0-9]{3,}/; # If we get a joe#### type address, assume it is junk mail.
    return 'junk mail'             if $from =~ /[0-9]{5,}/;    # If we get a ######  type address, assume it is junk mail.
    return $from;
}

return 1;
