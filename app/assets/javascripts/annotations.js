/* Document On Ready Initializations */

$(document).ready(function () {
  $('.skip-main').remove(); // removes skip main anchor tag
  $('.collapsible').collapsible({ accordion: false });
  //get line number in URL, if it exists
  var urlParams = new URLSearchParams(location.search);

  if (urlParams.has("line")) {
    scrollToLine(urlParams.get("line"));
  }
  if (!newFile.pdf) {
    purgeCurrentPageCache();
  }

  retrieveSharedComments();
  resizeCodeTable();
  resizeGradeList();
});

/* On Window Resize */
$(window).on('resize', function () {
  resizeCodeTable();
  resizeGradeList();
});

function getSharedCommentsForProblem(problem_id) {
  return localCache['shared_comments'][problem_id]?.map(
    (annotation) => {
      return {label: annotation.comment ?? annotation, value: annotation}
    }
  )
}

const selectAnnotation = box => (e, ui) => {
  const {label, value} = ui.item;

  const score = value.value ?? 0;
  box.find('#comment-score').val(score);

  const $textarea = box.find("#comment-textarea");
  M.textareaAutoResize($textarea);

  return false;
}

function focusAnnotation( event, ui ) {
  $(this).val(ui.item.label);
  return false;
}

// retrieve shared comments
// also retrieves annotation id to allow easy deletion in the future
function retrieveSharedComments() {
  $.getJSON(sharedCommentsPath, function (data) {
    localCache['shared_comments'] = {};
    data.forEach(e => {
      if (!e.problem_id)
        return;
      localCache['shared_comments'][e.problem_id] ||= [];
      localCache['shared_comments'][e.problem_id].push(e);
    });
  });
}

function resizeCodeTable() {
  // Resize code table if announcements are shown
  if ($(".announcement.gray-box").length > 0) {
    // Value determined empirically, so that the values below match those in annotations.scss
    const baseHeight = $(window).height() - $(".announcement.gray-box").height() - 17;
    const CODE_TABLE_OFFSET = 260;
    const DIFF_VIEWER_OFFSET = 235;
    const SPEEDGRADER_OFFSET = 178;
    $('.code-table').css("max-height", baseHeight - CODE_TABLE_OFFSET);
    $('#diff-viewer .d2h-file-side-diff').css("max-height", baseHeight - DIFF_VIEWER_OFFSET);
    $('#speedgrader').css("max-height", baseHeight - SPEEDGRADER_OFFSET);
    myLayout.updateSize();
  }
}

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

// Updates relevant elements of the speedgrader when a new file is selected
function loadFile(newFile) {
  // Update the code viewer and symbol tree with the cached data
  $('#code-box').replaceWith(newFile.codeBox);
  $('#symbol-tree-container').replaceWith(newFile.symbolTree);

  // Add syntax highlighting to the new code viewer
  $('pre code').each(function () {
    hljs.highlightBlock(this);
  });

  // Update the page URL
  history.replaceState(null, null, newFile.url);

  // Update version dropdown
  $('#version-dropdown').replaceWith(newFile.versionDropdown);

  // Update version buttons
  $('#version-links').replaceWith(newFile.versionLinks);

  // Update diff viewer
  $('#diff-box').replaceWith(newFile.diffBox);

  displayAnnotations();
  attachEvents();
  drawDiffViewer();
}

// Returns true if the file was cached, false otherwise
function changeFile(headerPos) {
  $('#code-box').addClass('loading');
  setActiveFilePos(headerPos);

  // If we've cached this file locally, just get it
  if (localCache[headerPos] !== undefined) {
    newFile = localCache[headerPos];
    loadFile(newFile);
    return true;
  }
  return false;
}

function purgeCurrentPageCache() {
  localCache[currentHeaderPos] = {
    codeBox: `<div id="code-box">${$('#code-box').html()}</div>`,
    pdf: false,
    symbolTree: `<div id="symbol-tree-container">${$('#symbol-tree-container').html()}</div>`,
    versionLinks: `<span id="version-links">${$('#version-links').html()}</span>`,
    versionDropdown: `<span id="version-dropdown">${$('#version-dropdown').html()}</span>`,
    diffBox: `<div id="diff-box">${$('#diff-box').html()}</div>`,
    url: window.location.href
  };
}

// Updates active tags to set the specified file
function setActiveFilePos(headerPos) {
  currentHeaderPos = headerPos;
  $('.file.active').removeClass("active");
  const rootFiles = $('.file-list').children();
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

// Go to a specific line in the codeviewer
// Where n is the line number
function scrollToLine(n) {
  $('.code-table').scrollTo($('#line-' + (n - 1)), { duration: "fast" })
}

function plusFix(n) {
  n = parseFloat(n)
  if (isNaN(n)) n = 0;

  if (n > 0) {
    return "+" + n.toFixed(2);
  }

  return n.toFixed(2);
}

// function called after create, update & delete of annotations
function fillAnnotationBox() {
  retrieveSharedComments();
  $('#loadScreen').css('display', 'flex');
  $.get(document.URL, function(data) {
    const $page = $('<div />').html(data);
    $('.problemGrades').html($page.find('.problemGrades'));
    $('#annotationPane').html($page.find(' #annotationPane'));
    $('.collapsible').collapsible({ accordion: false });
    $('#release-grades').html($page.find('#release-grades'));
    $('#loadScreen').hide();
    attachChangeFileEvents();
    attachAnnotationPaneEvents();
  });
}

// Sets up the keybindings
$(document).keydown(function (e) {
  if (!$(e.target).is('body')) {
    return true;
  }

  const allFilesFolders = $('.file-list').find("*");

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

    case 219: // left square bracket - navigate to the previous version containing this file
      $('#prev_version_link')[0].click();
      break;

    case 221: // right square bracket - navigate to the next version containing this file
      $('#next_version_link')[0].click();
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


/* Highlights lines longer than 80 characters Autolab red color */
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

function displayAnnotations() {

  $(".annotation-line").not(".base-annotation-line").remove();

  _.each(annotationsByPositionByLine[currentHeaderPos], function (arr_annotations, line) {
    _.each(arr_annotations, function (annotationObj, ind) {
      if (annotationObj.global_comment)
        return;
      $("#annotation-line-" + line).append(newAnnotationBox(annotationObj));
    });
  });

  refreshAnnotations();
}

function attachEvents() {
  $("#highlightLongLines").click(function () {
    highlightLines(this.checked);
  });

  var status = $('#highlightLongLines')[0].checked;
  highlightLines(status);

  $(".add-button").on("click", function (e) {
    e.preventDefault();
    const line = $(this).parent().parent().parent();
    const annotationContainer = line.data("lineId");

    // Allow multiple annotations per line
    // However, only allow one annotation to be created per line at a time
    const $annotationLine = $("#annotation-line-" + annotationContainer);
    if ($annotationLine.find(".new-annotation").length === 0) {
      $annotationLine.append(newAnnotationFormCode());
      $('.code-table').scrollTo($annotationLine.children().last(), { duration: "fast" });
      refreshAnnotations();
    } else {
      M.toast({html: 'Only one annotation can be created per line at a time!'});
    }
  });
}

function attachChangeFileEvents() {
  // Set up file switching to use the local cache
  function changeFileClickHandler(e) {
    const targetHeader = $(this).data("header_position");
    const wasCachedLocally = (targetHeader === currentHeaderPos) || changeFile(targetHeader);
    if (wasCachedLocally) {
      e.preventDefault();
      if ($(this).data("line")) {
        scrollToLine($(this).data("line"));
      }
      return false;
    }
    return true;
  }
  $(".file").off();
  $(".descript-link").off();

  $(".file").on("click", changeFileClickHandler);
  $(".descript-link").on("click", changeFileClickHandler);
}

// Events that deal with the annotation pane
function attachAnnotationPaneEvents() {
  // Add action
  $(".global-annotation-add-button").on("click", function (e) {
    e.preventDefault();
    if ($('#loadScreen').css('display') === 'flex') return;
    const problem = $(this).data("problem");
    const $headerDiv = $(this).parent().parent();

    if (!$headerDiv.next().hasClass("global-annotation-form")) {
      $headerDiv.after(globalAnnotationFormCode(true, { problem }));
    }
  });

  // Edit action
  $(".global-annotation-edit-button").on("click", function (e) {
    e.preventDefault();
    if ($('#loadScreen').css('display') === 'flex') return;
    const problem = $(this).parent().data("problem");
    const score = $(this).parent().data("score");
    const comment = $(this).parent().data("comment");
    const annotationId = $(this).parent().data("annotationid");
    const shared = $(this).parent().data("shared");
    const $annotationDiv = $(this).parents(".global-annotation");

    if (!$annotationDiv.next().hasClass("global-annotation-form")) {
      $annotationDiv.after(globalAnnotationFormCode(false, { problem, score, comment, annotationId, shared }));
    }
  });

  // Delete action for global annotations
  $('.global-annotation-delete-button').on("click", function (e) {
    e.preventDefault();
    if ($('#loadScreen').css('display') === 'flex') return;
    if (!confirm("Are you sure you want to delete this annotation?")) return;
    const annotationIdData = $(this).parent().data('annotationid');
    const annotationId = annotations.findIndex((e) => e.id === annotationIdData);

    if (annotationId === -1) return;

    const annotation = annotations[annotationId];

    $.ajax({
      url: deletePath(annotation),
      type: 'DELETE',
      complete: function () {
        annotations.splice(annotationId, 1);
        fillAnnotationBox();
      }
    });
  });

  // Chevron events (collapse / show problem)
  $('.collapsible-header-controls .collapse-icon, .collapsible-header-controls .expand-icon').on('click', function(e) {
    e.preventDefault();
    if ($('#loadScreen').css('display') === 'flex') return;
    $(e.target).closest(".collapsible-header-wrap").find(".collapsible-header").click();
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
  if (problem == undefined) return "Deleted Problem(s)";
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
  };

  if (currentHeaderPos || currentHeaderPos === 0) {
    annObj.position = currentHeaderPos
  }

  return annObj;
}

function newAnnotationFormCode() {
  var box = $(".base-annotation-line").clone();
  box.removeClass("base-annotation-line");

  // Allow us to enforce the creation of one annotation per line at a time
  box.addClass("new-annotation");

  // Creates a dictionary of problem and grader_id
  var problemGraderId = {};
  _.each(scores, function (score) {
    problemGraderId[score.problem_id] = score.grader_id;
  });

  var processStarred = false;
  _.each(problems, function (problem) {
    if (problemGraderId[problem.id] !== 0) { // Because grader == 0 is autograder
      if(problem.starred && !processStarred){
        box.find('select').append(
            $('<option disabled></option>').text('Starred Problems')
        );
        processStarred=true;
      }
      if(!problem.starred && processStarred){
        box.find('select').append(
            $('<option disabled></option>').text('-------------------')
        );
        processStarred=false;
      }
      box.find("select").append(
          $("<option />").val(problem.id).text(problem.name)
      );
    }
  });

  box.find('.annotation-form').show();
  box.find('.annotation-cancel-button').click(function (e) {
    e.preventDefault();
    $(this).parents(".annotation-form").parent().remove();
    refreshAnnotations();
  })

  box.find('#comment-textarea').autocomplete({
    appendTo: box.find('#comment-textarea').parent(),
    source: getSharedCommentsForProblem(box.find("select").val()) || [],
    minLength: 0,
    delay: 0,
    select: selectAnnotation(box),
    focus: focusAnnotation
  }).focus(function () {
    M.textareaAutoResize($(this));
    $(this).autocomplete('search', $(this).val())
  });

  box.tooltip();

  box.find("select").on('change', function () {
    const problem_id = $(this).val();

    // Update autocomplete to display shared comments for selected problem
    box.find("#comment-textarea").autocomplete({
        source: getSharedCommentsForProblem(problem_id) || []
    });
  });

  box.find('.annotation-form').submit(function (e) {
    e.preventDefault();
    var comment = $(this).find(".comment").val();
    var shared_comment = $(this).find("#shared-comment").is(":checked");
    var score = $(this).find(".score").val();
    var problem_id = $(this).find(".problem-id").val();
    var line = $(this).parent().parent().data("lineId");

    if (comment === undefined || comment === "") {
      box.find('.error').text("Annotation comment can not be blank!").show();
      return;
    }

    if (score === undefined || score === "") {
      box.find('.error').text("Annotation score can not be blank!").show();
      return;
    }

    if (problem_id == undefined) {
      if ($('.select').children('option').length > 0)
        box.find('.error').text("Problem not selected").show();
      else
        box.find('.error').text("There are no non-autograded problems. Create a new one at Edit Assessment > Problems").show();
      return;
    }


    submitNewAnnotation(comment, shared_comment, false, score, problem_id, line, $(this));
  });

  return box;
}

// Create form code to create / update a global annotation
// config takes the following keys: problem, score (for edit), comment (for edit), shared (for edit)
function globalAnnotationFormCode(newAnnotation, config) {
  const box = $(".base-global-annotation-form").clone();
  box.removeClass("base-global-annotation-form");

  if (!newAnnotation) {
    box.find(".annotation-form-header").text("Update global annotation");
    box.find(".comment").val(config.comment);
    box.find(".score").val(config.score);
    box.find("#shared-comment").prop("checked", config.shared);
    box.find('input[type=submit]').val("Update annotation");
  }

  var problemNameToIdMap = {};
  _.each(problems, function (problem) {
    problemNameToIdMap[problem.name] = problem.id;
  })

  box.find(".annotation-form-header").show();
  box.find('.annotation-form').show();
  box.find('.annotation-cancel-button').click(function (e) {
    e.preventDefault();
    $(this).parents(".annotation-form").parent().remove();
  })

  box.find('#comment-textarea').autocomplete({
    appendTo: box.find('#comment-textarea').parent(),
    minLength: 0,
    delay: 0,
    source: getSharedCommentsForProblem(problemNameToIdMap[config.problem]) || [],
    select: selectAnnotation(box),
    focus: focusAnnotation
  }).focus(function () {
    M.textareaAutoResize($(this));
    $(this).autocomplete('search', $(this).val())
  });

  M.textareaAutoResize(box.find('#comment-textarea'));

  box.tooltip();

  box.find('.annotation-form').submit(function (e) {
    e.preventDefault();
    var comment = $(this).find(".comment").val();
    var shared_comment = $(this).find("#shared-comment").is(":checked");
    var score = $(this).find(".score").val();
    var problem_id = problemNameToIdMap[config.problem];

    if (comment === undefined || comment === "") {
      box.find('.error').text("Annotation comment can not be blank!").show();
      return;
    }

    if (score === undefined || score === "") {
      box.find('.error').text("Annotation score can not be blank!").show();
      return;
    }

    if (newAnnotation) {
      submitNewAnnotation(comment, shared_comment, true, score, problem_id, 0, $(this));
    } else {
      const annotationObject = getAnnotationObject(config.annotationId);
      Object.assign(annotationObject, { comment, value: score, problem_id, shared_comment, global_comment: true });

      updateAnnotation(annotationObject, box);
    }
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

  // Creates a dictionary of problem and grader_id
  var problemGraderId = {};
  _.each(scores, function (score) {
    problemGraderId[score.problem_id] = score.grader_id;
  });

  var processStarred = false;
  _.each(problems, function (problem) {
    if (problemGraderId[problem.id] !== 0) { // Because grader == 0 is autograder
      if(problem.starred && !processStarred){
        box.find('select').append(
            $('<option disabled></option>').text('Starred Problems')
        );
        processStarred=true;
      }
      if(!problem.starred && processStarred){
        box.find('select').append(
            $('<option disabled></option>').text('-------------------')
        );
        processStarred=false;
      }
      box.find("select").append(
          $("<option />").val(problem.id).text(problem.name)
      );
    }
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
    var shared_comment = $(this).find("#shared-comment").is(":checked");
    var score = $(this).find(".score").val();
    var problem_id = $(this).find(".problem-id").val();

    if (comment === undefined || comment === "") {
      box.find('.error').text("Annotation comment can not be blank!").show();
      return;
    }

    if (score === undefined || score === "") {
      box.find('.error').text("Annotation score can not be blank!").show();
      return;
    }

    var annotationObject = getAnnotationObject(box.data('annotationId'));
    annotationObject.comment = comment;
    annotationObject.value = score;
    annotationObject.problem_id = problem_id;
    annotationObject.shared_comment = shared_comment;
    annotationObject.global_comment = false;

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
  var shared_comment = annotation.shared_comment;

  if (annotation.value < 0) {
    box.find('.value').parent().removeClass('neutral').addClass('negative');
  } else if (annotation.value > 0) {
    box.find('.value').parent().removeClass('neutral').addClass('positive');
  }

  box.find('.submitted_by').text(annotation.submitted_by);
  box.find('.comment').text(commentStr);
  box.find('.problem_id').text(problemStr);
  box.find('.value').text(valueStr);
  box.find('#shared-comment').prop("checked", shared_comment);

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
    
    M.textareaAutoResize(box.find('#comment-textarea'));

    box.find('#comment-textarea').autocomplete({
      appendTo: box.find('#comment-textarea').parent(),
      minLength: 0,
      delay: 0,
      source: getSharedCommentsForProblem(annotation.problem_id) || [],
      select: selectAnnotation(box),
      focus: focusAnnotation,
    }).focus(function () {
      M.textareaAutoResize($(this));
      $(this).autocomplete('search', $(this).val())
    });
    box.tooltip();
    
    refreshAnnotations();
  });

  box.find("select").on('change', function () {
    const problem_id = $(this).val();

    // Update autocomplete to display shared comments for selected problem
    box.find("#comment-textarea").autocomplete({
        source: getSharedCommentsForProblem(problem_id) || [],
    });
  });

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
  }); // Prevents dragging and editing

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

  var br = elt("br");

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

  // Creates a dictionary of problem and grader_id
  var problemGraderId = {};
  _.each(scores, function (score) {
    problemGraderId[score.problem_id] = score.grader_id;
  });

  _.each(problems, function (problem) {
    if (problemGraderId[problem.id] !== 0) { // Because grader == 0 is autograder
      problemSelect.appendChild(elt("option", {
        value: problem.id
      }, problem.name));
    }
  });

  var newForm = elt("form", {
    title: "Press <Enter> to Submit",
    class: name,
    id: name + "-" + pageInd
  }, commentLabel, rowDiv1, scoreLabel, colDiv2, br, submitButton, cancelButton);

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
var sharedCommentsPath = basePath + "/shared_comments";
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
var submitNewAnnotation = function (comment, shared_comment, global_comment, value, problem_id, lineInd, form) {
  var newAnnotation = createAnnotation();
  Object.assign(newAnnotation, { line: parseInt(lineInd), comment, value, problem_id, filename: fileNameStr, shared_comment, global_comment });

  if (comment === undefined || comment === "") {
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

      // Logic to render annotation boxes, not applicable to global annotations
      if (!global_comment) {
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
      }

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
