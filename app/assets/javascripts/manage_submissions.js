const manage_submissions_endpoints = {
    'regrade-selected': 'regradeBatch',
    'delete-selected': 'submissions/destroy_batch',
    'download-selected': 'submissions/download_batch',
    'excuse-selected': 'submissions/excuse_batch',
    'score_details': 'submissions/score_details',
};

const buttonIDs = ['#regrade-selected', '#delete-selected', '#download-selected', '#excuse-selected'];

let tweaks = [];
let currentPage = 0;
$(document).ready(function() {
  var submission_info = {}
  const EditTweakButton = (totalSum) => {
    if (totalSum == null) {
      return `
        <span>-</span>
        <i class="material-icons submissions-tweak-button">edit</i>
      `
    }
    return `
      <div class="submissions-tweak-points">${totalSum < 0 ? "" : "+"}${totalSum} points</div>
    `
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

  const selectSubmission = (data) => {
    submission_info = data
    basePath = data?.base_path;
    sharedCommentsPath = `${basePath}/shared_comments`;
    createPath = basePath + ".json";
    updatePath = function (ann) {
      return [basePath, "/", ann.id, ".json"].join("");
    };
    scores = data?.scores;
    deletePath = updatePath;
  }

  const selectTweak = submissions => {
    const submissionsById = Object.fromEntries(submissions.map(sub => [sub.id, sub]))

    return function () {
        $('#annotation-modal').modal('open');
        const $student = $(this);
        const submission = $student.data('submissionid');
        selectSubmission(submissionsById[submission]);
        retrieveSharedComments(() => {
          const newForm = newAnnotationFormCode();
          $('#active-annotation-form').html(newForm);
        });
    }
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
        const problem_headers = data.submissions[0].problems.map((problem) => {
          const max_score = problem.max_score;
          const autograded = problem.grader_id == null || problem.grader_id < 0 ? " (Autograded)" : "";
          return `<th class="submission-th">
                    ${problem.name}
                    <br>
                    <i> ${max_score} ${autograded} </i>
                  </th>`;
        }).join('');

        tweaks = [];

        const submissions_body = data.submissions.map((submission) => {
          const Tweak = new AutolabComponent(`tweak-value-${submission.id}`, { amount: null });
          Tweak.template = function () {
            return EditTweakButton( this.state.amount );
          }
          tweaks.push({tweak: Tweak, submission_id: submission.id, submission});

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
                        `<td class="submissions-td">
                        ${data.scores[submission.id]?.[problem.id]?.['score'] !== undefined
                          ? `<a href="viewFeedback?submission_id=${submission.id}&feedback=${problem.id}">
                        ${data.scores[submission.id][problem.id]['score'].toFixed(1)}
                     </a>`
                        : "-"}
                    </td>`
                    ).join('')}
                <td class="submissions-td">
                  ${submission.late_penalty}
                </td>
                <td class="submissions-td">
                  <div class="tweak-button" data-submissionid="${submission.id}" id="tweak-value-${submission.id}">
                  </div>
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
                  <th class="submission-th">Version No.</th>
                  <th class="submission-th">Submission Date</th>
                  <th class="submission-th">Final Score</th>
                    ${problem_headers}
                  <th class="submission-th">Late Penalty</th>
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

        updateEditTweakButtons();
        $('#score-details-table').DataTable({
          "order": [[0, "desc"]],
          "paging": false,
          "info": false,
          "searching": false,});

        return data.submissions;

      }).then((submissions) => {
        $('.tweak-button').on('click', selectTweak(submissions));
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

    var selectedStudentCids = [];
    var selectedSubmissions = [];

    var table = $('#submissions').DataTable({
      'dom': 'f<"selected-buttons">rtip', // show buttons, search, table
      'paging': true,
      'createdRow': completeRow,
      'sPaginationType': 'full_numbers',
      'pageLength': 100,
      'info': true,
      'deferRender': true,
    });

    // Check if the table is empty
    if (table.data().count() === 0) {
      $('#submissions').closest('.dataTables_wrapper').hide(); // Hide the table and its controls
      $('#no-data-message').show(); // Optionally show a custom message
    } else {
      $('#no-data-message').hide(); // Hide custom message when there is data
    }

    function completeRow(row, data, index) {
      var submission = additional_data[index];
      $(row).attr('data-submission-id', submission['submission-id']);
    }

    $('thead').on('click', function(e) {
      if (currentPage < 0) {
        currentPage = 0
      }
      if (currentPage > table.page.info().pages) {
        currentPage = table.page.info().pages - 1
      }
      table.page(currentPage).draw(false);
    })

    // Listen for select-all checkbox click
    $('#cbox-select-all').on('click', async function(e) {
      var selectAll = $(this).is(':checked');
      await toggleAllRows(selectAll);
    });

    // Function to toggle all checkboxes
    function toggleAllRows(selectAll) {
      $('#submissions tbody .cbox').each(function() {
        $('#cbox-select-all').prop('checked', selectAll);
        var submissionId = parseInt($(this).attr('id').replace('cbox-', ''), 10);
        if (selectAll) {
          if (selectedSubmissions.indexOf(submissionId) === -1) {
            toggleRow(submissionId, true); // force select
          }
        } else {
          if (selectedSubmissions.indexOf(submissionId) !== -1) {
            toggleRow(submissionId, false); // force unselect
          }
        }
      });
      changeButtonStates(!selectedSubmissions.length); // update button states
    }

    // SELECTED BUTTONS

    // create selected buttons inside datatable wrapper
    var regradeHTML = $('#regrade-batch-html').html();
    var deleteHTML = $('#delete-batch-html').html();
    var downloadHTML = $('#download-batch-html').html();
    var excuseHTML = $('#excuse-batch-html').html();
    $('div.selected-buttons').html(`<div id='selected-buttons'>${regradeHTML}${deleteHTML}${downloadHTML}${excuseHTML}</div>`);

    // add ids to each selected button
    $('#selected-buttons > a').each(function () {
      let idText = this.title.split(' ')[0].toLowerCase() + '-selected';
      this.setAttribute('id', idText);
    });

    if (!is_autograded) {
      $('#regrade-selected').hide();
      $('#regrade-all-html').hide();
    }

    // base URLs for selected buttons
    var baseURLs = {};
    buttonIDs.forEach(function(id) {
      baseURLs[id] = $(id).prop('href');
    });

    function updateSelectedCount(numericSubmissions) {
      const allBoxes = $('#submissions tbody .cbox').length;
      const selectedCountElement = document.getElementById("selected-count-html");
      const placeholder = document.querySelector(".selected-count-placeholder");
      if (selectedCountElement) {
        selectedCountElement.innerText = `All ${numericSubmissions.length} submissions on this page selected.`;
        if (numericSubmissions.length === allBoxes) {
          placeholder.style.display = "block";
        } else if (numericSubmissions.length <= allBoxes) {
          placeholder.style.display = "none";
        }
      }
    }

    function changeButtonStates(state) {
      buttonIDs.forEach((id) => {
        const button = $(id);
        if (state) {
          if (id === "#download-selected") {
            $(id).prop('href', baseURLs[id]);
          }
          button.addClass("disabled");
          button.off("click").prop("disabled", true);
        } else {
          button.removeClass("disabled").prop("disabled", false);
          if (id == "#download-selected") {
            var urlParam = $.param({'submission_ids': selectedSubmissions});
            buttonIDs.forEach(function(id) {
              var newHref = baseURLs[id] + '?' + urlParam;
              $(id).prop('href', newHref);
            });
            return;
          }
          $(document).off("click", id).on("click", id, function (event) {
            console.log(`${id} button clicked`);
            event.preventDefault();
            if (selectedSubmissions.length === 0) {
              alert("No submissions selected.");
              return;
            }
            const endpoint = manage_submissions_endpoints[id.replace("#", "")];
            const requestData = { submission_ids: selectedSubmissions };
            if (id === "#delete-selected") {
              if (!confirm("Deleting will delete all checked submissions and cannot be undone. Are you sure you want to delete these submissions?")) {
                return;
              }
            }
            let refreshInterval = setInterval(() => {
              location.reload();
            }, 5000);
            $.ajax({
              url: endpoint,
              type: "POST",
              contentType: "application/json",
              data: JSON.stringify(requestData),
              dataType: "json",
              headers: {
                "X-CSRF-Token": $('meta[name="csrf-token"]').attr("content"),
              },
              success: function (response) {
                clearInterval(refreshInterval);
                if (response.redirect) {
                  window.location.href = response.redirect;
                  return;
                }
                if (response.error) {
                  alert(response.error);
                }
                if (response.success) {
                  alert(response.success);
                }
                selectedSubmissions = [];
                changeButtonStates(true);
              },
              error: function (error) {
                clearInterval(refreshInterval);
                alert("An error occurred while processing the request.");
              },
            });
          });
        }
      });
    }

    changeButtonStates(true); // disable all buttons by default

    // SELECTING STUDENT CHECKBOXES
    function toggleRow(submissionId, forceSelect = null) {
      var selectedCid = submissions_to_cud[submissionId];
      const isSelected = selectedSubmissions.includes(submissionId);
      const shouldSelect = forceSelect !== null ? forceSelect : !isSelected;

      if (shouldSelect && !isSelected) {
        // not in the list
        selectedSubmissions.push(submissionId);
        $('#cbox-' + submissionId).prop('checked', true);
        $('#row-' + submissionId).addClass('selected');
        // add student cid
        if (selectedStudentCids.indexOf(selectedCid) < 0) {
          selectedStudentCids.push(selectedCid);
        }
      } else if (!shouldSelect && isSelected) {
        // in the list
        $('#cbox-' + submissionId).prop('checked', false);
        $('#row-' + submissionId).removeClass('selected');
        selectedSubmissions = _.without(selectedSubmissions, submissionId);
        // remove student cid, but only if none of their submissions are selected
        const hasOtherSelectedSubmissions = selectedSubmissions.some(id => submissions_to_cud[id] === selectedCid);
        if (!hasOtherSelectedSubmissions) {
          selectedStudentCids = selectedStudentCids.filter(cid => cid !== selectedCid);
        }
        selectedStudentCids = _.without(selectedStudentCids, selectedCid);
      }
      let disableButtons = !selectedSubmissions.length || (selectedSubmissions.length === 1 && selectedSubmissions[0] === 'select-all')
      // Ensure `selectedSubmissions` contains only numbers
      const numericSelectedSubmissions = selectedSubmissions.filter(submissionId => typeof submissionId === 'number');
      // Update the "Select All" checkbox based on filtered numeric submissions
      $('#cbox-select-all').prop('checked', numericSelectedSubmissions.length === $('#submissions tbody .cbox').length);
      updateSelectedCount(numericSelectedSubmissions);
      changeButtonStates(disableButtons);
    }

    $('#submissions').on('click', '.exclude-click i', function (e) {
      e.stopPropagation();
      return;
    });

    $('#submissions').on('click', '.submission-row', function (e) {
      // Don't toggle row if we originally clicked on an icon or anchor or input tag
      if(e.target.localName != 'i' && e.target.localName != 'a' && e.target.localName != 'input') {
        // e.target: tightest element that triggered the event
        // e.currentTarget: element the event has bubbled up to currently
        var submissionId = parseInt(e.currentTarget.id.replace('row-', ''), 10);
        toggleRow(submissionId);
        return false;
      }
    });

    $('#submissions_paginate').on('click', function(e) {
      currentPage = table.page();
      // Toggle previously selected submissions to be unselected
      selectedSubmissions.map(selectedSubmission => toggleRow(selectedSubmission, false));
    })

    $('#submissions').on('click', '.cbox', function (e) {
      var clickedSubmissionId = e.currentTarget.id.replace('cbox-', '');
      var submissionId = clickedSubmissionId == 'select-all' ?  clickedSubmissionId : parseInt(clickedSubmissionId, 10);
      toggleRow(submissionId);
      e.stopPropagation();
    });

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
  });

  jQuery(function() {
    var current_popover = undefined;

    function close_current_popover() {
      current_popover.hide();
      current_popover = undefined;
    }

    function close_current_popover_on_blur(event) {
      if (current_popover && !jQuery(event.target).closest(current_popover).length) {
        close_current_popover();
      }
    }

    jQuery(document).click(function(event) {
      event.stopPropagation();
      close_current_popover_on_blur(event);
    });

    jQuery(document).on('click', '.excuse-popover-cancel', function(event) {
      event.stopPropagation();
      close_current_popover();
    })

    function show_popover(popover, at, arrow_at) {
      if (current_popover) close_current_popover();

      popover.show();
      popover.position(at);

      var arrow = jQuery(".excused-arrow", popover)
      if (arrow_at) {
        arrow.position(arrow_at);
      } else {
        arrow.position({
          my: "right",
          at: "left",
          of: popover
        });
      }

      current_popover = popover;
    }

    jQuery('#submissions').on('click', 'td.submissions-td div.submissions-name a.submissions-excused-label',
        function(e) {
          if (current_popover) {
            close_current_popover();
            return;
          }

          var link = jQuery(this);
          let currentPopover = link.siblings("div.excused-popover");
          currentPopover.show();

          show_popover(currentPopover, {
            my: "left center",
            at: "right center",
            of: link,
            offset: "10px 0"
          });
          jQuery.ajax("excuse_popover", {
            data: { submission_id: link.closest('tr').data("submission-id") },
            success: function(data, status, jqXHR) {
              currentPopover.html(data)
              show_popover(currentPopover, {
                my: "left center",
                at: "right center",
                of: link,
                offset: "10px 0"
              });
            }
          });
        }
    );
  })
});
