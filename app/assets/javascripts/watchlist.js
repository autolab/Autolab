// Loads all Semantic javascripts
//= require semantic-ui

const escapeHtml = (unsafe) => {
  return unsafe.replaceAll('&', '&amp;')
               .replaceAll('<', '&lt;')
               .replaceAll('>', '&gt;')
               .replaceAll('"', '&quot;')
               .replaceAll("'", '&#039;');
}

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

function get_name_email_html(name, email, tab) {
  // janky way of conditionally rendering checkbox
  // display: none doesn't work and adding a parent div to
  // checkbox is difficult
  checkbox = tab !== "resolved" ?  `<input type="checkbox"/>` : ``;
  checkboxclass = tab !== "resolved" ? "checkbox" : ""
  return `
        <div class="ui select_single ${checkboxclass}">
          ${checkbox}
          <label>
            <p class="name_label"> ${escapeHtml(name)} </p>
            <p class="email_label"> ${escapeHtml(email)} </p>
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
      case "extension_requests":
        var extension_count = 0;
        var violation_list = [];
        $.each(violations, function( lab, val ) {
          violation_list.push(`${lab}: ${val}`);
          extension_count += val;
        });
        condition_string = `${extension_count} extension requests made`;
        violation_string = violation_list.join(" | ");
        break;
      default:
        console.log(`${condition} is not valid`);
        return;
    }
    conditions_html += `
        <div class="ui circular label condition gray black-text" data-html="${violation_string}" data-variation="wide"> 
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

  var name_email_html = get_name_email_html(name, email, tab);
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

function set_tab_html(is_search, instances, tab_name, archived_instances, empty_message, selected_user_ids) {
  is_empty = Object.keys(instances).length === 0;
  if (is_empty && !is_search){
    $(`#${tab_name}_header`).hide();
    html_empty_message = get_html_empty_message(empty_message);
    $(`#${tab_name}_tab`).html(html_empty_message);
  } else {
    $(`#${tab_name}_header`).show();
    html = "";
    $.each(instances, function( user_id, instance ) {
      html += get_row_html(user_id, instance, tab_name, archived_instances);
    });
    $(`#${tab_name}_instances`).html(html);
  }

  $('.ui.icon').popup();
  $('.ui.circular.label.condition').popup();

  $('.ui.checkbox.select_single.checkbox').checkbox({
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

  // contact single watchlist student associated with student
  if (tab_name === "pending") {
    $('.ui.button.contact_single').click(function() {

      // disable all action buttons
      var button_group = $(this).parent().find('button');
      button_group.prop('disabled', true);
  
      method = "contact";
      var user_id = $(this).parent().parent().attr('id');
      window.open(`mailto: ${instances[user_id]["email"]}`, "_blank");
      
      // re-enabling buttons on failure
      function enable_buttons () {
        button_group.removeAttr("disabled");
      } 
  
      update_watchlist(method, instances[user_id]["instance_ids"], enable_buttons);
    });
  }

  // resolve for single watchlist student
  $('.ui.button.resolve_single').click(function() {

    // disable all action buttons associated with student
    var button_group = $(this).parent().find('button');
    button_group.prop('disabled', true);
    
    method = "resolve";
    var user_id = $(this).parent().parent().attr('id');
    
    // re-enabling buttons on failure
    function enable_buttons () {
      button_group.removeAttr("disabled");
    } 
    console.log(user_id)
    console.log(instances)
    update_watchlist(method, instances[user_id]["instance_ids"], enable_buttons);
  });
}

function set_search_action(instances, tab_name, archived_instances, empty_message, search_content, selected_user_ids) {
  $(`#${tab_name}_search`).search({
    type: 'category',
    source: search_content,
    maxResults: 100,
    onSearchQuery: function(query) {
      search_enter_action(query, tab_name, instances, archived_instances, empty_message, selected_user_ids);
    },
    onSelect: function(result, _) {
      search_enter_action(result["title"], "pending", instances, archived_instances, empty_message, selected_user_ids);
    },
    onResultsClose: function() {
      query = $(`#${tab_name}_search .input .prompt`).val().toLowerCase().trim();
      search_enter_action(query, tab_name, instances, archived_instances, empty_message, selected_user_ids);
    }
  });
}

function add_instance_to_dict(
  {
    search_content, 
    instances_dict, 
    id, 
    user_id, 
    course_id, 
    user_name, 
    user_email, 
    condition_type, 
    violation_info, 
    watchlist_status
  }
) {
  if (user_id in instances_dict) {
    instances_dict[user_id]["conditions"][condition_type] = violation_info;
    instances_dict[user_id]["instance_ids"].push(id);
    instances_dict[user_id]["status"] = watchlist_status;
  } else {
    instances_dict[user_id] = {
      "name": user_name, 
      "email": user_email,
      "course_id": course_id,
      "conditions": {},
      "instance_ids": [id],
      "status": watchlist_status
    };
    instances_dict[user_id]["conditions"][condition_type] = violation_info;
    search_content.push({category: "email", title: user_email});
    search_content.push({category: "name", title: user_name});
  }
}

function instance_passes_condition_search(instance, search_input) {
  var convert_conditions = {
    "grace day used": "grace_day_usage", 
    "downward trend": "grade_drop", 
    "no submission": "no_submissions", 
    "low score": "low_grades"};
  var violated_conditions = Object.keys(instance["conditions"]);
  return violated_conditions.includes(convert_conditions[search_input]);
}

function search_enter_action(query, tab_name, instances, archived_instances, empty_message, selected_user_ids) {
  var search_input = query.toLowerCase().trim();
  if (search_input === "") {
    set_tab_html(
      true,
      instances,
      tab_name,
      archived_instances,
      empty_message,
      selected_user_ids,
    );
  }
  var filtered_instances = Object.keys(instances).reduce(function (filtered, key) {
    if (instances[key]["name"]?.toLowerCase()?.includes(search_input)
      || instances[key]["email"]?.toLowerCase()?.includes(search_input)
      || instance_passes_condition_search(instances[key], search_input)) {
      filtered[key] = instances[key];
    } 
    return filtered;
  }, {});
  set_tab_html(
    true,
    filtered_instances,
    tab_name,
    archived_instances,
    empty_message,
    selected_user_ids,
  );
}

function get_watchlist_function(){

  var pending_instances = {}
  var contacted_instances = {}
  var resolved_instances = {}
  var archived_instances = {}

  var selected_user_ids = []

	$.getJSON(watchlist_endpoints['get'],function(data, status){
	    if (status=='success') {
        let last_updated_date = "";

        $(".top-bar").show();
	    	$("#undefined_metrics").hide();
        $("#defined_metrics").show();

	    	$('#pending_instances').empty();
	    	$('#contacted_instances').empty();
	    	$('#resolved_instances').empty();
        $('#archived_instances').empty();

        var metrics_search_content = [
          {category: "metric", title: "grace day used"},
          {category: "metric", title: "downward trend"},
          {category: "metric", title: "no submission"},
          {category: "metric", title: "low score"},
        ]
        var pending_search_content = [...metrics_search_content];
        var contacted_search_content = [...metrics_search_content];
        var resolved_search_content = [...metrics_search_content];
        var archived_search_content = [...metrics_search_content];
        var status_search_content = {
          "archived": archived_search_content,
          "pending": pending_search_content,
          "contacted": contacted_search_content,
          "resolved": resolved_search_content,
        }
        var status_instances = {
          "archived": archived_instances,
          "pending": pending_instances,
          "contacted": contacted_instances,
          "resolved": resolved_instances,
        }

        data["instances"].forEach(watchlist_instance => {
          var id = _.get(watchlist_instance,'id');
          var course_id = _.get(watchlist_instance,'course_id');
          var user_id = _.get(watchlist_instance,'course_user_datum_id');
          // https://stackoverflow.com/questions/19902860/join-strings-with-a-delimiter-only-if-strings-are-not-null-or-empty
          var user_name = [_.get(data,`["users"][${user_id}].first_name`), _.get(data,`["users"][${user_id}].last_name`)].filter(Boolean).join(' ');
          var user_email = _.get(data,`["users"][${user_id}].email`);
          var risk_condition_id = _.get(watchlist_instance,'risk_condition_id');
          var watchlist_status = _.get(watchlist_instance,'status');
          var condition_type = _.get(data,`["risk_conditions"][${risk_condition_id}].condition_type`);
          var violation_info = _.get(watchlist_instance,'violation_info');

          if(watchlist_instance.updated_at > last_updated_date)
            last_updated_date = watchlist_instance.updated_at;

          var search_content;
          var instances_dict;
          if (_.get(watchlist_instance, "archived")) {
            search_content = status_search_content["archived"];
            instances_dict = status_instances["archived"];
          } else {
            search_content = status_search_content[watchlist_status];
            instances_dict = status_instances[watchlist_status];
          }
          var instance_info = {
            search_content,
            instances_dict,
            id, 
            user_id, 
            course_id, 
            user_name, 
            user_email, 
            condition_type, 
            violation_info, 
            watchlist_status,
          };
          add_instance_to_dict(instance_info);
        });
        
        pending_empty_message = "There are no pending students in need of attention";
        contacted_empty_message = "You have not contacted any students";
        resolved_empty_message = "You have not resolved any students";
        archived_empty_message = "You have no archived students";
        status_empty_message = {
          "pending": pending_empty_message,
          "contacted": contacted_empty_message,
          "resolved": resolved_empty_message,
          "archived": archived_empty_message,
        }

        for (var status in status_instances) {
          instances_dict = status_instances[status];
          set_tab_html(
            false,
            instances_dict,
            status,
            archived_instances,
            status_empty_message[status],
            selected_user_ids,
          )
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

      set_search_action(
        pending_instances, 
        "pending", 
        archived_instances, 
        pending_empty_message, 
        pending_search_content,
        selected_user_ids,
      );
      set_search_action(
        contacted_instances, 
        "contacted", 
        archived_instances, 
        contacted_empty_message, 
        contacted_search_content,
        selected_user_ids,
      );
      set_search_action(
        resolved_instances, 
        "resolved", 
        archived_instances, 
        resolved_empty_message, 
        resolved_search_content,
        selected_user_ids,
      );
      set_search_action(
        archived_instances, 
        "archived", 
        archived_instances, 
        archived_empty_message, 
        archived_search_content,
        selected_user_ids,
      );
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

  $('#export_button').off('click');
  $('#export_button').click(function(){
    var instances = get_active_instances(pending_instances, contacted_instances, archived_instances);
    
    var selected_instances = [];
    selected_user_ids.forEach(user_id => {
      selected_instances = selected_instances.concat(instances[user_id]);
    });

    if(selected_instances.length > 0) {
      export_instances_to_csv(selected_instances);
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

// helper function to export instances to csv
function export_instances_to_csv(instances) {

  var csv = "data:text/csv;charset=utf-8,";
  var header = "User Name, Email,Condition Type, Conditiong Info\n";
  csv += header;

  instances.forEach(instance => {
    let condition_type = `"${JSON.stringify(Object.keys(instance.conditions)).replaceAll('"', '""')}"`;
    let condition_info = `"${JSON.stringify(instance["conditions"]).replaceAll('"', '""')}"`;
    csv += `${instance.name},${instance.email},${condition_type},${condition_info}\n`;
  });

  var encodedUri = encodeURI(csv);
  var link = document.createElement("a");
  link.setAttribute("href", encodedUri);
  // create file name with current date and time
  link.setAttribute("download", `student_metrics_${new Date().toLocaleString()}.csv`);
  document.body.appendChild(link); // Required for FF
  link.click(); 
  document.body.removeChild(link);

}


// helper function to configure top button visibility
function showTopButtons(selectAllCheckbox, resolveButton, contactButton, deleteButton, exportButton) {
  $("#select_all_checkbox").toggle(selectAllCheckbox);
  $("#resolve_button").toggle(resolveButton);
  $("#contact_button").toggle(contactButton);
  $("#delete_button").toggle(deleteButton);
  $('#export_button').toggle(exportButton);
}

// controls visibility for top bar actions (select all, contact, resolve, delete)
function updateButtonVisibility(item){
  // Deleting instances only avilable in archive tab
  showTopButtons(true, true, true, false, true);
  switch ($(item).attr("data-tab")) {
    case "pending_tab":
      // if no students pending
      if ($("#pending_tab #empty_tabs").length > 0) {
        showTopButtons(false, false, false, false, false);
      }
      break;
    case "contacted_tab":
      // no students to contact
      if ($("#contacted_tab #empty_tabs").length > 0) {
        showTopButtons(false, false, false, false, false);
      } else {
        // still allowed to resolve
        showTopButtons(true, true, false, false, false);
      }
      break;
    case "resolved_tab":
      // no actions allowed
      showTopButtons(false, false, false, false, false);
      break;
    case "archived_tab":
      // only delete is allowed
      showTopButtons(true, false, false, true, false);
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
  $.post(watchlist_endpoints['refresh'],function(){
    
    // set last updated time to now on success
    $('#last-updated-time')
    .text(`Last Updated ${(new Date()).toLocaleString()}`);

    get_watchlist_function();
    render_banner({
      type:"positive",
      header:"Successfully refreshed watchlist instances",
      message: "The latest instances should be showing now",
    }, "json");
    
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

