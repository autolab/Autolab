/* Document On Ready Initializations */

$(document).ready(function () {
  $(".collapsible-body").show(); //expands all collapsible initially
  $('.collapsible').collapsible();
  //get line number in URL, if it exists
  var urlParams = new URLSearchParams(location.search);
  if (urlParams.has("line")) {
    scrollToLine(urlParams.get("line"));
  }
  if (!newFile.pdf) {
    purgeCurrentPageCache();
  }
});

/* File Tree and Code Viewer Helper Functions */

// Lets us open and close file folders
function switchFolderState(folderElement) {
  folderElement.toggleClass('active')
}

function refreshAnnotations() {
  $(".annotation-line .line-sticky").each(function () {
    $(this).height($(this).parent().height());
  });
}

// Returns true if the file was cached, false otherwise
function changeFile(headerPos) {
  $('#code-box').addClass('loading');
  setActiveFilePos(headerPos);

  // If we've cached this file locally, just get it
  if (localCache[headerPos] != undefined) {
    newFile = localCache[headerPos];
    // Update the code viewer and symbol tree with the cached data
    $('#code-box').replaceWith(newFile.codeBox);

    if (newFile.symbolTree == null) {
      $('#symbol-tree-box').hide();
    } else {
      $('#symbol-tree-container').html(newFile.symbolTree);
    }

    // Add syntax highlighting to the new code viewer
    $('pre code').each(function () {
      hljs.highlightBlock(this);
    });

    // Update the page URL
    history.replaceState(null, null, newFile.url);

    displayAnnotations();
    attachEvents();
    return true;
  }
  return false;
}

function purgeCurrentPageCache() {
  var symbolTree = $("#symbol-tree-box").html();
  if (symbolTree) {
    symbolTree = `<div id="symbol-tree-box">${symbolTree}</div>`
  }
  else {
    symbolTree = null;
  }
  localCache[currentHeaderPos] = {
    codeBox: `<div id="code-box">${$('#code-box').html()}</div>`,
    pdf: false,
    symbolTree
  };
}

// Updates active tags to set the specified file
function setActiveFilePos(headerPos) {
  currentHeaderPos = headerPos;
  $('.file.active').removeClass("active");
  rootFiles.each(function (_, file) {
    setActiveFilePosHelper($(file), headerPos);
  });
  $('.file-list').scrollTo($('.file.active'))
}

function setActiveFilePosHelper(elem, headerPos) {
  if (elem.data("header_position") == headerPos) {
    elem.addClass("active")
    return true
  }
  if ((elem.children().filter(function () {
    return setActiveFilePosHelper($(this), headerPos)
  })).size() > 0) {
    elem.children(".folder-name").addClass("active")
    return true
  }
  return false
}

// Go to a specific file and a specific line in the codeviewer
// Where f is the file's header_position value, and n is the line number
function scrollToFileLine(f, n) {
  if (currentHeaderPos == f) {
    scrollToLine(n)
  }
  else {
    if (!changeFile(f)) {
      // file not chached, go to page
      window.location = `./view?header_position=${f}&line=${n}`;
    }
    scrollToLine(n);
  }
}

// Go to a specific line in the codeviewer
// Where n is the line number
function scrollToLine(n) {
  $('.code-table').scrollTo($('#line-' + (n - 1)), { duration: "fast" })
}

function plusFix(n) {
  n = parseInt(n)
  if (isNaN(n)) n = 0;

  if (n > 0) {
    return "+" + n.toFixed(1);
  }

  return n.toFixed(1);
}

function fillAnnotationBox() {
  var annotationsByProblem = {}
  $(".collapsible.expandable").find('li').remove();
  for (var i = 0; i < annotations.length; i++) {
    var problem = getProblemNameWithId(annotations[i].problem_id)
    if (!annotationsByProblem[problem]) {
      annotationsByProblem[problem] = []
    }
    annotations[i].problem = problem;
    annotationsByProblem[problem].push(annotations[i])
  }

  for (var problem in annotationsByProblem) {
    var problemElement = $("#li-problem-" + problem);
    var score = 0;
    for (var i = 0; i < annotationsByProblem[problem].length; i++) {
      var annotation = annotationsByProblem[problem][i];
      var points = parseInt(annotation.value);
      if (isNaN(points)) points = 0;
      score += points;
    }

    var annotationsSummary = $(".annotationSummary");

    if (problemElement) {
      problemElement.remove();
    }

    var newLi = $("<li />");
    newLi.addClass('active');
    annotationsSummary.find("ul").append(newLi)
    newLi.attr("id", "li-problem-" + problem);
    var collapsible = $('<div />');
    collapsible.addClass('collapsible-header');
    collapsible.addClass('active');
    collapsible.append(
      '<h4 style="text-transform:capitalize;">' + problem + '<div class="summary_score">' + plusFix(score) + '</div>' +
      '</h4>'
    )
    newLi.append(collapsible);

    var listing = $('<div />');
    newLi.append(listing);
    listing.addClass("collapsible-body");
    listing.addClass("active");
    listing.css('display', 'block');

    // sorts the annotation by line order
    annotationsByProblem[problem].sort(function (annotation1, annotation2) { return annotation1.line - annotation2.line });

    for (var i = 0; i < annotationsByProblem[problem].length; i++) {
      var annotation = annotationsByProblem[problem][i];

      var annotationElement = $('<div />');
      annotationElement.addClass('descript');
      annotationElement.attr('id', 'li-annotation-' + annotation.id);

      // Standardized scrollToFileLine behavior
      // annotation.line + 1 because the line numbers on editor starts with 1 not 0
      annotationElement.attr('onclick', `scrollToFileLine(${annotation.position}, ${annotation.line + 1})`);

      var pointBadge = $('<span />');
      pointBadge.addClass('point_badge');
      if (annotation.value > 0) {
        pointBadge.addClass('positive');
      } else if (annotation.value < 0) {
        pointBadge.addClass('negative');
      } else {
        pointBadge.addClass('neutral');
      }

      pointBadge.text(plusFix(annotation.value));
      annotationElement.append(pointBadge);
      annotationElement.append(annotation.comment);
      listing.append(annotationElement);

    }
  }
  // Reloads the grades part upon update
  $('.problemGrades').load(document.URL + ' .problemGrades');
}

// Sets up the keybindings
$(document).keydown(function (e) {
  if (!$(e.target).is('body')) {
    return true;
  }

  switch (e.which) {
    case 37: // left - navigate to the previous submission
      $('#prev_submission_link')[0].click();
      break;

    case 38: // up - navigate to the previous file by DOM position
      var testPos = allFilesFolders.index($('.file.active')) - 1
      while (testPos > -1) {
        var testElem = $(allFilesFolders.get(testPos))
        if (testElem.data("header_position") != undefined) {
          testElem.click();
          break;
        }
        testPos -= 1;
      }
      break;

    case 39: // right - navigate to the next submission
      $('#next_submission_link')[0].click();
      break;

    case 40: // down - navigate to the next file by DOM position
      var testPos = allFilesFolders.index($('.file.active')) + 1;
      while (testPos < allFilesFolders.length) {
        var testElem = $(allFilesFolders.get(testPos));
        if (testElem.data("header_position") != undefined) {
          testElem.click();
          break;
        }
        testPos += 1;
      }
      break;

    default: return; // exit this handler for other keys
  }
  e.preventDefault(); // prevent the default action (scroll / move caret)
});

/* Some Helper functions */
function copyToClipboard(str) {
  var el = document.createElement('textarea'); // Create a <textarea> element
  el.value = str; // Set its value to the string that you want copied
  el.setAttribute('readonly', ''); // Make it readonly to be tamper-proof
  el.style.position = 'absolute';
  el.style.left = '-9999px'; // Move outside the screen to make it invisible
  document.body.appendChild(el); // Append the <textarea> element to the HTML document
  var selected =
    document.getSelection().rangeCount > 0 // Check if there is any content selected previously
      ?
      document.getSelection().getRangeAt(0) // Store selection if found
      :
      false; // Mark as false to know no selection existed before
  el.select(); // Select the <textarea> content
  document.execCommand('copy'); // Copy - only works as a result of a user action (e.g. click events)
  document.body.removeChild(el); // Remove the <textarea> element
  if (selected) { // If a selection existed before copying
    document.getSelection().removeAllRanges(); // Unselect everything on the HTML document
    document.getSelection().addRange(selected); // Restore the original selection
  }
}

function copyFileToClipboard() {
  copyToClipboard($('code').text())
}

/* Annotation-specific JS */

// Make the grades in the mini tab editable
function make_editable($editable) {
  // click/enter to edit cells

  /* Calls the Jquery plugin Jeditable to set up the element for in-place editing.
   * When done editing, a request to quickSetScore (on server) is called with the
   * following parameters.
   *
   * Note: Expects editableUrl to be set in javascript already and map to
   * something like url_for ([:quickSetScore, @course, @assessment])
   */
  $editable.editable(editableUrl, {
    name: 'score',
    event: 'click',
    placeholder: "&ndash;",
    select: true, // select all text in score editor on click/enter
    onblur: function () {
    },
    onreset: function (event) {
    },
    onerror: function () {
      // TODO: Display a message on save error
    },
    onsubmit: function () {
      // TODO: Don't submit a score chance if we have it in the cache
      return true;
    },
    submitdata: function (value, settings) {
      requestData = {
        submission_id: $editable.data('submission-id'),
        problem_id: $editable.data('problem-id')
      };
      return requestData;
    },
    callback: function (value, settings) {
      // TODO: Display a success message
    }

  });

}


/* Highlights lines longer than 80 characters autolab red color */
var highlightLines = function (highlight) {
  var highlightColor = "rgba(255, 255, 0, 0.3)"
  $("#code-box > .code-table > .code-line > .code").each(function () {
    var text = $(this).text();
    // To account for lines that have 80 characters and a line break
    var diff = text[text.length - 1] === "\n" ? 1 : 0;
    if (text.length - diff > 80 && highlight) {
      $(this).css("background", highlightColor);
      $(this).prev().css("background", highlightColor);
    } else {
      $(this).css("background", "inherit");
      $(this).prev().css("background", "inherit");
    }
  });
};

$("#highlightLongLines").click(function () {
  highlightLines(this.checked);
});

function displayAnnotations() {
  $(".annotation-line").not(".base-annotation-line").remove();

  _.each(annotationsByPositionByLine[currentHeaderPos], function (arr_annotations, line) {
    _.each(arr_annotations, function (annotationObj, ind) {
      $("#annotation-line-" + line).append(newAnnotationBox(annotationObj));
      refreshAnnotations();
    });
  });
}

function attachEvents() {
  var status = $('#highlightLongLines')[0].checked;
  highlightLines(status);

  $(".add-button").on("click", function (e) {

    e.preventDefault();
    var line = $(this).parent().parent().parent();
    var annotationContainer = line.data("lineId");

    // append an annotation form only if there is none currently
    if ($("#annotation-line-" + annotationContainer).find(".annotation-line").length == 0) {
      $("#annotation-line-" + annotationContainer).append(newAnnotationFormCode());

      refreshAnnotations();
    }

  });
}

var initializeAnnotationsForCode = function () {
  window.annotationMode = "Code";

  annotationsByPositionByLine = {};
  _.each(annotations, function (annotationObj, ind) {
    var lineNumber = annotationObj.line;
    var position = annotationObj.position || 0;

    if (!annotationsByPositionByLine[position]) {
      annotationsByPositionByLine[position] = {};
    }

    var annotationsByLine = annotationsByPositionByLine[position];

    if (!annotationsByLine[lineNumber]) {
      annotationsByLine[lineNumber] = [];
    }

    annotationsByLine[lineNumber].push(annotationObj);
  });

  displayAnnotations();
}


function getProblemNameWithId(problem_id) {
  var problem_id = parseInt(problem_id, 10);
  var problem = _.findWhere(problems, { "id": problem_id });
  if (problem == undefined) return "General";
  return problem.name;
}


// create an HTML element real nice and easy like
function elt(t, a) {
  var el = document.createElement(t);
  if (a) {
    for (var attr in a)
      if (a.hasOwnProperty(attr))
        el.setAttribute(attr, a[attr]);
  }
  for (var i = 2; i < arguments.length; ++i) {
    var arg = arguments[i];
    if (typeof arg === "string")
      arg = document.createTextNode(arg);
    el.appendChild(arg);
  }
  return el;
}


// this creates a JSON representation of what the actual Rails Annotation model looks like
function createAnnotation() {
  var annObj = {
    filename: fileNameStr,
    submitted_by: cudEmailStr,
  };

  if (currentHeaderPos) {
    annObj.position = currentHeaderPos
  }

  return annObj;
}

function newAnnotationFormCode() {
  var box = $(".base-annotation-line").clone();
  box.removeClass("base-annotation-line");

  // Creates a dictionary of problem and grader_id
  var autogradedproblems = {}
  _.each(scores, function (score) {
    autogradedproblems[score.problem_id] = score.grader_id;
  })

  _.each(problems, function (problem) {
    if (autogradedproblems[problem.id] != 0) { // Because grader == 0 is autograder
      box.find("select").append(
        $("<option />").val(problem.id).text(problem.name)
      )
    }
  })

  box.find('.annotation-form').show();
  box.find('.annotation-cancel-button').click(function (e) {
    e.preventDefault();
    $(this).parent().parent().parent().parent().remove();
    refreshAnnotations();
  })

  box.find('.annotation-form').submit(function (e) {
    e.preventDefault();
    var comment = $(this).find(".comment").val();
    var score = $(this).find(".score").val();
    var problem_id = $(this).find(".problem-id").val();
    var line = $(this).parent().parent().data("lineId");

    if (comment == undefined || comment == "") {
      box.find('.error').text("Annotation comment can not be blank!").show();
      return;
    }

    if (problem_id == undefined) {
      if ($('.select').children('option').length > 0)
        box.find('.error').text("Problem not selected").show();
      else
        box.find('.error').text("There are no non-autograded problems. Create a new one at Edit Assessment > Problems").show();
      return;
    }


    submitNewAnnotation(comment, score, problem_id, line, $(this));
  });

  return box;
}

function getAnnotationObject(annotationId) {
  for (var i = 0; i < annotations.length; i++) {
    if (annotations[i].id == annotationId) {
      return annotations[i];
    }
  }
}

function initializeBoxForm(box, annotation) {
  var problemStr = annotation.problem_id;
  var valueStr = annotation.value ? annotation.value.toString() : "0";
  var commentStr = annotation.comment;

  _.each(problems, function (problem) {
    box.find("select").append(
      $("<option />").val(problem.id).text(problem.name)
    )
  });

  box.find(".comment").val(commentStr);
  box.find(".score").val(valueStr);
  box.find(".problem-id").val(problemStr);
  box.find('input[type=submit]').val("Update annotation");

  box.find('.annotation-cancel-button').click(function (e) {
    e.preventDefault();
    $(this).parent().parent().parent().parent().remove();
    displayAnnotations();
  })

  box.find('.annotation-form').submit(function (e) {
    e.preventDefault();
    var comment = $(this).find(".comment").val();
    var score = $(this).find(".score").val();
    var problem_id = $(this).find(".problem-id").val();

    if (comment == undefined || comment == "") {
      box.find('.error').text("Annotation comment can not be blank!").show();
      return;
    }

    var annotationObject = getAnnotationObject(box.data('annotationId'));
    annotationObject.comment = comment;
    annotationObject.value = score;
    annotationObject.problem_id = problem_id;

    updateAnnotation(annotationObject, box);
  });
}

// this creates the HTML to display an annotation.
function newAnnotationBox(annotation) {

  var box = $(".base-annotation-line").clone();
  box.removeClass("base-annotation-line");

  var problemStr = annotation.problem_id ? getProblemNameWithId(annotation.problem_id) : "General";
  var valueStr = annotation.value ? annotation.value.toString() : "0";
  valueStr = plusFix(valueStr);
  var commentStr = annotation.comment;

  if (annotation.value < 0) {
    box.find('.value').parent().removeClass('positive').addClass('negative');
  }

  box.find('.submitted_by').text(annotation.submitted_by);
  box.find('.comment').text(commentStr);
  box.find('.problem_id').text(problemStr);
  box.find('.value').text(valueStr);

  if (isInstructor) {
    box.find('.instructors-only').show();
  }

  box.find('.annotation-box').show().css('width', '100%');
  box.data("annotationId", annotation.id);
  box.find('.annotation-delete-button').data("annotationId", annotation.id);

  box.find('.annotation-edit-button').on('click', function (e) {
    e.preventDefault();
    box.find('.annotation-box').hide();
    box.find('.annotation-form').show().css('width', '100%');
    refreshAnnotations();
  })

  box.find('.annotation-delete-button').on("click", function (e) {
    e.preventDefault();
    if (!confirm("Are you sure you want to delete this annotation?")) return;
    var annotationIdData = $(this).data('annotationId');
    var annotation = null;
    var annotationId = -1;

    for (var i = 0; i < annotations.length; i++) {
      if (annotations[i].id == annotationIdData) {
        annotation = annotations[i];
        annotationId = i;
        break;
      }
    }

    if (annotation == null) return;

    $.ajax({
      url: deletePath(annotation),
      type: 'DELETE',
      complete: function () {
        annotations.splice(annotationId, 1);
        initializeAnnotationsForCode();
        fillAnnotationBox();
      }
    });
  });

  initializeBoxForm(box, annotation);

  return box;
}

function newAnnotationBoxForPDF(annObj) {

  var problemStr = annObj.problem_id ? getProblemNameWithId(annObj.problem_id) : "General";
  var valueStr = annObj.value ? annObj.value.toString() : "None";
  var commentStr = annObj.comment;

  var grader = elt("span", {
    class: "grader"
  }, annObj.submitted_by + " says:");

  var edit = elt("span", {
    class: "edit",
    id: "edit-ann-" + annObj.id
  }, elt("i", { class: "material-icons" }, "edit"));

  var score = elt("div", {
    class: "score-box"
  },
    elt("div", {}, "Problem: " + problemStr),
    elt("div", {}, "Score: " + valueStr));

  var del = elt("span", {
    class: "delete"
  }, elt("i", { class: "material-icons" }, "delete"));

  var minimize = elt("span", {
    class: "minimize"
  }, elt("i", { class: "material-icons" }, "minimize"));

  var maximize = elt("span", {
    class: "maximize"
  }, elt("i", { class: "material-icons" }, "all_out"));

  if (isInstructor) {
    var header = elt("div", {
      class: "header"
    }, grader, minimize, del, edit);
  } else {
    var header = elt("div", {
      class: "header"
    }, grader, minimize);
  }

  var body = elt("div", {
    class: "body"
  }, commentStr);

  var box = elt("div", {
    class: "ann-box",
    id: "ann-box-" + annObj.id
  }, header, body, score, maximize);

  $(maximize).hide(); // Hides the maximize button at the start

  // Delete button
  $(del).on("click", function (e) {
    var annotationIdData = annObj.id;
    var annotation = null;
    var annotationId = -1;

    for (var i = 0; i < annotations.length; i++) {
      if (annotations[i].id == annotationIdData) {
        annotation = annotations[i];
        annotationId = i;
        break;
      }
    }

    if (annotation == null) return;

    $.ajax({
      url: deletePath(annObj),
      type: 'DELETE',
      complete: function () {
        $(box).remove();
        annotations.splice(annotationId, 1);
        fillAnnotationBox();
      }
    });
    return false;
  });

  $(del).on("mousedown", function (e) {
    return false;
  }); // Prevents dragging and deleting

  // Edit Button
  $(edit).on("click", function (e) {
    $(body).hide();
    $(edit).hide();
    $(score).hide();
    $(minimize).hide();
    var form = newEditAnnotationForm(annObj.line, annObj);
    $(box).draggable('disable');
    $(box).resizable('disable');
    $(box).append(form);
    $(box).width("auto");
    $(box).height("auto");
  });

  $(edit).on("mousedown", function (e) {
    return false;
  }); // Prevents dragging and edting

  // Maximize On Click
  // Shows everything and returns everything to size
  $(maximize).on("click", function (e) {
    $(header).show();
    $(body).show();
    $(edit).show();
    $(score).show();
    $(box).width("200px");
    $(box).height("145px");
    $(box).draggable('enable');
    $(box).resizable('enable');
    $(box).css({ 'opacity': 1, 'cursor': 'default' });
    $(this).hide();
  });

  // Minimize On Click
  // Hides everything, and set opacity to translucent
  // Makes it not draggable and resizable as well
  $(minimize).on("click", function (e) {
    $(header).hide();
    $(body).hide();
    $(edit).hide();
    $(score).hide();
    $(box).width("25px");
    $(box).height("25px");
    $(maximize).show();
    $(box).draggable('disable');
    $(box).resizable('disable');
    $(box).css({ 'opacity': 0.4, 'cursor': 'pointer' });
  });

  $(minimize).on("mousedown", function (e) {
    return false;
  }); // Prevents dragging and minimizing

  return box;
};

var updateAnnotationBox = function (annObj) {

  var problemStr = annObj.problem_id ? getProblemNameWithId(annObj.problem_id) : "General";
  var valueStr = annObj.value ? annObj.value.toString() : "None";
  var commentStr = annObj.comment;

  if (annotationMode === "PDF") {
    $('#ann-box-' + annObj.id).find('.score-box').html("<div>Problem: " + problemStr + "</div><div> Score: " + valueStr + "</div>");
    $("#ann-box-" + annObj.id).find('.body').html(commentStr);
  }
  else {
    $('#ann-box-' + annObj.id).find('.score-box').html("<span>" + problemStr + "</span><span>" + valueStr + "</span>");
  }
  $('#ann-box-' + annObj.id).find('.edit').show();
  $('#ann-box-' + annObj.id).find('.body').show();
  $('#ann-box-' + annObj.id).find('.score-box').show();
  $('#ann-box-' + annObj.id).find('.minimize').show();
  $('#ann-box-' + annObj.id).draggable('enable');
  $('#ann-box-' + annObj.id).resizable('enable');
}

// the current Annotation instance
var currentAnnotation = null;
// the currently examined li
var currentLine = null;

/** this function creates a new/edit annotation form
 * the names of the elements are
 * comment for the comment textarea
 * score for the score field
 * problem for the problem dropdown
 * submit for the submit button
 * cancel for the cancel button
*/
var newAnnotationFormTemplatePDF = function (name, pageInd) {

  var commentLabel = elt("label", {
    for: "comment-textarea",
    class: "active"
  }, "Comment")

  var commentInput = elt("textarea", {
    class: "comment",
    name: "comment",
    maxlength: "255"
  });

  var rowDiv1 = elt("div", {}, commentInput);

  var scoreLabel = elt("label", {
    for: "comment-textarea",
    class: "active"
  }, "Score")

  var scoreInput = elt("input", {
    type: "text",
    name: "score",
  });

  var scoreDiv = elt("div", {
    class: "col s5"
  }, scoreInput);

  var space = elt("div", {
    class: "col s1"
  });

  var problemSelect = elt("select", {
    class: "col s6 browser-default",
    name: "problem",
  }, elt("option"));

  var colDiv2 = elt("div", {
    class: "col",
    style: "width: 100%;"
  }, scoreDiv, space, problemSelect);

  var hr = elt("hr");

  var submitButton = elt("input", {
    type: "submit",
    value: "Add Annotation",
    class: "btn primary small",
    name: "submit"
  });

  var cancelButton = elt("input", {
    type: "button",
    value: "Cancel",
    class: "btn grey small",
    name: "cancel"
  });

  var hr = elt("hr");

  // Creates a dictionary of problem and grader_id
  var autogradedproblems = {}

  _.each(scores, function (score) {
    autogradedproblems[score.problem_id] = score.grader_id;
  })

  _.each(problems, function (problem) {
    if (autogradedproblems[problem.id] != 0) { // Because grader == 0 is autograder
      problemSelect.appendChild(elt("option", {
        value: problem.id
      }, problem.name));
    }
  })

  var newForm = elt("form", {
    title: "Press <Enter> to Submit",
    class: name,
    id: name + "-" + pageInd
  }, commentLabel, rowDiv1, scoreLabel, colDiv2, hr, submitButton, cancelButton);

  return newForm;
}

var newAnnotationFormForPDF = function (pageInd, xCord, yCord) {

  var newForm = newAnnotationFormTemplatePDF("annotation-form", pageInd);

  // Accessing the elements of the form
  var cancelButton = newForm.elements.cancel;
  var submitButton = newForm.elements.submit;

  newForm.onsubmit = function (e) {
    e.preventDefault();

    var comment = newForm.elements.comment.value;
    var value = newForm.elements.score.value;
    var problem_id = newForm.elements.problem.value;

    if (!comment || !problem_id) {
      if (document.getElementsByClassName("form-warning").length == 0)
        newForm.appendChild(elt("div", { class: "form-warning" }));
    }

    if (!comment) {
      $(newForm).find('.form-warning').text("The comment cannot be empty");
      return;
    }

    if (!problem_id) {
      if (newForm.elements.problem.children.length > 1)
        $(newForm).find('.form-warning').text("Problem not selected");
      else
        $(newForm).find('.form-warning').text("There are no non-autograded problems. Create a new one at Edit Assessment > Problems");
      return;
    }

    var xRatio = xCord / $("#page-canvas-" + pageInd).attr('width');
    var yRatio = yCord / $("#page-canvas-" + pageInd).attr('height');

    var widthRatio = 200 / $("#page-canvas-" + pageInd).attr('width');
    var heightRatio = 145 / $("#page-canvas-" + pageInd).attr('height');

    submitNewPDFAnnotation(comment, value, problem_id, pageInd, xRatio, yRatio, widthRatio, heightRatio, newForm);

    return false;
  };

  $(cancelButton).on('click', function (e) {
    $(newForm).remove();
    e.preventDefault();
    return false;
  });

  $(submitButton).on('click', function (e) {
    $(newForm).submit();
    e.preventDefault();
    return false;
  });

  return newForm;
}

var newEditAnnotationForm = function (pageInd, annObj) {
  var valueStr = annObj.value ? annObj.value.toString() : "None";
  var commentStr = annObj.comment;

  var newForm = newAnnotationFormTemplatePDF("annotation-edit-form", pageInd);

  newForm.elements.comment.value = commentStr;
  newForm.elements.score.value = valueStr;
  newForm.elements.problem.value = annObj.problem_id;

  var cancelButton = newForm.elements.cancel;
  var submitButton = newForm.elements.submit;
  submitButton.value = "Update"; //Changing the name of the submit button

  newForm.onsubmit = function (e) {
    e.preventDefault();

    var comment = newForm.elements.comment.value;
    var value = newForm.elements.score.value;
    var problem_id = newForm.elements.problem.value;

    if (!comment || !problem_id) {
      if (document.getElementsByClassName("form-warning").length == 0)
        newForm.appendChild(elt("div", { class: "form-warning" }));
    }

    if (!comment) {
      $(newForm).find('.form-warning').text("The comment cannot be empty");
      return;
    }

    if (!problem_id) {
      if (newForm.elements.problem.children.length > 1)
        $(newForm).find('.form-warning').text("Problem not selected");
      else
        $(newForm).find('.form-warning').text("There are no non-autograded problems. Create a new one at Edit Assessment > Problems");
      return;
    }

    annObj.comment = comment;
    annObj.value = value;
    annObj.problem_id = problem_id
    updateLegacyAnnotation(annObj, pageInd, newForm); //ajax function to update the old boxes

  };

  $(cancelButton).on('click', function () {
    updateAnnotationBox(annObj);
    $(newForm).remove();
  });

  $(submitButton).on('click', function (e) {
    $(newForm).submit();
    e.preventDefault();
    return false;
  });

  return newForm;
}

/* following paths/functions for annotations */
var createPath = basePath + ".json";
var updatePath = function (ann) {
  return [basePath, "/", ann.id, ".json"].join("");
};
var deletePath = updatePath;

// start annotating the coordinate with the given x and y
var showAnnotationFormAtCoord = function (pageInd, x, y) {
  var $page = $("#page-canvas-wrapper-" + pageInd);

  if ($page.length) {
    var newForm = newAnnotationFormForPDF(pageInd, x, y)
    $(newForm).css({ "left": x, "top": y });
    $(newForm).css("background", "white");
    $(newForm).css("padding-bottom", "10px");
    $page.append(newForm);
    $(newForm).on("click", function (e) {
      return false;
    });


    $(newForm).find('.comment').focus();
  }
}

var submitNewPDFAnnotation = function (comment, value, problem_id, pageInd, xRatio, yRatio, widthRatio, heightRatio, newForm) {

  var newAnnotation = createAnnotation();
  newAnnotation.coordinate = [xRatio, yRatio, pageInd, widthRatio, heightRatio].join(',');
  newAnnotation.comment = comment;
  newAnnotation.value = value;
  newAnnotation.problem_id = problem_id;

  var $page = $('#page-canvas-wrapper-' + pageInd);

  $.ajax({
    url: createPath,
    accepts: "json",
    dataType: "json",
    data: {
      annotation: newAnnotation
    },
    type: "POST",
    success: function (data, type) {
      var annotationEl = newAnnotationBoxForPDF(data);
      var xCord = xRatio * $("#page-canvas-" + pageInd).attr('width');
      var yCord = yRatio * $("#page-canvas-" + pageInd).attr('height');
      $(annotationEl).css({ "left": xCord + "px", "top": yCord + "px", "position": "absolute" });
      $page.append(annotationEl);
      makeAnnotationMovable(annotationEl, data, pageInd);
      $(newForm).remove();
      annotations.push(data);
      fillAnnotationBox();
    },
    error: function (result, type) {
      $(newForm).append(elt("div", null, "Failed to Save Annotation!!!"));
    },
    complete: function (result, type) { }
  });

}

/* sets up and calls $.ajax to submit an annotation */
var submitNewAnnotation = function (comment, value, problem_id, lineInd, form) {
  var newAnnotation = createAnnotation();
  newAnnotation.line = parseInt(lineInd);
  newAnnotation.comment = comment;
  newAnnotation.value = value;
  newAnnotation.problem_id = problem_id;
  newAnnotation.filename = fileNameStr;

  if (comment == undefined || comment == "") {
    $(form).find('.error').text("Could not save annotation. Please refresh the page and try again.").show();
    return;
  }

  $(form).find('.error').hide();

  $.ajax({
    url: createPath,
    accepts: "json",
    dataType: "json",
    data: {
      annotation: newAnnotation
    },
    type: "POST",
    success: function (data, type) {
      $(form).parent().remove();
      $("#annotation-line-" + lineInd).append(newAnnotationBox(data));
      refreshAnnotations();

      if (!annotationsByPositionByLine[currentHeaderPos]) {
        annotationsByPositionByLine[currentHeaderPos] = {};
      }

      var annotationsByLine = annotationsByPositionByLine[currentHeaderPos];

      if (!annotationsByLine[lineInd]) {
        annotationsByLine[lineInd] = [];
      }

      annotationsByLine[lineInd].push(data);
      annotations.push(data);
      fillAnnotationBox();
      purgeCurrentPageCache();
    },
    error: function (result, type) {
      $(form).find('.error').text("Could not save annotation. Please refresh the page and try again.").show();
    },
    complete: function (result, type) { }
  });

}

var updateAnnotation = function (annotationObj, box) {
  $(box).find(".error").hide();
  $.ajax({
    url: updatePath(annotationObj),
    accepts: "json",
    dataType: "json",
    data: {
      annotation: annotationObj
    },
    type: "PUT",
    success: function (data, type) {
      $(box).remove();
      displayAnnotations();
      fillAnnotationBox();
      purgeCurrentPageCache();
    },
    error: function (result, type) {
      $(box).find('.error').text("Failed to save changes to the annotation. Please refresh the page and try again.").show();
    },
    complete: function (result, type) { }
  });
}

var updateLegacyAnnotation = function (annotationObj, lineInd, formEl) {

  $.ajax({
    url: updatePath(annotationObj),
    accepts: "json",
    dataType: "json",
    data: {
      annotation: annotationObj
    },
    type: "PUT",
    success: function (data, type) {
      var annotationIdData = annotationObj.id;
      var annotation = null;
      var annotationId = -1;

      for (var i = 0; i < annotations.length; i++) {
        if (annotations[i].id == annotationIdData) {
          annotation = annotations[i];
          annotationId = i;
          break;
        }
      }

      if (annotation != null) annotations.splice(annotationId, 1);
      annotations.push(data);

      updateAnnotationBox(annotationObj);
      $(formEl).remove();
      fillAnnotationBox();
      purgeCurrentPageCache();
    },
    error: function (result, type) {
      $(formEl).append(elt("div", null, "Failed to Save Annotation!!!"));
    },
    complete: function (result, type) { }
  });
}

var makeAnnotationMovable = function (annotationEl, annotationObj) {

  var positionArr = annotationObj.coordinate.split(',');

  var curPageInd = positionArr[2];
  var $page = $("#page-canvas-" + curPageInd);

  var curXCord = parseFloat(positionArr[0]);
  var curYCord = parseFloat(positionArr[1]);
  var curWidth = (positionArr[3] || 120);
  var curHeight = (positionArr[4] || 60);

  $(annotationEl).draggable({
    stop: function (event, ui) {
      var xRatio = ui.position.left / $page.attr('width');
      var yRatio = ui.position.top / $page.attr('height');
      annotationObj.coordinate = [xRatio, yRatio, curPageInd, curWidth, curHeight].join(',');
      updateLegacyAnnotation(annotationObj, null, null);
    }
  });

  $(annotationEl).resizable({
    stop: function (event, ui) {
      var widthRatio = ui.size.width / $page.attr('width');
      var heightRatio = ui.size.height / $page.attr('height');
      annotationObj.coordinate = [curXCord, curYCord, curPageInd, widthRatio, heightRatio].join(',');
      updateLegacyAnnotation(annotationObj, null, null);
    },
    minHeight: 145,
    minWidth: 200
  });

}

var initializeAnnotationsForPDF = function () {
  window.annotationMode = "PDF";

  _.each(annotations, function (annotationObj, ind) {

    if (!annotationObj.coordinate) {
      return;
    }

    var position = annotationObj.position || 0
    if (position != currentHeaderPos) {
      return;
    }

    var positionArr = annotationObj.coordinate.split(',');

    var pageInd = positionArr[2];
    var xCord = parseFloat(positionArr[0]) * $("#page-canvas-" + pageInd).attr('width');
    var yCord = parseFloat(positionArr[1]) * $("#page-canvas-" + pageInd).attr('height');
    var width = (positionArr[3] || 0.4) * $("#page-canvas-" + pageInd).attr('width');
    var height = (positionArr[4] || 0.4) * $("#page-canvas-" + pageInd).attr('height');

    var annotationEl = newAnnotationBoxForPDF(annotationObj);

    $(annotationEl).css({
      "left": xCord + "px", "top": yCord + "px", "position": "absolute",
      "width": width, "height": height
    });

    $("#page-canvas-wrapper-" + pageInd).append(annotationEl);
    makeAnnotationMovable(annotationEl, annotationObj, pageInd);
  });

  if (isInstructor) {
    $(".page-canvas").on("click", function (e) {
      if ($(e.target).hasClass("page-canvas")) {
        var pageCanvas = e.currentTarget;
        var pageInd = parseInt(pageCanvas.id.replace('page-canvas-', ''), 10);
        $('.annotation-form').remove();
        showAnnotationFormAtCoord(pageInd, e.offsetX, e.offsetY);
      }
    });
  }
}

function renderPdf() {
  var canvasContainer = document.getElementById("pdf-doc");
  //
  // Fetch the PDF document from the URL using promises
  //

  var renderUrl = newFile.pdfUrl;
  if (newFile.previewMode) renderUrl = newFile.annotatedPdfUrl;

  PDFJS.getDocument(renderUrl).then(function (pdf) {
    var nmrPages = pdf.pdfInfo.numPages;

    for (var i = 1; i <= nmrPages; i++) {
      // Using promise to fetch the page
      var nmrPagesRendered = 0;
      pdf.getPage(i).then(function (page) {
        var scale = 1.3;
        var viewport = page.getViewport(scale);

        //
        // Prepare canvas using PDF page dimensions
        //
        var div = document.createElement('div');
        div.id = "page-canvas-wrapper-" + page.pageIndex;
        div.className = "page-canvas-wrapper";

        var canvas = document.createElement('canvas');
        canvas.id = "page-canvas-" + page.pageIndex;
        canvas.className = "page-canvas"

        var ctx = canvas.getContext('2d');
        var renderContext = {
          canvasContext: ctx,
          viewport: viewport
        };

        canvas.height = viewport.height;
        canvas.width = viewport.width;

        div.appendChild(canvas);
        div.style.width = Math.floor(viewport.width) + "px";

        canvasContainer.appendChild(div);

        page.render(renderContext);
        nmrPagesRendered = nmrPagesRendered + 1;

        if (nmrPagesRendered == nmrPages) {
          initializeAnnotationsForPDF();
        }
      });


    }
  }).catch(function (error) {
    //no error message is logged either
    console.log("Error occurred", error);
  });
}
