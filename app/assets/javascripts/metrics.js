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

});

$.getJSON("get_current_metrics",function(data,status){
	
	console.log(status);
	
	if(status=='success'){
		console.log(data);

		// situation when no conditions have been selected
		if(data.length == 1 && data[0]['condition_type'] == "no_condition_selected")
			return;

		data.forEach(condition => {
			switch(condition?.condition_type){
				case "no_submissions":
					$('#no_submit_checkbox').checkbox('check');
					$("#no_submit_value")
					.dropdown("set selected", condition?.parameters?.no_submissions_threshold ?? 1);
					break;
				case "grace_day_usage":
					$('#grace_days_checkbox').checkbox('check');
					$('#grace_days_value')
					.dropdown('set selected',condition?.parameters?.grace_day_threshold ?? 1);
					$('#grace_days_by_date')
					.calendar(condition?.parameters?.date, fireChange=false);
					break;
				case "grade_drop":
					$('#grades_drop_checkbox').checkbox('check');
					$('#grades_drop_percentage')
					.val(condition?.parameters?.percentage_drop);
					$('#grades_drop_consecutive_counts')
					.dropdown('set selected',condition?.parameters?.consecutive_counts ?? 1);
					break;
				case "low_grades":
					$('#low_grades_checkbox').checkbox('check');
					$('#low_grades_count')
					.dropdown('set selected',condition?.parameters?.count_threshold ?? 1);
					$('#low_grades_percentage')
					.val(condition?.parameters?.grade_threshold);
					break;
				default:
					console.error(condition?.condition_type +" is not valid");
					return;
			}
		})
	}

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