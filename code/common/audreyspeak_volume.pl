# Category = Audrey

#@ This module augments audreyspeak.pl to add volume control to events
#@ played and spoken to an Audrey.
#@ If the volume isn't being adjusted before the audio plays, then
#@ use the parameter audrey_volume_pause to set the number of
#@ milliseconds the routine should sleep before allowing the audio to play.
#@ Using this parameter WILL cause MH to pause for that amount of time.
#@ Use the parameter only if you must.

# $Date$
# $Revision$

=begin comment

audreyspeak_volume.pl

 1.0 Original version by Troy Carpenter <troy@carpenter.cx> - 5/24/06
     Based on code from audreyspeak.pl

This script augments audreyspeak.pl by adding volume control to events.

You don't necessarily need to activate audreyspeak.pl for this module, but
it probably won't be useful otherwise.  That means that you must also meet 
the requirements for that module.

In addition to the instructions in audreyspeak.pl you will need
(this is already in the MrAudrey image):

- Install volume.shtml on the Audrey
  1) Start the "Root Shell"
  2) type: cd /data/XML
  3) type: ftp blah.com volume.shtml

     The volume.shtml file placed on the Audrey should contain the following:

    <html><head><title>Shell</title></head><body>
    <!--#config cmdecho="OFF" -->
    <!--#exec cmd="volume $QUERY_STRING &" -->
    </body></html>

- By default, volume adjustments will will be pushed to ALL audrey's
  regardless of the value in the speak/play "rooms" parameter.  If you
  want the audrey's to honor the rooms parameter, then you must define
  the audrey_use_rooms parameter in my.private.ini

  audrey_use_rooms=1

- If you regularly experience cases where the volume is not adjusted before
  the audio starts to play on the Audrey (or the volume adjusts WHILE the
  audio is playing), then define a variable called audrey_volume_pause in
  my.private.ini to define the number of milliseconds to pause after setting
  the volume.

  audrey_volume_pause = 500
    (will pause for 500 ms (1/2 second) after setting the volume to allow the
    Audrey to finish the task before playing the audio.

=cut

#Tell MH to call our routine each time something is spoken or played
&Speak_parms_add_hook( \&Audrey_volume_adjust ) if $Reload;
&Play_parms_add_hook( \&Audrey_volume_adjust )  if $Reload;

my ( $audreyWrIndex, $audreyRdIndex, $audreyMaxIndex, @speakRooms,
    @speakVolume );

#MH is about to say or play something.  Adjust the volume if necessary.
sub Audrey_volume_adjust {
    my ($parms) = @_;
    my $volume = $$parms{volume};
    return
      if !$volume
      or (  $Save{mode}
        and ( $Save{mode} eq 'mute' or $Save{mode} eq 'offline' )
        and $$parms{mode} !~ /unmute/i );
    $volume =~ s/%//g
      ; # Audrey doesn't like percent signs in the volume setting.  It should be a raw number from 0 to 100.

    #   my $MHWeb = get_ip_address . ":" . $config_parms{http_port};
    #   my $MHWeb = hostname() . ":" . $config_parms{http_port};
    my $MHWeb = $Info{IPAddress_local} . ":" . $config_parms{http_port};
    my @rooms = split ',', lc $$parms{rooms};

    # determine which if any audreys to adjust the volume based on rooms paramter
    # whenever audrey_use_rooms is defined, otherwise, we send to all audreys
    if ( !exists $config_parms{audrey_use_rooms} || grep( /all/, @rooms ) ) {
        @rooms = ();
        for my $audrey ( split ',', $config_parms{Audrey_IPs} ) {
            $audrey =~ /(\S+)\-(\S+)/;
            my $room = lc $1;
            my $ip   = $2;
            push @rooms, $room;
            run "get_url -quiet http://$ip/volume.shtml?$volume /dev/null";
        }
    }
    else {
        my @audreyRooms = ();
        for my $audrey ( split ',', $config_parms{Audrey_IPs} ) {
            $audrey =~ /(\S+)\-(\S+)/;
            my $room = lc $1;
            my $ip   = $2;
            if ( grep( /$room/, @rooms ) ) {
                push @audreyRooms, $room;
                run
                  "get_url -quiet http://$ip/cgi-bin/volume?$volume /dev/null";
            }
        }
        @rooms = @audreyRooms;
    }
    return if ( !@rooms );

    &sleep_time( $config_parms{audrey_volume_pause} )
      if $config_parms{audrey_volume_pause};
}
