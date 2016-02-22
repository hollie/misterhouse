use strict;
use Data::Table;
use FileHandle;

package caddx;
use vars qw(%layouts %laycode);
use vars qw($eval_fh);

sub main {
    my $ofile = "caddx_parse.pm";
    my $th    = new FileHandle "caddx_fmt.csv";
    die "can't read csv" unless $th;
    my $eval_fh = new FileHandle "> $ofile";
    die "can't create $ofile" unless $eval_fh;

    my ( $byte, $bit, $layout );
    while (<$th>) {

        # print;
        s/[\n\r]+$//g;

        next unless ($_);    ## skip blank lines

        my $x = Data::Table::parseCSV($_);
        my ( $loc, $name ) = @$x;
        if ( $loc =~ /^layout\s+(.*)/i ) {
            $layout           = uc($1);
            $byte             = "";
            $bit              = "";
            $layouts{$layout} = [];
        }
        elsif ( $loc =~ /^bytes?\s+(.*)/i ) {
            $byte = $1;
            $bit  = "";
        }
        elsif ( $loc =~ /^bits?\s+(.*)/i ) {
            $bit = $1;
        }
        $loc = "$byte:$bit";

        ## stuff an anon array ref onto the layout hash for the current rec.
        push( @{ $layouts{$layout} }, [ $loc, $name ] );

        # print "layout: [$layout] byte: [$byte] bit: [$bit]\n";
        # foreach my $q (@$x){
        # 	print "\t[$q]\n";
        # }
        # print "\n";
    }

    #my  $t = Data::Table::fromCSV("caddx_fmt.csv");       # Read a csv file into a table oject
    #print $t->html;
    my $code_pkg = <<"BEGINPKG";
		use strict;
		package caddx::parse;
		use vars qw/\%laycode/;
BEGINPKG
    print $eval_fh $code_pkg || die "can't write to eval_fh";

    my $code_begin_init;
    foreach my $key ( sort keys %layouts ) {
        print "found layout: $key\n";
        my $code;
        $code_begin_init .= "\t\$laycode{'$key'}=\\&parse_$key;\n";
        $code .= <<"BEGINCMT";
		##################################################
		##  Dynamically generated code to parse layout [$key]
		##  DO NOT MODIFY THIS FILE! (look at $0)
		##################################################
		sub parse_$key {
BEGINCMT
        $code .= <<'BEGINCODE';
			my ($msg)=@_;
			my (@msgb)=split(//,$msg); # msgbytes
			unshift(@msgb,"\x7e"); #placeholder for 1-based array
			my (@msgdata);
			my (%msghash);
			my ($datum);
			foreach my $byte (@msgb){
				printf("[%02x]",ord($byte));
			}
				print "\n";
BEGINCODE

        foreach my $data ( @{ $layouts{$key} } ) {
            print "\t", join( " | ", @$data ), "\n";
            my ( $loc, $name ) = @$data;
            $name =~ s/'//g;    # no (nested) quotes in the name field
            if ( $loc =~ /([-\d]+):([-\d]*)/ ) {
                my $byte = $1;
                my $bit  = $2;

                if ( $bit =~ /\d+/ ) {
                    $code .=
                      "\$datum=&caddx::parse::getbits(\$msgb[$byte],'$bit') ;\n";
                    ## $code .= "push(\@msgdata, ['$loc','$name',&getbits(\$msgb[$byte],'$bit') ]);\n";
                }
                elsif ( defined $byte ) {

                    # process byte range as slice
                    my $bytesrc;
                    if ( $byte =~ s/-/../g ) {

                        # convert slice back to string
                        $bytesrc = "join('',\@msgb[$byte])";
                    }
                    else {
                        $bytesrc = "\$msgb[$byte]";
                    }
                    $code .= "\$datum=$bytesrc;\n";
                    ## $code .= "push(\@msgdata,['$loc','$name',$bytesrc]);\n";
                }
                else {
                    $code .= "\$datum='';\n";
                    ##$code .= "push(\@msgdata,['$loc','$name','']);\n # no data";
                }
                $code .= "push(\@msgdata,['$loc','$name',\$datum]);\n";

                ## if we need to save it in the hash...
                if ( $name =~ /{(\w+)}/ ) {
                    my $key = $1;
                    $code .= "\$msghash{$key}=\$datum;\n";

                }
            }
        }
        $code .= <<'ENDCODE';
			$msghash{_parsed_}=\@msgdata;    # stash verbose parse
			return \%msghash;    # send back a hash ref to all
		}
ENDCODE

        print $code;
        print $eval_fh $code || die "can't write to eval_fh";
        my $ref = eval $code;
        if ( ref($ref) eq "CODE" ) {
            $laycode{$key} = $ref;
            print "key [$key] has ref of $ref :", ref($ref), " \n";
        }
        else {
            ## no longer using anon subs
            # die "dyna sub won't eval [$ref]\n";
        }
    }

    my $code_common;
    $code_common .= "sub BEGIN{$code_begin_init};";
    $code_common .= <<'ENDCOMMON';
		sub getbits{
			my ($msg,$bits)=@_;
			
			my $debug=0;
			$msg=ord($msg);
			my $orig_msg=$msg;
			if($bits =~/(\d+)-?(\d*)/){
				my $startb=$1;
				my $endb=$2;
				$endb=$startb unless $endb=~/\d/;  # end is opt, dflt to start
				$msg= $msg >> $startb;
				my $bitcount=($endb-$startb)+1;
				## $debug && print "getbits: startb: $startb endb: $endb count:$bitcount\n";
				my $mask;
				while($bitcount-- > 0){
					$mask=$mask <<1; # left shift prior mask
					$mask=$mask | 1; # turn on a new bit
				}
				my $rc=($msg & $mask);
				$debug && printf("getbits msg:[%02x] bits:[%s], gave:[%s]\n",
					$orig_msg,$bits,$rc);
				return($rc);
			}
			return (-1);

		}
		1;
ENDCOMMON
    print $eval_fh $code_common || die "can't write to eval_fh";
}

&main();
1;
