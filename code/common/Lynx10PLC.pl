# Category = X10

########################################################################
#
# Lynx10PLC.pl
#
# Author: Joe Blecher
#
# The Lynx10PLC is an X10 controller developed by Marrick Ltd.
#
# This script provides the user with access to the extended features
# of the Lynx10PLC.
#
# Requires: Lynx10PLC.pm
#
#
########################################################################

#@ Output X10 statistics from the Lynx10PLC controller

if ($Startup) {
    print "***** Lynx10PLC Device Information ******\n";
    Lynx10PLC::readDeviceInfo();
}

# Read the stats on the hour or on startup
Lynx10PLC::readAllStats() if $::New_Hour || $Startup;

# Clear the statistic counters every hour
Lynx10PLC::clearAllStats() if $::New_Hour;
