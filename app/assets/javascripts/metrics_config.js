// Loads all Semantic javascripts
//= require semantic-ui

// metrics api endpoints
const metrics_config_endpoints = {
	get_category: 'get_watchlist_category_blocklist',
	update: 'update_watchlist_configuration',
}

// prevents enumerator from being changed
Object.freeze(metrics_config_endpoints);

$.getJSON(metrics_config_endpoints['get_category'],function(data, status){
		excluded_categories = [];

		if (status=='success') {
			data.forEach(category => {
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
	var new_blocklist = {"blocklist": {"category": [], "assessment": []}};

	$('#excluded_categories').children("div").each(function () {
		if($(this).css('visibility') == 'visible') {
			new_blocklist["blocklist"]["category"].push($(this).text());
		}
	});

	$("#save_configs_btn").addClass('loading');
	$.ajax({
		url:metrics_config_endpoints['update'],
		dataType: "json",
		contentType:'application/json',
		data: JSON.stringify(new_blocklist),
		type: "POST",
		success:function(data){
			render_banner({
				type:"positive",
				header:"You have successfully saved your included categories",
				message:"Your watchlist should reflect your new student metrics",
			});
			get_watchlist_function();
		},
		error:function(result, type){
			render_banner({
				type:"negative",
				header:"Currently unable to update included categories",
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
