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

// User can only be one of the following: instructor, course assistant, or dropped (student)
function mutual_exclusion() {
  const $instructor = $('#course_user_datum_instructor');
  const $course_assistant = $('#course_user_datum_course_assistant');
  const $dropped = $('#course_user_datum_dropped');
  const fields = [$instructor, $course_assistant, $dropped];

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
  $('#course_user_datum_instructor').on("click", mutual_exclusion);
  $('#course_user_datum_course_assistant').on("click", mutual_exclusion);
  $('#course_user_datum_dropped').on("click", mutual_exclusion);
});
