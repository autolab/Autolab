$(document).ready(function() {

  // USE LATER FOR GROUPING ROWS (POSSIBLY):

  // $.fn.dataTable.ext.search.push(
  //   function(settings, data, dataIndex) {
  //     var filterOnlyLatest = $("#only-latest").is(':checked');
  //     if (!filterOnlyLatest) {
  //       // if not filtered, return all the rows
  //       return true;
  //     } else {
  //       var isSubmissionLatest = data[8]; // use data for the age column
  //       return (isSubmissionLatest == "true");
  //     }
  //   }
  // );

  var table = $('#submissions').DataTable({
    "dom": 'fBrt', // show buttons, search, table
    buttons: [
      { text: '<i class="material-icons">cached</i>Regrade Selected', className: 'btn submissions-selected disabled' },
      { text: '<i class="material-icons">delete_outline</i>Delete Selected', className: 'btn submissions-selected disabled' },
      { text: '<i class="material-icons">download</i>Download Selected', className: 'btn submissions-selected disabled' },
      { text: '<i class="material-icons">done</i>Excuse Selected', className: 'btn submissions-selected disabled' }
    ]
  });

  var selectedSubmissions = [];

  // USE LATER FOR REGRADE SELECTED (POSSIBLY):

  // var initialBatchUrl = $("#batch-regrade").prop("href");

  // function updateBatchRegradeButton() {
  //   if (selectedSubmissions.length == 0) {
  //     $("#batch-regrade").fadeOut(120);
  //   } else {
  //     $("#batch-regrade").fadeIn(120);
  //   }
  //   var urlParam = $.param({
  //     "submission_ids": selectedSubmissions
  //   });
  //   var newHref = initialBatchUrl + "?" + urlParam;
  //   $("#batch-regrade").html("Regrade " + selectedSubmissions.length + " Submissions")
  //   $("#batch-regrade").prop("href", newHref);
  // };

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
    // updateBatchRegradeButton();
  }

  $("#submissions").on("click", ".exclude-click i", function (e) {
    e.stopPropagation();
    return;
  });

  $('#submissions').on("click", ".cbox", function(e) {
    var submissionId = parseInt(e.currentTarget.id.replace("cbox-", ""), 10);
    toggleRow(submissionId);
    e.stopPropagation();
  });

});
