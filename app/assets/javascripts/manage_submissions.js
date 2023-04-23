const manage_submissions_endpoints = {
  'score_details': 'submissions/score_details',
}

$(document).ready(function() {

  $('.modal').modal();

  $('.score-details').on('click', function() {
    // Get the email 
    const course_user_datum_id = $(this).data('cuid');
    const email = $(this).data('email');
    
    // Clear the modal content
    $('#score-details-content').html('');
    $('#score-details-email').html(email);
    
    // TODO: Add loading spinner

    // Open the modal
    $('#score-details-modal').modal('open');
    
    // Fetch data and render it in the modal 
    getTableData(course_user_datum_id).then((data) => {
      console.log(data);
      
      const problemHeaders = data.submissions[0].problems.map((problem) => {
        return `<th class="submission-th">${problem.name}</th>`;
      }).join('');

      const submissions = data.submissions.map((submission) => {
          return `
            <tr id="row-${submission.id}" class="submission-row">
              <td class="submission-td">
                ${submission.version}
              </td>
              <td class="submisison-td">
                ${submission.created_at}
              </td>
              <td class="submission-td">
                ${submission.total}
              </td>
              ${submission.problems.map((problem) => {
                return `<td class="submission-td">${data.scores[submission.id][problem.id]['score']}</td>`;
              }).join('')}
              <td class="submission-td">
                ${submission.late_penalty}
              </td>
              <td class="submission-td">
                <a href="submissions/${submission.id}/edit">
                  ${data?.tweaks[submission.id]?.value ?? "None"}
                </a>
              </td>
              <td class="submission-td">
                ${submission.filename ?
                  `<div class="submissions-center-icons">
                    <a href="submissions/${submission.id}/view"
                      title="View the file for this submission"
                      class="btn small">
                      <i class='material-icons'>zoom_in</i>
                    </a>
                    <p>View File</p>
                  </div>` : "None"}
                ${ /text/.test(submission.detected_mime_type) ?
                    `<div class="submissions-center-icons">
                      <a href="submissions/${submission.id}/download?forceMime=text/plain"
                        title="Download as text/plain"
                        class="btn small">
                        <i class='material-icons'>file_download</i>
                      </a>
                      <p>Download as text/plain</p>
                    </div>` :
                    `<div class="submissions-center-icons">
                      <a href="submissions/${submission.id}/download"
                        title="Download the file for this submission"
                        class="btn small">
                        <i class='material-icons'>file_download</i>
                      </a>
                      <p>Download File</p>
                    </div>`}
              </td>
            </tr>`;
      }).join('');

      const submissionsTable = 
        `<table class="prettyBorder" id="score-details-table">
            <thead>
              <tr>
                <th class="submission-th">Version No.</th>
                <th class="submission-th">Submission Date</th>
                <th class="submission-th">Final Score</th>
                  ${problemHeaders}
                <th class="submission-th">Late Penalty</th>
                <th class="submission-th">Tweak</th>
                <th class="submission-th">Actions</th>
              </tr>
            </thead>
            <tbody>
              ${submissions}
            </tbody>
          </table>
        `;

      $('#score-details-content').html(`<div> ${submissionsTable} </div>`);
    }).catch((err) => {
      console.log(err);
    });
  });

  function getTableData(course_user_datum_id) {
    return new Promise((resolve, reject) => {
      $.ajax({
        url: manage_submissions_endpoints['score_details'],
        type: 'GET',
        data: { cuid: course_user_datum_id },
        success: function(data) {
          resolve(data);
        },
        error: function(err) {
          console.log(err);
          reject(err);
        }
      })
    });
  }

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
