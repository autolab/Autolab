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

$(function() {
  var block = document.getElementById('code-block');

  hljs.highlightBlock(block);

  function getProblemNameWithId(problem_id) {
    console.log(problem_id)
    var problem_id = parseInt(problem_id, 10);
    var problem = _.findWhere(problems, {"id":problem_id});
    return problem.name;
  }

  // annotationsByLine: { 'lineNumber': [annotations_array ]}
  var annotationsByLine = {};
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

  // orphan the given node.  Welcome to life, node.
  function oliverTwist(node) {
    node.parentNode.removeChild(node);
  }

  // this creates a JSON representation of what the actual Rails Annotation model looks like
  function createAnnotation(line) {
    var annObj = {
      filename: fileNameStr,
      line: line,
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
    var commentStr = decodeURI(annObj.comment);

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

  var updateAnnotationBox = function(annObj) {

    var problemStr = annObj.problem_id? getProblemNameWithId(annObj.problem_id) : "General";
    var valueStr = annObj.value? annObj.value.toString() : "None";
    var commentStr = decodeURI(annObj.comment);

    $('#ann-box-' + annObj.id).find('.edit').show();
    $('#ann-box-' + annObj.id).find('.body').show();
    $('#ann-box-' + annObj.id).find('.score-box').html("<span>"+problemStr+"</span><span>"+valueStr+"</span>");
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

      submitNewAnnotation(comment, value, problem_id, lineInd, newForm);
    };

    $(cancelButton).on('click', function() {
      $(newForm).remove();
    })

    return newForm;
  }


  var newEditAnnotationForm = function(lineInd, annObj) {

    var problemStr = annObj.problem_id? getProblemNameWithId(annObj.problem_id) : "General";
    var valueStr = annObj.value? annObj.value.toString() : "None";
    var commentStr = decodeURI(annObj.comment);

    // this section creates the new/edit annotation form that's used everywhere
    var commentInput = elt("input", {
      class: "col-md-6 comment",
      type: "text",
      name: "comment",
      placeholder: "Comments Here",
      maxlength: "255",
      value: commentStr
    });
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

      annObj.comment = comment;
      annObj.value = value;
      annObj.problem_id = problem_id
        //function(annotationObj, lineInd, formEl) {
      updateAnnotation(annObj, lineInd, newForm);
    };

    $(cancelButton).on('click', function() {
      updateAnnotationBox(annObj);
      $(newForm).remove();
    })

    return newForm;
  }



  // start annotating the line with the given index
  function showAnnotationForm(lineInd) {
    var $line = $("#line-" + lineInd);

    if ($line.length) {
      var newForm = newAnnotationForm(lineInd)
      $line.append(newForm);
      $(newForm).find('.comment').focus();
    }
  }

  /* following paths/functions for annotations */
  var createPath = basePath + ".json";
  var updatePath = function(ann) {
    return [basePath, "/", ann.id, ".json"].join("");
  };
  var deletePath = updatePath;

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


  /* sets up and calls $.ajax to submit an annotation */
  var submitNewAnnotation = function(comment, value, problem_id, lineInd, formEl) {

    var newAnnotation = createAnnotation(lineInd);
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
        $(formEl).append("Failed to Save Annotation!!!");
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
        $(formEl).append("Failed to Save Annotation!!!");
      },
      complete: function(result, type) {}
    });
  }

});