// Loads all Semantic javascripts
//= require semantic-ui

const metrics_endpoints = {
	update: 'update_current_metrics',
	get: 'get_current_metrics'
}

// prevents enumerator from being changed
Object.freeze(metrics_endpoints);


$(document).ready(function(){

	// Initializing Fomantic UI elements
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

$.getJSON(metrics_endpoints['get'],function(data,status){
	
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
					.calendar('set date', new Date(condition?.parameters?.date));
					break;
				case "grade_drop":
					$('#grade_drop_checkbox').checkbox('check');
					$('#grade_drop_percentage')
					.val(condition?.parameters?.percentage_drop);
					$('#grade_drop_consecutive_counts')
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

$('#save').click(function(){
	
	$('#save').addClass('loading');

	let new_conditions = {};
	console.log($('#grace_days_by_date').calendar('get date'));
	if($('#no_submit_checkbox').checkbox('is checked')){
		new_conditions['no_submissions'] = {
			no_submissions_threshold: $("#no_submit_value").dropdown('get value')
		};
	}

	if($('#grace_days_checkbox').checkbox('is checked')){
		new_conditions['grace_day_usage'] = {
			grace_day_threshold: $("#grace_days_value").dropdown('get value'),
			date: $('#grace_days_by_date').calendar('get date')
		};
	}

	if($('#grade_drop_checkbox').checkbox('is checked')){
		new_conditions['grade_drop'] = {
			percentage_drop: $("#grade_drop_percentage").val(),
			consecutive_counts: $('#grade_drop_consecutive_counts').dropdown('get value')
		};
	}

	if($('#low_grades').checkbox('is checked')){
		new_conditions['low_grades'] = {
			grade_threshold: $("#low_grades_percentage").val(),
			count_threshold: $('#low_grades_count').dropdown('get value')
		};
	}

	$.ajax({
		url:metrics_endpoints['update'],
		dataType: "json",
		contentType:'application/json',
		data: JSON.stringify(new_conditions),
		type: "POST",
		success:function(data,type){
			console.log(data);
			$('#save').removeClass('loading');
			$('#save').addClass('disabled');
			display_banner({
				type:"positive",
				header:"You have successfully saved your conditions",
				message:"You're watchlist should reflect based on your new conditions"
			});
		}
	});
})

var message_count = 0;

const display_banner = (params) => {
	
	const message_html = `
						<div class="ui ${params.type} message" 
							id="message_${message_count}">
							<i class="close icon"></i>
							<div class="header">
							${params.header}
							</div>
							${params.message}
						</div>
						`;
	
	$('#message_area').append(message_html);
	
	$(`#message_${message_count} .close`)
	.on('click', function() {
		$(this)
		.closest('.message')
		.transition('fade')
		;
	});

	message_count++;
}