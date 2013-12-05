function getURLParameter(name) {
	return decodeURIComponent((new RegExp('[?|&]' + name + '=' + '([^&;]+?)(&|#|;|$)').exec(location.search)||[,""])[1].replace(/\+/g, '%20'))||null;
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

				//Put entities into button
				button_html = "<div style='vertical-align:middle'><button type='button' listType='"+listType+"'";
				button_html += "class='btn btn-default btn-lg btn-block btn-list btn-division'>";
				button_html += "" +button_text+"</button></div>";
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
		$(".dropdown-voice-cmd > li > a").click( function () {
			var button_group = $(this).parents('.btn-group');
			button_group.find('.leadcontainer > .dropdown-lead >u').html($(this).text());
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
		$(".btn-division").click( function () {
			window.location.href = "/ia7/print_selected.shtml?type="+$(this).attr("listType")+"&name=" + $(this).text();
		});
		}//success function
	});  //ajax request
};//loadlistfunction

var loadCollection = function(collection_key) {
	if (collection_key === null) collection_key = 0;
	$.ajax({
		type: "GET",
		url: '/ia7/include/collections.pl',
		dataType: "json",
		success: function( json ) {
			var entity_arr = [];
			// sort the collections
			var entity_sort = [];
			for (var key in json.collections) {
				if (json.collections.hasOwnProperty(key)) {
				entity_sort.push(key);
				}
			}
			entity_sort.sort ();
			for (var i = 0; i < entity_sort.length; i++){
				var collection = entity_sort[i];
				if (json.collections[collection].parent != collection_key) continue;
				var name = collection.replace(/^\d*-/g,'');
				var link = json.collections[collection].link;
				var icon = json.collections[collection].icon;
				if (link === undefined) link = "/ia7/index.shtml?collection_key="+ json.collections[collection].key;
				var button_html = "<a href='"+link+"' class='btn btn-default btn-lg btn-block btn-list' role='button'><i class='fa "+icon+" fa-2x fa-fw'></i>"+name+"</a>";
				entity_arr.push(button_html);
			}
			//loop through array and print buttons
			var row = 0;
			var column = 1;
			for (var i = 0; i < entity_arr.length; i++){
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
		}
	});
};