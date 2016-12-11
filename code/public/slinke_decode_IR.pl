#!/usr/bin/perl -w

use strict;
use Slinke;

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
$slinke->setIRReceivePorts(0xFF);

#$slinke->setIRTimeoutPeriod( 500 );
$slinke->setIRTimeoutPeriod(900);

while (1) {
    my $data = $slinke->requestInput;
    next if !$data;
    next if ( $data->{PORT} ne "PORT_IR" );

    pop @{ $data->{DATA} };
    my $code = decodeIR( @{ $data->{DATA} } );

    my $ir = $code->{CODE};

    #    print join( " ", @{$data->{ DATA } } ), "\n\n";
    if ( exists $COMMANDS{$ir} ) {
        next if $#{ $data->{DATA} } < 5 && $COMMANDS{$ir}->[2] == 0;
        print join( " ", @{ $COMMANDS{$ir} }[ 0 .. 1 ] ), "\n";
    }
    else {
        print $ir, "\n";
        print join( " ", @{ $data->{DATA} } ), "\n\n";
    }
}

