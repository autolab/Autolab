/* File Tree and Code Viewer Helper Functions */

// Lets us open and close file folders
function switchFolderState(folderElement) {
  folderElement.toggleClass('active')
}

function refreshAnnotations() {
  $(".annotation-line .line-sticky").each(function () {
    $(this).height($(this).parent().height())
  })
}

// Updates active tags to set the specified file
function setActiveFilePos(headerPos){
  currentHeaderPos = headerPos;
  $('.file.active').removeClass("active")
  rootFiles.each(function(_, file) {
    setActiveFilePosHelper($(file), headerPos);
  })
  $('.file-list').scrollTo($('.file.active'))
}

function setActiveFilePosHelper(elem, headerPos){
  if(elem.data("header_position") == headerPos){
    elem.addClass("active")
    return true
  }
  if ((elem.children().filter(function() {
        return setActiveFilePosHelper($(this), headerPos)
      })).size() > 0){
    elem.children(".folder-name").addClass("active")
    return true
  }
  return false
}

// Scroll to a specific line in the codeviewer
function scrollToLine(n){
  $('.code-table').scrollTo($('#line-'+(n-1)), {duration: "fast"})
}

function plusFix(n) {
  n = parseInt(n)

  if (n > 0) {
    return "+" + n.toFixed(1)
  }

  return n.toFixed(1)
}

// Sets up the keybindings
$(document).keydown(function(e) {
    switch(e.which) {
        case 37: // left - navigate to the previous submission
        $('#prev_submission_link')[0].click()
        break;

        case 38: // up - navigate to the previous file by DOM position
          var testPos = allFilesFolders.index($('.file.active')) - 1
          while(testPos > -1){
            var testElem = $(allFilesFolders.get(testPos))
            if(testElem.data("header_position") != undefined){
              testElem.click()
              break
            }
            testPos -= 1
          }
        break;

        case 39: // right - navigate to the next submission
        $('#next_submission_link')[0].click()
        break;

        case 40: // down - navigate to the next file by DOM position
          var testPos = allFilesFolders.index($('.file.active')) + 1
          while(testPos < allFilesFolders.length){
            var testElem = $(allFilesFolders.get(testPos))
            if(testElem.data("header_position") != undefined){
              testElem.click()
              break
            }
            testPos += 1
          }
        break;

        default: return; // exit this handler for other keys
    }
    e.preventDefault(); // prevent the default action (scroll / move caret)
});


/* Highlights lines longer than 80 characters autolab red color */
var highlightLines = function(highlight) {
  var highlightColor = "rgba(200, 200, 0, 0.9)"
  $("#code-list > li > code").each(function() {
    var text = $(this).text();
    // To account for lines that have 80 characters and a line break
    var diff = text[text.length - 1] === "\n" ? 1 : 0;
    if (text.length - diff > 80 && highlight) {
      $(this).css("background-color", highlightColor);
      $(this).prev().css("background-color", highlightColor);
    } else {
      $(this).css("background-color", "white");
      $(this).prev().css("background-color", "white");
    }
  });
};

$("#highlightLongLines").click(function() {
  highlightLines(this.checked);
});

function displayAnnotations() {
  $(".annotation-line").not(".base-annotation-line").remove();

  _.each(annotationsByPositionByLine[currentHeaderPos], function(arr_annotations, line) {
    _.each(arr_annotations, function(annotationObj, ind) {
      $("#annotation-line-" + line).append(newAnnotationBox(annotationObj));
      refreshAnnotations();
    });
  });
}

function attachEvents() {
  $(".add-button").on("click", function(e) {
    e.preventDefault();
    var line = $(this).parent().parent().parent();
    var annotationContainer = line.data("lineId");
    $("#annotation-line-" + annotationContainer).append(newAnnotationFormCode());

    refreshAnnotations();
  });
}

var initializeAnnotationsForCode = function() {
  window.annotationMode = "Code";

  annotationsByPositionByLine = {};
  _.each(annotations, function(annotationObj, ind) {
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
    var problem = _.findWhere(problems, {"id":problem_id});
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

    _.each(problems, function(problem) {
      box.find("select").append(
        $("<option />").val(problem.id).text(problem.name)
      )
    });

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

    _.each(problems, function(problem) {
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

    var problemStr = annotation.problem_id? getProblemNameWithId(annotation.problem_id) : "General";
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

    box.find('.annotation-delete-button').on("click", function(e) {
        e.preventDefault();
        if (!confirm("Are you sure you want to delete this annotation?")) return;
        var annotationIdData = $(this).data('annotationId');
        var annotation = null;
        var annotationId = -1;

        console.log(annotationIdData);
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
          complete: function() {
            annotations.splice(annotationId, 1);
            initializeAnnotationsForCode();
          }
        });
    });

    initializeBoxForm(box, annotation);

    return box;
  }

  function newAnnotationBoxForPDF(annObj) {

    var problemStr = annObj.problem_id? getProblemNameWithId(annObj.problem_id) : "General";
    var valueStr = annObj.value? annObj.value.toString() : "None";
    var commentStr = annObj.comment;

    var grader = elt("span", {
      class: "grader"
    }, annObj.submitted_by + " says:");
    var edit = elt("span", {
      class: "edit",
      id: "edit-ann-" + annObj.id
    }, elt("i", {class: "material-icons"}, "edit"));

    var score = elt("div", {
      class: "score-box"
    }, elt("div", {}, "Problem: " + problemStr), elt("div", {}, "Score: " + valueStr));

    var del = elt("span", {
      class: "delete"
    }, elt("i", {class: "material-icons"}, "delete"));

    // I (tjjohans) am keeping the minimize feature commented out because I'd
    // like to use it in the near future. Delete if it's convenient to you, or
    // come complain to me about leaving dead code lying around
    /*var min = elt("span", {
      class: "delete"
    }, elt("i", {class: "material-icons"}, "remove"));*/

    if (isInstructor) {
      var header = elt("div", {
        class: "header"
      //}, grader, del, edit, min);
      }, grader, del, edit);
    } else {
      var header = elt("div", {
        class: "header"
      }, grader);
    }

    var body = elt("div", {
      class: "body"
    }, commentStr);

    var box = elt("div", {
      class: "ann-box",
      id: "ann-box-" + annObj.id
    }, header, body, score);

    $(del).on("click", function(e) {
      $.ajax({
        url: deletePath(annObj),
        type: 'DELETE',
        complete: function() {
          $(box).remove();
        }
      });
      return false;
    });

    /*$(min).on("click", function(e) {
      $(body).hide();
      $(min).hide();
      $(score).hide();
      return false;
    });*/

    $(edit).on("click", function(e) {
      $(body).hide();
      $(edit).hide();
      $(score).hide();
      var form = newEditAnnotationForm(annObj.line, annObj);
      $(box).append(form);
      //var updateAnnotation = function(annotationObj, lineInd, formEl) {

    });

    return box;

  };

  var updateAnnotationBox = function(annObj) {

    var problemStr = annObj.problem_id? getProblemNameWithId(annObj.problem_id) : "General";
    var valueStr = annObj.value? annObj.value.toString() : "None";
    var commentStr = annObj.comment;

    if (annotationMode === "PDF") {
      $('#ann-box-' + annObj.id).find('.score-box').html("<div>Problem: "+problemStr+"</div><div>Score: "+valueStr+"</div>");
    }
    else {
      $('#ann-box-' + annObj.id).find('.score-box').html("<span>"+problemStr+"</span><span>"+valueStr+"</span>");
    }
    $('#ann-box-' + annObj.id).find('.edit').show();
    $('#ann-box-' + annObj.id).find('.body').show();
    $('#ann-box-' + annObj.id).find('.score-box').show();

  }


  // the current Annotation instance
  var currentAnnotation = null;
  // the currently examined li
  var currentLine = null;

  var newAnnotationFormForPDF = function(pageInd, xCord, yCord) {

    // this section creates the new/edit annotation form that's used everywhere
    var commentInput = elt("textarea", {
      class: "col l11 comment",
      name: "comment",
      placeholder: "Explanation Here",
      maxlength: "255"
    });
    var valueInput = elt("input", {
      class: "col l4",
      type: "text",
      name: "score",
      placeholder: "Score Here"
    });
    var problemSelect = elt("select", {
      class: "col l4 browser-default",
      name: "problem"
    }, elt("option", {
      value: ""
    }, "None"));

    var rowDiv1 = elt("div", {
      class: "row",
      style: "margin-left:4px;"
    }, commentInput);

    var rowDiv2 = elt("div", {
      class: "row",
      style: "margin-left:4px; width: 100%;"
    }, valueInput, problemSelect);

    var submitButton = elt("input", {
      type: "submit",
      value: "Save",
      class: "btn primary small"
    });
    var cancelButton = elt("input", {
      style: "margin-left: 4px;",
      type: "button",
      value: "Cancel",
      class: "btn small"
    });
    var hr = elt("hr");

    _.each(problems, function(problem) {
      problemSelect.appendChild(elt("option", {
        value: problem.id
      }, problem.name));
    })

    var newForm = elt("form", {
      title: "Press <Enter> to Submit",
      class: "annotation-form",
      id: "annotation-form-" + pageInd
    }, rowDiv1, rowDiv2, hr, submitButton, cancelButton);

    newForm.onsubmit = function(e) {
      e.preventDefault();

      var comment = commentInput.value;
      var value = valueInput.value;
      var problem_id = problemSelect.value;

      if (!comment) {
        newForm.appendChild(elt("div", null, "The comment cannot be empty"));
      } else {
        var xRatio = xCord / $("#page-canvas-" + pageInd).attr('width');
        var yRatio = yCord / $("#page-canvas-" + pageInd).attr('height');

        var widthRatio = 200 / $("#page-canvas-" + pageInd).attr('width');
        var heightRatio = 110 / $("#page-canvas-" + pageInd).attr('height');

        submitNewPDFAnnotation(comment, value, problem_id, pageInd, xRatio, yRatio, widthRatio, heightRatio, newForm);
      }
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


  var newEditAnnotationForm = function(lineInd, annObj) {

    var problemStr = annObj.problem_id? getProblemNameWithId(annObj.problem_id) : "General";
    var valueStr = annObj.value? annObj.value.toString() : "None";
    var commentStr = annObj.comment;

    // this section creates the new/edit annotation form that's used everywhere
    var commentInput = elt("input", {
      class: "col l6 comment",
      type: "text",
      name: "comment",
      placeholder: "Comments FLOOP FLAGG BOOP BOOP",
      maxlength: "255",
      value: commentStr
    });

    if (annotationMode === "PDF") {
      var commentInput = elt("textarea", {
        class: "col l12 comment",
        type: "text",
        name: "comment",
        placeholder: "Comments Here",
        maxlength: "255"
      }, commentStr);
    }

    var valueInput = elt("input", {
      class: "col l2",
      type: "text",
      name: "score",
      placeholder: "Score Here",
      value: valueStr
    });
    var problemSelect = elt("select", {
      class: "col l3 browser-default",
      name: "problem"
    }, elt("option", {
      value: ""
    }, "None"));
    var rowDiv = elt("div", {
      class: "row",
      style: "margin-left:4px;"
    }, commentInput, valueInput, problemSelect);


    var submitButton = elt("input", {
      type: "submit",
      value: "Save Changes",
      class: "btn primary small"
    });
    var cancelButton = elt("input", {
      style: "margin-left: 4px;",
      type: "button",
      value: "Cancel",
      class: "btn small"
    });

    _.each(problems, function(problem) {
      problemSelect.appendChild(elt("option", {
        value: problem.id
      }, problem.name));
    })

    $(problemSelect).val(annObj.problem_id);

    var newForm = elt("form", {
      title: "Press <Enter> to Submit",
      class: "annotation-edit-form",
      id: "edit-annotation-form-" + lineInd
    }, rowDiv, submitButton, cancelButton);

    newForm.onsubmit = function(e) {
      e.preventDefault();

      var comment = commentInput.value;
      var value = valueInput.value;
      var problem_id = problemSelect.value;
      if (!comment) {
        newForm.appendChild(elt("div", null, "The comment cannot be empty"));
      } else {
        annObj.comment = comment;
        annObj.value = value;
        annObj.problem_id = problem_id
        updateAnnotation(annObj, lineInd, newForm);
      }
    };

    $(cancelButton).on('click', function() {
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
  var updatePath = function(ann) {
    return [basePath, "/", ann.id, ".json"].join("");
  };
  var deletePath = updatePath;

// start annotating the coordinate with the given x and y
var showAnnotationFormAtCoord = function(pageInd, x, y) {
  var $page = $("#page-canvas-wrapper-" + pageInd);

  if ($page.length) {
      var newForm = newAnnotationFormForPDF(pageInd, x, y)
      $(newForm).css({ "left" : x, "top" : y});
      $page.append(newForm);
      $(newForm).on("click", function(e) {
        return false;
      });


      $(newForm).find('.comment').focus();
  }
}

var submitNewPDFAnnotation = function(comment, value, problem_id, pageInd, xRatio, yRatio, widthRatio, heightRatio, newForm) {

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
    success: function(data, type) {
      var annotationEl = newAnnotationBoxForPDF(data);
      var xCord = xRatio * $("#page-canvas-" + pageInd).attr('width');
      var yCord = yRatio * $("#page-canvas-" + pageInd).attr('height');
      $(annotationEl).css({ "left": xCord + "px",  "top" : yCord + "px", "position" : "absolute" });
      $page.append(annotationEl);
      makeAnnotationMovable(annotationEl, data, pageInd);
      $(newForm).remove();
    },
    error: function(result, type) {
      $(newForm).append(elt("div", null, "Failed to Save Annotation!!!"));
    },
    complete: function(result, type) {}
  });

}

/* sets up and calls $.ajax to submit an annotation */
var submitNewAnnotation = function(comment, value, problem_id, lineInd, form) {
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
    success: function(data, type) {
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
    },
    error: function(result, type) {
      $(form).find('.error').text("Could not save annotation. Please refresh the page and try again.").show();
    },
    complete: function(result, type) {}
  });

}

  var updateAnnotation = function(annotationObj, box) {
    $(box).find(".error").hide();
    $.ajax({
      url: updatePath(annotationObj),
      accepts: "json",
      dataType: "json",
      data: {
        annotation: annotationObj
      },
      type: "PUT",
      success: function(data, type) {
        $(box).remove();
        displayAnnotations();
      },
      error: function(result, type) {
        $(box).find('.error').text("Failed to save changes to the annotation. Please refresh the page and try again.").show();
      },
      complete: function(result, type) {}
    });
  }

var makeAnnotationMovable = function(annotationEl, annotationObj) {

    var positionArr = annotationObj.coordinate.split(',');

    var curPageInd  = positionArr[2];
    var $page =  $("#page-canvas-" + curPageInd);

    var curXCord = parseFloat(positionArr[0]);
    var curYCord = parseFloat(positionArr[1]);
    var curWidth = (positionArr[3] || 120);
    var curHeight = (positionArr[4] || 60);

    $(annotationEl).draggable({
      stop: function( event, ui ) {
        var xRatio = ui.position.left / $page.attr('width');
        var yRatio = ui.position.top / $page.attr('height');
        annotationObj.coordinate = [xRatio, yRatio, curPageInd, curWidth, curHeight].join(',');
        updateAnnotation(annotationObj, null, null);
      }
    });

    $(annotationEl).resizable({
      stop: function( event, ui ) {
        var widthRatio = ui.size.width / $page.attr('width');
        var heightRatio = ui.size.height / $page.attr('height');
        annotationObj.coordinate = [curXCord, curYCord, curPageInd, widthRatio, heightRatio].join(',');
        updateAnnotation(annotationObj, null, null);
      }
    });

}

var initializeAnnotationsForPDF = function() {
  window.annotationMode = "PDF";

  _.each(annotations, function(annotationObj, ind) {

    if (!annotationObj.coordinate) {
      return;
    }

    var positionArr = annotationObj.coordinate.split(',');

    var pageInd  = positionArr[2];
    var xCord = parseFloat(positionArr[0]) * $("#page-canvas-" + pageInd).attr('width');
    var yCord = parseFloat(positionArr[1]) * $("#page-canvas-" + pageInd).attr('height');
    var width = (positionArr[3] || 0.4) * $("#page-canvas-" + pageInd).attr('width');
    var height = (positionArr[4] || 0.2) * $("#page-canvas-" + pageInd).attr('height');

    var annotationEl = newAnnotationBoxForPDF(annotationObj);

    $(annotationEl).css({ "left": xCord + "px",  "top" : yCord + "px", "position" : "absolute",
                          "width": width, "height": height });

    $("#page-canvas-wrapper-"+pageInd).append(annotationEl);
    makeAnnotationMovable(annotationEl, annotationObj, pageInd);

  });

  $(".page-canvas").on("click", function(e) {
    if ($(e.target).hasClass("page-canvas")) {
      var pageCanvas = e.currentTarget;
      var pageInd = parseInt(pageCanvas.id.replace('page-canvas-',''), 10);
      $('.annotation-form').remove();
      showAnnotationFormAtCoord(pageInd, e.offsetX, e.offsetY);
    }

  });

}
