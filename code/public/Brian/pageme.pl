###########################################################
# Klier Home Automation - Paging Module                   #
# Requires calllog.pl                                     #
# Version 1.0 Alpha                                       #
# By: Brian J. Klier, N0QVC                               #
# E-Mail: klier@lakes.com                                 #
# Webpage: http://www.faribault.k12.mn.us/brian           #
###########################################################

###  USAGE EXAMPLE:
###            if (time_greater_than("22:00") and time_less_than("15:00")) {
###            $page_status = "0165*911*1";
###            }

# Category=Phone

# Declare Variables

my ($page_status);
$timer_hangup_pager = new Timer;

# Setup Phone Hangup Info

if (expired $timer_hangup_pager) {
    set $phone_modem 'ATH';
    set $timer_hangup_pager 0;
    print_msg "Page Sent Successfully...";
    print_log "Page Sent Successfully...";
    speak "Page Sent Successfully.";
}

# Set up Phone Item to Page Me

$v_page_me = new Voice_Cmd('Page Me');
if (said $v_page_me) {

    speak "Sending out Manual Page.";
    $page_status = "ATDT3329999,,,123454321#";

    set $timer_hangup_pager 30;
    set $phone_modem "$page_status";

    $page_status = '';
}

# Send the Page...

if ($page_status ne '') {

    speak "Sending out Page.";
    $page_status = "ATDT3329999,,," . $page_status . "#";

    set $timer_hangup_pager 30;
    set $phone_modem "$page_status";

    $page_status = '';
}
