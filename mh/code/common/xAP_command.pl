
# Category = xAP

#@ xAP command server for MH.  Will run requested commands and send respond results back.

# TODO: probably need to assign a unique id to request so the correct 
# response can always be found amongst many concurrent responses (scalability)
# Bruce: Feel free to change the command structure to suit your ideas. 
#        Just let me know when you do so I can update my client

use xAP_Items;
&xAP::startup if $Reload;

$xap_command_external = new xAP_Item('command.external');
if ($state = $xap_command_external->state_now()) {
	my $response;	
	print "s=$state, command=$$xap_command_external{'command.external'}{command}, xap=$xap_command_external\n";
	$response =&process_external_command(
		$$xap_command_external{'command.external'}{command},
		1,
		$xap_command_external,
		'xap');
				# Special error response.  Normal response handled by respond_xap
	if ($response ne 1) {
	        &xAP::send('xAP', 
			"command.response", 
			'command.response' => {response => '', error => 1});
	}
}

# This gets invoked by Respond, when target=xap
sub respond_xap
{
	my (%parms) = @_;
        &xAP::send('xAP', 
		"command.response", 
		'command.response' => {response => $parms{text}, error => 0});
}

$xap_command_voice = new xAP_Item('command.voice');
$xap_command_speak = new xAP_Item('command.speak');

