/* following paths/functions for annotations */
var sharedCommentsPath = basePath + "/shared_comments";

var createPath = basePath + ".json";
var updatePath = function (ann) {
  return [basePath, "/", ann.id, ".json"].join("");
};
var deletePath = updatePath;

function getSharedCommentsForProblem(problem_id) {
  return localCache['shared_comments'][problem_id]?.map(
    (annotation) => {
      return {label: annotation.comment ?? annotation, value: annotation}
    }
  )
}

var selectAnnotation = box => (e, ui) => {
  const {value} = ui.item;

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
function retrieveSharedComments(cb) {
  $.getJSON(sharedCommentsPath, function (data) {
      localCache['shared_comments'] = {};
      data.forEach(e => {
        if (!e.problem_id)
        return;
        localCache['shared_comments'][e.problem_id] ||= [];
        localCache['shared_comments'][e.problem_id].push(e);
      });
      cb?.();
  });
}

function purgeCurrentPageCache() {
  localCache[currentHeaderPos] = {
    codeBox: `<div id="code-box">${$('#code-box').html()}</div>`,
    pdf: false,
    symbolTree: `<div id="symbol-tree-box">${$('#symbol-tree-box').html()}</div>`,
    versionLinks: `<span id="version-links">${$('#version-links').html()}</span>`,
    versionDropdown: `<span id="version-dropdown">${$('#version-dropdown').html()}</span>`,
    url: window.location.href,
  };
}

function plusFix(n) {
  n = parseFloat(n)
  if (isNaN(n)) n = 0;

  if (n > 0) {
    return "+" + n.toFixed(2);
  }

  return n.toFixed(2);
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
    submitted_by: cudEmailStr,
  };
  if (fileNameStr != null) {
    annObj.filename = fileNameStr
  }

  if (currentHeaderPos || currentHeaderPos === 0) {
    annObj.position = currentHeaderPos
  }

  return annObj;
}

function getAnnotationObject(annotationId) {
  for (var i = 0; i < annotations.length; i++) {
    if (annotations[i].id == annotationId) {
      return annotations[i];
    }
  }
}


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
