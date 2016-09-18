#!/usr/bin/perl

use strict;

my ( %data, $i, $j );

while (<>) {
    chomp;
    my ( $city, $state );

    # New data
    unless ( ( $city, $state ) = $_ =~ /city=(.+) state=(.+) name=/ ) {

        # Old data
        $_ =~ s/\"//;
        ($city)  = $_ =~ /(.+?), /;
        ($state) = $_ =~ /,(\S+?),/;
    }
    $state =~ s/\"//;
    $state = 'unknown' unless $state;
    $data{"$state: $city"}{state} = $state;
    $data{"$state: $city"}{count}++;
    $i++;
}

my $time_date = localtime;
print "<b>Number of users: $i\n";
print "<br>Last updated: $time_date</b>\n";
print "<table cellpadding=2 border=1><tr>\n";
for my $state_city (
    sort {
             length $data{$a}{state} <=> length $data{$b}{state}
          or $data{$a}{state} cmp $data{$b}{state}
          or $a cmp $b
    } keys %data
  )
{
    print "</tr><tr>\n" unless $j++ % 4;
    my $cnt = $data{$state_city}{count};
    $state_city .= " ($cnt users)" if $cnt > 1;
    print "<td>$state_city</td>\n";
}
print "</tr></table>\n";

