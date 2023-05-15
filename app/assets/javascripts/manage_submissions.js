const manage_submissions_endpoints = {
  'regrade-selected': 'regradeBatch',
};

$(document).ready(function() {

  var selectedStudentCids = [];
  var selectedSubmissions = [];

  var table = $('#submissions').DataTable({
    'dom': 'f<"selected-buttons">rt', // show buttons, search, table
    'paging': false,
  });

  // SELECTED BUTTONS

  // create selected buttons inside datatable wrapper
  var regradeHTML = document.getElementById('regrade-batch-html').innerHTML;
  var deleteHTML = document.getElementById('delete-batch-html').innerHTML;
  var downloadHTML = document.getElementById('download-batch-html').innerHTML;
  var excuseHTML = document.getElementById('gradetype-batch-html').innerHTML;
  $('div.selected-buttons').html(`<div id='selected-buttons'>${regradeHTML}${deleteHTML}${downloadHTML}${excuseHTML}</div>`);

  // add ids to each selected button
  $('#selected-buttons > a').each(function () { 
    let idText = this.title.split(' ')[0].toLowerCase() + '-selected';
    this.setAttribute('id', idText);
   });

  if (!is_autograded) {
    $('#regrade-selected').hide();
  }

  // base URLs for selected buttons
  var buttonIDs = ['#regrade-selected', '#delete-selected', '#download-selected', '#gradetype-selected'];
  var baseURLs = {};
  buttonIDs.forEach(function(id) {
    baseURLs[id] = $(id).prop('href');
  });

  function changeButtonStates(state) {
    state ? buttonIDs.forEach((id) => $(id).addClass('disabled')) : buttonIDs.forEach((id) => $(id).removeClass('disabled'));

    // prop each selected button with selected submissions
    if (!state) {
      var urlParam = $.param({'submission_ids': selectedSubmissions});
      buttonIDs.forEach(function(id) {
        var newHref = baseURLs[id] + '?' + urlParam;
        $(id).prop('href', newHref);
      });
    } else {
      buttonIDs.forEach(function(id) {
        $(id).prop('href', baseURLs[id]);
      });
    }
  }
  
  changeButtonStates(true); // disable all buttons by default

  // SELECTING STUDENT CHECKBOXES

  function toggleRow(submissionId) {
    var selectedCid = submissions_to_cud[submissionId];
    if (selectedSubmissions.indexOf(submissionId) < 0) {
      // not in the list
      selectedSubmissions.push(submissionId);
      $('#cbox-' + submissionId).prop('checked', true);
      $('#row-' + submissionId).addClass('selected');
      // add student cid
      if (selectedStudentCids.indexOf(selectedCid) < 0) {
        selectedStudentCids.push(selectedCid);
      }
    } else {
      // in the list
      $('#cbox-' + submissionId).prop('checked', false);
      $('#row-' + submissionId).removeClass('selected');
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

  $('#submissions').on('click', '.cbox', function (e) {
    var clickedSubmissionId = e.currentTarget.id.replace('cbox-', '');
    var submissionId = clickedSubmissionId == 'select-all' ?  clickedSubmissionId : parseInt(clickedSubmissionId, 10);
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
