# Category=Misc

=begin comment

From Richard Smith  on 12/2002

I purchased one of these Creative Credit Card Remotes a few months back and
wasn't very happy with the included software, so I decoded the protocol for
use with MH recently.  The 24 button remote comes with a serial connected IR
receiver for only $8 (see the link below).  I have attached a simple pl file I
used for testing.  It could easily be used with any existing MH multimedia
control.  I am planning on using it for either the MH MP3 control or a MH
Video Control I am working on.  I am making it available here for anyone
interested in using it.  Please share any thoughts.

http://www.compgeeks.com/details.asp?invtid=CIMR100

Include the following lines in your ini file: (customize for your setup)

serial2_port=COM4
serial2_baudrate=2400
serial2_handshake=none
serial2_datatype=raw

=cut

my $data;
my @code;
my $command;
my %ir_creative = (
    2556888397 => 'play',
    1487340877 => 'stop',
    3626435917 => 'pause',
    952567117  => 'eject',
    3091662157 => 'previous',
    2022114637 => 'rewind',
    4161209677 => 'forward',
    83559757   => 'next',
    2222654797 => '1',
    1153107277 => '2',
    3292202317 => '3',
    618333517  => 'shift',
    2757428557 => '4',
    1687881037 => '5',
    3826976077 => '6',
    350946637  => 'mouse',
    2490041677 => '7',
    1420494157 => '8',
    3559589197 => '9',
    885720397  => 'vol+',
    3024815437 => 'start',
    1955267917 => '0',
    4094362957 => 'mute',
    217253197  => 'vol-'
);

$creative_remote = new Serial_Item( undef, undef, 'serial2' );

if ( $data = said $creative_remote ) {
    @code = unpack( "I*", $data );
    $command = $ir_creative{ join "", @code };
    print_log "Creative: $command";
}
