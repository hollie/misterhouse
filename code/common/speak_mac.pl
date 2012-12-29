
# Category = MisterHouse

#@ Enables speech on the Mac

=begin comment 

The original code relied on Mac::Speech. This module in return relies on
a Carbon module that only compiles op 32-bit installations.
In the time of 64-bit installs, this no longer works.

I have replaced it by a simple call to the OS X built-in 'say' command.

Seems to work fine, but it doesn't allow you routing the sound output to
other machines.
 
=cut


# noloop=start
# noloop=stop

sub speak_mac {
  print "Speak_mac @_\n";
  my ($mac_text) = @_;
  run "say $mac_text";
}
