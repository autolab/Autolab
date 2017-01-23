/* JavaScript code that will be added to every page throughout the application */


/* Moment JS generic converter */
$(document).ready(function() {
	$(".moment-date-time").each(function(ind) {
		$el = $(this);
		var format = $el.data("format")  || "MMMM Do YYYY, h:mm a";
		var unformattedDate = $el.html();
		var formattedDate = moment(unformattedDate, "YYYY-MM-DD hh:mm ZZ").format(format);
		$el.html(formattedDate);
	});

	/* Adding CSRF token to every Ajax call by default */
	jQuery.ajaxSetup({
    	headers: {
        	'X-CSRF-Token' : $('meta[name="csrf-token"]').attr('content')
    	},
	});

	/* Activating Tooltips */
	$('.tooltipped').tooltip({delay: 50});
    
    /* Materialize Initializations */
    $('select').material_select();
});


