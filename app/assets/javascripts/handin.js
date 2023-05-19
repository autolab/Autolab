// Loads all Semantic javascripts
//= require semantic-ui

var submittedFile = false;

function flashError(message) {
  const elem = $(".file-error").text(message).show();
}

function dropHandler(e) {
  e.preventDefault();
  $(".drag-drop-handin").get(0).style = undefined;
  if (e.dataTransfer.files.length === 1) {
    var fileSelector = $("#handin_show_assessment input[type='file']").get(0);
    fileSelector.files = e.dataTransfer.files;
    if (fileSelector.files.length === 1) {
      showFiles();
      enableSubmit();
    }
  }
}

function dragOverHandler(e) {
  e.preventDefault();
}

function dragEnter(e) {
  $(".drag-drop-handin").get(0).style = "background:rgba(0,0,0,0.05);";
}

function dragExit(e) {
  $(".drag-drop-handin").get(0).style = undefined;
}

function clickDrag(e) {
  // Ignore shift and tab
  if (e.key === "Shift" || e.key === "Tab") return;
  $("#handin_show_assessment input[type='file']").trigger('click');
}

document.querySelector("#handin_show_assessment input[type='file']").addEventListener(
  "change",
  function (e) {
    showFiles();
  },
  false
);

function showFiles() {
  var fileSelector = $("#handin_show_assessment input[type='file']").get(0);
  var file = fileSelector.files[0];
  $("#handin-file-name").text(file.name);

  // only do check for file type that has a period
  if( $('#handin-file-type').length && file
     && file.name.split(".").length > 1)         // use this if you are using id to check
  {
    $('#handin-file-type-incorrect').text("")
    var handin_filetype = $('#handin-file-type').text();
    var handin_filetype_length = handin_filetype.split(".").length;
    var file_type = file.name.split(".").slice(-handin_filetype_length).join('.');
    // compare expected file extension (handin_filetype) to submitted file extension (file_type)
    if (handin_filetype != file_type) {
      $('#handin-file-type-incorrect').text(`Warning: ${file.name}'s file type doesn't match expected .${handin_filetype} file type`)
    }
  } else if ($('#handin-file-type').length) {
    // no . in the filename, so probably wrong
    var handin_filetype = $('#handin-file-type').text();
    $('#handin-file-type-incorrect').text(`Warning: ${file.name}'s file type doesn't match expected .${handin_filetype} file type`)
  }


  $("#handin-modify-date").text(moment(file.lastModified).format("MMMM Do YYYY, h:mm a"));
  submittedFile = false;

  var sOutput = file.size + " bytes";
  for (var aMultiples = ["kb", "mb", "gb", "tb", "pb", "eb", "zb", "yb"], nMultiple = 0, nApprox = file.size / 1024; nApprox > 1; nApprox /= 1024, nMultiple++) {
    sOutput = nApprox.toFixed(1) + " " + aMultiples[nMultiple];
  }

  $("#handin-size").text(sOutput);

  if (file) {
    var reader = new FileReader();
    reader.readAsText(file, "UTF-8");
    reader.onload = function (evt) {
        var lines = evt.target.result;
        var lineCount = lines.split("\n").length;
        $("#handin-loc").text(lineCount);
    }
    reader.onerror = function (evt) {
        $("#handin-text").hide();
    }
  }

  if (fileSelector.files.length === 1) {
      $(".handin-row").hide(0, function () {
        $(".file-error").hide();
      });
      $(".handedin-row").show();
      enableSubmit();
  }
}

$("#integrity_checkbox").change(function (e) {
  enableSubmit();
});

$("#remove-handed-in").click(function (e) {
  e.preventDefault();
  var fileSelector = $("#handin_show_assessment input[type='file']").get(0);
  fileSelector.value = null;
  $(".handin-row").show(function () {
    enableSubmit();
  });
  $(".handedin-row").hide();
  $('#handin-file-type-incorrect').text("")
});

function enableSubmit() {
  var checkbox = document.getElementById("integrity_checkbox");
  var tab = $(".submission-panel .ui.tab.active").attr('id');
  var fileSelector = $("#handin_show_assessment input[type='file']").get(0);
  if (tab === "github_tab") {
    // hide file type check text
    $("#filename-check").hide();
  } else {
    $("#filename-check").show();
  }
  if (!checkbox.checked) {
    $("#fake-submit").addClass("disabled");
  } else {
    if (tab === "upload_tab") {
      if (fileSelector.files.length !== 1) {
        $("#fake-submit").addClass("disabled");
      } else {
        $("#fake-submit").removeClass("disabled");
      }  
    } else if (tab === "github_tab") {
      const repoSelected = $("#repo-dropdown .noselection").length === 0;
      const branchSelected = $("#branch-dropdown .noselection").length === 0;
      const commitSelected = $("#commit-dropdown .noselection").length === 0;
      $("#fake-submit").toggleClass("disabled", !repoSelected || !branchSelected || !commitSelected);
    }
  }

  if (tab === "upload_tab" && checkbox.checked && $(".handin-row").is(":hidden") && $("#fake-submit").hasClass("disabled") && fileSelector.files.length === 0) {
    // theres an issue
    $(".handin-row").show();
    $(".handedin-row").hide();
    flashError("There was an error processing your file, please try again.");
  }
}

$("#fake-submit").click(function (e) {
  if (submittedFile) {
    e.preventDefault();
    return;
  }
  $("#fake-submit").addClass("disabled");
  submittedFile = true;
});

$(document).on("click", ".submission-panel .item", function (e) {
  enableSubmit();
});

$(document).ready(function() {
  $('.tabular.menu .item').tab();
});