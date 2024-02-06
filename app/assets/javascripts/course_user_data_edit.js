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

// User can be at most one of the following: instructor, course assistant, or dropped (student)
const $instructor_checkbox = $('#course_user_datum_instructor');
const $course_assistant_checkbox = $('#course_user_datum_course_assistant');
const $dropped_checkbox = $('#course_user_datum_dropped');
const mutually_exclusive_fields = [
  $instructor_checkbox, $course_assistant_checkbox, $dropped_checkbox
];

function mutual_exclusion() {
  const fields = mutually_exclusive_fields; // For brevity
  // Enable all fields
  fields.forEach((field) => field.prop('disabled', false));

  // If any field is checked, disable the rest
  fields.forEach((field, idx) => {
    if (field.is(':checked')) {
      fields.forEach((field2, idx2) => {
        if (idx !== idx2) {
          field2.prop('disabled', true);
          field2.prop('checked', false);
        }
      });
    }
  });
}

$(document).ready(function(){
  $('#user_submit').on("click", function(e){
    formvalidation(this.closest('form'));
    e.preventDefault();
  });

  mutual_exclusion();
  mutually_exclusive_fields.forEach((field) => field.on("click", mutual_exclusion));
});
