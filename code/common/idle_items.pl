# Category = MisterHouse

#@ Lists time idle for various types of items.  User configurable "other" option allows reporting on other items.

$_vc_display_item_status = new Voice_Cmd 'Show Idle Time [RF,Analog Sensor,Other]';

if (defined($state = said $_vc_display_item_status)) {
   if ($state eq 'RF') {
      &display_idle_item_status('X10_Sensor,RF_Item');
   } elsif ($state eq 'Analog Sensor') {
      &display_idle_item_status('AnalogSensor_Item');
   } elsif ($state eq 'Other') {
     # has the config parm for item idle been defined?
     my $idle_items_other = $main::config_parms{idle_items_other};
     if ($idle_items_other) {
        &display_idle_item_status($idle_items_other);
     } else {
        print "You must first define idle_items_other in your ini parms.  Separate multiple item class names with a comma.\n";
     }
   }
}

sub display_idle_item_status
{
   my ($idle_types) = @_;
   my $output = "\n($idle_types) items and corresponding idle time";
   $output .= "\n------------------------------------------------------------";
   $output .= "\n  * warn - some items may report time since restart/reload\n\n";
   my @idle_items = &main::get_idle_item_data($idle_types);
   foreach my $idle_item_ptr (@idle_items) {
      if ($idle_item_ptr) {
         my %item_data = %$idle_item_ptr;
         my $name = $item_data{name};
         $name = sprintf("%-*s", 30, $name);
         $output .= $name . " | " . $item_data{idle_text} . "\n"
            if $item_data{idle_text};
      }
   }

    print $output;
}


