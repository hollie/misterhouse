
# Category = Entertainment

=begin comment

#@ This code uses The Eliza Chatbot module to reply to a message.
#@ Eliza is not a very sophisticated chatbot, but it allows for
#@ a simple conversation.  The rules are in mh/data/eliza/*.txt.

#@ Text can be entered via the Tk interface or via a web page.
#@ An example page is in <a href="/speak">mh/web/speak/speak.shtml</a>.

=cut

$eliza_rule    = new Generic_Item;
$eliza_data    = new Generic_Item;
$eliza_voice   = new Generic_Item;
$eliza_card    = new Generic_Item;
$eliza_wavcomp = new Generic_Item;

$eliza_data->set_authority('anyone');
$eliza_rule->set_authority('anyone');
$eliza_voice->set_authority('anyone');
$eliza_card->set_authority('anyone');
$eliza_wavcomp->set_authority('anyone');

#&tk_entry('Eliza Message', $eliza_data, 'Eliza Rule', $eliza_rule);
&tk_entry( 'Eliza Message', $eliza_data );
&tk_entry( 'Eliza Rule',    $eliza_rule );

use Eliza;
my ($eliza);
undef $eliza if $eliza and state_changed $eliza_rule;

$f_eliza_deep_thoughts =
  new File_Item("$config_parms{data_dir}/remarks/deep_thoughts.txt");

if ( defined( $state = state_now $eliza_data) ) {
    my $msg = $state;

    # Used cached data from a previous background DSN search, if from the web
    #   my ($name, $name_short) = net_domain_name_start 'eliza_server', 'http' if get_set_by $eliza_data =~ /^web/;
    my $name = $Http{Client_address};

    #   $name = 'unknown' unless $name;

    my $rule    = state $eliza_rule;
    my $voice   = state $eliza_voice;
    my $card    = state $eliza_card;
    my $wavcomp = state $eliza_wavcomp;
    if ( $rule eq 'none' or !$rule ) {

        #	$msg = "$name_short says: $msg";
        #       $msg = &Voice_Text::set_voice($voice, "$name_short says: $msg");
    }
    elsif ( $rule =~ 'thought' ) {
        my $response = read_current $f_eliza_deep_thoughts;
        $response = read_next $f_eliza_deep_thoughts if $rule eq 'thought2';

        #       $response = "$name_short says: $msg.  $name says: $response" if $msg;
        $response = "You said $msg.  $voice says: $response" if $msg;
        $msg = $response;

        #        $msg = &Voice_Text::set_voice($voice, $response);
    }
    else {
        $eliza = new Chatbot::Eliza "Eliza", "../data/eliza/$rule.txt"
          unless $eliza;
        my $response = $eliza->transform($msg);
        $msg = "You said: $msg.  $voice says: $response";

        #        $msg  = "$name_short said: $msg.  $name says: $response";
        #        $msg  = "$name_short said: " . &Voice_Text::set_voice($voice, $msg);
        #        $msg .= "  Eliza says: "     . &Voice_Text::set_voice($voice, $response);
    }
    print "Speaking eliza data with voice=$voice, compression=$wavcomp\n";

    #   speak card => 3, compression => $wavcomp, text => $msg;
    speak
      app         => 'chatbot',
      card        => $card,
      voice       => $voice,
      compression => $wavcomp,
      text        => $msg,
      requestor   => $name;

    #    speak app => 'chatbot',  compression => $wavcomp, text => $msg;
    logit( "$config_parms{data_dir}/logs/eliza_server.$Year.log",
        "domain=$name text=$msg" );
}

if ( my ( $name, $name_short ) = net_domain_name_done 'eliza_server' ) {
    print_log "Eliza visitor from $name_short ($name)";
}
