function newAnnotationFormCode() {
  var box = $(".base-annotation-line").clone();
  box.removeClass("base-annotation-line");

  box.addClass("new-annotation");

  // Creates a dictionary of problem and grader_id
  var problemGraderId = {};
  // _.each(scores, function (score) {
  //   problemGraderId[score.problem_id] = score.grader_id;
  // });

  _.each(problems, function (problem, i) {
    // if (problemGraderId[problem.id] !== 0) { // Because grader == 0 is autograder
    box.find("select")?.append(
        $("<option />").val(problem.id).text(problem.name)
    );
    // }
  });
  
  box.find('.annotation-form').show();
  box.find('.annotation-cancel-button').click(function (e) {
    e.preventDefault();
    $(this).parents(".annotation-form").parent().remove();
    $('#annotation-modal').modal('close');
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
    submitNewAnnotation(comment, shared_comment, true, score, problem_id, 0, $(this));
  });

  return box;
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
      $('#annotation-modal').modal('close');
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
    },
    error: function (result, type) {
      $(box).find('.error').text("Failed to save changes to the annotation. Please refresh the page and try again.").show();
    },
    complete: function (result, type) { }
  });
}

