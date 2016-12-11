#!/usr/bin/perl -w

use strict;
use Slinke;

my $DEBUG   = 0;
my $TIMEOUT = 500;

my $file = shift || "slinke.irdb";

# read in database
my ( %COMMANDS, %COMPONENT_LOOKUP, %COMPONENTS, %COMMAND_LOOKUP );
{
    local $/ = "";
    open FILE, $file;
    my $string = <FILE>;
    close FILE;

    eval $string;
}

my $slinke = new Slinke();

$slinke->setIRSamplingPeriod( 100 / 1e6 );
$slinke->setIRTimeoutPeriod($TIMEOUT);

while (1) {
    print "Enter 'component, command [, times to play]': ";
    my $input = <>;
    chomp $input;

    my ( $component, $command, $times_to_play );
    ( $component, $command, $times_to_play ) = split /\,/, $input;
    $component =~ s/^\s*(.*?)\s*$/$1/;
    $command =~ s/^\s*(.*?)\s*$/$1/;
    $times_to_play = 1 if !$times_to_play;
    $times_to_play =~ s/^\s*(.*?)\s*$/$1/;

    if ( !defined $COMPONENTS{$component} ) {
        print "ERROR: Unknown Component '$component'\n";
        next;
    }

    if ( !defined $COMMAND_LOOKUP{$component}->{$command} ) {
        print "ERROR: Unknown Command '$command' for '$component'\n";
        next;
    }

    my @tmpSeq;
    push @tmpSeq, @{ $COMPONENTS{$component}->{HEAD} };
    foreach my $i ( split / */, $COMMAND_LOOKUP{$component}->{$command} ) {
        push @tmpSeq,
          @{ $COMPONENTS{$component}->{ $i == 0 ? "ZERO" : "ONE" } };
    }

    my @RLC;
    my $repeat = $COMPONENTS{$component}->{REPEAT} || 0;
    while ( $repeat >= 0 ) {
        push @RLC, @tmpSeq;
        $repeat--;
        push @RLC, @{ $COMPONENTS{$component}->{TAIL} }
          if ( $COMPONENTS{$component}->{ZERO}->[1] !=
            $COMPONENTS{$component}->{ONE}->[1] );
        push @RLC, $COMPONENTS{$component}->{PAUSETIME}
          if $COMPONENTS{$component}->{PAUSETIME} && $repeat >= 0;
    }
    push @RLC, @{ $COMPONENTS{$component}->{TAIL} }
      if ( $COMPONENTS{$component}->{ZERO}->[1] ==
        $COMPONENTS{$component}->{ONE}->[1] );

    push @RLC, -100 * $TIMEOUT - 1000;

    if ($DEBUG) {
        foreach my $i (@RLC) {
            printf "%1.1f ", $i;
        }
        print "\n";
    }

    while ( $times_to_play-- > 0 ) {
        $slinke->sendIR( DATA => \@RLC );

        if ( !$COMMANDS{ $COMMAND_LOOKUP{$component}->{$command} }->[2] ) {
            select undef, undef, undef, .15;
        }
    }
}

