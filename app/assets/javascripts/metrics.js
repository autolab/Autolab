// Loads all Semantic javascripts
//= require semantic-ui

// metrics api endpoints
const metrics_endpoints = {
	update: 'update_current_metrics',
	get: 'get_current_metrics'
}

// watchlist api endpoints
const watchlist_endpoints = {
	update: 'update_watchlist_instances',
	refresh: 'refresh_watchlist_instances',
	get: 'get_watchlist_instances'
}

// prevents enumerator from being changed
Object.freeze(metrics_endpoints);

$(document).ready(function(){

	// Initializing Fomantic UI elements
	$('.tabular.menu .item').tab();	
	$('.ui.dropdown').dropdown();
	$('.ui.checkbox').checkbox();
	$('.ui.calendar').calendar({type: 'date', initialDate: new Date()});
	$('.ui.dropdown').dropdown('set selected',1);
	$('#grade_drop_consecutive_counts').dropdown('set selected',2);
	
});

// Updates form validation based on checked
$('.checkbox').change(function(){

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
	
	$('.ui.form').form({inline: true, fields});

});


$.getJSON(metrics_endpoints['get'],function(data, status){

	if(status=='success'){
		// situation when instructors have not set up any risk metrics
		if(data.length == 0){
			$("#undefined_metrics").show();
      		$("#defined_metrics").hide();
      		$('.top-bar').hide();
		}else{
			refresh_watchlist();
		}
		// situation when no conditions have been selected
		if(data.length == 1 && data[0]['condition_type'] == "no_condition_selected")
			return;

		// switch case to check each checkbox field
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

	$.ajax({
		url:metrics_endpoints['update'],
		dataType: "json",
		contentType:'application/json',
		data: JSON.stringify(new_conditions),
		type: "POST",
		success:function(data){
			render_banner({
				type:"positive",
				header:"You have successfully saved your conditions",
				message:"Your watchlist should reflect your new conditions",
			});
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
	else{
		refresh_watchlist();
	}
})

function get_html_empty_message(message){
	return `
    	<div id="empty_tabs">
             <center>
                <i class="huge inbox icon"></i> 
                <h3> ${message} </h3>
             </center>
        </div>`;
}

function refresh_watchlist(){
	$.getJSON(watchlist_endpoints['get'],function(data, status){
	    if(status=='success'){
	    	var new_empty = 0;
	    	var contacted_empty = 0;
	    	var resolved_empty = 0;
	    	var archived_empty = 0;
	    	
	    	$("#undefined_metrics").hide();
      		$("#defined_metrics").show();

	    	$('#new_tab').empty();
	    	$('#contacted_tab').empty();
	    	$('#resolved_tab').empty();
	    	$('#archived_tab').empty();

	    	data["instances"].forEach(watchlist_instance => {
	    		var user_id = watchlist_instance?.course_user_datum_id;
	    		var instance_id = watchlist_instance?.id;
		    	var user_name = data["users"][user_id]?.first_name + " " + data["users"][user_id]?.last_name; 
		    	var user_email = data["users"][user_id]?.email;
		    	var condition_type = data["risk_conditions"][watchlist_instance?.risk_condition_id]?.condition_type;

	    		if (watchlist_instance?.archived) {
	    			archived_empty = 1;
	    			var html_code = `<div class="ui segment"> ${user_name}, ${user_email}, ${condition_type}, ${instance_id}, ${watchlist_instance?.status} </div>`;
	    			$('#archived_tab').append(html_code);

	    		} else {
	    			var html_code = `<div class="ui segment"> ${user_name}, ${user_email}, ${condition_type}, ${instance_id}</div>`;
		    		switch(watchlist_instance?.status){
		    			case "new":
		    				new_empty = 1;
		    				$('#new_tab').append(html_code);
							break;
						case "contacted":
							contacted_empty = 1;
							$('#contacted_tab').append(html_code);
							break;
						case "resolved":
							resolved_empty = 1;
							$('#resolved_tab').append(html_code);
							break;
						default:
							console.error(watchlist_instance?.status + " is not valid");
							return;
		    		}
		    	}
	    	})
	    	// show empty messages
	    	if (!new_empty){
	    		html_empty_message = get_html_empty_message("There are no new students at risk");
	    		$('#new_tab').html(html_empty_message);
	    		$('.top-bar').hide();
	    	} 
	    	else {
	    		$('.top-bar').show();
	    	}
	    	if (!contacted_empty){
	    		html_empty_message = get_html_empty_message("You have not contacted any students");
	    		$('#contacted_tab').html(html_empty_message);
	    	}
	    	if (!resolved_empty){
	    		html_empty_message = get_html_empty_message("You have not resolved any students");
	    		$('#resolved_tab').html(html_empty_message);
	    	}
	    	if (!archived_empty){
	    		html_empty_message = get_html_empty_message("You have not archived any students ");
	    		$('#archived_tab').html(html_empty_message);
	    	}
	    }
	});

}

// TODO: obtain correct instance_id to update watchlist instance
$('#contact_button').click(function(){
	method = "contact";
	ids = []
	update_watchlist(method, ids);
})

$('#resolve_button').click(function(){
	method = "resolve";
	ids = []
	update_watchlist(method, ids);
})

function update_watchlist(method, ids){
	let students_selected = {};
	students_selected['method'] = method;
	students_selected['ids'] = ids;

	$.ajax({
		url:watchlist_endpoints['update'],
		dataType: "json",
		contentType:'application/json',
		data: JSON.stringify(students_selected),
		type: "POST",
		success:function(data){
			refresh_watchlist();
		},
		error:function(result, type){
			render_banner({
				type:"negative",
				header:"Currently unable to " + method + " students",
				message: "Do try again later",
				timeout: -1
			});
		},
		complete:function(){
		}
	});
}

// instructor clicks on 'refresh' button
$('#refresh_btn').click(function(){
	refresh_watchlist();
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
		},params['timeout']?? 5000);
	}

	message_count++;
}
