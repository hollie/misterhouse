// Optimization opportunity
//  add print_errorlog
//  updateStaticPage has lots of copy paste


var entity_store = {}; //global storage of entities
var json_store = {};
var updateSocket;
var display_mode;
if (display_mode == undefined) display_mode = "simple";


//Takes the current location and parses the achor element into a hash
function URLToHash() {
	if (location.hash === undefined) return;
	var URLHash = {};
	var url = location.hash.replace(/^\#/, ''); //Replace Hash Entity
	var pairs = url.split('&');
	for (var i = 0; i < pairs.length; i++) {
		var pair = pairs[i].split('=');
		URLHash[decodeURIComponent(pair[0])] = decodeURIComponent(pair[1]);
	}
	return URLHash;
}

//Takes a hash and turns it back into a url
function HashtoURL(URLHash) {
	var pairs = [];
	for (var key in URLHash){
		if (URLHash.hasOwnProperty(key)){
			pairs.push(encodeURIComponent(key) + '=' + encodeURIComponent(URLHash[key]));
		}
	}
	return location.path + "#" + pairs.join('&');
}

//Takes a hash and spits out the JSON request argument string
function HashtoJSONArgs(URLHash) {
	var pairs = [];
	var path = "";
	if (URLHash.path !== undefined) {
		path = URLHash.path;
	}
	delete URLHash.path;
	for (var key in URLHash){
		if (key.indexOf("_") === 0){
			//Do not include private arguments
			continue;
		}
		if (URLHash.hasOwnProperty(key)){
			pairs.push(encodeURIComponent(key) + '=' + encodeURIComponent(URLHash[key]));
		}
	}
	return path + "?" + pairs.join('&');
}

//Gets any arguments in the URL that aren't part of IA7
function HashPathArgs(URLHash) {
	var loc = location.href.split('?');
	if (loc[1] === undefined) {
		return;
	}
	var pairs = loc[1].split('&');
	var rpairs = [];
	for (var i = 0; i < pairs.length; i++) {
		var pair = pairs[i].split('=');
		if (pair[0].indexOf("_") === 0){
			//Do not include private arguments
			continue;
		}
		rpairs.push(pair[0]+"="+pair[1]);
	}
	return  rpairs.join('&');
}

//Stores the JSON data in the proper location based on the path requested
function JSONStore (json){
	var newJSON = {};
	for (var i = json.meta.path.length-1; i >= 0; i--){
		var path = json.meta.path[i];
		if ($.isEmptyObject(newJSON)){
			newJSON[path] = json.data;
		}
		else {
			var tempJSON = {};
			tempJSON[path] = newJSON;
			newJSON = tempJSON;
		}
	}
	newJSON.meta = json.meta;
	//Merge the new JSON data structure into our stored structure
	$.extend( true, json_store, newJSON );
}

//Get the JSON data for the defined path
function getJSONDataByPath (path){
	if (json_store === undefined){
		return undefined;
	}
	var returnJSON = json_store;
	path = path.replace(/^\/|\/$/g, "");
	var pathArr = path.split('/');
	for (var i = 0; i < pathArr.length; i++){
		if (returnJSON[pathArr[i]] !== undefined){
			returnJSON = returnJSON[pathArr[i]];
		}
		else {
			// We don't have this data
			return undefined;
		}
	}
	return returnJSON;
}


//Called anytime the page changes
function changePage (){
	var URLHash = URLToHash();
	if (URLHash.path === undefined) {
		// This must be a call to root.  To speed things up, only request
		// collections
		URLHash.path = "collections";
	}
	if (getJSONDataByPath("ia7_config") === undefined){
		// We need at minimum the basic collections data to render all pages
		// (the breadcrumb)
		// NOTE may want to think about how to handle dynamic changes to the 
		// collections list
		$.ajax({
			type: "GET",
			url: "/json/ia7_config",
			dataType: "json",
			success: function( json ) {
				JSONStore(json);
				changePage();
			}
		});
	} else {
		//console.log("x "+json_store.ia7_config.prefs.substate_percentages);
		if (json_store.ia7_config.prefs.header_button == "no") {
			$("#mhstatus").remove();
		}
		if (json_store.ia7_config.prefs.substate_percentages === undefined) json_store.ia7_config.prefs.substate_percentages = 20;
	}
	if (getJSONDataByPath("collections") === undefined){
		// We need at minimum the basic collections data to render all pages
		// (the breadcrumb)
		// NOTE may want to think about how to handle dynamic changes to the 
		// collections list
		$.ajax({
			type: "GET",
			url: "/json/collections",
			dataType: "json",
			success: function( json ) {
				JSONStore(json);
				changePage();
			}
		});
	} 
	else {
		// Clear Options Entity by Default
		$("#toolButton").attr('entity', '');
		
		//Trim leading and trailing slashes from path
		var path = URLHash.path.replace(/^\/|\/$/g, "");
		if (path.indexOf('objects') === 0){
			loadList();
		}
		else if (path.indexOf('vars') === 0){
			loadVars();
		}
		else if(URLHash._request == 'page'){
			var link = URLHash.link.replace(/\?+.*/,''); //HP for some reason, this often has the first arg with no value, ie ?bob
			var args = HashPathArgs(URLHash);
			if (args !== undefined) {
				args = args.replace(/\=undefined/img,''); //HP sometimes arguments are just items and not key=value...
				link += "?"+args;
			}
			//alert("link="+link);
			//$.get(URLHash.link, function( data ) {
			$.get(link, function( data ) {
				data = data.replace(/<link[^>]*>/img, ''); //Remove stylesheets
				data = data.replace(/<title[^>]*>((\r|\n|.)*?)<\/title[^>]*>/img, ''); //Remove title
				data = data.replace(/<meta[^>]*>/img, ''); //Remove meta refresh
				data = data.replace(/<base[^>]*>/img, ''); //Remove base target tags
				$('#list_content').html("<div id='buffer_page' class='row top-buffer'>");
				$('#buffer_page').append("<div id='row_page' class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>");
				$('#row_page').html(data);
			});
		}
		else if(path.indexOf('print_log') === 0){
			print_log();
		}
		else if(path.indexOf('print_speaklog') === 0){
			print_log("speak");
		}
		else if(path.indexOf('display_table') === 0){
			var path_arg = path.split('?');
			display_table(path_arg[1]);
		}
		else if(path.indexOf('floorplan') === 0){
			var path_arg = path.split('?');
			floorplan(path_arg[1]);
		}
		else if(URLHash._request == 'trigger'){
			trigger();
		}
		else { //default response is to load a collection
			loadCollection(URLHash._collection_key);
		}
		//update the breadcrumb: 
		// Weird end-case, The Group from browse items is broken with parents on the URL
		$('#nav').html('');
		var collection_keys_arr = URLHash._collection_key;
		if (collection_keys_arr === undefined) collection_keys_arr = '0';
		collection_keys_arr = collection_keys_arr.split(',');
		var breadcrumb = '';
		for (var i = 0; i < collection_keys_arr.length; i++){
			var nav_link, nav_name;
			if (collection_keys_arr[i].substring(0,1) == "$"){
				//We are browsing the contents of an object, currently only 
				//group objects can be browsed recursively.  Possibly use different
				//prefix if other recursively browsable formats are later added
				nav_name = collection_keys_arr[i].replace("$", '');
				nav_link = '#path=/objects&parents='+nav_name;
				if (nav_name == "Group") nav_link = '#path=objects&type=Group'; //Hardcode this use case
				if (json_store.objects[nav_name].label != undefined) nav_name = (json_store.objects[nav_name].label);

			}
			else {
				nav_link = json_store.collections[collection_keys_arr[i]].link;
				nav_name = json_store.collections[collection_keys_arr[i]].name;
			}
			nav_link = buildLink (nav_link, breadcrumb + collection_keys_arr[i]);
			breadcrumb += collection_keys_arr[i] + ",";
			if (i == (collection_keys_arr.length-1)){
				$('#nav').append('<li class="active">' + nav_name + '</a></li>');
				$('title').html("MisterHouse - " + nav_name);
			} 
			else {
				$('#nav').append('<li><a href="' + nav_link + '">' + nav_name + '</a></li>');
			}
		}
	}
}

function loadVars (){ //variables list
	var URLHash = URLToHash();
	$.ajax({
		type: "GET",
		url: "/json/"+HashtoJSONArgs(URLHash),
		dataType: "json",
		success: function( json ) {
			JSONStore(json);
			var list_output = "";
			var keys = [];
			for (var key in json.data) {
				keys.push(key);
			}
			keys.sort ();
			for (var i = 0; i < keys.length; i++){
				var value = variableList(json.data[keys[i]]);
				var name = keys[i];
				var list_html = "<ul><li><b>" + name + ":</b>" + value+"</li></ul>";
				list_output += (list_html);
			}
		
			//Print list output if exists;
			if (list_output !== ""){
				$('#list_content').html('');
				$('#list_content').append("<div id='buffer_vars' class='row top-buffer'>");
				$('#buffer_vars').append("<div id='row_vars' class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>");
				$('#row_vars').append(list_output);
			}
		}
	});
}

//Recursively parses a JSON entity to print all variables 
function variableList(value){
	var retValue = '';
	if (typeof value == 'object' && value !== null) {
		var keys = [];
		for (var key in value) {
			keys.push(key);
		}
		keys.sort ();
		for (var i = 0; i < keys.length; i++){
			retValue += "<ul><li><b>" + keys[i] +":</b>"+ variableList(value[keys[i]]) + "</li></ul>";
		}
	} else {
		retValue = "<ul><li>" + value+"</li></ul>";
	}
	return retValue;
}

//Prints a JSON generated list of MH objects
var loadList = function() {
	var URLHash = URLToHash();
	if (getJSONDataByPath("objects") === undefined){
		// We need at least some basic info on all objects
		$.ajax({
			type: "GET",
			url: "/json/objects?fields=sort_order,members,label",
			dataType: "json",
			success: function( json ) {
				JSONStore(json);
				loadList();
			}
		});
		return;
	}
	var collection_key = URLHash._collection_key;
	var button_text = '';
	var button_html = '';
	var entity_arr = [];
	URLHash.fields = "category,label,sort_order,members,state,states,state_log,hidden,type,text";
	$.ajax({
		type: "GET",
		url: "/json/"+HashtoJSONArgs(URLHash),
		dataType: "json",
		success: function( json ) {
			//Save this to the JSON store
			JSONStore(json);
			
			// Catch Empty Responses
			if ($.isEmptyObject(json.data)) {
				entity_arr.push("No objects found");
			}

			// Build sorted list of objects
			var entity_list = [];
			for(var k in json.data) entity_list.push(k);
			var sort_list;
			if (URLHash.parents !== undefined && 
				json_store.objects[URLHash.parents] !== undefined &&
				json_store.objects[URLHash.parents].sort_order !== undefined) {
				sort_list = json_store.objects[URLHash.parents].sort_order;
			}
			
			// Set Options Modal Entity
			// "Parent" entity can be different depending on the manner in which
			// the list is requested, need to figure out a heirarchy at some point
			// Currently, we only handle groups, so we only deal with parent
			if (URLHash.parents !== undefined) {
				$("#toolButton").attr('entity', URLHash.parents);
			}			
			
			// Sort that list if a sort exists, probably exists a shorter way to
			// write the sort
			if (sort_list !== undefined){
				entity_list = sortArrayByArray(entity_list, sort_list);
			}

			for (var i = 0; i < entity_list.length; i++) {
				var entity = entity_list[i];
				if (json_store.objects[entity].type === undefined){
					// This is not an entity, likely a value of the root obj
					continue;
				}
				if (json_store.objects[entity].hidden != undefined){
					// This is an entity with the hidden property, so skip it
					continue;
				}
				if (json_store.objects[entity].type == "Voice_Cmd"){
					button_text = json_store.objects[entity].text;
					//Choose the first alternative of {} group
					while (button_text.indexOf('{') >= 0){
						var regex = /([^\{]*)\{([^,]*)[^\}]*\}(.*)/;
						button_text = button_text.replace(regex, "$1$2$3");
					}
					//Put each option in [] into toggle list, use first option by default
					if (button_text.indexOf('[') >= 0){
						var regex = /(.*)\[([^\]]*)\](.*)/;
						var options = button_text.replace(regex, "$2");
						var button_text_start = button_text.replace(regex, "$1");
						var button_text_end = button_text.replace(regex, "$3");
						options = options.split(',');
						button_html = '<div class="btn-group btn-block fillsplit">';
						button_html += '<div class="leadcontainer">';
						button_html += '<button type="button" class="btn btn-default dropdown-lead btn-lg btn-list btn-voice-cmd navbutton-padding">'+button_text_start + "<u>" + options[0] + "</u>" + button_text_end+'</button>';
						button_html += '</div>';
						button_html += '<button type="button" class="btn btn-default btn-lg dropdown-toggle pull-right btn-list-dropdown navbutton-padding" data-toggle="dropdown">';
						button_html += '<span class="caret"></span>';
						button_html += '<span class="sr-only">Toggle Dropdown</span>';
						button_html += '</button>';
						button_html += '<ul class="dropdown-menu dropdown-voice-cmd" role="menu">';
						for (var j=0,len=options.length; j<len; j++) { 
							button_html += '<li><a href="#">'+options[j]+'</a></li>';
						}
						button_html += '</ul>';
						button_html += '</div>';
					}
					else {
						button_html = "<div style='vertical-align:middle'><button type='button' class='btn btn-default btn-lg btn-block btn-list btn-voice-cmd navbutton-padding'>";
						button_html += "" +button_text+"</button></div>";
					}
					entity_arr.push(button_html);
				} //Voice Command Button
				else if(json_store.objects[entity].type == "Group" ||
					    json_store.objects[entity].type == "Type" ||
					    json_store.objects[entity].type == "Category"){
					json_store.objects[entity] = json_store.objects[entity];
					var object = json_store.objects[entity];
					button_text = entity;
					if (object.label !== undefined) button_text = object.label;
					//Put entities into button
					var filter_args = "parents="+entity;
					if (json_store.objects[entity].type == "Category"){
						filter_args = "type=Voice_Cmd&category="+entity;
					}
					else if (json_store.objects[entity].type == "Type") {
						filter_args = "type="+entity;
					}
					button_html = "<div style='vertical-align:middle'><a role='button' listType='objects'";
					button_html += "class='btn btn-default btn-lg btn-block btn-list btn-division navbutton-padding'";
					button_html += "href='#path=/objects&"+filter_args+"&_collection_key="+collection_key+",$" + entity +"' >";
					button_html += "" +button_text+"</a></div>";
					entity_arr.push(button_html);
					continue;
				}
				else {
					// These are controllable MH objects
					json_store.objects[entity] = json_store.objects[entity];
					var name = entity;
					var color = getButtonColor(json_store.objects[entity].state);
					if (json_store.objects[entity].label !== undefined) name = json_store.objects[entity].label;
					//Put objects into button
					var dbl_btn = "";
					if (json_store.ia7_config.prefs.always_double_buttons == "yes") {
						if (name.length < 30) dbl_btn = "<br>"; 
					}
					button_html = "<div style='vertical-align:middle'><button entity='"+entity+"' ";
					button_html += "class='btn btn-"+color+" btn-lg btn-block btn-list btn-popover btn-state-cmd navbutton-padding'>";
					button_html += name+dbl_btn+"<span class='pull-right'>"+json_store.objects[entity].state+"</span></button></div>";
					entity_arr.push(button_html);
				}
			}//entity each loop
			
			//loop through array and print buttons
			var row = 0;
			var column = 1;
			for (var i = 0; i < entity_arr.length; i++){
				if (i === 0) {
					$('#list_content').html('');
				}
				if (column == 1){
					$('#list_content').append("<div id='buffer"+row+"' class='row top-buffer'>");
					$('#buffer'+row).append("<div id='row" + row + "' class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>");
				}
				$('#row'+row).append("<div class='col-sm-4'>" + entity_arr[i] + "</div>");
				if (column == 3){
					column = 0;
					row++;
				}
				column++;
			}
			
			//Affix functions to all button clicks
			$(".dropdown-voice-cmd > li > a").click( function (e) {
				var button_group = $(this).parents('.btn-group');
				button_group.find('.leadcontainer > .dropdown-lead >u').html($(this).text());
				e.preventDefault();
			});
			$(".btn-voice-cmd").click( function () {
				var voice_cmd = $(this).text().replace(/ /g, "_");
				var url = '/RUN;last_response?select_cmd=' + voice_cmd;
				$.get( url, function(data) {
					var start = data.toLowerCase().indexOf('<body>') + 6;
					var end = data.toLowerCase().indexOf('</body>');
					$('#lastResponse').find('.modal-body').html(data.substring(start, end));
					$('#lastResponse').modal({
						show: true
					});
				});
			});
			$(".btn-state-cmd").click( function () {
				var entity = $(this).attr("entity");
				create_state_modal(entity);
			});
		}
	});
	// Continuously check for updates if this was a group type request
	updateList(URLHash.path);

};//loadlistfunction

var getButtonColor = function (state) {
	var color = "default";
	if (state == "on" || state == "open" || state == "disarmed" || state == "unarmed" || state == "ready" || state == "dry" || state == "up" || state == "100%" || state == "online") {
		 color = "success";
	} else if (state == "motion" || state == "closed" || state == "armed" || state == "wet" || state == "fault" || state == "down" || state == "offline") {
		 color = "danger";
	} else if (state == undefined || state == "unknown" ) {
		 color = "info";
	} else if (state == "low" || state == "med" || state.indexOf('%') >= 0 || state == "light") { 
		 color = "warning";
	}
	return color;
};

var filterSubstate = function (state) {
 	// ideally the gear icon on the set page will remove the filter
    var filter = 0
    // remove 11,12,13... all the mod 10 states
    if (state.indexOf('%') >= 0) {
    
       var number = parseInt(state, 10)
       if (number % json_store.ia7_config.prefs.substate_percentages != 0) {
         filter = 1
        }
    }
    
    if (state == "manual" ||
    	state == "double on" ||
    	state == "double off" ||
    	state == "triple on" ||
    	state == "triple off" ||
    	state == "status on" ||
    	state == "status off" ||
    	state == "status on" ||
    	state == "clear" ||
    	state == "setramprate" ||
    	state == "setonlevel" ||
    	state == "addscenemembership" ||
    	state == "setsceneramprate" ||
    	state == "deletescenemembership" ||
    	state == "disablex10transmit" ||
    	state == "enablex10transmit" ||
    	state == "set ramp rate" ||
    	state == "set on level" ||
    	state == "add to scene" ||
    	state == "remove from scene" ||
    	state == "set scene ramp rate" ||
    	state == "disable transmit" ||
    	state == "enable transmit" ||
    	state == "disable programming" ||
    	state == "enable programming" ||
    	state == "0%" ||
    	state == "100%" ||
    	state == "error" ||
        state == "status" ) {
        filter = 1
    }
    
    return filter;
};
        


var sortArrayByArray = function (listArray, sortArray){
	listArray.sort(function(a,b) {
		if (sortArray.indexOf(a) < 0) {
			return 1;
		}
		else if (sortArray.indexOf(b) < 0) {
			return -1;
		}
		else {
			return sortArray.indexOf(a) - sortArray.indexOf(b);
		}
	});
	return listArray;
};

//Used to dynamically update the state of objects
var updateList = function(path) {
	var URLHash = URLToHash();
	URLHash.fields = "state,state_log,type";
	URLHash.long_poll = 'true';
	URLHash.time = json_store.meta.time;
	if (updateSocket !== undefined && updateSocket.readyState != 4){
		// Only allow one update thread to run at once
		updateSocket.abort();
	}
	var split_path = HashtoJSONArgs(URLHash).split("?");
	var path_str = split_path[0];
	var arg_str = split_path[1];
	updateSocket = $.ajax({
		type: "GET",
		url: "/LONG_POLL?json('GET','"+path_str+"','"+arg_str+"')",
		dataType: "json",
		success: function( json, textStatus, jqXHR) {
			if (jqXHR.status == 200) {
				JSONStore(json);
				for (var entity in json.data){
					if (json.data[entity].type === undefined){
						// This is not an entity, skip it
						continue;
					}
					var color = getButtonColor(json.data[entity].state);
					$('button[entity="'+entity+'"]').find('.pull-right').text(
						json.data[entity].state);
					$('button[entity="'+entity+'"]').removeClass("btn-default");
					$('button[entity="'+entity+'"]').removeClass("btn-success");
					$('button[entity="'+entity+'"]').removeClass("btn-warning");
					$('button[entity="'+entity+'"]').removeClass("btn-danger");
					$('button[entity="'+entity+'"]').removeClass("btn-info");
					$('button[entity="'+entity+'"]').addClass("btn-"+color);
					
				}
			}
			if (jqXHR.status == 200 || jqXHR.status == 204) {
				//Call update again, if page is still here
				//KRK best way to handle this is likely to check the URL hash
				if (URLHash.path == path){
					//While we don't anticipate handling a list of groups, this 
					//may error out if a list was used
					updateList(path);
				}
			}
		}, // End success
	});  //ajax request
};//loadlistfunction

var updateItem = function(item,link,time) {
	var URLHash = URLToHash();
	URLHash.fields = "state";
	URLHash.long_poll = 'true';
	//URLHash.time = json_store.meta.time;
	if (updateSocket !== undefined && updateSocket.readyState != 4){
		// Only allow one update thread to run at once
		updateSocket.abort();
	}
	if (time === undefined) {
		time = "";
	}
	var path_str = "/objects"  // override, for now, would be good to add voice_cmds
	//arg_str=link=%2Fia7%2Fhouse%2Fgarage.shtml&fields=state%2Ctype&long_poll=true&time=1426011733833.94
	//arg_str = "fields=state,states,label&long_poll=true&time="+time;
	var arg_str = "fields=state,states,label,state_log&long_poll=true&items="+item+"&time="+time;
	//alert("path_str="+path_str+" arg_str="+arg_str)
	updateSocket = $.ajax({
		type: "GET",
		url: "/LONG_POLL?json('GET','"+path_str+"','"+arg_str+"')",
		dataType: "json",
		success: function( json, textStatus, jqXHR) {
			var requestTime = time;
			if (jqXHR.status == 200) {
				JSONStore(json);
				requestTime = json_store.meta.time;
				var color = getButtonColor(json.data[item].state);
				$('button[entity="'+item+'"]').find('.pull-right').text(
					json.data[item].state);
				$('button[entity="'+item+'"]').removeClass("btn-default");
				$('button[entity="'+item+'"]').removeClass("btn-success");
				$('button[entity="'+item+'"]').removeClass("btn-warning");
				$('button[entity="'+item+'"]').removeClass("btn-danger");
				$('button[entity="'+item+'"]').removeClass("btn-info");
				$('button[entity="'+item+'"]').addClass("btn-"+color);
			}
			if (jqXHR.status == 200 || jqXHR.status == 204) {

				if (URLHash.link == link || link == undefined){
//					//While we don't anticipate handling a list of groups, this 
//					//may error out if a list was used
					//testingObj(json_store.meta.time);
				updateItem(item,URLHash.link,requestTime);
				}
			}
		}, // End success
	});  //ajax request
}

var updateStaticPage = function(link,time) {
// Loop through objects and get entity name
// update entity based on mh module.
	var entity;
	var states_loaded = 0;
	if (link != undefined) {
  		states_loaded = 1;
	}
	var items = '';
    $('button[entity]').each(function(index) {
        if (index != 0) { //TODO really kludgy
          items += $(this).attr('entity')+",";
   		 }
   	})
	var URLHash = URLToHash();
	URLHash.fields = "state,states,state_log,label,type";
	URLHash.long_poll = 'true';
	URLHash.time = json_store.meta.time;
	if (updateSocket !== undefined && updateSocket.readyState != 4){
		// Only allow one update thread to run at once
		updateSocket.abort();
	}

	var path_str = "/objects"  // override, for now, would be good to add voice_cmds
	var arg_str = "fields=state%2Cstates%2Cstate_log%2Clabel&long_poll=true&items="+items+"&time="+time;

	updateSocket = $.ajax({
		type: "GET",
		url: "/LONG_POLL?json('GET','"+path_str+"','"+arg_str+"')",
		dataType: "json",
		success: function( json, textStatus, jqXHR) {
			var requestTime = time;
			if (jqXHR.status == 200) {
				JSONStore(json);
				requestTime = json_store.meta.time;
				$('button[entity]').each(function(index) {
					if ($(this).attr('entity') != '' && json.data[$(this).attr('entity')] != undefined ) { //need an entity item for this to work.
						entity = $(this).attr('entity');
						//alert ("entity="+entity+" this="+$(this).attr('entity'));
						//alert ("state "+json.data[entity].state)
						var color = getButtonColor(json.data[entity].state);
						$('button[entity="'+entity+'"]').find('.pull-right').text(json.data[entity].state);
						$('button[entity="'+entity+'"]').removeClass("btn-default");
						$('button[entity="'+entity+'"]').removeClass("btn-success");
						$('button[entity="'+entity+'"]').removeClass("btn-warning");
						$('button[entity="'+entity+'"]').removeClass("btn-danger");
						$('button[entity="'+entity+'"]').removeClass("btn-info");
						$('button[entity="'+entity+'"]').addClass("btn-"+color);
				
						//don't run this if stategrp0 exists	
						if (states_loaded == 0) {
			                $(".btn-state-cmd").click( function () {
                                var entity = $(this).attr("entity");			
								create_state_modal(entity);
							});
						}																
					}			
				});
			}
			if (jqXHR.status == 200 || jqXHR.status == 204) {
				//Call update again, if page is still here
				//KRK best way to handle this is likely to check the URL hash
				if (URLHash.link == link || link == undefined){
					//While we don't anticipate handling a list of groups, this 
					//may error out if a list was used
					updateStaticPage(URLHash.link,requestTime);
				}
			}
		}, 
	});  
}

	
//Prints all of the navigation items for Ia7
var loadCollection = function(collection_keys) {
	if (collection_keys === undefined) collection_keys = '0';
	var collection_keys_arr = collection_keys.split(",");
	var last_collection_key = collection_keys_arr[collection_keys_arr.length-1];
	var entity_arr = [];
	var items = "";
	var entity_sort = json_store.collections[last_collection_key].children;
	if (entity_sort.length <= 0){
		entity_arr.push("Childless Collection");
	}
	for (var i = 0; i < entity_sort.length; i++){
		var collection = entity_sort[i];
		if (!(collection in json_store.collections)) continue;
		var link = json_store.collections[collection].link;
		var icon = json_store.collections[collection].icon;
		var name = json_store.collections[collection].name;
		var mode = json_store.collections[collection].mode;
		var keys = json_store.collections[collection].keys; //for legacy CGI scripts to recreate proper URL
		var item = json_store.collections[collection].item;
		
		if (item !== undefined) {
			if (json_store.objects[item] === undefined) {
				var path_str = "/objects";
				var arg_str = "fields=state,states,label,state_log&items="+item;
				$.ajax({
					type: "GET",
					url: "/json"+path_str+"?"+arg_str,
					dataType: "json",
					success: function( json ) {
						JSONStore(json);
						loadCollection(collection_keys);
						}
				});
			} else {
				var name = item;
				var color = getButtonColor(json_store.objects[item].state);
				if (json_store.objects[item].label !== undefined) name = json_store.objects[item].label;
				var dbl_btn = "";
				if (name.length < 30) dbl_btn = "<br>"; 
				var button_html = "<div style='vertical-align:middle'><button entity='"+item+"' ";
				button_html += "class='btn btn-"+color+" btn-lg btn-block btn-list btn-popover btn-state-cmd navbutton-padding'>";
				button_html += name+dbl_btn+"<span class='pull-right'>"+json_store.objects[item].state+"</span></button></div>";
				entity_arr.push(button_html);
				items += item+",";		
			}
		
		} else {		
			if (json_store.collections[collection].iframe !== undefined) {
				link = "/ia7/include/iframe.shtml?"+json_store.collections[collection].iframe;
			}
			var hidden = "";
			if (mode != display_mode && mode != undefined ) hidden = "hidden"; //Hide any simple/advanced buttons
			var next_collection_keys = collection_keys + "," + entity_sort[i];
			if (keys === "true") {
				var arg = "?";
				if (link.indexOf("?") >= 0 ) { //already has arguments, so just add one on
					arg = "&";
				}
				link += arg+"ia7="+next_collection_keys;
			}		
			link = buildLink (link, next_collection_keys);
			if (json_store.collections[collection].external !== undefined) {
				link = json_store.collections[collection].external;
			}
			var icon_set = "fa";
			if (icon.indexOf("wi-") !=-1) icon_set = "wi";
			var button_html = "<a link-type='collection' href='"+link+"' class='btn btn-default btn-lg btn-block btn-list "+hidden+" navbutton-padding' role='button'><i class='"+icon_set+" "+icon+" icon-larger fa-2x fa-fw'></i>"+name+"</a>";
			entity_arr.push(button_html);
		}
	}
	//loop through array and print buttons
	var row = 0;
	var column = 1;
	for (var i = 0; i < entity_arr.length; i++){
		if (column == 1){
            if (row === 0){
                $('#list_content').html('');
            }
			$('#list_content').append("<div id='buffer"+row+"' class='row top-buffer'>");
			$('#buffer'+row).append("<div id='row" + row + "' class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>");
		}
		$('#row'+row).append("<div class='col-sm-4'>" + entity_arr[i] + "</div>");
		if (column == 3){
			column = 0;
			row++;
		}
		column++;
	}
	// if any items present, then create modals and activate updateItem...
	if (items !== "") {
		items = items.slice(0,-1); //remove last comma
		//console.log("items="+items);
		$('.btn-state-cmd').click( function () {			
			var entity = $(this).attr("entity");
			//console.log("entity="+entity);
			create_state_modal(entity);
		});
// test multiple items at some point
		updateItem(items);
	}	
	
};

//Constructs a link, likely should be replaced by HashToURL
function buildLink (link, collection_keys){
	if (link === undefined) {
		link = "#";
	} 
	else if (link.indexOf("#") === -1){
		link = "#_request=page&link="+link+"&";
	}
	else {
		link += "&";
	}
	link += "_collection_key="+ collection_keys;
	return link;
}

//Outputs a constantly updating print log
var print_log = function(type,time) {

	var URLHash = URLToHash();
	if (typeof time === 'undefined'){
		$('#list_content').html("<div id='print_log' class='row top-buffer'>");
		$('#print_log').append("<div id='row_log' class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>");
		$('#row_log').append("<ul id='list'></ul>");
		time = 0;
	}
	URLHash.time = time;
	URLHash.long_poll = 'true';
	if (updateSocket !== undefined && updateSocket.readyState != 4){
		// Only allow one update thread to run at once
		updateSocket.abort();
	}
	var split_path = HashtoJSONArgs(URLHash).split("?");
	var path_str = split_path[0];
	if (type == "speak") path_str = "/print_speaklog";
	var arg_str = split_path[1];	
	updateSocket = $.ajax({
		type: "GET",
		url: "/LONG_POLL?json('GET','"+path_str+"','"+arg_str+"')",
		dataType: "json",
		success: function( json, statusText, jqXHR ) {
			var requestTime = time;
			if (jqXHR.status == 200) {
				JSONStore(json);
				for (var i = (json.data.length-1); i >= 0; i--){
					var line = String(json.data[i]);
					line = line.replace(/\n/g,"<br>");
					if (line) $('#list').prepend("<li style='font-family:courier, monospace;white-space:pre-wrap;font-size:small;position:relative;'>"+line+"</li>");
				}
				requestTime = json.meta.time;
			}
			if (jqXHR.status == 200 || jqXHR.status == 204) {
				//Call update again, if page is still here
				//KRK best way to handle this is likely to check the URL hash
				if ($('#row_log').length !== 0){
					//If the print log page is still active request more data
					print_log(type,requestTime);
				}
			}		
		}
	});
};


//Creates a table based on the $json_table data structure. desktop & mobile design
var display_table = function(table,time) {

	var URLHash = URLToHash();
	if (typeof time === 'undefined'){
		$('#list_content').html("<div id='display_table' class='row top-buffer'>");
		$('#display_table').append("<div id='rtable' class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2 col-xs-11 col-xs-offset-0'>");
		time = 0;
	}
	URLHash.time = time;
	URLHash.long_poll = 'true';
	if (updateSocket !== undefined && updateSocket.readyState != 4){
		// Only allow one update thread to run at once
		updateSocket.abort();
	}	
	var path_str = "/table_data"  
	var arg_str = "var="+table+"&long_poll=true&time="+time;
	updateSocket = $.ajax({
		type: "GET",
		url: "/LONG_POLL?json('GET','"+path_str+"','"+arg_str+"')",
		dataType: "json",
		success: function( json, statusText, jqXHR ) {
			var requestTime = time;
			if (jqXHR.status == 200) {
				JSONStore(json);
				// HP should probably use jquery, but couldn't get sequencing right.
				// HP jquery would allow selected values to be replaced in the future.
				var html = "<table class='table table-curved'><thead><tr>";
				for (var i = 0; i < json.data.head.length; i++){
					var head = String(json.data.head[i]);
					html += "<th>"+head+"</th>";
				}
				html += "</tr></thead><tbody>";

				for (var i = 0; i < json.data.data.length; i++){
					html +="<tr>";
					for (var j = 0; j < json.data.data[i].length; j++){
					   var line = String(json.data.data[i][j]);
					  	html += "<td data-title='"+json.data.head[j]+"'>"+line+"</td>";

						}
					html += "</tr>";
				}
				html += "</tbody></table></div>";
				requestTime = json.meta.time;
				$('#rtable').html(html);

			}
			if (jqXHR.status == 200 || jqXHR.status == 204) {
				//Call update again, if page is still here
				//KRK best way to handle this is likely to check the URL hash
				if ($('#display_table').length !== 0){
					//If the display table page is still active request more data
					display_table(table,requestTime);
				}
			}		
		}
	});
};


var floorplan = function(group,time) {
	var URLHash = URLToHash();
	var baseimg_width;
	if (typeof time === 'undefined'){
  		$('#list_content').html("<div id='floorplan' class='row top-buffer'>");
  		$('#floorplan').append("<div id='graphic' class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>");
  		time = 0;
  		$('#graphic').prepend('<center><img id="fp_graphic" width="" src="/ia7/graphics/floorplan-'+group+'.png" /></center>');
  		baseimg_width = $(window).width();
    	if (baseimg_width > 990) baseimg_width = 800;
    	$('#fp_graphic').attr("width",baseimg_width+"px");
  	}
  	
 	if (updateSocket !== undefined && updateSocket.readyState != 4){
  		// Only allow one update thread to run at once
  		updateSocket.abort();
 	} 
	//resize window if changed
	window.onresize = function(){
    	baseimg_width = $(window).width();
   		if (baseimg_width > 990) baseimg_width = 800;
    	$('#fp_graphic').attr("width",baseimg_width+"px");
    	// update the location of all the objects...
    	$(".floorplan_item").each(function(index) {
    		var classstr = $(this).attr("class");
    		var coords = classstr.split(/coords=/)[1];
    		var fp_location = coords.split(/x/);
    		var location = get_fp_location(fp_location,0);
    		//alert("fp_location="+fp_location+" location="+location); 
    		$(this).attr("style",location);
		});
	}

 	var path_str = "/objects";  
 	var arg_str = "parents="+group+"&fields=fp_location,state,states,state_log,fp_icons,type&long_poll=true&time="+time;

 	updateSocket = $.ajax({
  		type: "GET",
  		url: "/LONG_POLL?json('GET','"+path_str+"','"+arg_str+"')",
  		dataType: "json",
  		success: function( json, statusText, jqXHR ) {
   			var requestTime = time;
    		if (jqXHR.status == 200) {
     			JSONStore(json);
     			for (var entity in json.data) {
					for (var i=0 ; i < json.data[entity].fp_location.length-1; i=i+2){ //allow for multiple graphics
						//alert("length="+json.data[entity].fp_location.length+" i="+i+" x="+json.data[entity].fp_location[i]+" y="+json.data[entity].fp_location[i+1]+" ent_length="+$('#entity_'+entity).length);
    					var location = get_fp_location(json.data[entity].fp_location,i);
   						var image = get_fp_image(json.data[entity]);
      					if ($('#entity_'+entity+'_'+i).length > 0) {
      						$('#entity_'+entity+'_'+i).attr('src',"/ia7/graphics/"+image);
      					} else {				   					
							$('#graphic').append('<img id="entity_'+entity+'_'+i+'" class="entity='+entity+'_'+i+' floorplan_item coords='+json.data[entity].fp_location[i]+'x'+json.data[entity].fp_location[i+1]+'" style="'+location+'" src="/ia7/graphics/'+image+'" />');
							//create_state_modal('#entity_'+entity+i,entity); 
						}
						$('#entity_'+entity+'_'+i).click( function () {
							//var fp_entity = $(this).attr("id").split(/entity_/)[1]; //
							var fp_entity = $(this).attr("id").match(/entity_(.*)_\d+$/)[1]; //strip out entity_ and ending _X ... item names can have underscores in them.
							//alert("entity="+fp_entity);
							create_state_modal(fp_entity);
						});	
 					}
 				}
    			requestTime = json.meta.time;
   			 }
   			if (jqXHR.status == 200 || jqXHR.status == 204) {
    		//Call update again, if page is still here
    		//KRK best way to handle this is likely to check the URL hash
    			if ($('#floorplan').length !== 0){
     				//If the floorplan page is still active request more data
     				floorplan(group,requestTime);
    			}
    		}
   		}  
 	});
};

//have to figure out height, and the jumps at 991 and 1200
var get_fp_location = function(item,index) {
	var baseimg_width = $(window).width();
	//var baseimg_height = $(window).height() - 60;
	var baseimg_height = $('#fp_graphic').height();	
	var tmargin = 0;
	var lmargin = 0;
  	//console.log("baseimg_width="+baseimg_width+"baseimg_height="+baseimg_height+" h2="+baseimg_height2); 
  	if (baseimg_width > 990) {
  		lmargin = (baseimg_width - 980) / 2;
  		tmargin = 20;
  		if (baseimg_width > 1200) {
  			lmargin = (baseimg_width - 1180) / 2;
  		}
  		baseimg_width = 800;

  	}
  	var location = "position: absolute; ";
  	var top = parseInt((baseimg_height * item[index] / 100)+tmargin);
  	var left = parseInt((baseimg_width * item[index+1] / 100)+lmargin);
  	console.log("baseimg_width="+baseimg_width+" top="+top+" left="+left); 
  	location += "top: "+top+"px;";
  	location += "left: "+left+"px";
  	return location;
}

var get_fp_image = function(item,size,orientation) {
  	var image_name;
 	if (item.fp_icons !== undefined) {
 		//alert("Has a button defined state="+item.fp_icons[item.state]);
 		if (item.fp_icons[item.state] !== undefined) return item.fp_icons[item.state];
 	}
 	//	if item.fp_icons.return item.fp_icons[state];
  	if(item.type == "Light_Item" || item.type == "Fan_Light" ||
    		item.type == "Insteon_Device" || item.type == "UPB_Link" ||
    		item.type == "Insteon::SwitchLinc" || item.type == "Insteon::SwitchLincRelay" ||    
    		item.type == "Insteon::KeyPadLinc" ||   		    				
    		item.type == "EIB_Item" || item.type == "EIB1_Item" ||
    		item.type == "EIB2_Item" || item.type == "EIO_Item" ||
    		item.type == "UIO_Item" || item.type == "X10_Item" ||    		
    		item.type == "xPL_Plugwise" || item.type == "X10_Appliance") {
 		if (item.state == "on") {
  			return "fp-light-on.png";
 		} else if (item.state == "off") {
  			return "fp-light-off.png";
 		} else {
  			return "fp-light-dim.png";
 		}
  	}
  	
  	if(item.type == "Motion_Item" || item.type == "X10_Sensor" ||
    		item.type == "Insteon::MotionSensor" ) {
 		if (item.state == "on" || item.state == "motion" ) {
  			return "fp-motion-motion.png";
 		} else if (item.state == "off" || item.state == "still") {
  			return "fp-motion-still.png";
 		}  else {
 			return "fp-unknown.png";
 		}
  	}
  	
  	if(item.type == "Door_Item" ) {
 		if (item.state == "open") {
  			return "fp-door-closed.png";
 		} else if (item.state == "closed") {
  			return "fp-door-closed.png";
 		} else {
  			return "fp-unknown.png";
 		}
  	}  	
  	
  	return "fp-unknown.png";
}

var create_state_modal = function(entity) {
		var name = entity;
		if (json_store.objects[entity].label !== undefined) name = json_store.objects[entity].label;
		$('#control').modal('show');
		var modal_state = json_store.objects[entity].state;
		$('#control').find('.object-title').html(name + " - " + json_store.objects[entity].state);
		$('#control').find('.control-dialog').attr("entity", entity);
		var modal_states = json_store.objects[entity].states;
		// HP need to have at least 2 states to be a controllable object...
		if (modal_states.length > 1) {
			$('#control').find('.states').html('<div class="btn-group stategrp0 btn-block"></div>');
			var modal_states = json_store.objects[entity].states;
			var buttonlength = 0;
			var stategrp = 0;
			var advanced_html = "";
			for (var i = 0; i < modal_states.length; i++){
				if (filterSubstate(modal_states[i]) == 1) {
				advanced_html += "<button class='btn btn-default col-sm-3 col-xs-3 hidden'>"+modal_states[i]+"</button>";
				continue 
			} else {
//TODO: Maybe just count buttons to create groups, organize them a bit better, <4 buttons, do a block?
				buttonlength += 2 + modal_states[i].length 
			}
			if (buttonlength >= 25) {
				stategrp++;
				$('#control').find('.states').append("<div class='btn-group btn-block stategrp"+stategrp+"'></div>");
				buttonlength = 0;
			}
			var color = getButtonColor(modal_states[i])
			var disabled = ""
			if (modal_states[i] == json_store.objects[entity].state) {
				disabled = "disabled";
			}
			$('#control').find('.states').find(".stategrp"+stategrp).append("<button class='btn col-sm-3 col-xs-3 btn-"+color+" "+disabled+"'>"+modal_states[i]+"</button>");
						
		}
		$('#control').find('.states').append("<div class='btn-group advanced btn-block'>"+advanced_html+"</div>");
		$('#control').find('.states').find('.btn').click(function (){
			url= '/SET;none?select_item='+$(this).parents('.control-dialog').attr("entity")+'&select_state='+$(this).text();
			$('#control').modal('hide');
			$.get( url);
		});
		} else {
			//remove states from anything that doesn't have more than 1 state
			$('#control').find('.states').find('.btn-group').remove();
		}
		if (json_store.ia7_config.prefs.state_log_show !== "no") {
			//state log show last 4 (separate out set_by as advanced) - keeps being added to each time it opens
			// could load all log items, and only unhide the last 4 -- maybe later
			$('#control').find('.modal-body').find('.obj_log').remove();

			$('#control').find('.modal-body').append("<div class='obj_log'><h4>Object Log</h4>");
			for (var i = 0; i < json_store.ia7_config.prefs.state_log_entries; i++) {
				if (json_store.objects[entity].state_log[i] == undefined) continue;
				var slog = json_store.objects[entity].state_log[i].split("set_by=");
				$('#control').find('.obj_log').append(slog[0]+"<span class='mh_set_by hidden'>set_by="+slog[1]+"</span><br>");
			}
		}		
		$('.mhstatemode').on('click', function(){
			$('#control').find('.states').find('.btn').removeClass('hidden');
			$('#control').find('.mh_set_by').removeClass('hidden');
		});
}	


//Outputs the list of triggers
var trigger = function() {
	$.ajax({
	type: "GET",
	url: "/json/triggers",
	dataType: "json",
	success: function( json ) {
		var keys = [];
		for (var key in json.triggers) {
			keys.push(key);
		}
		var row = 0;
		for (var i = (keys.length-1); i >= 0; i--){
			var name = keys[i];
			if (row === 0){
				$('#list_content').html('');
			}
			var dark_row = '';
			if (row % 2 == 1){
				dark_row = 'dark-row';
			}
			$('#list_content').append("<div id='row_a_" + row + "' class='row top-buffer'>");
			$('#row_a_'+row).append("<div id='content_a_" + row + "' class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>");
			$('#content_a_'+row).append("<div class='col-sm-5 trigger "+dark_row+"'><b>Name: </b><a id='name_"+row+"'>" + name + "</a></div>");
			$('#content_a_'+row).append("<div class='col-sm-4 trigger "+dark_row+"'><b>Type: </b><a id='type_"+row+"'>" + json.triggers[keys[i]].type + "</a></div>");
			$('#content_a_'+row).append("<div class='col-sm-3 trigger "+dark_row+"'><b>Last Run:</b> " + json.triggers[keys[i]].triggered + "</div>");
			$('#list_content').append("<div id='row_b_" + row + "' class='row'>");
			$('#row_b_'+row).append("<div id='content_b_" + row + "' class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>");
			$('#content_b_'+row).append("<div class='col-sm-5 trigger "+dark_row+"'><b>Trigger:</b> <a id='trigger_"+row+"'>" + json.triggers[keys[i]].trigger + "</a></div>");
			$('#content_b_'+row).append("<div class='col-sm-7 trigger "+dark_row+"'><b>Code:</b> <a id='code_"+row+"'>" + json.triggers[keys[i]].code + "</a></div>");
			$.fn.editable.defaults.mode = 'inline';
			$('#name_'+row).editable({
				type: 'text',
				pk: 1,
				url: '/post',
				title: 'Enter username'
			});
			$('#type_'+row).editable({
				type: 'select',
				pk: 1,
				url: '/post',
				title: 'Select Type',
				source: [{value: 1, text: "Disabled"}, {value: 2, text: "NoExpire"}]
			});
			$('#trigger_'+row).editable({
				type: 'text',
				pk: 1,
				url: '/post',
				title: 'Enter trigger'
			});
			$('#code_'+row).editable({
				type: 'text',
				pk: 1,
				url: '/post',
				title: 'Enter code'
			});
			row++;
		}
	}
	});
};

$(document).ready(function() {
	// Start
	changePage();
	//Watch for future changes in hash
	$(window).bind('hashchange', function() {
		changePage();
	});
	$("#mhstatus").click( function () {
		var link = json_store.collections[600].link;
		link = buildLink (link, "0,600");
	//    window.location.href = "/ia7/#path=/objects&parents=group1&_collection_key=0,1,17,$group1";
	    window.location.href = link;
	});
	updateItem("ia7_status");
	$("#toolButton").click( function () {
		var entity = $("#toolButton").attr('entity');
		$('#optionsModal').modal('show');
		$('#optionsModal').find('.object-title').html("Mr.House Options");
		$('#optionsModal').find('.options-dialog').attr("entity", "options");
		
		$('#optionsModal').find('.modal-body').html('<div class="btn-group btn-block" data-toggle="buttons"></div>');
		var simple_active = "active";
		var simple_checked = "checked";
		var advanced_active = "";
		var advanced_checked = ""
		if (display_mode == "advanced") {
			simple_active = "";
			simple_checked = "";
			advanced_active = "active";
			advanced_checked = "checked"
		}
		$('#optionsModal').find('.modal-body').find('.btn-group').append("<label class='btn btn-default mhmode col-xs-6 col-sm-6"+simple_active+"'><input type='radio' name='mhmode2' id='simple' autocomplete='off'"+simple_checked+">simple</label>");
		$('#optionsModal').find('.modal-body').find('.btn-group').append("<label class='btn btn-default mhmode col-xs-6 col-sm-6"+advanced_active+"'><input type='radio' name='mhmode2' id='advanced' autocomplete='off'"+advanced_checked+">advanced</label>");
		$('.mhmode').on('click', function(){
			display_mode = $(this).find('input').attr('id');	
			changePage();
  		});
		// parse the collection ID 500 and build a list of buttons
		var opt_collection_keys = 0;
		var opt_entity_html = "";
		var opt_entity_sort = json_store.collections[500].children;
		if (opt_entity_sort.length <= 0){
		opt_entity_html = "Childless Collection";
		} else {
		    for (var i = 0; i < opt_entity_sort.length; i++){
				var collection = opt_entity_sort[i];
				if (!(collection in json_store.collections)) continue;
				var link = json_store.collections[collection].link;
				var icon = json_store.collections[collection].icon;
				var name = json_store.collections[collection].name;
				if (json_store.collections[collection].iframe !== undefined) {
				   link = "/ia7/include/iframe.shtml?"+json_store.collections[collection].iframe;
				}
				var opt_next_collection_keys = opt_collection_keys + "," + opt_entity_sort[i];
				link = buildLink (link, opt_next_collection_keys);
				if (json_store.collections[collection].external !== undefined) {
					link = json_store.collections[collection].external;
				}
				opt_entity_html += "<a link-type='collection' href='"+link+"' class='btn btn-default btn-lg btn-block btn-list' role='button'><i class='fa "+icon+" fa-2x fa-fw'></i>"+name+"</a>";
			}
		}
		$('#optionsModal').find('.modal-body').append(opt_entity_html);						
		$('#optionsModal').find('.btn-list').click(function (){
			$('#optionsModal').modal('hide');
		});
	});
});

//
// LICENSE
//
// This program is free software; you can redistribute it and/or modify it under the terms of
//   the GNU General Public License as published by the Free Software Foundation; 
//   either version 2 of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//   without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
//   See the GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License along with this program;
//   if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
