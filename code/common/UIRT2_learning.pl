
# Category = IR

#@ Use this script to learn and import codes for the
#@ <a href='http://www.fukushima.us/UIRT2/'>UIRT2 2 way IR interface</a>.
#@ To enable this code, add the uirt2_* parms listed at the top of
#@ <a href='/bin/browse.pl?/lib/UIRT2.pm'>UIRT2.pm</a>,
#@ then click <a href="/SUB;uirt2_update_html">here</a> or click on the IR category button.

=begin comment 

10/03/2002	Created by David Norwood (dnorwood2@yahoo.com)
01/14/2003	clicking on devices and functions automatically loads them 
07/14/2005	added some features from usb uirt learning script like send_ofa_key, dvc_commit 

To enable the UIRT2 module, add these entries to your .ini file: 

uirt2_module=UIRT2
uirt2_port=/dev/ttyS1	# optional, defaults to COM1
uirt2_baudrate=115200	# optional, defaults to 115200

$config_parms{uirt2_module} $config_parms{uirt2_port} $config_parms{uirt2_baudrate}

=cut

my ( @devices, @functions, $prev_device, $current_device, $current_function,
    $ofa_html );
use vars '$uirt2_function_pcode';

use UIRT2;
use IR_Utils;

if ($Reload) {
    &IR_Utils::init_ir_utils;
    $Included_HTML{'IR'} =
      '<!--#include code="&uirt2_update_html"-->' . "\n\n\n";
    $ofa_html = &ofa_html;
}

$uirt2_test = new Voice_Cmd(
    "uirt2 debug [version,raw,uir,struct,gpio,replay,learn,dump codes]");

if ( my $state = said $uirt2_test) {
    UIRT2::get_version()    if $state eq 'version';
    UIRT2::set_moderaw()    if $state eq 'raw';
    UIRT2::set_modeuir()    if $state eq 'uir';
    UIRT2::set_modestruct() if $state eq 'struct';
    UIRT2::get_gpiocaps()   if $state eq 'gpio';
    UIRT2::send_ir_code( 'tv', 'volume down' ) if $state eq 'replay';
    UIRT2::learn_code( 'tv', 'volume down' ) if $state eq 'learn';
    dump_codes() if $state eq 'dump codes';
}

sub uirt2_update_html {

    #    print_log "Updating HTML";
    #        <META HTTP-EQUIV="REFRESH" CONTENT="6; url=' . "'" . 'SUB;referer?uirt2_update_html()' . "'" . '">
    my $html;
    if ( UIRT2::is_learning() ) {
        $html = '
        <META HTTP-EQUIV="REFRESH" CONTENT="6">
        <h1><b><p align=center>Learning</p></b></h1>
        ';
        return $html;
    }
    $html = '
      <form action="SET;referer" target="control" name=fm>
      <table border=0 cellspacing=0 cellpadding=8><tr>
      <td colspan=2><b>Devices</b><spacer height=20></td>
      <td colspan=2><b>Functions</b><spacer height=20></td></tr>
      <tr><td valign=top>
      <select name="$uirt2_device_list" size="15" onChange="form.submit()">
      ';
    @devices        = UIRT2::list_devices();
    $current_device = $devices[ state $uirt2_device_list] if @devices;
    $current_device = $devices[0] if $current_device eq '' and @devices;
    my $i = 0;
    foreach (@devices) {
        $html .=
            '<option value="'
          . $i++
          . ( $current_device eq $_ ? '" selected>' : '">' )
          . $_
          . "&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp\n";
    }
    $html .= '
      </select></td>
      <td valign=top>
      Device Name<br>
      <input value="" size="10" name=$uirt2_device_text>
      <input type=submit value="Add" name=$uirt2_device_add><br>
      <input type=submit name=$uirt2_device_delete value="Delete"><br>
      <input type=submit name=$uirt2_device_rename value="Rename"><br>
      </td>
      ';
    $html .= '
      <td valign=top>
      <select name="$uirt2_function_list" size="15" onChange="form.submit()">
      ';
    @functions = ();
    @functions = UIRT2::list_functions($current_device)
      if $current_device ne '';
    $current_function = $functions[ state $uirt2_function_list] if @functions;
    $current_function = $functions[0]
      if $current_function eq ''
      or $current_device ne $prev_device and @functions;
    $prev_device = $current_device;
    $i           = 0;

    foreach (@functions) {
        $html .=
            '<option value="'
          . $i++
          . ( $current_function eq $_ ? '" selected>' : '">' )
          . $_
          . "&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp\n";
    }
    my ( $frequency, $repeat, $code1, $code2 ) =
      UIRT2::get_ir_code( $current_device, $current_function );
    my $pronto;
    ($pronto) =
      UIRT2::raw_to_pronto(
        UIRT2::struct_to_raw( $frequency, $repeat, $code1, $code2 ) );
    $html .= '
      </select></td>
      <td valign=top>
      Function Name<br>
      <input value="" size="30" name=$uirt2_function_text>
      <input type=submit value="Learn" name=$uirt2_function_learn><br>
      <input type=submit value="Create" name=$uirt2_function_new><br>
      <input type=submit name=$uirt2_function_delete value="Delete"><br>
      <input type=submit name=$uirt2_function_rename value="Rename"><br>
      <input type=submit name=$uirt2_function_send value="Send"><br>
      UIRT2 Code<br>
      1 <input value="' . $code1 . '" size="70" name=$uirt2_function_code1><br> 
      2 <input value="' . $code2 . '" size="70" name=$uirt2_function_code2><br> 
      Frequency
      <input type="radio" value="36" name=$uirt2_function_frequency'
      . ( $frequency == 36 ? ' checked' : '' ) . '>36
      <input type="radio" value="38" name=$uirt2_function_frequency'
      . ( $frequency == 38 ? ' checked' : '' ) . '>38
      <input type="radio" value="40" name=$uirt2_function_frequency'
      . ( $frequency == 40 ? ' checked' : '' ) . '>40 kHz 
      &nbsp&nbsp&nbsp Repeat <input value="' . $repeat
      . '" size="5" name=$uirt2_function_repeat>
      &nbsp&nbsp&nbsp <input type=submit value="Modify" name=$uirt2_function_modify><br>
	Generate from Protocol Spec<br>
      Protocol <select name="$uirt2_gen_protocol">
      ';
    my @protocols = IR_Utils::get_protocol_names();

    foreach (@protocols) {
        $html .= '<option>' . $_ . "\n";
    }
    $html .= '
      </select>
      Device # <input value="" size="10" name=$uirt2_gen_device>
      Function # <input value="" size="10" name=$uirt2_gen_function>
      <input type=submit value="Generate" name=$uirt2_gen_commit><br>
	Generate from DVC File<br>
      DVC File <select name="$uirt2_dvc_file">
      ';
    my @dvc_files = IR_Utils::get_dvc_files();
    foreach (@dvc_files) {
        $html .= '<option>' . $_ . "\n";
    }
    $html .= '
      </select>
      <input type=submit value="Generate" name=$uirt2_dvc_commit><br>
      </td></tr>
      <tr><td colspan=4>
      Pronto Code<br>
      <textarea name=$uirt2_function_pcode Rows=8 COLS=84 wrap="hard">'
      . $pronto . '</textarea>  
      <input type=submit value="Import" name=$uirt2_function_import><br>
      You can find Pronto codes at <a target="_BLANK" href="http://www.remotecentral.com">Remote Central</a> and
      at <a target="_BLANK" href="http://ir.premisesystems.com/">Premise Systems</a>.<p>
      ';
    my $raw = UIRT2::last_learned();
    $html .= '
      Last learned raw code (for debugging)<br>
      <textarea name=$uirt2_function_raw Rows=8 COLS=100 wrap="hard">' . $raw
      . '</textarea>  
      ' if $raw;
    $html .= '
      <a target="control" href="SUB;referer?uirt2_update_html()">Refresh</a><br>
      </td></tr></table>
      </form>
      ';
    return $html . $ofa_html;
}

$uirt2_device_list   = new Generic_Item;
$uirt2_device_add    = new Generic_Item;
$uirt2_device_text   = new Generic_Item;
$uirt2_device_load   = new Generic_Item;
$uirt2_device_delete = new Generic_Item;
$uirt2_device_rename = new Generic_Item;

if ( state_now $uirt2_device_add) {
    my $device = uc state $uirt2_device_text;
    return unless $device;
    print_log "Adding device $device";
    UIRT2::add_device($device);
    $current_device   = $device;
    $current_function = '';
}

if ( state_now $uirt2_device_load) {
    my $dev = state $uirt2_device_list;
    $current_device = $devices[$dev] if $dev =~ /\d+/;
    $current_function = '';
}

if ( state_now $uirt2_device_delete) {
    my $dev = state $uirt2_device_list;
    UIRT2::delete_device( $devices[$dev] ) if $dev =~ /\d+/;
    $current_device   = '';
    $current_function = '';
}

if ( state_now $uirt2_device_rename) {
    my $dev    = state $uirt2_device_list;
    my $device = uc state $uirt2_device_text;
    UIRT2::rename_device( $devices[$dev], $device )
      if $dev =~ /\d+/ and $device;
    $current_device   = $device;
    $current_function = '';
}

$uirt2_function_list   = new Generic_Item;
$uirt2_function_learn  = new Generic_Item;
$uirt2_function_new    = new Generic_Item;
$uirt2_function_text   = new Generic_Item;
$uirt2_function_load   = new Generic_Item;
$uirt2_function_delete = new Generic_Item;
$uirt2_function_rename = new Generic_Item;
$uirt2_function_send   = new Generic_Item;

#$uirt2_function_pcode = new Generic_Item;
$uirt2_function_import    = new Generic_Item;
$uirt2_function_code1     = new Generic_Item;
$uirt2_function_code2     = new Generic_Item;
$uirt2_function_frequency = new Generic_Item;
$uirt2_function_repeat    = new Generic_Item;
$uirt2_function_modify    = new Generic_Item;
$uirt2_function_raw       = new Generic_Item;

if ( state_now $uirt2_function_learn) {
    my $dev = state $uirt2_device_list;
    my $device;
    $device         = $devices[$dev]           if $dev =~ /\d+/;
    $device         = state $uirt2_device_text if state $uirt2_device_text;
    $current_device = $device                  if $device;
    my $func = state $uirt2_function_list;
    my $function;
    $function = $functions[$func]             if $func =~ /\d+/;
    $function = uc state $uirt2_function_text if state $uirt2_function_text;
    $current_function = $function if $function;
    my $frequency = state $uirt2_function_frequency;
    my $repeat    = 1;
    print_log "Learning device $device function $function";
    UIRT2::learn_code( $device, $function, $frequency, $repeat );
}

if ( state_now $uirt2_function_delete) {
    my $device = $current_device;
    my $func   = state $uirt2_function_list;
    my $function;
    $function = $functions[$func] if $func =~ /\d+/;
    print_log "Deleting device $device function $function";
    UIRT2::delete_function( $device, $function );
    $current_function = '';
}

if ( state_now $uirt2_function_load) {
    my $func = state $uirt2_function_list;
    $current_function = $functions[$func] if $func =~ /\d+/;
}

if ( state_now $uirt2_function_send) {
    my $device = $current_device;
    my $func   = state $uirt2_function_list;
    my $function;
    $function         = $functions[$func] if $func =~ /\d+/;
    $current_function = $function         if $function;
    print_log "Sending device $device function $function";
    UIRT2::set( $device, $function );
}

if ( state_now $uirt2_function_rename) {
    my $device = $current_device;
    my $func   = state $uirt2_function_list;
    my $function;
    $function = $functions[$func] if $func =~ /\d+/;
    my $funcnew;
    $funcnew = uc state $uirt2_function_text if state $uirt2_function_text;
    $current_function = $funcnew if $funcnew;
    print_log "Renaming device $device function $function to $funcnew";
    UIRT2::rename_function( $device, $function, $funcnew );
}

if ( state_now $uirt2_function_import) {
    my $device = $current_device;
    my $func   = state $uirt2_function_list;
    my $function;
    $function = $functions[$func]             if $func =~ /\d+/;
    $function = uc state $uirt2_function_text if state $uirt2_function_text;
    $current_function = $function if $function;
    my $repeat = 1;

    #	my $pcode = state $uirt2_function_pcode;
    print_log
      "Importing device $device function $function pronto $uirt2_function_pcode";
    UIRT2::set_ir_code(
        $device,
        $function,
        UIRT2::raw_to_struct(
            UIRT2::pronto_to_raw( $uirt2_function_pcode, $repeat )
        )
    );
}

if ( state_now $uirt2_function_new) {
    my $device    = $current_device;
    my $code1     = state $uirt2_function_code1;
    my $code2     = state $uirt2_function_code2;
    my $frequency = state $uirt2_function_frequency;
    my $repeat    = state $uirt2_function_repeat;
    $repeat = 1 unless $repeat =~ /^\d+$/;
    my $funcnew;
    $funcnew = uc state $uirt2_function_text if state $uirt2_function_text;
    $current_function = $funcnew if $funcnew;
    print_log "Creating device $device function $funcnew";
    UIRT2::set_ir_code( $device, $funcnew, $frequency, $repeat, $code1,
        $code2 );
}

if ( state_now $uirt2_function_modify) {
    my $device    = $current_device;
    my $function  = $current_function;
    my $code1     = state $uirt2_function_code1;
    my $code2     = state $uirt2_function_code2;
    my $frequency = state $uirt2_function_frequency;
    my $repeat    = state $uirt2_function_repeat;
    $repeat = 1 unless $repeat =~ /^\d+$/;
    print_log "Modlfying device $device function $function";
    UIRT2::set_ir_code( $device, $function, $frequency, $repeat, $code1,
        $code2 );
}

$uirt2_gen_protocol = new Generic_Item;
$uirt2_gen_device   = new Generic_Item;
$uirt2_gen_function = new Generic_Item;
$uirt2_gen_commit   = new Generic_Item;

if ( state_now $uirt2_gen_commit) {
    my $device       = $current_device;
    my $function     = $current_function;
    my $gen_protocol = state $uirt2_gen_protocol;
    my $gen_device   = state $uirt2_gen_device;
    my $gen_function = state $uirt2_gen_function;
    print_log "Generating device $device function $function";
    UIRT2::set_ir_code(
        $device,
        $function,
        UIRT2::raw_to_struct(
            UIRT2::pronto_to_raw(
                &IR_Utils::generate_pronto(
                    $gen_protocol, $gen_device, $gen_function
                )
            )
        )
    );
}

$uirt2_dvc_file = new Generic_Item;
$uirt2_dvc_file->set_casesensitive;
$uirt2_dvc_commit = new Generic_Item;

if ( state_now $uirt2_dvc_commit) {
    my $dvc_file = state $uirt2_dvc_file;
    my ( $device, $repeat, %prontos ) = &IR_Utils::read_dvc_file($dvc_file);
    print_log "Generating device $device from DVC file $dvc_file";
    foreach my $function ( keys %prontos ) {
        UIRT2::set_ir_code( $device, $function,
            UIRT2::raw_to_struct( UIRT2::pronto_to_raw( $prontos{$function} ) )
        );
    }
}

sub ofa_html {
    my $sub_prev;
    my $mfgs_prev;
    my $list = '<h2>Pick a Device to Autogenerate</h2><p>';
    foreach (&IR_Utils::ofa_bysub) {
        my ( $sub, $type, $mfgs, $code ) = split "$;";
        $list .= "<p>\n$sub ($type)" if "$sub$;$type" ne $sub_prev;
        $list .= "<br>\n\t$mfgs "    if $mfgs ne $mfgs_prev;
        $list .= ", "                if $mfgs eq $mfgs_prev;
        $list .=
            "<a target='control' href=" . '"'
          . "SUB;referer?uirt2_add_ofa_device('$mfgs $sub','$type','$code')"
          . '"'
          . ">$code</a>";
        $list .=
            " [<a target='speech' href=" . '"'
          . "SUB;send_ofa_key('$type','$code','POWER')" . '"'
          . ">test</a>]";
        $sub_prev  = "$sub$;$type";
        $mfgs_prev = $mfgs;
    }
    $list .= '<p>';
    return $list;
}

sub uirt2_add_ofa_device {
    my $device_name = shift;
    my $type        = shift;
    my $code        = shift;
    print_log "Adding device $device_name $type $code";
    my ( $repeat, %prontos ) = &IR_Utils::generate_ofa_device( $type, $code );
    while ( my ( $key, $pronto ) = each %prontos ) {
        UIRT2::set_ir_code( $device_name, $key,
            UIRT2::raw_to_struct( UIRT2::pronto_to_raw( $pronto, $repeat ) ) );
    }
    $current_device   = uc $device_name;
    $current_function = '';
}

sub send_ofa_key {
    my $type = shift;
    my $code = shift;
    my $key  = shift;
    my %keys = &IR_Utils::get_ofa_keys( $type, $code );
    my $efc  = $keys{$key};
    my ( $protocol, $device, $function ) =
      &IR_Utils::get_function( $type, $code, $efc );
    print
      "$type $code $key protocol $protocol efc $efc device $device function $function\n";
    my ( $pronto, $repeat ) =
      &IR_Utils::generate_pronto( uc $protocol, $device, $function );
    UIRT2::transmit_pronto( $pronto, $repeat );
}

sub dump_codes {
    $current_device = $devices[ state $uirt2_device_list] if @devices;
    print "Manufacturer=\nModel=$current_device\n\n[Key Codes]\n\n";
    my @functions = UIRT2::list_functions($current_device)
      if $current_device ne '';
    foreach ( sort @functions ) {
        my ($pronto) =
          UIRT2::raw_to_pronto(
            UIRT2::struct_to_raw( UIRT2::get_ir_code( $current_device, $_ ) ) );
        print "$_ = $pronto\n\n";
    }
}
