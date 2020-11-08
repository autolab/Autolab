// Loads all Semantic javascripts
//= require semantic-ui
$(document).ready(function(){
    $('.tabular.menu .item').tab();
		$('.ui.dropdown').dropdown();
		$('.ui.checkbox').checkbox();
		$('.ui.calendar').calendar({type: 'date'});
    $('.ui.form')
	  .form({
			inline: true,
	    fields: {
	      percentage1: {
	        identifier: 'percentage1',
	        optional: 'true',
	        rules: [
	          {
	            type   : 'integer[0..100]',
	            prompt : 'Please enter an integer from 0 to 100 for percentages'
	          }
	        ]
				},
				percentage2: {
	        identifier: 'percentage2',
	        optional: 'true',
	        rules: [
	          {
	            type   : 'integer[0..100]',
	            prompt : 'Please enter an integer from 0 to 100 for percentages'
	          }
	        ]
				},
	    }
		});

		$('[name="metrics-checkbox-1"]').change(function() {
			$('#save').removeClass('disabled');
		});

		$('[name="metrics-checkbox-2"]').change(function() {
			$('#save').removeClass('disabled');
		});

		$('[name="metrics-checkbox-3"]').change(function() {
			$('#save').removeClass('disabled');
		});

		$('[name="metrics-checkbox-4"]').change(function() {
			$('#save').removeClass('disabled');
		});
		
		$(window).bind('beforeunload', function(){
			if (!$('#save').hasClass('disabled')) {
				return 'Make sure to save your changes';
			}
		});
});
