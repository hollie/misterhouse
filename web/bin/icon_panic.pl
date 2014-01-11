
# Return a panic mode button - red to start panic process, green to cancel

# Authority: anyone

my $icon = '/ia5/images/panicred.gif';
my $action = '';
#my $action = '/SET;referer/ia5/top.shtml?hpc_panic_mode=on';
#           # Return a user specific icon, or default logout icon if not found.
#if (active $hpc_timer_panic) {
#    $icon = '/ia5/images/panicgreen.gif';
#    $action = '/SET;referer/ia5/top.shtml?hpc_panic_mode=off';
#}

#print "\ndbx a=$Authorized i=$icon a=$action\n";
return "<a href='$action' target='title'><img src='$icon' alt='Panic Mode' border=0></a>";
