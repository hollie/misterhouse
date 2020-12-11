
# Simply return an object state, with no html formating, for use with other
# programs like php

# Call like this:  http://localhost:8080/bin/get_state.pl?$Front_light

my ($object) = @ARGV;

my $state = eval "state $object";
print "get_state.pl error: $@" if $@;
print "returning status of $object: $state\n";

# Use this if returning to a browser
#return &html_page('', $state);

# Use this if you want simple raw data, like for use by php
return $state;

