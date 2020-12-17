// Loads all Semantic javascripts
//= require semantic-ui

// watchlist api endpoints
const watchlist_endpoints = {
	update: 'update_watchlist_instances',
	refresh: 'refresh_watchlist_instances',
	get: 'get_watchlist_instances'
}

function get_html_empty_message(message){
	return `
    	<div id="empty_tabs">
            <center>
              <i class="huge inbox icon"></i> 
              <h3> ${message} </h3>
            </center>
      </div>`;
}

function get_name_html(name) {
  return `
      <div class="ui checkbox select_single">
        <input type="checkbox"/>
        <label>
          <p class="name_label"> ${name} </p>
        </label>
      </div>`;
}

function get_gradebook_link_html(course_id, user_id) {
  return `
      <a href="../course_user_data/${course_id}/gradebook/student?id=${user_id}" title="Gradebook" target="_blank">
        <i class="external alternate icon"></i>
      </a>`
}

function get_condition_html(condition_types) {
  var conditions_html = "";
  $.each(condition_types, function( condition, violations ) {
    var condition_string = "";
    var violation_string = "";
    switch(condition){
      case "grade_drop":
        condition_string = "downward trend";
        var violation_list = [];
        $.each(violations, function( assessmentType, vals ) {
          var inner_list = []
          vals?.forEach(dict => {
            $.each(dict, function( lab, val ) {
              inner_list.push(`${lab}: ${val}`);
            });
          });
          violation_list.push(`${assessmentType} - ${inner_list.join(" | ")}`);
        });
        violation_string = violation_list.join(" <br /><br /> ");
        break;
      case "low_grades":
        condition_string = `${Object.keys(violations ?? {})?.length} low score`;
        var violation_list = [];
        $.each(violations, function( lab, val ) {
          violation_list.push(`${lab}: ${val}`);
        });
        violation_string = violation_list.join(" | ");
        break;
      case "no_submissions":
        condition_string = `${Object.keys(violations?.no_submissions_asmt_names ?? {})?.length} no submission`;
        var violation_list = [];
        violations?.no_submissions_asmt_names?.forEach(val => {
          violation_list.push(val);
        });
        violation_string = violation_list.join(" | ");
        break;
      case "grace_day_usage":
        condition_string = `${Object.keys(violations ?? {})?.length} grace days used`;
        var violation_list = [];
        $.each(violations, function( lab, val ) {
          violation_list.push(`${lab}: ${val}`);
        });
        violation_string = violation_list.join(" | ");
        break;
      default:
        console.log(`${condition} is not valid`);
        return;
    }
    conditions_html += `
        <div class="ui circular label condition" data-html="${violation_string}" data-variation="wide"> 
          ${condition_string}
        </div>`
  });
  return conditions_html;
}

function get_buttons_html(user_id, tab, archived_instances) {
  var archived_icon = (user_id in archived_instances) ? 
      `<div class="left ui icon" data-content="Student also appears in archived">
        <i class="exclamation circle icon"></i>
      </div>` : "";

  switch(tab) {
    case "new":
      return `
        <div class="students-buttons-right"> 
          ${archived_icon}
          <button class="ui submit tiny button contact_single"><i class="mail outline icon"></i>CONTACT</button>
          <button class="ui submit tiny button resolve_single"><i class="check circle icon"></i>RESOLVE</button>
        </div>`
    case "contacted":
      return `
        <div class="students-buttons-right"> 
          ${archived_icon}
          <button class="ui submit tiny button resolve_single"><i class="check circle icon"></i>RESOLVE</button>
        </div>`
    case "resolved":
      return `
        <div class="students-buttons-right"> 
          ${archived_icon}
        </div>`
    case "archived":
      return "";
    default:
      console.log(`${tab} is not a valid tab`);
      return;
  }
}

function get_row_html(user_id, instance, tab, archived_instances) {
  var name = instance["name"];
  var condition_types = instance["conditions"];
  var course_id = instance["course_id"];

  var name_html = get_name_html(name);
  var gradebook_link_html = get_gradebook_link_html(course_id, user_id);
  var conditions_html = get_condition_html(condition_types);
  var buttons_html = get_buttons_html(user_id, tab, archived_instances);
  return `
      <div class="ui segment" id=${user_id}>
        ${name_html}
        ${gradebook_link_html}
        ${conditions_html}
        ${buttons_html}
      </div>`;
}

function addInstanceToDict(instancesDict, id, user_id, course_id, user_name, user_email, condition_type, violation_info) {
  if (user_id in instancesDict) {
    instancesDict[user_id]["conditions"][condition_type] = violation_info;
    instancesDict[user_id]["instance_ids"].push(id);
  } else {
    instancesDict[user_id] = {
      "name": user_name, 
      "email": user_email,
      "course_id": course_id,
      "conditions": {},
      "instance_ids": [id]
    };
    instancesDict[user_id]["conditions"][condition_type] = violation_info;
  }
}

function get_watchlist_function(){
  var new_instances = {}
  var contacted_instances = {}
  var resolved_instances = {}
  var archived_instances = {}

  var selected_user_ids = []

	$.getJSON(watchlist_endpoints['get'],function(data, status){
	    if(status=='success') {
	    	var new_empty = 1;
	    	var contacted_empty = 1;
	    	var resolved_empty = 1;
        var archived_empty = 1;
        let last_updated_date = "";

        $(".top-bar").show();
	    	$("#undefined_metrics").hide();
        $("#defined_metrics").show();

	    	$('#new_tab').empty();
	    	$('#contacted_tab').empty();
	    	$('#resolved_tab').empty();
        $('#archived_tab').empty();

        data["instances"].forEach(watchlist_instance => {
          var id = watchlist_instance?.id;
          var course_id = watchlist_instance?.course_id;
          var user_id = watchlist_instance?.course_user_datum_id;
		    	var user_name = data["users"][user_id]?.first_name + " " + data["users"][user_id]?.last_name; 
          var user_email = data["users"][user_id]?.email;
          var condition_type = data["risk_conditions"][watchlist_instance?.risk_condition_id]?.condition_type;
          var violation_info = watchlist_instance?.violation_info;
          
          if(watchlist_instance.updated_at > last_updated_date)
            last_updated_date = watchlist_instance.updated_at;

          if (watchlist_instance?.archived) {
            archived_empty = 0;
            addInstanceToDict(archived_instances, id, user_id, course_id, user_name, user_email, condition_type, violation_info);
          }
          switch(watchlist_instance?.status){
            case "new":
              new_empty = 0;
              addInstanceToDict(new_instances, id, user_id, course_id, user_name, user_email, condition_type, violation_info);
              break;
            case "contacted":
              contacted_empty = 0;
              addInstanceToDict(contacted_instances, id, user_id, course_id, user_name, user_email, condition_type, violation_info);
              break;
            case "resolved":
              resolved_empty = 0;
              addInstanceToDict(resolved_instances, id, user_id, course_id, user_name, user_email, condition_type, violation_info);
              break;
            default:
              console.error(watchlist_instance?.status + " is not valid");
              return;
          }
        });

        new_html = "";
        contacted_html = "";
        resolved_html = "";
        archived_html = "";

	    	$.each(new_instances, function( user_id, instance ) {
          new_html += get_row_html(user_id, instance, "new", archived_instances);
        });
        $.each(contacted_instances, function( user_id, instance ) {
          contacted_html += get_row_html(user_id, instance, "contacted", archived_instances);
        });
        $.each(resolved_instances, function( user_id, instance ) {
          resolved_html += get_row_html(user_id, instance, "resolved", archived_instances);
        });
        $.each(archived_instances, function( user_id, instance ) {
          archived_html += get_row_html(user_id, instance, "archived", archived_instances);
        });
        

	    	// show empty messages
	    	if (new_empty){
	    		html_empty_message = get_html_empty_message("There are no new students at risk");
	    		$('#new_tab').html(html_empty_message);
	    	} else {
          $('#new_tab').html(new_html);
        }
	    	if (contacted_empty){
	    		html_empty_message = get_html_empty_message("You have not contacted any students");
	    		$('#contacted_tab').html(html_empty_message);
	    	} else {
          $('#contacted_tab').html(contacted_html);
        }
	    	if (resolved_empty){
	    		html_empty_message = get_html_empty_message("You have not resolved any students");
	    		$('#resolved_tab').html(html_empty_message);
	    	} else {
          $('#resolved_tab').html(resolved_html);
        }
	    	if (archived_empty){
	    		html_empty_message = get_html_empty_message("You have not archived any students ");
	    		$('#archived_tab').html(html_empty_message);
	    	} else {
          $('#archived_tab').html(archived_html);
        }

        // displays last refreshed time in local time zone
        $('#last-updated-time').text(`Last Updated ${(new Date(last_updated_date)).toLocaleString()}`);

      } else {
        render_banner({
          type:"negative",
          header:"Currently unable to load students",
          message: "Do try again later",
          timeout: -1
        });
      }

      $('.ui.checkbox.select_single').checkbox({
        onChecked: function () { 
          selected_user_ids.push($(this).parent().parent().attr('id'));
        },
        onUnchecked: function () { 
          var user_id = $(this).parent().parent().attr('id');
          var index = selected_user_ids.indexOf(user_id);
          if (index > -1) {
            selected_user_ids.splice(index, 1);
          } else {
            console.log(`User #${user_id} was never checked`)
          }
        }
      });

      $('.ui.icon').popup();
      $('.ui.circular.label.condition').popup();

      $('.ui.button.contact_single').click(function() {
        method = "contact";
        var user_id = $(this).parent().parent().attr('id');

        window.open(`mailto: ${new_instances[user_id]["email"]}`, "_blank");
        console.log(new_instances[user_id]["instance_ids"]);
        update_watchlist(method, new_instances[user_id]["instance_ids"]);
      })

      $('.ui.button.resolve_single').click(function() {
        method = "resolve";
        var user_id = $(this).parent().parent().attr('id');
        var instances = get_active_instances(new_instances, contacted_instances);
        update_watchlist(method, instances[user_id]["instance_ids"]);
      })
  });

  $('#contact_button').click(function(){
    method = "contact";

    var emails = [];
    selected_user_ids.forEach(user_id => {
      emails.push(new_instances[user_id]["email"]);
    });

    var instance_ids = [];
    selected_user_ids.forEach(user_id => {
      instance_ids = instance_ids.concat(new_instances[user_id]["instance_ids"]);
    });
  
    if (instance_ids.length > 0) {
      window.open(`mailto: ${emails}`, "_blank");
      update_watchlist(method, instance_ids);
    }
  });

  $('#resolve_button').click(function(){
    method = "resolve";
    var instances = get_active_instances(new_instances, contacted_instances);

    var instance_ids = [];
    selected_user_ids.forEach(user_id => {
      instance_ids = instance_ids.concat(instances[user_id]["instance_ids"]);
    });

    if (instance_ids.length > 0) {
      update_watchlist(method, instance_ids);
    }
  });
}

// Uncheck all checkboxes when moving to another tab
$('.ui.vertical.fluid.tabular.menu .item').on('click', function() {
  $('.ui.tab.segments.active .ui.checkbox').checkbox('uncheck');
  $('.ui.checkbox.select_all').checkbox('uncheck');
  $('.ui.vertical.fluid.tabular.menu .item').removeClass('active');
  $(this).addClass('active');

  switch ($(this).attr("data-tab")) {
    case "new_tab":
      $("#contact_button").removeClass("disabled");
      $("#resolve_button").removeClass("disabled");
      break;
    case "contacted_tab":
      $("#contact_button").addClass("disabled");
      $("#resolve_button").removeClass("disabled");
      break;
    case "resolved_tab":
      $("#contact_button").addClass("disabled");
      $("#resolve_button").addClass("disabled");
      break;
    case "archived_tab":
      $("#contact_button").addClass("disabled");
      $("#resolve_button").addClass("disabled");
      break;
    default:
      console.log(`${$(this).attr("data-tab")} is not a valid tab`);
      return;
  }
});

function get_active_instances(new_instances, contacted_instances) {
  var tab = $(".ui.tab.segments.active").attr('id');
  
  switch(tab){
    case "new_tab":
      return new_instances;
    case "contacted_tab":
      return contacted_instances;
    default:
      console.log(`${tab} is not a valid tab for this action`)
      return;
  }
}

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
			get_watchlist_function();
		},
		error:function(result, type){
			render_banner({
				type:"negative",
				header:"Currently unable to " + method + " students",
				message: "Do try again later",
				timeout: -1
			});
		}
	});
}

// instructor clicks on 'refresh' button
// only activates if it is not already loading
$('#refresh_btn').click(function(){
  
  if(!$('#refresh_btn').hasClass("loading"))
	  refresh_watchlist();
});

function refresh_watchlist(){

  // uses formantic ui loading class 
  $("#refresh_btn").addClass('loading');
  $.getJSON(watchlist_endpoints['refresh'],function(){
    get_watchlist_function();
    render_banner({
      type:"positive",
      header:"Successfully refreshed watchlist instances",
      message: "The latest instances should be showing now",
    });
  }).fail(function(){
    render_banner({
      type:"negative",
      header:"Currently unable to refresh students",
      message: "Do try again later",
      timeout: -1
    });
  })
  .always(function(){
    $("#refresh_btn").removeClass('loading');
  })

}

