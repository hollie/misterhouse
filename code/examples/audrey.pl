
# Category = Misc

=begin comment

This is an example of controling the led and screen on the audrey.

For this to work, you need to update your Audrey to allow for
control from external browsers.   Instructions for this, can be found
here:

  http://homepage.mac.com/deandavis/audrey/AudreyOnOff.html

Also change the http://audrey urls to the appropriate ip address,
or update your hosts file.  

On my windows box, this file is \windows\system32\drivers\etc\hosts
On unix, it is in /etc/hosts

=cut

$v_audrey_led = new Voice_Cmd("Audrey Led [on,off,blink]");
if ( $state = said $v_audrey_led) {
    print_log "Audrey led set to $state";
    $state = 0 if $state eq 'off';
    $state = 1 if $state eq 'blink';
    $state = 2 if $state eq 'on';
    get "http://audrey/cgi-bin/SetLEDState?$state";
}

$v_audrey_screen = new Voice_Cmd("Audrey screen [on,off]");
if ( $state = said $v_audrey_screen) {
    print_log "Audrey screen set to $state";
    $state = 0 if $state eq 'off';
    $state = 3 if $state eq 'on';
    get "http://audrey/gpio.shtml?$state";
}

