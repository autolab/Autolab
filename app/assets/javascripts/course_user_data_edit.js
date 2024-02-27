function formvalidation(form){
  function DoubleByte(str) {
    for (var i = 0, n = str.length; i < n; i++) {
      if (str.charCodeAt(i) > 127) { return true; }
    }
    return false;
  }
  var nickname = document.getElementById('course_user_datum_nickname');

  if (DoubleByte(nickname.value)){
    nickname.setAttribute('style','background-color:#FFF352');
    nickname.focus();
    alert("Your nickname has non-ASCII characters");
  } else {
    form.submit();
  }
}

const $instructor_checkbox = $('#course_user_datum_instructor');
const $course_assistant_checkbox = $('#course_user_datum_course_assistant');
const $dropped_checkbox = $('#course_user_datum_dropped');
const $fields = [$instructor_checkbox, $course_assistant_checkbox, $dropped_checkbox];

function disable_fields(cur_field, excluded_fields) {
  const checked = cur_field.is(':checked');
  if (checked) {
    excluded_fields.forEach((field) => {
      field.prop('disabled', true);
      field.prop('checked', false);
    });
  }
}

// User can't be dropped if they are an instructor or course assistant
function instructor_or_ca_not_dropped() {
  $fields.forEach((field) => field.prop('disabled', false));
  disable_fields($instructor_checkbox, [$dropped_checkbox]);
  disable_fields($course_assistant_checkbox, [$dropped_checkbox]);
  disable_fields($dropped_checkbox, [$instructor_checkbox, $course_assistant_checkbox]);
}

$(document).ready(function(){
  $('#user_submit').on("click", function(e){
    formvalidation(this.closest('form'));
    e.preventDefault();
  });

  instructor_or_ca_not_dropped();
  $fields.forEach((field) => field.on("click", instructor_or_ca_not_dropped));
});
