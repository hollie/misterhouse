# Name   : Win32::DUN.pm
# Author : Mike Blazer      blazer@mail.nevalink.ru
# Version: 0.02              Last Modified: May 18, 1998  11:42:45
# Tested :
# on GS port of Perl 5.004_02; Win'95
#====================================================================

package Win32::DUN;

srand time.$$;
use Win32::Registry;

$DIALER  = 'rasdial.exe';
$INIFILE = 'dialup.ini';

#==================
# import constants 
#==================

@constants = qw{
HKEY_CLASSES_ROOT
HKEY_CURRENT_USER
HKEY_LOCAL_MACHINE
HKEY_USERS
HKEY_PERFORMANCE_DATA
HKEY_CURRENT_CONFIG
HKEY_DYN_DATA
};
for (@constants) {
   eval "\$$_ = \$main::$_";
}

undef @constants;

#=========================
sub newDUNarray {
#=========================
# the same in HKEY_USERS/RemoteAccess
  local ($hkey);

  $HKEY_CURRENT_USER->Open('RemoteAccess', $hkey) || die $!;
  $hkey->Open('Profile', $hkey) || die $!;
  $hkey->GetKeys(\@ENTRIES) || die "DUN: Can't get keys for $object $!\n";
  $hkey->Close();

  @ENTRIES;
}

#=========================
sub GetRandEntry {
#=========================
  if (! defined @ENTRIES || scalar(@ENTRIES)==0) {
    newDUNarray();
    die "DUN: no dialup entries found.\n" if scalar(@ENTRIES)==0;
  }

  $ENTRIES[int rand @ENTRIES];
}

#=========================
sub DialSelectedEntry {
#=========================
  my ($entry, $user, $pass) = @_;
  my ($out, $EntryConn);
  my $found=0;
  local $_;

  die "DUN: DialSelectedEntry - not enough parameters.\n" if @_ < 3;

  if (! defined @ENTRIES || scalar(@ENTRIES)==0) {
    newDUNarray();
    die "DUN: no dialup entries found.\n" if scalar(@ENTRIES)==0;
  }

  die "DUN: dialing program not defined.\n" if !$DIALER;

  for (@ENTRIES) {
    if ($_ eq $entry) {
      $found=1; last;
    }
  }
  die "DUN: entry $entry is not defined in Dial-Up Networking.\n" if !$found;

  $EntryConn = CheckConnect();

  return ($EntryConn) if $EntryConn; # will not reconnect

  print "$DIALER '$entry' $user $pass\n";
  $out = `$DIALER "$entry" $user $pass`;

  return ( $out =~ /Successfully connected to (.+)/i )[0];
}

#=========================
sub HangUp {
#=========================
  my ($out, $entry);

  if (!$DIALER) { die "DUN: dialing program not defined.\n" }

  $out = `$DIALER /DISCONNECT`;

  if ($out =~ /No connections\r*\nCommand completed successfully\./i) {
    return;
  } else {
    return ( $out =~ /Successfully disconnected from (.+?)\./i )[0];
  }
}
#=========================
sub CheckConnect {
#=========================
# in fact this one checks if somebody _tries_ to establish connection.
# 0 - nobody even tries to
# DUN-entry - if Dial-Up Networking is at least activied

  my ($entry, $out);

  if (!$DIALER) { die "DUN: dialing program not defined.\n" }

  $out = `$DIALER`;

  if ($out =~ /No connections\r*\nCommand completed successfully\./i) {
    return;
  } else {
    return ( $out =~ /Connected to\r*\n(.+)\r*\nCommand completed successfully\./i)[0];
  }
}


#=========================
sub Reconnect {
#=========================
  HangUp(); # HangUp for reconnect

  sleep 2;

  DialSelectedEntry(@_);
}

#=========================
sub Autodial {
#=========================
# ask - 1/0 1- ask for each reconnection

  my ($entry, $user, $pass, $maxtimes, $pause, $ask) = @_;
  my ($EntryConn);

  die "DUN: Autodial - not enough parameters.\n" if @_ < 3;

  $pause    ||= 1;
  $pause--  if $ask;
  $maxtimes ||= 10000;
  
  while($maxtimes--) {

    ($EntryConn) = Reconnect($entry, $user, $pass);
    return ($EntryConn) if $EntryConn;

    return () if $maxtimes == 0;
    if ($ask) {
       sleep 1;
       return () unless ConnectAgain();
    }
    sleep $pause;
  }
}

#=========================
sub AutodialRand {
#=========================
# ask - 1/0 1- ask for each reconnection

  my ($maxtimes, $pause, $ask) = @_;
  my ($EntryConn, $ref);
  local ($_, $@);

  $pause    ||= 1;
  $pause--  if $ask;
  $maxtimes ||= 10000;

  unless (defined($DIALLIST) && @{$DIALLIST} > 0) {
    die "DUN: ini-file '$INIFILE' not found.\n"
	 unless -f $INIFILE && -r_;
    eval { require "$INIFILE" };
    die "DUN: ini-file bad format: $@\n" if $@;
  }
  
  while($maxtimes--) {
    $ref = $DIALLIST->[int rand @{$DIALLIST}];
#print map $ref->[$_], (0,1,2); print "\n";

    ($EntryConn) = Reconnect(map $ref->[$_], (0,1,2));
    return ($EntryConn) if $EntryConn;

    return () if $maxtimes == 0;
    if ($ask) {
       sleep 1;
       return () unless ConnectAgain();
    }
    sleep $pause;
  }
}

#=========================
sub MsgBox {
#=========================
   my ($caption, $message, $buttons, $icon) = @_;

# Buttons------              # Icons--------
#  0  Ok                     # 16  Hand
#  1  Ok, Cancel             # 32  Question
#  2  Abort, Retry, Ignore   # 48  Exclamation
#  3  Yes, No, Cancel        # 64  Asterisk
#  4  Yes, No
#  5  Retry, Cancel

   use Win32;

   (qw(. Ok Cancel Abort Retry Ignore Yes No))
	[Win32::MsgBox($message, $buttons | $icon, $caption)];
}

#=========================
sub ConnectAgain {
#=========================
MsgBox('ATTENTION!!!', "Connection failed.
Click \"RETRY\"  to dial again.
Click \"CANCEL\" to abort.\n", 5, 48) eq "Retry";
}

1;

