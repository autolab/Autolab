/* JavaScript code that will be added to every page throughout the application */


/* Adding CSRF token to every Ajax call by default */

jQuery.ajaxSetup({
    headers: {
        'X-CSRF-Token' : $('meta[name="csrf-token"]').attr('content')
    },
});


/* Moment JS generic converter */
$(".moment-date-time").each(function(ind) {
	$el = $(this);
	var format = $el.data("format")  || "dddd, MMM Do YYYY, h:mm:ss a";
	var unformattedDate = $el.html();
	var formattedDate = moment(new Date(unformattedDate)).format(format);
	$el.html(formattedDate);
})

/* Activating Tooltips */
$(function () {
  $('[data-toggle="tooltip"]').tooltip()
})
