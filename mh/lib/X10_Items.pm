
package X10_Item;

my (%items_by_house_code, %appliances_by_house_code);

#&main::Reload_post_hook(\&X10_Item::reset, 1) if $Startup;

sub reset {
#   print "\n\nRunning X10_Item reset\n\n\n";
    undef %items_by_house_code;
    undef %appliances_by_house_code;
}

@X10_Item::ISA = ('Serial_Item');

sub new {
    my ($class, $id, $interface) = @_;
    my $self = {};
    $$self{state} = '';     # Only items with state defined are controlable from web interface

    bless $self, $class;

#   print "\n\nWarning: duplicate ID codes on different X10_Item objects: id=$id\n\n" if $serial_item_by_id{$id};

    my $hc = substr($id, 0, 1);
    push @{$items_by_house_code{$hc}}, $self;
    $id = "X$id";
    $self->{x10_id} = $id;

                                # Setup house only codes:     e.g. XAO, XAP, XA+20
                                #  - allow for all bright/dim commands so we can detect incoming signals
    if (length($id) == 2) {
        $self-> add ($id . 'O', 'on');
        $self-> add ($id . 'P', 'off');
        $self-> add ($id . '+5',  '+5');
        $self-> add ($id . '+10', '+10');
        $self-> add ($id . '+15', '+15');
        $self-> add ($id . '+20', '+20');
        $self-> add ($id . '+25', '+25');
        $self-> add ($id . '+30', '+30');
        $self-> add ($id . '+35', '+35');
        $self-> add ($id . '+40', '+40');
        $self-> add ($id . '+45', '+45');
        $self-> add ($id . '+50', '+50');
        $self-> add ($id . '+55', '+55');
        $self-> add ($id . '+60', '+60');
        $self-> add ($id . '+65', '+65');
        $self-> add ($id . '+70', '+70');
        $self-> add ($id . '+75', '+75');
        $self-> add ($id . '+80', '+80');
        $self-> add ($id . '+85', '+85');
        $self-> add ($id . '+90', '+90');
        $self-> add ($id . '+95', '+95');
        $self-> add ($id . '+100', '+100');
        $self-> add ($id . '-5',  '-5');
        $self-> add ($id . '-10', '-10');
        $self-> add ($id . '-15', '-15');
        $self-> add ($id . '-20', '-20');
        $self-> add ($id . '-25', '-25');
        $self-> add ($id . '-30', '-30');
        $self-> add ($id . '-35', '-35');
        $self-> add ($id . '-40', '-40');
        $self-> add ($id . '-45', '-45');
        $self-> add ($id . '-50', '-50');
        $self-> add ($id . '-55', '-55');
        $self-> add ($id . '-60', '-60');
        $self-> add ($id . '-65', '-65');
        $self-> add ($id . '-70', '-70');
        $self-> add ($id . '-75', '-75');
        $self-> add ($id . '-80', '-80');
        $self-> add ($id . '-85', '-85');
        $self-> add ($id . '-90', '-90');
        $self-> add ($id . '-95', '-95');
        $self-> add ($id . '-100', '-100');
    }
                                # Setup unit-command  codes:  e.g. XA1AJ, XA1AK, XA1+20
                                # Note: The 0%->100% states are handled directly in Serial_Item.pm
    else {
        $self-> add ($id . $hc . 'J', 'on');
        $self-> add ($id . $hc . 'K', 'off');
        $self-> add ($id . $hc . 'L', 'brighten');
        $self-> add ($id . $hc . 'M', 'dim');
        $self-> add ($id . $hc . '+5',  '+5');
        $self-> add ($id . $hc . '+10', '+10');
        $self-> add ($id . $hc . '+15', '+15');
        $self-> add ($id . $hc . '+20', '+20');
        $self-> add ($id . $hc . '+25', '+25');
        $self-> add ($id . $hc . '+30', '+30');
        $self-> add ($id . $hc . '+35', '+35');
        $self-> add ($id . $hc . '+40', '+40');
        $self-> add ($id . $hc . '+45', '+45');
        $self-> add ($id . $hc . '+50', '+50');
        $self-> add ($id . $hc . '+55', '+55');
        $self-> add ($id . $hc . '+60', '+60');
        $self-> add ($id . $hc . '+65', '+65');
        $self-> add ($id . $hc . '+70', '+70');
        $self-> add ($id . $hc . '+75', '+75');
        $self-> add ($id . $hc . '+80', '+80');
        $self-> add ($id . $hc . '+85', '+85');
        $self-> add ($id . $hc . '+90', '+90');
        $self-> add ($id . $hc . '+95', '+95');
        $self-> add ($id . $hc . '+100', '+100');
        $self-> add ($id . $hc . '-5',  '-5');
        $self-> add ($id . $hc . '-10', '-10');
        $self-> add ($id . $hc . '-15', '-15');
        $self-> add ($id . $hc . '-20', '-20');
        $self-> add ($id . $hc . '-25', '-25');
        $self-> add ($id . $hc . '-30', '-30');
        $self-> add ($id . $hc . '-35', '-35');
        $self-> add ($id . $hc . '-40', '-40');
        $self-> add ($id . $hc . '-45', '-45');
        $self-> add ($id . $hc . '-50', '-50');
        $self-> add ($id . $hc . '-55', '-55');
        $self-> add ($id . $hc . '-60', '-60');
        $self-> add ($id . $hc . '-65', '-65');
        $self-> add ($id . $hc . '-70', '-70');
        $self-> add ($id . $hc . '-75', '-75');
        $self-> add ($id . $hc . '-80', '-80');
        $self-> add ($id . $hc . '-85', '-85');
        $self-> add ($id . $hc . '-90', '-90');
        $self-> add ($id . $hc . '-95', '-95');
        $self-> add ($id . $hc . '-100', '-100');

                                # These are added because perl interprets +10 the
                                # same as 10.  Ideally people would use '+10'
        $self-> add ($id . $hc . '+5',  5); # Allow for numeric (5 instead of '+5');
        $self-> add ($id . $hc . '+10', 10);
        $self-> add ($id . $hc . '+15', 15);
        $self-> add ($id . $hc . '+20', 20);
        $self-> add ($id . $hc . '+25', 25);
        $self-> add ($id . $hc . '+30', 30);
        $self-> add ($id . $hc . '+35', 35);
        $self-> add ($id . $hc . '+40', 40);
        $self-> add ($id . $hc . '+45', 45);
        $self-> add ($id . $hc . '+50', 50);
        $self-> add ($id . $hc . '+55', 55);
        $self-> add ($id . $hc . '+60', 60);
        $self-> add ($id . $hc . '+65', 65);
        $self-> add ($id . $hc . '+70', 70);
        $self-> add ($id . $hc . '+75', 75);
        $self-> add ($id . $hc . '+80', 80);
        $self-> add ($id . $hc . '+85', 85);
        $self-> add ($id . $hc . '+90', 90);
        $self-> add ($id . $hc . '+95', 95);
        $self-> add ($id . $hc . '+100', 100);

        $self-> add ($id . $hc . 'STATUS', 'status');
        $self-> add ($id , 'manual'); # Used in Group.pm.  This is what we get with a manual kepress, with on ON/OFF after it

    }

    $self->set_interface($interface);

    return $self;
}

sub set_with_timer {
    my ($self, $state, $time) = @_;
    
    $self->set($state);
    return unless $time;

                                # If off, timeout to on, otherwise timeout to off
    my $state_change = ($state eq 'off') ? 'on' : 'off';

#   my $x10_timer = new  main::Timer;
    my $x10_timer = &Timer::new();
    my $object = $self->{object_name};
    my $action = "set $object '$state_change'";
#   my $action = "&X10_Items::set($object, '$state_change')";
#   print "db Setting x10 timer $x10_timer: self=$self time=$time action=$action\n";
#   $x10_timer->set($time, $action);
    &Timer::set($x10_timer, $time, $action);

}

sub set_by_housecode {
    my ($hc, $state) = @_;
    for my $object (@{$items_by_house_code{$hc}}) {
        print "Setting X10 House code $hc item $object to $state\n" if $main::config_parms{debug} eq 'X10';
        set_receive $object $state;
    }

    return if $state eq 'on';     # All lights on does not effect appliances

    for my $object (@{$appliances_by_house_code{$hc}}) {
        print "Setting X10 House code $hc appliance $object to $state\n" if $main::config_parms{debug} eq 'X10';
        set_receive $object $state;
    }
        
}

package X10_Appliance;

#@X10_Appliance::ISA = ("Serial_Item");
@X10_Appliance::ISA = ('X10_Item');

sub new {
    my ($class, $id, $interface) = @_;
    my $self = {};
    $$self{state} = '';

    bless $self, $class;

#   print "\n\nWarning: duplicate ID codes on different X10_Appliance objects: id=$id\n\n" if $serial_item_by_id{$id};

    my $hc = substr($id, 0, 1);
    push @{$appliances_by_house_code{$hc}}, $self;
    $id = "X$id";
    $self->{x10_id} = $id;

    $self-> add ($id . $hc . 'J', 'on');
    $self-> add ($id . $hc . 'K', 'off');
    $self-> add ($id , 'manual');

    $self->set_interface($interface);

    return $self;
}


package X10_Garage_Door;

@X10_Garage_Door::ISA = ('X10_Item');

sub new {
    my ($class, $id, $interface) = @_;
    my $self = {};
    $$self{state} = ''; 

    bless $self, $class;

    print "\n\nWarning: X10_Garage_Door object should not specify unit code; ignored\n\n" if length($id) > 1;
    my $hc = substr($id, 0, 1); 
    $id = "X$hc" . 'Z';
#   print "\n\nWarning: duplicate ID codes on different X10_Garage_Door objects: id=$id\n\n" if $serial_item_by_id{$id};
    $self->{x10_id} = $id;

# Returned state is "bbbdccc"
# "bbb" is 1=door enrolled, 0=enrolled, indexed by door # (i.e. 123)
# "d" is door that caused transmission, numeric 1, 2, or 3
# "ccc" is C=Closed, O=Open, indexed by door #

    $self-> add ($id . '00001d',   '0000CCC');    # Only on initial power up of receiver; no doors enrolled.

    $self-> add ($id . '01101d',   '1001CCC'); 
    $self-> add ($id . '01111d',   '1001OCC');
    $self-> add ($id . '01121d',   '1001COC');
    $self-> add ($id . '01131d',   '1001OOC');
    $self-> add ($id . '01141d',   '1001CCO');
    $self-> add ($id . '01151d',   '1001OCO');
    $self-> add ($id . '01161d',   '1001COO');
    $self-> add ($id . '01171d',   '1001OOO');
    $self-> add ($id . '01201d',   '1002CCC');
    $self-> add ($id . '01211d',   '1002OCC');
    $self-> add ($id . '01221d',   '1002COC');
    $self-> add ($id . '01231d',   '1002OOC');
    $self-> add ($id . '01241d',   '1002CCO');
    $self-> add ($id . '01251d',   '1002OCO');
    $self-> add ($id . '01261d',   '1002COO');
    $self-> add ($id . '01271d',   '1002OOO');
    $self-> add ($id . '01401d',   '1003CCC');
    $self-> add ($id . '01411d',   '1003OCC');
    $self-> add ($id . '01421d',   '1003COC');
    $self-> add ($id . '01431d',   '1003OOC');
    $self-> add ($id . '01441d',   '1003CCO');
    $self-> add ($id . '01451d',   '1003OCO');
    $self-> add ($id . '01461d',   '1003COO');
    $self-> add ($id . '01471d',   '1003OOO');

    $self-> add ($id . '02101d',   '0101CCC'); 
    $self-> add ($id . '02111d',   '0101OCC');
    $self-> add ($id . '02121d',   '0101COC');
    $self-> add ($id . '02131d',   '0101OOC');
    $self-> add ($id . '02141d',   '0101CCO');
    $self-> add ($id . '02151d',   '0101OCO');
    $self-> add ($id . '02161d',   '0101COO');
    $self-> add ($id . '02171d',   '0101OOO');
    $self-> add ($id . '02201d',   '0102CCC');
    $self-> add ($id . '02211d',   '0102OCC');
    $self-> add ($id . '02221d',   '0102COC');
    $self-> add ($id . '02231d',   '0102OOC');
    $self-> add ($id . '02241d',   '0102CCO');
    $self-> add ($id . '02251d',   '0102OCO');
    $self-> add ($id . '02261d',   '0102COO');
    $self-> add ($id . '02271d',   '0102OOO');
    $self-> add ($id . '02401d',   '0103CCC');
    $self-> add ($id . '02411d',   '0103OCC');
    $self-> add ($id . '02421d',   '0103COC');
    $self-> add ($id . '02431d',   '0103OOC');
    $self-> add ($id . '02441d',   '0103CCO');
    $self-> add ($id . '02451d',   '0103OCO');
    $self-> add ($id . '02461d',   '0103COO');
    $self-> add ($id . '02471d',   '0103OOO');

    $self-> add ($id . '03101d',   '1101CCC'); 
    $self-> add ($id . '03111d',   '1101OCC');
    $self-> add ($id . '03121d',   '1101COC');
    $self-> add ($id . '03131d',   '1101OOC');
    $self-> add ($id . '03141d',   '1101CCO');
    $self-> add ($id . '03151d',   '1101OCO');
    $self-> add ($id . '03161d',   '1101COO');
    $self-> add ($id . '03171d',   '1101OOO');
    $self-> add ($id . '03201d',   '1102CCC');
    $self-> add ($id . '03211d',   '1102OCC');
    $self-> add ($id . '03221d',   '1102COC');
    $self-> add ($id . '03231d',   '1102OOC');
    $self-> add ($id . '03241d',   '1102CCO');
    $self-> add ($id . '03251d',   '1102OCO');
    $self-> add ($id . '03261d',   '1102COO');
    $self-> add ($id . '03271d',   '1102OOO');
    $self-> add ($id . '03401d',   '1103CCC');
    $self-> add ($id . '03411d',   '1103OCC');
    $self-> add ($id . '03421d',   '1103COC');
    $self-> add ($id . '03431d',   '1103OOC');
    $self-> add ($id . '03441d',   '1103CCO');
    $self-> add ($id . '03451d',   '1103OCO');
    $self-> add ($id . '03461d',   '1103COO');
    $self-> add ($id . '03471d',   '1103OOO');

    $self-> add ($id . '04101d',   '0011CCC'); 
    $self-> add ($id . '04111d',   '0011OCC');
    $self-> add ($id . '04121d',   '0011COC');
    $self-> add ($id . '04131d',   '0011OOC');
    $self-> add ($id . '04141d',   '0011CCO');
    $self-> add ($id . '04151d',   '0011OCO');
    $self-> add ($id . '04161d',   '0011COO');
    $self-> add ($id . '04171d',   '0011OOO');
    $self-> add ($id . '04201d',   '0012CCC');
    $self-> add ($id . '04211d',   '0012OCC');
    $self-> add ($id . '04221d',   '0012COC');
    $self-> add ($id . '04231d',   '0012OOC');
    $self-> add ($id . '04241d',   '0012CCO');
    $self-> add ($id . '04251d',   '0012OCO');
    $self-> add ($id . '04261d',   '0012COO');
    $self-> add ($id . '04271d',   '0012OOO');
    $self-> add ($id . '04401d',   '0013CCC');
    $self-> add ($id . '04411d',   '0013OCC');
    $self-> add ($id . '04421d',   '0013COC');
    $self-> add ($id . '04431d',   '0013OOC');
    $self-> add ($id . '04441d',   '0013CCO');
    $self-> add ($id . '04451d',   '0013OCO');
    $self-> add ($id . '04461d',   '0013COO');
    $self-> add ($id . '04471d',   '0013OOO');

    $self-> add ($id . '05101d',   '1011CCC'); 
    $self-> add ($id . '05111d',   '1011OCC');
    $self-> add ($id . '05121d',   '1011COC');
    $self-> add ($id . '05131d',   '1011OOC');
    $self-> add ($id . '05141d',   '1011CCO');
    $self-> add ($id . '05151d',   '1011OCO');
    $self-> add ($id . '05161d',   '1011COO');
    $self-> add ($id . '05171d',   '1011OOO');
    $self-> add ($id . '05201d',   '1012CCC');
    $self-> add ($id . '05211d',   '1012OCC');
    $self-> add ($id . '05221d',   '1012COC');
    $self-> add ($id . '05231d',   '1012OOC');
    $self-> add ($id . '05241d',   '1012CCO');
    $self-> add ($id . '05251d',   '1012OCO');
    $self-> add ($id . '05261d',   '1012COO');
    $self-> add ($id . '05271d',   '1012OOO');
    $self-> add ($id . '05401d',   '1013CCC');
    $self-> add ($id . '05411d',   '1013OCC');
    $self-> add ($id . '05421d',   '1013COC');
    $self-> add ($id . '05431d',   '1013OOC');
    $self-> add ($id . '05441d',   '1013CCO');
    $self-> add ($id . '05451d',   '1013OCO');
    $self-> add ($id . '05461d',   '1013COO');
    $self-> add ($id . '05471d',   '1013OOO');

    $self-> add ($id . '06101d',   '0111CCC'); 
    $self-> add ($id . '06111d',   '0111OCC');
    $self-> add ($id . '06121d',   '0111COC');
    $self-> add ($id . '06131d',   '0111OOC');
    $self-> add ($id . '06141d',   '0111CCO');
    $self-> add ($id . '06151d',   '0111OCO');
    $self-> add ($id . '06161d',   '0111COO');
    $self-> add ($id . '06171d',   '0111OOO');
    $self-> add ($id . '06201d',   '0112CCC');
    $self-> add ($id . '06211d',   '0112OCC');
    $self-> add ($id . '06221d',   '0112COC');
    $self-> add ($id . '06231d',   '0112OOC');
    $self-> add ($id . '06241d',   '0112CCO');
    $self-> add ($id . '06251d',   '0112OCO');
    $self-> add ($id . '06261d',   '0112COO');
    $self-> add ($id . '06271d',   '0112OOO');
    $self-> add ($id . '06401d',   '0113CCC');
    $self-> add ($id . '06411d',   '0113OCC');
    $self-> add ($id . '06421d',   '0113COC');
    $self-> add ($id . '06431d',   '0113OOC');
    $self-> add ($id . '06441d',   '0113CCO');
    $self-> add ($id . '06451d',   '0113OCO');
    $self-> add ($id . '06461d',   '0113COO');
    $self-> add ($id . '06471d',   '0113OOO');

    $self-> add ($id . '07101d',   '1111CCC'); 
    $self-> add ($id . '07111d',   '1111OCC');
    $self-> add ($id . '07121d',   '1111COC');
    $self-> add ($id . '07131d',   '1111OOC');
    $self-> add ($id . '07141d',   '1111CCO');
    $self-> add ($id . '07151d',   '1111OCO');
    $self-> add ($id . '07161d',   '1111COO');
    $self-> add ($id . '07171d',   '1111OOO');
    $self-> add ($id . '07201d',   '1112CCC');
    $self-> add ($id . '07211d',   '1112OCC');
    $self-> add ($id . '07221d',   '1112COC');
    $self-> add ($id . '07231d',   '1112OOC');
    $self-> add ($id . '07241d',   '1112CCO');
    $self-> add ($id . '07251d',   '1112OCO');
    $self-> add ($id . '07261d',   '1112COO');
    $self-> add ($id . '07271d',   '1112OOO');
    $self-> add ($id . '07401d',   '1113CCC');
    $self-> add ($id . '07411d',   '1113OCC');
    $self-> add ($id . '07421d',   '1113COC');
    $self-> add ($id . '07431d',   '1113OOC');
    $self-> add ($id . '07441d',   '1113CCO');
    $self-> add ($id . '07451d',   '1113OCO');
    $self-> add ($id . '07461d',   '1113COO');
    $self-> add ($id . '07471d',   '1113OOO');

    $self->set_interface($interface);

    return $self;
}

package X10_IrrigationController;

# More info at: http://ourworld.compuserve.com/homepages/rciautomation/p6.htm

@X10_IrrigationController::ISA = ('Serial_Item');
@X10_IrrigationController::Inherit::ISA = @ISA;

sub new {
    my ($class, $id, $interface) = @_;
    my $self = {};
    $$self{state} = ''; 

    bless $self, $class;

    my $hc = substr($id, 0, 1);
    $self->{x10_hc} = $hc;

    $self-> add ("X" . $hc . 'P', 'off');

    $self-> add ("X" . $hc . "1" . $hc . 'J', '1on');
    $self-> add ("X" . $hc . "2" . $hc . 'J', '2on');
    $self-> add ("X" . $hc . "3" . $hc . 'J', '3on');
    $self-> add ("X" . $hc . "4" . $hc . 'J', '4on');
    $self-> add ("X" . $hc . "5" . $hc . 'J', '5on');
    $self-> add ("X" . $hc . "6" . $hc . 'J', '6on');
    $self-> add ("X" . $hc . "7" . $hc . 'J', '7on');
    $self-> add ("X" . $hc . "8" . $hc . 'J', '8on');

    $self-> add ("X" . $hc . "1" . $hc . 'K', '1off');
    $self-> add ("X" . $hc . "2" . $hc . 'K', '2off');
    $self-> add ("X" . $hc . "3" . $hc . 'K', '3off');
    $self-> add ("X" . $hc . "4" . $hc . 'K', '4off');
    $self-> add ("X" . $hc . "5" . $hc . 'K', '5off');
    $self-> add ("X" . $hc . "6" . $hc . 'K', '6off');
    $self-> add ("X" . $hc . "7" . $hc . 'K', '7off');
    $self-> add ("X" . $hc . "8" . $hc . 'K', '8off');

    $self->set_interface($interface);

    $self->{zone_runtimes} = [10,10,10,10,10,10,10,10];
    $self->{zone_runcount} = 8;
    $self->{zone_delay} = 10;
    $self->{timer} = &Timer::new();

    return $self;
}

sub set_runtimes
{
    my ($self) = shift @_;
    my $count = @_;

    if($count < 1)
    {
        print "X10_IrrigationController: set_runtimes called without data, ignoring\n";
    }
    else
    {
        $self->{zone_runtimes} = [@_];
        $self->{zone_runcount} = $count;
        print "X10_IrrigationController: setting runtimes for $count zones\n" if $main::config_parms{debug} eq 'X10';
    }
}

sub set_rundelay
{
    my ($self, $rundelay) = @_;

    if($rundelay < 1)
    {
        print "X10_IrrigationController: set_rundelay called without data, ignoring\n";
    }
    else
    {
        $self->{zone_delay} = $rundelay;
        print "X10_IrrigationController: rundelay set to $rundelay second(s)\n" if $main::config_parms{debug} eq 'X10';
    }
}

sub set
{
    my ($self, $state) = @_;

    if(lc($state) eq 'on')
    {
        # Start a cascade
        $self->zone_cascade();
    }
    elsif(lc($state) eq 'off')
    {
        # Kill any outstanding timer
        $self->{timer}->unset();
        # Send all off to shutdown controller
        $self->X10_IrrigationController::Inherit::set('off');
    }
    else
    {
        # We don't special handle this command, pass it thru
        $self->X10_IrrigationController::Inherit::set($state);
    }
}


sub zone_cascade
{
    my ($self, $zone) = @_;

    # Default to zone 1 (start of run)
    $zone = 1 if $zone eq undef;

    # Turn off last zone
    $self->X10_IrrigationController::Inherit::set(($zone - 1) . 'off') unless $zone == 1;
    # Or turn off all is starting from zone 1
    $self->X10_IrrigationController::Inherit::set('off') if $zone == 1;

    print "Zone $zone of $self->{zone_runcount}\n" if $main::config_parms{debug} eq 'X10';

    # Print start message
    print "X10_IrrigationController: zone_cascade start\n" if($zone == 1);
    # Print stop message
    print "X10_IrrigationController: zone_cascade complete\n" if($zone > $self->{zone_runcount});

    # Stop now if we've run out of zones
    return if($zone > $self->{zone_runcount});

    my $runtime = $self->{zone_runtimes}[$zone-1];
    if($runtime ne undef)
    {
        # Set a timer to turn it off and turn the next zone on
        my $sprinkler_timer = $self->{timer};
        my $object = $self->{object_name};
        my $action = "$object->zone_delay($zone," . $runtime*60 . ")";
        &Timer::set($sprinkler_timer, $self->{zone_delay}, $action);
        print "X10_IrrigationController: Delaying zone $zone start for $self->{zone_delay} seconds\n" if $main::config_parms{debug} eq 'X10';
    }
    else
    {
        # Recursion is your friend
        zone_cascade($self,$zone + 1);
    }

    return;
}

sub zone_delay
{
    my ($self, $zone, $runtime) = @_;

    # Turn the zone on
    $self->X10_IrrigationController::Inherit::set($zone . 'on');

    # Set a timer to turn it off and turn the next zone on
    my $sprinkler_timer = $self->{timer};
    my $object = $self->{object_name};
    my $action = "$object->zone_cascade(" . ($zone + 1) . ")";
    &Timer::set($sprinkler_timer, $runtime, $action);
    print "X10_IrrigationController: Running zone $zone for " . ($runtime/60) . " minute(s)\n" if $main::config_parms{debug} eq 'X10';
    return;
}


package X10_Switchlinc;

@X10_Switchlinc::ISA = ('X10_Item');

sub new {
    my $self = &X10_Item::new(@_);
    my $id = $self->{x10_id};
    $self-> add ($id . 'OGNGMGPGMG', 'clear');
    $self-> add ($id . 'OGPGMGPGMG', 'setramprate');
    $self-> add ($id . 'PGNGMGOGMG', 'setonlevel');
    $self-> add ($id . 'MGNGOGPG',   'addscenemembership');
    $self-> add ($id . 'OGPGMGNG',   'deletescenemembership');
    $self-> add ($id . 'NGOGPGMG',   'setsceneramprate');
    $self-> add ($id . 'MGNGPGOGPG', 'disablex10transmit');
    $self-> add ($id . 'OGMGPGOGPG', 'enablex10transmit');

    return $self;
}


# $Log$
# Revision 1.13  2000/11/12 21:02:38  winter
# - 2.34 release
#
# Revision 1.12  2000/10/22 16:48:29  winter
# - 2.32 release
#
# Revision 1.11  2000/10/01 23:29:40  winter
# - 2.29 release
#
# Revision 1.10  2000/08/19 01:25:08  winter
# - 2.27 release
#
# Revision 1.9  2000/06/24 22:10:55  winter
# - 2.22 release.  Changes to read_table, tk_*, tie_* functions, and hook_ code
#
# Revision 1.8  2000/05/27 16:40:10  winter
# - 2.20 release
#
# Revision 1.7  2000/02/20 04:47:55  winter
# -2.01 release
#
# Revision 1.6  2000/01/27 13:45:00  winter
# - add Garage_Door
#
# Revision 1.5  2000/01/13 13:40:35  winter
# - added Garage_Door
#
# Revision 1.4  2000/01/02 23:44:56  winter
# - add 'none' state
#
# Revision 1.3  1999/11/21 02:55:40  winter
# - fix set_with_timer bug
#
# Revision 1.2  1999/11/08 02:21:40  winter
# - add set_with_timer method
#
# Revision 1.1  1999/11/07 00:36:56  winter
# - moved out of Serial_Item.pm
#
