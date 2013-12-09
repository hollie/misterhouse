var collection_json;  //global storage for collection database

function getURLParameter(name, type) {
    var prefix = '[?|&]';
    if (type === undefined) type = 'search';
    if (type == 'hash') prefix = '[#|&]';
	return decodeURIComponent((new RegExp(prefix + name + '=' + '([^&;]+?)(&|#|;|$)').exec(location[type])||[,""])[1].replace(/\+/g, '%20'))||null;
}

function changePage (){
	if (collection_json === undefined){
		$.ajax({
			type: "GET",
			url: '/ia7/include/collections.pl',
			dataType: "json",
			success: function( json ) {
				collection_json = json;
				changePage();
			}
		});
	} 
	else { //We have the database
		if (getURLParameter('request', 'hash') == 'list'){
	        loadList(getURLParameter('type','hash'),getURLParameter('name','hash'));
		}
		else if(getURLParameter('request', 'hash') == 'page'){
			$('#list_content').load(getURLParameter('link', 'hash'));
		}
		else { //default response is to load a collection
	        loadCollection(getURLParameter('collection_key', 'hash'));
		}
		//update the breadcrumb
		$('#nav').html('');
		var collection_keys_arr = getURLParameter('collection_key', 'hash');
		if (collection_keys_arr === null) collection_keys_arr = '0';
		collection_keys_arr = collection_keys_arr.split(',');
		var breadcrumb = '';
		for (var i = 0; i < collection_keys_arr.length; i++){
			var nav_link = collection_json.collections[collection_keys_arr[i]].link;
			nav_link = buildLink (nav_link, breadcrumb + collection_keys_arr[i]);
			breadcrumb += collection_keys_arr[i] + ",";
			var nav_name = collection_json.collections[collection_keys_arr[i]].name;
			if (i == (collection_keys_arr.length-1)){
				$('#nav').append('<li class="active">' + nav_name + '</a></li>');
			} 
			else {
				$('#nav').append('<li><a href="' + nav_link + '">' + nav_name + '</a></li>');
			}
		}
	}
}

var loadList = function(listType,listValue) {
	var url;
	if (listValue !== null){
		url = "/sub?json("+listType+"="+listValue+",fields=text|type|state|states)";
	} 
	else {
		url = "/sub?json("+listType+",truncate)";
	}
	$.ajax({
	type: "GET",
	url: url,
	dataType: "json",
	success: function( json ) {
		var button_text = '';
		var button_html = '';
		var entity_arr = [];
		for (var division in json[listType]){
			if (listValue === null){ //truncated list
				button_text = division;
                var collection_key = getURLParameter('collection_key', 'hash');
				//Put entities into button
				button_html = "<div style='vertical-align:middle'><a role='button' listType='"+listType+"'";
				button_html += "class='btn btn-default btn-lg btn-block btn-list btn-division'";
				button_html += "href='#request=list&collection_key="+collection_key+"&type="+listType+"&name="+button_text+"' >";
				button_html += "" +button_text+"</a></div>";
				entity_arr.push(button_html);
				continue;
			}//end truncated list
			for (var entity in json[listType][division]){
				if (json[listType][division][entity].type == "Voice_Cmd"){
					button_text = json[listType][division][entity].text;
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
						button_html += '<button type="button" class="btn btn-default dropdown-lead btn-lg btn-list btn-voice-cmd">'+button_text_start + "<u>" + options[0] + "</u>" + button_text_end+'</button>';
						button_html += '</div>';
						button_html += '<button type="button" class="btn btn-default btn-lg dropdown-toggle pull-right btn-list-dropdown" data-toggle="dropdown">';
						button_html += '<span class="caret"></span>';
						button_html += '<span class="sr-only">Toggle Dropdown</span>';
						button_html += '</button>';
						button_html += '<ul class="dropdown-menu dropdown-voice-cmd" role="menu">';
						for (var i=0,len=options.length; i<len; i++) { 
							button_html += '<li><a href="#">'+options[i]+'</a></li>';
						}
						button_html += '</ul>';
						button_html += '</div>';
					}
					else {
						button_html = "<div style='vertical-align:middle'><button type='button' class='btn btn-default btn-lg btn-block btn-list btn-voice-cmd'>";
						button_html += "" +button_text+"</button></div>";
					}
					entity_arr.push(button_html);
				} //Voice Command Button
				else {
					var object = json[listType][division][entity];
					var state = object.state;
					var name = entity;
					//Put objects into button
					button_html = "<div style='vertical-align:middle'><button entity='"+name+"' division='"+division+"' ";
					button_html += "class='btn btn-default btn-lg btn-block btn-list btn-popover btn-state-cmd'>";
					button_html += name+"<span class='pull-right'>"+state+"</span></button></div>";
					entity_arr.push(button_html);
				} //Not voice command button
			}//entity each loop
		}//division loop
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
			$('#control').modal('show');
			var modal_state = json[listType][$(this).attr("division")][$(this).attr("entity")].state;
			$('#control').find('.object-title').html($(this).attr("entity") + " - " + modal_state);
			$('#control').find('.control-dialog').attr("entity", $(this).attr("entity"));
			$('#control').find('.states').html('<div class="btn-group"></div>');
			var modal_states = json[listType][$(this).attr("division")][$(this).attr("entity")].states;
			for (var k in modal_states){
				$('#control').find('.states').find('.btn-group').append("<button class='btn btn-default'>"+modal_states[k]+"</button>");
			}
			$('#control').find('.states').find(".btn-default").click(function (){
				url= '/SET;none?select_item='+$(this).parents('.control-dialog').attr("entity")+'&select_state='+$(this).text();
				$('#control').modal('hide');
				$.get( url);
			});
		});
		}//success function
	});  //ajax request
};//loadlistfunction

var loadCollection = function(collection_keys) {
	if (collection_keys === null) collection_keys = '0';
	var collection_keys_arr = collection_keys.split(",");
	var last_collection_key = collection_keys_arr[collection_keys_arr.length-1];
	var entity_arr = [];
	// sort the collections
	var entity_sort = collection_json.collections[last_collection_key].children;
	for (var i = 0; i < entity_sort.length; i++){
		var collection = entity_sort[i];
		if (!(collection in collection_json.collections)) continue;
		var link = collection_json.collections[collection].link;
		var icon = collection_json.collections[collection].icon;
		var name = collection_json.collections[collection].name;
		var next_collection_keys = collection_keys + "," + entity_sort[i];
		link = buildLink (link, next_collection_keys);
		var button_html = "<a link-type='collection' href='"+link+"' class='btn btn-default btn-lg btn-block btn-list' role='button'><i class='fa "+icon+" fa-2x fa-fw'></i>"+name+"</a>";
		entity_arr.push(button_html);
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
};

function buildLink (link, collection_keys){
	if (link === undefined) {
		link = "#";
	} 
	else if (link.indexOf("#") === -1){
		link = "#request=page&link="+link+"&";
	}
	else {
		link += "&";
	}
	link += "collection_key="+ collection_keys;
	return link;
}