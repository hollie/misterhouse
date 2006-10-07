<?

/* 

From Douglas Parrish on 07/2002:

> Is there a way to get the state of various objects without having all this
> extra stuff returned?  I want to talk to mh from php a little more
> directly, without all the formatting and fluff.  i'm going to put my own
> formatting in.

Here's what I used.  It's not real pretty, but I found that it's much easier 
to parse the XML output from MH.

*/


$item_states = array();

function get_state_graphic($item_name)
{
	global $item_states;

	echo $item_states[$item_name]['graphic'];
}

function get_state_text($item_name)
{
	global $item_states;

	return $item_states[$item_name]['text'];
}

function get_state_raw($item_name)
{
	global $item_states;

	return $item_states[$item_name]['val'];
}

function get_object_information()
{
	global $item_states;
	
	$vals = file('http://mh:8080/sub?xml(objects)');

	foreach ($vals as $v) {
		if (strstr($v, '<object>')) {
			preg_match_all("/<\w*>.[\w\.\%]*<\/\w*>/", $v, $macro);

			$name = strip_tags($macro[0][0]);
			$name = substr($name, 1, strlen($name)-1);

			$state = strtolower(strip_tags($macro[0][3]));

			if ($state == 'on' OR $state == 'off') {
				$item_states[$name]['graphic'] = "/graphics/$state.gif";
			} else {
				$item_states[$name]['graphic'] = "/graphics/dim.gif";
			}

			if ($state != 'on' && $state != 'off') {
				$item_states[$name]['text'] = 'dim';
				$item_states[$name]['val'] = $state;
			} else {
				$item_states[$name]['text'] = $state;
			}
		}
	}
}

get_object_information();

?>
