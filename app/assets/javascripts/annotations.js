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

/* This function takes the contents of the 3 inputs and 
 * turns them into an annotation to be submitted to the server
 */
var getText = function(comment, value, problem) {
  comment = encodeURI(comment);

  if (value) {
    if (problem) {
      return comment + "[" + value + ":" + problem + "]";
    } else {
      return comment + "[" + value + "]";
    }
  } else {
    if (problem) {
      return comment + "[?:" + problem + "]";
    }
  }
  return comment;
}

// given annotation tex, return an array of [comment, value, problem]
var parseText = function(text) {
  var res = text.split("[");
  if (res.length === 1) {
    return [decodeURI(text), "", ""];
  } else {
    res2 = res[1].split(":");
    if (res2.length === 1) {
      return [decodeURI(res[0]), res[1].split("]")[0], ""];
    } else {
      if (res2[0] === "?") {
        return [decodeURI(res[0]), "", res2[1].split("]")[0]];
      } else {
        return [decodeURI(res[0]), res2[0], res2[1].split("]")[0]];
      }
    }
  }
};


$("#highlightLongLines").click(function() {
  highlightLines(this.checked);
});

$(function() {
  var block = document.getElementById('code-block');

  hljs.highlightBlock(block);


  // annotationsByLine: { 'lineNumber': [annotations_array ]}
  var annotationsByLine = {};
  $.each(annotations, function(ind, annotationObj) {
    var lineInd = annotationObj.line
    if (!annotationsByLine[lineInd]) {
      annotationsByLine[lineInd] = [];
    }
    annotationsByLine[lineInd].push(annotationObj);
  });


  var lines = document.querySelector("#code-list").children,
    ann;

  $.each(annotationsByLine, function(lineInd, arr_annotations) {
    $.each(arr_annotations, function(ind, annotationObj) {
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
  function newAnnotationBox(ann) {

    var annObj = ann;
    var parsedAnn = parseText(decodeURI(annObj.text));
    var problemStr = parsedAnn[2] || "General"
    var grader = elt("span", {
      class: "grader"
    }, annObj.submitted_by + " says:");
    var edit = elt("span", {
      class: "edit glyphicon glyphicon-edit",
      id: "edit-ann-" + annObj.id
    });

    var score = elt("span", {
      class: "score-box"
    }, elt("span", {}, problemStr), elt("span", {}, parsedAnn[1]));
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
    }, parsedAnn[0]);

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

  var updateAnnotationBox = function(ann) {
    $('#ann-box-' + ann.id).find('.edit').show();
    $('#ann-box-' + ann.id).find('.body').show();
    $('#ann-box-' + ann.id).find('.body').html(decodeURI(ann.text));
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

    for (i = 0; i < problems.length; ++i) {
      problemSelect.appendChild(elt("option", {
        value: problems[i].name
      }, problems[i].name));
    }

    var newForm = elt("form", {
      title: "Press <Enter> to Submit",
      class: "annotation-form",
      id: "annotation-form-" + lineInd
    }, rowDiv, hr, submitButton, cancelButton);

    newForm.onsubmit = function(e) {
      e.preventDefault();

      var comment = commentInput.value;
      var value = valueInput.value;
      var problem = problemSelect.value;

      submitNewAnnotation(comment, value, problem, lineInd, newForm);
    };

    $(cancelButton).on('click', function() {
      $(newForm).remove();
    })

    return newForm;
  }


  var newEditAnnotationForm = function(lineInd, ann) {

    var arr = parseText(ann.text);
    var commentStr = arr[0];
    var valueStr = arr[1];
    var problemStr = arr[2];

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

    for (i = 0; i < problems.length; ++i) {
      problemSelect.appendChild(elt("option", {
        value: problems[i].name
      }, problems[i].name));
    }

    $(problemSelect).val(problemStr);

    var newForm = elt("form", {
      title: "Press <Enter> to Submit",
      class: "annotation-edit-form",
      id: "edit-annotation-form-" + lineInd
    }, rowDiv, hr, submitButton, cancelButton);

    newForm.onsubmit = function(e) {
      e.preventDefault();

      var comment = commentInput.value;
      var value = valueInput.value;
      var problem = problemSelect.value;

      ann.text = getText(comment, value, problem)
        //function(annotationObj, lineInd, formEl) {
      updateAnnotation(ann, lineInd, newForm);
    };

    $(cancelButton).on('click', function() {
      updateAnnotationBox(ann);
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
  var submitNewAnnotation = function(comment, value, problem, lineInd, formEl) {

    var newAnnotation = createAnnotation(lineInd);
    newAnnotation.text = getText(comment, value, problem);
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
        console.log(result);
        $(formEl).append("Failed to Save Annotation!!!");
      },
      complete: function(result, type) {}
    });
  }

});