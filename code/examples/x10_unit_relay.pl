
=begin comment 

From David Norwood on 09/2003:

> What I'm trying to do is create a "virtual" X10 device, effectively
> listening for one X10 address and relaying all commands to another.

Misterhouse has to see the N2 and the N On commands together and within a
short time to recognize it as N2 On.  The N2 by itself is what causes the
"manual" state.

I think you would be better off working at a lower level, like the rf relay
script.  Check out the attached script I whipped up.  Make sure you wait a
few seconds between button pushes.

=cut

# Category = X10

my $source = 'N2';
my $target = 'A4';
my $current_unit;
my $h1 = substr $source, 0, 1;
my $h2 = substr $target, 0, 1;

$X10_controller = new X10_Item;
Serial_data_add_hook( \&x10_unit_relay ) if $Reload;

sub x10_unit_relay {
    my $state = shift;
    return unless $state =~ /^X/;

    #print "db s=$state h1=$1 c=$current_unit \n";
    $current_unit = $1 if ( $state =~ /^X([A-P][1-9A-G])/ );
    if ( $current_unit eq $source ) {
        my $new_state = $state;
        $new_state =~ s/$source/$target/g;
        $new_state =~ s/$h1([JKLM])/$h2$1/g;
        if ( $new_state ne $state ) {
            $new_state =~ s/^X/X$target/ unless $new_state =~ /^X$target/;
            print_log "Relaying X10 data: $state -> $new_state"
              if $config_parms{x10_errata} >= 3;
            set $X10_controller $new_state;
        }
    }
}

