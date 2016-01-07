
# Modify this rule for use with get_email
# Rename to get_email_rule.pl to enable
#  - $from_full has the full email address, not just the name portion.
sub get_email_rule {
    my ( $from, $to, $subject, $from_full ) = @_;
    $from = 'The Mister House guys' if $to =~ /[mh]/;
    $from = 'The perl guys'         if $to =~ /Perl-Win32-Users/;
    $from = 'The phone guys'        if $to =~ /ktx/ or $subject =~ /kx-t/i;
    $from = 'junk mail'
      if $from =~ /\S+[0-9]{3,}/
      ;    # If we get a joe#### type address, assume it is junk mail.
    return if $from =~ /X10 Newsletter/;

    # These are not needed if using the MS TTS engine (it pronounces fred@placed.com ok)
    #   $from =~ s/\./ Dot /g ;     # ...change "." to the word "Dot"
    #   $from =~ s/\@/ At /g ;      # ...change \@  to the word "At"

    return $from;
}

return 1;
