//
// Playlist Functions ( include script)
// Pete Flaherty 2004.07.15.001
//
var isAudrey = navigator.userAgent.indexOf("Audrey") !=-1;
//
if ( isAudrey == false) { setTimeout('UpdateYou()', 2000); }
if ( isAudrey == true) { setTimeout('UpdateMe()', 20000); }
//
function remove(pos){
// document.write('delete location $serv/SUB:mp3_playlist_delete(%22' + pos + '%22)' + pos );
    window.open('/SUB:mp3_playlist_delete(%22' + pos + '%22)','invisi');
    setTimeout('UpdateMe()', 1000);
}

function skipTo(pos){
    parent.window.open('/SUB:mp3_set_playlist_pos(%22' + pos + '%22)','invisi');
    setTimeout('UpdateMe()', 2000);
}

function UpdateMe() {
    // window.open('/misc/mpnow.html','mp3play','',false);
    // location = 'mp3play';
    // parent.location.reload() ;
    window.location.reload(); 
}

function UpdateYou() {
    target = '/misc/mpnowplay.html';
    targname = 'mp3play';
    window.open(target,targname);
    // location = 'mp3play';
    // parent.location.reload() ;
    // window.location.reload(); 
}
