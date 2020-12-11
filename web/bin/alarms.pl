
=begin comment

This file is called from /misc/alarms.html or called directly with:

  http://localhost:8080/bin/alarms.pl?time&text

It is an example of adding an event to the triggers file.


=cut

my ( $time, $text ) = @ARGV;

$time =~ s/time=//;
$text =~ s/text=//;

print_log "Writing a web entered alarm trigger for $time: $text";

&print_log( "time_now '$time'", "speak 'app=timer Notice, $text at $time" );
&trigger_set( "time_now '$time'", "speak 'app=timer Notice, $text at $time'" );

return &html_page( '', "1 Alarm set for $time: $text" );

