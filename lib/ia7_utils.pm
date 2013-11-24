package ia7_utils;

=head1 B<ia7_utils>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Provides support for the common routines used by the ia7 interface.

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item B<get_cats>

Returns a reference to a hash containing the database of catagories.

In the future, the categories will be written to the data directory.  If no such
file exists a default copy will be created.  While building the code, it is
easiest to force the default setup.

=cut

sub get_cats {
	my %default_cats = (
		'01-Mr. House Home' => { 
			'link' => 'view_sub_cat.pl?category=1',
			'icon' => 'fa-home',
			'key' => 1
		},
		'02-Mail and News' => { 
			'link' => 'news/index.html',
			'icon' => 'fa-envelope',
			'key' => 2
		},
		'03-Modes' => { 
			'link' => 'modes/index.html',
			'icon' => 'fa-tasks',
			'key' => 3
		},
		'04-Lights & Appliances' => { 
			'link' => 'lights/index.html',
			'icon' => 'fa-lightbulb-o',
			'key' => 4
		},
		'05-HVAC & Weather' => { 
			'link' => 'outside/index.shtml',
			'icon' => 'fa-umbrella',
			'key' => 5
		},
		'06-Security Cameras' => { 
			'link' => 'security/index.html',
			'icon' => 'fa-camera',
			'key' => 6
		},
		'07-Phone Calls & VoiceMail Msgs' => { 
			'link' => 'phone/index.html',
			'icon' => 'fa-phone',
			'key' => 7
		},
		'08-TV/Radio Guide & MP3 Music' => { 
			'link' => 'entertain/index.html',
			'icon' => 'fa-music',
			'key' => 8
		},
		'09-Speech' => { 
			'link' => 'speak/index.html',
			'icon' => 'fa-microphone',
			'key' => 9
		},
		'10-Comics & Pictures' => { 
			'link' => 'pictures/index.html',
			'icon' => 'fa-picture-o',
			'key' => 10
		},
		'11-Events, Calendar, & Clock' => { 
			'link' => 'calendar/index.html',
			'icon' => 'fa-calendar',
			'key' => 11
		},
		'12-Statistics & Logged Data' => { 
			'link' => 'statistics/index.html',
			'icon' => 'fa-bar-chart-o',
			'key' => 12
		},
		
	);
	return \%default_cats;
}

=item B<get_sub_cats>

Returns a reference to a hash containing the database of sub-catagories.

In the future, the sub-categories will be written to the data directory.  If no such
file exists a default copy will be created.  While building the code, it is
easiest to force the default setup.

=cut

sub get_sub_cats {
	my %default_sub_cats = (
		'01-About MrHouse' => { 
			'link' => 'house/main.shtml',
			'icon' => 'fa-home',
			'category' => 1
		},
		'02-About 3Com Audrey' => { 
			'link' => 'house/aboutaudrey.shtml',
			'icon' => 'fa-desktop',
			'category' => 1
		},
		'03-Browse MrHouse' => { 
			'link' => 'print_categories.pl?categories=MisterHouse',
			'icon' => 'fa-home',
			'category' => 1
		},
		'04-Browse Categories' => { 
			'link' => 'list_categories.shtml',
			'icon' => 'fa-archive',
			'category' => 1
		},
		'05-Browse Groups' => { 
			'link' => 'list_groups.shtml',
			'icon' => 'fa-group',
			'category' => 1
		},
		'06-Browse Items' => { 
			'link' => 'list_types.shtml',
			'icon' => 'fa-info',
			'category' => 1
		},
		'07-Browse Widgets' => { 
			'link' => '/bin/list_widgets.pl',
			'icon' => 'fa-gears',
			'category' => 1
		},
		'08-Setup MrHouse' => { 
			'link' => 'house/setup.shtml',
			'icon' => 'fa-wrench',
			'category' => 1
		},
	);
	return \%default_sub_cats;
}

sub print_header {
	my ($title) = @_;
	$output =<<END;
	
	<!DOCTYPE html>
	<html><head><title>$title</title>
END
	$output .=<<'END';
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		
		<!--Font Awesome-->
		<link href="//netdna.bootstrapcdn.com/font-awesome/4.0.3/css/font-awesome.min.css" rel="stylesheet">
		
		<!-- Jquery -->
		<script src="//code.jquery.com/jquery-1.10.2.min.js"></script>
		
		<!--Bootstrap-->
		<!-- Latest compiled and minified CSS -->
		<link rel="stylesheet" href="//netdna.bootstrapcdn.com/bootstrap/3.0.2/css/bootstrap.min.css">
		
		<!-- Optional theme -->
		<link rel="stylesheet" href="//netdna.bootstrapcdn.com/bootstrap/3.0.2/css/bootstrap-theme.min.css">
		
		<!-- Latest compiled and minified JavaScript -->
		<script src="//netdna.bootstrapcdn.com/bootstrap/3.0.2/js/bootstrap.min.js"></script>
		
		<style type="text/css">
		.btn-category {
		  overflow: hidden;
		  text-overflow: ellipsis;
		  white-space: nowrap;
		  text-align: left;
		  padding-left: 15px;
		  padding-right: 15px;
		}
		.btn-category-dropdown {
		  
		}
		@media (min-width: 768px) {
			.top-buffer {
				margin-top:20px;
			}
		}
		
		@media (min-width: 450px){
			.control-dialog {
				width: 400px;
			}
		}
		.col-center {
			text-align: center;
		}
		.dropdown-lead{
			width: 100%;
		}
		.leadcontainer {
			left: 0;
			position: absolute;
			right: 30px;
		}
		.dropdown-toggle{
			width: 30px;
			box-sizing: border-box;
		}
		.fillsplit {
			position: relative;
		}
		.states {
			text-align: center;
		}
		</style>
	</head>
	<body>
	<div class='row top-buffer'>
		<div class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>
			<div class='col-sm-4'>
				<a href='/ia5/'>
				<img src='/ia5/images/mhlogo.gif' alt='Reload Page' alt='Reload' border='0'>
				</a>
			</div>
		</div>
	</div>
END
	return $output;	
}

sub list_selected{
	my ($req_type) = @_;
	my $output =<<'END';
	<div id="list_content">
	</div>

	<script type="text/javascript">
	var list_selected = function(req_type) {
		$.ajax({
		type: "GET",
		url: "/sub?json("+req_type+",truncate)",
		dataType: "json",
		success: function( json ) {
			var row = 0;
			var column = 1;
			var button_text = '';
			var button_html = '';
			for (var k in json[req_type]){
				if (column == 1){
					$('#list_content').append("<div id='buffer"+row+"' class='row top-buffer'>");
					$('#buffer'+row).append("<div id='row" + row + "' class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>");
				}
				button_text = k;

				//Put Categories into button
				button_html = "<div style='vertical-align:middle'><button type='button' class='btn btn-default btn-lg btn-block btn-category'>";
				button_html += "" +button_text+"</button></div>";

				$('#row'+row).append("<div class='col-sm-4'>" + button_html + "</div>");
				if (column == 3){
					column = 0;
					row++;
				}
				column++;
			};//json for loop
			$(".btn-category").click( function () {
				window.location.href = "/ia7/print_"+req_type+".pl?"+req_type+"=" + $(this).text();
			});
			}//success function
		});  //ajax request
	}//loadlistfunction
	$(document).ready(function() {
	// Start
END
	$output .= "\t\tlist_selected('$req_type');\n\t});\n</script>";
	return $output;
}

sub print_category {
	my ($category) = @_;
	
	$output =<<'END';
	<div id="list_content">
	</div>
	<!-- Modal -->
	<div class="modal fade" id="lastResponse" tabindex="-1" role="dialog" aria-labelledby="myModalLabel" aria-hidden="true">
	  <div class="modal-dialog">
	    <div class="modal-content">
	      <div class="modal-header">
	        <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
	        <h4 class="modal-title" id="myModalLabel">Last Response</h4>
	      </div>
	      <div class="modal-body">
	      </div>
	      <div class="modal-footer">
	        <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
	      </div>
	    </div><!-- /.modal-content -->
	  </div><!-- /.modal-dialog -->
	</div><!-- /.modal -->
	<script type="text/javascript">
	
	var loadList = function(category) {
		$.ajax({
		type: "GET",
		url: "/sub?json(categories="+category+",fields=text|type)",
		dataType: "json",
		success: function( json ) {
			var row = 0;
			var column = 1;
			var button_text = '';
			var button_html = '';
			var cat_hash = {};
			for (var k in json.categories){
				cat_hash = json.categories[k];
				break
			}
			for (var k in cat_hash){
				if (column == 1){
					$('#list_content').append("<div id='buffer"+row+"' class='row top-buffer'>");
					$('#buffer'+row).append("<div id='row" + row + "' class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>");
				}
				button_text = cat_hash[k].text;
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
					button_html += '<button type="button" class="btn btn-default dropdown-lead btn-lg btn-category">'+button_text_start + "<u>" + options[0] + "</u>" + button_text_end+'</button>';
					button_html += '</div>';
					button_html += '<button type="button" class="btn btn-default btn-lg dropdown-toggle pull-right btn-category-dropdown" data-toggle="dropdown">';
					button_html += '<span class="caret"></span>';
					button_html += '<span class="sr-only">Toggle Dropdown</span>';
					button_html += '</button>';
					button_html += '<ul class="dropdown-menu" role="menu">';
					for (var i=0,len=options.length; i<len; i++) { 
						button_html += '<li><a href="#">'+options[i]+'</a></li>';
					}
					button_html += '</ul>';
					button_html += '</div>';
				}
				else {
					button_html = "<div style='vertical-align:middle'><button type='button' class='btn btn-default btn-lg btn-block btn-category'>";
					button_html += "" +button_text+"</button></div>";
				}
				$('#row'+row).append("<div class='col-sm-4'>" + button_html + "</div>");
				if (column == 3){
					column = 0;
					row++;
				}
				column++;
			};//json each loop
			$(".dropdown-menu > li > a").click( function () {
				var button_group = $(this).parents('.btn-group');
				button_group.find('.leadcontainer > .dropdown-lead >u').html($(this).text());
			});
			$(".btn-category").click( function () {
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
			}//success function
		});  //ajax request
	}//loadlistfunction
	
	$(document).ready(function() {
		// Start
END
	$output .= "\t\tloadList('$category');\n\t});\n</script>";

	return $output;
}

sub print_group {
	my ($group) = @_;
	
	$output =<<'END';
	<div id="list_content">
	</div>
	<!-- Modal -->
	<div class="modal fade" id="control" tabindex="-1" role="dialog" aria-labelledby="myModalLabel" aria-hidden="true">
	  <div class="modal-dialog control-dialog">
	    <div class="modal-content">
	      <div class="modal-header">
	        <h4 class="modal-title" id="myModalLabel"><span class="object-title"></span>
		        <div class="btn-group btn-group-sm pull-right">
		        	<button type="button" class="btn btn-default"><i class="fa fa-gear"></i></button>
		        	<button type="button" class="btn btn-default" data-dismiss="modal"><i class="fa fa-times"></i></button>
		        </div>
	        </h4>
	      </div>
	      <div class="modal-body">
	        <div class="states">
	        </div>
	      </div>
	    </div><!-- /.modal-content -->
	  </div><!-- /.modal-dialog -->
	</div><!-- /.modal -->
	<script type="text/javascript">
	
	var loadList = function(category) {
		$.ajax({
		type: "GET",
		url: "/sub?json(groups="+category+",fields=state|states)",
		dataType: "json",
		success: function( json ) {
			var row = 0;
			var column = 1;
			var button_text = '';
			var button_html = '';
			var cat_hash = {};
			for (var k in json.groups){
				cat_hash = json.groups[k];
				break
			}
			for (var k in cat_hash){
				var object = cat_hash[k];
				if (column == 1){
					$('#list_content').append("<div id='buffer"+row+"' class='row top-buffer'>");
					$('#buffer'+row).append("<div id='row" + row + "' class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>");
				}
				var state = object.state;
				var name = k;
				var html = "";
				var html = "";
				//Put objects into button
				html = "<div style='vertical-align:middle'><button id='"+name+"' class='btn btn-default btn-lg btn-block btn-category btn-popover'>";
				html += name+"<span class='pull-right'>"+state+"</span></button></div>";
				$('#row'+row).append("<div class='col-sm-4'>" + html + "</div>\n");
				if (column == 3){
					column = 0;
					row++;
				}
				column++;
			};//json each loop
			$(".btn-popover").click( function () {
				$('#control').modal('show');
				$('#control').find('.object-title').html($(this).attr("id") + " - " + state);
				$('#control').find('.control-dialog').attr("id", $(this).attr("id"));
				$('#control').find('.states').html('<div class="btn-group"></div>');
				var states = cat_hash[$(this).attr("id")].states;
				for (var k in cat_hash[$(this).attr("id")].states){
					$('#control').find('.states').find('.btn-group').append("<button class='btn btn-default'>"+states[k]+"</button>");
				}
				$('#control').find('.states').find(".btn-default").click(function (){
					url= '/SET;none?select_item='+$(this).parents('.control-dialog').attr("id")+'&select_state='+$(this).text();
					console.log(url);
					$('#control').modal('hide');
					$.get( url);
				});
			});
			//$('.btn-popover').popover({});
			}//success function
		});  //ajax request
	}//loadlistfunction
	
	$(document).ready(function() {
		// Start
END
	$output .= "\t\tloadList('$group');\n\t});\n</script>";

	return $output;
}

sub print_log_changes{
	my ($time) = @_;
	if (int($time) >= int(::print_log_current_time())){
		return;
	}
	return ::json('print_log','time='.$time);
}


=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Kevin Robert Keegan

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut
1;