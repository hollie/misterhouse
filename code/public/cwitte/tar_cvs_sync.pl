#######################
#######################
##  Script to automate the process of syncing cvs/mh on sourceforge
##  I've had to do this a couple of times now to refresh sf.net with
##  the changes on Bruce's local drive.
##
##  Checking it in so that we don't lose it, but it hopefully won't
##  be needed if we keep cvs in sync.
##
##  to use: untar current release
##          checkout current cvs
##          run this script with 2 parms (tar_dir and cvs_dir)
##          verify the output (shell commands)
##          if they look ok,
##          CONFIRM YOUR INTENTION WITH THE misterhouse-users list!!
##          if you get approval from the list, run them
#######################
#######################
use File::Find;
use File::Basename;
use strict;
$| = 1;
my $tar_dir = shift;
my $cvs_dir = shift;
my $debug   = 0;
if   ( $tar_dir && -d $tar_dir ) { print "#using tar_dir: $tar_dir\n"; }
else                             { die "no such tar_dir: [$tar_dir]\n"; }
if   ( $cvs_dir && -d $cvs_dir ) { print "#using cvs_dir: $cvs_dir\n"; }
else                             { die "no such cvs_dir: [$cvs_dir]\n"; }

print "cd $cvs_dir   ### make sure we're in the cvs dir for the add cmds\n\n";
$tar_dir =~ s|/*$||;    ## remove trailing slash on dir
$cvs_dir =~ s|/*$||;    ## remove trailing slash on dir
my %dir;
my %tar_log;
find(
    {
        wanted   => \&for_each_tarnode,
        no_chdir => 1,
        bydepth  => 0,                    ## need to add dirs before files
    },
    $tar_dir
);

find(
    {
        wanted   => \&for_each_cvsnode,
        no_chdir => 1,
        bydepth  => 1,                    ## need to cleanup files before dirs
    },
    $cvs_dir
);

sub for_each_cvsnode {
    my $tar_test      = $File::Find::name;
    my $relative_base = $File::Find::name;
    $relative_base =~ s/^$cvs_dir//;
    $relative_base =~ s|^/||;             ## No leading slash

    if ( $relative_base =~ /CVS/ ) {
        return;                           ## skip CVS control files
    }
    if ( $tar_test =~ s/^$cvs_dir/$tar_dir/ ) {
        if ( -d $tar_test || -f $tar_test ) {
            ## ok
        }
        else {
            my $rm_tgt = $File::Find::name;
            print "echo 'removing $rm_tgt'\n";
            print "rm -f  $rm_tgt\n" if ( -f $rm_tgt );
            print "cvs remove $relative_base\n";
        }
    }
    else {
        die
          "illogic:  can't change cvs_dir [$cvs_dir] to tar_dir [$tar_dir] for file: [$tar_test]\n";
    }
}

sub for_each_tarnode {
    my $cvs_test      = $File::Find::name;
    my $relative_base = $File::Find::name;
    $relative_base =~ s/^$tar_dir//;
    $relative_base =~ s|^/||;    ## No leading slash
    if (
           $relative_base =~ /\~/
        || $relative_base =~ /#/
        || $relative_base =~ /\.swp/    ## don't want swap files either
        || $relative_base =~ /CVS/
      )
    {
        $debug && print "#ignoring file: [$relative_base]\n";
        return;

    }
    if ( $relative_base =~ /\s+/ ) {
        print "#ignoring file with embedded spaces: [$relative_base]\n";
        return;
    }
    if ( $cvs_test =~ s/^$tar_dir/$cvs_dir/ ) {
        if ( -d $cvs_test || -f $cvs_test ) {
            $debug && print "#cvs file: $cvs_test found\n";
            &compare_file( $cvs_test, $File::Find::name );
        }
        else {
            $debug && print "#cvs file: $cvs_test missing\n";
            if ( -d $File::Find::name ) {
                if ( !-d $cvs_test ) {
                    print "echo 'adding cvs_dir: $cvs_test'\n";
                    print "mkdir  -p $cvs_test\n";
                    ##print "## when testing, the first add fails w/ broken pipe, the second works?!?!\n";
                    print "cvs add $relative_base ## add dir\n";
                    print "cvs add $relative_base ## add dir\n";
                }
                else {
                    die "illogic: $cvs_test exists but not!? \n";
                }
            }
            else {
                print "echo 'adding cvs_file: $cvs_test'\n";
                print "cp -p $File::Find::name $cvs_test\n";
                print "cvs add $relative_base    ## add file\n";
            }

        }
    }
    else {
        die
          "illogic:  can't change tar_dir [$tar_dir] to cvs_dir [$cvs_dir] for file: [$cvs_test]\n";
    }
    $tar_log{$relative_base}++;
### 	print "$File::Find::dir\n" if (! $dir{$File::Find::dir}++);
}
#######################################
##  Here, we have 2 files that are both in the tarball and cvs.
##  Check to see if they match.
##   If not,  refresh cvs with the tarball version.
#######################################
sub compare_file {
    my ( $cvs, $tar ) = @_;
    my $c_sum         = &sysVchecksum($cvs);
    my $t_sum         = &sysVchecksum($tar);
    my $relative_base = $cvs;
    $relative_base =~ s/^$cvs_dir//;
    $relative_base =~ s|^/||;    ## No leading slash

    $debug && print "compare files: $c_sum : $t_sum\n";
    if ( $c_sum ne $t_sum ) {
        print "\n## checksum mismatch on $relative_base ($c_sum:$t_sum)\n";
        my $tmp_dir  = "/tmp/cvs_tar_diff";
        my $diff_out = $relative_base;
        $relative_base =~ s|\/|::|g;
        mkdir($tmp_dir);

        system("diff $tar $cvs > $tmp_dir/$relative_base");
        print "cp -p $tar $cvs\n";
    }

}

sub sysVchecksum {
    my ($file) = @_;
    my (@stat) = stat($file);
    my $flen   = $stat[7];
    open( TST, $file ) || die "sysVchecksum can't read $file\n";
    my $checksum = do {
        local $/;    #slurp!
        unpack( "%32C*", <TST> ) % 65535;
    };
    return ( $checksum . "-" . $flen );
}
