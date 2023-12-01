const updateEditTweakButtons = () => {
  tweaks.forEach(({tweak, submission}) => {
    get_tweak_total(submission.id).then(data => {
      tweak?.setState({ amount: data })
    })
  })
}
const get_tweak_total = (submission_id) => {
  return new Promise((resolve, reject) => {
    $.ajax({
      url: `submissions/${submission_id}/tweak_total`,
      method: 'GET',
      dataType: 'json',
      success: (data) => {
        resolve(data);
      },
      error: (error) => {
        console.error("There was an error fetching the scores:", error);
        reject(error);
      }
    });
  });
}
function newAnnotationFormCode() {
  var box = $(".base-annotation-line").clone();
  box.removeClass("base-annotation-line");

  box.addClass("new-annotation");

  // Creates a dictionary of problem and grader_id
  var problemGraderId = {};

  _.each(scores, function (score) {
    problemGraderId[score.problem_id] = score.grader_id;
  });

  _.each(problems, function (problem, i) {
    if (problemGraderId[problem.id] !== 0) { // Because grader == 0 is autograder
      box.find("select")?.append(
          $("<option />").val(problem.id).text(problem.name)
      );
    }
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
      updateEditTweakButtons();
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

