const manage_submissions_endpoints = {
  'regrade-selected': 'regradeBatch',
};

$(document).ready(function() {

  var excusing = true;
  var selectedStudentCids = [];
  var selectedSubmissions = [];

  var table = $('#submissions').DataTable({
    "dom": 'fBrt', // show buttons, search, table
    buttons: [
      { text: '<i class="material-icons">cached</i>Regrade Selected',
        className: 'btn submissions-selected',
        attr: {id: 'regrade-selected'},
        action: function ( e, dt, node, config ) {
          var urlParam = $.param({"submission_ids": selectedSubmissions});
          var initialUrl = $("#regrade-batch").prop("href");
          var newHref = initialUrl + "?" + urlParam;
          location.href = newHref;
        }
      },
      { text: '<i class="material-icons">delete_outline</i>Delete Selected',
        className: 'btn submissions-selected',
        attr: {id: 'delete-selected'},
        action: function ( e, dt, node, config ) {
          // TODO
        }
      },
      { text: '<i class="material-icons">download</i>Download Selected',
        className: 'btn submissions-selected',
        attr: {id: 'download-selected'},
        action: function ( e, dt, node, config ) {
          var urlParam = $.param({"submission_ids": selectedSubmissions});
          var initialUrl = $("#download-batch").prop("href");
          var newHref = initialUrl + "?" + urlParam;
          location.href = newHref;
        }
      },
      { text: '<i class="material-icons">done</i>Excuse Selected',
        className: 'btn submissions-selected',
        attr: {id: 'excuse-selected'},
        action: function ( e, dt, node, config ) {
          $.ajax({
            url: 'update'
          });
          // selectedStudentCids.forEach((cid) =>
          //   excusing ? // set to 0 : set to 2
          // );
          // // TODO
        }
      },
    ]
  });


  // SELECTED BUTTONS

  if (!is_autograded) {
    $("#regrade-selected").hide();
  }

  function changeButtonStates(state) {
    var buttonIDs = ['#regrade-selected', '#delete-selected', '#download-selected', '#excuse-selected'];
    buttonIDs.forEach((id) => $(id).prop('disabled', state));
  }
  
  changeButtonStates(true); // disable all buttons by default


  // EXCUSING STUDENTS

  function allSelectedExcused() {
    if (!selectedStudentCids.length) return false;
    for (cidIndex in selectedStudentCids) {
      if (excused_cids.indexOf(selectedStudentCids[cidIndex]) < 0) {
        return false;
      }
    }
    return true;
  }

  // Updating text of "Excuse Selected" / "Unexcuse Selected" button
  function updateExcusedButtonText() {
    var allExcused = allSelectedExcused();
    var currState = allExcused ? "Unexcuse" : "Excuse";
    var buttonHTML = '<span><i class="material-icons">done</i>' + currState + ' Selected</span>'
    excusing = allExcused;
    $('#excuse-selected').html(buttonHTML);
  }


  // SELECTING STUDENT CHECKBOXES

  function toggleRow(submissionId) {
    var selectedCid = submissions_to_cud[submissionId];
    if (selectedSubmissions.indexOf(submissionId) < 0) {
      // not in the list
      selectedSubmissions.push(submissionId);
      $("#cbox-" + submissionId).prop('checked', true);
      $("#row-" + submissionId).addClass("selected");
      // add student cid
      if (selectedStudentCids.indexOf(selectedCid) < 0) {
        selectedStudentCids.push(selectedCid);
      }
    } else {
      // in the list
      $("#cbox-" + submissionId).prop('checked', false);
      $("#row-" + submissionId).removeClass("selected");
      selectedSubmissions = _.without(selectedSubmissions, submissionId);
      // remove student cid, but only if none of their submissions are selected
      for (sidIndex in selectedSubmissions) {
        var currSid = selectedSubmissions[sidIndex]
        if (submissions_to_cud[currSid] == selectedCid) {
          return;
        }
      }
      selectedStudentCids = _.without(selectedStudentCids, selectedCid);
    }
    changeButtonStates(!selectedSubmissions.length);
    updateExcusedButtonText();
  }

  $("#submissions").on("click", ".exclude-click i", function (e) {
    e.stopPropagation();
    return;
  });

  $('#submissions').on("click", ".submission-row", function(e) {
    // Don't toggle row if we originally clicked on an icon or anchor or input tag
    if(e.target.localName != 'i' && e.target.localName != 'a' && e.target.localName != 'input') {
      // e.target: tightest element that triggered the event
      // e.currentTarget: element the event has bubbled up to currently
      var submissionId = parseInt(e.currentTarget.id.replace("row-", ""), 10);
      toggleRow(submissionId);
      return false;
    }
  });

  $('#submissions').on("click", ".cbox", function(e) {
    var clickedSubmissionId = e.currentTarget.id.replace("cbox-", "");
    var submissionId = clickedSubmissionId == "select-all" ?  clickedSubmissionId : parseInt(clickedSubmissionId, 10);
    toggleRow(submissionId);
    e.stopPropagation();
  });

  // TODO: adapt below code if necessary for grouping / select all
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
});


// POPOVERS [TODO]

// jQuery(function() {
//   var current_popover = undefined;

//   function close_current_popover() {
//     current_popover.hide();
//     current_popover = undefined;
//   }

//   function close_current_popover_on_blur(event) {
//     if (current_popover && jQuery(current_popover).closest("td").find(event.target).length == 0) {
//         close_current_popover();
//     }
//   }

//   jQuery(document).click(function(event) {
//     event.stopPropagation();
//     console.log("hi");
//     close_current_popover_on_blur(event);
//   });
  
//   function show_popover(popover, at, arrow_at) {
//     if (current_popover) close_current_popover();

//     popover.show();
//     popover.position(at);

//     var arrow = jQuery(".excused-arrow", popover)
//       if (arrow_at) {
//         arrow.position(arrow_at);
//       } else {
//         arrow.position({
//           my: "right",
//           at: "left",
//           of: popover
//         });
//       }

//     current_popover = popover;
//   }

//   jQuery('#submissions').on('click', 'td.submissions-td div.submissions-name a.submissions-excused-label',
//     function() {
//       if (current_popover) {
//         close_current_popover();
//         return;
//       }

//       var link = jQuery(this);
//       currentPopover = link.siblings("div.excused-popover");
//       currentPopover.show();

//       // show_popover(popover, {
//       //         my: "left center",
//       //         at: "right center",
//       //         of: link,
//       //         offset: "10px 0"
//       //       });

//       // jQuery.ajax("submission_popover", {
//       //   data: { submission_id: link.parent().data("submission-id") },
//       //   success: function(data, status, jqXHR) {
//       //     popover.html(data)
//       //     show_popover(popover, {
//       //       my: "left center",
//       //       at: "right center",
//       //       of: link,
//       //       offset: "10px 0"
//       //     });
//       //   }
//       // });

//     }
//   );
// });
