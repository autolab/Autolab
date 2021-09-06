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

function get_name_email_html(name, email) {
  return `
      <div class="ui checkbox select_single">
        <input type="checkbox"/>
        <label>
          <p class="name_label"> ${name} </p>
          <p class="email_label"> ${email} </p>
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
          if(vals){
            vals.forEach(dict => {
              $.each(dict, function( lab, val ) {
                inner_list.push(`${lab}: ${val}`);
              });
            });
          }
          violation_list.push(`${assessmentType} - ${inner_list.join(" | ")}`);
        });
        violation_string = violation_list.join(" <br /><br /> ");
        break;
      case "low_grades":
        condition_string = `${Object.keys(violations || {}).length} low score`;
        var violation_list = [];
        $.each(violations, function( lab, val ) {
          violation_list.push(`${lab}: ${val}`);
        });
        violation_string = violation_list.join(" | ");
        break;
      case "no_submissions":
        condition_string = `${Object.keys(_.get(violations,'no_submissions_asmt_names',{})).length} no submission`;
        var violation_list = [];
        _.get(violations,'no_submissions_asmt_names',[]).forEach(val => {
          violation_list.push(val);
        });
        violation_string = violation_list.join(" | ");
        break;
      case "grace_day_usage":
        var num_grace_days_used = 0;
        var violation_list = [];
        $.each(violations, function( lab, val ) {
          violation_list.push(`${lab}: ${val}`);
          num_grace_days_used += val;
        });
        condition_string = `${num_grace_days_used} grace days used`;
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
    case "pending":
      return `
        <div class="students-buttons-right"> 
          ${archived_icon}
          <button class="ui submit tiny button contact_single"><i class="mail outline icon"></i>CONTACT</button>
          <button class="ui submit tiny button resolve_single"><i class="check circle icon"></i>RESOLVE</button>
        </div>`;
    case "contacted":
      return `
        <div class="students-buttons-right"> 
          ${archived_icon}
          <button class="ui submit tiny button resolve_single"><i class="check circle icon"></i>RESOLVE</button>
        </div>`;
    case "resolved":
      return `
        <div class="students-buttons-right"> 
          ${archived_icon}
        </div>`;
    case "archived":
      return `
        <div class="students-buttons-right"> 
          <div class="ui circular label condition" data-variation="wide">
          ${archived_instances[user_id]["status"]}
          </div>
        </div>`;
    default:
      console.log(`${tab} is not a valid tab`);
      return;
  }
}

function get_row_html(user_id, instance, tab, archived_instances) {
  var name = instance["name"];
  var email = instance["email"];
  var condition_types = instance["conditions"];
  var course_id = instance["course_id"];

  var name_email_html = get_name_email_html(name, email);
  var gradebook_link_html = get_gradebook_link_html(course_id, user_id);
  var conditions_html = get_condition_html(condition_types);
  var buttons_html = get_buttons_html(user_id, tab, archived_instances);
  return `
      <div class="ui segment" id=${user_id}>
        ${name_email_html}
        ${gradebook_link_html}
        ${conditions_html}
        ${buttons_html}
      </div>`;
}

function addInstanceToDict(instancesDict, id, user_id, course_id, user_name, user_email, condition_type, violation_info, watchlist_status) {
  if (user_id in instancesDict) {
    instancesDict[user_id]["conditions"][condition_type] = violation_info;
    instancesDict[user_id]["instance_ids"].push(id);
    instancesDict[user_id]["status"] = watchlist_status;
  } else {
    instancesDict[user_id] = {
      "name": user_name, 
      "email": user_email,
      "course_id": course_id,
      "conditions": {},
      "instance_ids": [id],
      "status": watchlist_status
    };
    instancesDict[user_id]["conditions"][condition_type] = violation_info;
  }
}

function get_watchlist_function(){

  var pending_instances = {}
  var contacted_instances = {}
  var resolved_instances = {}
  var archived_instances = {}

  var selected_user_ids = []

	$.getJSON(watchlist_endpoints['get'],function(data, status){
	    if (status=='success') {
	    	var pending_empty = 1;
	    	var contacted_empty = 1;
	    	var resolved_empty = 1;
        var archived_empty = 1;
        let last_updated_date = "";

        $(".top-bar").show();
	    	$("#undefined_metrics").hide();
        $("#defined_metrics").show();

	    	$('#pending_tab').empty();
	    	$('#contacted_tab').empty();
	    	$('#resolved_tab').empty();
        $('#archived_tab').empty();

        data["instances"].forEach(watchlist_instance => {
          var id = _.get(watchlist_instance,'id');
          var course_id = _.get(watchlist_instance,'course_id');
          var user_id = _.get(watchlist_instance,'course_user_datum_id');
          var user_name = _.get(data,`["users"][${user_id}].first_name`) + " " + _.get(data,`["users"][${user_id}].last_name`); 
          var user_email = _.get(data,`["users"][${user_id}].email`);
          var risk_condition_id = _.get(watchlist_instance,'risk_condition_id');
          var watchlist_status = _.get(watchlist_instance,'status');
          var condition_type = _.get(data,`["risk_conditions"][${risk_condition_id}].condition_type`);
          var violation_info = _.get(watchlist_instance,'violation_info');

          if(watchlist_instance.updated_at > last_updated_date)
            last_updated_date = watchlist_instance.updated_at;

          if (_.get(watchlist_instance,'archived')) {
            archived_empty = 0;
            addInstanceToDict(archived_instances, id, user_id, course_id, user_name, user_email, condition_type, violation_info, watchlist_status);
          } else {
            switch(watchlist_status){
              case "pending":
                pending_empty = 0;
                addInstanceToDict(pending_instances, id, user_id, course_id, user_name, user_email, condition_type, violation_info, watchlist_status);
                break;
              case "contacted":
                contacted_empty = 0;
                addInstanceToDict(contacted_instances, id, user_id, course_id, user_name, user_email, condition_type, violation_info, watchlist_status);
                break;
              case "resolved":
                resolved_empty = 0;
                addInstanceToDict(resolved_instances, id, user_id, course_id, user_name, user_email, condition_type, violation_info, watchlist_status);
                break;
              default:
                console.error(_.get(watchlist_instance,'status') + " is not valid");
                return;
            }
          }
        });
        
        pending_html = `<div class="ui secondary segment" >
                     <h5> Pending students in need of attention</h5>
                    </div>`;
        contacted_html = `<div class="ui secondary segment" >
                          <h5> Contacted students </h5>
                        </div>`;
        resolved_html = `<div class="ui secondary segment" >
                          <h5> Resolved students </h5>
                        </div>`;
        archived_html = `<div class="ui secondary segment" >
                          <h5> Archived students </h5> <b>Resolved and contacted students becomes archived when student metrics are changed </b>
                         </div>`;

	    	$.each(pending_instances, function( user_id, instance ) {
          pending_html += get_row_html(user_id, instance, "pending", archived_instances);
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
	    	if (pending_empty){
	    		html_empty_message = get_html_empty_message("There are no pending students in need of attention");
	    		$('#pending_tab').html(html_empty_message);
	    	} else {
          $('#pending_tab').html(pending_html);
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
	    		html_empty_message = get_html_empty_message("You have no archived students");
	    		$('#archived_tab').html(html_empty_message);
	    	} else {
          $('#archived_tab').html(archived_html);
        }
        
        updateButtonVisibility($('.ui.vertical.fluid.tabular.menu .item.active'));
        
        // displays latest updated time based on item with latest time
        if(last_updated_date != "")
          $('#last-updated-time')
          .text(`Last Updated ${(new Date(last_updated_date)).toLocaleString()}`);

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

        // disable all action buttons
        var button_group = $(this).parent().find('button');
        button_group.prop('disabled', true);

        method = "contact";
        var user_id = $(this).parent().parent().attr('id');
        window.open(`mailto: ${pending_instances[user_id]["email"]}`, "_blank");
        console.log(pending_instances[user_id]["instance_ids"]);
        
        // re-enabling buttons on failure
        function enable_buttons () {
          button_group.removeAttr("disabled");
        } 

        update_watchlist(method, pending_instances[user_id]["instance_ids"], enable_buttons);
      });

      $('.ui.button.resolve_single').click(function() {

        // disable all action buttons
        var button_group = $(this).parent().find('button');
        button_group.prop('disabled', true);
        
        method = "resolve";
        var user_id = $(this).parent().parent().attr('id');
        var instances = get_active_instances(pending_instances, contacted_instances, archived_instances);
        
        // re-enabling buttons on failure
        function enable_buttons () {
          button_group.removeAttr("disabled");
        } 

        update_watchlist(method, instances[user_id]["instance_ids"], enable_buttons);
      });
  });

  // Removes previous click function binded to contact button
  $('#contact_button').off('click');
  $('#contact_button').click(function(){
    method = "contact";

    var emails = [];
    selected_user_ids.forEach(user_id => {
      emails.push(pending_instances[user_id]["email"]);
    });

    var instance_ids = [];
    selected_user_ids.forEach(user_id => {
      instance_ids = instance_ids.concat(pending_instances[user_id]["instance_ids"]);
    });
  
    if (instance_ids.length > 1) {
      window.open(`mailto: ?bcc=${emails}`, "_blank");
      update_watchlist(method, instance_ids);
    } else if (instance_ids.length > 0) {
      window.open(`mailto: ${emails}`, "_blank");
      update_watchlist(method, instance_ids);
    }
  });

  // Removes previous click function binded to resolve button
  $('#resolve_button').off('click');
  $('#resolve_button').click(function(){
    method = "resolve";
    var instances = get_active_instances(pending_instances, contacted_instances, archived_instances);

    var instance_ids = [];
    selected_user_ids.forEach(user_id => {
      instance_ids = instance_ids.concat(instances[user_id]["instance_ids"]);
    });

    if (instance_ids.length > 0) {
      update_watchlist(method, instance_ids);
    }
  });

   // Removes previous click function binded to delete button
  $('#delete_button').off('click');
  $('#delete_button').click(function(){
    method = "delete";
    var instances = get_active_instances(pending_instances, contacted_instances, archived_instances);

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
  updateButtonVisibility(this);
});

function updateButtonVisibility(item){
  // Deleting instances only avilable in archive tab
  $("#delete_button").hide();
  switch ($(item).attr("data-tab")) {
    case "pending_tab":
      if ($("#pending_tab #empty_tabs").length > 0) {
        $("#contact_button").addClass("disabled");
        $("#resolve_button").addClass("disabled");
      } else {
        $("#contact_button").removeClass("disabled");
        $("#resolve_button").removeClass("disabled");
      }
      break;
    case "contacted_tab":
      $("#contact_button").addClass("disabled");
      if ($("#contacted_tab #empty_tabs").length > 0) {
        $("#resolve_button").addClass("disabled");
      } else {
        $("#resolve_button").removeClass("disabled");
      }
      break;
    case "resolved_tab":
      $("#contact_button").addClass("disabled");
      $("#resolve_button").addClass("disabled");
      break;
    case "archived_tab":
      $("#contact_button").addClass("disabled");
      $("#resolve_button").addClass("disabled");
      $("#delete_button").show();
      break;
    default:
      console.log(`${$(this).attr("data-tab")} is not a valid tab`);
      return;
  }
}

function get_active_instances(pending_instances, contacted_instances, archived_instances) {
  var tab = $(".ui.tab.segments.active").attr('id');
  
  switch(tab){
    case "pending_tab":
      return pending_instances;
    case "contacted_tab":
      return contacted_instances;
    case "archived_tab":
      return archived_instances;
    default:
      console.log(`${tab} is not a valid tab for this action`)
      return;
  }
}

function update_watchlist(method, ids, on_error = null){
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

      // call on_error if exists
      if(on_error!=null){ 
        on_error();
      }
		},
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
    
    // set last updated time to now on success
    $('#last-updated-time')
    .text(`Last Updated ${(new Date()).toLocaleString()}`);

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

