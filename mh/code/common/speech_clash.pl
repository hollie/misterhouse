# Category = Speech

#@ One some systems, when two or more speech events are too close, only the fisrt will be
#@ granted access to the audio device. The second and third may cause the PA relays to be
#@ set for their speech events, even thought they cannot speak, and the first event hasn't
#@ finished. This code creates a "queue" of overlapping seech events, and fires them when
#@ "is_speeking()" is false.
#@ Seems to be necessary with Cepstral's Theta under Unix.

=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	speech_clash.pl

Description:
	Resolves issues of two or more speech events trying to run overlapping

Author:
	Steve Switzer
	steve@switzerny.org

License:
	This free software is licensed under the terms of the GNU public license.

Special Thanks to:
	Bruce Winter - MH, and much programming help

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

sub speak_clash_stub {
   my ($ref) = @_;
   &print_log("Clash control stub called!") if $main::Debug{voice};
   if (1 == &Voice_Text::is_speaking() && $$ref{to_file} eq '') {
      if ($main::Debug{voice}) {
         $$ref{clash_retry}=0 unless $$ref{clash_retry};
         $$ref{clash_retry}++; #To track how many loops are made
      }
      $$ref{nolog}=1;       #To stop MH from logging the speech again
      &print_log("SPEAK CLASH($$ref{clash_retry}): Delaying speech call for " . $$ref{text} . "\n") if $main::Debug{voice};
      my $parmstxt;
      my ($pkey,$pval);
      while (($pkey,$pval) = each(%{$ref})) {
         $parmstxt.=', ' if $parmstxt;
         $parmstxt.="$pkey => '$pval'";
      }
      &print_log("CLASH Parameters: $parmstxt") if $main::Debug{voice};
      &run_after_delay(2, "speak($parmstxt);");
      $$ref{no_speak}=1;    #To stop MH from speaking this time around
      return;
   }

   if ($$ref{clash_retry}) {
      &print_log("SPEAK CLASH: Resolved, continuing speech.") if $main::Debug{voice};
      $is_speaking=0;
      $is_speaking_flag=0;
   }
}

&Speak_parms_add_hook(\&speak_clash_stub) if $Reload;

=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
End of speech_clash.pl
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

!DSPAM:408bfdde70931011919926!
