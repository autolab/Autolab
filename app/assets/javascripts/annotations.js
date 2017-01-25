/* Highlights lines longer than 80 characters autolab red color */
var highlightLines = function(highlight) {
  $("#code-list > li > code").each(function() {
    var text = $(this).text();
    // To account for lines that have 80 characters and a line break
    var diff = text[text.length - 1] === "\n" ? 1 : 0;
    if (text.length - diff > 80 && highlight) {
      $(this).css("background-color", "rgba(153, 0, 0, .9)");
      $(this).prev().css("background-color", "rgba(153, 0, 0, .9)");
    } else {
      $(this).css("background-color", "white");
      $(this).prev().css("background-color", "white");
    }
  });
};

$("#highlightLongLines").click(function() {
  highlightLines(this.checked);
});

var initializeAnnotationsForCode = function() {
  window.annotationMode = "Code";

  var block = document.getElementById('code-block');
  hljs.highlightBlock(block);

  // annotationsByLine: { 'lineNumber': [annotations_array ]}
  annotationsByLine = {};
  _.each(annotations, function(annotationObj, ind) {
    var lineInd = annotationObj.line
    if (!annotationsByLine[lineInd]) {
      annotationsByLine[lineInd] = [];
    }
    annotationsByLine[lineInd].push(annotationObj);
  });

  var lines = document.querySelector("#code-list").children,
    ann;

  _.each(annotationsByLine, function(arr_annotations, lineInd) {
    _.each(arr_annotations, function(annotationObj, ind) {
      $(lines[lineInd - 1]).find(".annotations-container").append(newAnnotationBox(annotationObj));
    });
  });

  /* if you click a line, clean up any '.annotating's and
   * call annotate to set up the annotation.
   */
  $(".add-annotation-btn").on("click", function(e) {
    var btn = e.currentTarget;
    var lineInd = parseInt(btn.id.replace('add-btn-', ''), 10);
    if ($('#annotation-form-' + lineInd).length) {
      $('#annotation-form-' + lineInd).find('.comment').focus();
    } else {
      showAnnotationForm(lineInd);
    }
    e.stopPropagation();
  });

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

    if (headerPositionStr) {
      annObj.position = headerPositionStr
    }

    return annObj;
  }

  // this creates the HTML to display an annotation.
  function newAnnotationBox(annObj) {

    var problemStr = annObj.problem_id? getProblemNameWithId(annObj.problem_id) : "General";
    var valueStr = annObj.value? annObj.value.toString() : "None";
    var commentStr = annObj.comment;

    var grader = elt("span", {
      class: "grader"
    }, annObj.submitted_by + " says:");
    var edit = elt("span", {
      class: "edit glyphicon glyphicon-edit",
      id: "edit-ann-" + annObj.id
    });

    var score = elt("span", {
      class: "score-box"
    }, elt("span", {}, problemStr), elt("span", {}, valueStr));

    var del = elt("span", {
      class: "delete glyphicon glyphicon-remove"
    });

    if (isInstructor) {
      var header = elt("div", {
        class: "header"
      }, grader, del, edit, score);
    } else {
      var header = elt("div", {
        class: "header"
      }, grader, score);
    }

    var body = elt("div", {
      class: "body"
    }, commentStr);

    var box = elt("div", {
      class: "ann-box",
      id: "ann-box-" + annObj.id
    }, header, body)

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

    $(edit).on("click", function(e) {
      $(body).hide();
      $(edit).hide();
      var form = newEditAnnotationForm(annObj.line, annObj);
      $(box).append(form);
      //var updateAnnotation = function(annotationObj, lineInd, formEl) {

    });

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
      class: "edit glyphicon glyphicon-edit",
      id: "edit-ann-" + annObj.id
    });

    var score = elt("div", {
      class: "score-box"
    }, elt("div", {}, "Problem: " + problemStr), elt("div", {}, "Score: " + valueStr));

    var del = elt("span", {
      class: "delete glyphicon glyphicon-remove"
    });

    if (isInstructor) {
      var header = elt("div", {
        class: "header"
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

    $('#ann-box-' + annObj.id).find('.edit').show();
    $('#ann-box-' + annObj.id).find('.body').show();
    if (annotationMode === "PDF") {
      $('#ann-box-' + annObj.id).find('.score-box').html("<div>Problem: "+problemStr+"</div><div>Score: "+valueStr+"</div>");
      $('#ann-box-' + annObj.id).find('.score-box').show();
    }
    else {
      $('#ann-box-' + annObj.id).find('.score-box').html("<span>"+problemStr+"</span><span>"+valueStr+"</span>");
    }

    $('#ann-box-' + annObj.id).find('.body').html(commentStr);

  }


  // the current Annotation instance
  var currentAnnotation = null;
  // the currently examined li
  var currentLine = null;

  var newAnnotationForm = function(lineInd) {

    // this section creates the new/edit annotation form that's used everywhere
    var commentInput = elt("input", {
      class: "col-md-6 comment",
      type: "text",
      name: "comment",
      placeholder: "Comments Here",
      maxlength: "255"
    });
    var valueInput = elt("input", {
      class: "col-md-2",
      type: "text",
      name: "score",
      placeholder: "Score Here"
    });
    var problemSelect = elt("select", {
      class: "col-md-2 browser-default",
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
      id: "annotation-form-" + lineInd
    }, rowDiv, hr, submitButton, cancelButton);

    newForm.onsubmit = function(e) {
      e.preventDefault();

      var comment = commentInput.value;
      var value = valueInput.value;
      var problem_id = problemSelect.value;

      if (!comment) {
        newForm.appendChild(elt("div", null, "The comment cannot be empty"));
      } else {
        submitNewAnnotation(comment, value, problem_id, lineInd, newForm);
      }
    };

    $(cancelButton).on('click', function(e) {
      $(newForm).remove();
      e.preventDefault();
    })

    return newForm;
  }

  var newAnnotationFormForPDF = function(pageInd, xCord, yCord) {

    // this section creates the new/edit annotation form that's used everywhere
    var commentInput = elt("textarea", {
      class: "col-md-11 comment",
      name: "comment",
      placeholder: "Explanation Here",
      maxlength: "255"
    });
    var valueInput = elt("input", {
      class: "col-md-4",
      type: "text",
      name: "score",
      placeholder: "Score Here"
    });
    var problemSelect = elt("select", {
      class: "col-md-4 browser-default",
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
      class: "col-md-6 comment",
      type: "text",
      name: "comment",
      placeholder: "Comments Here",
      maxlength: "255",
      value: commentStr
    });

    if (annotationMode === "PDF") {
      var commentInput = elt("textarea", {
        class: "col-md-12 comment",
        type: "text",
        name: "comment",
        placeholder: "Comments Here",
        maxlength: "255"
      }, commentStr);
    }

    var valueInput = elt("input", {
      class: "col-md-2",
      type: "text",
      name: "score",
      placeholder: "Score Here",
      value: valueStr
    });
    var problemSelect = elt("select", {
      class: "col-md-2",
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
    var hr = elt("hr");

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
    }, rowDiv, hr, submitButton, cancelButton);

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
    })

    return newForm;
  }

  /* following paths/functions for annotations */
  var createPath = basePath + ".json";
  var updatePath = function(ann) {
    return [basePath, "/", ann.id, ".json"].join("");
  };
  var deletePath = updatePath;

  // start annotating the line with the given index
  function showAnnotationForm(lineInd) {
    var $line = $("#line-" + lineInd);

    if ($line.length) {
      var newForm = newAnnotationForm(lineInd)
      $line.append(newForm);
      $(newForm).find('.comment').focus();
    }
  }


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
var submitNewAnnotation = function(comment, value, problem_id, lineInd, formEl) {

  var newAnnotation = createAnnotation();
  newAnnotation.line = lineInd;
  newAnnotation.comment = comment;
  newAnnotation.value = value;
  newAnnotation.problem_id = problem_id;

  var $line = $('#line-' + lineInd);

  $.ajax({
    url: createPath,
    accepts: "json",
    dataType: "json",
    data: {
      annotation: newAnnotation
    },
    type: "POST",
    success: function(data, type) {
      $line.find('.annotations-container').append(newAnnotationBox(data));
      if (!annotationsByLine[lineInd]) {
        annotationsByLine[lineInd] = [];
      }
      annotationsByLine[lineInd].push(data);
      $(formEl).remove();
    },
    error: function(result, type) {
      $(formEl).append(elt("div", null, "Failed to Save Annotation!!!"));
    },
    complete: function(result, type) {}
  });

}

  var updateAnnotation = function(annotationObj, lineInd, formEl) {

    $.ajax({
      url: updatePath(annotationObj),
      accepts: "json",
      dataType: "json",
      data: {
        annotation: annotationObj
      },
      type: "PUT",
      success: function(data, type) {
        updateAnnotationBox(annotationObj);
        $(formEl).remove();
      },
      error: function(result, type) {
        $(formEl).append(elt("div", null, "Failed to Save Annotation!!!"));
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


