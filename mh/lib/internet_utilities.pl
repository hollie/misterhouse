#---------------------------------------------------------------------------
#  File:
#      internet_utitiltes.pl
#  Description:
#      perl functions for doing internet stuff
#  Author:
#      Bruce Winter    winter@isl.net  http://www.isl.net/~winter
#  Latest version:
#      http://www.isl.net/~winter/house/programs
#  Change log:
#    11/23/96  Created.
#---------------------------------------------------------------------------

use strict;

package internet_utilities;

                            # Get password, userid, host from config file
require 'handy_utilities.pl';
my %parms;
&main::read_opts(\%parms, "$main::Pgm_Path/mh.ini");

sub main::urlget {
    use Win32;
    use Win32::Internet;
    my(%parms) = @_;
    my $I = new Win32::Internet();
    unless ($parms{'quiet'}) {
	print "Getting data from:  $parms{'url'}\n";
	print "Storing data to:    $parms{'file'}\n" if $parms{'file'};
    }
    my($data) = $I->FetchURL($parms{'url'});
    my($err) = $I->Error();
    unless ($data) {
	print "$main::pgm urlget error: $err\n";
	$data = " web page data not found for $parms{'url'}\n";
    }
    if ($parms{'file'}) {
	open (OUT, ">$parms{'file'}") or die "Error, could not open urlget output file $parms{'file'}: $!\n\n";
	print OUT $data;
	close OUT;
    }
    undef $I;
    return $data;
}

sub main::ftp {
    use Win32;
    use Win32::Internet;

    my(%parms) = @_;
    my $I = new Win32::Internet();

    $parms{'host'} = $main::opt_net_host unless $parms{'host'};
    $parms{'user'} = $main::opt_net_user unless $parms{'user'};
    $parms{'user'} = 'anonymous' unless $parms{'user'};
    $parms{'password'} = $main::opt_net_www_password unless $parms{'password'};
    $parms{'password'} = $ENV{'netpass'} unless $parms{'password'};
    $parms{'password'} = $main::opt_net_mail_address unless $parms{'password'};

    unless ($parms{'quiet'}) {
	print "Running ftp command: $parms{'command'}\n";
	print "user:            $parms{'user'}\n";
	print "host:            $parms{'host'}\n";
	print "password:        $parms{'password'}\n";
	print "ftp directory:   $parms{'ftpdir'}\n";
	print "local directory: $parms{'localdir'}\n" if $parms{'localdir'};
	print "local files:     $parms{'files'}\n" if $parms{'files'};
	print "local file:      $parms{'file'}\n" if $parms{'file'};
	print "\n";
    }
    print "Connecting to $parms{'host'}\n"  unless $parms{'quiet'};
    my $FTP;
    undef $FTP;
    $I->FTP($FTP, $parms{'host'}, $parms{'user'}, $parms{'password'});

    unless ($FTP) {
	my($num,$text)=$I->Error();
	print "$main::pgm ftp connect error: [$num] $text\n\n";
	return;
    }	
    my $result = $FTP->GetResponse();
    print "FTP connect response\n  $result\n" unless $parms{'quiet'};

    $result = $FTP->Cd($parms{'ftpdir'});
    my $err=$FTP->Error();
    print "$main::pgm ftp cd error: $err\n\n" unless $result;

    my @files = split(',', $parms{'files'});
    
    if ($parms{'file'}) {
	my ($file_path, $member) = $parms{'file'} =~ /(.*)\/(.*)/;
	$member = $parms{'file'} unless $member;
	$parms{'localdir'} = $file_path if $file_path;
	push(@files, $member);
    }


    chdir($parms{'localdir'}) if $parms{'localdir'};

    my $file;
    foreach $file (@files) {
	my $command = $parms{'command'};
	$command = ucfirst($command);
#	$result = $FTP->Put($file, $file);
#	$FTP->Delete($file) if $command eq "Put";  # In case remote file exists
	my $localfile = $file;
	$localfile = "$parms{'localdir'}\\$localfile" if $parms{'localdir'};
	unlink $localfile if $command eq "Get";    # In case local file exists
	print "Running ftp command=$command for file=$file\n";
	my $result = $FTP->$command($file, $file);
	my $err=$FTP->Error();
	print "$main::pgm ftp error: $err\n" unless $result;
#	print "FTP $command response\n  ", $result, "\n\n" unless $parms{'quiet'};
	print "File $file has been FTPed\n\n" if $result;
    }
    
    $FTP->Close();
    $I->Close();
    undef $I;        # If we don't undef, we can not reopen the FTP handle a 2nd time without an error :(

}

sub main::mail_stmp {
    my(%parms) = @_;

    $parms{'mail_server'} = $main::opt_net_mail_server unless $parms{'mail_server'};
    $parms{'user'} = $main::opt_net_mail_user unless $parms{'user'};

    $parms{'from'} = $main::opt_net_mail_address unless $parms{'from'};
    $parms{'to'} = $main::opt_net_mail_forward_address unless $parms{'to'};
    ((print "Error, no 'to' address specified\n"), return) unless $parms{'to'};

    $parms{'subject'} = "No Subject" unless $parms{'subject'};

    open (INFILE, $parms{'file'}) or die "mail_stmp error:  Could not open $parms{'file'}: $!\n";
#   use Winsock;
    
    my $packman='S n a4 x8';
    my $port=25;

                 # No need to mess with client side
#   chop ($hostname=`hostname`);
#   chop ($hostname="100.100.100.1");
#   ($d1,$d2,$d3,$d4,$clntadd)=gethostbyname($hostname);
#   $client=pack($packman,&AF_INET,0,$clntadd);
#   bind(MAIL,$client)||die("bind failed:$!");

                 # Connect with mail server
    my ($d1,$d2,$d3,$d4,$proto,$servadd);
    ($d1,$d2,$proto)=getprotobyname('tcp');
    ($d1,$d2,$d3,$d4,$servadd)=gethostbyname($parms{'mail_server'});
    print "db2b sa=$servadd p=$port pm=$packman\n";
# Hmmm, with 8/97 version of perl 3.0007? this loops and explodes memory usage!
#return;
    my $server=pack($packman,&AF_INET,$port,$servadd);
    $server=print "$packman,&AF_INET,$port,$servadd\n";
    print "db2c\n";
    socket(MAIL,&AF_INET,&SOCK_STREAM,$proto)||die ("socket failed:$!");
    print "db2d\n";
    connect (MAIL,$server)||die("connect failed:$!");
    print "db2e\n";
    binmode(MAIL);
    print "db3\n";
    my $init;
    recv(MAIL,$init,1000,0);

                 # Send the mail
    my $start = "MAIL FROM:$parms{'to'}\nRCPT TO:$parms{'to'}\nDATA\nSUBJECT:$parms{'subject'}\n";
    if ($init = ~/Sendmail/){
	send(MAIL, $start, 0);

    print "db3\n";
	while ($_ = <INFILE>){
	    send (MAIL, $_, 0);
	}
    }
    print "db4\n";
    my $end=".\nQUIT\n\n";

    send(MAIL, $end, 0);
    close (MAIL);

    print ("Mail sent to:$parms{'to'}, subject:$parms{'subject'}\n");
}

1;
