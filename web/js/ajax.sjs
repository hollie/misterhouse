// Get the refresh rate from MH
var refresh_frequency=(<!-- #include var="$config_parms{html_refresh_rate}" -->*1000);
	
// Start the update timer for the refresh interval
jQuery(document).ready(function(){
	setTimeout("ajaxUpdate();", refresh_frequency);
});
	
// Function to update ajax fields
function ajaxUpdate(){
	// Check the refresh frequency is greater or equal to 10 seconds, anything lower hammers Misterhouse too much
	// If less than 10 seconds, we set the refresh to 10 seconds, and skip the current update
	// otherwise proceed as normal
	if (refresh_frequency < 10000){
		refresh_frequency=10000;
	} else {
		// Loop through each ajax include
		jQuery("span.ajax_update").each(function(){
			// Get the url we use to update the data
			var source_url = jQuery(this).find("input:hidden").val();
			// Get the span we should be updating
			var span = jQuery(this).find("span.content");
	
			// Update the field
			jQuery.ajax({
				url: source_url,
				dataType: "html",
				success: function(data){
					span.html(data);
				}
			});
		});
	}
	// Restart the refresh timer
	setTimeout("ajaxUpdate();", refresh_frequency);
}

jQuery.fn.vertCenter = function () {
    this.css("top", ((jQuery(window).height() - this.outerHeight()) / 2) + jQuery(window).scrollTop() + "px");
    return this;
}
