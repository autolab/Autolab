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

function disable_dropped(){
    $('#course_user_datum_dropped').prop("checked",false);
    $('#course_user_datum_dropped').prop("disabled",true);
}

function enable_dropped(){
    $('#course_user_datum_dropped').prop("disabled",false);
}

function prevent_dropping_instructor_ca(){
    if($('#course_user_datum_instructor').is(':checked') || 
        $('#course_user_datum_course_assistant').is(':checked')){
        disable_dropped();
    }
    else{
        enable_dropped();
    }
}

$(document).ready(prevent_dropping_instructor_ca);

$('#course_user_datum_instructor').on( "click", 
    prevent_dropping_instructor_ca);

$('#course_user_datum_course_assistant').on( "click", 
    prevent_dropping_instructor_ca);
