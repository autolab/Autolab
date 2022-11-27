// Loads all Semantic javascripts
//= require semantic-ui

// metrics api endpoints
const metrics_config_endpoints = {
	get: 'get_watchlist_configuration',
	update: 'update_watchlist_configuration',
}

// prevents enumerator from being changed
Object.freeze(metrics_config_endpoints);

$(document).ready(function(){
	// initial allow_ca checkbox
	$('#allow_ca').checkbox({
		onChange: function(){
			$('#save_configs_btn').removeClass('disabled');
		}
	});
});

$.getJSON(metrics_config_endpoints['get'],function(data, status){
		excluded_categories = [];

		$('#allow_ca').checkbox(data['allow_ca'] ? 'check' : 'uncheck');

		if (status=='success') {
			data['category_blocklist'].forEach(category => {
				excluded_categories.push(category);
				$(`[id='excluded_${category}']`).css('visibility', 'visible');
			});

			$('#included_categories').children("div").each(function () {
				// category is not in blocklist
				if(excluded_categories.indexOf($(this).text()) < 0) {
					$(this).css('visibility', 'visible');
				}
			});
		}
});

$('.exchange.icon').click(function(){
	var category = $(this).attr("data-value");
	var included_category = $(`[id='included_${category}']`);
	var excluded_category = $(`[id='excluded_${category}']`);
	if(included_category.css('visibility') == 'hidden') {
		included_category.css('visibility', 'visible');
		excluded_category.css('visibility', 'hidden');
	} else {
		included_category.css('visibility', 'hidden');
		excluded_category.css('visibility', 'visible');
	}
	$('#save_configs_btn').removeClass('disabled');
});

$('#save_configs_btn').click(function(){
	let new_data = {};
	let new_blocklist = {"category": [], "assessment": []};
	let new_allow_ca = $('#allow_ca').checkbox('is checked');

	$('#excluded_categories').children("div").each(function () {
		if($(this).css('visibility') == 'visible') {
			new_blocklist["category"].push($(this).text());
		}
	});

	new_data["blocklist"] = new_blocklist;
	new_data["allow_ca"] = new_allow_ca;

	$("#save_configs_btn").addClass('loading');
	$.ajax({
		url:metrics_config_endpoints['update'],
		dataType: "json",
		contentType:'application/json',
		data: JSON.stringify(new_data),
		type: "POST",
		success:function(data){
			render_banner({
				type:"positive",
				header:"You have successfully saved your configuration",
				message:"Your watchlist should reflect your new student metrics",
			});
			get_watchlist_function();
		},
		error:function(result, type){
			render_banner({
				type:"negative",
				header:"Currently unable to update your configuration",
				message: "Please try again later",
				timeout: -1
			});
		},
		complete:function(){
			$('#save_configs_btn').addClass('disabled');
			$('#save_configs_btn').removeClass('loading');
		}
	});
})
