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

function clickDrag() {
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
});

function enableSubmit() {
  var checkbox = document.getElementById("integrity_checkbox");
  var tab = $(".submission-panel .ui.tab.active").attr('id');
  var fileSelector = $("#handin_show_assessment input[type='file']").get(0);
  if (tab === "github_tab") {
    fileSelector.value = null;
    $(".handin-row").show();
    $(".handedin-row").hide();
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
      var repoSelected = $("#repo-dropdown .noselection").length === 0;
      var branchSelected = $("#branch-dropdown .noselection").length === 0;
      // if there's no repos
      if (!repoSelected || !branchSelected) {
        $("#fake-submit").addClass("disabled");
      } else {
        $("#fake-submit").removeClass("disabled");
      }
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