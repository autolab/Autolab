/* JavaScript code that will be added to every page throughout the application */

/* Moment JS generic converter */
$(".moment-time").each(function(ind) {
	$el = $(this);
	var format = $el.data("format");
	var unformattedDate = $el.html();
	var formattedDate = moment(new Date(unformattedDate)).format(format);
	$el.html(formattedDate);
})