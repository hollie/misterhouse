# Category = Appliances

# LitterFree.pl
# Author: Dan Hoffard
# Date: 1/20/06#

#@ For the LitterFree Automatic Flushing Cat Litter Box
#@ Used to sell for $300 on www.litterfree.com, company has gone out of business.
#@ Can be found easily on eBay for around $200

# The only flaw with the litterfree system is its inability to use sensors to detect
# when it is safe to flush.  This is easily accomplished with a single X10 appliance
# module, X10 sensor, and the following code.  Without this fix, you have to specify
# three "flush times" during the day.  If your cat is in the litterbox when it flushes,
# you just wasted $300, because it won't go near the litterbox again!

# Automatically flushes the litterbox when the cat is finished by cycling power.
# You must tape down the "start cycle" button on the unit.  Requires an X10
# appliance module ($LitterBox) and a sensor mounted inside the box ($Litterbox_Movement).

# Adjust the following two values to your preference
my $litter_timeout = 960
  ; # Time the sensor must be inactive before a flush begins.  Currently 16 minutes.
my $litter_cycle_timeout =
  1980;    # LitterFree cycle time (wash and dry).  It's about 33 minutes.

my $litterboxstate   = 'OFF';
my $littercyclestate = 'OFF';

$litter_timer       = new Timer();
$litter_cycle_timer = new Timer();

#  Cat enters the litter box (not during a cycle)
if (
    (
           state_now $Litterbox_Movement eq 'ON'
        or state_now $Litterbox_Movement eq 'on'
    )
    and ( expired $litter_cycle_timer or inactive $litter_cycle_timer)
  )
{
    set $litter_timer ($litter_timeout);
    if ( $Save{litterboxstate} ne 'OFF' ) {
        set $LitterBox OFF;
        print_log "Turning off LitterFree at $Time_Now \n";
    }
    $Save{litterboxstate} = 'OFF';
}

# Cat is finished, time for flush
if ( ( expired $litter_timer or inactive $litter_timer )
    and $Save{litterboxstate} eq 'OFF' )
{
    set $LitterBox ON;
    set $litter_cycle_timer ($litter_cycle_timeout);
    $Save{litterboxstate}   = 'ON';
    $Save{littercyclestate} = 'ON';
    print_log "Starting a LitterFree cycle at $Time_Now \n";
}

# Flush complete
if ( ( expired $litter_cycle_timer or inactive $litter_cycle_timer)
    and $Save{littercyclestate} ne 'OFF' )
{
    $Save{littercyclestate} = 'OFF';
    $Save{litterboxstate}   = 'WAITING';
    set $LitterBox OFF;
    print_log "LitterFree cycle ended at $Time_Now \n";
}

#Safety check
if ( ( state $LitterBox eq 'on' or state $LitterBox eq 'ON' )
    and $Save{litterboxstate} ne 'ON' )
{
    set $LitterBox OFF;
}

if ( ( state $LitterBox eq 'off' or state $LitterBox eq 'OFF' )
    and $Save{litterboxstate} eq 'ON' )
{
    set $LitterBox ON;
}
