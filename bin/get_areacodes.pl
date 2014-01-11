#!/usr/bin/perl
use strict;
use warnings;
use HTML::TableExtract;
use LWP::Simple;

use Time::Local;

my $url = "http://www-cse.ucsd.edu/users/bsy/area.html";
my $html = get($url);
my $table = HTML::TableExtract->new;
my $row;
print "# Downloaded from $url\n";
print "# On ". (localtime) . "\n";
print "#\n";
$table->parse($html);
# Table parsed, extract the data.
 foreach $row ($table->rows) {
    next unless @$row[0] =~ m/^[\-|\d]/;
    my $ac = @$row[0];
    my $prov = @$row[1];
    my $tz = @$row[2]; 
    my $description = @$row[3];
    $description =~ s/^\s+//g;
    if ($description =~ m/^canada\:/ig) {
	$description =~ s/^canada\:\s+//i;
	$description =~ s/\(.*\)$//;
	$description =~ s/^.+\:\s+//; #remove additional province details
	$description =~ s/[\-\-|\;].*//;
	#my $place;
	#($place) = $description =~ /\:(.*)\(.*\)$/i; #get rid of the end stuff
	print "$ac $prov $tz $description\n";
	#print "\t\t$place\n";
    } else {
    print "$ac $prov $tz $description\n";
    }
#    print join(',', @$row), "\n";
 }
