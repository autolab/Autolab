const manage_submissions_endpoints = {
  'score_details': 'submissions/score_details',
}

function get_score_details(course_user_datum_id) {
  return new Promise((resolve, reject) => {
    $.ajax({
      url: manage_submissions_endpoints['score_details'],
      type: 'GET',
      data: { cuid: course_user_datum_id },
      success: function (data) {
        resolve(data);
      },
      error: function (err) {
        reject(err);
      }
    })
  });
}

$(document).ready(function () {

  $('.modal').modal();

  $('.score-details').on('click', function () {
    // Get the email 
    const course_user_datum_id = $(this).data('cuid');
    const email = $(this).data('email');

    // Set the email
    $('#score-details-email').html(email);

    // Clear the modal content
    $('#score-details-content').html('');

    // Add a loading bar
    $('#score-details-content').html(`
        <div class="progress">
            <div class="indeterminate"></div>
        </div>`);

    // Open the modal
    $('#score-details-modal').modal('open');

    // Fetch data and render it in the modal 
    get_score_details(course_user_datum_id).then((data) => {
      const sorting_icons =
      ` <i class="material-icons tiny sort-icon sort-icon__both" aria-hidden="true">swap_vert</i>
        <i class="material-icons tiny sort-icon sort-icon__up" aria-hidden="true">arrow_upward</i>
        <i class="material-icons tiny sort-icon sort-icon__down" aria-hidden="true">arrow_downward</i>`;

      const problem_headers = data.submissions[0].problems.map((problem) => {
        const max_score = problem.max_score;
        const autograded = problem.grader_id < 0 ? " (Autograded)" : "";
        return `<th class="submission-th submissions-problem-bg">
                  <div class="sorting-th">
                    ${problem.name}
                    ${sorting_icons}
                  </div>
                  <span class="score-styling"> ${max_score} ${autograded} </span>
                </th>`;
      }).join('');

      const submissions_body = data.submissions.map((submission) => {
        
        let tweak_value = data?.tweaks[submission.id]?.value ?? "None";
        if (tweak_value != "None" && tweak_value > 0) {
          tweak_value = `+${tweak_value}`;
        }

        // Convert to human readable date with timezone 
        const human_readable_created_at = 
              moment(submission.created_at).format('MMM Do YY, h:mma z UTC Z');

        const view_button = submission.filename ? 
              `<div class="submissions-center-icons">
                  <a href="submissions/${submission.id}/view"
                    title="View the file for this submission"
                    class="btn small">
                    <i class='material-icons'>zoom_in</i>
                  </a>
                  <p>View Source</p>
                </div>` 
                : "None";

        const download_button = 
                /text/.test(submission.detected_mime_type) ?
                `<div class="submissions-center-icons">
                    <a href="submissions/${submission.id}/download?forceMime=text/plain"
                      title="Download as text/plain"
                      class="btn small">
                      <i class='material-icons'>file_download</i>
                    </a>
                    <p>Download</p>
                  </div>` :
                `<div class="submissions-center-icons">
                    <a href="submissions/${submission.id}/download"
                      title="Download the file for this submission"
                      class="btn small">
                      <i class='material-icons'>file_download</i>
                    </a>
                    <p>Download</p>
                  </div>`;

        return `
            <tr id="row-${submission.id}" class="submission-row">
              <td class="submissions-td">
                ${submission.version}
              </td>
              <td class="submissions-td">
                ${human_readable_created_at}
              </td>
              <td class="submissions-td">
                ${submission.total}
              </td>
              ${submission.problems.
              map((problem) =>
                `<td class="submissions-td submissions-problem-bg">${data.scores[submission.id][problem.id]?.['score']}</td>`
              ).join('')}
              <td class="submissions-td">
                ${submission.late_penalty}
              </td>
              <td class="submissions-td">
                <a href="submissions/${submission.id}/edit">
                  ${tweak_value}
                </a>
              </td>
              <td class="submissions-td">
                ${view_button}
                ${download_button}
              </td>
            </tr>`;
      }).join('');

      const submissions_table =
        ` <p>Click on non-autograded problem scores to edit or leave a comment. </p>
          <table class="prettyBorder" id="score-details-table">
            <thead>
              <tr>
                <th class="submission-th">
                  <div class="sorting-th">
                    Version No.
                    ${sorting_icons}
                  </div>
                </th>
                <th class="submission-th">
                  <div class="sorting-th">
                    Submission Date
                    ${sorting_icons}
                  </div>
                </th>
                <th class="submission-th">
                  <div class="sorting-th">
                    Final Score
                    ${sorting_icons}
                  </div>
                </th>
                  ${problem_headers}
                <th class="submission-th">
                  <div class="sorting-th">
                    Late Penalty
                    ${sorting_icons}
                  </div>
                </th>
                <th class="submission-th">Tweak</th>
                <th class="submission-th">Actions</th>
              </tr>
            </thead>
            <tbody>
              ${submissions_body}
            </tbody>
          </table>
        `;

      $('#score-details-content').html(`<div> ${submissions_table} </div>`);
      $('#score-details-table').DataTable({
        "order": [[0, "desc"]],
        "paging": false,
        "info": false,
        "searching": false,});

    }).catch((err) => {
      $('#score-details-content').html(`
        <div class="row">
          <div class="col s12">
            <div class="card-panel red lighten-2">
            ${err}
            </div>
          </div>
        </div>`);
    });
  });

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

  $('#submissions').on("click", ".cbox", function (e) {
    var submissionId = parseInt(e.currentTarget.id.replace("cbox-", ""), 10);
    toggleRow(submissionId);
    e.stopPropagation();
  });

});
