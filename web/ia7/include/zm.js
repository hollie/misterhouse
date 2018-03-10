var zm = { 
    //creates a new modal dialog to display zoneminder events 
	init: function(){
	    if ($("#zm").length !== 0) {
            return;
        }

		var html = '';
		html += '<div class="modal fade" id="zm" tabindex="-1" role="dialog" aria-labelledby="myModalLabel" aria-hidden="true">';
		html += '  <div class="modal-dialog dev-dialog">';
		html += '    <div class="modal-content">';
		html += '      <div class="modal-header">';
		html += '        <h3 class="modal-title" id="myModalLabel">';
		html +=	'			<span class="object-title">Zoneminder</span>';
		html += '	        <div class="btn-group btn-group-sm pull-right">';
		html += '	        	<button type="button" class="btn btn-default" data-dismiss="modal">';
		html += '					<i class="fa fa-times"></i>';
		html += '	       		</button>';
		html += '	        </div>';
		html += '        </h3>';
		html += '      </div>';
		html += '      <div class="modal-body"></div>';
		html += '    </div>';
		html += '  </div>';
		html += '</div>';
		$('body').append(html);
		console.log("zm js loaded...");
	},

    // connects to the server and subscribes to the zonminder events.
	connect_server: function(config) {
		var myWebSocket;
		var conf = config;
		var timeout = (config.timeout === undefined ? 5500 : config.timeout);
		var zm_url = (conf.protocol === undefined ? 'wss': conf.protocol);
		var notify = (conf.browsernotifications  === undefined ? false: conf.browsernotifications);

		if (notify){
			if (!("Notification" in window)) 
			{
				warn("browser notifications are not supported");
				notify = false;
			}
			else{
				Notification.requestPermission().then(function(result) {
					log(result);
				});
			}
		}

		zm_url  += "://";
		zm_url  += (conf.host === undefined ? 'localhost': conf.host);
		zm_url  += ':';
		zm_url  += (conf.port === undefined ? 9000: conf.port);
		var timers = {};
		function log(msg, isError){
			if (conf !== undefined && conf.debug === undefined){
				return;
			}
			console.log("ZM '"+conf.host+"': " + msg);
		}
		function warn (msg){
			console.warn("ZM '" + conf.host+"' WARN: " + msg);
		}

		var connect = function () {
			var auth = JSON.stringify({ "event": "auth", "data":{ "user": conf.user, "password": conf.password } }, null, 2);

			if (myWebSocket !== undefined) {
				myWebSocket.close();
			}

			log("connecting...");

			myWebSocket = new WebSocket(zm_url);

			myWebSocket.onmessage = function(e) {
				var msg = JSON.parse(e.data);
				log("new messag = " + JSON.stringify(msg, null, 2));
				if (msg.event !== "alarm"){
					return;
				}
				var monitor_event = msg.events[0];
				var id = 'zm-'+conf.host + '-'+monitor_event.Name;
				id = id.replace(/\./g,'-');
				if (document.hidden && notify && Notification.permission === "granted") {
					var n = new Notification("Alarm: " + monitor_event.Name);
					setTimeout(n.close.bind(n), timeout); 
				}

				if ($("#div-"+ id).length === 0)
				{
					var url = '';
					var cgipath = '/zm';
					if (conf.cgipath !== undefined) cgipath = conf.cgipath;
					url += 'http://' +conf.host+cgipath+'/cgi-bin/nph-zms?mode=jpeg';
					url += '&scale='+ (conf.scale === undefined ? '100': conf.scale);
					url += '&maxfps=5&buffer=1000';
					url += '&monitor='+ monitor_event.MonitorId+'&rand=1507918186';

					var html =''; 
					html += '<div id="div-'+id+'" >'  ;
					html +=   '<center>';
					html +=      '<h4>'+ monitor_event.Name + '</h4>';
					html +=      '<img border=1 id="img-'+id + '"';
					html +=           'src="' + url +'" ';
					html +=      'width="90%" />';
					html +=   '</center>';
					html += '</div>';
					log("created new div: " + html);
					$('#zm').find('.modal-body').append(html);
				}
				$('#zm').modal({ show: true });
				restart_timer(id);
			};

			myWebSocket.onopen = function(e) {
				log("sending auth");
				myWebSocket.send(auth);
			};

			myWebSocket.onclose = function(e) {
				log("Connection closed: " + JSON.stringify(e));
				setTimeout(connect, 2000);
			};

			myWebSocket.onerror = function(e) {
				warn(JSON.stringify(e));
			};

			function restart_timer(id){
				stop_timer(id);
				timers[id] = setTimeout(function() {
					$("#div-"+ id).remove() ;
					var cnt =  $('#zm').find('.modal-body').children().length;
					if (cnt === 0)
					{
						log ("no more cameras, hiding modal dialog");
						$('#zm').modal('hide');
					}
					else
					{
						log ('still '+ cnt +' cameras.');
					}
					stop_timer(id);
				} , timeout );
				log('timer for ' + id + ' started (' + timeout +'ms)'); 
			}
			function stop_timer(id)
			{
				if (timers[id] !== undefined)
				{
					clearTimeout(timers[id]);
					delete timers[id];
					log('timeout for ' + id + ' cleared'); 
				}
			}
		};
		connect();
	},
};
