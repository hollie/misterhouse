# Category = CopyCode

#
# Written by Jeff Crum (dilligaf@dilligaf.d2g.com) for
# misterhouse software (http://misterhouse.net).
#
# Feel free to chop, butcher, slice, hack, mutilate, disfigure or deface this
# code to meet your needs.
#
# I wrote this to keep all my computers voice commands in sync.
#
# I have 1 computer (main) that has the CM11A and the MR25A attached.  I also
# have other computers that are running MH that needed the commands that I
# programmed for the main computer.  They use the same commands, but, they
# send the commands to the main computer using mhsend.
#
# Instead of having to keep track and program the same commands for the other
# computers, I wrote this script that runs thru selected code and creates
# the same code filename with voice commands set up to mhsend the command
# to the main computer.
#
# The voice commands must be formatted just like:
#    $v_master_fan = new  Voice_Cmd('master fan [on,off]');
#    set $master_fan $state if ($state = said $v_master_fan);
#
# The command in the new file will look like:
#    $v_master_fan = new  Voice_Cmd('master fan [on,off]');
#    run "mhsend -host 192.168.1.2 -run 'master fan $state'" if $state = said $v_master_fan;
#
#
# The voice command variable must start with $v_ and start in the 1st positon.
# The actual voice command must be within single quote marks.  Due to my laziness,
# it currently only works for voice commands with variable info at the end.  Meaning
# it'll work for the above 'master fan [on,off]' command, but it won't work for a
# command like:  Voice_Cmd('reload [master,mikey,laptop] code').
#
# My directory structure is: (this code currently relies on this)
#    All my code for all computers is on the same network drive mapped to z:
#      z:/
#       -master/
#         -code/
#         -data/
#       -template/
#         -code/
#         -data/
#       -laptop/
#         -code/
#         -data/
#       -mikey/
#         -code/
#         -data/
#
# The template directory is used as a staging area for this and is where I
# copy the directories from when I add another computer.  The master directory
# is used by the computer that has the CM11A and MR25A connected.  The code is
# copied/converted from the master/code directory to the template/code directory.
# Each converted file is then copied from the template/code directory to the code
# directory of each of the other computer directories.
#
# Since I didn't want all code modules copied this way, I wrote this to only copy
# the ones that have '# copycode' in them.  I just add that line after the Category
# line in the code files I want copied.
#
# Variables that need set for your situation:
# $maincomputer - the IP address or DNS/hosts name of the computer with the
#                 X-10 equipment installed.
# $codedrive - The drive mapping that has the above directory structure
#
# Don't forget to add a comment like the next line to the modules you want copied.
# copycode
#

$v_copy_code = new Voice_Cmd('copy code');
&copycode if ( $state = said $v_copy_code);

sub copycode {
    my $maincomputer = "192.168.1.2";
    my $codedrive    = "z:";

    my @files       = ();
    my @filestocopy = ();
    my @computers   = ();
    my @lines       = ();
    my (
        $file,            $line,         $computer,
        $variable_phrase, $phrase_start, $phrase_length,
        $var_end_pos,     $count,        $outline
    );

    #                                            Find the files in the master/code directory that
    #                                            we want to copy
    opendir( DIR, "$codedrive/master/code" );
    @files = readdir DIR;
    close DIR;

    #                                            Drop items from the list that are not .pl
    @files = grep( /^[a-z0-9].*\.pl$/i, @files );
    if ( @files > 0 ) {
        foreach $file (@files) {
            open( PERLIN, "$codedrive/master/code/$file" );
            @lines = <PERLIN>;
            close(PERLIN);
            chomp(@lines);

            #                                            Check to see if we are supposed to copy this file
            if ( grep( /# copycode/, @lines ) ) {

                #                                            Build another array of just the files we are
                #                                            supposed to copy and use it later
                push( @filestocopy, $file );
                open( TEMPOUT, ">$codedrive/template/code/$file" );
                foreach $line (@lines) {
                    if ( substr( $line, 0, 10 ) eq '# Category' ) {
                        print TEMPOUT "$line\n\n";
                        print TEMPOUT
                          "# This file is automatically created by running the copycode\n";
                        print TEMPOUT
                          "# program in the master code directory.  Any changes made to\n";
                        print TEMPOUT
                          "# this file will be overwritten the next time it is run.\n";
                        print TEMPOUT
                          "# You should make changes to the appropiate file in the master\n";
                        print TEMPOUT
                          "# code directory then re-run the copycode program.\n\n";
                    }
                    elsif ( substr( $line, 1, 2 ) eq 'v_' ) {
                        $phrase_start    = 0;
                        $phrase_length   = 0;
                        $var_end_pos     = 0;
                        $variable_phrase = "no";
                        for ( $count = 0; $count <= length($line); $count++ ) {
                            if ( $phrase_start eq 0 ) {
                                if (   ( substr( $line, $count, 1 ) eq " " )
                                    && ( $var_end_pos eq 0 ) )
                                {
                                    $var_end_pos = $count;
                                }
                                elsif ( substr( $line, $count, 1 ) eq "'" ) {
                                    $phrase_start  = ++$count;
                                    $phrase_length = 0;
                                }
                            }
                            else {
                                $phrase_length++;
                                if (   ( substr( $line, $count, 1 ) eq "'" )
                                    || ( substr( $line, $count, 1 ) eq "[" ) )
                                {
                                    if ( substr( $line, $count, 1 ) eq "[" ) {
                                        $variable_phrase = "yes";
                                    }
                                    $count = length($line) + 1;
                                }
                            }
                        }
                        if ( $phrase_start > 0 ) {
                            print TEMPOUT "$line\n";
                            if ( $variable_phrase eq "yes" ) {
                                $outline =
                                  "run \"mhsend -host $maincomputer -run \'"
                                  . substr( $line, $phrase_start,
                                    $phrase_length )
                                  . "\$state\'\" if \$state = said "
                                  . substr( $line, 0, $var_end_pos ) . "\;";
                            }
                            else {
                                $outline =
                                  "run \"mhsend -host $maincomputer -run \'"
                                  . substr( $line, $phrase_start,
                                    $phrase_length )
                                  . "\'\" if \$state = said "
                                  . substr( $line, 0, $var_end_pos ) . "\;";
                            }
                            print TEMPOUT "$outline\n\n";
                        }
                    }
                }
                close(TEMPOUT);
                print_log "$file copied";
            }
        }
    }

    #  Copy the created files from the template directory to the computer directories
    opendir( DIR, "$codedrive" );
    @computers = readdir DIR;
    close DIR;

    #  Drop items from the list with names of '.', '..', 'master', and 'template'
    @computers = grep( !/^\.\.?\z/ && !/master/ && !/template/, @computers );

    foreach $computer (@computers) {

        #  Of the remaining items in the list we only want the directories
        #  that have a subdirectory named 'code'
        if ( -d "$codedrive/$computer/code" ) {
            foreach $file (@filestocopy) {
                open( TEMPIN, "$codedrive/template/code/$file" );
                @lines = <TEMPIN>;
                close(TEMPIN);
                open( PERLOUT, ">$codedrive/$computer/code/$file" );
                foreach $line (@lines) {
                    print PERLOUT "$line";
                }
                close(PERLOUT);
            }
            print_log "files copied to $computer";
        }
    }
}
