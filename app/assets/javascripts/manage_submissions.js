var hideStudent;

$(document).ready(function() {

  $.fn.dataTable.ext.search.push(
    function(settings, data, dataIndex) {
      var filterOnlyLatest = $("#only-latest").is(':checked');
      if (!filterOnlyLatest) {
        // if not filtered, return all the rows
        return true;
      } else {
        var isSubmissionLatest = data[8]; // use data for the age column
        return (isSubmissionLatest == "true");
      }
    }
  );

  var $floater = $("#floater"),
    $backdrop = $("#gradeBackdrop");
  $('.trigger').bind('ajax:success', function showStudent(event, data, status, xhr) {
    $floater.html(data);
    $floater.show();
    $backdrop.show();
  });

  /** override the global **/
  hideStudent = function hideStudent() {
    $floater.hide();
    $backdrop.hide();
  };

  var table = $('#submissions').DataTable({
    'sPaginationType': 'full_numbers',
    'iDisplayLength': 100,
    'oLanguage': {
      'sLengthMenu':'<label><input type="checkbox" id="only-latest">' +
        '<span>Show only latest</span></label>'
    },
    "columnDefs": [{
      "targets": [8],
      "visible": false,
      // "searchable": false
    }],
    "aaSorting": [
      [4, "desc"]
    ]
  });

  $("#only-latest").on("change", function() {
    table.draw();
  });

  var ids = [];
  $("input[type='checkbox']:checked").each(function() {
    ids.push($(this).val());
  });

  var selectedSubmissions = [];

  var initialBatchUrl = $("#batch-regrade").prop("href");

  function updateBatchRegradeButton() {

    if (selectedSubmissions.length == 0) {
      $("#batch-regrade").fadeOut(120);
    } else {
      $("#batch-regrade").fadeIn(120);
    }
    var urlParam = $.param({
      "submission_ids": selectedSubmissions
    });
    var newHref = initialBatchUrl + "?" + urlParam;
    $("#batch-regrade").html("Regrade " + selectedSubmissions.length + " Submissions")
    $("#batch-regrade").prop("href", newHref);
  };

  function toggleRow(submissionId) {
    if (selectedSubmissions.indexOf(submissionId) < 0) {
      // not in the list
      selectedSubmissions.push(submissionId);
      $("#cbox-" + submissionId).prop('checked', true);
      $("#row-" + submissionId).addClass("selected");
    } else {
      // in the list
      $("#cbox-" + submissionId).prop('checked', false);
      $("#row-" + submissionId).removeClass("selected");
      selectedSubmissions = _.without(selectedSubmissions, submissionId);
    }

    updateBatchRegradeButton();
  }

  $("#submissions").on("click", ".exclude-click i", function (e) {
    e.stopPropagation();
    return;
  });

  $('#submissions').on("click", ".submission-row", function(e) {
    // Don't toggle row if we originally clicked on an anchor and input tag
    if(e.target.localName != 'a' && e.target.localName !='input') {
      // e.target: tightest element that triggered the event
      // e.currentTarget: element the event has bubbled up to currently
      var submissionId = parseInt(e.currentTarget.id.replace("row-", ""), 10);
      toggleRow(submissionId);
      return false;
    }
  });

  $('#submissions').on("click", ".cbox", function(e) {
    var submissionId = parseInt(e.currentTarget.id.replace("cbox-", ""), 10);
    toggleRow(submissionId);
    e.stopPropagation();
  });

});
