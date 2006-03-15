# Virtual Keyboard
# Matthew Williams
#
# $Revision$
# $Date$
#
#@ This code should be activated if you want a 
#@ virtual keyboard included within certain web pages
#@
#@ To include a keyboard, you need to run insert_keyboard(%options).
#
# The currently valid options are:
#   target: id of the textbox you want to type in.
#   autocap: if defined, then the first letter of each word will be capitalized
#
# For example, to insert a keyboard that manipulates the textbox with the
# id of 'mytextbox' and that autocapitalizes the first letter of each word:
#   &insert_keyboard({target=>'mytextbox',autocap=>'yes'});
# 
# Based on an idea suggested by Gaetan Lord
#

sub insert_keyboard {
	my ($options)=@_;	# pass a hash reference of options

	if (ref($options) ne 'HASH') {
		return 'VKB Usage Error!!  You must pass a hash reference.';
	}

	my $target=$$options{target};
	my $autocap=$$options{autocap};

	if ($target eq '') {
		return 'VKB Usage Error!!  You must specify a target.';
	}

	my @rows=qw/ ~!@#$%^&*()_+ `1234567890-= qwertyuiop[]\{}| asdfghjkl;':" zxcvbnm,.\/<>?/;

	my $result=qq[<div id="virtual_keyboard_$target">\n];

	$result.=qq[<hr /><table>\n];

	for (@rows) {
		$result .= "<tr>\n";
		my @chars=split(//,$_);
		for (@chars) {
			my $value=$_;
			my $jchar=$_;
			$jchar="\\'" if $jchar eq "'";
			$value='&quot;' if $value eq '"';
			$jchar='&quot;' if $jchar eq '"';
			$result .= qq[<td><input type="button" onclick="insert_char_$target('$jchar')" value="$value"></td>\n];
		}
		$result .= "</tr>\n";
	}
	$result.=qq[<tr>
<td colspan="2"><input type="button" onclick="shift_pressed_$target(' ')" value="Shift" id="shift_key_$target"></td>
<td colspan="2"><input type="button" onclick="insert_char_$target(' ')" value="Space"></td>
<td colspan="3"><input type="button" onclick="delete_char_$target()" value="Backspace"></td>
<td colspan="3"><input type="button" onclick="delete_all_$target()" value="Clear"></td></tr>
];
	$result.=qq[</table><hr />
<script language="javascript" type="text/javascript">
<!--

var textbox_$target=document.getElementById('$target');
var shift_currently_pressed_$target=false;
var shift_key_$target=document.getElementById('shift_key_$target');

function insert_char_$target(letter) {
	if (shift_currently_pressed_$target) {
		letter=letter.toUpperCase();
		shift_currently_pressed_$target=false;
		shift_key_$target.value='Shift';
	}
];
	if ($autocap ne '') {
		$result.=qq[
	if (textbox_$target.value.length == 0) {
		letter=letter.toUpperCase();
	} else {
		if (textbox_$target.value.substring(textbox_$target.value.length-1,textbox_$target.value.length) == ' ') {
			letter=letter.toUpperCase();
		}
	}
		];
	}
	$result.=qq[
	textbox_$target.value=textbox_$target.value+letter;
}

function delete_char_$target() {
	if (textbox_$target.value.length > 0) {
		textbox_$target.value=textbox_$target.value.substring(0,textbox_$target.value.length-1);
	}
}

function delete_all_$target() {
	textbox_$target.value='';
}

function shift_pressed_$target() {
	shift_currently_pressed_$target=!shift_currently_pressed_$target;
	if (shift_currently_pressed_$target == true) {
		shift_key_$target.value='SHIFT';
	} else {
		shift_key_$target.value='Shift';
	}
}

//-->
</script>
</div>
];
	return $result;
}

