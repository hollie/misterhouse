
                                # Modify this rule for use with get_email
                                # Rename to get_email_rule.pl to enable
sub get_email_rule {
    my ($from, $to, $subject) = @_;
    $from = 'The S F gals'          if $to =~ /FEM-SF/;
    $from = 'The E C S guys'        if $to =~ /ecs/;
    $from = 'The Mister House guys' if $to =~ /misterhouse/;
    $from = 'The perl guys'         if $to =~ /Perl-Win32-Users/;
    $from = 'The phone guys'        if $to =~ /ktx/ or $subject =~ /kx-t/i;
    $from = 'junk mail'             if $from =~ /\S+[0-9]{3,}/; # If we get a joe#### type address, assume it is junk mail.
    return                          if $from =~ /X10 Newsletter/;
    return $from;
}

return 1;
