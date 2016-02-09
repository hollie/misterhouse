
# Category = IR

#@ Use this code file to learn and import codes for the
#@ <a href='http://home.earthlink.net/~jrhees/USBUIRT/index.htm'>USB-UIRT 2 way IR interface</a>.
#@ To enable this code, add the usb_uirt_* parms listed at the top of
#@ <a href='/bin/browse.pl?/lib/USB_UIRT.pm'>USB_UIRT.pm</a>,
#@ then click <a href="/SUB;usb_uirt_update_html">here</a> or click on the IR category button.
#@ Windows is now supported using the uuirt.DLL driver.  Note: Learning is still not working
#@ in this release.  Support for the USB-UIRT is included in the ftdi_sio driver in the 2.4.22
#@ Linux kernel.

=begin comment 

03/26/2003	Created by David Norwood (dnorwood2@yahoo.com)

To enable the USB_UIRT module, add these entries to your .ini file: 

usb_uirt_module=USB_UIRT
usb_uirt_port=/dev/ttyUSB1	# optional, defaults to /dev/ttyUSB0, not used on Windows 

$config_parms{usb_uirt_module} $config_parms{usb_uirt_port} 

=cut

my ( @devices, @functions, $prev_device, $current_device, $current_function,
    $ofa_html );
use vars '$usb_uirt_function_code';

use USB_UIRT;
use IR_Utils;

if ($Reload) {
    &IR_Utils::init_ir_utils;
    $Included_HTML{'IR'} =
      '<!--#include code="&usb_uirt_update_html"-->' . "\n\n\n";
    $ofa_html = &ofa_html;
}

$usb_uirt_test = new Voice_Cmd(
    "usb_uirt debug [version,raw,oldraw,uir,get config,learn,dump codes]");

if ( my $state = said $usb_uirt_test) {
    USB_UIRT::get_version()    if $state eq 'version';
    USB_UIRT::set_moderaw()    if $state eq 'raw';
    USB_UIRT::set_modeoldraw() if $state eq 'oldraw';
    USB_UIRT::set_modeuir()    if $state eq 'uir';
    USB_UIRT::get_config()     if $state eq 'get config';
    USB_UIRT::learn_code( 'test device', 'test function' ) if $state eq 'learn';
    dump_codes() if $state eq 'dump codes';
}

sub usb_uirt_update_html {

    #    print_log "Updating HTML";
    #        <META HTTP-EQUIV="REFRESH" CONTENT="6; url=' . "'" . 'SUB;referer?usb_uirt_update_html()' . "'" . '">
    my $html;
    if ( USB_UIRT::is_learning() ) {
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
      <tr><td valign=top halign=right>
      <select name="$usb_uirt_device_list" size="15" onChange="form.submit()">
      ';
    @devices        = USB_UIRT::list_devices();
    $current_device = $devices[ state $usb_uirt_device_list] if @devices;
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
      <td valign=top halign=left>
      Device Name<br>
      <input value="" size="10" name=$usb_uirt_device_text>
      <input type=submit value="Add" name=$usb_uirt_device_add><br>
      <input type=submit name=$usb_uirt_device_delete value="Delete"><br>
      <input type=submit name=$usb_uirt_device_rename value="Rename"><br>
      </td>
      ';
    $html .= '
      <td valign=top>
      <select name="$usb_uirt_function_list" size="15" onChange="form.submit()">
      ';
    @functions = ();
    @functions = USB_UIRT::list_functions($current_device)
      if $current_device ne '';
    $current_function = $functions[ state $usb_uirt_function_list]
      if @functions;
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
      USB_UIRT::get_ir_code( $current_device, $current_function );
    my ( $pronto, $raw );
    if ( $code1 =~ /^0000 / ) {
        $pronto = lc $code1;
    }
    else {
        $raw = $code1;
        $raw .= " $code2" if $code2;
        ($pronto) =
          USB_UIRT::raw_to_pronto(
            USB_UIRT::struct_to_raw( $frequency, $repeat, $code1, $code2 ) );
    }

    #      <input type=submit value="Learn" name=$usb_uirt_function_learn>
    $html .= '
      </select></td>
      <td valign=top>
      Function Name<br>
      <input value="" size="30" name=$usb_uirt_function_text>
      <input type=submit value="Create" name=$usb_uirt_function_new><br>
      <input type=submit name=$usb_uirt_function_delete value="Delete"><br>
      <input type=submit name=$usb_uirt_function_rename value="Rename"><br>
      <input type=submit name=$usb_uirt_function_send value="Send"><br>
      Frequency <input size="3" value="'
      . $frequency . '" name=$usb_uirt_function_frequency>
      &nbsp&nbsp&nbsp Repeat <input value="' . $repeat
      . '" size="2" name=$usb_uirt_function_repeat>
      &nbsp&nbsp&nbsp <input type=submit value="Modify" name=$usb_uirt_function_modify><br>
      </td></tr>
      <tr><td colspan=4>
<h2>Import a Code</h2>
Enter a device name and click "Add", then enter a function name.  Now you can
enter your Pronto or USB-UIRT Raw code into the "Code" field and click "Create". 
Repeat for the other functions on that device.
Pronto codes start with 0000, and USB-UIRT Raw codes start with either F##R## or R##.<p>
      <b>Code</b><br>
      <textarea name=$usb_uirt_function_code Rows=8 COLS=84 wrap="hard">'
      . ( $raw ? $raw : $pronto ) . '</textarea>
      <input type=submit value="Import" name=$usb_uirt_function_import><br>
      ' . ( $raw ? "<p>Pronto code: $pronto<p>" : '' ) . '
      You can find Pronto codes at <a target="_BLANK" href="http://www.remotecentral.com">Remote Central</a> and
      at <a target="_BLANK" href="http://ir.premisesystems.com/">Premise Systems</a>.<p>
<h2>Generate from Protocol Spec</h2>
If you know the protocol, device number, and function number for the signal, enter them here.  
You do not need to create a device or function above.<p>
      Protocol <select name="$usb_uirt_gen_protocol">
	<option>
      ';
    my @protocols = IR_Utils::get_protocol_names();

    foreach (@protocols) {
        $html .= '<option>' . $_ . "\n";
    }
    $html .= '
      </select>
      Device # <input value="" size="10" name=$usb_uirt_gen_device>
      Function # <input value="" size="10" name=$usb_uirt_gen_function>
      <input type=submit value="Generate" name=$usb_uirt_gen_commit><br>
<h2>Generate from DVC File</h2>
If you have a DVC file for your device, put it in the devicelib directory and select it here.  
You do not need to create a device or function above.<p>
      DVC File <select name="$usb_uirt_dvc_file">
      ';
    my @dvc_files = IR_Utils::get_dvc_files();
    foreach (@dvc_files) {
        $html .= '<option>' . $_ . "\n";
    }
    $html .= '
      </select>
      <input type=submit value="Generate" name=$usb_uirt_dvc_commit><br>
      ';
    my $raw = USB_UIRT::last_learned();
    $html .= '
      Last learned raw code (for debugging)<br>
      <textarea name=$usb_uirt_function_raw Rows=8 COLS=100 wrap="hard">'
      . $raw . '</textarea>  
      ' if $raw;
    $html .= '
      <a target="control" href="SUB;referer?usb_uirt_update_html()">Refresh</a><br>
      </td></tr></table>
      </form>
      ';
    return $html . $ofa_html;
}

$usb_uirt_device_list   = new Generic_Item;
$usb_uirt_device_add    = new Generic_Item;
$usb_uirt_device_text   = new Generic_Item;
$usb_uirt_device_load   = new Generic_Item;
$usb_uirt_device_delete = new Generic_Item;
$usb_uirt_device_rename = new Generic_Item;

if ( state_now $usb_uirt_device_add) {
    my $device = uc state $usb_uirt_device_text;
    return unless $device;
    print_log "Adding device $device";
    USB_UIRT::add_device($device);
    $current_device   = $device;
    $current_function = '';
}

if ( state_now $usb_uirt_device_load) {
    my $dev = state $usb_uirt_device_list;
    $current_device = $devices[$dev] if $dev =~ /\d+/;
    $current_function = '';
}

if ( state_now $usb_uirt_device_delete) {
    my $dev = state $usb_uirt_device_list;
    USB_UIRT::delete_device( $devices[$dev] ) if $dev =~ /\d+/;
    $current_device   = '';
    $current_function = '';
}

if ( state_now $usb_uirt_device_rename) {
    my $dev    = state $usb_uirt_device_list;
    my $device = uc state $usb_uirt_device_text;
    USB_UIRT::rename_device( $devices[$dev], $device )
      if $dev =~ /\d+/ and $device;
    $current_device   = $device;
    $current_function = '';
}

$usb_uirt_function_list   = new Generic_Item;
$usb_uirt_function_learn  = new Generic_Item;
$usb_uirt_function_new    = new Generic_Item;
$usb_uirt_function_text   = new Generic_Item;
$usb_uirt_function_load   = new Generic_Item;
$usb_uirt_function_delete = new Generic_Item;
$usb_uirt_function_rename = new Generic_Item;
$usb_uirt_function_send   = new Generic_Item;

#$usb_uirt_function_code = new Generic_Item;
$usb_uirt_function_import    = new Generic_Item;
$usb_uirt_function_frequency = new Generic_Item;
$usb_uirt_function_repeat    = new Generic_Item;
$usb_uirt_function_modify    = new Generic_Item;
$usb_uirt_function_raw       = new Generic_Item;

if ( state_now $usb_uirt_function_learn) {
    my $dev = state $usb_uirt_device_list;
    my $device;
    $device = $devices[$dev] if $dev =~ /\d+/;
    $device = state $usb_uirt_device_text if state $usb_uirt_device_text;
    $current_device = $device if $device;
    my $func = state $usb_uirt_function_list;
    my $function;
    $function = $functions[$func] if $func =~ /\d+/;
    $function = uc state $usb_uirt_function_text
      if state $usb_uirt_function_text;
    $current_function = $function if $function;
    my $frequency = state $usb_uirt_function_frequency;
    my $repeat    = 1;
    print_log "Learning device $device function $function";
    USB_UIRT::learn_code( $device, $function, $frequency, $repeat );
}

if ( state_now $usb_uirt_function_delete) {
    my $device = $current_device;
    my $func   = state $usb_uirt_function_list;
    my $function;
    $function = $functions[$func] if $func =~ /\d+/;
    print_log "Deleting device $device function $function";
    USB_UIRT::delete_function( $device, $function );
    $current_function = '';
}

if ( state_now $usb_uirt_function_load) {
    my $func = state $usb_uirt_function_list;
    $current_function = $functions[$func] if $func =~ /\d+/;
}

if ( state_now $usb_uirt_function_send) {
    my $device = $current_device;
    my $func   = state $usb_uirt_function_list;
    my $function;
    $function         = $functions[$func] if $func =~ /\d+/;
    $current_function = $function         if $function;
    my ( $frequency, $repeat, $code1, $code2 ) =
      USB_UIRT::get_ir_code( $current_device, $current_function );
    print_log
      "Sending device $device function $function frequency $frequency repeat $repeat code1 $code1 code2 $code2";
    USB_UIRT::set( $device, $function );
}

if ( state_now $usb_uirt_function_rename) {
    my $device = $current_device;
    my $func   = state $usb_uirt_function_list;
    my $function;
    $function = $functions[$func] if $func =~ /\d+/;
    my $funcnew;
    $funcnew = uc state $usb_uirt_function_text
      if state $usb_uirt_function_text;
    $current_function = $funcnew if $funcnew;
    print_log "Renaming device $device function $function to $funcnew";
    USB_UIRT::rename_function( $device, $function, $funcnew );
}

if ( state_now $usb_uirt_function_import) {
    my $device   = $current_device;
    my $function = $current_function;
    my $repeat   = state $usb_uirt_function_repeat;
    $repeat = 3  unless $repeat =~ /^\d+$/ and $repeat > 0;
    $repeat = 50 unless $repeat =~ /^\d+$/ and $repeat < 50;
    my $frequency = state $usb_uirt_function_frequency;
    my ( $code1, $code2 );
    $code1 = $usb_uirt_function_code;

    if ( $code1 =~ /^0000 / ) {
        $code1 =~ s/\s+/ /gs;
        $frequency = '';
    }
    else {
        $code1 =~ s/[\r\n]+//gs;
        ( $code1, $code2 ) = split ' ', $code1;
    }
    print_log
      "Importing device $device function $function code $usb_uirt_function_code";
    USB_UIRT::set_ir_code( $device, $function, $frequency, $repeat, $code1,
        $code2 );
}

if ( state_now $usb_uirt_function_new) {
    my $device = $current_device;
    my $funcnew;
    $funcnew = uc state $usb_uirt_function_text
      if state $usb_uirt_function_text;
    $current_function = $funcnew if $funcnew;
    my $frequency = state $usb_uirt_function_frequency;
    my $repeat    = state $usb_uirt_function_repeat;
    $repeat = 3  unless $repeat =~ /^\d+$/ and $repeat > 0;
    $repeat = 50 unless $repeat =~ /^\d+$/ and $repeat < 50;
    my ( $code1, $code2 );
    $code1 = $usb_uirt_function_code;

    if ( $code1 =~ /^0000 / ) {
        $code1 =~ s/\s+/ /gs;
        $frequency = '';
    }
    else {
        $code1 =~ s/[\r\n]+//gs;
        ( $code1, $code2 ) = split ' ', $code1;
    }
    print_log "Creating device $device function $funcnew";
    USB_UIRT::set_ir_code( $device, $funcnew, $frequency, $repeat, $code1,
        $code2 );
}

if ( state_now $usb_uirt_function_modify) {
    my $device   = $current_device;
    my $function = $current_function;
    my ( $frequency, $repeat, $code1, $code2 ) =
      USB_UIRT::get_ir_code( $current_device, $current_function );
    $frequency = state $usb_uirt_function_frequency;
    $repeat    = state $usb_uirt_function_repeat;
    $repeat    = 3 unless $repeat =~ /^\d+$/ and $repeat > 0;
    $repeat    = 50 unless $repeat =~ /^\d+$/ and $repeat < 50;
    print_log "Modifying device $device function $function";
    USB_UIRT::set_ir_code( $device, $function, $frequency, $repeat, $code1,
        $code2 );
}

$usb_uirt_gen_protocol = new Generic_Item;
$usb_uirt_gen_device   = new Generic_Item;
$usb_uirt_gen_function = new Generic_Item;
$usb_uirt_gen_commit   = new Generic_Item;

if ( state_now $usb_uirt_gen_commit) {
    my $device = $current_device;
    my $func   = state $usb_uirt_function_list;
    my $function;
    $function = $functions[$func] if $func =~ /\d+/;
    $function = uc state $usb_uirt_function_text
      if state $usb_uirt_function_text;
    $current_function = $function if $function;
    my $gen_protocol = state $usb_uirt_gen_protocol;
    my $gen_device   = state $usb_uirt_gen_device;
    my $gen_function = state $usb_uirt_gen_function;
    print_log "Generating device $device function $function";
    my ( $pronto, $repeat ) =
      &IR_Utils::generate_pronto( $gen_protocol, $gen_device, $gen_function );
    USB_UIRT::set_ir_code( $device, $function, '', $repeat, $pronto );
}

$usb_uirt_dvc_file = new Generic_Item;
$usb_uirt_dvc_file->set_casesensitive;
$usb_uirt_dvc_commit = new Generic_Item;

if ( state_now $usb_uirt_dvc_commit) {
    my $dvc_file = state $usb_uirt_dvc_file;
    my ( $device, $repeat, %prontos ) = &IR_Utils::read_dvc_file($dvc_file);
    print_log "Generating device $device from DVC file $dvc_file";
    foreach my $function ( keys %prontos ) {
        USB_UIRT::set_ir_code( $device, $function, '', $repeat,
            $prontos{$function} );
    }
}

sub ofa_html {
    my $sub_prev;
    my $mfgs_prev;
    my $list = '<h2>Pick a Device to Autogenerate</h2>
If you have a device from one of the established manufacturers below, try each of the "Test" buttons 
next to your device type.  If one of these turns your device on, click the number proceeding it to 
autogenerate all the codes for that device.   
You do not need to create a device or function above.<p>';
    foreach (&IR_Utils::ofa_bysub) {
        my ( $sub, $type, $mfgs, $code ) = split "$;";
        $list .= "<p>\n$sub ($type)" if "$sub$;$type" ne $sub_prev;
        $list .= "<br>\n\t&nbsp&nbsp&nbsp&nbsp$mfgs " if $mfgs ne $mfgs_prev;
        $list .= ", " if $mfgs eq $mfgs_prev;
        $list .=
            "<a target='control' href=" . '"'
          . "SUB;referer?usb_uirt_add_ofa_device('$mfgs $sub','$type','$code')"
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

sub usb_uirt_add_ofa_device {
    my $device_name = shift;
    my $type        = shift;
    my $code        = shift;
    print_log "Adding device $device_name $type $code";
    my ( $repeat, %prontos ) = &IR_Utils::generate_ofa_device( $type, $code );
    while ( my ( $key, $pronto ) = each %prontos ) {
        USB_UIRT::set_ir_code( $device_name, $key, '', $repeat, $pronto );
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
    USB_UIRT::transmit_pronto( $pronto, $repeat );
}

sub dump_codes {
    $current_device = $devices[ state $usb_uirt_device_list] if @devices;
    print "Manufacturer=\nModel=$current_device\n\n[Key Codes]\n\n";
    my @functions = USB_UIRT::list_functions($current_device)
      if $current_device ne '';
    foreach ( sort @functions ) {
        print "$_ = " . USB_UIRT::get_ir_string( $current_device, $_ ) . "\n\n";
    }
}
