#!/usr/bin/perl -w

use strict;
use Slinke;
use Data::Dumper;

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
$slinke->setIRTimeoutPeriod(500);

#$slinke->setIRSamplingPeriod( 50 / 1e6 );
#$slinke->setIRTimeoutPeriod( 1000 );

# put code into database
#    in hash COMMANDS ( key = IR code, value = [ component name, command name ] )
#    in hash COMPONENTS ( key = component name, value = [ head, tail, pause, [ zero, one ] ] )
#    in hash COMPONENT_LOOKUP ( key = IR head, value = component name )
#    in hash COMMAND_LOOKUP ( key = [ component name ~ command name ], value = IR code )

while (1) {
    my $data = $slinke->requestInput;
    next if !$data;
    next if ( $data->{PORT} ne "PORT_IR" );

    pop @{ $data->{DATA} };
    my $code = decodeIR( @{ $data->{DATA} } );

    my $ir = $code->{CODE};

    my @zero = @{ $code->{ENCODING}->[0] };
    my @one  = @{ $code->{ENCODING}->[1] };

    my $componentBits;
    if ( $zero[0] == $one[0] ) {
        $componentBits = substr( $ir, 0, 16 );
    }
    else {    # Sony equipment - device is last five bits
        $componentBits = substr( $ir, 7 );
    }

    my $component;
    my $command;
    my $repeatable;

    # Check if we've seen this command before
    if ( exists $COMMANDS{$ir} ) {
        my $val = "q";
        while ( $val ne "y" && $val ne "n" ) {
            print "Received '" . join( " ", @{ $COMMANDS{$ir} }[ 0 .. 1 ] ),
              "'\n";
            print "Is this correct? [Y/n] ";
            $val = lc(<STDIN>);
            chomp $val;
            $val = "y" if !$val;
            if ( $val eq "y" ) {
                $component  = $COMMANDS{$ir}->[0];
                $command    = $COMMANDS{$ir}->[1];
                $repeatable = $COMMANDS{$ir}->[2];
            }
        }
    }

    # If it's a new command, prompt the user for component and command name
    if ( !$command ) {
        $component = $COMPONENT_LOOKUP{$componentBits} || "";
        print "Received new command\n" if !exists $COMMANDS{$ir};
        my $val = undef;
        while ( !$val ) {
            print "Component Name: [$component] ";
            $val = <STDIN>;
            chomp $val;
            $val = $component if !$val;
        }
        $component = $val;

        $val = undef;
        while ( !$val ) {
            print "Command Name: ";
            $val = <STDIN>;
            chomp $val;
        }
        $command = $val;

        $val = "a";
        while ( $val ne "y" && $val ne "n" ) {
            print "Is this command repeatable [y/N]: ";
            $val = lc(<STDIN>);
            chomp $val;
            $val = "n" if !$val;
        }
        $repeatable = $val eq "y" ? 1 : 0;
    }

    # Now, update the database

    # if we've seen the component before, average in the new values
    my $count =
      exists $COMMAND_LOOKUP{$component}
      ? scalar keys %{ $COMMAND_LOOKUP{$component} }
      : 0;

    if ( $count > 0 ) {
        if ( $code->{PAUSETIME} ) {
            if ( $COMPONENTS{$component}->{PAUSETIME} ) {
                $COMPONENTS{$component}->{PAUSETIME} =
                  ( $COMPONENTS{$component}->{PAUSETIME} * $count +
                      $code->{PAUSETIME} ) /
                  ( $count + 1 );
            }
            else {
                $COMPONENTS{$component}->{PAUSETIME} = $code->{PAUSETIME};
            }
        }

        if ( $#{ $code->{HEAD} } == $#{ $COMPONENTS{$component}->{HEAD} } ) {
            for ( my $i = 0; $i <= $#{ $code->{HEAD} }; $i++ ) {
                $COMPONENTS{$component}->{HEAD}->[$i] =
                  ( $COMPONENTS{$component}->{HEAD}->[$i] * $count +
                      $code->{HEAD}->[$i] ) /
                  ( $count + 1 );
            }
        }

        if ( $#{ $code->{TAIL} } == $#{ $COMPONENTS{$component}->{TAIL} } ) {
            for ( my $i = 0; $i <= $#{ $code->{TAIL} }; $i++ ) {
                $COMPONENTS{$component}->{TAIL}->[$i] =
                  ( $COMPONENTS{$component}->{TAIL}->[$i] * $count +
                      $code->{TAIL}->[$i] ) /
                  ( $count + 1 );
            }
        }
        elsif ( $#{ $COMPONENTS{$component}->{TAIL} } < 0 ) {
            $COMPONENTS{$component}->{TAIL} = $code->{TAIL};
        }

        if ( $#{ $code->{ENCODING}->[0] } ==
            $#{ $COMPONENTS{$component}->{ZERO} } )
        {
            for ( my $i = 0; $i <= $#{ $code->{ENCODING}->[0] }; $i++ ) {
                $COMPONENTS{$component}->{ZERO}->[$i] =
                  ( $COMPONENTS{$component}->{ZERO}->[$i] * $count +
                      $code->{ENCODING}->[0]->[$i] ) /
                  ( $count + 1 );
            }
        }

        if ( $#{ $code->{ENCODING}->[1] } ==
            $#{ $COMPONENTS{$component}->{ONE} } )
        {
            for ( my $i = 0; $i <= $#{ $code->{ENCODING}->[1] }; $i++ ) {
                $COMPONENTS{$component}->{ONE}->[$i] =
                  ( $COMPONENTS{$component}->{ONE}->[$i] * $count +
                      $code->{ENCODING}->[1]->[$i] ) /
                  ( $count + 1 );
            }
        }
    }
    else {
        $COMPONENTS{$component}->{HEAD}      = $code->{HEAD};
        $COMPONENTS{$component}->{TAIL}      = $code->{TAIL};
        $COMPONENTS{$component}->{ZERO}      = $code->{ENCODING}->[0];
        $COMPONENTS{$component}->{ONE}       = $code->{ENCODING}->[1];
        $COMPONENTS{$component}->{PAUSETIME} = $code->{PAUSETIME}
          if $code->{PAUSETIME};
        $COMPONENTS{$component}->{REPEAT} = $code->{REPEAT} if $code->{REPEAT};
    }

    $COMMANDS{$ir} = [ $component, $command, $repeatable ];
    $COMPONENT_LOOKUP{$componentBits} = $component;
    $COMMAND_LOOKUP{$component}->{$command} = $ir;

    if (0) {
        print "$ir\n";
        print "'$component' '$command'\n";

        print join( " ", @{ $code->{HEAD} } ), "\n";
        print join( " ", @{ $code->{TAIL} } ), "\n";
        print join( " ", @{ $code->{ENCODING}->[0] } ), "\n";
        print join( " ", @{ $code->{ENCODING}->[1] } ), "\n";

        #	print join( " ", @{$COMMANDS{ $ir }} ) || $ir, "\n";
    }
    last;
}

# now save information
#print Data::Dumper->Dump( [ \%COMMANDS, \%COMPONENT_LOOKUP, \%COMPONENTS, \%COMMAND_LOOKUP ],
#			  [ qw( *COMMANDS *COMPONENT_LOOKUP *COMPONENTS *COMMAND_LOOKUP ) ] );
#exit;
open( FILE, "> $file" );
print FILE Data::Dumper->Dump(
    [ \%COMMANDS, \%COMPONENTS, \%COMPONENT_LOOKUP, \%COMMAND_LOOKUP ],
    [qw( *COMMANDS *COMPONENTS *COMPONENT_LOOKUP *COMMAND_LOOKUP )]
);
close(FILE);

