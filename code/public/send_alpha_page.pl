#-----------------------------------------------------------------------------
# send_alpha_page.pl - Send alphanumberic pages to your pager from inside
# MisterHouse.
#
# Requires:
#	    bip  - alpha paging package for Linux
#                  Couldn't find homepage for BIP but you can get it at
#                  http://filewatcher.org/sec/bip.html
#
# bip requires the following perl modules available at CPAN:
#	    perl-HTML-Parser
#	    perl-URI
#           perl-libwww-perl
#
#
# Author: Dave Lounsberry
# 	  dlounsberry@kc.rr.com
#         12/19/1999
#
#
# NOTE: This script does not bring up your internet connection. I have a cable
#	connection so it would be impossible for me to test it out. If you have
#	a Linux system, the best route would be to set up diald (on demand dialing).
#
# Usage examples:
#       I use this feature for when I am away from home and want to know if someone
# 	is in my house. Nice to know don't you think? I can also check up on my
#	neighbors to make sure they feed my cats when they are supposed to. :-)
#
#	&send_page("$Time_Now Someone is in your house") if $Save{travel} eq 'family';
#
#	&send_page("A vampire is lurking, help me!","Buffy", "pagenet", "123456" ");
#
#
#-----------------------------------------------------------------------------

$v_page_dave = new Voice_Cmd('Page Dave with test message');
&send_page("This is a test page from MisterHouse") if said $v_page_dave;

sub send_page {
    s/\'//
      ;   # remove any escape backticks because everything is an argument to bip
    my ( $pager_msg, $pager_name, $pager_service, $pager_pin ) = @_;
    my $print_msg;

    # Put your service and pin numbers here. Refer to /etc/bip.conf for service
    # names and how to call bip.
    $pager_name    = "Dave"                     if $pager_name eq "";
    $pager_msg     = "MisterHouse default page" if $pager_msg eq "";
    $pager_service = "xxxxxxx"                  if $pager_service eq "";
    $pager_pin     = "xxxxxxx"                  if $pager_pin eq "";

    $print_msg = "Paging " . $pager_name . " with message " . $pager_msg;

    print_log "$print_msg";
    speak("$print_msg");
    system("/usr/bin/bip $pager_service $pager_pin \'$pager_msg\'");
}
