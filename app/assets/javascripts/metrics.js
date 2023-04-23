// Loads all Semantic javascripts
//= require semantic-ui

// metrics api endpoints
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
	$('.ui.checkbox.conditions').checkbox();
	$('.ui.checkbox.select_all').checkbox({
		onChecked: function () { $('.ui.tab.segments.active .ui.checkbox.select_single').checkbox('check') },
		onUnchecked: function () { $('.ui.tab.segments.active .ui.checkbox.select_single').checkbox('uncheck')  }
	});
	$('.ui.calendar').calendar({type: 'date', initialDate: new Date()});
	$('.ui.dropdown').dropdown('set selected',1);
	$('#grade_drop_consecutive_counts').dropdown('set selected',2);
});

// Updates form validation based on checked
$('.checkbox.conditions').change(function(){

	let fields = {};

	if($('#grade_drop_checkbox').checkbox('is checked')){
		fields['grade_drop_percentage'] = {
			identifier: 'grade_drop_percentage',
			rules: [
			  {
				type   : 'integer[1..100]',
				prompt : 'Please enter an integer from 1 to 100 for percentages'
			  }
			]
		};
	}

	if($('#low_grades_checkbox').checkbox('is checked')){
		fields['low_grades_percentage'] = {
			identifier: 'low_grades_percentage',
			rules: [
			  {
				type   : 'integer[1..100]',
				prompt : 'Please enter an integer from 1 to 100 for percentages'
			  }
			]
		};
	}

	if($('#extension_requests_checkbox').checkbox('is checked')){
		fields['extension_requests_count'] = {
			identifier: 'extension_requests_count',
			rules: [
				{
					type   : 'integer[1..]',
					prompt : 'Please enter an integer greater or equal to 1 for count'
				}
			]
		};
	}
	
	$('.ui.form').form({inline: true, fields});

});


$.getJSON(metrics_endpoints['get'],function(data, status){

	if(status=='success'){
		// situation when instructors have not set up any student metrics
		if(data.length == 0){
			$("#undefined_metrics").show();
      		$("#defined_metrics").hide();
      		$('.top-bar').hide();
		}else{
			get_watchlist_function();
		}
		// situation when no conditions have been selected
		if(data.length == 1 && data[0]['condition_type'] == "no_condition_selected")
			return;

		// switch case to check each checkbox field
		data.forEach(condition => {
			switch(_.get(condition,'condition_type')){
				case "no_submissions":
					$('#no_submit_checkbox').checkbox('check');
					$("#no_submit_value")
					.dropdown("set selected", _.get(condition,'parameters.no_submissions_threshold',1));
					break;
				case "grace_day_usage":
					$('#grace_days_checkbox').checkbox('check');
					$('#grace_days_value')
					.dropdown('set selected',_.get(condition,'parameters.grace_day_threshold',1));
					$('#grace_days_by_date')
					.calendar('set date', new Date(_.get(condition,'parameters.date',null)));
					break;
				case "grade_drop":
					$('#grade_drop_checkbox').checkbox('check');
					$('#grade_drop_percentage')
					.val(_.get(condition,'parameters.percentage_drop',null));
					$('#grade_drop_consecutive_counts')
					.dropdown('set selected',_.get(condition,'parameters.consecutive_counts',1));
					break;
				case "low_grades":
					$('#low_grades_checkbox').checkbox('check');
					$('#low_grades_count')
					.dropdown('set selected',_.get(condition,'parameters.count_threshold',1));
					$('#low_grades_percentage')
					.val(_.get(condition,'parameters.grade_threshold',1));
					break;
				case "extension_requests":
					$('#extension_requests_checkbox').checkbox('check');
					$('#extensions_requests_count')
					.val(_.get(condition,'parameters.extension_count',1));
					break;
				default:
					console.error(_.get(condition,'condition_type') + " is not valid");
					return;
			}
		})
	}

	$('.ui.form').change(function() {
		$('#save').removeClass('disabled');
	});

	$('.ui.calendar').calendar({
		type: 'date',
 		onChange: function () {
     		$('#save').removeClass('disabled');
    	},
	});

	$(window).bind('beforeunload', function(){
		if (!$('#save').hasClass('disabled')) {
			return 'Make sure to save your changes';
		}
	});
});

$('#save').click(function(){

	// Checks form validity
	if(!$('.ui.form').form('is valid'))
		return;
	
	$('#save').addClass('loading');
	let new_conditions = {};

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

	if($('#no_submit_checkbox').checkbox('is checked')){
		new_conditions['no_submissions'] = {
			no_submissions_threshold: $("#no_submit_value").dropdown('get value')
		};
	}

	if($('#low_grades_checkbox').checkbox('is checked')){
		new_conditions['low_grades'] = {
			grade_threshold: $("#low_grades_percentage").val(),
			count_threshold: $('#low_grades_count').dropdown('get value')
		};
	}

	if($('#extension_requests_checkbox').checkbox('is checked')){
		new_conditions['extension_requests'] = {
			extension_count: $('#extension_requests_count').val()
		};
	}

	$.ajax({
		url: metrics_endpoints['update'],
		dataType: "json",
		contentType:'application/json',
		data: JSON.stringify(new_conditions),
		type: "POST",
		success:function(data){
			render_banner({
				type:"positive",
				header:"You have successfully saved your student metrics",
				message:"Your watchlist should reflect your new student metrics",
			});
			get_watchlist_function();
		},
		error:function(result, type){
			render_banner({
				type:"negative",
				header:"Currently unable to update conditions",
				message: "Do try again later",
				timeout: -1
			});
		},
		complete:function(){
			$('#save').removeClass('loading');
			$('#save').addClass('disabled');
		}
	});

	// nothing was checked
	if($.isEmptyObject(new_conditions)) {
		$("#undefined_metrics").show();
      	$("#defined_metrics").hide();
      	$('.top-bar').hide();
	}
})


// variable to keep track of the different banners
var message_count = 0;

/**
 * Renders a banner given parameters
 * @param {Object} params Parameters of the banner
 * @param {string} params.type type of the banner, positive, negative, or warning
 * @param {string} params.header html string header of the banner
 * @param {string} params.message html string body of the banner
 * @param {number} params.timeout timeout of banner in milleseconds. -1 for no timeout. 
 */
const render_banner = (params) => {
	
	const message_id = message_count; // using a count as id

	// templating the html
	// important to give each element an unique id
	const message_html = `
	<div class="ui ${params.type} message" id="message_${message_id}">
		<i class="close icon"></i>
		<div class="header">
		${params.header}
		</div>
		${params.message}
	</div>
	`;
	
	// adding the html to a particular div
	$('#message_area').append(message_html);

	// logic handling
	$(`#message_${message_id} .close`)
	.on('click', function() {
		$(this).closest('.message').transition('fade');
	});

	// close after set number of seconds
	// if not closed yet
	if(!params['timeout'] || ['timeout'] >= 0){
		setTimeout(function(){
			const message_box = 
				$(`#message_${message_id} .close`).closest('.message');
			if(!message_box.hasClass('hidden'))
				message_box.transition('fade');
		},params['timeout'] || 5000 );
	}

	message_count++;
}
