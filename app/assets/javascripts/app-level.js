/* JavaScript code that will be added to every page throughout the application */


/* Moment JS generic converter */
$(document).ready(function() {
	// if using ancient browser that doesn't support Intl.DateTimeFormat, fallback to moment.tz
	var timezone = Intl.DateTimeFormat().resolvedOptions().timeZone || moment.tz.guess();

	$(".moment-date-time").each(function(ind) {
		$el = $(this);
		var format = $el.data("format")  || "YYYY-MM-DD HH:mm:ss ZZ";
		var unformattedDate = $el.html();
		var formattedDate = moment(unformattedDate, "YYYY-MM-DD hh:mm:ss ZZ").tz(timezone).format(format);
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
    $('select').formSelect();

	/* Initialize tabs */
	$('.tabs').tabs();
});


