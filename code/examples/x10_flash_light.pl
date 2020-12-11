
=begin comment
 
From Kirk Bauer on 10/2003

I thought I would share this with others as they might find it useful.
I don't have sound (yet), but would like to know that Misterhouse got my
command (like home/away/awake/asleep) since they are done by dumb X10
controllers and traffic might cause them not to be received.  But this
could also be used instead of voice confirmation when somebody is
sleeping (for example).

Basically I just use this function to signal by blinking a light a
certain number of times.  I have just rewritten it to be quicker by
sending X10 commands directly (and more efficiently).

The arguments are:
  Arg1: Which X10 light to flash
  Arg2: How many times the light should turn ON (for example, if you set this
        to 2 but the light is already on it will just turn off and back on, 
        but if it was off initially it would turn on, off, and on again.
  Arg3: The final state, ON or OFF

=cut

my $X10_controller = new X10_Item;

sub Flash_Light ($$$) {
    my ( $light, $count, $final ) = @_;
    my $code = $light->{'x10_id'};
    my ( $hc, $uc ) = ( $code =~ /^X(.)(.)/ );
    my $cmd = "X$hc$uc";
    for ( my $i = 0; $i < $count; $i++ ) {
        $cmd .= "${hc}J${hc}K";
    }
    if ( $final eq OFF ) {
        $light->set_receive(OFF);
    }
    else {
        $light->set_receive(ON);
        $cmd .= "${hc}J";
    }
    print_log "FlashLights($code, $count, $final) sending '$cmd'\n"
      if $config_parms{x10_errata} >= 3;
    set $X10_controller $cmd;
}

