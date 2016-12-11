
# Category=Phone

#@ This module provides an interface to Linux vocp system: http://www.vocpsystem.com
#@ See code for more info.

=begin comment

This module provides an interface to vocp. It uses the .flag-xxx file
to get information on which voicemails are out there.

It supports multiple mailboxes. Maiboxes (and their owners) are
specified by the config parm:

vocp_mailboxes = 'user1=maiboxnumber1,user2=mailboxnumber2';

The directory where vocp stores its messages is set with this config parm:

vocp_voicemail_dir = /var/spool/voice/incoming

This file uses vocp utilities pvftowav and rmdtopvf. This parm point to the directory where these files live:
vocp_bin_dir = /usr/local/bin

To use this code to handle your voicemail, set this config parm:
phone_voicemail_type = vocp

Known Bugs: Right now, if you delete a voicemail, the program thinks a
new message arrived. I will fix that at some point.

Dependencies:

You need XML::Simple and Data::Dumper libraries.

=cut

use XML::Simple;
use Data::Dumper;

# noloop=start
my $vocp_users;
my $first = 1;
my @mailboxes = split ',', $config_parms{vocp_mailboxes};
for my $mailbox (@mailboxes) {
    my ( $thisuser, $boxnum ) = $mailbox =~ /^(\S*)=(\S*)/;
    if ($first) {
        $vocp_users .= $thisuser;
    }
    else {
        $vocp_users .= ", " . $thisuser;
    }
    $first = 0;
}
print "vocp users = $vocp_users";

# noloop=stop

$v_count_voicemails =
  new Voice_Cmd("Count voice mail messages for [$vocp_users]");

if ( my $user = said $v_count_voicemails) {
    my @mailboxes = split ',', $config_parms{vocp_mailboxes};
    my $msgcount = 0;

    for my $mailbox (@mailboxes) {
        my ( $thisuser, $boxnum ) = $mailbox =~ /^(\S*)=(\S*)/;
        if ( lc $user eq $thisuser ) {
            $msgcount = vocp_countmsgs($boxnum);
        }
    }
    respond "$user has $msgcount voicemail messages";
}

sub vocp_countmsgs {
    my $boxnum = shift;
    my $xml    = new XML::Simple;

    my $flagfile = $config_parms{vocp_voicemail_dir} . "/" . ".flag." . $boxnum;

    #    print "checking for file $flagfile\n";
    die "can't find file $flagfile" if ( not( -f $flagfile ) );

    my $data     = $xml->XMLin($flagfile);
    my $msgcount = 0;

    foreach my $key ( sort keys %{ $data->{boxData}->{message} } ) {
        $msgcount++;

    }
    return $msgcount;
}

sub vocp_clearmsgs {

    my ( $user, $mailbox, $message ) = @_;

    #	return '' unless $Authorized eq 'admin' or $Authorized eq 'family';
    return &html_header("Delete voicemail?")
      . "<H2><A HREF=\"/SUB?vocp_deletemsgs($user,$mailbox,$message)\">Continue?</A></H2>";
}

sub vocp_deletemsgs {

    #	return '' unless $Authorized eq 'admin' or $Authorized eq 'family';
    my ( $user, $mailbox, $message ) = @_;
    print "deletemsgs: user:$user mbx:$mailbox message:$message\n"
      if $main::Debug{vocp};
    my $file =
        $config_parms{vocp_voicemail_dir} . "/"
      . $mailbox . "-"
      . $message . ".rmd";

    my $xml = new XML::Simple;

    my $flagfile =
      $config_parms{vocp_voicemail_dir} . "/" . ".flag." . $mailbox;
    print "checking for file $flagfile\n" if $main::Debug{vocp};
    if ( not -f $flagfile ) { die "can't find file" }

    my $data = $xml->XMLin( $flagfile, keyattr => "", forcearray => '1' );
    print Dumper($data) if $main::Debug{vocp};

    open TEST_FILE, ">$flagfile" or die "can't open file";

    my $xmlout;

    $xmlout = '<VOCPMetaData>
  <boxData>';

    for my $key ( @{ $data->{boxData}->[0]->{message} } ) {
        my $msgnum = $key->{id};
        if ( not( $msgnum eq $message ) ) {
            $xmlout .= "\n   <message id=\"$msgnum\">";
            $xmlout .= "\n    <source>\n     phone\n    </source>";
            my $time = $key->{time}->[0];
            $xmlout .= "\n    <time>${time}</time>";
            my $from = $key->{from}->[0];
            $from =~ s/&/&amp;/g;

            #	    $from =~ s/'/&apos;/g; don't think we need this
            print "from is $from\n";
            $xmlout .= "\n    <from>${from}</from>";
            my $size = $key->{size}->[0];
            $xmlout .= "\n    <size>${size}</size>";
            $xmlout .= "\n   </message>";
        }
    }

    $xmlout .= "\n  </boxData>";
    $xmlout .= "\n </VOCPMetaData>\n";

    print $xmlout;
    print TEST_FILE "$xmlout";
    close TEST_FILE or die "can't close file";

    my $html = &vocp_display_voicemail;
    unlink $file or die "cannot delete $file";
    return $html;
}

# check for new voicemails
my @mailboxes = split ',', $config_parms{vocp_mailboxes};
if ($New_Minute) {
    for my $mailbox (@mailboxes) {
        my ( $user, $boxnum ) = $mailbox =~ /^(\S*)=(\S*)/;
        my $file = $config_parms{vocp_voicemail_dir} . '/.flag.' . $boxnum;
        if ( file_changed($file) ) {
            respond "new message $user in mailbox $boxnum";
        }
    }
}

sub vocp_play_voicemail {
    my ( $user, $boxnum, $message ) = @_;
    print "starting args:  ";
    for my $arg (@ARGV) { print "arg is $arg\n"; }

    $message =~ s/message=//;
    $user =~ s/user=//;
    $boxnum =~ s/box=//;
    print "checking for message $message for user $user in box $boxnum";

    my $path     = '/var/spool/voice/incoming/';
    my $filename = $boxnum . "-" . "$message" . '.rmd';
    my $file     = $path . $filename;
    print "checking for file $file\n";

    system
      qq[$config_parms{vocp_bin_dir}/rmdtopvf $file | $config_parms{vocp_bin_dir}/pvftowav > $config_parms{html_dir}/ia5/phone/voicemail1.wav];

    my $html .=
      "\n<br><EMBED SRC='voicemail1.wav' VOLUME=20 WIDTH=144 HEIGHT=60 AUTOSTART='true'>\n";
    return $html;
}

sub vocp_display_voicemail {
    my %callerid_by_number;
    my $html_voicemails;
    my @mailboxes = split ',', $config_parms{vocp_mailboxes};

    for my $mailbox (@mailboxes) {
        my $html_voicemail_hdr;
        my $html_voicemail_data;
        my $num = 0;
        print "working on mailbox $mailbox\n";
        my ( $user, $boxnum ) = $mailbox =~ /^(\S*)=(\S*)/;

        my $file = $config_parms{vocp_voicemail_dir} . '/.flag.' . $boxnum;
        my $xml  = new XML::Simple;
        my $data = $xml->XMLin( $file, keyattr => "", forcearray => '1' );
        print Dumper($data);
        print "working on file $file for user $user\n";

        if ( $#{ $data->{boxData}->[0]->{message} } ne '-1' ) {
            for my $key ( @{ $data->{boxData}->[0]->{message} } ) {
                my $msgnum = $key->{id};
                my $time   = localtime( $key->{time}->[0] );
                my ( $calls, $time2, $date, $name2 );
                my $number_data = $key->{from}->[0];
                my $size        = $key->{size}->[0];
                my $duration    = int $size / 8192;
                $number_data =~ s/[\n]*//g;
                my ( $number, $name ) = $number_data =~ /^[\s]*(\d+) (\S*)/;

                my $good_num = $number =~ /(\d\d\d)(\d\d\d)(\d+)/;
                if ($good_num) {
                    $number = $1 . '-' . $2 . "-" . $3;
                    %callerid_by_number =
                      dbm_read("$config_parms{data_dir}/phone/callerid.dbm")
                      unless %callerid_by_number;
                    my $cid_data = $callerid_by_number{$number};
                    ( $calls, $time2, $date, $name2 ) =
                      $cid_data =~ /^(\d+) +(.+), (.+) name=(.+)/
                      if $cid_data;
                    $name2 = "Not in Database" if $name2 eq '';
                }
                else { $number = 'Unknown'; $name2 = "Not in Database"; }

                $num++;

                $html_voicemail_data .=
                  "<tr id='resultrow' vAlign=center bgcolor='#EEEEEE' class='wvtrow'>";
                $html_voicemail_data .=
                  "<td nowrap>$time</td><td nowrap><a href=\"SUB?vocp_play_voicemail($user,$boxnum,$msgnum)\"><img src='/graphics/sound.gif' border=0 alt='Play message'></a><a href=\"/SUB?vocp_clearmsgs($user,$boxnum,$msgnum)\"><img src='/graphics/trash.gif' border=0 alt='Delete message'></a>&nbsp;$number</td><td nowrap>$name2</td><td nowrap>$duration</td></tr>";

            }
            $html_voicemail_hdr .= &html_header("$num Messages for $user ");

            $html_voicemail_hdr .=
              "<table width=100% cellspacing=2><tbody><font face=COURIER size=2>
<tr id='resultrow' bgcolor='#9999CC' class='wvtheader'>
<th align='left'>Time</th>
<th align='left'>Number</th>
<th align='left'>Name</th>
<th align='left'>Duration</th>";

            $html_voicemails .= $html_voicemail_hdr;
            $html_voicemails .= $html_voicemail_data;
            $html_voicemails .= "</font></tbody></table>";
        }

    }

    print_log "html_voicemails is $html_voicemails";

    my $html = "<html>
<head>
<style>
TR.wvtrow {font-family:Arial; font-size:11; color:#000000}
TR.wvtheader {font-family:Tahoma; font-size:11; color:#101010}
</style>
</head>
<body>" . &html_header('Voicemail Messages');

    $html .= $html_voicemails . "
</body>
";

    print $html;

    my $htmlfooter .= qq[
<script language="javascript">
<!--
try{
  if (resultrow.length>1) {
    for (x=1;x<resultrow.length;x++) {
      if (x%2==0) {resultrow[x].style.backgroundColor='#DDDDDD';}
    }
  }
}
catch(er){}
// -->
</script>
</html>
];

    print_log "html is $html\n";
    my $html_page = &html_page( '', $html . $htmlfooter );
    print_log "page is $html_page\n";
    return &html_page( '', $html . $htmlfooter );

}
