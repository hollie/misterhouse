# Authority: anyone
#
# $Revision$
# $Date$
#
# http_utils.pl
#
# This is where non HTTP server related stuff should be placed when you
# want to add functionality to the misterhouse web experience
#
#

# Start of Virtual Keyboard section
#
# Virtual Keyboard
# Originally by Matthew Williams
# Contributions:
# -  Gaeton Lord (original idea)
# -  David Mark (substantial increase in functionality & browser compatibility)
#
#
# To include a keyboard, you need to run insert_keyboard(%options).
#
# To include default style info, run insert_keyboard_style.
#
# The currently valid options are:
#   form: name of the form containing the textbox (required)
#   target: name of the textbox you want to type in (required)
#   autocap: if defined, then the first letter of each word will be capitalized
#   numerickeypad: includes numeric keypad if defined
#   hidebutton: includes hide button (requires implementing a hideKeyboard method in client script)
#
# For example, to insert a keyboard that manipulates the textbox with the
# id of 'mytextbox' in the form named 'myform' and that autocapitalizes
# the first letter of each word:
#   &insert_keyboard({target=>'mytextbox',autocap=>'yes',form=>'myform'});
#
# div.keyboard table.keyboard_container {border:outset 2px}
# div.keyboard table {border:inset 2px}
# div.keyboard td {text-align:center}
# div.keyboard input.spacebar {width:50%;font-size:smaller}
# div.keyboard td input {font-size:smaller}
# div.keyboard td input.small {padding-left:4px;padding-right:4px;width:2em}

sub insert_keyboard_style {
    return qq[
<style type="text/css">
div.keyboard td {
	text-align: center;
}

div.keyboard input {
	width: 2em;
}

div.keyboard input.special {
	width: auto;
	font-style: italic;
	font-size: 0.75em;
}

div.keyboard input.spacebar {
	width:20em;
}
</style>
];
}

sub insert_keyboard {
    my ($options) = @_;    # pass a hash reference of options

    if ( ref($options) ne 'HASH' ) {
        return 'virtual_keyboard: You must pass a hash reference.';
    }

    my $form           = $$options{form};
    my $target         = $$options{target};
    my $autocap        = $$options{autocap};
    my $hide_button    = $$options{hide_button};
    my $numeric_keypad = $$options{numeric_keypad};

    if ( !$form ) {
        return 'virtual_keyboard: You must specify a form.';
    }

    if ( !$target ) {
        return 'virtual_keyboard: You must specify a target.';
    }

    #	my @rows=qw/`1234567890-= qwertyuiop[]\ asdfghjkl;' zxcvbnm,.\//;  # This gives warnings with use diagnostics
    my @rows =
      ( "`1234567890-=", "qwertyuiop[]\\", "asdfghjkl;'", "zxcvbnm,.\/" );

    my $result = qq[<div class="keyboard">
<br/>
<form name="keyboard" action="">
<table class="container">
<tr><td>
<table class="main">];

    my $row = 0;
    for (@rows) {
        $result .= '<tr><td>';
        my @chars = split( //, $_ );
        my $column = 0;
        for (@chars) {
            my $value = $_;

            $value = '&quot;' if $value eq '"';
            $value = '&amp;'  if $value eq '&';

            if ( $row == 1 && $column == 0 ) {
                $result .=
                  qq[<input class="special" type="button" onclick="keyboard_next_control()" value="Tab">];
            }

            if ( $row == 2 && $column == 0 ) {
                $result .=
                  qq[<input class="special" type="button" value="Caps" onclick="keyboard_caps_pressed(this)">];
            }

            if ( $row == 3 && $column == 0 ) {
                $result .=
                  qq[<input class="special" type="button" value="Shift" onclick="keyboard_shift_pressed(this)">];
            }

            $result .=
              qq[<input type="button" onclick="keyboard_insert_char(this.value)" class="small" value="$value">];
            $column++;
        }

        if ( $row == 0 ) {
            $result .=
              qq[<input class="special" type="button" onclick="keyboard_delete_char()" value="Backspace">];
        }

        if ( $row == 2 ) {
            $result .=
              qq[<input class="special" type="button" onclick="keyboard_form.submit()" value="Enter">];
        }

        if ( $row == 3 ) {
            $result .=
              qq[<input class="special" type="button" value="Shift" onclick="keyboard_shift_pressed(this)">];
        }
        $row++;
        $result .= "</td></tr>";
    }

    $result .= qq[<tr>
<td><input class="special" type="button" onclick="keyboard_delete_all()" value="Clear">
<input class="spacebar special" type="button" onclick="keyboard_insert_char(' ')" value="Space">];

    if ($hide_button) {
        $result .=
          qq[<input name="hide" value="Hide" type="button" onclick="hideKeyboard()">];
    }

    $result .= '</td></tr></table></td>';

    if ($numeric_keypad) {

        @rows = qw/123 456 789 0/;

        $result .= '<td><table class="numeric">';

        $row = 0;
        for (@rows) {
            my $column = 0;
            $result .= '<tr><td>';
            my @chars = split( //, $_ );
            for (@chars) {
                my $value = $_;
                $result .=
                  qq[<input type="button" onclick="keyboard_insert_char(this.value)" class="small" value="$value">];
                $column++;
            }
            if ( $row == 3 ) {
                $result .=
                  qq[<input class="keyboard" type="button" onclick="keyboard_delete_all()" value="Clear">];
            }

            $result .= '</td></tr>';
            $row++;
        }
        $result .= '</table></td>';
    }

    $result .= qq[</tr></table></form>
<script language="javascript" type="text/javascript">
<!--

var keyboard_form=document.$form;
var keyboard_textbox=keyboard_form.$target;
var keyboard_shift_currently_pressed=false;
var keyboard_caps_currently_pressed=false;

var shiftedNumbers = ')!@#\$%^&*(';
var shiftedSymbols = '_+{}|:"<>?';
var unshiftedSymbols = "-=[]\\\\;',./";

// Call this before showing to use one keyboard for multiple inputs
// Pass form object and input object from client script (these will be used in lieu of server-supplied named args)

function keyboard_set_target(f,t) {
	keyboard_textbox = t;
	keyboard_form = f;
}

function keyboard_next_control() {
	var e = keyboard_form.elements;
	var i=0;

	for (i=0; i < e.length && e[i].name &&
		e[i].name != keyboard_textbox.name; i++) {
	}

	// we couldn't find current textbox, so do nothing
	if (i == e.length) {
		return;
	}

	var j=i;
	do {
		if (!keyboard_shift_currently_pressed) {
			j++;
			if (j >= e.length) {
				j=0;
			}
		} else {
			j--;
			if (j < 0) {
				j=e.length-1;
			}
		}
		if (e[j].type=="text") {
			break;
		}
	}
	while (i != j);
	if (i != j) {
		keyboard_textbox=e[j];
		e[j].focus();
	}
	if (keyboard_shift_currently_pressed) {
		keyboard_shift_currently_pressed=false;
		keyboard_update_buttons();
	}
}

function keyboard_insert_char(letter) {
	if (keyboard_shift_currently_pressed) {
		keyboard_shift_currently_pressed = false;
		keyboard_update_buttons();
	}
];
    if ($autocap) {
        $result .= qq[
	if (keyboard_textbox.value.length == 0) {
		letter=letter.toUpperCase();
	} else {
		if (keyboard_textbox.value.substring(keyboard_textbox.value.length-1,keyboard_textbox.value.length) == ' ') {
			letter=letter.toUpperCase();
		}
	}
		];
    }
    $result .= qq[
	keyboard_textbox.value=keyboard_textbox.value + letter;
}

function keyboard_delete_char() {
	if (keyboard_textbox.value.length > 0) {
		keyboard_textbox.value=keyboard_textbox.value.substring(0,keyboard_textbox.value.length-1);
	}
}

function keyboard_delete_all() {
	keyboard_textbox.value='';
}

function keyboard_caps_pressed(e) {
	keyboard_caps_currently_pressed=!keyboard_caps_currently_pressed;
	keyboard_update_buttons();
}

function keyboard_shift_pressed(e) {
	keyboard_shift_currently_pressed=!keyboard_shift_currently_pressed;
	keyboard_update_buttons();
}

function keyboard_update_buttons() {
	var buttons = document.forms["keyboard"].elements;
	if (buttons) {
		if (keyboard_shift_currently_pressed || keyboard_caps_currently_pressed) {
			for (var i = 0; i < buttons.length; i++) {
				if (buttons[i].value.length == 1 && buttons[i].value >= 'a' && buttons[i].value <= 'z') {
					buttons[i].value = buttons[i].value.toUpperCase();
				}
			}
		} else {
			for (var i = 0; i < buttons.length; i++) {
				if (buttons[i].value.length == 1 && buttons[i].value >= 'A' && buttons[i].value <= 'Z') {
					buttons[i].value = buttons[i].value.toLowerCase();
				}
			}
		}

		if (keyboard_shift_currently_pressed) {
			for (var i = 0; i < buttons.length; i++) {
				if (buttons[i].value >= '0' && buttons[i].value <= '9') {
					buttons[i].value = shiftedNumbers.substring(buttons[i].value.charCodeAt(0) - 48, buttons[i].value.charCodeAt(0) - 47);
				} else {
					if (unshiftedSymbols.lastIndexOf(buttons[i].value) != -1) {
						buttons[i].value = shiftedSymbols.substring(unshiftedSymbols.lastIndexOf(buttons[i].value), unshiftedSymbols.lastIndexOf(buttons[i].value) + 1);
					}
				}
			}
		} else {
			for (var i = 0; i < buttons.length; i++) {
				if (shiftedNumbers.lastIndexOf(buttons[i].value) != -1) {
					buttons[i].value = shiftedNumbers.lastIndexOf(buttons[i].value);
				} else {
					if (shiftedSymbols.lastIndexOf(buttons[i].value) != -1) {
						buttons[i].value = unshiftedSymbols.substring(shiftedSymbols.lastIndexOf(buttons[i].value), shiftedSymbols.lastIndexOf(buttons[i].value) + 1);
					}
				}
			}
		}
	}
}

//-->
</script>
</div>
];
    return $result;
}

# end of Virtual Keyboard section

# don't delete the next line!  Required files need to return 1
1;
