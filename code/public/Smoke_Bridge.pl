# Category=Safety

# Example configuration for using ONELINK Smoke/Carbon Monoxide (CO) detectors
# with an INSTEON Smoke Bridge (2982-222).
#
##
# Author: Jared Fernandez (Jared.Fernandez@GMail.com) with minor
# contributions by Brian Rudy (brudyNO@SPAMpraecogito.com)
#
###
#
# Notes
#
###
#
# Full Smoke Bridge manual with instructions for how to set the Smoke Bridge
# up as a "scene controller": http://www.insteon.com/pdf/2982-222.pdf
#
# Currently there is no specific MH support for the Smoke Bridge, but it behaves
# much like the INSTEON Leak Sensor which works with the INSTEON_TRIGGERLINC
# declaration.
#
# The Smoke Bridge reports the following INSTEON groups for the supported
# states:
#
# Group	  Meaning
# 01	  Smoke Detected
# 02	  Carbon Monoxide Detected
# 03	  Detector Test
# 04	  Unknown Message
# 05	  All Clear
# 06	  Detector Battery Low
# 07	  Sensor Malfunction
#
# Therefore, you can declare them in your MHT file like this:
#
# # Insteon SmokeBridge
# INSTEON_TRIGGERLINC, AB.CD.EF:01, Smoke_Bridge_Smoke,       Sensors|All_Devices
# INSTEON_TRIGGERLINC, AB.CD.EF:02, Smoke_Bridge_CO,          Sensors|All_Devices
# INSTEON_TRIGGERLINC, AB.CD.EF:03, Smoke_Bridge_Test,        Sensors|All_Devices
# INSTEON_TRIGGERLINC, AB.CD.EF:04, Smoke_Bridge_Unknown,     Sensors|All_Devices
# INSTEON_TRIGGERLINC, AB.CD.EF:05, Smoke_Bridge_Clear,       Sensors|All_Devices
# INSTEON_TRIGGERLINC, AB.CD.EF:06, Smoke_Bridge_Battery,     Sensors|All_Devices
# INSTEON_TRIGGERLINC, AB.CD.EF:07, Smoke_Bridge_Malfunction, Sensors|All_Devices
#
# Once you have linked the Smoke Bridge to the PLM as a "scene controller",
# tapping the set button on the Smoke Bridge will initiate a test of the Smoke
# bridge and cycle through the following groups in the order listed below. This
# will let you test your MH config and ensure it behaves appropriately:
#
# Group   Meaning
# 01      Smoke Detected
# 02      Carbon Monoxide Detected
# 06      Detector Battery Low
# 07      Sensor Malfunction
# 05      All Clear
#
# When you initiate a test of the ONELINK detectors via the test button on one
# of the linked detectors, the Smoke Bridge will send only group 03 (Detector
# Test) to MH.
#

if ( state_now $Smoke_Bridge_Smoke eq ON ) {

    # You can now include any events here that you'd like to happen if the smoke alarm goes off
    #$Red_Alert_Lamp->set(ON)
    print_log "Fire Detected!";
    speak "Fire detected! Exit immediately!";
}

if ( state_now $Smoke_Bridge_CO eq ON ) {
    print_log "Carbon Monoxide Detected!";
    speak "Carbon monoxide above safe levels detected! Exit immediately!";
}

if ( state_now $Smoke_Bridge_Test eq ON ) {
    print_log "Smoke Detector Test Initiated";
}

if ( state_now $Smoke_Bridge_Unknown eq ON ) {
    print_log "Unknown Message Received from Smoke Bridge";
}

if ( state_now $Smoke_Bridge_Clear eq ON ) {
    print_log "Smoke Detector Reports All-Clear";
}

if ( state_now $Smoke_Bridge_Battery eq ON ) {
    print_log "Smoke Detector Reports a Low Battery";
    speak "Smoke detector reports a low battery";
}

if ( state_now $Smoke_Bridge_Malfunction eq ON ) {
    print_log "Smoke Detector Reports a Malfunction";
    speak "Smoke detector reports a malfunction";
}

