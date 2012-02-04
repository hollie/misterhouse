# Category = Android

# $Date: 2007-08-04 20:37:08 -0400 (Sat, 04 Aug 2007) $
# $Revision: 1146 $

#@ This module allows MisterHouse to capture and send all speech and played
#@ wav files to an Android internet appliance. See the detailed instructions
#@ in the script for Android set-up information.

=begin comment

androidspeak.pl

This script allows MisterHouse to capture and send speech and played
wav files to an Android unit.

- By default, ALL speak and play events will be pushed to ALL android's
  regardless of the value in the speak/play "rooms" parameter.  If you
  want the android's to honor the rooms parameter, then you must define
  the android_use_rooms parameter in my.private.ini.  Each android declares
  a room name when the android registers with the server.

  android_use_rooms=1

=cut

use Voice_Text;

my (%androidClients);

#Tell MH to call our routine each time something is spoken
if ($Startup or $Reload) {
    &Speak_parms_add_hook(\&pre_speak_to_android);
}

$android_server = new Socket_Item(undef, undef, 'server_android');
if ($state = said $android_server) {
    my ($pass, $android_device, $port, $room) = split /,/, $state;
    &print_log ("android_server pass: $pass android_device: $android_device, port: $port, room: $room") if $Debug{android};
    if (my $user = password_check $pass, 'server_android') {
        &print_log ("Android Connect accepted for: room: $room at device: $android_device") if $Debug{android};
	my $client = $Socket_Ports{'server_proxy'}{socka};
	$room = $client unless defined $room;
	&print_log("android_register: $client $room") if $Debug{android};
	$androidClients{$client}{room} = $room;
    }
    else {
        &print_log ("Android Connect denied for: $room at $android_device") if $Debug{android};
    }
}

sub file_ready_for_android {
    my (%parms) = @_;
    my $speakFile = $parms{web_file};
    &print_log("file ready for android $speakFile") if $Debug{android};
    my @rooms = $parms{androidSpeakRooms};
    foreach my $android (keys %androidClients) {
        my $room = lc $androidClients{$android}{room};
	&print_log("file_ready_for_android client: $android room: $room") if $Debug{android};
       if ( grep(/$room/, @{$parms{androidSpeakRooms}}) ) {
	    my $function = "speak";
#if ($android->active( )) {
		$android_server->set(join '?', $function, $speakFile), $android;
#}
	}
    }
}

#MH just said something. Generate the same thing to our file (which is monitored above)
sub pre_speak_to_android {
    my ($parms_ref) = @_;
    &print_log("pre_speak_to_android $parms_ref->{web_file}") if $Debug{android};
    return if $parms_ref->{mode} and ($parms_ref->{mode} eq 'mute' or $parms_ref->{mode} eq 'offline');
    return if $Save{mode} and ($Save{mode} eq 'mute' or $Save{mode} eq 'offline') and $parms_ref->{mode} !~ /unmute/i;
    my @rooms = split ',', lc $parms_ref->{rooms};

    # determine which if any androids to speak to; we honor the rooms paramter 
    # whenever android_use_rooms is defined, otherwise, we send to all androids
    if (!exists $config_parms{android_use_rooms} || !exists $parms_ref->{rooms} || grep(/all/, @rooms) ) {
      @rooms = ();
      foreach my $android (keys %androidClients) {
	  my $room = lc $androidClients{$android}{room};
	  &print_log("pre_speak_to_android client: $android room: $room") if $Debug{android};
	  push @rooms, $room;
      }
    } else {
      my @androidRooms = ();
      foreach my $android (keys %androidClients) {
	  my $room = lc $androidClients{$android}{room};
	  if ( grep(/$room/, @rooms) ) {
	      push @androidRooms, $room;
	  }
      }
      @rooms = @androidRooms;
    }
    &print_log("pre_speak_to_android rooms: @rooms") if $Debug{android};
    return if (!@rooms);

    # okay, process the speech and add to the process array
    $parms_ref->{web_file} = "web_file";
    push(@{$parms_ref->{androidSpeakRooms}},@rooms);
    push @{$parms_ref->{web_hook}},\&file_ready_for_android;
    $parms_ref->{async} = 1;
    $parms_ref->{async} = 0 if $config_parms{Android_speak_sync};
}

#Tell MH to call our routine each time a wav file is played
&Play_parms_add_hook(\&pre_play_to_android) if $Reload;

#MH just played a wav file. Copy it to our file (which is monitored above)
sub pre_play_to_android {
    my ($parms_ref) = @_;
    &print_log("pre play to android") if $Debug{android};
    return if $Save{mode} and ($Save{mode} eq 'mute' or $Save{mode} eq 'offline') and $parms_ref->{mode} !~ /unmute/i;

    # determine which if any androids to speak to; we honor the rooms parameter
    # whenever android_use_rooms is defined, otherwise, we send to all androids
    my @rooms = split ',', lc $parms_ref->{rooms};
    if (!exists $config_parms{android_use_rooms} || !exists $parms_ref->{rooms} || grep(/all/, @rooms) ) {
      @rooms = ();
      foreach my $android (keys %androidClients) {
        my $room = lc $androidClients{$android}{room};
        push @rooms, $room;
      }
    } else {
      my @androidRooms = ();
      foreach my $android (keys %androidClients) {
        my $room = lc $androidClients{$android}{room};
        if ( grep(/$room/, @rooms) ) {
          push @androidRooms, $room;
        }
      }
      @rooms = @androidRooms;
    }
    return if (!@rooms);

    $parms_ref->{web_file} = "web_file";
    push(@{$parms_ref->{androidSpeakRooms}},@rooms);
    push(@{$parms_ref->{web_hook}},\&file_ready_for_android);
}
