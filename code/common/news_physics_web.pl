#Category=News

#@ This module adds functionality to obtain news from physicsweb.org,
#@ then read or display it.

#  Physics Web News Stories Archive
my $f_physics_web      = "$config_parms{data_dir}/web/physics_web.txt";
my $f_physics_web_html = "$config_parms{data_dir}/web/physics_web.html";

$p_physics_web = new Process_Item(
    "get_url http://physicsweb.org/archive/news $f_physics_web_html");
$v_physics_web = new Voice_Cmd('[Get,Read] physics web');
$v_physics_web->set_authority('anyone');

$v_physics_web->respond($f_physics_web) if said $v_physics_web eq 'Read';

if ( said $v_physics_web eq 'Get' ) {
    if (&net_connect_check) {
        $v_physics_web->respond(
            "Retrieving Physics Web News Stories from the Internet...");

        # Use start instead of run so we can detect when it is done
        start $p_physics_web;
    }
    else {
        $v_physics_web->respond("Connect to the Internet first!");
    }
}

if ( done_now $p_physics_web) {
    my $html = file_read $f_physics_web_html;
    my ( $text, $count );

    # *** This is broken!

    $text = "Physics Web News items: \n";
    for ( file_read "$f_physics_web_html" ) {

        #	if (m!<a href=.+of News';return true;">(<font color=blue>)??(\w)+</!){
        #		$text .= "$1\n";
        #		$text =~ s!</?\w>!!g;
        #	}

        #	if ((m!(\[\d.+)<\w>!)and $count <3){
        if ( (m!(\[\d.+)!) and $count < 3 ) {
            $text .= "$1\n";
            $text =~ s!</?\w>!!g;
            $count++;
        }

    }
    $text =~ s![/[|\]]!!g;
    $text =~ s!\(.+\)!!g;
    file_write( $f_physics_web, $text );
    $v_physics_web->respond("connected=0 Physics web news retrieved.");
}

